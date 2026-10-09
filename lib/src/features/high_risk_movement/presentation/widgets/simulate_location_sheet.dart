import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/models/animal.dart';
import '../../application/animal_monitoring_controller.dart';
import '../../domain/monitoring_state.dart';

/// Development sheet for simulating location updates to test the detection flow.
///
/// Features:
/// - Select from seeded animals (e.g. elephant-23)
/// - Choose preset locations (inside/outside high-risk zones)
/// - Or enter custom lat/lng coordinates
/// - Triggers the real detection flow via controller.onLocationReceived
/// - Shows feedback on detection results
class SimulateLocationSheet extends StatefulWidget {
  final AnimalMonitoringController controller;

  const SimulateLocationSheet({super.key, required this.controller});

  @override
  State<SimulateLocationSheet> createState() => _SimulateLocationSheetState();
}

class _SimulateLocationSheetState extends State<SimulateLocationSheet> {
  String? selectedAnimalId;
  String selectedLocationMode = 'preset';
  String selectedPreset = 'inside_farmland';

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  bool _isLoading = false;
  String? _resultMessage;
  Color? _resultColor;

  // Preset locations based on seeded data from plan
  final Map<String, Map<String, dynamic>> _presetLocations = {
    'inside_farmland': {
      'name': 'Inside Farmland Zone',
      'lat': -1.2921,
      'lng': 36.8219,
      'description': 'Center of farmland border zone (should trigger alert)',
    },
    'inside_road': {
      'name': 'Inside Road Zone',
      'lat': -1.3000,
      'lng': 36.8300,
      'description': 'Center of main road zone (should trigger alert)',
    },
    'outside_zones': {
      'name': 'Outside All Zones',
      'lat': -1.2500,
      'lng': 36.7500,
      'description': 'Safe area outside all zones (no alert)',
    },
    'near_farmland': {
      'name': 'Near Farmland Zone',
      'lat': -1.2930,
      'lng': 36.8230,
      'description': 'Just outside farmland zone (no alert)',
    },
  };

  // Demo animals from seeded data
  final List<Map<String, String>> _demoAnimals = [
    {
      'id': 'elephant-23',
      'name': 'Elephant-23',
      'species': 'Elephant',
      'description': 'Has collar, suitable for testing',
    },
    {
      'id': 'buffalo-11',
      'name': 'Buffalo-11',
      'species': 'Buffalo',
      'description': 'No collar (will be skipped)',
    },
  ];

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.developer_mode, color: alertColors.signal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulate Location Update',
                        key: const Key('simulateSheetTitle'),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animal selection
                      _buildAnimalSelection(),
                      const SizedBox(height: 24),

                      // Location mode selection
                      _buildLocationModeSelection(),
                      const SizedBox(height: 16),

                      // Location input based on mode
                      if (selectedLocationMode == 'preset')
                        _buildPresetSelection()
                      else
                        _buildCustomLocationInput(),
                      const SizedBox(height: 24),

                      // Simulate button
                      _buildSimulateButton(),
                      const SizedBox(height: 16),

                      // Result display
                      if (_resultMessage != null) _buildResultDisplay(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build animal selection section
  Widget _buildAnimalSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Animal',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._demoAnimals.map((animal) {
          final isSelected = selectedAnimalId == animal['id'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              title: Text(animal['name']!),
              subtitle: Text(animal['description']!),
              leading: Icon(
                Icons.pets,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                setState(() {
                  selectedAnimalId = animal['id'];
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Build location mode selection (preset vs custom)
  Widget _buildLocationModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Input Mode',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'preset',
              label: Text('Preset Locations'),
              icon: Icon(Icons.location_city),
            ),
            ButtonSegment(
              value: 'custom',
              label: Text('Custom Coords'),
              icon: Icon(Icons.edit_location),
            ),
          ],
          selected: {selectedLocationMode},
          onSelectionChanged: (Set<String> selection) {
            setState(() {
              selectedLocationMode = selection.first;
            });
          },
        ),
      ],
    );
  }

  /// Build preset location selection
  Widget _buildPresetSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Preset Location',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._presetLocations.entries.map((entry) {
          final preset = entry.key;
          final data = entry.value;
          final isSelected = selectedPreset == preset;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              title: Text(data['name'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['description'] as String),
                  const SizedBox(height: 4),
                  Text(
                    '${data['lat']}, ${data['lng']}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
              leading: Icon(
                _getPresetIcon(preset),
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                setState(() {
                  selectedPreset = preset;
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Build custom location input fields
  Widget _buildCustomLocationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Coordinates',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '-1.2921',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '36.8219',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build simulate button
  Widget _buildSimulateButton() {
    final alertColors = Theme.of(context).extension<AlertColors>()!;
    final canSimulate = selectedAnimalId != null && _canGetCoordinates();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSimulate && !_isLoading ? _simulateLocationUpdate : null,
        icon: _isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isLoading ? 'Simulating...' : 'Simulate Location Update'),
        style: ElevatedButton.styleFrom(
          backgroundColor: alertColors.signal,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Build result display
  Widget _buildResultDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (_resultColor ?? Theme.of(context).colorScheme.surfaceVariant)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _resultColor ?? Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulation Result',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _resultMessage!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: _resultColor),
          ),
        ],
      ),
    );
  }

  /// Get appropriate icon for preset location
  IconData _getPresetIcon(String preset) {
    switch (preset) {
      case 'inside_farmland':
      case 'near_farmland':
        return Icons.agriculture;
      case 'inside_road':
        return Icons.directions_car;
      case 'outside_zones':
        return Icons.forest;
      default:
        return Icons.location_on;
    }
  }

  /// Check if we can get coordinates based on current mode
  bool _canGetCoordinates() {
    if (selectedLocationMode == 'preset') {
      return true; // Presets always have coordinates
    } else {
      return _latController.text.isNotEmpty && _lngController.text.isNotEmpty;
    }
  }

  /// Get coordinates based on current selection
  Map<String, double>? _getCoordinates() {
    if (selectedLocationMode == 'preset') {
      final preset = _presetLocations[selectedPreset];
      if (preset != null) {
        return {'lat': preset['lat']!, 'lng': preset['lng']!};
      }
    } else {
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    }
    return null;
  }

  /// Simulate location update by calling controller
  Future<void> _simulateLocationUpdate() async {
    if (selectedAnimalId == null) return;

    final coordinates = _getCoordinates();
    if (coordinates == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _resultColor = null;
    });

    try {
      // Create animal location for the update
      final animalLocation = AnimalLocation(
        latitude: coordinates['lat']!,
        longitude: coordinates['lng']!,
        timestamp: Timestamp.fromDate(DateTime.now()),
      );

      // Call controller to process the location update
      await widget.controller.onLocationReceived(
        selectedAnimalId!,
        animalLocation,
      );

      // Check controller state for result
      final state = widget.controller.state;
      if (state == MonitoringState.alertRaised) {
        setState(() {
          _resultMessage =
              '🚨 HIGH-RISK ALERT CREATED!\n'
              'Animal entered dangerous zone. Alert sent to nearby officers.';
          _resultColor = Theme.of(context).extension<AlertColors>()!.critical;
        });
      } else if (state == MonitoringState.locationUpdated) {
        setState(() {
          _resultMessage =
              '✅ Location updated successfully.\n'
              'Animal is safe - no high-risk zones detected.';
          _resultColor = Theme.of(context).colorScheme.secondary;
        });
      } else if (state == MonitoringState.error) {
        setState(() {
          _resultMessage =
              '❌ Simulation failed:\n${widget.controller.errorMessage ?? 'Unknown error'}';
          _resultColor = Theme.of(context).colorScheme.error;
        });
      } else {
        setState(() {
          _resultMessage = 'ℹ️ Animal skipped (no collar or invalid data)';
          _resultColor = Theme.of(context).colorScheme.onSurfaceVariant;
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = '❌ Simulation error: $e';
        _resultColor = Theme.of(context).colorScheme.error;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
