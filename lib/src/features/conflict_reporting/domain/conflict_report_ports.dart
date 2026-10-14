import 'conflict_report.dart';

/// Durable device storage and a remote gateway are separate so failures and
/// offline retries can be tested without Firebase or platform plugins.
abstract interface class ConflictReportStore {
  Future<List<ConflictReport>> load();
  Future<void> save(ConflictReport report);
}

/// A server snapshot establishes connectivity; cached records do not.
class ConflictReportFeed {
  const ConflictReportFeed(this.reports, {required this.isConnected});
  final List<ConflictReport> reports;
  final bool isConnected;
}

abstract interface class ConflictReportRemote {
  Stream<ConflictReportFeed> watchSubmitted();
  Future<ConflictReport> submit(ConflictReport report);
  Future<void> review(ConflictReport report);
  Future<void> resolve(ConflictReport report, String notes);
}

/// Delivers an attachment and returns its server reference.
abstract interface class ConflictPhotoUploader {
  Future<String> upload(ConflictReport report);
}

/// Reads images from addresses supported by the provider.
abstract interface class ConflictPhotoDownloader {
  bool canDownload(String url);
  Future<List<int>> download(String url);
}

abstract interface class ConflictPhotoRemote
    implements ConflictPhotoUploader, ConflictPhotoDownloader {}
