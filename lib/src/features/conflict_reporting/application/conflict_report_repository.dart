import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/conflict_report_ports.dart';
import '../domain/conflict_report.dart';

/// Coordinates the durable outbox, server acknowledgement and CLO workflow.
/// All I/O is injected; UI code only invokes use cases and reads snapshots.
class ConflictReportRepository extends ChangeNotifier {
  ConflictReportRepository({
    required this._store,
    required this._remote,
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.syncTimeout = const Duration(seconds: 25),
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _newId;

  final ConflictReportStore _store;
  final ConflictReportRemote _remote;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final Duration syncTimeout;
  final Map<String, ConflictReport> _local = {};
  final Map<String, ConflictReport> _dashboard = {};
  final Set<String> _busy = {};
  StreamSubscription<ConflictReportFeed>? _subscription;
  Future<void>? _initializing;
  Future<void>? _saveTail;
  bool _disposed = false;
  bool _initialized = false;
  bool _isConnected = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  List<ConflictReport> _sorted(Iterable<ConflictReport> values) =>
      List.unmodifiable(
        values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
  List<ConflictReport> get reports => _sorted(_local.values);
  List<ConflictReport> get synchronizedReports => _sorted(
    {
      ..._dashboard,
      for (final report in _local.values)
        if (report.syncStatus == SyncStatus.synced) report.id: report,
    }.values,
  );
  int get pendingCount =>
      _local.values.where((r) => r.syncStatus != SyncStatus.synced).length;
  ConflictReport current(ConflictReport report) =>
      _local[report.id] ?? _dashboard[report.id] ?? report;
  bool isBusy(ConflictReport report) => _busy.contains(report.id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reloads interrupted submissions as pending; never fabricates acceptance.
  Future<void> initialize() => _initializing ??= _load();
  Future<void> refreshRemote() async {
    await _subscription?.cancel();
    _initializing = null;
    await initialize();
  }

  Future<void> _load() async {
    _errorMessage = null;
    _notify();
    try {
      for (final report in await _store.load()) {
        _local[report.id] = report.syncStatus == SyncStatus.syncing
            ? report.copyWith(syncStatus: SyncStatus.pending)
            : report;
      }
      _initialized = true;
      _errorMessage = null;
      if (_disposed) return;
      _subscription = _remote.watchSubmitted().listen(
        (feed) {
          final reconnected = !isConnected && feed.isConnected;
          _isConnected = feed.isConnected;
          final reports = feed.reports;
          _dashboard
            ..clear()
            ..addEntries(reports.map((r) => MapEntry(r.id, r)));
          // Remote workflow changes replace local status but retain attachments.
          for (final report in reports) {
            if (report.isDemo && !_local.containsKey(report.id)) {
              _local[report.id] = report;
              unawaited(_persistRemoteSnapshot(report));
            }
            final local = _local[report.id];
            if (local != null &&
                local.syncStatus == SyncStatus.synced &&
                !_busy.contains(report.id) &&
                !report.updatedAt.isBefore(local.updatedAt)) {
              final updated = local.copyWith(
                reportStatus: report.reportStatus,
                responseNotes: report.responseNotes,
                reviewedBy: report.reviewedBy,
                reviewedAt: report.reviewedAt,
                resolvedAt: report.resolvedAt,
                updatedAt: report.updatedAt,
                photoUrl: report.photoUrl,
              );
              _local[report.id] = updated;
              unawaited(_persistRemoteSnapshot(updated));
            }
          }
          _notify();
          if (reconnected) unawaited(_retryAfterReconnect());
        },
        onError: (Object error) {
          _isConnected = false;
          _errorMessage =
              'Dashboard unavailable. Your saved reports are retained.';
          _notify();
        },
      );
    } on Object {
      _errorMessage = 'Could not load saved reports. Retry before submitting.';
      _initializing = null;
      rethrow;
    } finally {
      _notify();
    }
  }

  /// Serialize writes so remote updates and local actions cannot contend for
  /// the same temporary file. Failed writes do not block subsequent retries.
  Future<void> _save(ConflictReport report) {
    final previous = _saveTail;
    final operation = previous == null
        ? _store.save(report)
        : previous.then((_) => _store.save(report));
    _saveTail = operation.catchError((Object error) {});
    return operation;
  }

  Future<void> _persistRemoteSnapshot(ConflictReport report) async {
    try {
      await _save(report);
    } on Object {
      _errorMessage =
          'The latest review is visible but could not be saved on this device.';
      _notify();
    }
  }

  Future<void> _retryAfterReconnect() async {
    try {
      await syncPending();
    } on Object {
      _errorMessage = 'Could not retry saved reports. Use Sync to try again.';
      _notify();
    }
  }

  /// Local persistence must succeed before the report is exposed as saved.
  Future<ConflictReport> create({
    required WildlifeType wildlifeType,
    required ConflictType conflictType,
    required String description,
    required double latitude,
    required double longitude,
    required String locationDescription,
    String? photoPath,
    Uint8List? photoBytes,
    String? photoContentType,
  }) async {
    await initialize();
    final now = _clock();
    final id = _idGenerator();
    final report = ConflictReport(
      id: id,
      referenceNumber: 'HWC-${id.toUpperCase()}',
      wildlifeType: wildlifeType,
      conflictType: conflictType,
      description: description.trim(),
      latitude: latitude,
      longitude: longitude,
      locationDescription: locationDescription.trim(),
      createdAt: now,
      photoPath: photoPath,
      photoBytes: photoBytes,
      photoContentType: photoContentType,
    );
    report.validate();
    if (_local.containsKey(id)) throw StateError('Report ID already exists.');
    await _save(report);
    _local[id] = report;
    _notify();
    return report;
  }

  /// Concurrent taps cannot issue duplicate requests. Stable IDs also make
  /// retries after a timeout safe when the server accepted the first attempt.
  Future<bool> sync(ConflictReport report) async {
    report = current(report);
    if (report.syncStatus == SyncStatus.synced) return true;
    if (!_local.containsKey(report.id)) {
      throw ArgumentError('Save the report locally before sending it.');
    }
    if (!_busy.add(report.id)) return false;
    _errorMessage = null;
    _local[report.id] = report.copyWith(syncStatus: SyncStatus.syncing);
    _notify();
    try {
      final acknowledgement = await _remote.submit(report).timeout(syncTimeout);
      final accepted = report.copyWith(
        syncStatus: SyncStatus.synced,
        reporterId: acknowledgement.reporterId,
        isDemo: acknowledgement.isDemo,
        photoDeliveryStatus: acknowledgement.photoDeliveryStatus,
        reviewedBy: acknowledgement.reviewedBy,
        reportStatus: acknowledgement.reportStatus,
        photoUrl: acknowledgement.photoUrl,
        responseNotes: acknowledgement.responseNotes,
        reviewedAt: acknowledgement.reviewedAt,
        resolvedAt: acknowledgement.resolvedAt,
        updatedAt: acknowledgement.updatedAt,
      );
      await _save(accepted);
      _local[report.id] = accepted;
      return true;
    } on Object {
      final failed = report.copyWith(syncStatus: SyncStatus.failed);
      _local[report.id] = failed;
      _errorMessage =
          'Sending failed. The report is saved; retry when connected.';
      // The original pending snapshot is already durable even if this fails.
      try {
        await _save(failed);
      } on Object {
        _errorMessage =
            'Sending failed. The original pending report is retained.';
      }
      return false;
    } finally {
      _busy.remove(report.id);
      _notify();
    }
  }

  Future<void> syncPending() async {
    await initialize();
    for (final report in reports.where(
      (r) => r.syncStatus != SyncStatus.synced,
    )) {
      await sync(report);
    }
  }

  Future<void> markUnderReview(ConflictReport report) async {
    report = current(report);
    if (report.reportStatus != ReportStatus.submitted ||
        report.syncStatus != SyncStatus.synced) {
      throw StateError('Only submitted reports can be reviewed.');
    }
    await _change(
      report,
      () => _remote.review(report),
      report.copyWith(
        reportStatus: ReportStatus.underReview,
        reviewedAt: _clock(),
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> resolve(ConflictReport report, String notes) async {
    report = current(report);
    if (notes.trim().isEmpty) {
      throw ArgumentError('Enter response notes first.');
    }
    if (report.reportStatus != ReportStatus.underReview) {
      throw StateError('Mark the report under review before resolving it.');
    }
    await _change(
      report,
      () => _remote.resolve(report, notes.trim()),
      report.copyWith(
        reportStatus: ReportStatus.resolved,
        responseNotes: notes.trim(),
        resolvedAt: _clock(),
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> _change(
    ConflictReport report,
    Future<void> Function() remote,
    ConflictReport updated,
  ) async {
    if (!_busy.add(report.id)) {
      throw StateError('This report is being updated.');
    }
    _notify();
    try {
      await remote().timeout(syncTimeout);
      _dashboard[report.id] = updated;
      if (_local.containsKey(report.id)) {
        _local[report.id] = updated;
        await _save(updated);
      }
    } finally {
      _busy.remove(report.id);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
