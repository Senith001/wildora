import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

import 'fakes.dart';

void main() {
  test(
    'serialization round trip preserves attachment and workflow timestamps',
    () {
      final now = DateTime.utc(2026, 10, 9);
      final report = ConflictReport(
        id: 'test-1',
        referenceNumber: 'HWC-test-1',
        wildlifeType: WildlifeType.leopard,
        conflictType: ConflictType.animalSighting,
        description: 'Leopard near village',
        latitude: 7,
        longitude: 80,
        locationDescription: 'Village (GPS)',
        createdAt: now,
        photoPath: 'evidence.png',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoUrl: 'https://example.test/photo',
        photoContentType: 'image/png',
        reportStatus: ReportStatus.resolved,
        syncStatus: SyncStatus.synced,
        reviewedBy: 'officer-1',
        responseNotes: 'Response recorded',
        reviewedAt: now,
        resolvedAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );
      expect(ConflictReport.fromMap(report.toMap()).toMap(), report.toMap());
      expect(
        report.toMap(includePhotoBytes: false).containsKey('photoBytes'),
        isFalse,
      );
    },
  );
  test('minimal round trip has nullable attachment and response fields', () {
    final report = reportFixture();
    expect(ConflictReport.fromMap(report.toMap()).toMap(), report.toMap());
  });
  test('copy creates a new snapshot retaining all omitted values', () {
    final report = reportFixture();
    expect(report.copyWith().toMap(), report.toMap());
    final changed = report.copyWith(syncStatus: SyncStatus.synced);
    expect(changed.syncStatus, SyncStatus.synced);
    expect(report.syncStatus, SyncStatus.pending);
  });
  test('rejects unsafe file IDs and invalid photo sizes', () {
    expect(reportFixture(id: '../escape').validate, throwsArgumentError);
    final map = reportFixture().toMap()..['photoBytes'] = '';
    expect(() => ConflictReport.fromMap(map), throwsArgumentError);
  });
  test('coordinate boundary values are valid', () {
    final map = reportFixture().toMap()
      ..['latitude'] = -90
      ..['longitude'] = 180;
    expect(() => ConflictReport.fromMap(map), returnsNormally);
  });
  test('all report labels are readable', () {
    for (final value in [
      ...WildlifeType.values,
      ...ConflictType.values,
      ...ReportStatus.values,
      ...SyncStatus.values,
    ]) {
      expect(value.label, isNotEmpty);
    }
    expect(SyncStatus.failed.label, 'Sync Failed');
    expect(ConflictType.cropRaiding.label, 'Crop Raiding');
  });
  test(
    'attachment snapshots cannot be mutated through the input or report',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final report = ConflictReport(
        id: 'immutable',
        referenceNumber: 'HWC-immutable',
        wildlifeType: WildlifeType.elephant,
        conflictType: ConflictType.cropRaiding,
        description: 'Incident',
        latitude: 7,
        longitude: 80,
        locationDescription: 'Village',
        createdAt: DateTime.utc(2026),
        photoBytes: bytes,
      );
      bytes[0] = 9;
      expect(report.photoBytes![0], 1);
      expect(() => report.photoBytes![0] = 9, throwsUnsupportedError);
    },
  );
}
