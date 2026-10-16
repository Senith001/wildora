import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/wildlife-incident/application/incident_access.dart';
import 'package:wildora/src/features/wildlife-incident/application/incident_submission_controller.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_report.dart';

class SubmissionStub implements IncidentSubmission {
  int calls = 0;
  final result = Completer<IncidentReport>();
  @override
  Future<IncidentReport> submit(IncidentDraft draft) {
    calls++;
    return result.future;
  }
}

IncidentDraft draft() => IncidentDraft()
  ..type = 'Injured Wildlife'
  ..latitude = 6
  ..longitude = 79
  ..description = 'Injured animal'
  ..occurredAt = DateTime.utc(2020);

void main() {
  late SubmissionStub submission;
  late IncidentSubmissionController controller;
  setUp(() {
    submission = SubmissionStub();
    controller = IncidentSubmissionController(submission);
  });
  tearDown(() => controller.dispose());

  test('invalid input never invokes the submission dependency', () async {
    await expectLater(controller.submit(IncidentDraft()), throwsArgumentError);
    expect(submission.calls, 0);
    expect(controller.submitting, isFalse);
  });
  test(
    'notifies busy state and ignores duplicate submit while waiting',
    () async {
      final states = <bool>[];
      controller.addListener(() => states.add(controller.submitting));
      final input = draft();
      final first = controller.submit(input);
      expect(controller.submitting, isTrue);
      expect(await controller.submit(input), isNull);
      expect(submission.calls, 1);
      final report = input.toReport('installation');
      submission.result.complete(report);
      expect(await first, same(report));
      expect(states, [true, false]);
    },
  );
  test(
    'submission failure resets busy state and propagates the error',
    () async {
      final pending = controller.submit(draft());
      final assertion = expectLater(pending, throwsStateError);
      submission.result.completeError(StateError('disk full'));
      await assertion;
      expect(controller.submitting, isFalse);
    },
  );
}
