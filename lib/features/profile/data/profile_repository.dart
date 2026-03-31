import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/entities/app_user.dart';

@lazySingleton
class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ProfileRepository(this._firestore, this._storage);

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    // Compress image
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}_compressed.jpg';
    
    final compressedImage = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 400,
      minHeight: 400,
    );

    if (compressedImage == null) {
      throw Exception('Failed to compress image');
    }

    // Upload to Storage
    final ref = _storage.ref().child('profiles/$uid.jpg');
    final uploadTask = await ref.putFile(File(compressedImage.path));
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Clean up temp file
    File(compressedImage.path).deleteSync();

    return downloadUrl;
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    // Use set with merge:true so it works whether the doc exists or not
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<AppUser> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      // Self-heal: Create standard AppUser document for users missing it (legacy users)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        final AppUser newUser = AppUser(
          uid: uid,
          fullName: currentUser.displayName ?? 'Food Loop User',
          email: currentUser.email ?? '',
          phoneNumber: currentUser.phoneNumber ?? '',
          isVerified: currentUser.emailVerified,
          createdAt: DateTime.now(),
        );
        try {
          await _firestore.collection('users').doc(uid).set(newUser.toJson());
        } catch (e) {
          // Attempting to self-heal
        }
        return newUser;
      }
      throw Exception('User profile not found');
    }
    return AppUser.fromJson(doc.data()!);
  }
}
