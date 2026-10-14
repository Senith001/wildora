import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import 'conflict_theme.dart';
import 'conflict_repository_view.dart';
import 'conflict_report_photo.dart';
import '../application/conflict_photo_settings.dart';

class ConflictDetailsScreen extends StatelessWidget {
  const ConflictDetailsScreen({
    super.key,
    required this.report,
    required this.repository,
  });
  final ConflictReport report;
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => ConflictRepositoryView(
    repository: repository,
    builder: (context, _) {
      final report = repository.current(this.report);
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Report Details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              report.referenceNumber,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
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
                  icon: Icons.cloud_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detail(context, 'Wildlife', report.wildlifeType.label),
            _detail(context, 'Conflict', report.conflictType.label),
            _detail(context, 'Location', report.locationDescription),
            _detail(context, 'Description', report.description),
            if (report.isDemo)
              const Text(
                'DEMO — fictional incident; no responder notification',
              ),
            ConflictReportPhoto(report: report),
            if (ConflictPhotoSettings.enabled &&
                report.photoBytes != null &&
                report.photoDeliveryStatus == 'deviceOnly' &&
                report.syncStatus == SyncStatus.synced)
              OutlinedButton.icon(
                onPressed: repository.isBusy(report)
                    ? null
                    : () => repository.sync(report, retryPhoto: true),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload saved photo'),
              ),
            if (repository.errorMessage != null) Text(repository.errorMessage!),
            _detail(
              context,
              'Reported',
              report.createdAt.toLocal().toString().split('.').first,
            ),
            if (report.responseNotes != null)
              _detail(context, 'Officer response', report.responseNotes!),
            if (report.syncStatus != SyncStatus.synced)
              FilledButton.icon(
                onPressed: repository.isBusy(report)
                    ? null
                    : () => repository.sync(report),
                icon: const Icon(Icons.sync),
                label: const Text('Retry Sync'),
              ),
          ],
        ),
      );
    },
  );

  Widget _detail(BuildContext context, String title, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
}
