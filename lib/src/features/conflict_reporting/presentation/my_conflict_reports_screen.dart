import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import 'conflict_theme.dart';
import 'conflict_repository_view.dart';

class MyConflictReportsScreen extends StatelessWidget {
  const MyConflictReportsScreen({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => ConflictRepositoryView(
    repository: repository,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: repository.reports.isEmpty
          ? const Center(child: Text('No reports yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: repository.reports.length,
              itemBuilder: (context, index) {
                final report = repository.reports[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      report.syncStatus == SyncStatus.synced
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: context.syncStatusColor(report.syncStatus),
                    ),
                    title: Text(report.referenceNumber),
                    subtitle: Text(
                      '${report.wildlifeType.label} • ${report.conflictType.label}\n'
                      '${report.reportStatus.label} • ${report.syncStatus.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.reportStatusColor(report.reportStatus),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/conflict/details',
                      arguments: report,
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
