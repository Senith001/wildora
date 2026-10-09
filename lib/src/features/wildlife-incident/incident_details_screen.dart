import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'data/incident_report.dart';
import 'incident_widgets.dart';

class IncidentDetailsScreen extends StatefulWidget {
  const IncidentDetailsScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onNext,
  });
  final IncidentDraft draft;
  final VoidCallback onBack;
  final VoidCallback onNext;
  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  final _key = GlobalKey<FormState>();
  bool _picking = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image == null) return;
      final photo = await readIncidentPhoto(image);
      if (mounted) setState(() => widget.draft.photos.add(photo));
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to add photo: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _dateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.draft.occurredAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.draft.occurredAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      setState(() => _error = 'Incident time cannot be in the future.');
      return;
    }
    setState(() {
      widget.draft.occurredAt = selected;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => IncidentPage(
    title: 'Report Incident',
    step: 3,
    onBack: _picking ? null : widget.onBack,
    footer: Row(
      children: [
        Expanded(
          child: IncidentActionButton(
            label: 'Back',
            filled: false,
            onPressed: _picking ? null : widget.onBack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IncidentActionButton(
            label: 'Next',
            onPressed: _picking
                ? null
                : () {
                    if (_key.currentState!.validate()) widget.onNext();
                  },
          ),
        ),
      ],
    ),
    children: [
      Text('Incident Details', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Provide more information about the incident.'),
      const SizedBox(height: 20),
      const Text('Add Photos (optional, up to 3)'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < widget.draft.photos.length; i++)
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        widget.draft.photos[i].bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      tooltip: 'Remove photo',
                      onPressed: _picking
                          ? null
                          : () =>
                                setState(() => widget.draft.photos.removeAt(i)),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (widget.draft.photos.length < 3)
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _picking ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Add Photo'),
            ),
            OutlinedButton.icon(
              onPressed: _picking ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
          ],
        ),
      if (_picking) const LinearProgressIndicator(),
      const SizedBox(height: 20),
      Form(
        key: _key,
        child: TextFormField(
          initialValue: widget.draft.description,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText:
                'Describe what you observed, people involved and the animal’s condition.',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => widget.draft.description = value,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Describe the incident.'
              : null,
        ),
      ),
      const SizedBox(height: 12),
      ListTile(
        leading: const Icon(Icons.calendar_today, color: incidentGreen),
        title: const Text('Date and Time'),
        subtitle: Text(
          '${MaterialLocalizations.of(context).formatMediumDate(widget.draft.occurredAt)}, ${TimeOfDay.fromDateTime(widget.draft.occurredAt).format(context)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _picking ? null : _dateTime,
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.red)),
    ],
  );
}

Future<IncidentPhoto> readIncidentPhoto(XFile image) async {
  final bytes = await image.readAsBytes();
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Choose an image smaller than 5 MB.');
  }
  // Detect image content rather than trusting a filename or browser MIME type.
  String? contentType;
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    contentType = 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
    contentType = 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    contentType = 'image/webp';
  }
  if (contentType == null) {
    throw const FormatException('Choose a JPEG, PNG or WebP image.');
  }
  return IncidentPhoto(bytes: bytes, contentType: contentType);
}
