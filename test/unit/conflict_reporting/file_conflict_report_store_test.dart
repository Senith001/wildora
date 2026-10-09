import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/data/file_conflict_report_store.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FileConflictReportStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wildora-store-test-');
    store = FileConflictReportStore(directory: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('empty storage loads no reports', () async {
    expect(await store.load(), isEmpty);
  });
  test(
    'reports survive a new store instance and updates replace the same ID',
    () async {
      final report = reportFixture();
      await store.save(report);
      await store.save(
        report.copyWith(
          syncStatus: SyncStatus.synced,
          reportStatus: ReportStatus.submitted,
        ),
      );
      final reloaded = await FileConflictReportStore(
        directory: () async => directory,
      ).load();
      expect(reloaded.length, 1);
      expect(reloaded.single.syncStatus, SyncStatus.synced);
      expect(reloaded.single.reportStatus, ReportStatus.submitted);
      expect(
        await File('${directory.path}/conflict_reports/test-1.json.tmp')
            .exists(),
        isFalse,
      );
    },
  );
  test('uncommitted temporary files are ignored', () async {
    await store.save(reportFixture());
    await File('${directory.path}/conflict_reports/interrupted.json.tmp')
        .writeAsString('{incomplete');
    expect((await store.load()).length, 1);
  });
  test(
    'corrupt saved data fails explicitly rather than erasing report history',
    () async {
      await store.save(reportFixture());
      await File('${directory.path}/conflict_reports/test-1.json')
          .writeAsString('broken');
      await expectLater(store.load(), throwsFormatException);
    },
  );
  test(
    'unavailable directory cannot be acknowledged as a successful save',
    () async {
      final file = File('${directory.path}/file');
      await file.writeAsString('not a directory');
      final invalid = FileConflictReportStore(
        directory: () async => Directory(file.path),
      );
      await expectLater(
        invalid.save(reportFixture()),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}
