import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'features/wallet/data/flutterwave_service.dart';
import 'injection_container.config.dart';

final GetIt sl = GetIt.instance; // sl stands for Service Locator

@InjectableInit()
Future<void> configureDependencies() async {
  await sl.init();
  // Manually register FlutterwaveService to avoid build_runner delay
  if (!sl.isRegistered<FlutterwaveService>()) {
    sl.registerLazySingleton<FlutterwaveService>(() => FlutterwaveService(sl<FirebaseFunctions>()));
  }
}

@module
abstract class FirebaseModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  FirebaseStorage get firebaseStorage => FirebaseStorage.instance;

  @lazySingleton
  FirebaseFunctions get firebaseFunctions => FirebaseFunctions.instanceFor(region: 'us-central1');

  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;

  @lazySingleton
  FlutterwaveService get flutterwaveService => FlutterwaveService(firebaseFunctions);
}
