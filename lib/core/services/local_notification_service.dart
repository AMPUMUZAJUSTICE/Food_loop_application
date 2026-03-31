import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    // Determine timezone. For a real app, use flutter_timezone package to get local timezone.
    // Defaulting to UTC, but ideally we set local timezone.
    tz.setLocalLocation(tz.getLocation('Africa/Kampala')); // Best effort default for Food Loop context

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleExpiryNotifications(String id, String itemName, DateTime expiryDate) async {
    // Generate an integer ID from the string UUID (naive hash for simplicity)
    final int baseId = id.hashCode.abs();
    final int dayBeforeId = baseId;
    final int dayOfId = baseId + 1;

    // 1. Day before at 9 AM
    final DateTime dayBefore = expiryDate.subtract(const Duration(days: 1));
    final DateTime dayBeforeScheduled = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0);

    // 2. Day of at 8 AM
    final DateTime dayOfScheduled = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 8, 0);

    final now = DateTime.now();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Alerts',
      channelDescription: 'Notifications for expiring food items',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    if (dayBeforeScheduled.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        dayBeforeId,
        'Expiring Tomorrow!',
        '$itemName expires tomorrow! Share it on Food Loop or plan to use it.',
        tz.TZDateTime.from(dayBeforeScheduled, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (dayOfScheduled.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        dayOfId,
        'Expiring Today!',
        '$itemName expires today! Quick — share or discard safely.',
        tz.TZDateTime.from(dayOfScheduled, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelNotifications(String id) async {
    final int baseId = id.hashCode.abs();
    await flutterLocalNotificationsPlugin.cancel(baseId);
    await flutterLocalNotificationsPlugin.cancel(baseId + 1);
  }
}
