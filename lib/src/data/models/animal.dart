import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for Animal collection.
///
/// Schema/data model justified by the Wildora class diagram and
/// Detect High-Risk Animal Movement scenario. Persistence/repository
/// logic is NOT part of this foundation.
class Animal {
  static const String collectionName = 'animals';

  final String animalId;
  final String species;
  final String name;
  final String? collarId;
  final AnimalLocation? currentLocation;

  const Animal({
    required this.animalId,
    required this.species,
    required this.name,
    this.collarId,
    this.currentLocation,
  });

  factory Animal.fromMap(String id, Map<String, dynamic> map) {
    return Animal(
      animalId: id,
      species: map['species'] as String,
      name: map['name'] as String,
      collarId: map['collarId'] as String?,
      currentLocation: map['currentLocation'] != null
          ? AnimalLocation.fromMap(
              map['currentLocation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'animalId': animalId,
      'species': species,
      'name': name,
      'collarId': collarId,
      'currentLocation': currentLocation?.toMap(),
    };
  }
}

/// Value class for animal location data.
class AnimalLocation {
  final double latitude;
  final double longitude;
  final Timestamp timestamp;

  const AnimalLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory AnimalLocation.fromMap(Map<String, dynamic> map) {
    return AnimalLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: map['timestamp'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }
}
