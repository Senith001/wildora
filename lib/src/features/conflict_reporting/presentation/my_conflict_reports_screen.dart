import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: repository.reports.isEmpty
          ? const Center(child: Text('No reports yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: repository.reports.length,
              itemBuilder: (context, index) {
                final report = repository.reports[index];
                return ConflictReportListCard(
                  report: report,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/conflict/details',
                    arguments: report,
                  ),
                );
              },
            ),
    ),
  );
}
