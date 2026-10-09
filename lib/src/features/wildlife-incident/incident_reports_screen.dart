import 'package:flutter/material.dart';

import 'data/incident_report.dart';
import 'data/incident_repository.dart';
import 'incident_report_detail_screen.dart';
import 'incident_review_screen.dart';
import 'incident_widgets.dart';
import 'incident_theme.dart';

class IncidentReportsScreen extends StatefulWidget {
  const IncidentReportsScreen({
    super.key,
    required this.repository,
    this.onBack,
    this.onAnother,
  });
  final IncidentRepository repository;
  final VoidCallback? onBack;
  final VoidCallback? onAnother;
  @override
  State<IncidentReportsScreen> createState() => _IncidentReportsScreenState();
}

class _IncidentReportsScreenState extends State<IncidentReportsScreen> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final repository = widget.repository;
      final reports = repository.reports
          .where(
            (report) =>
                _filter == 0 ||
                (_filter == 1 &&
                    report.status != IncidentSyncStatus.synchronized) ||
                (_filter == 2 &&
                    report.status == IncidentSyncStatus.synchronized),
          )
          .toList();
      return IncidentPage(
        title: 'My Reports',
        onBack: widget.onBack,
        footer: widget.onAnother == null
            ? null
            : SizedBox(
                width: double.infinity,
                child: IncidentActionButton(
                  label: 'Report an Incident',
                  onPressed: widget.onAnother,
                ),
              ),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var index = 0; index < 3; index++)
                ChoiceChip(
                  label: Text(['All', 'Pending Sync', 'Synchronized'][index]),
                  selected: _filter == index,
                  onSelected: (_) => setState(() => _filter = index),
                ),
            ],
          ),
          if (repository.cloudError != null)
            IncidentInfoCard(
              title: 'Cloud connection',
              value: repository.cloudError!,
            ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No reports in this category.'),
            ),
          for (final report in reports)
            Card(
              child: ListTile(
                leading: const Icon(Icons.pets, color: incidentGreen),
                title: Text(report.type),
                subtitle: Text(
                  '${formatIncidentDate(context, report.occurredAt)}\n${incidentStatusLabel(report.status)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Theme(
                      data: incidentTheme(),
                      child: ListenableBuilder(
                        listenable: repository,
                        builder: (_, _) => IncidentReportDetailScreen(
                          report: repository.reports.firstWhere(
                            (item) => item.id == report.id,
                            orElse: () => report,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
