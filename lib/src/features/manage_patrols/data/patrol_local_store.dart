import 'package:hive_flutter/hive_flutter.dart';

import 'patrol_models.dart';

/// Abstract contract for local patrol data persistence.
abstract class PatrolLocalStore {
  Future<void> initialize();
  PatrolSession? readActiveSession();
  PatrolSession? readSessionById(String sessionId);
  List<PatrolSession> readAllSessions();
  Future<void> saveSession(PatrolSession session);
  Future<void> deleteSession(String sessionId);

  // Assignment caching for offline resilience
  List<PatrolAssignment> readCachedAssignments({String? rangerId});
  Future<void> saveCachedAssignments(List<PatrolAssignment> assignments);
  Future<void> saveCachedAssignment(PatrolAssignment assignment);

  // Session history
  List<PatrolSession> readSessionHistory({String? rangerId});
}

/// Hive-backed implementation for durable local patrol storage.
///
/// Stores each session under `patrol:<sessionId>` and keeps a pointer to the
/// active session under 'activeSessionId'. Uses [Hive.initFlutter] for
/// platform-appropriate directory resolution (native: app documents; web:
/// IndexedDB).
class HivePatrolLocalStore implements PatrolLocalStore {
  HivePatrolLocalStore({this.directory});
  final String? directory;
  late Box<dynamic> _box;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory!);
    }
    _box = await Hive.openBox<dynamic>('wildora_patrol_sessions_v1');
    _initialized = true;
  }

  @override
  PatrolSession? readActiveSession() {
    final activeId = _box.get('activeSessionId') as String?;
    if (activeId == null) return null;
    final map = _box.get('patrol:$activeId');
    if (map == null) return null;
    return PatrolSession.fromMap(map as Map);
  }

  @override
  PatrolSession? readSessionById(String sessionId) {
    final map = _box.get('patrol:$sessionId');
    if (map == null) return null;
    return PatrolSession.fromMap(map as Map);
  }

  @override
  List<PatrolSession> readAllSessions() => _box.keys
      .where((key) => key.toString().startsWith('patrol:'))
      .map((key) => PatrolSession.fromMap(_box.get(key) as Map))
      .toList();

  @override
  Future<void> saveSession(PatrolSession session) async {
    await _box.put('patrol:${session.sessionId}', session.toMap());
    // Update active pointer when session is active
    if (session.lifecycleStatus == PatrolLifecycleStatus.active) {
      await _box.put('activeSessionId', session.sessionId);
    }
    // Clear active pointer when session is completed
    if (session.lifecycleStatus == PatrolLifecycleStatus.completed) {
      final currentActive = _box.get('activeSessionId') as String?;
      if (currentActive == session.sessionId) {
        await _box.delete('activeSessionId');
      }
    }
    await _box.flush();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _box.delete('patrol:$sessionId');
    final currentActive = _box.get('activeSessionId') as String?;
    if (currentActive == sessionId) {
      await _box.delete('activeSessionId');
    }
    await _box.flush();
  }

  @override
  List<PatrolAssignment> readCachedAssignments({String? rangerId}) {
    final all = _box.keys
        .where((key) => key.toString().startsWith('assignment:'))
        .map((key) => PatrolAssignment.fromMap(_box.get(key) as Map))
        .toList();
    if (rangerId != null && rangerId.isNotEmpty) {
      return all.where((a) => a.assignedRangerId == rangerId).toList();
    }
    return all;
  }

  @override
  Future<void> saveCachedAssignments(List<PatrolAssignment> assignments) async {
    for (final a in assignments) {
      await _box.put('assignment:${a.id}', a.toMap());
    }
    await _box.flush();
  }

  @override
  Future<void> saveCachedAssignment(PatrolAssignment assignment) async {
    await _box.put('assignment:${assignment.id}', assignment.toMap());
    await _box.flush();
  }

  @override
  List<PatrolSession> readSessionHistory({String? rangerId}) {
    final all = readAllSessions()
        .where((s) => s.lifecycleStatus == PatrolLifecycleStatus.completed)
        .toList();
    if (rangerId != null && rangerId.isNotEmpty) {
      return all.where((s) => s.rangerId == rangerId).toList();
    }
    return all;
  }
}

/// In-memory implementation for testing.
class InMemoryPatrolLocalStore implements PatrolLocalStore {
  final Map<String, PatrolSession> _sessions = {};
  final Map<String, PatrolAssignment> _assignments = {};
  String? _activeSessionId;
  bool shouldFail = false;

  /// Test helper to set the active session ID directly.
  void setActiveSessionId(String? id) => _activeSessionId = id;

  @override
  Future<void> initialize() async {}

  @override
  PatrolSession? readActiveSession() {
    if (_activeSessionId == null) return null;
    return _sessions[_activeSessionId];
  }

  @override
  PatrolSession? readSessionById(String sessionId) => _sessions[sessionId];

  @override
  List<PatrolSession> readAllSessions() => _sessions.values.toList();

  @override
  Future<void> saveSession(PatrolSession session) async {
    if (shouldFail) throw Exception('Simulated storage failure');
    _sessions[session.sessionId] = session;
    if (session.lifecycleStatus == PatrolLifecycleStatus.active) {
      _activeSessionId = session.sessionId;
    }
    if (session.lifecycleStatus == PatrolLifecycleStatus.completed) {
      if (_activeSessionId == session.sessionId) {
        _activeSessionId = null;
      }
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
    }
  }

  @override
  List<PatrolAssignment> readCachedAssignments({String? rangerId}) {
    if (rangerId != null && rangerId.isNotEmpty) {
      return _assignments.values
          .where((a) => a.assignedRangerId == rangerId)
          .toList();
    }
    return _assignments.values.toList();
  }

  @override
  Future<void> saveCachedAssignments(List<PatrolAssignment> assignments) async {
    for (final a in assignments) {
      _assignments[a.id] = a;
    }
  }

  @override
  Future<void> saveCachedAssignment(PatrolAssignment assignment) async {
    _assignments[assignment.id] = assignment;
  }

  @override
  List<PatrolSession> readSessionHistory({String? rangerId}) {
    final completed = _sessions.values
        .where((s) => s.lifecycleStatus == PatrolLifecycleStatus.completed)
        .toList();
    if (rangerId != null && rangerId.isNotEmpty) {
      return completed.where((s) => s.rangerId == rangerId).toList();
    }
    return completed;
  }
}
