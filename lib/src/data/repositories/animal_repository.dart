import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/animal.dart';

/// Repository interface for Animal operations.
///
/// Provides dependency inversion for testability - domain logic depends on
/// this interface, not concrete Firestore implementation.
abstract class AnimalRepository {
  /// Get animal by ID
  Future<Animal?> getById(String animalId);

  /// Update animal's current location
  Future<void> updateCurrentLocation(String animalId, AnimalLocation location);

  /// Get all animals (optional method for admin/debug)
  Future<List<Animal>> getAll();
}

/// Firestore implementation of AnimalRepository.
///
/// Uses cloud_firestore for persistence with animals collection.
class FirestoreAnimalRepository implements AnimalRepository {
  final FirebaseFirestore _firestore;

  FirestoreAnimalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Animal?> getById(String animalId) async {
    try {
      final doc = await _firestore
          .collection(Animal.collectionName)
          .doc(animalId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Animal.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get animal $animalId: $e');
    }
  }

  @override
  Future<void> updateCurrentLocation(
    String animalId,
    AnimalLocation location,
  ) async {
    try {
      await _firestore.collection(Animal.collectionName).doc(animalId).update({
        'currentLocation': location.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to update location for animal $animalId: $e');
    }
  }

  @override
  Future<List<Animal>> getAll() async {
    try {
      final snapshot = await _firestore.collection(Animal.collectionName).get();

      return snapshot.docs.map((doc) {
        return Animal.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all animals: $e');
    }
  }
}
