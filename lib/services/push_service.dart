import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/navigation/app_navigator.dart';
import 'device_service.dart';

/// Background/terminated message handler. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  // System tray displays the notification automatically (payload carries a
  // `notification` block); nothing else to do here.
}

/// End-to-end FCM integration: init, permission, token register/refresh,
/// foreground display and tap deep-link routing. All methods are best-effort
/// and never throw so a missing Firebase config can't crash the app.
class PushService {
  PushService._internal();
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;

  final DeviceService _deviceService = DeviceService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'porttivo_default',
    'Porttivo Notifications',
    description: 'Inquiries, quotes and trip updates',
    importance: Importance.high,
  );

  bool _initialized = false;
  bool _available = false;
  String? _currentToken;

  /// Initialize Firebase + messaging. Safe to call multiple times; the token
  /// is (re)registered with the backend on each successful login.
  Future<void> initAndRegister() async {
    try {
      if (!_initialized) {
        await Firebase.initializeApp();
        await _setupLocalNotifications();
        await _requestPermission();
        _wireHandlers();
        _initialized = true;
        _available = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('PushService: init skipped (Firebase unavailable): $e');
      }
      _available = false;
      return;
    }

    await _registerToken();
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            _routeFromData(Map<String, dynamic>.from(jsonDecode(payload)));
          } catch (_) {}
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  void _wireHandlers() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _routeFromData(_asStringMap(m.data));
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _currentToken = token;
      _deviceService.register(token: token, platform: _platform());
    });
    // Cold start via notification tap.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) {
        _routeFromData(_asStringMap(m.data));
      }
    });
  }

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await _deviceService.register(token: token, platform: _platform());
      }
    } catch (e) {
      if (kDebugMode) {
        print('PushService: token registration failed: $e');
      }
    }
  }

  /// Unregister the current device token (called on logout).
  Future<void> unregister() async {
    final token = _currentToken;
    if (token != null && token.isNotEmpty) {
      await _deviceService.unregister(token);
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _currentToken = null;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = _asStringMap(message.data);
    if (notification == null && data.isEmpty) return;

    final title = notification?.title ?? data['title'] ?? 'Porttivo';
    final body = notification?.body ?? data['body'] ?? '';

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) => out[k.toString()] = v);
    return out;
  }

  String _platform() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'unknown';
  }

  /// Map a notification `data` payload to an in-app destination.
  void _routeFromData(Map<String, dynamic> data) {
    final nav = appNavigatorKey.currentState;
    if (nav == null || data.isEmpty) return;

    final kind = (data['kind'] ?? '').toString();
    final requirementId = (data['requirementId'] ?? '').toString();
    final quoteId = (data['quoteId'] ?? '').toString();

    switch (kind) {
      case 'INQUIRY_BROADCAST':
        if (requirementId.isNotEmpty) {
          nav.pushNamed('/incoming-requirement', arguments: requirementId);
        }
        break;
      case 'QUOTE_COUNTERED':
        if (requirementId.isNotEmpty) {
          nav.pushNamed('/incoming-requirement', arguments: requirementId);
        }
        break;
      case 'QUOTE_NOT_SELECTED':
        nav.pushNamed('/incoming-requirement', arguments: requirementId);
        break;
      case 'QUOTE_RECEIVED':
        if (requirementId.isNotEmpty) {
          nav.pushNamed('/requirement-detail', arguments: requirementId);
        }
        break;
      case 'QUOTE_SELECTED':
        // Winner: head to marketplace trips (ready to start).
        nav.pushNamed('/home');
        break;
      case 'QUOTE_MESSAGE':
        if (quoteId.isNotEmpty) {
          nav.pushNamed('/quote-chat', arguments: {
            'quoteId': quoteId,
            'requirementId': requirementId,
          });
        }
        break;
      default:
        nav.pushNamed('/notifications');
    }
  }
}
