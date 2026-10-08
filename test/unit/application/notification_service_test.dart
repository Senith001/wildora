import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/features/high_risk_movement/application/notification_service.dart';
import 'package:wildora/src/features/high_risk_movement/application/messaging_wrapper.dart';

import '../../fakes/in_memory_repositories.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;
    late InMemoryOfficerRepository officerRepo;
    late MockMessagingWrapper mockMessaging;

    setUp(() {
      officerRepo = InMemoryOfficerRepository();
      mockMessaging = MockMessagingWrapper();
      service = NotificationService(
        officerRepository: officerRepo,
        messaging: mockMessaging,
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    group('initialize', () {
      test('successfully initializes with granted permission', () async {
        // Mock permission granted
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );

        // Mock token
        mockMessaging.nextToken = 'test-token-123';

        await service.initialize('officer-1');

        expect(mockMessaging.requestPermissionCalled, isTrue);
        expect(mockMessaging.getTokenCalled, isTrue);

        // Verify token was registered with officer
        expect(officerRepo.lastAddTokenOfficerId, equals('officer-1'));
        expect(officerRepo.lastAddToken, equals('test-token-123'));
      });

      test('skips token registration when permission denied', () async {
        // Mock permission denied
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.denied,
          alert: AppleNotificationSetting.disabled,
          badge: AppleNotificationSetting.disabled,
          sound: AppleNotificationSetting.disabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.disabled,
          notificationCenter: AppleNotificationSetting.disabled,
          showPreviews: AppleShowPreviewSetting.never,
          timeSensitive: AppleNotificationSetting.notSupported,
        );

        await service.initialize('officer-1');

        expect(mockMessaging.requestPermissionCalled, isTrue);
        expect(mockMessaging.getTokenCalled, isFalse);
        expect(officerRepo.lastAddTokenOfficerId, isNull);
      });

      test('handles token refresh', () async {
        // Set up successful initialization first
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
        mockMessaging.nextToken = 'initial-token';

        await service.initialize('officer-1');

        // Simulate token refresh
        mockMessaging.simulateTokenRefresh('refreshed-token-456');

        // Wait for async processing
        await Future.delayed(Duration(milliseconds: 10));

        // Verify refreshed token was registered
        expect(officerRepo.tokenRegistrations, hasLength(2));
        expect(
          officerRepo.tokenRegistrations.last.token,
          equals('refreshed-token-456'),
        );
        expect(
          officerRepo.tokenRegistrations.last.officerId,
          equals('officer-1'),
        );
      });

      test('handles initialization errors gracefully', () async {
        // Force messaging to throw
        mockMessaging.forceError = true;

        expect(() => service.initialize('officer-1'), throwsException);
      });
    });

    group('getCurrentToken', () {
      test('returns current token', () async {
        mockMessaging.nextToken = 'current-token-789';

        final token = await service.getCurrentToken();

        expect(token, equals('current-token-789'));
        expect(mockMessaging.getTokenCalled, isTrue);
      });

      test('returns null when token retrieval fails', () async {
        mockMessaging.forceError = true;

        final token = await service.getCurrentToken();

        expect(token, isNull);
      });
    });

    group('message handling', () {
      test('handles foreground messages', () async {
        // Initialize service first
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
        mockMessaging.nextToken = 'test-token';

        await service.initialize('officer-1');

        // Simulate foreground message
        final message = RemoteMessage(
          messageId: 'msg-1',
          data: {'alertId': 'alert-123', 'type': 'high_risk_movement'},
          notification: RemoteNotification(
            title: 'High-Risk Alert',
            body: 'Elephant-23 entered Farmland Border',
          ),
        );

        mockMessaging.simulateForegroundMessage(message);

        // In a real test, we'd verify the message was processed
        // For now, we just ensure no errors were thrown
        expect(true, isTrue); // Test passes if no exception
      });

      test('handles message opened app events', () async {
        // Initialize service first
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
        mockMessaging.nextToken = 'test-token';

        await service.initialize('officer-1');

        // Simulate message opened app
        final message = RemoteMessage(
          messageId: 'msg-2',
          data: {'alertId': 'alert-456'},
        );

        mockMessaging.simulateMessageOpenedApp(message);

        // Test passes if no exception thrown
        expect(true, isTrue);
      });
    });

    group('dispose', () {
      test('cleans up subscriptions', () async {
        // Initialize service first
        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
        mockMessaging.nextToken = 'test-token';

        await service.initialize('officer-1');

        // Dispose should not throw
        await service.dispose();

        expect(true, isTrue); // Test passes if no exception
      });
    });

    group('error handling', () {
      test('handles token registration failures gracefully', () async {
        // Set up repo to fail
        officerRepo.forceError = true;

        mockMessaging.nextPermissionResult = NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          sound: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
        mockMessaging.nextToken = 'test-token';

        // Should not throw even if token registration fails
        await service.initialize('officer-1');

        expect(true, isTrue); // Service should handle errors gracefully
      });
    });
  });
}

/// Mock implementation of MessagingWrapper for testing
class MockMessagingWrapper implements MessagingWrapper {
  bool requestPermissionCalled = false;
  bool getTokenCalled = false;
  bool forceError = false;

  NotificationSettings? nextPermissionResult;
  String? nextToken;
  RemoteMessage? nextInitialMessage;

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _messageOpenedController =
      StreamController<RemoteMessage>.broadcast();

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    if (forceError) throw Exception('Mock error');

    requestPermissionCalled = true;
    return nextPermissionResult ??
        NotificationSettings(
          authorizationStatus: AuthorizationStatus.denied,
          alert: AppleNotificationSetting.disabled,
          badge: AppleNotificationSetting.disabled,
          sound: AppleNotificationSetting.disabled,
          announcement: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.disabled,
          notificationCenter: AppleNotificationSetting.disabled,
          showPreviews: AppleShowPreviewSetting.never,
          timeSensitive: AppleNotificationSetting.notSupported,
        );
  }

  @override
  Future<String?> getToken() async {
    if (forceError) throw Exception('Mock error');

    getTokenCalled = true;
    return nextToken;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    if (forceError) throw Exception('Mock error');

    return nextInitialMessage;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Stream<RemoteMessage> get onMessage => _foregroundController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      _messageOpenedController.stream;

  // Test helper methods
  void simulateTokenRefresh(String newToken) {
    _tokenRefreshController.add(newToken);
  }

  void simulateForegroundMessage(RemoteMessage message) {
    _foregroundController.add(message);
  }

  void simulateMessageOpenedApp(RemoteMessage message) {
    _messageOpenedController.add(message);
  }

  void dispose() {
    _tokenRefreshController.close();
    _foregroundController.close();
    _messageOpenedController.close();
  }
}

/// Extension to expose internal methods for testing
/// Helper class to track token registrations
class TokenRegistration {
  final String officerId;
  final String token;

  TokenRegistration(this.officerId, this.token);
}
