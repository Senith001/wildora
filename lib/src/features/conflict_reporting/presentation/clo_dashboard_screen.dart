import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import 'conflict_theme.dart';
import 'conflict_repository_view.dart';

class CloDashboardScreen extends StatelessWidget {
  const CloDashboardScreen({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => ConflictRepositoryView(
    repository: repository,
    builder: (context, _) {
      final reports = repository.synchronizedReports;
      int count(ReportStatus status) =>
          reports.where((report) => report.reportStatus == status).length;
      return Scaffold(
        appBar: AppBar(title: const Text('CLO Dashboard')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (repository.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(repository.errorMessage!),
              ),
            Row(
              children: [
                _stat(context, 'Pending', count(ReportStatus.submitted)),
                _stat(context, 'Review', count(ReportStatus.underReview)),
                _stat(context, 'Resolved', count(ReportStatus.resolved)),
              ],
            ),
            const SizedBox(height: 20),
            if (reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No synchronized reports are available for review.',
                  ),
                ),
              ),
            ...reports.map(
              (report) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.assignment,
                    color: context.reportStatusColor(report.reportStatus),
                  ),
                  title: Text(report.referenceNumber),
                  subtitle: Text(
                    '${report.wildlifeType.label} • ${report.conflictType.label}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/conflict/clo/review',
                    arguments: report,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _stat(BuildContext context, String label, int value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
