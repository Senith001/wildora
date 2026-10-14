import 'dart:convert';

import 'package:web/web.dart' as web;

import '../domain/conflict_report.dart';
import '../domain/conflict_report_ports.dart';

/// Browser adapter. Quota/storage errors propagate before a saved confirmation;
/// private browsing and clearing site data can remove local reports.
class BrowserConflictReportStore implements ConflictReportStore {
  static const _prefix = 'wildora.conflict.';

  @override
  Future<List<ConflictReport>> load() async {
    final storage = web.window.localStorage;
    final reports = <ConflictReport>[];
    for (var i = 0; i < storage.length; i++) {
      final key = storage.key(i);
      if (key != null && key.startsWith(_prefix)) {
        reports.add(
          ConflictReport.fromMap(
            jsonDecode(storage.getItem(key)!) as Map<String, dynamic>,
          ),
        );
      }
    }
    return reports;
  }

  @override
  Future<void> save(ConflictReport report) async {
    report.validate();
    web.window.localStorage.setItem(
      '$_prefix${report.id}',
      jsonEncode(report.toMap()),
    );
  }
}

ConflictReportStore createConflictReportStore() => BrowserConflictReportStore();
