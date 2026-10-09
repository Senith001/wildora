import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../data/repositories/officer_repository.dart';
import 'messaging_wrapper.dart';

/// Notification service wrapping firebase_messaging for the CLIENT path.
///
/// Handles:
/// 1. FCM token registration and refresh for officers
/// 2. Foreground/background message handlers for in-app notifications
/// 3. Import-safe initialization for web+android
///
/// The ACTUAL push sending is done by Cloud Function (Phase E).
/// This service is only for client registration + receipt handling.
///
/// Battery-conscious: no background isolate work beyond standard FCM handlers.
class NotificationService {
  final OfficerRepository _officerRepository;
  late final MessagingWrapper _messaging;

  String? _currentOfficerId;
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Message handlers for in-app display
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  NotificationService({
    required OfficerRepository officerRepository,
    MessagingWrapper? messaging,
  }) : _officerRepository = officerRepository {
    _messaging = messaging ?? FirebaseMessagingWrapper();
  }

  /// Initialize FCM for the given officer.
  ///
  /// Sequence:
  /// 1. Request permission
  /// 2. Get initial token
  /// 3. Register token with officer
  /// 4. Setup token refresh handler
  /// 5. Setup message handlers
  Future<void> initialize(String officerId) async {
    try {
      _currentOfficerId = officerId;

      // Step 1: Request permission (handles both iOS and web)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          print('NotificationService: Permission denied');
        }
        return; // Don't proceed without permission
      }

      // Step 2 & 3: Get token and register
      await _refreshAndRegisterToken();

      // Step 4: Setup token refresh handler
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        _onTokenRefresh,
        onError: (error) {
          if (kDebugMode) {
            print('NotificationService: Token refresh error: $error');
          }
        },
      );

      // Step 5: Setup message handlers
      _setupMessageHandlers();

      if (kDebugMode) {
        print('NotificationService: Initialized for officer $officerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Cleanup subscriptions when service is disposed.
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _messageOpenedAppSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _messageOpenedAppSubscription = null;
    _currentOfficerId = null;
  }

  /// Get current FCM token (for debugging/manual testing).
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Failed to get token: $e');
      }
      return null;
    }
  }

  /// Setup foreground and opened app message handlers.
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    _foregroundSubscription = _messaging.onMessage.listen(
      _onForegroundMessage,
      onError: (error) {
        if (kDebugMode) {
          print('NotificationService: Foreground message error: $error');
        }
      },
    );

    // Handle notification tap when app was in background/terminated
    _messageOpenedAppSubscription = _messaging.onMessageOpenedApp.listen(
      _onMessageOpenedApp,
      onError: (error) {
        if (kDebugMode) {
          print('NotificationService: Message opened app error: $error');
        }
      },
    );

    // Check for initial message if app was opened from terminated state
    _checkInitialMessage();
  }

  /// Handle message received while app is in foreground.
  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('NotificationService: Foreground message received');
      print('  Title: ${message.notification?.title}');
      print('  Body: ${message.notification?.body}');
      print('  Data: ${message.data}');
    }

    // In a real app, this would show an in-app banner or update UI
    // For now, we just log it since the actual alert display is handled
    // by Firestore listeners in the alert dashboard/detail screens
  }

  /// Handle notification tap that opened the app from background.
  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('NotificationService: App opened from notification');
      print('  Data: ${message.data}');
    }

    // In a real app, this would navigate to the alert detail screen
    // using the alertId from message.data['alertId']
    // For now, we just log it since navigation is handled by the UI layer
  }

  /// Check for initial message if app was opened from terminated state.
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('NotificationService: App opened from terminated state');
          print('  Data: ${initialMessage.data}');
        }
        // Same navigation logic as _onMessageOpenedApp would apply here
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Failed to get initial message: $e');
      }
    }
  }

  /// Refresh token and register with officer repository.
  Future<void> _refreshAndRegisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && _currentOfficerId != null) {
        await _registerFcmToken(_currentOfficerId!, token);

        if (kDebugMode) {
          final truncated = token.length > 20 ? token.substring(0, 20) : token;
          print('NotificationService: Token registered: $truncated...');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Token refresh failed: $e');
      }
    }
  }

  /// Handle token refresh events.
  Future<void> _onTokenRefresh(String newToken) async {
    if (kDebugMode) {
      final truncated = newToken.length > 20
          ? newToken.substring(0, 20)
          : newToken;
      print('NotificationService: Token refreshed: $truncated...');
    }

    if (_currentOfficerId != null) {
      await _registerFcmToken(_currentOfficerId!, newToken);
    }
  }

  /// Register FCM token with officer repository.
  Future<void> _registerFcmToken(String officerId, String token) async {
    try {
      await _officerRepository.addFcmToken(officerId, token);
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Failed to register token: $e');
      }
      // Don't rethrow - token registration failure shouldn't crash the app
    }
  }
}

/// Background message handler (must be top-level function).
///
/// This handler is called when the app receives a message in the background.
/// It must be a top-level function and cannot access instance members.
///
/// For high-risk alerts, we generally want immediate foreground attention,
/// so background processing is minimal - just logging for debugging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Don't call Firebase.initializeApp() here - it's handled in main()

  if (kDebugMode) {
    print('NotificationService: Background message received');
    print('  Title: ${message.notification?.title}');
    print('  Body: ${message.notification?.body}');
    print('  Data: ${message.data}');
  }

  // For high-risk alerts, we rely on the system notification to bring
  // the user back to the app. No heavy background processing needed.
}
