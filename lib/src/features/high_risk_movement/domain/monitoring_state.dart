/// State of the animal monitoring system controller.
///
/// Represents the current status of location processing and alert generation
/// to provide clear state management for the UI and testing.
enum MonitoringState {
  /// Initial state - no processing active.
  idle,

  /// Currently processing a location update.
  processing,

  /// Location was successfully updated in storage.
  locationUpdated,

  /// Location was processed but no alert was needed (animal not in zone).
  noAlert,

  /// High-risk alert was raised and sent to officers.
  alertRaised,

  /// Expected location update was not received within the expected timeframe.
  missingUpdate,

  /// An error occurred during processing.
  error;

  /// Returns true if the state represents successful processing.
  bool get isSuccess => switch (this) {
    locationUpdated || noAlert || alertRaised => true,
    _ => false,
  };

  /// Returns true if the state represents an active operation.
  bool get isProcessing => this == processing;

  /// Returns true if the state represents an error condition.
  bool get isError => this == error || this == missingUpdate;

  /// Returns true if the state represents an alert condition.
  bool get isAlertState => this == alertRaised;
}
