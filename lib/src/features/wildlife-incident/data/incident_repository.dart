import 'dart:async';
import 'package:flutter/foundation.dart';
import 'incident_store_ports.dart';
import '../application/incident_access.dart';
export '../application/incident_access.dart' show IncidentSyncSummary;
import 'incident_failure_policy.dart';
export 'incident_failure_policy.dart' show incidentErrorMessage;
import 'incident_report.dart';

class IncidentRepository extends ChangeNotifier
    implements IncidentFeatureAccess {
  IncidentRepository({
    required IncidentLocalStore local,
    required IncidentRemoteStore remote,
    IncidentFailurePolicy failurePolicy = const DefaultIncidentFailurePolicy(),
  }) : _local = local,
       _remote = remote,
       _failurePolicy = failurePolicy;

  final IncidentFailurePolicy _failurePolicy;
  final IncidentLocalStore _local;
  final IncidentRemoteStore _remote;
  final Map<String, IncidentReport> _reports = {};
  final Map<String, IncidentReport> _cloudReports = {};
  StreamSubscription<List<IncidentReport>>? _subscription;
  Timer? _retryTimer;
  Future<void>? _initializing;
  Future<IncidentSyncSummary>? _syncing;
  bool _disposed = false;
  @override
  bool ready = false;
  @override
  bool syncing = false;
  @override
  int syncCompleted = 0;
  @override
  int syncTotal = 0;
  String? loadError;
  @override
  String? cloudError;
  late String reporterId;

  @override
  List<IncidentReport> get reports {
    final merged = {..._cloudReports, ..._reports};
    final result = merged.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  int get pendingCount => _reports.values
      .where((report) => report.status != IncidentSyncStatus.synchronized)
      .length;

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      reporterId = await _local.initialize();
      for (final report in _local.readReports()) {
        _reports[report.id] = report;
      }
      if (_disposed) return;
      ready = true;
      loadError = null;
      _subscription = _remote
          .watchReports(reporterId)
          .listen(
            (reports) {
              _cloudReports
                ..clear()
                ..addEntries(
                  reports.map((report) => MapEntry(report.id, report)),
                );
              cloudError = null;
              _notify();
            },
            onError: (Object error) {
              cloudError = _failurePolicy.message(error);
              _notify();
            },
          );
      _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_reports.values.any(
          (report) => report.status == IncidentSyncStatus.pending,
        )) {
          unawaited(
            syncPending(includeFailed: false).catchError((Object error) {
              cloudError = _failurePolicy.message(error);
              _notify();
              return IncidentSyncSummary(
                uploaded: 0,
                failed: 0,
                remaining: pendingCount,
              );
            }),
          );
        }
      });
      _notify();
    } catch (error) {
      loadError = 'Unable to open local report storage: $error';
      _initializing = null;
      _notify();
      rethrow;
    }
  }

  /// Local save must succeed before the UI can claim a report has been saved.
  @override
  Future<IncidentReport> submit(IncidentDraft draft) async {
    await initialize();
    final report = draft.toReport(reporterId);
    await _local.save(report);
    _reports[report.id] = report;
    _notify();
    try {
      await syncPending();
      // A submission created during an existing upload batch needs its own turn.
      if (_reports[report.id]!.status == IncidentSyncStatus.pending &&
          _reports[report.id]!.error == null) {
        await syncPending();
      }
    } catch (error) {
      // The original report was already persisted; never invite a duplicate submit.
      _reports[report.id] = _reports[report.id]!.withSync(
        IncidentSyncStatus.pending,
        error:
            'Report saved locally, but sync could not finish: ${_failurePolicy.message(error)}',
      );
      _notify();
    }
    return _reports[report.id]!;
  }

  @override
  Future<IncidentSyncSummary> syncPending({bool includeFailed = true}) async {
    await initialize();
    // One upload worker per repository prevents double taps from duplicating work.
    if (_syncing != null) {
      return _syncing!;
    }
    final work = _runSync(includeFailed: includeFailed);
    _syncing = work;
    try {
      return await work;
    } finally {
      if (identical(_syncing, work)) _syncing = null;
    }
  }

  Future<IncidentSyncSummary> _runSync({required bool includeFailed}) async {
    final pending = _reports.values
        .where(
          (report) =>
              report.status == IncidentSyncStatus.pending ||
              (includeFailed && report.status == IncidentSyncStatus.failed),
        )
        .toList();
    syncing = true;
    syncTotal = pending.length;
    syncCompleted = 0;
    _notify();
    var uploaded = 0;
    var failed = 0;
    try {
      for (final report in pending) {
        IncidentReport updated;
        try {
          final urls = await _remote.upload(report);
          updated = report.withSync(
            IncidentSyncStatus.synchronized,
            photoUrls: urls,
          );
          uploaded++;
        } catch (failure) {
          final error = failure is IncidentUploadFailure
              ? failure.cause
              : failure;
          final retryable = _failurePolicy.isRetryable(error);
          updated = report.withSync(
            retryable ? IncidentSyncStatus.pending : IncidentSyncStatus.failed,
            error: _failurePolicy.message(error),
            photoUrls: failure is IncidentUploadFailure
                ? failure.photoUrls
                : null,
          );
          failed++;
        }
        await _local.save(updated);
        _reports[report.id] = updated;
        syncCompleted++;
        _notify();
      }
      return IncidentSyncSummary(
        uploaded: uploaded,
        failed: failed,
        remaining: pendingCount,
      );
    } finally {
      syncing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
