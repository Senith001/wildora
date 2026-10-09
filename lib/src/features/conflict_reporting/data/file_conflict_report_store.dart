import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/conflict_report.dart';
import '../domain/conflict_report_ports.dart';

/// Stores one report per file, including its attachment, before network work.
/// Writing and flushing a temporary file then renaming it prevents partial
/// JSON from replacing a previously saved report if the app stops mid-write.
class FileConflictReportStore implements ConflictReportStore {
  FileConflictReportStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<Directory> _reportsDirectory() async {
    final root = await _directory();
    return Directory('${root.path}/conflict_reports').create(recursive: true);
  }

  @override
  Future<List<ConflictReport>> load() async {
    final directory = await _reportsDirectory();
    final reports = <ConflictReport>[];
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        reports.add(
          ConflictReport.fromMap(
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
          ),
        );
      }
    }
    return reports;
  }

  @override
  Future<void> save(ConflictReport report) async {
    report.validate();
    final directory = await _reportsDirectory();
    final file = File('${directory.path}/${report.id}.json');
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(report.toMap()), flush: true);
    await temporary.rename(file.path);
  }
}

ConflictReportStore createConflictReportStore() => FileConflictReportStore();
