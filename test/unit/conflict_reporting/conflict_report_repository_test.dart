import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/application/conflict_report_repository.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

import 'fakes.dart';

void main() {
  late FakeReportStore store;
  late FakeReportRemote remote;
  late ConflictReportRepository repository;
  var sequence = 0;
  setUp(() {
    store = FakeReportStore();
    remote = FakeReportRemote();
    sequence = 0;
    repository = ConflictReportRepository(
      store: store,
      remote: remote,
      clock: () => DateTime.utc(2026, 10, 9),
      idGenerator: () => 'report-${++sequence}',
    );
  });
  tearDown(() async {
    repository.dispose();
    await remote.events.close();
  });

  test(
    'persists a pending report before returning a saved confirmation',
    () async {
      final report = await createFixture(repository);
      expect(report.description, 'Elephant in farmland');
      expect(report.locationDescription, 'Kandy (manual)');
      expect(report.reportStatus, ReportStatus.savedOffline);
      expect(report.syncStatus, SyncStatus.pending);
      expect(store.saved[report.id], report.toMap());
      expect(repository.pendingCount, 1);
      expect(remote.submissions, 0);
    },
  );

  test('failed local storage never exposes an unsaved report', () async {
    store.failSave = true;
    await expectLater(createFixture(repository), throwsException);
    expect(repository.reports, isEmpty);
    expect(remote.submissions, 0);
  });

  for (final input in ['', '   ', 'x' * 501]) {
    test(
      'rejects invalid description length ${input.length} before persistence',
      () async {
        await expectLater(
          createFixture(repository, description: input),
          throwsArgumentError,
        );
        expect(store.saves, 0);
        expect(repository.reports, isEmpty);
      },
    );
  }
  for (final latitude in [double.nan, double.infinity, -90.1, 90.1]) {
    test('rejects invalid latitude $latitude', () async {
      await expectLater(
        createFixture(repository, latitude: latitude),
        throwsArgumentError,
      );
      expect(store.saves, 0);
    });
  }
  test('rejects missing location and out-of-range longitude', () async {
    await expectLater(
      createFixture(repository, location: ' '),
      throwsArgumentError,
    );
    await expectLater(
      createFixture(repository, longitude: 181),
      throwsArgumentError,
    );
    expect(store.saves, 0);
  });

  test('unique IDs distinguish reports created at the same time', () async {
    final a = await createFixture(repository);
    final b = await createFixture(repository);
    expect(a.id, isNot(b.id));
    expect(a.referenceNumber, isNot(b.referenceNumber));
    expect(store.saved.length, 2);
  });

  test(
    'server acknowledgement updates status and persists attachment URL',
    () async {
      final report = await createFixture(repository);
      remote.url = 'https://example.test/photo';
      expect(await repository.sync(report), isTrue);
      final accepted = repository.current(report);
      expect(accepted.syncStatus, SyncStatus.synced);
      expect(accepted.reportStatus, ReportStatus.submitted);
      expect(accepted.photoUrl, remote.url);
      expect(store.saved[report.id]!['photoUrl'], remote.url);
      expect(repository.pendingCount, 0);
      expect(repository.synchronizedReports.single.id, report.id);
      expect(
        report.syncStatus,
        SyncStatus.pending,
        reason: 'old snapshots are immutable',
      );
    },
  );

  test(
    'failed upload retains durable pending data and can be retried',
    () async {
      final report = await createFixture(repository);
      remote.failSubmit = true;
      expect(await repository.sync(report), isFalse);
      expect(repository.current(report).syncStatus, SyncStatus.failed);
      expect(
        repository.current(report).reportStatus,
        ReportStatus.savedOffline,
      );
      expect(repository.synchronizedReports, isEmpty);
      expect(repository.errorMessage, contains('retry'));
      remote.failSubmit = false;
      expect(await repository.sync(report), isTrue);
      expect(remote.submitted.keys.toList(), [report.id]);
      expect(remote.submissions, 2);
    },
  );

  test('repeat sync of an accepted report issues no new upload', () async {
    final report = await createFixture(repository);
    await repository.sync(report);
    await repository.sync(report);
    expect(remote.submissions, 1);
  });

  test('concurrent sync taps cannot submit twice', () async {
    final report = await createFixture(repository);
    remote.holdSubmit = Completer<void>();
    final first = repository.sync(report);
    expect(repository.isBusy(report), isTrue);
    expect(await repository.sync(report), isFalse);
    expect(remote.submissions, 1);
    remote.holdSubmit!.complete();
    expect(await first, isTrue);
    expect(repository.isBusy(report), isFalse);
  });

  test('timeout remains retryable without claiming server receipt', () async {
    repository.dispose();
    repository = ConflictReportRepository(
      store: store,
      remote: remote,
      syncTimeout: const Duration(milliseconds: 1),
    );
    final report = await createFixture(repository);
    remote.holdSubmit = Completer<void>();
    expect(await repository.sync(report), isFalse);
    expect(repository.current(report).reportStatus, ReportStatus.savedOffline);
    expect(repository.isBusy(report), isFalse);
    remote.holdSubmit!.complete();
  });

  test(
    'failure saving an acknowledgement preserves retryable local state',
    () async {
      final report = await createFixture(repository);
      store.failSave = true;
      expect(await repository.sync(report), isFalse);
      expect(store.saved[report.id]!['syncStatus'], SyncStatus.pending.name);
      expect(repository.current(report).syncStatus, SyncStatus.failed);
      expect(repository.errorMessage, contains('retained'));
    },
  );

  test(
    'reloads interrupted sync and retains previously accepted reports',
    () async {
      await store.save(reportFixture(sync: SyncStatus.syncing));
      await store.save(
        reportFixture(
          id: 'accepted',
          sync: SyncStatus.synced,
          status: ReportStatus.submitted,
        ),
      );
      await repository.initialize();
      expect(repository.reports.length, 2);
      expect(repository.pendingCount, 1);
      expect(
        repository.current(reportFixture()).syncStatus,
        SyncStatus.pending,
      );
      await repository.syncPending();
      expect(remote.submissions, 1);
      expect(repository.pendingCount, 0);
    },
  );

  test('initialization failure is visible and retry can recover', () async {
    store.failLoad = true;
    await expectLater(repository.initialize(), throwsException);
    expect(repository.initialized, isFalse);
    expect(repository.errorMessage, contains('Retry'));
    store.failLoad = false;
    await repository.initialize();
    expect(repository.initialized, isTrue);
    expect(repository.errorMessage, isNull);
  });

  test('remote dashboard errors do not discard saved reports', () async {
    await createFixture(repository);
    remote.events.addError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.reports.length, 1);
    expect(repository.errorMessage, contains('retained'));
  });

  test(
    'dashboard combines local acceptance and reports from other devices',
    () async {
      final local = await createFixture(repository);
      await repository.sync(local);
      remote.events.add([
        reportFixture(
          id: 'other',
          sync: SyncStatus.synced,
          status: ReportStatus.submitted,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.synchronizedReports.length, 2);
      expect(
        repository.reports.length,
        1,
        reason: 'My Reports must remain local',
      );
    },
  );

  test('remote resolution updates existing My Reports snapshot', () async {
    final local = await createFixture(repository);
    await repository.sync(local);
    remote.events.add([
      repository
          .current(local)
          .copyWith(
            reportStatus: ReportStatus.resolved,
            responseNotes: 'Resolved remotely',
          ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.current(local).reportStatus, ReportStatus.resolved);
    expect(repository.current(local).responseNotes, 'Resolved remotely');
  });

  test('pending reports cannot enter officer review', () async {
    final report = await createFixture(repository);
    await expectLater(repository.markUnderReview(report), throwsStateError);
    expect(remote.reviews, 0);
  });

  test(
    'review and resolution require acknowledgement and nonblank notes',
    () async {
      final report = await createFixture(repository);
      await repository.sync(report);
      await expectLater(repository.resolve(report, '   '), throwsArgumentError);
      await expectLater(
        repository.resolve(report, 'Response'),
        throwsStateError,
      );
      await repository.markUnderReview(report);
      expect(repository.current(report).reportStatus, ReportStatus.underReview);
      expect(repository.current(report).reviewedAt, isNotNull);
      await repository.resolve(report, ' Ranger response recorded ');
      expect(repository.current(report).reportStatus, ReportStatus.resolved);
      expect(
        repository.current(report).responseNotes,
        'Ranger response recorded',
      );
      expect(repository.current(report).resolvedAt, isNotNull);
      expect(store.saved[report.id]!['reportStatus'], 'resolved');
      await expectLater(repository.markUnderReview(report), throwsStateError);
    },
  );

  test('failed officer update does not optimistically claim success', () async {
    final report = await createFixture(repository);
    await repository.sync(report);
    remote.failReview = true;
    await expectLater(repository.markUnderReview(report), throwsException);
    expect(repository.current(report).reportStatus, ReportStatus.submitted);
    expect(repository.isBusy(report), isFalse);
    remote.failReview = false;
    await repository.markUnderReview(report);
    remote.failResolve = true;
    await expectLater(repository.resolve(report, 'Response'), throwsException);
    expect(repository.current(report).reportStatus, ReportStatus.underReview);
  });

  test(
    'remote-only CLO report can be reviewed without joining My Reports',
    () async {
      await repository.initialize();
      final remoteReport = reportFixture(
        sync: SyncStatus.synced,
        status: ReportStatus.submitted,
      );
      remote.events.add([remoteReport]);
      await Future<void>.delayed(Duration.zero);
      await repository.markUnderReview(remoteReport);
      expect(
        repository.synchronizedReports.single.reportStatus,
        ReportStatus.underReview,
      );
      expect(repository.reports, isEmpty);
      expect(store.saved, isEmpty);
    },
  );
  test('reconnection automatically retries a saved outbox report', () async {
    final report = await createFixture(repository);
    remote.connected = false;
    remote.events.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(remote.submissions, 0);
    remote.connected = true;
    remote.events.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.isConnected, isTrue);
    expect(repository.current(report).syncStatus, SyncStatus.synced);
    expect(remote.submissions, 1);
    remote.events.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(
      remote.submissions,
      1,
      reason: 'Each snapshot must not trigger new sends',
    );
  });
  test(
    'acknowledgement of an earlier submission preserves server workflow',
    () async {
      final report = await createFixture(repository);
      remote.acknowledgement = report.copyWith(
        syncStatus: SyncStatus.synced,
        reportStatus: ReportStatus.resolved,
        responseNotes: 'Handled remotely',
      );
      await repository.sync(report);
      expect(repository.current(report).reportStatus, ReportStatus.resolved);
      expect(repository.current(report).responseNotes, 'Handled remotely');
    },
  );
  test('an unsaved report cannot enter the sync pipeline', () async {
    await expectLater(repository.sync(reportFixture()), throwsArgumentError);
    expect(remote.submissions, 0);
  });
  test('ID collision never overwrites an existing saved report', () async {
    repository.dispose();
    repository = ConflictReportRepository(
      store: store,
      remote: remote,
      idGenerator: () => 'collision',
    );
    final original = await createFixture(repository);
    await expectLater(
      createFixture(repository, description: 'Different incident'),
      throwsStateError,
    );
    expect(repository.reports.single.description, original.description);
    expect(store.saved.length, 1);
  });
  test(
    'remote response notes remain available after restarting offline',
    () async {
      final report = await createFixture(repository);
      await repository.sync(report);
      remote.events.add([
        repository
            .current(report)
            .copyWith(
              reportStatus: ReportStatus.resolved,
              responseNotes: 'Response from other device',
            ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        store.saved[report.id]!['responseNotes'],
        'Response from other device',
      );
      final restarted = ConflictReportRepository(store: store, remote: remote);
      await restarted.initialize();
      expect(restarted.reports.single.reportStatus, ReportStatus.resolved);
      expect(
        restarted.reports.single.responseNotes,
        'Response from other device',
      );
      restarted.dispose();
    },
  );
  test(
    'stale cached workflow cannot roll back a newer local resolution',
    () async {
      final report = await createFixture(repository);
      await repository.sync(report);
      await repository.markUnderReview(report);
      await repository.resolve(report, 'Response recorded');
      remote.events.add([
        report.copyWith(
          syncStatus: SyncStatus.synced,
          reportStatus: ReportStatus.submitted,
          updatedAt: report.createdAt.subtract(const Duration(days: 1)),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.current(report).reportStatus, ReportStatus.resolved);
      expect(repository.current(report).responseNotes, 'Response recorded');
    },
  );
  test('explicit demo reports in the server feed become durable My Reports entries', () async {
    await repository.initialize();
    final demo = reportFixture(id: 'demo').copyWith(
      isDemo: true,
      syncStatus: SyncStatus.synced,
      reportStatus: ReportStatus.submitted,
    );
    remote.events.add([demo]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.reports.single.isDemo, isTrue);
    expect(store.saved['demo']!['isDemo'], isTrue);
    expect(remote.submissions, 0);
  });
}
