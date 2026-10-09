import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';

extension ConflictThemeColors on BuildContext {
  Color syncStatusColor(SyncStatus status) {
    final colors = Theme.of(this).colorScheme;
    return switch (status) {
      SyncStatus.synced => colors.primary,
      SyncStatus.syncing => colors.secondary,
      SyncStatus.failed => colors.error,
      SyncStatus.pending => colors.tertiary,
    };
  }

  Color reportStatusColor(ReportStatus status) {
    final colors = Theme.of(this).colorScheme;
    return switch (status) {
      ReportStatus.resolved => colors.primary,
      ReportStatus.underReview => colors.secondary,
      ReportStatus.submitted => colors.tertiary,
      ReportStatus.savedOffline => colors.error,
    };
  }
}
