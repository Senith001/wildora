import 'package:flutter/material.dart';
import 'data/incident_report.dart';
import 'incident_widgets.dart';

class IncidentReviewScreen extends StatelessWidget {
  const IncidentReviewScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onSubmit,
    required this.submitting,
  });
  final IncidentDraft draft;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Report Incident',
    step: 4,
    onBack: submitting ? null : onBack,
    footer: Row(
      children: [
        Expanded(
          child: IncidentActionButton(
            label: 'Back',
            filled: false,
            onPressed: submitting ? null : onBack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IncidentActionButton(
            label: submitting ? 'Submitting…' : 'Submit Report',
            onPressed: submitting ? null : onSubmit,
          ),
        ),
      ],
    ),
    children: [
      Text(
        'Review Incident Report',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text('Please review the details before submitting.'),
      const SizedBox(height: 16),
      IncidentInfoCard(title: 'Incident Type', value: draft.type ?? ''),
      IncidentInfoCard(
        title: 'Location',
        value: '${draft.latitude}, ${draft.longitude}\n${draft.locationName}',
      ),
      if (draft.photos.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in draft.photos)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  photo.bytes,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      IncidentInfoCard(title: 'Description', value: draft.description),
      IncidentInfoCard(
        title: 'Date and Time',
        value: formatIncidentDate(context, draft.occurredAt),
      ),
      if (submitting)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('Saving report and uploading to Firebase…'),
            ],
          ),
        ),
    ],
  );
}

String formatIncidentDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  return '${MaterialLocalizations.of(context).formatMediumDate(local)}, ${TimeOfDay.fromDateTime(local).format(context)}';
}
