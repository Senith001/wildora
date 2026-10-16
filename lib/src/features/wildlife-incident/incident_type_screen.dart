import 'package:flutter/material.dart';

import 'data/incident_report.dart';
import 'incident_widgets.dart';

class IncidentTypeScreen extends StatelessWidget {
  const IncidentTypeScreen({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });
  final IncidentDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Report Incident',
    step: 1,
    onBack: onBack,
    footer: SizedBox(
      width: double.infinity,
      child: IncidentActionButton(
        label: 'Next',
        onPressed: draft.type == null ? null : onNext,
      ),
    ),
    children: [
      Text(
        'Select Incident Type',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text('Choose the type of incident you want to report.'),
      const SizedBox(height: 20),
      for (final entry in incidentTypes.entries)
        Card(
          color: draft.type == entry.key ? const Color(0xFFE2F1E8) : null,
          child: ListTile(
            leading: const Icon(Icons.pets, color: incidentGreen),
            title: Text(entry.key),
            subtitle: Text(entry.value),
            trailing: Icon(
              draft.type == entry.key
                  ? Icons.check_circle
                  : Icons.chevron_right,
            ),
            onTap: () {
              draft.type = entry.key;
              onChanged();
            },
          ),
        ),
    ],
  );
}
