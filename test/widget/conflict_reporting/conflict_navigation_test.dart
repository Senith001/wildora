import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/conflict_reporting.dart';

import '../../unit/conflict_reporting/fakes.dart';

void main() {
  late FakeReportStore store;
  late FakeReportRemote remote;
  late ConflictReportRepository repository;
  late List<RouteSettings> visited;
  setUp(() {
    store = FakeReportStore();
    remote = FakeReportRemote();
    repository = ConflictReportRepository(store: store, remote: remote);
    visited = [];
  });
  tearDown(() async {
    repository.dispose();
    await remote.events.close();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        home: screen,
        onGenerateRoute: (settings) {
          visited.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('Opened ${settings.name}')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in {
    'Start report': '/conflict/report',
    'My Reports (0)': '/conflict/reports',
    'CLO Dashboard': '/conflict/clo',
  }.entries) {
    testWidgets('home opens ${entry.value}', (tester) async {
      await pump(tester, ConflictReportingHome(repository: repository));
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(visited.last.name, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'home displays pending count and retry clears it on acknowledgement',
    (tester) async {
      await createFixture(repository);
      await pump(tester, ConflictReportingHome(repository: repository));
      expect(find.text('1 report(s) waiting to sync.'), findsOneWidget);
      await tester.tap(find.text('Sync'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reports are confirmed only after server receipt.'),
        findsOneWidget,
      );
      expect(remote.submissions, 1);
    },
  );
  testWidgets('home exposes loading failure and supports retry', (
    tester,
  ) async {
    store.failLoad = true;
    await pump(tester, ConflictReportingHome(repository: repository));
    expect(find.textContaining('Could not load saved reports'), findsOneWidget);
    store.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.initialized, isTrue);
  });
  testWidgets('history shows empty state then saved and submitted status', (
    tester,
  ) async {
    await pump(tester, MyConflictReportsScreen(repository: repository));
    expect(find.text('No reports yet.'), findsOneWidget);
    final report = await createFixture(repository);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved Offline'), findsOneWidget);
    await repository.sync(report);
    await tester.pumpAndSettle();
    expect(find.textContaining('Submitted'), findsOneWidget);
    await tester.tap(find.text(report.referenceNumber));
    await tester.pumpAndSettle();
    expect(visited.last.name, '/conflict/details');
    expect((visited.last.arguments! as ConflictReport).id, report.id);
  });
  testWidgets(
    'CLO dashboard excludes pending reports and opens accepted report review',
    (tester) async {
      final report = await createFixture(repository);
      await pump(tester, CloDashboardScreen(repository: repository));
      expect(
        find.text('No synchronized reports are available for review.'),
        findsOneWidget,
      );
      expect(find.text(report.referenceNumber), findsNothing);
      await repository.sync(report);
      await tester.pumpAndSettle();
      expect(find.text(report.referenceNumber), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text(report.referenceNumber));
      await tester.pumpAndSettle();
      expect(visited.last.name, '/conflict/clo/review');
      expect((visited.last.arguments! as ConflictReport).id, report.id);
    },
  );
  testWidgets(
    'confirmation wraps long locations and reference IDs on a small display',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = ConflictReport.fromMap(
        reportFixture().toMap()
          ..['referenceNumber'] = 'HWC-1791594316401853-5AFE0886'
          ..['locationDescription'] = 'A long village name near the northern road and farmland (manual)',
      );
      await pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: ConflictConfirmationScreen(report: report),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Done'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(visited.last.name, '/conflict');
    },
  );
  testWidgets('direct history navigation restores durable saved reports', (
    tester,
  ) async {
    await store.save(reportFixture(id: 'restored'));
    await pump(tester, MyConflictReportsScreen(repository: repository));
    expect(find.text('HWC-restored'), findsOneWidget);
    expect(find.text('No reports yet.'), findsNothing);
  });
  testWidgets(
    'direct history load failure offers recovery instead of empty history',
    (tester) async {
      store.failLoad = true;
      await pump(tester, MyConflictReportsScreen(repository: repository));
      expect(
        find.textContaining('Could not load saved reports'),
        findsOneWidget,
      );
      expect(find.text('No reports yet.'), findsNothing);
      store.failLoad = false;
      await store.save(reportFixture(id: 'restored'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('HWC-restored'), findsOneWidget);
    },
  );
}
