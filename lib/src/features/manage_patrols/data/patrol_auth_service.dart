import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models/officer.dart';
import '../../../data/repositories/officer_repository.dart';

/// Contract for patrol authentication and role authorization.
///
/// Follows Single Responsibility and Principle of Least Privilege:
/// - Authenticates via real Firebase Authentication credentials.
/// - Obtains role authority from server-controlled sources (custom claims or verified officer record).
/// - Distinguishes Park Manager / Admin vs Field Ranger.
/// - Strictly prevents unauthorized users from granting themselves manager privileges.
abstract class PatrolAuthService {
  /// Current authenticated user ID, or null if signed out.
  String? get currentUserId;

  /// Get current user UID (or null if unauthenticated).
  Future<String?> getCurrentUserId();

  /// Get verified user display name or email.
  Future<String> getCurrentUserName();

  /// Get verified role ('manager', 'admin', 'ranger'), or null if unauthenticated.
  Future<String?> getCurrentRole();

  /// Check whether current authenticated user has manager/admin privileges.
  Future<bool> isParkManager();

  /// Check if an authenticated user session is active.
  Future<bool> isSignedIn();

  /// Retrieve all registered field rangers from the database.
  Future<List<Officer>> getRegisteredRangers();

  /// Sign in with email and password using Firebase Authentication.
  Future<void> signInWithEmail(String email, String password);

  /// Sign out current authenticated session.
  Future<void> signOut();
}

/// Firebase and Firestore-backed implementation of [PatrolAuthService].
class FirebasePatrolAuthService implements PatrolAuthService {
  FirebasePatrolAuthService({
    this._auth,
    this._officerRepository,
    this._firestore,
  });

  final FirebaseAuth? _auth;
  final OfficerRepository? _officerRepository;
  final FirebaseFirestore? _firestore;

  FirebaseAuth? get _safeAuth {
    if (_auth != null) return _auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  OfficerRepository? get _safeOfficerRepo {
    if (_officerRepository != null) return _officerRepository;
    try {
      return FirestoreOfficerRepository();
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _safeFirestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUserId => _safeAuth?.currentUser?.uid;

  @override
  Future<String?> getCurrentUserId() async {
    return _safeAuth?.currentUser?.uid;
  }

  @override
  Future<String> getCurrentUserName() async {
    final user = _safeAuth?.currentUser;
    if (user == null) return 'Not Signed In';

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!;
    }

    // Attempt lookup in Firestore officers collection
    final firestore = _safeFirestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection(Officer.collectionName)
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final officerName = doc.data()!['name'] as String?;
          if (officerName != null && officerName.isNotEmpty) {
            return officerName;
          }
        }
      } catch (_) {}
    }

    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }

    return 'User (${user.uid.length > 6 ? user.uid.substring(0, 6) : user.uid})';
  }

  @override
  Future<String?> getCurrentRole() async {
    final user = _safeAuth?.currentUser;
    if (user == null) return null;

    // 1. Check custom claims from trusted Firebase Auth token
    try {
      final tokenResult = await user.getIdTokenResult();
      final claimRole = tokenResult.claims?['role'] as String?;
      if (claimRole != null &&
          (claimRole == 'manager' ||
              claimRole == 'admin' ||
              claimRole == 'ranger')) {
        return claimRole;
      }
    } catch (_) {}

    // 2. Check verified officer document in Firestore
    final firestore = _safeFirestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection(Officer.collectionName)
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final role = doc.data()!['role'] as String?;
          if (role != null &&
              (role == 'manager' || role == 'admin' || role == 'ranger')) {
            return role;
          }
        }
      } catch (_) {}
    }

    // Default to least privilege ranger if authenticated without explicit role
    return 'ranger';
  }

  @override
  Future<bool> isParkManager() async {
    final role = await getCurrentRole();
    return role == 'manager' || role == 'admin';
  }

  @override
  Future<bool> isSignedIn() async {
    return _safeAuth?.currentUser != null;
  }

  @override
  Future<List<Officer>> getRegisteredRangers() async {
    final repo = _safeOfficerRepo;
    if (repo != null) {
      try {
        final officers = await repo.getByRole('ranger');
        return officers;
      } catch (e) {
        if (kDebugMode) {
          print('Firestore getByRole(ranger) error: $e');
        }
        rethrow;
      }
    }
    return [];
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final auth = _safeAuth;
    if (auth == null) {
      throw StateError(
          'Firebase Authentication is uninitialized. Please configure Firebase.');
    }

    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Authentication failed: no user record returned.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    final auth = _safeAuth;
    if (auth != null) {
      await auth.signOut();
    }
  }
}

/// In-memory implementation of [PatrolAuthService] for automated unit tests.
class InMemoryPatrolAuthService implements PatrolAuthService {
  InMemoryPatrolAuthService({
    String? currentUserId = 'test_ranger_uid',
    String currentUserName = 'Test Ranger',
    String? currentRole = 'ranger',
    List<Officer>? registeredRangers,
  })  : _userId = currentUserId,
        _userName = currentUserName,
        _role = currentRole,
        _rangers = registeredRangers ??
            [
              const Officer(
                officerId: 'test_ranger_uid',
                name: 'Test Ranger',
                role: 'ranger',
              ),
              const Officer(
                officerId: 'ranger_2',
                name: 'Ranger Two',
                role: 'ranger',
              ),
            ];

  String? _userId;
  String _userName;
  String? _role;
  final List<Officer> _rangers;

  @override
  String? get currentUserId => _userId;

  @override
  Future<String?> getCurrentUserId() async => _userId;

  @override
  Future<String> getCurrentUserName() async => _userName;

  @override
  Future<String?> getCurrentRole() async => _role;

  @override
  Future<bool> isParkManager() async =>
      _role == 'manager' || _role == 'admin';

  @override
  Future<bool> isSignedIn() async => _userId != null;

  @override
  Future<List<Officer>> getRegisteredRangers() async => _rangers;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    if (email.contains('manager')) {
      _role = 'manager';
      _userId = 'manager_test_uid';
      _userName = 'Park Manager ($email)';
    } else {
      _role = 'ranger';
      _userId = 'ranger_test_uid';
      _userName = 'Field Ranger ($email)';
    }
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _role = null;
    _userName = 'Not Signed In';
  }

  /// Helper for unit tests to configure identity explicitly.
  void setTestIdentity({
    required String? userId,
    required String? role,
    String userName = 'Test User',
  }) {
    _userId = userId;
    _role = role;
    _userName = userName;
  }

  /// Convenience helper for unit tests.
  Future<void> signIn({
    required String role,
    required String officerId,
    required String name,
  }) async {
    _userId = officerId;
    _role = role;
    _userName = name;
  }
}
