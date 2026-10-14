import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/officer.dart';
import '../application/patrol_controller.dart';
import '../data/patrol_assignment_repository.dart';
import '../data/patrol_auth_service.dart';
import '../data/patrol_local_store.dart';
import '../data/patrol_models.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Screen for authorized Park Managers / Administrators to design and assign
/// field patrol routes to registered rangers.
///
/// Features:
/// - Select actual registered rangers from the official database.
/// - Interactive map route definition (tap to add ordered checkpoints).
/// - Fallback manual coordinate entry dialog for each checkpoint.
/// - Auto-calculated planned distance using Haversine formula.
/// - Durably saved to Cloud Firestore and cached locally.
class AssignPatrolScreen extends StatefulWidget {
  const AssignPatrolScreen({
    super.key,
    this.controller,
    this.assignmentRepository,
    this.authService,
  });

  final PatrolController? controller;
  final PatrolAssignmentRepository? assignmentRepository;
  final PatrolAuthService? authService;

  @override
  State<AssignPatrolScreen> createState() => _AssignPatrolScreenState();
}

class _AssignPatrolScreenState extends State<AssignPatrolScreen> {
  PatrolAssignmentRepository get _assignmentRepo {
    if (widget.assignmentRepository != null) return widget.assignmentRepository!;
    if (widget.controller != null) return widget.controller!.assignmentRepository;
    return FirestorePatrolAssignmentRepository(localStore: HivePatrolLocalStore());
  }

  PatrolAuthService get _authService {
    if (widget.authService != null) return widget.authService!;
    if (widget.controller != null) return widget.controller!.authService;
    return FirebasePatrolAuthService();
  }
  final _formKey = GlobalKey<FormState>();
  final _routeNameController = TextEditingController();
  final _areaController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final MapController _mapController = MapController();

  List<Officer> _registeredRangers = [];
  Officer? _selectedRanger;
  final List<PatrolCheckpoint> _checkpoints = [];
  DateTime _assignedDate = DateTime.now();

  bool _isLoadingRangers = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Default focus: Yala National Park, Sri Lanka
  static const LatLng _initialMapCenter = LatLng(6.3685, 81.5175);

  @override
  void initState() {
    super.initState();
    _routeNameController.text = 'Sector 04 Perimeter Patrol';
    _areaController.text = 'Yala National Park • Buffer Zone';
    _durationController.text = '120';
    _loadRangers();
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _areaController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRangers() async {
    setState(() => _isLoadingRangers = true);
    try {
      final rangers = await _authService.getRegisteredRangers();
      if (mounted) {
        setState(() {
          _registeredRangers = rangers;
          if (rangers.isNotEmpty) {
            _selectedRanger = rangers.first;
          }
          _isLoadingRangers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRangers = false;
          _errorMessage = 'Could not load rangers: $e';
        });
      }
    }
  }

  void _addCheckpointAt(LatLng point) {
    setState(() {
      final order = _checkpoints.length + 1;
      _checkpoints.add(PatrolCheckpoint(
        order: order,
        latitude: point.latitude,
        longitude: point.longitude,
        label: 'CP-$order',
      ));
      _recalculatePlannedDistance();
    });
  }

  void _removeCheckpoint(int index) {
    setState(() {
      _checkpoints.removeAt(index);
      // Re-index remaining checkpoints
      for (int i = 0; i < _checkpoints.length; i++) {
        final cp = _checkpoints[i];
        _checkpoints[i] = PatrolCheckpoint(
          order: i + 1,
          latitude: cp.latitude,
          longitude: cp.longitude,
          label: 'CP-${i + 1}',
        );
      }
      _recalculatePlannedDistance();
    });
  }

  void _clearCheckpoints() {
    setState(() {
      _checkpoints.clear();
      _distanceController.text = '0.0';
    });
  }

  void _recalculatePlannedDistance() {
    if (_checkpoints.length < 2) {
      _distanceController.text = '0.0';
      return;
    }

    double totalKm = 0.0;
    for (int i = 1; i < _checkpoints.length; i++) {
      totalKm += _haversineKm(
        _checkpoints[i - 1].latitude,
        _checkpoints[i - 1].longitude,
        _checkpoints[i].latitude,
        _checkpoints[i].longitude,
      );
    }
    _distanceController.text = totalKm.toStringAsFixed(1);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  Future<void> _showManualCoordinateDialog() async {
    final latCtrl = TextEditingController(text: '6.37000');
    final lngCtrl = TextEditingController(text: '81.52000');
    final labelCtrl =
        TextEditingController(text: 'CP-${_checkpoints.length + 1}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PatrolTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: PatrolTheme.radiusMd),
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt,
                color: PatrolTheme.forestPrimary, size: 22),
            SizedBox(width: 10),
            Text('Input Coordinates Fallback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Checkpoint Label',
                hintText: 'e.g. River Crossing Outpost',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Latitude (-90 to +90)',
                hintText: '6.3700',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Longitude (-180 to +180)',
                hintText: '81.5200',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: PatrolTheme.forestPrimary),
            child: const Text('Add Checkpoint'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final lat = double.tryParse(latCtrl.text.trim());
      final lng = double.tryParse(lngCtrl.text.trim());

      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        setState(() {
          final order = _checkpoints.length + 1;
          _checkpoints.add(PatrolCheckpoint(
            order: order,
            latitude: lat,
            longitude: lng,
            label: labelCtrl.text.trim().isEmpty ? 'CP-$order' : labelCtrl.text.trim(),
          ));
          _recalculatePlannedDistance();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid coordinates. Please enter valid ranges.'),
              backgroundColor: PatrolTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAndAssign() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRanger == null) {
      setState(() => _errorMessage = 'Please select a registered ranger.');
      return;
    }

    if (_checkpoints.length < 2) {
      setState(() => _errorMessage =
          'Please define at least 2 route checkpoints (tap the map or use manual coordinates).');
      return;
    }

    final distanceKm = double.tryParse(_distanceController.text.trim()) ?? 0.0;
    final durationMin = int.tryParse(_durationController.text.trim()) ?? 0;

    if (distanceKm <= 0) {
      setState(() => _errorMessage = 'Planned distance must be greater than 0.');
      return;
    }
    if (durationMin <= 0) {
      setState(
          () => _errorMessage = 'Estimated duration must be greater than 0.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final managerId = (await _authService.getCurrentUserId()) ?? 'manager_dispatch';
      final assignmentId = 'route_${DateTime.now().millisecondsSinceEpoch}';

      final assignment = PatrolAssignment(
        id: assignmentId,
        routeName: _routeNameController.text.trim(),
        area: _areaController.text.trim(),
        assignedRangerId: _selectedRanger!.officerId,
        assignedRangerName: _selectedRanger!.name,
        assignedByManagerId: managerId,
        checkpoints: List.from(_checkpoints),
        plannedDistanceKm: distanceKm,
        estimatedDurationMinutes: durationMin,
        assignedDate: _assignedDate,
        createdAt: DateTime.now(),
        status: PatrolAssignmentStatus.assigned,
      );

      // Save to Firebase and durable local storage
      await _assignmentRepo.saveAssignment(assignment);

      // Reload assignments in controller if provided
      if (widget.controller != null) {
        await widget.controller!.loadAssignment();
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patrol assigned to ${_selectedRanger!.name} successfully!',
            ),
            backgroundColor: PatrolTheme.forestPrimary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to assign patrol: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolTheme.background,
      appBar: AppBar(
        title: const Text('Assign Field Patrol'),
        backgroundColor: PatrolTheme.forestDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ResponsiveContentWrapper(
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Manager Authority Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: PatrolTheme.forestSurface,
                      borderRadius: PatrolTheme.radiusMd,
                      border: Border.all(color: PatrolTheme.forestBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings,
                            color: PatrolTheme.forestPrimary, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Authorized Park Manager / Dispatch Console',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PatrolTheme.forestDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Registered Ranger Selector ───────────────────────────
                  OperationalCard(
                    title: 'Assign to Registered Ranger',
                    icon: Icons.person_search_outlined,
                    child: _isLoadingRangers
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: PatrolTheme.forestPrimary),
                            ),
                          )
                        : _registeredRangers.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: PatrolTheme.amberSurface,
                                  borderRadius: PatrolTheme.radiusSm,
                                  border: Border.all(color: PatrolTheme.amber),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: PatrolTheme.amberDark, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No registered rangers found in Firestore. Please register field officers before dispatching patrols.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: PatrolTheme.amberDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<Officer>(
                                    initialValue: _selectedRanger,
                                    decoration: InputDecoration(
                                      labelText: 'Select Registered Ranger',
                                      filled: true,
                                      fillColor: PatrolTheme.surfaceElevated,
                                      border: OutlineInputBorder(
                                        borderRadius: PatrolTheme.radiusSm,
                                        borderSide: const BorderSide(
                                            color: PatrolTheme.borderLight),
                                      ),
                                    ),
                                    items: _registeredRangers.map((ranger) {
                                      return DropdownMenuItem<Officer>(
                                        value: ranger,
                                        child: Text(
                                          '${ranger.name} • ${ranger.officerId}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (officer) {
                                      setState(() => _selectedRanger = officer);
                                    },
                                  ),
                              if (_selectedRanger != null &&
                                  _selectedRanger!.contactNo != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Direct Comms: ${_selectedRanger!.contactNo}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PatrolTheme.charcoalMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Route Identity & Sector ──────────────────────────────
                  OperationalCard(
                    title: 'Route Specifications',
                    icon: Icons.route_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _routeNameController,
                          decoration: InputDecoration(
                            labelText: 'Route Name',
                            hintText: 'e.g. Yala Sector 04 Perimeter',
                            filled: true,
                            fillColor: PatrolTheme.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: PatrolTheme.radiusSm,
                              borderSide: const BorderSide(
                                  color: PatrolTheme.borderLight),
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Route name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _areaController,
                          decoration: InputDecoration(
                            labelText: 'Conservation Area / Sector',
                            hintText: 'e.g. Yala National Park • Block 1',
                            filled: true,
                            fillColor: PatrolTheme.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: PatrolTheme.radiusSm,
                              borderSide: const BorderSide(
                                  color: PatrolTheme.borderLight),
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Area or sector is required.'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Interactive Route Mapping Canvas ─────────────────────
                  OperationalCard(
                    title: 'Define Ordered Route on Map',
                    icon: Icons.map_outlined,
                    trailing: Text(
                      '${_checkpoints.length} Checkpoints',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PatrolTheme.forestPrimary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Tap anywhere on the tactical map to add ordered route checkpoints. The planned path will be mapped sequentially.',
                          style: TextStyle(
                            fontSize: 12,
                            color: PatrolTheme.charcoalMuted,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Map Box
                        SizedBox(
                          height: 250,
                          child: ClipRRect(
                            borderRadius: PatrolTheme.radiusSm,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _initialMapCenter,
                                initialZoom: 13.8,
                                onTap: (_, point) => _addCheckpointAt(point),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.wildora.wildora',
                                ),
                                if (_checkpoints.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: _checkpoints
                                            .map((cp) => LatLng(
                                                cp.latitude, cp.longitude))
                                            .toList(),
                                        color: const Color(0xFF2563EB),
                                        strokeWidth: 3.5,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: _checkpoints.map((cp) {
                                    return Marker(
                                      point: LatLng(cp.latitude, cp.longitude),
                                      width: 28,
                                      height: 28,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${cp.order}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Action Buttons: Manual Coordinate Fallback & Clear
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showManualCoordinateDialog,
                              icon: const Icon(Icons.add_location_alt, size: 16),
                              label: const Text('Add Coordinate Fallback'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PatrolTheme.forestPrimary,
                                side: const BorderSide(
                                    color: PatrolTheme.forestBorder),
                              ),
                            ),
                            const Spacer(),
                            if (_checkpoints.isNotEmpty)
                              TextButton.icon(
                                onPressed: _clearCheckpoints,
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: PatrolTheme.error),
                                label: const Text('Clear All',
                                    style: TextStyle(color: PatrolTheme.error)),
                              ),
                          ],
                        ),

                        // Checkpoint Chips
                        if (_checkpoints.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(_checkpoints.length, (idx) {
                              final cp = _checkpoints[idx];
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: const Color(0xFF2563EB),
                                  child: Text('${cp.order}',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white)),
                                ),
                                label: Text(
                                  '${cp.label} (${cp.latitude.toStringAsFixed(3)}, ${cp.longitude.toStringAsFixed(3)})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => _removeCheckpoint(idx),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Distance, Duration & Schedule ────────────────────────
                  OperationalCard(
                    title: 'Logistics & Metrics',
                    icon: Icons.speed_outlined,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _distanceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*$')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Planned Distance (km)',
                                  hintText: '8.5',
                                  filled: true,
                                  fillColor: PatrolTheme.surfaceElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: PatrolTheme.radiusSm,
                                    borderSide: const BorderSide(
                                        color: PatrolTheme.borderLight),
                                  ),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Required.'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _durationController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Est. Duration (min)',
                                  hintText: '120',
                                  filled: true,
                                  fillColor: PatrolTheme.surfaceElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: PatrolTheme.radiusSm,
                                    borderSide: const BorderSide(
                                        color: PatrolTheme.borderLight),
                                  ),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Required.'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Assignment Date Picker
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Assignment Scheduled Date',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${_assignedDate.day}/${_assignedDate.month}/${_assignedDate.year}',
                            style: const TextStyle(
                                fontSize: 13, color: PatrolTheme.charcoalMuted),
                          ),
                          trailing: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _assignedDate,
                                firstDate: DateTime.now().subtract(
                                    const Duration(days: 7)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setState(() => _assignedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Change Date'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error notification banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
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
                              _errorMessage!,
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
                  ],

                  const SizedBox(height: 20),

                  // ─── Primary Submit Button ────────────────────────────────
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveAndAssign,
                      style: FilledButton.styleFrom(
                        backgroundColor: PatrolTheme.forestPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: PatrolTheme.radiusMd,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.assignment_turned_in, size: 22),
                      label: Text(_isSaving
                          ? 'Assigning Patrol…'
                          : 'Assign Patrol Route to Ranger'),
                    ),
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
}
