import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/features/conflict_reporting/conflict_reporting.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/conflict_theme.dart';

import '../../unit/conflict_reporting/fakes.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'status colours distinguish workflow from delivery with readable text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Builder(
              builder: (context) {
                final surface = Theme.of(context).colorScheme.surface;
                final colours = [
                  context.syncStatusColor(SyncStatus.synced),
                  context.reportStatusColor(ReportStatus.submitted),
                  context.reportStatusColor(ReportStatus.resolved),
                  context.reportStatusColor(ReportStatus.underReview),
                ];
                expect(
                  colours.toSet().length,
                  4,
                  reason: 'Delivery, acceptance, review and resolution must be distinguishable.',
                );
                for (final colour in [
                  ...SyncStatus.values.map(context.syncStatusColor),
                  ...ReportStatus.values.map(context.reportStatusColor),
                ]) {
                  final background = Color.alphaBlend(
                    colour.withValues(alpha: .10),
                    surface,
                  );
                  expect(
                    contrast(colour, background),
                    greaterThanOrEqualTo(4.5),
                    reason: 'Status labels must remain readable on their tinted badge.',
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'report cards support narrow screens and enlarged text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = FakeReportStore();
        final remote = FakeReportRemote();
        final report = reportFixture().copyWith(isDemo: true);
        await store.save(report);
        final repository = ConflictReportRepository(
          store: store,
          remote: remote,
        );
        addTearDown(() async {
          repository.dispose();
          await remote.events.close();
        });
        await repository.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: ConflictFeatureTheme(
                child: MyConflictReportsScreen(repository: repository),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(report.referenceNumber), findsOneWidget);
        expect(find.text('Saved Offline'), findsOneWidget);
        expect(find.text('Pending Sync'), findsOneWidget);
        expect(find.text('Demo'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
