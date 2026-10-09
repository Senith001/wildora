import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Abstraction for firebase_messaging to enable testing.
abstract class MessagingWrapper {
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  });

  Future<String?> getToken();
  Future<RemoteMessage?> getInitialMessage();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
}

/// Production implementation using real FirebaseMessaging.
class FirebaseMessagingWrapper implements MessagingWrapper {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) {
    return _messaging.requestPermission(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
