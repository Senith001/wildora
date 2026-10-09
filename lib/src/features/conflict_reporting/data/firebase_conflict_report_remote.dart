import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/conflict_report.dart';
import '../application/conflict_session.dart';
import '../domain/conflict_report_ports.dart';

/// Report IDs and attachment paths remain stable across retries. A report is
/// acknowledged only after both Storage and Firestore have completed.
class FirebaseConflictReportRemote implements ConflictReportRemote {
  FirebaseConflictReportRemote({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ConflictSession? session,
    this.uploadPhotos = true,
  }) : _providedFirestore = firestore,
       _providedStorage = storage,
       _session = session ?? FirebaseConflictSession();

  final bool uploadPhotos;
  final ConflictSession _session;
  final FirebaseFirestore? _providedFirestore;
  final FirebaseStorage? _providedStorage;
  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _providedStorage ?? FirebaseStorage.instance;
  static const collection = 'conflictReports';

  @override
  Stream<ConflictReportFeed> watchSubmitted() async* {
    final uid = await _session.reporterId();
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (await _session.isClo()) {
      if (await _session.isDemo()) {
        query = query.where('isDemo', isEqualTo: true);
      }
    } else {
      query = query.where(
        Filter.or(
          Filter('reporterId', isEqualTo: uid),
          Filter('isDemo', isEqualTo: true),
        ),
      );
    }
    yield* query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => ConflictReportFeed(
            snapshot.docs
                .where((doc) => !doc.metadata.hasPendingWrites)
                .map((doc) => ConflictReport.fromMap(doc.data()))
                .toList(),
            isConnected: !snapshot.metadata.isFromCache,
          ),
        );
  }

  @override
  Future<ConflictReport> submit(ConflictReport report) async {
    report.validate();
    final uid = await _session.reporterId();
    String? photoUrl = report.photoUrl;
    final bytes = report.photoBytes;
    if (uploadPhotos && bytes != null && photoUrl == null) {
      final reference = _storage.ref('conflictReports/${report.id}/photo');
      await reference.putData(
        bytes,
        SettableMetadata(contentType: report.photoContentType),
      );
      photoUrl = await reference.getDownloadURL();
    }
    final data = report.toMap(includePhotoBytes: false)
      ..['isDemo'] = report.isDemo || await _session.isDemo()
      ..['photoDeliveryStatus'] = bytes == null
          ? 'none'
          : uploadPhotos
          ? 'uploaded'
          : 'deviceOnly'
      ..['reporterId'] = report.reporterId ?? uid
      ..['photoUrl'] = photoUrl
      ..['syncStatus'] = SyncStatus.synced.name
      ..['reportStatus'] = ReportStatus.submitted.name;
    // A transaction prevents a delayed/repeated submission from resetting an
    // officer's review or resolution after an earlier acknowledgement was lost.
    final ref = _firestore.collection(collection).doc(report.id);
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return ConflictReport.fromMap(existing.data()!);
      transaction.set(ref, data);
      return ConflictReport.fromMap(data);
    });
  }

  @override
  Future<void> review(ConflictReport report) => _transition(
    report,
    ReportStatus.submitted,
    ReportStatus.underReview,
    {'reviewedAt': DateTime.now().toIso8601String()},
  );

  @override
  Future<void> resolve(ConflictReport report, String notes) => _transition(
    report,
    ReportStatus.underReview,
    ReportStatus.resolved,
    {'responseNotes': notes, 'resolvedAt': DateTime.now().toIso8601String()},
  );

  Future<void> _transition(
    ConflictReport report,
    ReportStatus from,
    ReportStatus to,
    Map<String, dynamic> fields,
  ) async {
    if (!await _session.isClo() ||
        (await _session.isDemo() && !report.isDemo)) {
      throw const CloAccessDenied();
    }
    final ref = _firestore.collection(collection).doc(report.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.data()?['reportStatus'] != from.name) {
        throw StateError('The report status changed. Refresh and try again.');
      }
      transaction.update(ref, {
        ...fields,
        if (to == ReportStatus.underReview)
          'reviewedBy': await _session.reporterId(),
        'reportStatus': to.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }
}
