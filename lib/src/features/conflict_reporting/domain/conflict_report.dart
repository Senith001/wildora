import 'dart:convert';
import 'dart:typed_data';

enum SyncStatus { pending, syncing, synced, failed }

enum ReportStatus { savedOffline, submitted, underReview, resolved }

enum WildlifeType { elephant, leopard, wildBoar, other }

enum ConflictType {
  cropRaiding,
  animalSighting,
  propertyDamage,
  threatToPeople,
  other,
}

extension ConflictLabels on Enum {
  String get label {
    switch (this) {
      case WildlifeType.elephant:
        return 'Elephant';
      case WildlifeType.leopard:
        return 'Leopard';
      case WildlifeType.wildBoar:
        return 'Wild Boar';
      case WildlifeType.other:
        return 'Other';
      case ConflictType.cropRaiding:
        return 'Crop Raiding';
      case ConflictType.animalSighting:
        return 'Animal Sighting';
      case ConflictType.propertyDamage:
        return 'Property Damage';
      case ConflictType.threatToPeople:
        return 'Threat to People';
      case ConflictType.other:
        return 'Other';
      case SyncStatus.pending:
        return 'Pending Sync';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.failed:
        return 'Sync Failed';
      case ReportStatus.savedOffline:
        return 'Saved Offline';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.resolved:
        return 'Resolved';
      default:
        return name;
    }
  }
}

/// Immutable incident snapshot. Workflow changes use [copyWith].
class ConflictReport {
  ConflictReport({
    required this.id,
    required this.referenceNumber,
    required this.wildlifeType,
    required this.conflictType,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.locationDescription,
    required this.createdAt,
    this.photoDeliveryStatus = 'none',
    this.reporterId,
    this.isDemo = false,
    this.photoPath,
    Uint8List? photoBytes,
    this.photoUrl,
    this.photoContentType,
    this.reportStatus = ReportStatus.savedOffline,
    this.syncStatus = SyncStatus.pending,
    this.responseNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.resolvedAt,
    DateTime? updatedAt,
  }) : photoBytes = photoBytes == null
           ? null
           : Uint8List.fromList(photoBytes).asUnmodifiableView(),
       updatedAt = updatedAt ?? createdAt;

  final String photoDeliveryStatus;
  final String? reporterId;
  final bool isDemo;
  final String id;
  final String referenceNumber;
  final WildlifeType wildlifeType;
  final ConflictType conflictType;
  final String description;
  final String? photoPath;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? photoContentType;
  final double latitude;
  final double longitude;
  final String locationDescription;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportStatus reportStatus;
  final SyncStatus syncStatus;
  final String? responseNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? resolvedAt;

  /// Workflow updates create a new snapshot; screens cannot mutate status.
  ConflictReport copyWith({
    bool? isDemo,
    String? photoDeliveryStatus,
    String? reporterId,
    SyncStatus? syncStatus,
    ReportStatus? reportStatus,
    String? photoUrl,
    String? responseNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) => ConflictReport(
    id: id,
    isDemo: isDemo ?? this.isDemo,
    photoDeliveryStatus: photoDeliveryStatus ?? this.photoDeliveryStatus,
    reporterId: reporterId ?? this.reporterId,
    referenceNumber: referenceNumber,
    wildlifeType: wildlifeType,
    conflictType: conflictType,
    description: description,
    latitude: latitude,
    longitude: longitude,
    locationDescription: locationDescription,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    photoPath: photoPath,
    photoBytes: photoBytes,
    photoContentType: photoContentType,
    photoUrl: photoUrl ?? this.photoUrl,
    reportStatus: reportStatus ?? this.reportStatus,
    syncStatus: syncStatus ?? this.syncStatus,
    responseNotes: responseNotes ?? this.responseNotes,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  /// Validate before storing or uploading so callers cannot bypass UI checks.
  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid report ID.');
    }
    if (description.trim().isEmpty || description.length > 500) {
      throw ArgumentError('Enter a description of 1 to 500 characters.');
    }
    if (locationDescription.trim().isEmpty ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Enter a location with valid coordinates.');
    }
    if (photoBytes != null &&
        (photoBytes!.isEmpty || photoBytes!.length > 5 * 1024 * 1024)) {
      throw ArgumentError('Choose a photo smaller than 5 MB.');
    }
  }

  Map<String, dynamic> toMap({bool includePhotoBytes = true}) => {
    'id': id,
    'isDemo': isDemo,
    'reporterId': reporterId,
    'photoDeliveryStatus': photoDeliveryStatus,
    'referenceNumber': referenceNumber,
    'wildlifeType': wildlifeType.name,
    'conflictType': conflictType.name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'locationDescription': locationDescription,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'photoPath': photoPath,
    'photoUrl': photoUrl,
    'photoContentType': photoContentType,
    if (includePhotoBytes && photoBytes != null)
      'photoBytes': base64Encode(photoBytes!),
    'reportStatus': reportStatus.name,
    'syncStatus': syncStatus.name,
    'responseNotes': responseNotes,
    'reviewedBy': reviewedBy,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory ConflictReport.fromMap(Map<String, dynamic> data) {
    DateTime? date(String key) =>
        data[key] == null ? null : DateTime.parse(data[key] as String);
    final report = ConflictReport(
      id: data['id'] as String,
      isDemo: data['isDemo'] as bool? ?? false,
      reporterId: data['reporterId'] as String?,
      photoDeliveryStatus: data['photoDeliveryStatus'] as String? ?? 'none',
      referenceNumber: data['referenceNumber'] as String,
      wildlifeType: WildlifeType.values.byName(data['wildlifeType'] as String),
      conflictType: ConflictType.values.byName(data['conflictType'] as String),
      description: data['description'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      locationDescription: data['locationDescription'] as String,
      createdAt: date('createdAt')!,
      updatedAt: date('updatedAt'),
      photoPath: data['photoPath'] as String?,
      photoUrl: data['photoUrl'] as String?,
      photoContentType: data['photoContentType'] as String?,
      photoBytes: data['photoBytes'] == null
          ? null
          : base64Decode(data['photoBytes'] as String),
      reportStatus: ReportStatus.values.byName(data['reportStatus'] as String),
      syncStatus: SyncStatus.values.byName(data['syncStatus'] as String),
      responseNotes: data['responseNotes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: date('reviewedAt'),
      resolvedAt: date('resolvedAt'),
    );
    report.validate();
    return report;
  }
}
