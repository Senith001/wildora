import 'package:hive_flutter/hive_flutter.dart';
import 'incident_report.dart';

abstract class IncidentLocalStore {
  Future<String> initialize();
  List<IncidentReport> readReports();
  Future<void> save(IncidentReport report);
}

/// Hive writes the report and photo bytes before any network upload starts.
/// Native: application documents directory. Web: IndexedDB in this browser.
class HiveIncidentLocalStore implements IncidentLocalStore {
  HiveIncidentLocalStore({this.directory});
  final String? directory;
  late Box<dynamic> _box;

  @override
  Future<String> initialize() async {
    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory!);
    }
    _box = await Hive.openBox<dynamic>('wildora_incident_reports_v1');
    final existing = _box.get('reporterId') as String?;
    if (existing != null) return existing;
    final id = newIncidentId();
    await _box.put('reporterId', id);
    return id;
  }

  @override
  List<IncidentReport> readReports() => _box.keys
      .where((key) => key.toString().startsWith('report:'))
      .map((key) => IncidentReport.fromLocalMap(_box.get(key) as Map))
      .toList();

  @override
  Future<void> save(IncidentReport report) async {
    await _box.put('report:${report.id}', report.toLocalMap());
    await _box.flush();
  }
}
