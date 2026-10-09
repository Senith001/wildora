import 'package:cloud_firestore/cloud_firestore.dart';
import 'incident_report.dart';
import 'cloudinary_photo_store.dart';

class IncidentUploadFailure implements Exception {
  IncidentUploadFailure(this.cause, List<String> urls)
    : photoUrls = List.unmodifiable(urls);
  final Object cause;
  final List<String> photoUrls;
}

abstract class IncidentRemoteStore {
  Stream<List<IncidentReport>> watchReports(String reporterId);
  Future<List<String>> upload(IncidentReport report);
}

class FirebaseIncidentRemoteStore implements IncidentRemoteStore {
  FirebaseIncidentRemoteStore({
    FirebaseFirestore? firestore,
    CloudinaryPhotoStore? photos,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _photos = photos ?? CloudinaryPhotoStore();

  final FirebaseFirestore _firestore;
  final CloudinaryPhotoStore _photos;

  @override
  Stream<List<IncidentReport>> watchReports(String reporterId) => _firestore
      .collection('wildlifeIncidents')
      .where('reporterId', isEqualTo: reporterId)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.docs
            // A local Firestore write is not proof of successful server upload.
            .where((doc) => !doc.metadata.hasPendingWrites)
            .map((doc) {
              final data = doc.data();
              final photoUrls = incidentPhotoUrls(data['photoUrls']);
              return IncidentReport(
                id: doc.id,
                reporterId: data['reporterId'] as String,
                type: data['type'] as String,
                latitude: (data['latitude'] as num).toDouble(),
                longitude: (data['longitude'] as num).toDouble(),
                locationName: data['locationName'] as String,
                description: data['description'] as String,
                occurredAt: (data['occurredAt'] as Timestamp).toDate(),
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                photoUrls: photoUrls,
                status: IncidentSyncStatus.synchronized,
              );
            })
            .toList(),
      );

  @override
  Future<List<String>> upload(IncidentReport report) async {
    final urls = List<String>.from(report.photoUrls);
    try {
      // URLs already saved after an earlier failure are reused on retry.
      for (var index = urls.length; index < report.photos.length; index++) {
        urls.add(await _photos.upload(report.photos[index]));
      }

      await _firestore
          .collection('wildlifeIncidents')
          .doc(report.id)
          .set({
            'reporterId': report.reporterId,
            'type': report.type,
            'latitude': report.latitude,
            'longitude': report.longitude,
            'location': GeoPoint(report.latitude, report.longitude),
            'locationName': report.locationName,
            'description': report.description,
            'occurredAt': Timestamp.fromDate(report.occurredAt),
            'createdAt': Timestamp.fromDate(report.createdAt),
            'photoUrls': urls,
            'status': 'synchronized',
            'uploadedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
      return urls;
    } catch (error) {
      throw IncidentUploadFailure(error, urls);
    }
  }
}

/// Firestore web arrays are dynamically typed, including empty photo arrays.
/// Construct an explicitly typed list before passing it to the report model.
List<String> incidentPhotoUrls(Object? value) => value is Iterable
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];
