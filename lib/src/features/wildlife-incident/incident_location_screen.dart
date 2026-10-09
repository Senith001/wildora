import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'data/incident_report.dart';
import 'data/incident_location_service.dart';
import 'incident_widgets.dart';
import 'incident_location_map.dart';

class IncidentLocationScreen extends StatefulWidget {
  const IncidentLocationScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onNext,
    this.captureLocation,
    this.tileProvider,
  });
  final IncidentDraft draft;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final Future<Position> Function()? captureLocation;
  final TileProvider? tileProvider;
  @override
  State<IncidentLocationScreen> createState() => _IncidentLocationScreenState();
}

class _IncidentLocationScreenState extends State<IncidentLocationScreen> {
  bool _capturing = false;
  String? _error;
  double? _accuracy;

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final position =
          await (widget.captureLocation ?? IncidentLocationService().capture)();
      if (!mounted) return;
      setState(() {
        widget.draft.latitude = position.latitude;
        widget.draft.longitude = position.longitude;
        widget.draft.locationName = '';
        _accuracy = position.accuracy;
      });
    } catch (error) {
      if (mounted) {
        final message = locationFailureMessage(error);
        setState(() => _error = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _manual() async {
    final latitude = TextEditingController(
      text: widget.draft.latitude?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: widget.draft.longitude?.toString() ?? '',
    );
    final name = TextEditingController(text: widget.draft.locationName);
    final key = GlobalKey<FormState>();
    final coordinates = await showDialog<(double, double, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (-90 to 90)',
                  ),
                  validator: (text) => _coordinateError(text, 90),
                ),
                TextFormField(
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (-180 to 180)',
                  ),
                  validator: (text) => _coordinateError(text, 180),
                ),
                TextFormField(
                  controller: name,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Place / nearby landmark (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, (
                  double.parse(latitude.text.trim()),
                  double.parse(longitude.text.trim()),
                  name.text.trim(),
                ));
              }
            },
            child: const Text('Save Location'),
          ),
        ],
      ),
    );
    // Allow the dialog's closing animation to finish before disposing its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    latitude.dispose();
    longitude.dispose();
    name.dispose();
    if (coordinates != null && mounted) {
      setState(() {
        widget.draft.latitude = coordinates.$1;
        widget.draft.longitude = coordinates.$2;
        widget.draft.locationName = coordinates.$3;
        _accuracy = null;
        _error = null;
      });
    }
  }

  String? _coordinateError(String? text, double limit) {
    final value = double.tryParse(text?.trim() ?? '');
    return value == null || !value.isFinite || value < -limit || value > limit
        ? 'Enter a number between -$limit and $limit.'
        : null;
  }

  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Report Incident',
    step: 2,
    onBack: _capturing ? null : widget.onBack,
    footer: Row(
      children: [
        Expanded(
          child: IncidentActionButton(
            label: 'Back',
            filled: false,
            onPressed: _capturing ? null : widget.onBack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IncidentActionButton(
            label: 'Next',
            onPressed: _capturing || widget.draft.latitude == null
                ? null
                : widget.onNext,
          ),
        ),
      ],
    ),
    children: [
      Text('Incident Location', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Capture the location where the incident occurred.'),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      const SizedBox(height: 24),
      if (widget.draft.latitude != null && widget.draft.longitude != null)
        IncidentLocationMap(
          latitude: widget.draft.latitude!,
          longitude: widget.draft.longitude!,
          accuracy: _accuracy,
          tileProvider: widget.tileProvider,
          onLocationChanged: (latitude, longitude) {
            if (!mounted) return;
            setState(() {
              widget.draft.latitude = latitude;
              widget.draft.longitude = longitude;
              widget.draft.locationName = '';
              _accuracy = null;
              _error = null;
            });
          },
        )
      else
        Container(
          height: 250,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEAD8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 56, color: incidentGreen),
              SizedBox(height: 8),
              Text('Capture your location to show it on the map'),
            ],
          ),
        ),
      if (widget.draft.latitude != null) ...[
        const SizedBox(height: 12),
        SelectableText(
          '${widget.draft.latitude!.toStringAsFixed(6)}, ${widget.draft.longitude!.toStringAsFixed(6)}',
        ),
        if (_accuracy != null && _accuracy!.isFinite)
          Text('GPS accuracy: ±${_accuracy!.toStringAsFixed(0)} m'),
        if (widget.draft.locationName.isNotEmpty)
          Text(widget.draft.locationName),
      ],
      const SizedBox(height: 12),
      const Text(
        'Drag the map to move the pin, or tap anywhere on the map to choose a new point.',
        style: TextStyle(color: Color(0xFF365C50), fontSize: 12),
      ),
      const SizedBox(height: 16),
      IncidentActionButton(
        label: _capturing ? 'Capturing Location…' : 'Capture Current Location',
        onPressed: _capturing ? null : _capture,
      ),
      const SizedBox(height: 24),
      const Text('GPS not working?'),
      const SizedBox(height: 8),
      IncidentActionButton(
        label: 'Enter Location Manually',
        filled: false,
        onPressed: _capturing ? null : _manual,
      ),
    ],
  );
}
