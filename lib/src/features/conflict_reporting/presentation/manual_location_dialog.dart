import 'package:flutter/material.dart';

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
  });
  final String description;
  final double? latitude;
  final double? longitude;

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
    title: const Text('Enter incident location'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              'Enter coordinates for the incident, or cancel and use GPS.',
            ),
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
              validator: (v) => _coordinate(v, 90),
            ),
            TextFormField(
              controller: _longitude,
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
