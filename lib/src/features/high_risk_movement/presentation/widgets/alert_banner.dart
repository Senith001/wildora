import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Critical alert banner widget for high-risk movement alerts.
///
/// Features a red background with warning icon and bold text
/// that adapts to both light and dark themes using AlertColors.
class AlertBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const AlertBanner({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColors.critical,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: alertColors.onCritical, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: alertColors.onCritical,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: alertColors.onCritical),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
