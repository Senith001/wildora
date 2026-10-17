import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/features/high_risk_movement/domain/monitoring_state.dart';

void main() {
  group('MonitoringState helpers', () {
    group('isSuccess', () {
      test('is true only for locationUpdated/noAlert/alertRaised', () {
        expect(MonitoringState.locationUpdated.isSuccess, isTrue);
        expect(MonitoringState.noAlert.isSuccess, isTrue);
        expect(MonitoringState.alertRaised.isSuccess, isTrue);
      });

      test('is false for idle/processing/missingUpdate/error', () {
        expect(MonitoringState.idle.isSuccess, isFalse);
        expect(MonitoringState.processing.isSuccess, isFalse);
        expect(MonitoringState.missingUpdate.isSuccess, isFalse);
        expect(MonitoringState.error.isSuccess, isFalse);
      });
    });

    group('isProcessing', () {
      test('is true only for processing', () {
        expect(MonitoringState.processing.isProcessing, isTrue);
      });

      test('is false for every other state', () {
        expect(MonitoringState.idle.isProcessing, isFalse);
        expect(MonitoringState.locationUpdated.isProcessing, isFalse);
        expect(MonitoringState.noAlert.isProcessing, isFalse);
        expect(MonitoringState.alertRaised.isProcessing, isFalse);
        expect(MonitoringState.missingUpdate.isProcessing, isFalse);
        expect(MonitoringState.error.isProcessing, isFalse);
      });
    });

    group('isError', () {
      test('is true for error AND missingUpdate', () {
        expect(MonitoringState.error.isError, isTrue);
        expect(MonitoringState.missingUpdate.isError, isTrue);
      });

      test('is false for every other state', () {
        expect(MonitoringState.idle.isError, isFalse);
        expect(MonitoringState.processing.isError, isFalse);
        expect(MonitoringState.locationUpdated.isError, isFalse);
        expect(MonitoringState.noAlert.isError, isFalse);
        expect(MonitoringState.alertRaised.isError, isFalse);
      });
    });

    group('isAlertState', () {
      test('is true only for alertRaised', () {
        expect(MonitoringState.alertRaised.isAlertState, isTrue);
      });

      test('is false for every other state', () {
        expect(MonitoringState.idle.isAlertState, isFalse);
        expect(MonitoringState.processing.isAlertState, isFalse);
        expect(MonitoringState.locationUpdated.isAlertState, isFalse);
        expect(MonitoringState.noAlert.isAlertState, isFalse);
        expect(MonitoringState.missingUpdate.isAlertState, isFalse);
        expect(MonitoringState.error.isAlertState, isFalse);
      });
    });
  });
}
