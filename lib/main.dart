import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'app.dart';
import 'injection_container.dart';
import 'core/notifications/notification_service.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await configureDependencies();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await sl<NotificationService>().initialize();

  Future<void> saveTokenToFirestore(String token) async {
    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
      } catch (e) {
        debugPrint("Failed to save FCM token: $e");
      }
    }
  }

  messaging.getToken().then((token) {
    if (token != null) saveTokenToFirestore(token);
  });

  messaging.onTokenRefresh.listen(saveTokenToFirestore);

  auth.authStateChanges().listen((user) async {
    if (user != null) {
      final token = await messaging.getToken();
      if (token != null) saveTokenToFirestore(token);
      sl<NotificationBloc>().add(StartListeningToNotifications(user.uid));
    }
  });

  runApp(const FoodLoopApp());
}
