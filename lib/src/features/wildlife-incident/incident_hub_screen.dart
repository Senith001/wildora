import 'package:flutter/material.dart';
import 'incident_widgets.dart';

/// Presents the feature entry points; navigation is supplied by the owner.
class IncidentHubScreen extends StatelessWidget {
  const IncidentHubScreen({
    super.key,
    required this.onReport,
    required this.onReports,
    required this.onSync,
  });
  final VoidCallback onReport;
  final VoidCallback onReports;
  final VoidCallback onSync;

  Widget _hubActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F1EB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: incidentGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF123B2D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5F6B65),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: incidentGreen),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/landscape.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0x660F583F), BlendMode.darken),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Wildlife Incident',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Respond to wildlife issues quickly and keep reports synced.',
                style: TextStyle(
                  color: Color(0xFFE7F2ED),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 84),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        _hubActionCard(
                          title: 'Report Incident',
                          subtitle: 'Report wildlife or poaching incidents',
                          icon: Icons.pets_rounded,
                          onTap: onReport,
                        ),
                        _hubActionCard(
                          title: 'View My Reports',
                          subtitle: 'Check submitted reports',
                          icon: Icons.assignment_rounded,
                          onTap: onReports,
                        ),
                        _hubActionCard(
                          title: 'Sync Pending Reports',
                          subtitle: 'Upload offline reports',
                          icon: Icons.sync_alt_rounded,
                          onTap: onSync,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
