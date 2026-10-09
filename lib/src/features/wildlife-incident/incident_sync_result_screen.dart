import 'package:flutter/material.dart';
import 'data/incident_repository.dart';
import 'incident_widgets.dart';

class IncidentSyncResultScreen extends StatelessWidget {
  const IncidentSyncResultScreen({
    super.key,
    required this.summary,
    required this.onDone,
  });
  final IncidentSyncSummary summary;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Sync Result',
    footer: SizedBox(
      width: double.infinity,
      child: IncidentActionButton(label: 'OK', onPressed: onDone),
    ),
    children: [
      Icon(
        summary.remaining == 0 ? Icons.check_circle : Icons.cloud_off,
        size: 90,
        color: summary.remaining == 0 ? Colors.green : Colors.orange,
      ),
      const SizedBox(height: 20),
      Text(
        summary.remaining == 0
            ? 'Synchronization Complete'
            : 'Some Reports Still Need Sync',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      IncidentInfoCard(title: 'Reports Uploaded', value: '${summary.uploaded}'),
      IncidentInfoCard(
        title: 'Unsuccessful Attempts',
        value: '${summary.failed}',
      ),
      IncidentInfoCard(title: 'Remaining', value: '${summary.remaining}'),
    ],
  );
}
