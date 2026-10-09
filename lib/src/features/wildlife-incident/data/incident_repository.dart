import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'incident_local_store.dart';
import 'incident_remote_store.dart';
import 'incident_report.dart';
import 'cloudinary_photo_store.dart';

class IncidentSyncSummary {
  const IncidentSyncSummary({
    required this.uploaded,
    required this.failed,
    required this.remaining,
  });
  final int uploaded;
  final int failed;
  final int remaining;
}

class IncidentRepository extends ChangeNotifier {
  IncidentRepository({
    required IncidentLocalStore local,
    required IncidentRemoteStore remote,
  }) : _local = local,
       _remote = remote;

  factory IncidentRepository.firebase() => IncidentRepository(
    local: HiveIncidentLocalStore(),
    remote: FirebaseIncidentRemoteStore(),
  );

  final IncidentLocalStore _local;
  final IncidentRemoteStore _remote;
  final Map<String, IncidentReport> _reports = {};
  final Map<String, IncidentReport> _cloudReports = {};
  StreamSubscription<List<IncidentReport>>? _subscription;
  Timer? _retryTimer;
  Future<void>? _initializing;
  Future<IncidentSyncSummary>? _syncing;
  bool _disposed = false;
  bool ready = false;
  bool syncing = false;
  int syncCompleted = 0;
  int syncTotal = 0;
  String? loadError;
  String? cloudError;
  late String reporterId;

  List<IncidentReport> get reports {
    final merged = {..._cloudReports, ..._reports};
    final result = merged.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  int get pendingCount => _reports.values
      .where((report) => report.status != IncidentSyncStatus.synchronized)
      .length;

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
              cloudError = incidentErrorMessage(error);
              _notify();
            },
          );
      _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_reports.values.any(
          (report) => report.status == IncidentSyncStatus.pending,
        )) {
          unawaited(
            syncPending(includeFailed: false).catchError((Object error) {
              cloudError = incidentErrorMessage(error);
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
            'Report saved locally, but sync could not finish: ${incidentErrorMessage(error)}',
      );
      _notify();
    }
    return _reports[report.id]!;
  }

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
          final retryable =
              error is TimeoutException ||
              (error is CloudinaryUploadException && error.retryable) ||
              (error is FirebaseException &&
                  [
                    'unavailable',
                    'network-request-failed',
                    'retry-limit-exceeded',
                    'unknown',
                  ].contains(error.code));
          updated = report.withSync(
            retryable ? IncidentSyncStatus.pending : IncidentSyncStatus.failed,
            error: incidentErrorMessage(error),
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

String incidentErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'Connection timed out. Your report remains saved on this device.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Firebase denied access. Check the incident Firestore rules, then retry.';
      case 'bucket-not-found':
      case 'no-default-bucket':
        return 'Photos use Cloudinary. Check your Firebase project configuration and retry.';
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return 'Unable to reach Firebase. Your report remains saved on this device.';
      default:
        return 'Firebase ${error.code}: ${error.message ?? 'Upload failed. Please retry.'}';
    }
  }
  return error.toString();
}
