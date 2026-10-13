import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_report_repository.dart';
import '../application/incident_location_service.dart';
import '../application/incident_photo_service.dart';
import 'manual_location_dialog.dart';
import 'incident_location_map.dart';
import '../application/conflict_photo_settings.dart';

enum _PhotoChoice { camera, gallery }

class ConflictReportFormScreen extends StatefulWidget {
  const ConflictReportFormScreen({
    super.key,
    required this.repository,
    this.locationService,
    this.photoService,
    this.mapTileProvider,
  });
  final ConflictReportRepository repository;
  final IncidentLocationService? locationService;
  final IncidentPhotoService? photoService;
  final TileProvider? mapTileProvider;

  @override
  State<ConflictReportFormScreen> createState() =>
      _ConflictReportFormScreenState();
}

class _ConflictReportFormScreenState extends State<ConflictReportFormScreen> {
  WildlifeType? wildlife;
  ConflictType? conflict;
  String location = '';
  double? latitude;
  double? longitude;
  String? locationError;
  bool locating = false;
  bool pickingPhoto = false;
  IncidentPhoto? photo;
  final formKey = GlobalKey<FormState>();
  bool get hasPhoto => photo != null;
  bool submitting = false;
  late final locationService =
      widget.locationService ?? DeviceIncidentLocationService();
  late final photoService = widget.photoService ?? DeviceIncidentPhotoService();
  final description = TextEditingController();

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final result = await showDialog<ManualIncidentLocation>(
      context: context,
      builder: (context) => ManualLocationDialog(
        description: location.startsWith('Current Location')
            ? ''
            : location.replaceFirst(RegExp(r' \(manual\)$'), ''),
        latitude: latitude,
        longitude: longitude,
        tileProvider: widget.mapTileProvider,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      location = '${result.description} (manual)';
      latitude = result.latitude;
      longitude = result.longitude;
      locationError = null;
    });
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, _PhotoChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() => pickingPhoto = true);
    try {
      final selectedPhoto = await photoService.select(
        choice == _PhotoChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (!mounted || selectedPhoto == null) return;
      setState(() {
        photo = selectedPhoto;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        _message('Photo picker unavailable: ${error.message ?? error.code}');
      }
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) {
        _message('Could not select a photo. Try again or submit without it.');
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _useCurrentLocation() async {
    if (locating) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final position = await locationService.currentLocation();
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        location = position.accuracy == null
            ? 'Current Location (GPS)'
            : 'Current Location (GPS, ±${position.accuracy!.round()} m)';
      });
    } on LocationUnavailable catch (error) {
      if (mounted) setState(() => locationError = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => locationError =
              'Could not get GPS. Try again or enter coordinates manually.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _submit() async {
    if (submitting || locating || pickingPhoto) return;
    final valid = formKey.currentState!.validate();
    if (latitude == null || longitude == null || location.isEmpty) {
      setState(
        () => locationError =
            'Use GPS or enter the incident location and coordinates.',
      );
      return;
    }
    if (!valid) return;
    setState(() => submitting = true);
    try {
      final report = await widget.repository.create(
        wildlifeType: wildlife!,
        conflictType: conflict!,
        description: description.text,
        latitude: latitude!,
        longitude: longitude!,
        locationDescription: location,
        photoPath: photo?.name,
        photoBytes: photo?.bytes,
        photoContentType: photo?.contentType,
      );
      // Saving is the foreground guarantee. Sending can continue while the
      // confirmation screen observes acknowledgement, failure, or retry.
      unawaited(widget.repository.sync(report));
      if (!mounted) return;
      await Navigator.pushReplacementNamed(
        context,
        '/conflict/confirmation',
        arguments: widget.repository.current(report),
      );
    } on Object {
      if (mounted) {
        _message(
          'Could not save your report. Your entries are kept; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Report Conflict',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us what happened',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Add the incident details and location. A photo is optional.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'CONFLICT TYPE'),
              DropdownButtonFormField<ConflictType>(
                initialValue: conflict,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    value == null ? 'Select a conflict type' : null,
                decoration: InputDecoration(
                  hintText: 'Select conflict type',
                  prefixIcon: Icon(
                    Icons.campaign_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                items: ConflictType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => conflict = value),
              ),
              const SizedBox(height: 14),
              _sectionLabel(context, 'WILDLIFE TYPE'),
              DropdownButtonFormField<WildlifeType>(
                initialValue: wildlife,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    value == null ? 'Select a wildlife type' : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.pets_outlined),
                  hintText: 'Select wildlife type',
                ),
                items: WildlifeType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => wildlife = value),
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'INCIDENT LOCATION'),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      tileColor: Theme.of(context).colorScheme.primaryContainer,
                      leading: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        location.isEmpty
                            ? 'Choose incident location'
                            : location,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: location.isEmpty
                          ? const Text('Use GPS or choose a point on the map.')
                          : Text(
                              location.endsWith('(manual)')
                                  ? 'Manually selected • confirm the incident position'
                                  : 'GPS location • confirm the incident position',
                            ),
                      trailing: TextButton(
                        onPressed: submitting || locating
                            ? null
                            : _chooseLocation,
                        child: const Text('Change'),
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      _LocationPreview(
                        latitude: latitude!,
                        longitude: longitude!,
                        tileProvider: widget.mapTileProvider,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No incident coordinates selected.'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: submitting || locating ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  locating ? 'Getting location...' : 'Use Current Location',
                ),
              ),
              if (locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    locationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _sectionLabel(context, 'DESCRIPTION'),
              TextFormField(
                controller: description,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Describe the incident'
                    : null,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened and when...',
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel(context, 'PHOTO (OPTIONAL)'),
              Text(
                ConflictPhotoSettings.enabled
                    ? 'Photos are saved on this device and securely uploaded when the report is sent. Only the reporter and authorized CLOs can view them.'
                    : 'Photos are saved on this device. Cloud photo delivery is not enabled on the current free-plan setup.',
              ),
              const SizedBox(height: 8),
              if (hasPhoto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    photo!.bytes,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    semanticLabel: 'Selected incident photo',
                    errorBuilder: (context, error, stack) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Preview unavailable. Change or remove this photo.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: submitting || pickingPhoto ? null : _pickPhoto,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Change Photo'),
                    ),
                    TextButton.icon(
                      onPressed: submitting || pickingPhoto
                          ? null
                          : () => setState(() => photo = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Photo'),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: submitting || pickingPhoto ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    pickingPhoto ? 'Opening photos...' : '+ Add Photo',
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: submitting || locating || pickingPhoto
                    ? null
                    : _submit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  submitting ? 'Saving report...' : 'Submit Conflict Report',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: .35,
      ),
    ),
  );
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({
    required this.latitude,
    required this.longitude,
    this.tileProvider,
  });
  final double latitude;
  final double longitude;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IncidentLocationMap(
        latitude: latitude,
        longitude: longitude,
        tileProvider: tileProvider,
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}',
        ),
      ),
    ],
  );
}
