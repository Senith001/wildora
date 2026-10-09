import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';

class ConflictConfirmationScreen extends StatelessWidget {
  const ConflictConfirmationScreen({
    super.key,
    required this.report,
    this.repository,
  });
  final ConflictReport report;
  final ConflictReportRepository? repository;

  @override
  Widget build(BuildContext context) => repository == null
      ? _build(context)
      : AnimatedBuilder(
          animation: repository!,
          builder: (context, _) => _build(context),
        );

  Widget _build(BuildContext context) {
    final report = repository?.current(this.report) ?? this.report;
    final sending = report.syncStatus == SyncStatus.syncing;
    final pending = report.syncStatus != SyncStatus.synced;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 28),
          children: [
            if (report.isDemo)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'DEMO — fictional report; no actual responder notification',
                  textAlign: TextAlign.center,
                ),
              ),
            Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  pending ? Icons.cloud_off : Icons.check,
                  size: 38,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              sending
                  ? 'Sending Report'
                  : pending
                  ? 'Report Saved'
                  : 'Report Submitted',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sending
                  ? 'Saved on this device. Sending to the server...'
                  : pending
                  ? 'Your report is saved on this device. It will retry when this app reconnects. You can also use Retry Sync in My Reports.'
                  : report.reportStatus == ReportStatus.resolved
                  ? 'Your report has been resolved. Response notes are available in My Reports.'
                  : report.reportStatus == ReportStatus.underReview
                  ? 'Your report is being reviewed by the operations team.'
                  : 'The server has received your report. It is pending review and assignment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'REPORT REFERENCE ID',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Chip(
                          label: Text(
                            sending
                                ? 'Sending'
                                : pending
                                ? 'Pending Sync'
                                : report.reportStatus == ReportStatus.submitted
                                ? 'Pending Response'
                                : report.reportStatus.label,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          side: BorderSide(color: colors.error),
                          backgroundColor: colors.surface,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      '#${report.referenceNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    _summaryRow(
                      context,
                      Icons.info_outline,
                      'CONFLICT TYPE',
                      report.conflictType.label,
                    ),
                    const SizedBox(height: 14),
                    _summaryRow(
                      context,
                      Icons.location_on_outlined,
                      'LOCATION',
                      report.locationDescription,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              color: colors.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.shield_outlined, color: colors.primary),
                title: Text(
                  pending
                      ? 'The operations team can review this report after it is sent.'
                      : 'Check My Reports for review updates. Notification has not been confirmed.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/conflict',
                  (route) => route.isFirst,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
