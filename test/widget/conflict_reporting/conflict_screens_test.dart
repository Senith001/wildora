import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wildora/src/features/conflict_reporting/conflict_reporting.dart';
import 'package:wildora/src/features/conflict_reporting/application/incident_location_service.dart';
import 'package:wildora/src/features/conflict_reporting/application/incident_photo_service.dart';

import '../../unit/conflict_reporting/fakes.dart';

class FakeLocationService implements IncidentLocationService {
  bool fail = false;
  @override
  Future<IncidentLocation> currentLocation() async {
    if (fail) {
      throw const LocationUnavailable('Enable GPS or enter coordinates.');
    }
    return const IncidentLocation(7.291, 80.635, accuracy: 12);
  }
}

class NoPhotoService implements IncidentPhotoService {
  @override
  Future<IncidentPhoto?> select(ImageSource source) async => null;
}

void main() {
  late FakeReportStore store;
  late FakeReportRemote remote;
  late ConflictReportRepository repository;
  late FakeLocationService location;
  setUp(() {
    store = FakeReportStore();
    remote = FakeReportRemote();
    repository = ConflictReportRepository(
      store: store,
      remote: remote,
      idGenerator: () => 'widget-report',
    );
    location = FakeLocationService();
  });
  tearDown(() async {
    repository.dispose();
    await remote.events.close();
  });

  Future<void> form(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ConflictReportFormScreen(
          repository: repository,
          locationService: location,
          photoService: NoPhotoService(),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => ConflictConfirmationScreen(
            report: settings.arguments! as ConflictReport,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<ConflictType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop Raiding').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<WildlifeType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elephant').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Elephant in farmland');
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();
  }

  testWidgets('invalid submission shows inline errors and never saves', (
    tester,
  ) async {
    await form(tester);
    await tester.tap(find.text('Submit Conflict Report'));
    await tester.pumpAndSettle();
    expect(find.text('Select a conflict type'), findsOneWidget);
    expect(find.text('Select a wildlife type'), findsOneWidget);
    expect(find.text('Describe the incident'), findsOneWidget);
    expect(find.textContaining('Use GPS or enter'), findsOneWidget);
    expect(store.saved, isEmpty);
    expect(remote.submissions, 0);
  });

  testWidgets('GPS failure exposes recovery without demo coordinates', (
    tester,
  ) async {
    location.fail = true;
    await form(tester);
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();
    expect(find.text('Enable GPS or enter coordinates.'), findsOneWidget);
    expect(find.text('No incident coordinates selected.'), findsOneWidget);
    expect(find.textContaining('6.927'), findsNothing);
  });

  testWidgets(
    'manual location rejects invalid coordinates and updates actual coordinates',
    (tester) async {
      await form(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Village');
      await tester.enterText(fields.at(1), '100');
      await tester.enterText(fields.at(2), '80.635');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('between -90'), findsOneWidget);
      await tester.enterText(fields.at(1), '7.291');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Village (manual)'), findsOneWidget);
      expect(find.text('7.291, 80.635'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('optional photo is not required for acknowledged submission', (
    tester,
  ) async {
    await form(tester);
    await fill(tester);
    await tester.tap(find.text('Submit Conflict Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report Submitted'), findsOneWidget);
    expect(
      find.textContaining('Notification has not been confirmed'),
      findsOneWidget,
    );
    expect(repository.reports.single.photoBytes, isNull);
    expect(repository.reports.single.syncStatus, SyncStatus.synced);
    expect(remote.submissions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed sending shows saved confirmation and pending sync', (
    tester,
  ) async {
    remote.failSubmit = true;
    await form(tester);
    await fill(tester);
    await tester.tap(find.text('Submit Conflict Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report Saved'), findsOneWidget);
    expect(find.text('Pending Sync'), findsOneWidget);
    expect(find.textContaining('after it is sent'), findsOneWidget);
    expect(repository.pendingCount, 1);
    expect(store.saved.length, 1);
  });

  testWidgets(
    'local save failure retains entries and shows no saved confirmation',
    (tester) async {
      store.failSave = true;
      await form(tester);
      await fill(tester);
      await tester.tap(find.text('Submit Conflict Report'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save your report'), findsOneWidget);
      expect(find.text('Report Saved'), findsNothing);
      expect(find.text('Elephant in farmland'), findsOneWidget);
      expect(remote.submissions, 0);
    },
  );

  testWidgets('CLO resolution is unavailable until report is under review', (
    tester,
  ) async {
    final report = await createFixture(repository);
    await repository.sync(report);
    await tester.pumpWidget(
      MaterialApp(
        home: CloReviewScreen(report: report, repository: repository),
      ),
    );
    expect(find.text('Record Response & Resolve'), findsNothing);
    await tester.tap(find.text('Mark Under Review'));
    await tester.pumpAndSettle();
    expect(find.text('Under Review'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record Response & Resolve'));
    await tester.tap(find.text('Record Response & Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Enter response notes first.'), findsOneWidget);
    expect(remote.resolutions, 0);
    await tester.enterText(find.byType(TextField), 'Response completed');
    await tester.ensureVisible(find.text('Record Response & Resolve'));
    await tester.tap(find.text('Record Response & Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Record Response & Resolve'), findsNothing);
    expect(remote.resolutions, 1);
  });

  testWidgets('details refresh after retry succeeds', (tester) async {
    final report = await createFixture(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: ConflictDetailsScreen(report: report, repository: repository),
      ),
    );
    expect(find.text('Retry Sync'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Sync'));
    await tester.pumpAndSettle();
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Retry Sync'), findsNothing);
  });
}
