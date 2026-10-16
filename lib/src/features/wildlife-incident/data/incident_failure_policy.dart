import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'cloudinary_photo_store.dart';

abstract interface class IncidentFailurePolicy {
  bool isRetryable(Object error);
  String message(Object error);
}

class DefaultIncidentFailurePolicy implements IncidentFailurePolicy {
  const DefaultIncidentFailurePolicy();
  @override
  bool isRetryable(Object error) =>
      error is TimeoutException ||
      (error is CloudinaryUploadException && error.retryable) ||
      (error is FirebaseException &&
          const [
            'unavailable',
            'network-request-failed',
            'retry-limit-exceeded',
            'unknown',
          ].contains(error.code));
  @override
  String message(Object error) => incidentErrorMessage(error);
}

String incidentErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'Connection timed out. Your report remains saved on this device.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Firebase denied access. Check the incident Firestore rules, then retry.';
      case 'bucket-not-found':
      case 'no-default-bucket':
        return 'Photos use Cloudinary. Check your Firebase project configuration and retry.';
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return 'Unable to reach Firebase. Your report remains saved on this device.';
      default:
        return 'Firebase ${error.code}: ${error.message ?? 'Upload failed. Please retry.'}';
    }
  }
  return error.toString();
}
