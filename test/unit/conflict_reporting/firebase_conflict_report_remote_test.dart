import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/data/firebase_conflict_report_remote.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

import 'fakes.dart';

import 'package:wildora/src/features/conflict_reporting/application/conflict_session.dart';

class TestSession implements ConflictSession {
  bool allowed = true;
  bool demo = false;
  @override
  Future<String> reporterId() async => 'test-reporter';
  @override
  Future<bool> isClo() async => allowed;
  @override
  Future<bool> isDemo() async => demo;
  @override
  Future<void> signInClo(String email, String password) async {}
}

class TestMetadata extends Fake implements SnapshotMetadata {
  TestMetadata({this.cached = false, this.pending = false});
  final bool cached;
  final bool pending;
  @override
  bool get isFromCache => cached;
  @override
  bool get hasPendingWrites => pending;
}

// Firebase marks these interfaces sealed; this scoped fake exercises the
// gateway contract without inheriting production implementation behavior.
// ignore: subtype_of_sealed_class
class TestDocument<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  TestDocument(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

// Firebase marks these interfaces sealed; this scoped fake exercises the
// gateway contract without inheriting production implementation behavior.
// ignore: subtype_of_sealed_class
class TestQueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestQueryDocument(this.value, {bool pending = false})
    : metadata = TestMetadata(pending: pending);
  final Map<String, dynamic> value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic> data() => value;
}

class TestQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  TestQuerySnapshot(this.docs, {bool cached = false})
    : metadata = TestMetadata(cached: cached);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

// Firebase marks these interfaces sealed; this scoped fake exercises the
// gateway contract without inheriting production implementation behavior.
// ignore: subtype_of_sealed_class
class TestReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  TestReference(this.id);
  @override
  final String id;
}

// Firebase marks these interfaces sealed; this scoped fake exercises the
// gateway contract without inheriting production implementation behavior.
// ignore: subtype_of_sealed_class
class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final events =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  final _metadataRequests = <bool>[];
  bool get metadataRequested => _metadataRequests.last;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      TestReference(path!);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _metadataRequests.add(includeMetadataChanges);
    return events.stream;
  }
}

class TestTransaction extends Fake implements Transaction {
  TestTransaction(this.records);
  final Map<String, Map<String, dynamic>> records;
  int writes = 0;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => TestDocument<T>(records[ref.id] as T?);
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes++;
    records[ref.id] = Map<String, dynamic>.from(data as Map<String, dynamic>);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    writes++;
    records[ref.id]!.addAll(data.cast<String, dynamic>());
    return this;
  }
}

class TestFirestore extends Fake implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{};
  final reports = TestCollection();
  late final transaction = TestTransaction(records);
  bool fail = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    expect(collectionPath, 'conflictReports');
    return reports;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (fail) throw Exception('Firestore unavailable');
    return handler(transaction);
  }
}

class TestTaskSnapshot extends Fake implements TaskSnapshot {}

class TestUploadTask extends Fake implements UploadTask {
  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) =>
      Future<TaskSnapshot>.value(TestTaskSnapshot())
          .then(onValue, onError: onError);
}

class TestStorageReference extends Fake implements Reference {
  bool fail = false;
  int uploads = 0;
  Uint8List? bytes;
  SettableMetadata? metadata;
  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    uploads++;
    if (fail) throw Exception('Upload failed');
    bytes = data;
    this.metadata = metadata;
    return TestUploadTask();
  }

  @override
  Future<String> getDownloadURL() async => 'https://example.test/photo';
}

class TestStorage extends Fake implements FirebaseStorage {
  final photo = TestStorageReference();
  String? path;
  @override
  Reference ref([String? path]) {
    this.path = path;
    return photo;
  }
}

void main() {
  late TestFirestore firestore;
  late TestStorage storage;
  late FirebaseConflictReportRemote remote;
  setUp(() {
    firestore = TestFirestore();
    storage = TestStorage();
    remote = FirebaseConflictReportRemote(
      firestore: firestore,
      storage: storage,
      session: TestSession(),
    );
  });
  tearDown(() async => firestore.reports.events.close());

  ConflictReport withPhoto() => ConflictReport.fromMap(
    reportFixture().toMap()
      ..['photoBytes'] = '/9j/4A=='
      ..['photoContentType'] = 'image/jpeg',
  );

  test(
    'submits without optional photo and omits image bytes from Firestore',
    () async {
      final accepted = await remote.submit(reportFixture());
      expect(accepted.syncStatus, SyncStatus.synced);
      expect(accepted.reportStatus, ReportStatus.submitted);
      expect(storage.photo.uploads, 0);
      expect(firestore.records['test-1']!.containsKey('photoBytes'), isFalse);
    },
  );
  test(
    'uploads actual bytes to stable path before recording download URL',
    () async {
      final accepted = await remote.submit(withPhoto());
      expect(storage.path, 'conflictReports/test-1/photo');
      expect(storage.photo.bytes, withPhoto().photoBytes);
      expect(storage.photo.metadata!.contentType, 'image/jpeg');
      expect(accepted.photoUrl, 'https://example.test/photo');
      expect(firestore.records['test-1']!['photoUrl'], accepted.photoUrl);
      expect(firestore.records['test-1']!.containsKey('photoBytes'), isFalse);
    },
  );
  test('upload failure cannot create a server report', () async {
    storage.photo.fail = true;
    await expectLater(remote.submit(withPhoto()), throwsException);
    expect(firestore.records, isEmpty);
  });
  test('database failure cannot produce an accepted report', () async {
    firestore.fail = true;
    await expectLater(remote.submit(reportFixture()), throwsException);
    expect(firestore.records, isEmpty);
  });
  test(
    'retry does not overwrite review or resolution already on the server',
    () async {
      final resolved = reportFixture(
        sync: SyncStatus.synced,
        status: ReportStatus.resolved,
      ).copyWith(responseNotes: 'Already handled');
      firestore.records[resolved.id] = resolved.toMap(includePhotoBytes: false);
      final accepted = await remote.submit(reportFixture());
      expect(accepted.reportStatus, ReportStatus.resolved);
      expect(accepted.responseNotes, 'Already handled');
      expect(firestore.transaction.writes, 0);
    },
  );
  test(
    'review and resolution use guarded transactions and persist notes',
    () async {
      final accepted = await remote.submit(reportFixture());
      await remote.review(accepted);
      expect(firestore.records[accepted.id]!['reportStatus'], 'underReview');
      expect(firestore.records[accepted.id]!['reviewedAt'], isNotNull);
      await remote.resolve(accepted, 'Response recorded');
      expect(firestore.records[accepted.id]!['reportStatus'], 'resolved');
      expect(
        firestore.records[accepted.id]!['responseNotes'],
        'Response recorded',
      );
      expect(firestore.records[accepted.id]!['resolvedAt'], isNotNull);
      await expectLater(remote.review(accepted), throwsStateError);
      await expectLater(remote.resolve(accepted, 'Again'), throwsStateError);
    },
  );
  test(
    'feed distinguishes cached data and excludes unacknowledged writes',
    () async {
      final feeds = [];
      final subscription = remote.watchSubmitted().listen(feeds.add);
      await Future<void>.delayed(Duration.zero);
      expect(firestore.reports.metadataRequested, isTrue);
      firestore.reports.events.add(
        TestQuerySnapshot([
          TestQueryDocument(
            reportFixture(
              id: 'acknowledged',
              sync: SyncStatus.synced,
              status: ReportStatus.submitted,
            ).toMap(),
          ),
          TestQueryDocument(
            reportFixture(id: 'unacknowledged').toMap(),
            pending: true,
          ),
        ], cached: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(feeds.single.isConnected, isFalse);
      expect(feeds.single.reports.length, 1);
      firestore.reports.events.add(TestQuerySnapshot([], cached: false));
      await Future<void>.delayed(Duration.zero);
      expect(feeds.last.isConnected, isTrue);
      await subscription.cancel();
    },
  );
  test(
    'free-plan mode accepts report while retaining attachment on device',
    () async {
      final gateway = FirebaseConflictReportRemote(
        firestore: firestore,
        storage: storage,
        session: TestSession(),
        uploadPhotos: false,
      );
      final accepted = await gateway.submit(withPhoto());
      expect(accepted.reportStatus, ReportStatus.submitted);
      expect(accepted.photoDeliveryStatus, 'deviceOnly');
      expect(storage.photo.uploads, 0);
      expect(firestore.records['test-1']!['reporterId'], 'test-reporter');
    },
  );
  test(
    'a member cannot invoke an officer transition through the gateway',
    () async {
      final session = TestSession()..allowed = false;
      final gateway = FirebaseConflictReportRemote(
        firestore: firestore,
        storage: storage,
        session: session,
      );
      await expectLater(
        gateway.review(reportFixture()),
        throwsA(isA<CloAccessDenied>()),
      );
      expect(firestore.transaction.writes, 0);
    },
  );
  test('the training CLO cannot review a real incident', () async {
    final session = TestSession()..demo = true;
    final gateway = FirebaseConflictReportRemote(
      firestore: firestore,
      storage: storage,
      session: session,
    );
    await expectLater(
      gateway.review(reportFixture()),
      throwsA(isA<CloAccessDenied>()),
    );
    expect(firestore.transaction.writes, 0);
  });
}
