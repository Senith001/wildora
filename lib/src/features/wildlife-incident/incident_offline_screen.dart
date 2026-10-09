import 'package:flutter/material.dart';
import 'data/incident_report.dart';
import 'incident_widgets.dart';

class IncidentOfflineScreen extends StatelessWidget {
  const IncidentOfflineScreen({
    super.key,
    required this.report,
    required this.onReports,
    required this.onAnother,
  });
  final IncidentReport report;
  final VoidCallback onReports;
  final VoidCallback onAnother;
  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Saved on This Device',
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.cloud_upload_outlined, size: 100, color: Colors.orange),
      const SizedBox(height: 20),
      Text(
        'Saved Locally',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      const Text(
        'Your report and photos are saved on this device. The upload has not completed.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      if (report.error != null)
        IncidentInfoCard(title: 'Upload status', value: report.error!),
      IncidentInfoCard(title: 'Report ID', value: report.id),
      const SizedBox(height: 24),
      IncidentActionButton(label: 'View Pending Reports', onPressed: onReports),
      const SizedBox(height: 12),
      IncidentActionButton(
        label: 'Report Another Incident',
        filled: false,
        onPressed: onAnother,
      ),
    ],
  );
}
