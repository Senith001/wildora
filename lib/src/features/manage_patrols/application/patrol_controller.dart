import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/patrol_assignment_repository.dart';
import '../data/patrol_auth_service.dart';
import '../data/patrol_local_store.dart';
import '../data/patrol_location_service.dart';
import '../data/patrol_models.dart';
import '../data/patrol_sync_service.dart';

/// Central controller for patrol lifecycle management.
///
/// Follows Single Responsibility and Dependency Injection principles:
/// - Manages field patrol lifecycle (assigned -> active -> completed).
/// - Serializes local state mutations sequentially to prevent concurrent write loss.
/// - Connects hardware GPS signal changes to the reactive presentation layer.
/// - Enforces authentication and authorization scoping (Managers vs Rangers).
/// - Publishes live location to Firestore at a 12-second throttle while active.
/// - Prevents restarting completed patrols in controller logic and remote.
/// - Notifies listeners on state changes using [ChangeNotifier].
class PatrolController extends ChangeNotifier {
  PatrolController({
    required this.localStore,
    required this.locationService,
    required this.syncService,
    PatrolAssignmentRepository? assignmentRepository,
    PatrolAuthService? authService,
    this.firestore,
  })  : assignmentRepository = assignmentRepository ??
            FirestorePatrolAssignmentRepository(localStore: localStore),
        authService = authService ?? FirebasePatrolAuthService() {
    _listenToGpsSignalStatus();
  }

  final PatrolLocalStore localStore;
  final PatrolLocationService locationService;
  final PatrolSyncService syncService;
  final PatrolAssignmentRepository assignmentRepository;
  final PatrolAuthService authService;
  final FirebaseFirestore? firestore;

  FirebaseFirestore? get _safeDb {
    if (firestore != null) return firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  PatrolSession? _currentSession;
  PatrolSession? get currentSession => _currentSession;

  List<PatrolAssignment> _availableAssignments = [];
  List<PatrolAssignment> get availableAssignments => _availableAssignments;

  PatrolAssignment? _selectedAssignment;
  PatrolAssignment? get selectedAssignment => _selectedAssignment;

  List<PatrolSession> _historyCache = [];
  List<PatrolSession> get historyCache => _historyCache;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  String _currentUserName = 'Not Signed In';
  String get currentUserName => _currentUserName;

  String? _currentRole;
  String? get currentRole => _currentRole;

  bool _isManager = false;
  bool get isManager => _isManager;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _gpsAvailable = true;
  bool get gpsAvailable => _gpsAvailable;

  GpsSignalStatus _gpsSignalStatus = GpsSignalStatus.locating;
  GpsSignalStatus get gpsSignalStatus => _gpsSignalStatus;

  double? _gpsAccuracy;
  double? get gpsAccuracy => _gpsAccuracy;

  DateTime? _lastGpsFix;
  DateTime? get lastGpsFix => _lastGpsFix;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool get isSimulationMode => locationService.isSimulationMode;

  /// Most recently accepted GPS trackpoint (within 30s) — used by AddWaypointScreen.
  TrackPoint? _latestRecentFix;
  TrackPoint? get latestRecentFix {
    final fix = _latestRecentFix;
    if (fix == null) return null;
    return DateTime.now().difference(fix.timestamp).inSeconds <= 30 ? fix : null;
  }

  /// Last time a live location was published to Firestore.
  DateTime? _lastPublishedAt;
  DateTime? get lastPublishedAt => _lastPublishedAt;

  Timer? _durationTimer;
  Timer? _liveLocationTimer;
  StreamSubscription<GpsSignalStatus>? _gpsStatusSubscription;

  // Asynchronous mutation queue to strictly serialize concurrent local writes
  Future<void> _mutationQueue = Future.value();

  Future<T> _serializeMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _listenToGpsSignalStatus() {
    _gpsStatusSubscription = locationService.signalStatusStream.listen((status) {
      _gpsSignalStatus = status;
      _lastGpsFix = locationService.lastFixTime;
      _gpsAccuracy = locationService.lastAccuracy;
      _gpsAvailable = status == GpsSignalStatus.available;
      notifyListeners();
    });
  }

  // ─── Authentication & Initialization ─────────────────────────────

  /// Initialize controller: verify authentication, open durable local storage,
  /// restore user active session, and subscribe to GPS state.
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await localStore.initialize();

      // Resolve authenticated identity
      await refreshAuthSession();

      // Restore active session scoped to the authenticated user
      final storedActive = localStore.readActiveSession();
      if (storedActive != null) {
        final rid = storedActive.rangerId;
        if (_currentUserId == null ||
            rid == null ||
            rid.isEmpty ||
            rid == _currentUserId) {
          _currentSession = storedActive;
          if (storedActive.lifecycleStatus == PatrolLifecycleStatus.active) {
            _startDurationTimer();
            startGpsTracking();
            _startLiveLocationPublishing();
          }
        }
      }

      // Initial GPS hardware state
      _gpsSignalStatus = locationService.signalStatus;
      _lastGpsFix = locationService.lastFixTime;
      _gpsAccuracy = locationService.lastAccuracy;

      _error = null;
    } catch (e) {
      _error = 'Failed to load patrol data: $e';
    }
    _setLoading(false);
  }

  /// Refresh identity and role permissions from server-backed auth service.
  Future<void> refreshAuthSession() async {
    try {
      _currentUserId = await authService.getCurrentUserId();
      _currentUserName = await authService.getCurrentUserName();
      _currentRole = await authService.getCurrentRole();
      _isManager = await authService.isParkManager();
      notifyListeners();
    } catch (_) {}
  }

  /// Sign in with official email and password.
  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await authService.signInWithEmail(email, password);
      await refreshAuthSession();
      await loadAssignment();
      _error = null;
    } catch (e) {
      _error = 'Sign in failed: $e';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out current session and reset local user context.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      stopGpsTracking();
      _stopLiveLocationPublishing();
      _durationTimer?.cancel();
      // Remove live location document if signed in
      if (_currentUserId != null) {
        await _clearLiveLocation(_currentUserId!);
      }
      await authService.signOut();
      _currentUserId = null;
      _currentUserName = 'Not Signed In';
      _currentRole = null;
      _isManager = false;
      _currentSession = null;
      _availableAssignments = [];
      _selectedAssignment = null;
      _historyCache = [];
      _error = null;
    } catch (e) {
      _error = 'Sign out error: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ─── Patrol Assignments ─────────────────────────────────────────

  /// Load designated assignments for the authenticated ranger.
  ///
  /// HONEST DATA GUARANTEE:
  /// - Queries assignments strictly for the ranger's UID.
  /// - Completed/cancelled assignments are excluded from the actionable list.
  /// - If no assignments exist on server or cache, leaves list empty.
  /// - NEVER generates fake sample routes.
  Future<void> loadAssignment() async {
    _setLoading(true);
    try {
      final uid = _currentUserId;
      if (uid == null || uid.isEmpty) {
        _availableAssignments = [];
        _selectedAssignment = null;
        _currentSession = null;
        _setLoading(false);
        return;
      }

      List<PatrolAssignment> assignments = [];
      try {
        assignments = await assignmentRepository.getAssignmentsForRanger(uid);
      } catch (_) {
        assignments = localStore.readCachedAssignments(rangerId: uid);
      }

      // KEY FIX: exclude completed/cancelled assignments and assignments
      // for which a completed session already exists locally.
      final completedRouteIds = localStore
          .readSessionHistory(rangerId: uid)
          .map((s) => s.assignedRouteId)
          .whereType<String>()
          .toSet();

      final active = assignments
          .where((a) =>
              a.status != PatrolAssignmentStatus.completed &&
              a.status != PatrolAssignmentStatus.cancelled &&
              !completedRouteIds.contains(a.id))
          .toList();

      _availableAssignments = active;
      _selectedAssignment = active.isNotEmpty ? active.first : null;

      if (_selectedAssignment != null) {
        // Restore or create a session for the selected assignment
        final storedActive = localStore.readActiveSession();
        if (storedActive != null &&
            storedActive.assignedRouteId == _selectedAssignment!.id &&
            storedActive.lifecycleStatus != PatrolLifecycleStatus.completed) {
          _currentSession = storedActive;
        } else if (_currentSession == null ||
            _currentSession!.lifecycleStatus == PatrolLifecycleStatus.completed) {
          // Do not overwrite an ongoing session
          if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
            final newSession = PatrolSession(
              sessionId: newPatrolSessionId(),
              assignedRouteId: _selectedAssignment!.id,
              rangerId: uid,
              routeName: _selectedAssignment!.routeName,
              estimatedDurationMinutes:
                  _selectedAssignment!.estimatedDurationMinutes,
              plannedDistanceKm: _selectedAssignment!.plannedDistanceKm,
              checkpoints: _selectedAssignment!.checkpoints,
              lifecycleStatus: PatrolLifecycleStatus.assigned,
            );
            await localStore.saveSession(newSession);
            _currentSession = newSession;
          }
        }
      } else {
        // No pending assignments — clear only if it's a plain assigned template
        if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.assigned) {
          _currentSession = null;
        }
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load assignments: $e';
    }
    _setLoading(false);
  }

  /// Select an assignment from the available assignments list.
  void selectAssignment(PatrolAssignment assignment) {
    _selectedAssignment = assignment;
    final uid = _currentUserId ?? 'ranger';
    if (_currentSession == null ||
        _currentSession!.lifecycleStatus == PatrolLifecycleStatus.assigned) {
      _currentSession = PatrolSession(
        sessionId: newPatrolSessionId(),
        assignedRouteId: assignment.id,
        rangerId: uid,
        routeName: assignment.routeName,
        estimatedDurationMinutes: assignment.estimatedDurationMinutes,
        plannedDistanceKm: assignment.plannedDistanceKm,
        checkpoints: assignment.checkpoints,
        lifecycleStatus: PatrolLifecycleStatus.assigned,
      );
      localStore.saveSession(_currentSession!);
    }
    notifyListeners();
  }

  // ─── Start Patrol ───────────────────────────────────────────────

  bool _startingPatrol = false;

  /// Start the patrol.
  ///
  /// Guarantees:
  /// - Only ONE active session permitted per ranger.
  /// - Prevents starting if no real assignment is selected.
  /// - Stable session ID generated.
  /// - Persists Active status and start time locally BEFORE showing success.
  /// - Double-tap race conditions guarded.
  /// - Starts GPS tracking only after local storage persistence succeeds.
  Future<bool> startPatrol() async {
    if (_startingPatrol) return false;
    _startingPatrol = true;

    return _serializeMutation(() async {
      try {
        // KEY FIX: Completed sessions CANNOT be restarted.
        if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.completed) {
          _error = 'This patrol has already been completed. A new assignment is needed to patrol again.';
          _startingPatrol = false;
          notifyListeners();
          return false;
        }

        if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.active) {
          _startingPatrol = false;
          return true;
        }

        if (_currentSession == null && _selectedAssignment == null) {
          _error = 'No patrol assignment selected. Contact your Park Manager.';
          _startingPatrol = false;
          notifyListeners();
          return false;
        }

        _setLoading(true);
        _error = null;

        final now = DateTime.now();
        final currentRev = _currentSession?.revision ?? 0;
        final currentLocalRev =
            _currentSession?.syncMetadata.localRevision ?? 0;

        final session = (_currentSession ??
                PatrolSession(
                  sessionId: newPatrolSessionId(),
                  assignedRouteId: _selectedAssignment!.id,
                  rangerId: _currentUserId ?? 'ranger',
                  routeName: _selectedAssignment!.routeName,
                  estimatedDurationMinutes:
                      _selectedAssignment!.estimatedDurationMinutes,
                  plannedDistanceKm: _selectedAssignment!.plannedDistanceKm,
                  checkpoints: _selectedAssignment!.checkpoints,
                ))
            .copyWith(
          lifecycleStatus: PatrolLifecycleStatus.active,
          startTime: now,
          revision: currentRev + 1,
          syncMetadata: SyncMetadata(
            syncStatus: SyncStatus.pendingSync,
            localRevision: currentLocalRev + 1,
          ),
        );

        // Persist locally before updating UI state
        await localStore.saveSession(session);
        _currentSession = session;
        _startDurationTimer();

        // Update assignment status to inProgress on server (best-effort)
        if (_selectedAssignment != null) {
          _updateAssignmentStatusQueued(
              _selectedAssignment!.id, PatrolAssignmentStatus.inProgress);
        }

        // Start GPS and live location publishing after local persistence
        startGpsTracking();
        _startLiveLocationPublishing();

        _setLoading(false);
        _startingPatrol = false;
        return true;
      } catch (e) {
        _error = 'Failed to start patrol. Please retry. ($e)';
        _setLoading(false);
        _startingPatrol = false;
        return false;
      }
    });
  }

  /// Queue a best-effort assignment status update (fire-and-forget).
  void _updateAssignmentStatusQueued(
      String assignmentId, PatrolAssignmentStatus status) {
    assignmentRepository
        .updateAssignmentStatus(assignmentId, status)
        .catchError((_) {});
  }

  // ─── GPS Tracking ───────────────────────────────────────────────

  void startGpsTracking() {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      return;
    }
    _gpsAvailable = true;
    notifyListeners();

    locationService.startTracking((trackPoint) {
      if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
        return;
      }
      _latestRecentFix = trackPoint;
      _addTrackPoint(trackPoint);
    });
  }

  void stopGpsTracking() {
    locationService.stopTracking();
  }

  /// Request continuous GPS permission and retry obtaining location.
  Future<void> retryGps() async {
    _error = null;
    await locationService.checkAndRequestPermission();
    if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.active) {
      stopGpsTracking();
      startGpsTracking();
    } else {
      await captureGpsFix();
    }
  }

  /// Record a single GPS fix manually.
  Future<bool> captureGpsFix() async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      return false;
    }
    try {
      final point = await locationService.captureCurrentPosition();
      _latestRecentFix = point;
      await _addTrackPoint(point);
      _gpsAvailable = true;
      _gpsSignalStatus = locationService.signalStatus;
      _gpsAccuracy = point.accuracy;
      _lastGpsFix = point.timestamp;
      notifyListeners();
      return true;
    } catch (e) {
      _gpsAvailable = false;
      _gpsSignalStatus = locationService.signalStatus;
      _error = 'GPS fix unavailable: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _addTrackPoint(TrackPoint point) async {
    if (_currentSession == null ||
        _currentSession!.lifecycleStatus != PatrolLifecycleStatus.active) {
      return;
    }

    // Reject non-finite and out-of-range coordinates
    if (!TrackPoint.isValid(point.latitude, point.longitude)) {
      return;
    }

    await _serializeMutation(() async {
      if (_currentSession == null ||
          _currentSession!.lifecycleStatus != PatrolLifecycleStatus.active) {
        return;
      }

      final updatedPoints = [..._currentSession!.trackPoints, point];
      _currentSession = _currentSession!.copyWith(
        trackPoints: updatedPoints,
        revision: _currentSession!.revision + 1,
        syncMetadata: _currentSession!.syncMetadata.copyWith(
          syncStatus: SyncStatus.pendingSync,
          localRevision: _currentSession!.syncMetadata.localRevision + 1,
        ),
      );
      _lastGpsFix = point.timestamp;
      _gpsAccuracy = point.accuracy;
      _gpsAvailable = true;
      _gpsSignalStatus = GpsSignalStatus.available;
      _latestRecentFix = point;

      // Incrementally persist to local store
      await localStore.saveSession(_currentSession!);
      notifyListeners();
    }).catchError((Object e) {
      _error = 'Failed to save GPS point: $e';
      notifyListeners();
    });
  }

  // ─── Waypoints ──────────────────────────────────────────────────

  Future<bool> addWaypoint(Waypoint waypoint) async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      _error = 'Cannot add waypoint: patrol is not active.';
      notifyListeners();
      return false;
    }

    if (!TrackPoint.isValid(waypoint.latitude, waypoint.longitude)) {
      _error = 'Invalid coordinates: Waypoint coordinates are outside valid geographical range.';
      notifyListeners();
      return false;
    }

    return _serializeMutation(() async {
      try {
        final updatedWaypoints = [..._currentSession!.waypoints, waypoint];
        _currentSession = _currentSession!.copyWith(
          waypoints: updatedWaypoints,
          revision: _currentSession!.revision + 1,
          syncMetadata: _currentSession!.syncMetadata.copyWith(
            syncStatus: SyncStatus.pendingSync,
            localRevision: _currentSession!.syncMetadata.localRevision + 1,
          ),
        );

        await localStore.saveSession(_currentSession!);
        _error = null;
        notifyListeners();
        return true;
      } catch (e) {
        _error = 'Failed to save waypoint: $e';
        notifyListeners();
        return false;
      }
    });
  }

  // ─── Route Deviations ───────────────────────────────────────────

  Future<bool> recordDeviation({
    required double latitude,
    required double longitude,
    String? reason,
  }) async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      _error = 'Cannot record deviation: patrol is not active.';
      notifyListeners();
      return false;
    }

    if (!TrackPoint.isValid(latitude, longitude)) {
      _error = 'Invalid deviation: coordinates are outside valid geographical range.';
      notifyListeners();
      return false;
    }

    return _serializeMutation(() async {
      try {
        final deviation = RouteDeviation(
          timestamp: DateTime.now(),
          latitude: latitude,
          longitude: longitude,
          reason: reason,
        );

        final updatedDeviations = [..._currentSession!.deviations, deviation];
        _currentSession = _currentSession!.copyWith(
          deviations: updatedDeviations,
          revision: _currentSession!.revision + 1,
          syncMetadata: _currentSession!.syncMetadata.copyWith(
            syncStatus: SyncStatus.pendingSync,
            localRevision: _currentSession!.syncMetadata.localRevision + 1,
          ),
        );

        await localStore.saveSession(_currentSession!);
        _error = null;
        notifyListeners();
        return true;
      } catch (e) {
        _error = 'Failed to record deviation: $e';
        notifyListeners();
        return false;
      }
    });
  }

  // ─── Complete Patrol ────────────────────────────────────────────

  bool _completingPatrol = false;

  Future<bool> completePatrol() async {
    if (_completingPatrol) return false;
    _completingPatrol = true;

    return _serializeMutation(() async {
      try {
        if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.completed) {
          _completingPatrol = false;
          return false;
        }

        if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
          _error = 'Cannot complete patrol: no active patrol session.';
          _completingPatrol = false;
          notifyListeners();
          return false;
        }

        _setLoading(true);

        final completedSession = _currentSession!.copyWith(
          lifecycleStatus: PatrolLifecycleStatus.completed,
          endTime: DateTime.now(),
          revision: _currentSession!.revision + 1,
          syncMetadata: _currentSession!.syncMetadata.copyWith(
            syncStatus: SyncStatus.pendingSync,
            localRevision: _currentSession!.syncMetadata.localRevision + 1,
          ),
        );

        // Persist Completed state to durable storage BEFORE stopping GPS tracking
        await localStore.saveSession(completedSession);
        _currentSession = completedSession;

        // Stop tracking and timers after durable persistence succeeds
        stopGpsTracking();
        _stopLiveLocationPublishing();
        _durationTimer?.cancel();
        _durationTimer = null;

        // Remove live location document from Firestore
        final uid = completedSession.rangerId ?? _currentUserId;
        if (uid != null) {
          _clearLiveLocation(uid);
        }

        // Update assignment status to completed (best-effort)
        if (_selectedAssignment != null) {
          _updateAssignmentStatusQueued(
              _selectedAssignment!.id, PatrolAssignmentStatus.completed);
        }

        // Invalidate history cache so it reloads on next visit
        _historyCache = [];

        _error = null;
        _setLoading(false);
        _completingPatrol = false;
        return true;
      } catch (e) {
        _error = 'Failed to complete patrol. Session remains active. ($e)';
        _setLoading(false);
        _completingPatrol = false;
        return false;
      }
    });
  }

  // ─── Cloud Synchronization ──────────────────────────────────────

  Future<bool> syncCurrentSession() async {
    if (_currentSession == null) return false;
    if (_isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    return _serializeMutation(() async {
      try {
        final synced = await syncService.syncSession(_currentSession!);
        _currentSession = synced;
        _error = synced.syncMetadata.lastSyncError;
        _isSyncing = false;
        notifyListeners();
        return synced.syncMetadata.syncStatus == SyncStatus.synchronized;
      } catch (e) {
        _error = 'Synchronization error: $e';
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    });
  }

  /// Retry sync for a specific session from history.
  Future<bool> syncHistorySession(PatrolSession session) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    notifyListeners();
    try {
      final synced = await syncService.syncSession(session);
      final idx =
          _historyCache.indexWhere((s) => s.sessionId == session.sessionId);
      if (idx >= 0) {
        _historyCache[idx] = synced;
      }
      _isSyncing = false;
      notifyListeners();
      return synced.syncMetadata.syncStatus == SyncStatus.synchronized;
    } catch (e) {
      _error = 'Sync error: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Patrol History ─────────────────────────────────────────────

  /// Load the authenticated ranger's completed patrol history.
  ///
  /// Merges local completed sessions with remote Firestore records,
  /// deduplicating by sessionId and preferring higher localRevision.
  Future<void> loadPatrolHistory() async {
    if (_historyLoading) return;
    _historyLoading = true;
    notifyListeners();
    try {
      final uid = _currentUserId;
      final local = localStore.readSessionHistory(rangerId: uid);

      List<PatrolSession> remote = [];
      try {
        remote = await syncService.getSynchronizedPatrolSessions();
        if (!_isManager && uid != null) {
          remote = remote.where((s) => s.rangerId == uid).toList();
        }
      } catch (_) {}

      final merged = <String, PatrolSession>{};
      for (final s in local) {
        merged[s.sessionId] = s;
      }
      for (final s in remote) {
        final existing = merged[s.sessionId];
        if (existing == null ||
            s.syncMetadata.localRevision > existing.syncMetadata.localRevision) {
          merged[s.sessionId] = s;
        }
      }

      final list = merged.values.toList()
        ..sort((a, b) {
          final ta = a.endTime ?? a.startTime ?? DateTime(0);
          final tb = b.endTime ?? b.startTime ?? DateTime(0);
          return tb.compareTo(ta);
        });

      _historyCache = list;
    } catch (e) {
      _error = 'Failed to load history: $e';
    }
    _historyLoading = false;
    notifyListeners();
  }

  // ─── Live Location Publishing ────────────────────────────────────

  static const Duration _liveLocationInterval = Duration(seconds: 12);

  void _startLiveLocationPublishing() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer =
        Timer.periodic(_liveLocationInterval, (_) => _publishLiveLocation());
  }

  void _stopLiveLocationPublishing() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
  }

  Future<void> _publishLiveLocation() async {
    final session = _currentSession;
    if (session == null ||
        session.lifecycleStatus != PatrolLifecycleStatus.active) {
      return;
    }
    final latestTrack =
        session.trackPoints.isNotEmpty ? session.trackPoints.last : null;
    if (latestTrack == null) return;
    if (latestTrack.source == LocationSource.simulated) return;

    final db = _safeDb;
    if (db == null) return;

    try {
      final uid = session.rangerId ?? _currentUserId;
      if (uid == null) return;
      final now = DateTime.now().toUtc();
      await db.collection('activePatrolLocations').doc(uid).set({
        'rangerId': uid,
        'rangerName': _currentUserName,
        'sessionId': session.sessionId,
        'assignedRouteId': session.assignedRouteId,
        'routeName': session.routeName,
        'latitude': latestTrack.latitude,
        'longitude': latestTrack.longitude,
        'accuracy': latestTrack.accuracy,
        'capturedAt': latestTrack.timestamp.toUtc().toIso8601String(),
        'reportedAt': now.toIso8601String(),
        'startTime': session.startTime?.toUtc().toIso8601String(),
        'trackPointCount': session.trackPoints.length,
        'waypointCount': session.waypoints.length,
        'status': 'active',
      }, SetOptions(merge: false));
      _lastPublishedAt = now.toLocal();
    } catch (e) {
      if (kDebugMode) print('Live location publish error: $e');
    }
  }

  Future<void> _clearLiveLocation(String uid) async {
    final db = _safeDb;
    if (db == null) return;
    try {
      await db.collection('activePatrolLocations').doc(uid).delete();
    } catch (_) {}
  }

  // ─── Session Helpers ────────────────────────────────────────────

  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  Future<void> resetForNewAssignment() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _stopLiveLocationPublishing();
    stopGpsTracking();
    _currentSession = null;
    _error = null;
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.active) {
        notifyListeners();
      }
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _durationTimer?.cancel();
    _liveLocationTimer?.cancel();
    _gpsStatusSubscription?.cancel();
    locationService.dispose();
    super.dispose();
  }
}
