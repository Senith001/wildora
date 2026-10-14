import 'dart:async';

import 'package:wildora/src/features/conflict_reporting/application/conflict_report_repository.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report_ports.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

class FakeReportStore implements ConflictReportStore {
  final Map<String, Map<String, dynamic>> saved = {};
  bool failSave = false;
  bool failLoad = false;
  int saves = 0;
  @override
  Future<List<ConflictReport>> load() async {
    if (failLoad) throw Exception('Disk unavailable');
    return saved.values.map(ConflictReport.fromMap).toList();
  }

  @override
  Future<void> save(ConflictReport report) async {
    saves++;
    if (failSave) throw Exception('Disk full');
    saved[report.id] = report.toMap();
  }
}

class FakeReportRemote implements ConflictReportRemote {
  final events = StreamController<List<ConflictReport>>.broadcast();
  final Map<String, ConflictReport> submitted = {};
  bool failSubmit = false;
  bool failReview = false;
  bool failResolve = false;
  Completer<void>? holdSubmit;
  int submissions = 0;
  int reviews = 0;
  int resolutions = 0;
  String? url;
  bool connected = false;
  ConflictReport? acknowledgement;
  @override
  Stream<ConflictReportFeed> watchSubmitted() => events.stream.map(
    (reports) => ConflictReportFeed(reports, isConnected: connected),
  );
  @override
  Future<ConflictReport> submit(ConflictReport report) async {
    submissions++;
    if (holdSubmit != null) await holdSubmit!.future;
    if (failSubmit) throw Exception('Network unavailable');
    submitted.putIfAbsent(report.id, () => report);
    return acknowledgement ??
        report.copyWith(
          syncStatus: SyncStatus.synced,
          reportStatus: ReportStatus.submitted,
          photoUrl: url,
        );
  }

  @override
  Future<void> review(ConflictReport report) async {
    reviews++;
    if (failReview) throw Exception('Permission denied');
  }

  @override
  Future<void> resolve(ConflictReport report, String notes) async {
    resolutions++;
    if (failResolve) throw Exception('Network unavailable');
  }
}

ConflictReport reportFixture({
  String id = 'test-1',
  SyncStatus sync = SyncStatus.pending,
  ReportStatus status = ReportStatus.savedOffline,
}) => ConflictReport(
  id: id,
  referenceNumber: 'HWC-$id',
  wildlifeType: WildlifeType.elephant,
  conflictType: ConflictType.cropRaiding,
  description: 'Elephant in farmland',
  latitude: 7.291,
  longitude: 80.635,
  locationDescription: 'Kandy (manual)',
  createdAt: DateTime.utc(2026, 10, 9),
  syncStatus: sync,
  reportStatus: status,
);

Future<ConflictReport> createFixture(
  ConflictReportRepository repository, {
  String description = ' Elephant in farmland ',
  double latitude = 7.291,
  double longitude = 80.635,
  String location = ' Kandy (manual) ',
}) => repository.create(
  wildlifeType: WildlifeType.elephant,
  conflictType: ConflictType.cropRaiding,
  description: description,
  latitude: latitude,
  longitude: longitude,
  locationDescription: location,
);
