import 'package:flutter/foundation.dart';
import '../data/incident_report.dart';
import 'incident_access.dart';

/// Owns submission state independently of widgets, navigation and persistence.
class IncidentSubmissionController extends ChangeNotifier {
  IncidentSubmissionController(this._submission);
  final IncidentSubmission _submission;
  bool _disposed = false;
  bool _submitting = false;
  bool get submitting => _submitting;

  Future<IncidentReport?> submit(IncidentDraft draft) async {
    if (_submitting) return null;
    final validation = draft.validate();
    if (validation != null) throw ArgumentError(validation);
    _submitting = true;
    notifyListeners();
    try {
      return await _submission.submit(draft);
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
