import 'package:flutter/foundation.dart';
import '../data/incident_report.dart';

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

/// Read-only access for report lists. It exposes no submission or sync commands.
abstract interface class IncidentReportReader implements Listenable {
  List<IncidentReport> get reports;
  String? get cloudError;
}

/// The sync screen only depends on progress and the sync command.
abstract interface class IncidentSyncAccess implements Listenable {
  int get pendingCount;
  bool get syncing;
  int get syncCompleted;
  int get syncTotal;
  String? get cloudError;
  Future<IncidentSyncSummary> syncPending({bool includeFailed = true});
}

abstract interface class IncidentSubmission {
  Future<IncidentReport> submit(IncidentDraft draft);
}

/// Lifecycle belongs to the feature owner, rather than individual screens.
abstract interface class IncidentFeatureAccess
    implements IncidentReportReader, IncidentSyncAccess, IncidentSubmission {
  bool get ready;
  Future<void> initialize();
  void dispose();
}
