import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'incident_location_map.dart';

class ManualIncidentLocation {
  const ManualIncidentLocation(this.description, this.latitude, this.longitude);
  final String description;
  final double latitude;
  final double longitude;
}

/// Owns and disposes its input controllers with the dialog's actual lifecycle.
class ManualLocationDialog extends StatefulWidget {
  const ManualLocationDialog({
    super.key,
    required this.description,
    this.latitude,
    this.longitude,
    this.tileProvider,
  });
  final String description;
  final double? latitude;
  final double? longitude;
  final TileProvider? tileProvider;

  @override
  State<ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<ManualLocationDialog> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.description);
  late final _latitude = TextEditingController(
    text: widget.latitude?.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.longitude?.toString() ?? '',
  );

  double? get _validLatitude => _coordinate(_latitude.text, 90) == null
      ? double.parse(_latitude.text.trim())
      : null;
  double? get _validLongitude => _coordinate(_longitude.text, 180) == null
      ? double.parse(_longitude.text.trim())
      : null;

  void _selectPoint(LatLng point) {
    setState(() {
      _latitude.text = point.latitude.toStringAsFixed(6);
      _longitude.text = point.longitude.toStringAsFixed(6);
      if (_label.text.trim().isEmpty) {
        _label.text = 'Selected incident location';
      }
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  String? _coordinate(String? value, double limit) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite || number.abs() > limit
        ? 'Enter a value between -$limit and $limit'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose incident location'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tap the map to place the incident pin, or enter coordinates below.',
              ),
              const SizedBox(height: 8),
              IncidentLocationMap(
                latitude: _validLatitude,
                longitude: _validLongitude,
                tileProvider: widget.tileProvider,
                onSelect: _selectPoint,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Village, road or landmark',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter a location name'
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Coordinates update when you select a point on the map.',
              ),
              TextFormField(
                controller: _latitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
                validator: (v) => _coordinate(v, 90),
              ),
              TextFormField(
                controller: _longitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
                validator: (v) => _coordinate(v, 180),
              ),
            ],
          ),
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
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              ManualIncidentLocation(
                _label.text.trim(),
                double.parse(_latitude.text.trim()),
                double.parse(_longitude.text.trim()),
              ),
            );
          }
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}
