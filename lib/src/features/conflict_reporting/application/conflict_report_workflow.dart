import '../domain/conflict_report.dart';

/// Validates officer transitions and prepares updated report snapshots.
class ConflictReportWorkflow {
  ConflictReportWorkflow(this._clock);

  final DateTime Function() _clock;

  ConflictReport underReview(ConflictReport report) {
    if (report.reportStatus != ReportStatus.submitted ||
        report.syncStatus != SyncStatus.synced) {
      throw StateError('Only submitted reports can be reviewed.');
    }
    return report.copyWith(
      reportStatus: ReportStatus.underReview,
      reviewedAt: _clock(),
      updatedAt: _clock(),
    );
  }

  ConflictReport resolved(ConflictReport report, String notes) {
    if (notes.trim().isEmpty) {
      throw ArgumentError('Enter response notes first.');
    }
    if (report.reportStatus != ReportStatus.underReview) {
      throw StateError('Mark the report under review before resolving it.');
    }
    return report.copyWith(
      reportStatus: ReportStatus.resolved,
      responseNotes: notes.trim(),
      resolvedAt: _clock(),
      updatedAt: _clock(),
    );
  }
}
