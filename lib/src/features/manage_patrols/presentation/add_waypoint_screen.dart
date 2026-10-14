import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Screen 3: Add Waypoint
///
/// Tactical field entry screen to log observations, sightings, water sources,
/// markers, or evidence during an active patrol with GPS or manual coordinates,
/// optional notes, and optional photo reference.
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
    final recent = widget.controller.latestRecentFix;
    if (recent != null) {
      _latController.text = recent.latitude.toStringAsFixed(6);
      _lngController.text = recent.longitude.toStringAsFixed(6);
      _locationSource = LocationSource.gps;
    }
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
          _error = 'GPS fix unavailable. Please input coordinates manually.';
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
            content: Text('Waypoint recorded to local patrol storage!'),
            backgroundColor: PatrolTheme.forestPrimary,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _error = widget.controller.error ?? 'Failed to save waypoint. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolTheme.background,
      appBar: AppBar(
        title: const Text('Add Waypoint'),
        backgroundColor: PatrolTheme.forestDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ResponsiveContentWrapper(
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Waypoint Type Selector ───────────────────────────────
                  OperationalCard(
                    title: 'Waypoint Type',
                    icon: Icons.category_outlined,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WaypointType.values.map((type) {
                        final selected = _selectedType == type;
                        return ChoiceChip(
                          label: Text(type.label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedType = type),
                          selectedColor: PatrolTheme.forestPrimary,
                          backgroundColor: PatrolTheme.surfaceElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: PatrolTheme.radiusFull,
                            side: BorderSide(
                              color: selected
                                  ? PatrolTheme.forestPrimary
                                  : PatrolTheme.borderLight,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : PatrolTheme.charcoal,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          avatar: Icon(
                            _typeIcon(type),
                            size: 16,
                            color: selected
                                ? Colors.white
                                : PatrolTheme.forestPrimary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Spatial Coordinates & Source ──────────────────────────
                  OperationalCard(
                    title: 'Spatial Location Coordinates',
                    icon: Icons.pin_drop_outlined,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _locationSource == LocationSource.gps
                            ? PatrolTheme.successSurface
                            : PatrolTheme.amberSurface,
                        borderRadius: PatrolTheme.radiusFull,
                        border: Border.all(
                          color: _locationSource == LocationSource.gps
                              ? PatrolTheme.successBorder
                              : PatrolTheme.amberBorder,
                        ),
                      ),
                      child: Text(
                        _locationSource == LocationSource.gps
                            ? 'GPS ACTIVE'
                            : 'MANUAL ENTRY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _locationSource == LocationSource.gps
                              ? PatrolTheme.success
                              : PatrolTheme.amberDark,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isCapturingGps)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: PatrolTheme.surfaceElevated,
                              borderRadius: PatrolTheme.radiusSm,
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: PatrolTheme.forestPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Acquiring GPS fix coordinates…',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: PatrolTheme.charcoalMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          // Latitude input
                          TextFormField(
                            controller: _latController,
                            decoration: InputDecoration(
                              labelText: 'Latitude (-90.0 to +90.0)',
                              hintText: 'e.g. 6.927150',
                              prefixIcon: const Icon(Icons.north,
                                  size: 18, color: PatrolTheme.forestPrimary),
                              filled: true,
                              fillColor: PatrolTheme.surfaceElevated,
                              border: OutlineInputBorder(
                                borderRadius: PatrolTheme.radiusSm,
                                borderSide: const BorderSide(
                                    color: PatrolTheme.borderLight),
                              ),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
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
                                setState(() =>
                                    _locationSource = LocationSource.manual);
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

                          // Longitude input
                          TextFormField(
                            controller: _lngController,
                            decoration: InputDecoration(
                              labelText: 'Longitude (-180.0 to +180.0)',
                              hintText: 'e.g. 79.861200',
                              prefixIcon: const Icon(Icons.east,
                                  size: 18, color: PatrolTheme.forestPrimary),
                              filled: true,
                              fillColor: PatrolTheme.surfaceElevated,
                              border: OutlineInputBorder(
                                borderRadius: PatrolTheme.radiusSm,
                                borderSide: const BorderSide(
                                    color: PatrolTheme.borderLight),
                              ),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
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
                                setState(() =>
                                    _locationSource = LocationSource.manual);
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

                          // GPS Reload button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _captureGps,
                                icon: const Icon(Icons.gps_fixed, size: 16),
                                label: const Text('Refresh GPS Position'),
                                style: TextButton.styleFrom(
                                  foregroundColor: PatrolTheme.forestPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Field Notes ──────────────────────────────────────────
                  OperationalCard(
                    title: 'Field Observation Notes',
                    icon: Icons.notes_outlined,
                    child: TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText:
                            'Provide observational details, species identifier, snare condition, or hazard remarks…',
                        filled: true,
                        fillColor: PatrolTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: PatrolTheme.radiusSm,
                          borderSide:
                              const BorderSide(color: PatrolTheme.borderLight),
                        ),
                      ),
                      maxLines: 3,
                      maxLength: 500,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Photographic Evidence Reference ──────────────────────
                  OperationalCard(
                    title: 'Photographic Evidence (Optional)',
                    icon: Icons.camera_alt_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_photoReference != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PatrolTheme.forestSurface,
                              borderRadius: PatrolTheme.radiusSm,
                              border:
                                  Border.all(color: PatrolTheme.forestBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: PatrolTheme.forestPrimary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Reference: ${_photoReference!}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: PatrolTheme.charcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remove photo',
                                  onPressed: () =>
                                      setState(() => _photoReference = null),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _photoReference =
                                  'IMG_PATROL_${DateTime.now().millisecondsSinceEpoch}';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Camera capture simulated. Photographic evidence attached.'),
                                backgroundColor: PatrolTheme.forestPrimary,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PatrolTheme.forestPrimary,
                            side: const BorderSide(
                                color: PatrolTheme.forestBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: PatrolTheme.radiusSm,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: Text(_photoReference != null
                              ? 'Replace Photo'
                              : 'Attach Photo'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Inline Error Banner ──────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PatrolTheme.errorSurface,
                        borderRadius: PatrolTheme.radiusSm,
                        border: Border.all(color: PatrolTheme.errorBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: PatrolTheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: PatrolTheme.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 10),

                  // ─── Action Buttons ───────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PatrolTheme.charcoal,
                              shape: RoundedRectangleBorder(
                                borderRadius: PatrolTheme.radiusMd,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveWaypoint,
                            style: FilledButton.styleFrom(
                              backgroundColor: PatrolTheme.forestPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: PatrolTheme.radiusMd,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 20),
                            label: Text(
                                _isSaving ? 'Saving…' : 'Save Waypoint'),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
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
