import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';

extension ConflictThemeColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  Color syncStatusColor(SyncStatus status) => switch (status) {
    SyncStatus.synced =>
      _dark ? const Color(0xFF80CBC4) : const Color(0xFF00695C),
    SyncStatus.syncing =>
      _dark ? const Color(0xFF80DEEA) : const Color(0xFF006064),
    SyncStatus.failed =>
      _dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    SyncStatus.pending =>
      _dark ? const Color(0xFFFFCC80) : const Color(0xFF8A5100),
  };

  Color reportStatusColor(ReportStatus status) => switch (status) {
    ReportStatus.resolved =>
      _dark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
    ReportStatus.underReview =>
      _dark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
    ReportStatus.submitted =>
      _dark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
    ReportStatus.savedOffline =>
      _dark ? const Color(0xFFFFCC80) : const Color(0xFF8A5100),
  };
}

/// Applies presentation defaults only within the conflict-reporting routes.
class ConflictFeatureTheme extends StatelessWidget {
  const ConflictFeatureTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: colors.surfaceContainerLowest,
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.appBarTheme.foregroundColor ?? colors.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: theme.cardTheme.copyWith(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
            FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).merge(
            OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
            TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Status remains readable without relying on colour alone.
class ConflictStatusBadge extends StatelessWidget {
  const ConflictStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      border: Border.all(color: color.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class ConflictReportListCard extends StatelessWidget {
  const ConflictReportListCard({
    super.key,
    required this.report,
    required this.onTap,
  });
  final ConflictReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(report.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${report.wildlifeType.label} • ${report.conflictType.label}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(report.referenceNumber, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Text(
                report.locationDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(date, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConflictStatusBadge(
                    label: report.reportStatus.label,
                    color: context.reportStatusColor(report.reportStatus),
                    icon: Icons.assignment_outlined,
                  ),
                  ConflictStatusBadge(
                    label: report.syncStatus.label,
                    color: context.syncStatusColor(report.syncStatus),
                    icon: report.syncStatus == SyncStatus.synced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
