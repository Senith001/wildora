import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/wildlife-incident/application/incident_access.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_report.dart';
import 'package:wildora/src/features/wildlife-incident/incident_reports_screen.dart';
import 'package:wildora/src/features/wildlife-incident/incident_sync_screen.dart';

// Neither screen requires the concrete IncidentRepository or unrelated methods.
class ReportReader extends ChangeNotifier implements IncidentReportReader {
  @override
  List<IncidentReport> get reports => [];
  @override
  String? get cloudError => null;
}

class SyncAccess extends ChangeNotifier implements IncidentSyncAccess {
  int calls = 0;
  @override
  int get pendingCount => 1;
  @override
  bool get syncing => false;
  @override
  int get syncCompleted => 0;
  @override
  int get syncTotal => 1;
  @override
  String? get cloudError => null;
  @override
  Future<IncidentSyncSummary> syncPending({bool includeFailed = true}) async {
    calls++;
    return const IncidentSyncSummary(uploaded: 1, failed: 0, remaining: 0);
  }
}

void main() {
  testWidgets('reports screen accepts a read-only dependency', (tester) async {
    final reader = ReportReader();
    await tester.pumpWidget(
      MaterialApp(home: IncidentReportsScreen(repository: reader)),
    );
    expect(find.text('No reports in this category.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    reader.dispose();
  });
  testWidgets('sync screen invokes only its sync contract', (tester) async {
    final sync = SyncAccess();
    await tester.pumpWidget(
      MaterialApp(home: IncidentSyncScreen(repository: sync)),
    );
    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();
    expect(sync.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    sync.dispose();
  });
}
