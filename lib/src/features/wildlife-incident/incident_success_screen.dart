import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/incident_report.dart';
import 'incident_widgets.dart';

class IncidentSuccessScreen extends StatelessWidget {
  const IncidentSuccessScreen({
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
    title: 'Report Submitted',
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.check_circle, color: Colors.green, size: 100),
      const SizedBox(height: 20),
      Text(
        'Incident Reported Successfully!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      const Text(
        'Your report and photos have been uploaded successfully.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Card(
        child: ListTile(
          title: const Text('Report ID'),
          subtitle: SelectableText(report.id),
          trailing: IconButton(
            tooltip: 'Copy report ID',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report ID copied')),
                );
              }
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
      IncidentActionButton(label: 'View My Reports', onPressed: onReports),
      const SizedBox(height: 12),
      IncidentActionButton(
        label: 'Report Another Incident',
        filled: false,
        onPressed: onAnother,
      ),
    ],
  );
}
