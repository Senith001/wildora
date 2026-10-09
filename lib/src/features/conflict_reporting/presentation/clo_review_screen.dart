import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import 'conflict_theme.dart';
import 'conflict_repository_view.dart';

class CloReviewScreen extends StatefulWidget {
  const CloReviewScreen({
    super.key,
    required this.report,
    required this.repository,
  });
  final ConflictReport report;
  final ConflictReportRepository repository;

  @override
  State<CloReviewScreen> createState() => _CloReviewScreenState();
}

class _CloReviewScreenState extends State<CloReviewScreen> {
  late final notes = TextEditingController(text: widget.report.responseNotes);

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the report. Refresh and retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ConflictRepositoryView(
    repository: widget.repository,
    builder: (context, _) {
      final report = widget.repository.current(widget.report);
      final busy = widget.repository.isBusy(report);
      return Scaffold(
        appBar: AppBar(title: const Text('Review Report')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              report.referenceNumber,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: context.reportStatusColor(report.reportStatus),
              ),
              label: Text(report.reportStatus.label),
            ),
            const SizedBox(height: 16),
            Text('${report.wildlifeType.label} • ${report.conflictType.label}'),
            const SizedBox(height: 8),
            Text(report.description),
            const SizedBox(height: 8),
            Text('Location: ${report.locationDescription}'),
            const SizedBox(height: 24),
            if (report.reportStatus == ReportStatus.submitted)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _perform(
                        () => widget.repository.markUnderReview(report),
                        'Report is under review.',
                      ),
                child: const Text('Mark Under Review'),
              ),
            TextField(
              controller: notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Response notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (report.reportStatus == ReportStatus.underReview)
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        if (notes.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter response notes first.'),
                            ),
                          );
                          return;
                        }
                        _perform(
                          () => widget.repository.resolve(report, notes.text),
                          'Report resolved.',
                        );
                      },
                icon: const Icon(Icons.check),
                label: const Text('Record Response & Resolve'),
              ),
          ],
        ),
      );
    },
  );
}
