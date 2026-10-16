import 'package:flutter/material.dart';

import '../../../app/theme/theme_controller.dart';

/// App settings screen embedded in the 4-tab shell.
///
/// Provides:
/// - Appearance: theme mode selection (System / Light / Dark) bound to
///   [ThemeController].
/// - Monitoring: local-only toggles for GPS monitoring and power saving.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.themeController})
    : super(key: const Key('settingsScreen'));

  final ThemeController themeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _continuousGps = true;
  bool _powerSaving = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            _sectionHeader(context, 'Appearance'),
            ListenableBuilder(
              listenable: widget.themeController,
              builder: (context, _) {
                final mode = widget.themeController.themeMode;
                return Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System'),
                      secondary: Icon(
                        Icons.brightness_auto,
                        color: colorScheme.primary,
                      ),
                      value: ThemeMode.system,
                      groupValue: mode,
                      onChanged: (value) {
                        if (value != null) {
                          widget.themeController.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      secondary: Icon(
                        Icons.light_mode,
                        color: colorScheme.primary,
                      ),
                      value: ThemeMode.light,
                      groupValue: mode,
                      onChanged: (value) {
                        if (value != null) {
                          widget.themeController.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      secondary: Icon(
                        Icons.dark_mode,
                        color: colorScheme.primary,
                      ),
                      value: ThemeMode.dark,
                      groupValue: mode,
                      onChanged: (value) {
                        if (value != null) {
                          widget.themeController.setThemeMode(value);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const Divider(),
            _sectionHeader(context, 'Monitoring'),
            SwitchListTile(
              key: const Key('continuousGpsSwitch'),
              title: const Text('Continuous GPS Monitoring'),
              secondary: Icon(Icons.gps_fixed, color: colorScheme.primary),
              value: _continuousGps,
              onChanged: (value) => setState(() => _continuousGps = value),
            ),
            SwitchListTile(
              key: const Key('powerSavingSwitch'),
              title: const Text('Power Saving Mode'),
              secondary: Icon(Icons.battery_saver, color: colorScheme.primary),
              value: _powerSaving,
              onChanged: (value) => setState(() => _powerSaving = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
