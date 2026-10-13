import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/conflict_reporting.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/conflict_report_photo.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/conflict_photo_scope.dart';

import '../../unit/conflict_reporting/fakes.dart';

import 'package:wildora/src/features/conflict_reporting/domain/conflict_report_ports.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOYeWbmfwAG/gL+8h1avgAAAABJRU5ErkJggg==',
);

class TestPrivatePhoto implements ConflictPhotoDownloader {
  int downloads = 0;
  bool fail = false;
  Completer<List<int>>? pending;
  @override
  Future<List<int>> download(String url) async {
    downloads++;
    if (fail) throw Exception('Denied');
    return pending == null ? _photo : pending!.future;
  }

  @override
  bool canDownload(String url) => true;
}

void main() {
  testWidgets(
    'scoped image reader works without a concrete backend dependency',
    (tester) async {
      final reader = TestPrivatePhoto();
      final report = reportFixture().copyWith(
        photoUrl: 'https://photos.example/private',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictPhotoScope(
              downloader: reader,
              child: ConflictReportPhoto(report: report),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reader.downloads, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
    },
  );

  testWidgets('private download shows loading and does not repeat on rebuild', (
    tester,
  ) async {
    final service = TestPrivatePhoto()..pending = Completer<List<int>>();
    final report = reportFixture().copyWith(
      photoUrl: 'https://photos.example/private',
    );
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConflictReportPhoto(report: report, photoRemote: service),
        ),
      ),
    );
    await show();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await show();
    expect(service.downloads, 1);
    service.pending!.complete(_photo);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed private download can be retried after access returns', (
    tester,
  ) async {
    final service = TestPrivatePhoto()..fail = true;
    final report = reportFixture().copyWith(
      photoUrl: 'https://photos.example/private',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConflictReportPhoto(report: report, photoRemote: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    service.fail = false;
    await tester.tap(find.text('Retry photo'));
    await tester.pumpAndSettle();
    expect(service.downloads, 2);
    expect(find.byType(Image), findsOneWidget);
  });

  for (final clo in [false, true]) {
    final screen = clo ? 'CLO review' : 'report details';
    testWidgets('$screen shows locally saved photo after sync and reload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FakeReportStore();
      final remote = FakeReportRemote();
      final repository = ConflictReportRepository(store: store, remote: remote);
      final report = await repository.create(
        wildlifeType: WildlifeType.elephant,
        conflictType: ConflictType.cropRaiding,
        description: 'Test photograph',
        latitude: 7.291,
        longitude: 80.635,
        locationDescription: 'Test location',
        photoBytes: _photo,
        photoContentType: 'image/png',
      );
      expect(await repository.sync(report), isTrue);
      repository.dispose();
      final restored = ConflictReportRepository(store: store, remote: remote);
      await restored.initialize();
      addTearDown(() async {
        restored.dispose();
        await remote.events.close();
      });
      final saved = restored.reports.single;
      await tester.pumpWidget(
        MaterialApp(
          home: clo
              ? CloReviewScreen(report: saved, repository: restored)
              : ConflictDetailsScreen(report: saved, repository: restored),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Incident photo'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, orderedEquals(_photo));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$screen explains a photo missing from this device', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = reportFixture(
        sync: SyncStatus.synced,
        status: ReportStatus.submitted,
      ).copyWith(photoDeliveryStatus: 'deviceOnly');
      final store = FakeReportStore();
      await store.save(report);
      final remote = FakeReportRemote();
      final repository = ConflictReportRepository(store: store, remote: remote);
      addTearDown(() async {
        repository.dispose();
        await remote.events.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: clo
              ? CloReviewScreen(report: report, repository: repository)
              : ConflictDetailsScreen(report: report, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not available here'), findsOneWidget);
      expect(find.text('No photo attached.'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  }

  testWidgets('reports without a photo show explicit optional-photo state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConflictReportPhoto(report: reportFixture())),
      ),
    );
    expect(find.text('No photo attached.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'local photo discloses that it was not delivered to other devices',
    (tester) async {
      final report = ConflictReport(
        id: 'photo-local',
        referenceNumber: 'HWC-photo-local',
        wildlifeType: WildlifeType.elephant,
        conflictType: ConflictType.cropRaiding,
        description: 'Test',
        latitude: 7,
        longitude: 80,
        locationDescription: 'Test',
        createdAt: DateTime.utc(2026),
        photoBytes: _photo,
        photoDeliveryStatus: 'deviceOnly',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConflictReportPhoto(report: report)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('has not been delivered'), findsOneWidget);
    },
  );

  testWidgets('invalid local image displays recovery text without crashing', (
    tester,
  ) async {
    final report = ConflictReport(
      id: 'photo-invalid',
      referenceNumber: 'HWC-photo-invalid',
      wildlifeType: WildlifeType.elephant,
      conflictType: ConflictType.cropRaiding,
      description: 'Test',
      latitude: 7,
      longitude: 80,
      locationDescription: 'Test',
      createdAt: DateTime.utc(2026),
      photoBytes: Uint8List.fromList([1, 2, 3]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConflictReportPhoto(report: report)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('remote photo URL is used and a failed download gives feedback', (
    tester,
  ) async {
    final report = reportFixture().copyWith(
      photoUrl: 'https://example.invalid/incident.png',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConflictReportPhoto(report: report)),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'https://example.invalid/incident.png',
    );
    // Flutter's widget-test HTTP client returns 400 without making a network call.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
