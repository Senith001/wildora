import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_local_store.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_remote_store.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_report.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_repository.dart';

IncidentDraft validDraft() => IncidentDraft()
  ..type = 'Injured Wildlife'
  ..latitude = 6.86
  ..longitude = 79.86
  ..description = ' Injured elephant near the road '
  ..locationName = ' Forest entrance '
  ..occurredAt = DateTime.utc(2020);

// These doubles implement only their respective storage contracts. No Firebase,
// Hive initialization, platform channels or network access is needed.
class MemoryLocal implements IncidentLocalStore {
  final reports = <String, IncidentReport>{};
  final events = <String>[];
  bool failSave = false;
  bool failInitialize = false;
  int initializations = 0;
  @override
  Future<String> initialize() async {
    initializations++;
    if (failInitialize) throw StateError('storage unavailable');
    return 'installation-1';
  }

  @override
  List<IncidentReport> readReports() => reports.values.toList();
  @override
  Future<void> save(IncidentReport report) async {
    if (failSave) throw StateError('disk full');
    events.add('save:${report.status.name}');
    reports[report.id] = report;
  }
}

class ControlledRemote implements IncidentRemoteStore {
  final feed = StreamController<List<IncidentReport>>.broadcast();
  final uploads = <IncidentReport>[];
  Object? failure;
  Completer<List<String>>? gate;
  String? watchedReporter;
  @override
  Stream<List<IncidentReport>> watchReports(String reporterId) {
    watchedReporter = reporterId;
    return feed.stream;
  }

  @override
  Future<List<String>> upload(IncidentReport report) async {
    uploads.add(report);
    if (failure != null) throw failure!;
    if (gate != null) return gate!.future;
    return ['https://res.cloudinary.com/demo/image/upload/photo.jpg'];
  }
}

void main() {
  group('SRP: draft validation and report conversion', () {
    test(
      'valid draft trims text and starts pending with installation identity',
      () {
        final report = validDraft().toReport('installation-1');
        expect(report.description, 'Injured elephant near the road');
        expect(report.locationName, 'Forest entrance');
        expect(report.reporterId, 'installation-1');
        expect(report.status, IncidentSyncStatus.pending);
      },
    );

    final invalidDrafts = <String, void Function(IncidentDraft)>{
      'missing type': (d) => d.type = null,
      'unknown type': (d) => d.type = 'Unknown',
      'missing latitude': (d) => d.latitude = null,
      'latitude out of range': (d) => d.latitude = 90.01,
      'longitude out of range': (d) => d.longitude = -180.01,
      'NaN coordinates': (d) => d.latitude = double.nan,
      'infinite coordinates': (d) => d.longitude = double.infinity,
      'blank description': (d) => d.description = '   ',
      'long description': (d) => d.description = 'a' * 501,
      'long landmark': (d) => d.locationName = 'a' * 201,
      'future time': (d) =>
          d.occurredAt = DateTime.now().add(const Duration(days: 1)),
      'empty photo': (d) => d.photos.add(
        IncidentPhoto(bytes: Uint8List(0), contentType: 'image/png'),
      ),
      'oversized photo': (d) => d.photos.add(
        IncidentPhoto(
          bytes: Uint8List(maxIncidentPhotoBytes + 1),
          contentType: 'image/png',
        ),
      ),
      'unsupported photo': (d) => d.photos.add(
        IncidentPhoto(bytes: Uint8List(1), contentType: 'image/gif'),
      ),
      'too many photos': (d) => d.photos.addAll(
        List.generate(
          4,
          (_) => IncidentPhoto(bytes: Uint8List(1), contentType: 'image/png'),
        ),
      ),
    };
    for (final entry in invalidDrafts.entries) {
      test('rejects ${entry.key} before report creation', () {
        final draft = validDraft();
        entry.value(draft);
        expect(draft.validate(), isNotNull);
        expect(() => draft.toReport('installation-1'), throwsArgumentError);
      });
    }
    test('accepts coordinate, text and photo count boundaries', () {
      final draft = validDraft()
        ..latitude = -90
        ..longitude = 180
        ..description = 'a' * 500
        ..locationName = 'a' * 200;
      draft.photos.addAll(
        List.generate(
          3,
          (_) => IncidentPhoto(bytes: Uint8List(1), contentType: 'image/webp'),
        ),
      );
      expect(draft.validate(), isNull);
      draft.latitude = 90;
      draft.longitude = -180;
      expect(draft.validate(), isNull);
    });
    test('local serialization retains photo bytes, URLs and failure state', () {
      final draft = validDraft();
      draft.photos.add(
        IncidentPhoto(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/png',
        ),
      );
      final report = draft
          .toReport('installation-1')
          .withSync(
            IncidentSyncStatus.failed,
            error: 'denied',
            photoUrls: ['https://example.com/photo'],
          );
      final restored = IncidentReport.fromLocalMap(report.toLocalMap());
      expect(restored.toLocalMap(), report.toLocalMap());
    });
  });

  group('DIP / ISP: repository uses separate injected storage contracts', () {
    late MemoryLocal local;
    late ControlledRemote remote;
    late IncidentRepository repository;
    setUp(() {
      local = MemoryLocal();
      remote = ControlledRemote();
      repository = IncidentRepository(local: local, remote: remote);
    });
    tearDown(() async {
      repository.dispose();
      await remote.feed.close();
    });
    test(
      'concurrent initialization opens storage once and watches its identity',
      () async {
        await Future.wait([repository.initialize(), repository.initialize()]);
        expect(local.initializations, 1);
        expect(remote.watchedReporter, 'installation-1');
        expect(repository.ready, isTrue);
      },
    );
    test('storage initialization can be retried after failure', () async {
      local.failInitialize = true;
      await expectLater(repository.initialize(), throwsStateError);
      expect(repository.ready, isFalse);
      expect(repository.loadError, isNotNull);
      local.failInitialize = false;
      await repository.initialize();
      expect(repository.ready, isTrue);
      expect(repository.loadError, isNull);
    });
    test('failed durable save prevents upload and success exposure', () async {
      local.failSave = true;
      await expectLater(repository.submit(validDraft()), throwsStateError);
      expect(remote.uploads, isEmpty);
      expect(repository.reports, isEmpty);
    });
    test(
      'upload waits for durable save and acknowledgement before success',
      () async {
        remote.gate = Completer<List<String>>();
        final submission = repository.submit(validDraft());
        await pumpEventQueue();
        expect(local.events, ['save:pending']);
        expect(repository.reports.single.status, IncidentSyncStatus.pending);
        expect(repository.syncing, isTrue);
        remote.gate!.complete(['https://example.com/photo']);
        final report = await submission;
        expect(report.status, IncidentSyncStatus.synchronized);
        expect(local.reports[report.id]!.photoUrls, [
          'https://example.com/photo',
        ]);
        expect(repository.pendingCount, 0);
        expect(repository.syncing, isFalse);
      },
    );
    test('invalid submission performs no write or upload', () async {
      await expectLater(
        repository.submit(validDraft()..description = ''),
        throwsArgumentError,
      );
      expect(local.events, isEmpty);
      expect(remote.uploads, isEmpty);
    });
    test('concurrent sync requests upload each pending report once', () async {
      final report = validDraft().toReport('installation-1');
      local.reports[report.id] = report;
      remote.gate = Completer<List<String>>();
      final first = repository.syncPending();
      final second = repository.syncPending();
      await pumpEventQueue();
      expect(remote.uploads, hasLength(1));
      remote.gate!.complete([]);
      final results = await Future.wait([first, second]);
      expect(results.every((result) => result.uploaded == 1), isTrue);
      expect(remote.uploads, hasLength(1));
    });
    test(
      'timeout preserves pending report and retry reuses report ID',
      () async {
        remote.failure = TimeoutException('offline');
        final saved = await repository.submit(validDraft());
        expect(saved.status, IncidentSyncStatus.pending);
        expect(local.reports.containsKey(saved.id), isTrue);
        remote.failure = null;
        final summary = await repository.syncPending();
        expect(summary.uploaded, 1);
        expect(summary.remaining, 0);
        expect(remote.uploads.map((r) => r.id), [saved.id, saved.id]);
      },
    );
    test(
      'permanent failure is skipped by automatic retry but retried explicitly',
      () async {
        remote.failure = StateError('invalid configuration');
        final saved = await repository.submit(validDraft());
        expect(saved.status, IncidentSyncStatus.failed);
        final automatic = await repository.syncPending(includeFailed: false);
        expect(automatic.uploaded, 0);
        expect(remote.uploads, hasLength(1));
        remote.failure = null;
        final manual = await repository.syncPending();
        expect(manual.uploaded, 1);
      },
    );
    test('partial photo upload retains bytes and URLs across retry', () async {
      final draft = validDraft();
      draft.photos.add(
        IncidentPhoto(bytes: Uint8List.fromList([1]), contentType: 'image/png'),
      );
      remote.failure = IncidentUploadFailure(TimeoutException('offline'), [
        'https://example.com/already-uploaded',
      ]);
      final saved = await repository.submit(draft);
      expect(saved.photos.single.bytes, [1]);
      expect(saved.photoUrls, ['https://example.com/already-uploaded']);
      remote.failure = null;
      await repository.syncPending();
      expect(remote.uploads.last.photoUrls, saved.photoUrls);
      expect(repository.reports.single.photos, isEmpty);
    });
    test('one upload failure does not stop other queued reports', () async {
      final a = validDraft().toReport('installation-1');
      final b = validDraft().toReport('installation-1');
      local.reports.addAll({a.id: a, b.id: b});
      remote.failure = TimeoutException('offline');
      final summary = await repository.syncPending();
      expect(remote.uploads, hasLength(2));
      expect(summary.failed, 2);
      expect(summary.remaining, 2);
      expect(repository.syncCompleted, 2);
    });
    test(
      'remote stream failure retains local reports and recovers on next feed',
      () async {
        final saved = validDraft().toReport('installation-1');
        local.reports[saved.id] = saved;
        await repository.initialize();
        remote.feed.addError(StateError('offline'));
        await pumpEventQueue();
        expect(repository.cloudError, isNotNull);
        expect(repository.reports.single.id, saved.id);
        remote.feed.add([]);
        await pumpEventQueue();
        expect(repository.cloudError, isNull);
        expect(repository.reports.single.id, saved.id);
      },
    );
  });
}
