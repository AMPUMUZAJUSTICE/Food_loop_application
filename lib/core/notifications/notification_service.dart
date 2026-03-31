import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../../app.dart';

@lazySingleton
class NotificationService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  NotificationService(this._messaging)
      : _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize local notifications for foreground popups
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          _handleDeepLink(data);
        }
      },
    );

    // 2. Create high importance channel for Android
    const androidChannel = AndroidNotificationChannel(
      'food_loop_channel',
      'Food Loop Alerts',
      description: 'Used for important notifications.',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // 3. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message, androidChannel);
      }
    });

    // 4. Listen to background/terminated app taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleDeepLink(message.data);
    });

    // 5. Handle if app was killed and opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Small delay to allow router to initialize if needed
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleDeepLink(initialMessage.data);
      });
    }
  }

  void _showLocalNotification(RemoteMessage message, AndroidNotificationChannel channel) {
    _localNotifications.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleDeepLink(Map<String, dynamic> data) {
    if (navigatorKey.currentContext == null) return;
    final context = navigatorKey.currentContext!;

    // Using go_router from our navigator context
    final type = data['type'] as String?;
    
    // Cloud Functions sets 'route' generally across old notifications, but we can handle specific payload types
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      context.push(route);
      return;
    }

    if (type == 'new_message') {
      final chatId = data['chatId'];
      if (chatId != null) context.push('/chat/$chatId');
    } else if (type == 'payment_received') {
      context.push('/wallet');
    } else if (type == 'pickup_confirmed') {
      final orderId = data['orderId'];
      if (orderId != null) context.push('/rate/$orderId');
    } else if (type == 'listing_expiry') {
      context.push('/listings');
    } else if (type == 'new_order') {
      context.push('/orders'); // Can specify tab index internally if needed
    }
  }
}
