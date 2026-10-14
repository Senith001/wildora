import 'package:flutter/material.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import 'conflict_theme.dart';
import 'conflict_repository_view.dart';
import 'conflict_report_photo.dart';

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
        appBar: AppBar(
          title: const Text(
            'Review Report',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              report.referenceNumber,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
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
                  icon: Icons.cloud_done_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${report.wildlifeType.label} • ${report.conflictType.label}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(report.description),
            const SizedBox(height: 8),
            Text('Location: ${report.locationDescription}'),
            const SizedBox(height: 16),
            ConflictReportPhoto(report: report),
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
            const SizedBox(height: 16),
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
