import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

const maxIncidentPhotoBytes = 5 * 1024 * 1024;

const incidentTypes = <String, String>{
  'Poaching Activity':
      'Evidence or suspicion of illegal hunting, trapping or wildlife trade',
  'Injured Wildlife': 'Wild animal found injured or in distress',
  'Dead Wildlife': 'Wild animal found dead',
  'Human-Wildlife Conflict': 'Conflict between humans and wildlife',
  'Other': 'Other wildlife related incident',
};

String newIncidentId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

enum IncidentSyncStatus { pending, failed, synchronized }

class IncidentPhoto {
  const IncidentPhoto({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;

  String toFirestoreDataUri() =>
      'data:$contentType;base64,${base64Encode(bytes)}';

  static Uint8List decodeFirestoreDataUri(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('data:')) {
      throw const FormatException(
        'Only Firestore data URIs can be decoded here.',
      );
    }
    final separatorIndex = trimmed.indexOf(',');
    if (separatorIndex == -1) {
      throw const FormatException('Invalid photo data URI.');
    }
    final encoded = trimmed.substring(separatorIndex + 1);
    if (encoded.isEmpty) {
      throw const FormatException('Photo payload is empty.');
    }
    return base64Decode(encoded);
  }

  Map<String, dynamic> toLocalMap() => {
    'bytes': bytes,
    'contentType': contentType,
  };
  factory IncidentPhoto.fromLocalMap(Map<dynamic, dynamic> map) =>
      IncidentPhoto(
        bytes: Uint8List.fromList(List<int>.from(map['bytes'] as List)),
        contentType: map['contentType'] as String,
      );
}

Uint8List decodeIncidentPhotoDataUri(String value) =>
    IncidentPhoto.decodeFirestoreDataUri(value);

class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.reporterId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.description,
    required this.occurredAt,
    required this.createdAt,
    this.photos = const [],
    this.photoUrls = const [],
    this.status = IncidentSyncStatus.pending,
    this.error,
  });

  final String id;
  // Installation identity: the existing app has no officer login flow yet.
  final String reporterId;
  final String type;
  final double latitude;
  final double longitude;
  final String locationName;
  final String description;
  final DateTime occurredAt;
  final DateTime createdAt;
  final List<IncidentPhoto> photos;
  final List<String> photoUrls;
  final IncidentSyncStatus status;
  final String? error;

  IncidentReport withSync(
    IncidentSyncStatus status, {
    List<String>? photoUrls,
    String? error,
  }) => IncidentReport(
    id: id,
    reporterId: reporterId,
    type: type,
    latitude: latitude,
    longitude: longitude,
    locationName: locationName,
    description: description,
    occurredAt: occurredAt,
    createdAt: createdAt,
    photos: status == IncidentSyncStatus.synchronized ? const [] : photos,
    photoUrls: photoUrls ?? this.photoUrls,
    status: status,
    error: error,
  );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'reporterId': reporterId,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'locationName': locationName,
    'description': description,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'photos': photos.map((photo) => photo.toLocalMap()).toList(),
    'photoUrls': photoUrls,
    'status': status.name,
    'error': error,
  };

  factory IncidentReport.fromLocalMap(Map<dynamic, dynamic> map) =>
      IncidentReport(
        id: map['id'] as String,
        reporterId: map['reporterId'] as String,
        type: map['type'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        locationName: map['locationName'] as String,
        description: map['description'] as String,
        occurredAt: DateTime.parse(map['occurredAt'] as String).toLocal(),
        createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
        photos: (map['photos'] as List)
            .map((photo) => IncidentPhoto.fromLocalMap(photo as Map))
            .toList(),
        photoUrls: List<String>.from(map['photoUrls'] as List),
        status: IncidentSyncStatus.values.byName(map['status'] as String),
        error: map['error'] as String?,
      );
}

class IncidentDraft {
  String? type;
  double? latitude;
  double? longitude;
  String locationName = '';
  String description = '';
  DateTime occurredAt = DateTime.now();
  final List<IncidentPhoto> photos = [];

  String? validate() {
    if (locationName.trim().length > 200) {
      return 'Keep the location name under 200 characters.';
    }
    if (!incidentTypes.containsKey(type)) return 'Choose an incident type.';
    if (latitude == null ||
        longitude == null ||
        !latitude!.isFinite ||
        !longitude!.isFinite ||
        latitude! < -90 ||
        latitude! > 90 ||
        longitude! < -180 ||
        longitude! > 180) {
      return 'Capture a location or enter valid coordinates.';
    }
    if (description.trim().isEmpty || description.trim().length > 500) {
      return 'Enter a description between 1 and 500 characters.';
    }
    if (occurredAt.isAfter(DateTime.now())) {
      return 'Incident time cannot be in the future.';
    }
    if (photos.length > 3 ||
        photos.any(
          (photo) =>
              photo.bytes.isEmpty || photo.bytes.length > maxIncidentPhotoBytes,
        )) {
      return 'Use up to 3 photos, each no larger than 5 MB.';
    }
    if (photos.any(
      (photo) => ![
        'image/jpeg',
        'image/png',
        'image/webp',
      ].contains(photo.contentType),
    )) {
      return 'Use JPEG, PNG or WebP photos.';
    }
    return null;
  }

  IncidentReport toReport(String reporterId) {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    return IncidentReport(
      id: newIncidentId(),
      reporterId: reporterId,
      type: type!,
      latitude: latitude!,
      longitude: longitude!,
      locationName: locationName.trim(),
      description: description.trim(),
      occurredAt: occurredAt,
      createdAt: DateTime.now(),
      photos: List.unmodifiable(photos),
    );
  }
}
