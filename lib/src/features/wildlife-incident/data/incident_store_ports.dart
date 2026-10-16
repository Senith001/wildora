import 'incident_report.dart';

abstract class IncidentLocalStore {
  Future<String> initialize();
  List<IncidentReport> readReports();
  Future<void> save(IncidentReport report);
}

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

abstract interface class IncidentPhotoStore {
  Future<String> upload(IncidentPhoto photo);
}
