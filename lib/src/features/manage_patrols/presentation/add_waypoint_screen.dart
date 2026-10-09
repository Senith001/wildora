import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';

/// Screen 3: Add Waypoint
///
/// Allows a ranger to record a point of interest during an active patrol
/// with GPS or manual coordinates, category, optional note, and optional
/// photo reference.
class AddWaypointScreen extends StatefulWidget {
  const AddWaypointScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  State<AddWaypointScreen> createState() => _AddWaypointScreenState();
}

class _AddWaypointScreenState extends State<AddWaypointScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _noteController = TextEditingController();

  WaypointType _selectedType = WaypointType.animalSighting;
  LocationSource _locationSource = LocationSource.gps;
  bool _isSaving = false;
  bool _isCapturingGps = false;
  String? _error;
  String? _photoReference;

  @override
  void initState() {
    super.initState();
    _captureGps();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() {
      _isCapturingGps = true;
      _error = null;
    });
    try {
      final point =
          await widget.controller.locationService.captureCurrentPosition();
      if (mounted) {
        setState(() {
          _latController.text = point.latitude.toStringAsFixed(6);
          _lngController.text = point.longitude.toStringAsFixed(6);
          _locationSource = LocationSource.gps;
          _isCapturingGps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationSource = LocationSource.manual;
          _isCapturingGps = false;
          _error = 'GPS unavailable. Enter coordinates manually.';
        });
      }
    }
  }

  Future<void> _saveWaypoint() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      setState(() => _error = 'Enter valid numeric coordinates.');
      return;
    }

    if (lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be between -90 and 90.');
      return;
    }
    if (lng < -180 || lng > 180) {
      setState(() => _error = 'Longitude must be between -180 and 180.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final waypoint = Waypoint(
      id: newWaypointId(),
      sessionId: widget.controller.currentSession!.sessionId,
      type: _selectedType,
      latitude: lat,
      longitude: lng,
      locationSource: _locationSource,
      timestamp: DateTime.now(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      photoReference: _photoReference,
    );

    final success = await widget.controller.addWaypoint(waypoint);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waypoint saved successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _error = widget.controller.error ?? 'Failed to save. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Waypoint'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Waypoint Type selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waypoint Type',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: WaypointType.values.map((type) {
                          final selected = _selectedType == type;
                          return ChoiceChip(
                            label: Text(type.label),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedType = type),
                            selectedColor: colors.primaryContainer,
                            labelStyle: TextStyle(
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            avatar: Icon(
                              _typeIcon(type),
                              size: 18,
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface.withValues(alpha: 0.6),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Location',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Location source badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _locationSource == LocationSource.gps
                                  ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _locationSource == LocationSource.gps
                                    ? const Color(0xFF2E7D32)
                                    : Colors.orange,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _locationSource == LocationSource.gps
                                      ? Icons.gps_fixed
                                      : Icons.edit_location_alt,
                                  size: 14,
                                  color:
                                      _locationSource == LocationSource.gps
                                          ? const Color(0xFF2E7D32)
                                          : Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _locationSource == LocationSource.gps
                                      ? 'GPS'
                                      : 'Manual',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _locationSource == LocationSource.gps
                                            ? const Color(0xFF2E7D32)
                                            : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isCapturingGps)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Acquiring GPS fix…'),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Latitude
                        TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            hintText: 'e.g. 6.9271',
                            prefixIcon: Icon(Icons.north),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*$'),
                            ),
                          ],
                          onChanged: (_) {
                            if (_locationSource != LocationSource.manual) {
                              setState(
                                  () => _locationSource = LocationSource.manual);
                            }
                          },
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Latitude is required.';
                            }
                            final v = double.tryParse(val.trim());
                            if (v == null || !v.isFinite) {
                              return 'Enter a valid number.';
                            }
                            if (v < -90 || v > 90) {
                              return 'Must be between -90 and 90.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Longitude
                        TextFormField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            hintText: 'e.g. 79.8612',
                            prefixIcon: Icon(Icons.east),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*$'),
                            ),
                          ],
                          onChanged: (_) {
                            if (_locationSource != LocationSource.manual) {
                              setState(
                                  () => _locationSource = LocationSource.manual);
                            }
                          },
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Longitude is required.';
                            }
                            final v = double.tryParse(val.trim());
                            if (v == null || !v.isFinite) {
                              return 'Enter a valid number.';
                            }
                            if (v < -180 || v > 180) {
                              return 'Must be between -180 and 180.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // GPS Retry button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _captureGps,
                            icon: const Icon(Icons.gps_fixed, size: 16),
                            label: const Text('Retry GPS'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notes section (optional)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes (Optional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'Describe what you observed…',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Photo section (optional)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo (Optional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Photo attachment - uses a reference string.
                          // In production this would open image_picker.
                          setState(() {
                            _photoReference =
                                'photo_${DateTime.now().millisecondsSinceEpoch}';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Photo capture simulated. '
                                'In production, this opens the device camera.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          _photoReference != null
                              ? 'Photo attached ✓'
                              : 'Attach Photo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Error display
              if (_error != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveWaypoint,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving…' : 'Save Waypoint'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(WaypointType type) {
    switch (type) {
      case WaypointType.animalSighting:
        return Icons.pets;
      case WaypointType.evidence:
        return Icons.search;
      case WaypointType.trailMarker:
        return Icons.flag;
      case WaypointType.waterSource:
        return Icons.water_drop;
      case WaypointType.other:
        return Icons.more_horiz;
    }
  }
}
