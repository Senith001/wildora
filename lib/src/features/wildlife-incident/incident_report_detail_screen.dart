import 'package:flutter/material.dart';

import 'data/incident_report.dart';
import 'incident_review_screen.dart';
import 'incident_widgets.dart';

class IncidentReportDetailScreen extends StatelessWidget {
  const IncidentReportDetailScreen({super.key, required this.report});
  final IncidentReport report;

  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Report Details',
    onBack: () => Navigator.pop(context),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.type,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1D),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: incidentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    incidentStatusLabel(report.status),
                    style: const TextStyle(
                      color: incidentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              report.id,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
      if (report.error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8B7B7)),
          ),
          child: Text(
            report.error!,
            style: const TextStyle(color: Color(0xFFB3261E)),
          ),
        ),
      if (report.photos.isNotEmpty || report.photoUrls.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final photo in report.photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        photo.bytes,
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                  for (final source in report.photoUrls)
                    _buildPhotoWidget(source),
                ],
              ),
            ],
          ),
        ),
      _buildInfoCard(
        title: 'Location',
        value:
            '${report.latitude}, ${report.longitude}\n${report.locationName}',
      ),
      const SizedBox(height: 14),
      _buildInfoCard(
        title: 'Date and Time',
        value: formatIncidentDate(context, report.occurredAt),
      ),
      const SizedBox(height: 14),
      _buildInfoCard(title: 'Description', value: report.description),
    ],
  );

  Widget _buildInfoCard({required String title, required String value}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAE6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF2C2C2C),
              ),
            ),
          ],
        ),
      );
}

Widget _buildPhotoWidget(String source) {
  if (source.startsWith('data:')) {
    try {
      final bytes = decodeIncidentPhotoDataUri(source);
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(bytes, height: 110, width: 110, fit: BoxFit.cover),
      );
    } on FormatException {
      return const SizedBox(
        width: 110,
        height: 110,
        child: Center(child: Text('Photo unavailable')),
      );
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image.network(
      source,
      height: 110,
      width: 110,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stack) => const SizedBox(
        width: 110,
        height: 110,
        child: Center(child: Text('Photo unavailable offline')),
      ),
    ),
  );
}

String incidentStatusLabel(IncidentSyncStatus status) => switch (status) {
  IncidentSyncStatus.pending => 'Pending Sync',
  IncidentSyncStatus.failed => 'Sync Failed',
  IncidentSyncStatus.synchronized => 'Synchronized',
};
