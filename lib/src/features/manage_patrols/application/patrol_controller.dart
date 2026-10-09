import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/patrol_models.dart';
import '../data/patrol_local_store.dart';
import '../data/patrol_location_service.dart';
import '../data/patrol_sync_service.dart';

/// Central controller for patrol lifecycle management.
///
/// Separates business logic from UI. Notifies listeners on state changes
/// using [ChangeNotifier] (matching the project's ThemeController pattern).
class PatrolController extends ChangeNotifier {
  PatrolController({
    required this.localStore,
    required this.locationService,
    required this.syncService,
  });

  final PatrolLocalStore localStore;
  final PatrolLocationService locationService;
  final PatrolSyncService syncService;

  PatrolSession? _currentSession;
  PatrolSession? get currentSession => _currentSession;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _gpsAvailable = true;
  bool get gpsAvailable => _gpsAvailable;

  DateTime? _lastGpsFix;
  DateTime? get lastGpsFix => _lastGpsFix;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Timer? _durationTimer;

  // ─── Initialization ─────────────────────────────────────────────

  /// Initialize the controller: open local storage and restore any active
  /// patrol session.
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await localStore.initialize();
      _currentSession = localStore.readActiveSession();
      if (_currentSession != null &&
          _currentSession!.lifecycleStatus == PatrolLifecycleStatus.active) {
        _startDurationTimer();
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to load patrol data: $e';
    }
    _setLoading(false);
  }

  /// Load the assigned patrol. In a real app this would fetch from a server.
  /// Here we create a mock assignment if none exists.
  Future<void> loadAssignment() async {
    if (_currentSession != null) return;
    _setLoading(true);
    try {
      _currentSession = PatrolSession(
        sessionId: newPatrolSessionId(),
        assignedRouteId: 'route_yala_east_01',
        rangerId: 'ranger_001',
        routeName: 'Yala East Perimeter',
        estimatedDurationMinutes: 120,
        plannedDistanceKm: 8.5,
        lifecycleStatus: PatrolLifecycleStatus.assigned,
      );
      await localStore.saveSession(_currentSession!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load assignment: $e';
      _currentSession = null;
    }
    _setLoading(false);
  }

  // ─── Start Patrol ───────────────────────────────────────────────

  /// Start the patrol. Creates a unique session and persists before confirming.
  ///
  /// Prevents duplicate active sessions: if one already exists, returns it.
  /// Uses a [_startingPatrol] guard to prevent double-tap race conditions.
  bool _startingPatrol = false;

  Future<bool> startPatrol() async {
    // Prevent double-tap
    if (_startingPatrol) return false;
    _startingPatrol = true;

    try {
      // Check for existing active session
      if (_currentSession?.lifecycleStatus == PatrolLifecycleStatus.active) {
        _startingPatrol = false;
        return true; // Already active, just resume
      }

      _setLoading(true);
      _error = null;

      final now = DateTime.now();
      final session = (_currentSession ?? PatrolSession(
        sessionId: newPatrolSessionId(),
        assignedRouteId: 'route_yala_east_01',
        rangerId: 'ranger_001',
      )).copyWith(
        startTime: now,
        lifecycleStatus: PatrolLifecycleStatus.active,
        revision: (_currentSession?.revision ?? 0) + 1,
        syncMetadata: const SyncMetadata(syncStatus: SyncStatus.pendingSync),
      );

      // Persist BEFORE confirming to the user
      await localStore.saveSession(session);
      _currentSession = session;
      _startDurationTimer();
      _setLoading(false);
      _startingPatrol = false;
      return true;
    } catch (e) {
      _error = 'Failed to start patrol. Please retry. ($e)';
      _setLoading(false);
      _startingPatrol = false;
      return false;
    }
  }

  // ─── GPS Tracking ───────────────────────────────────────────────

  /// Start GPS tracking and record fixes to the session.
  void startGpsTracking() {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) return;
    _gpsAvailable = true;
    notifyListeners();

    locationService.startTracking((trackPoint) {
      if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
        return;
      }
      _addTrackPoint(trackPoint);
    });
  }

  /// Stop GPS tracking.
  void stopGpsTracking() {
    locationService.stopTracking();
  }

  /// Record a single GPS fix manually (e.g. from retry button).
  Future<bool> captureGpsFix() async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      return false;
    }
    try {
      final point = await locationService.captureCurrentPosition();
      _addTrackPoint(point);
      _gpsAvailable = true;
      _lastGpsFix = point.timestamp;
      notifyListeners();
      return true;
    } catch (e) {
      _gpsAvailable = false;
      _error = 'GPS unavailable: $e';
      notifyListeners();
      return false;
    }
  }

  void _addTrackPoint(TrackPoint point) {
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
    _gpsAvailable = true;
    // Persist incrementally
    localStore.saveSession(_currentSession!).catchError((Object e) {
      _error = 'Failed to save GPS point: $e';
      notifyListeners();
    });
    notifyListeners();
  }

  // ─── Waypoints ──────────────────────────────────────────────────

  /// Add a waypoint to the current active session.
  ///
  /// Validates coordinates. Does NOT count manual waypoints as GPS distance.
  /// Persists locally before returning success.
  Future<bool> addWaypoint(Waypoint waypoint) async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      _error = 'Cannot add waypoint: patrol is not active.';
      notifyListeners();
      return false;
    }

    if (!TrackPoint.isValid(waypoint.latitude, waypoint.longitude)) {
      _error = 'Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180.';
      notifyListeners();
      return false;
    }

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
      _error = 'Failed to save waypoint. Please retry. ($e)';
      notifyListeners();
      return false;
    }
  }

  // ─── Route Deviations ───────────────────────────────────────────

  /// Record a route deviation with optional reason.
  Future<bool> recordDeviation({
    required double latitude,
    required double longitude,
    String? reason,
  }) async {
    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      return false;
    }
    if (!TrackPoint.isValid(latitude, longitude)) {
      _error = 'Invalid deviation coordinates.';
      notifyListeners();
      return false;
    }

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
      _error = 'Failed to record deviation. ($e)';
      notifyListeners();
      return false;
    }
  }

  // ─── Complete Patrol ────────────────────────────────────────────

  bool _completingPatrol = false;

  /// Complete the patrol.
  ///
  /// Persists the Completed status and end time before confirming.
  /// Stops GPS tracking only after successful persistence.
  /// If persistence fails, the patrol stays Active with data intact.
  Future<bool> completePatrol() async {
    if (_completingPatrol) return false;
    _completingPatrol = true;

    if (_currentSession?.lifecycleStatus != PatrolLifecycleStatus.active) {
      _completingPatrol = false;
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final now = DateTime.now();
      final completed = _currentSession!.copyWith(
        endTime: now,
        lifecycleStatus: PatrolLifecycleStatus.completed,
        revision: _currentSession!.revision + 1,
        syncMetadata: _currentSession!.syncMetadata.copyWith(
          syncStatus: SyncStatus.pendingSync,
          localRevision: _currentSession!.syncMetadata.localRevision + 1,
        ),
      );

      // Persist BEFORE updating state
      await localStore.saveSession(completed);

      // Only stop GPS after successful persistence
      stopGpsTracking();
      _stopDurationTimer();

      _currentSession = completed;
      _setLoading(false);
      _completingPatrol = false;
      return true;
    } catch (e) {
      // Keep patrol Active – data is still intact
      _error = 'Failed to complete patrol. Data preserved. Please retry. ($e)';
      _setLoading(false);
      _completingPatrol = false;
      return false;
    }
  }

  // ─── Synchronization ───────────────────────────────────────────

  /// Attempt to synchronize the current session with the remote server.
  Future<bool> syncCurrentSession() async {
    if (_currentSession == null || _isSyncing) return false;
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      _currentSession = await syncService.syncSession(_currentSession!);
      _isSyncing = false;
      notifyListeners();
      return _currentSession!.syncMetadata.syncStatus == SyncStatus.synchronized;
    } catch (e) {
      _error = 'Sync failed: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Connectivity ───────────────────────────────────────────────

  /// Update the online status (called by the UI layer).
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  // ─── Reset / New Assignment ─────────────────────────────────────

  /// Reset the controller state to accept a new patrol assignment.
  Future<void> resetForNewAssignment() async {
    stopGpsTracking();
    _stopDurationTimer();
    _currentSession = null;
    _error = null;
    _gpsAvailable = true;
    _lastGpsFix = null;
    notifyListeners();
  }

  // ─── Internal helpers ───────────────────────────────────────────

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners(); // Trigger UI rebuild for elapsed time
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    locationService.dispose();
    super.dispose();
  }
}
