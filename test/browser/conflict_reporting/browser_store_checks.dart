import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:wildora/src/features/conflict_reporting/data/web_conflict_report_store.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

import '../../unit/conflict_reporting/fakes.dart';

void main() {
  const id = 'browser-store-check';
  const key = 'wildora.conflict.$id';
  setUp(() => web.window.localStorage.removeItem(key));
  tearDown(() => web.window.localStorage.removeItem(key));

  test(
    'browser reports persist across adapter instances and updates',
    () async {
      final report = reportFixture(id: id);
      await BrowserConflictReportStore().save(report);
      await BrowserConflictReportStore().save(
        report.copyWith(
          syncStatus: SyncStatus.synced,
          reportStatus: ReportStatus.submitted,
        ),
      );
      final reports = await BrowserConflictReportStore().load();
      final restored = reports.where((r) => r.id == id).single;
      expect(restored.syncStatus, SyncStatus.synced);
      expect(restored.reportStatus, ReportStatus.submitted);
    },
  );
  test('unrelated site storage is excluded', () async {
    const other = 'wildora-browser-check-unrelated';
    web.window.localStorage.setItem(other, 'not report JSON');
    try {
      expect(await BrowserConflictReportStore().load(), isEmpty);
    } finally {
      web.window.localStorage.removeItem(other);
    }
  });
  test('invalid reports are rejected before browser persistence', () async {
    await expectLater(
      BrowserConflictReportStore().save(reportFixture(id: '../unsafe')),
      throwsArgumentError,
    );
    expect(
      web.window.localStorage.getItem('wildora.conflict.../unsafe'),
      isNull,
    );
  });
}
