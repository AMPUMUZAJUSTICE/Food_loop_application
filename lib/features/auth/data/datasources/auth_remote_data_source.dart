import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

abstract class AuthRemoteDataSource {
  Future<UserCredential> signUpWithEmail(String email, String password, String fullName);
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<void> sendEmailVerificationCode(String email);
  Future<bool> verifyEmailOTP(String code);
  Future<void> sendPhoneOTP(String phoneNumber);
  Future<PhoneAuthCredential> verifyPhoneOTP(String verificationId, String smsCode);
  Future<void> linkPhoneToAccount(PhoneAuthCredential credential);
  Future<void> signOut();
  User? getCurrentUser();
  Stream<User?> authStateChanges();
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl(this.firebaseAuth, this.firestore);

  @override
  Future<UserCredential> signUpWithEmail(String email, String password, String fullName) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(fullName);
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': email,
        'phoneNumber': '',
        'isVerified': false,
        'averageRating': 0.0,
        'totalRatings': 0,
        'walletBalance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': await FirebaseMessaging.instance.getToken(),
      });
    }
    return credential;
  }

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      await firestore.collection('users').doc(user.uid).update({
        'fcmToken': await FirebaseMessaging.instance.getToken(),
      });
    }
    return credential;
  }

  @override
  Future<void> sendEmailVerificationCode(String email) async {
    await FirebaseFunctions.instance.httpsCallable('sendOTP').call({
      'type': 'email',
      'value': email,
    });
  }

  @override
  Future<bool> verifyEmailOTP(String code) async {
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) return false;
    
    final userDoc = await firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    
    final storedCode = userDoc.data()?['emailOTP'];
    final expiry = userDoc.data()?['emailOTPExpiry'] as Timestamp?;
    
    if (storedCode == code && expiry != null && expiry.toDate().isAfter(DateTime.now())) {
      await firestore.collection('users').doc(uid).update({
        'isVerified': true,
        'emailOTP': FieldValue.delete(),
        'emailOTPExpiry': FieldValue.delete(),
      });
      return true;
    }
    return false;
  }

  @override
  Future<void> sendPhoneOTP(String phoneNumber) async {
    // Instead of Firebase Phone Auth (which requires SMS), we use our FCM-based OTP
    await FirebaseFunctions.instance.httpsCallable('sendOTP').call({
      'type': 'phone',
      'value': phoneNumber,
    });
  }

  @override
  Future<PhoneAuthCredential> verifyPhoneOTP(String verificationId, String smsCode) async {
    // Since we are using a custom flow, 'verificationId' will be 'FCM_PROVIDER'
    // and we verify against Firestore. We return a dummy credential if successful
    // because linkWithCredential expects one. 
    // BUT linkWithCredential only works with real provider credentials.
    // Instead, we just update the Firestore record for 'phoneNumber'.
    
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    
    final userDoc = await firestore.collection('users').doc(uid).get();
    final storedCode = userDoc.data()?['phoneOTP'];
    final expiry = userDoc.data()?['phoneOTPExpiry'] as Timestamp?;

    if (storedCode == smsCode && expiry != null && expiry.toDate().isAfter(DateTime.now())) {
       return PhoneAuthProvider.credential(verificationId: 'FCM_PROVIDER', smsCode: smsCode);
    }
    throw Exception('Invalid or expired OTP');
  }

  @override
  Future<void> linkPhoneToAccount(PhoneAuthCredential credential) async {
    // If it's our custom FCM provider, we just update Firestore
    if (credential.verificationId == 'FCM_PROVIDER') {
       final uid = firebaseAuth.currentUser?.uid;
       if (uid != null) {
          // In a real app, you'd update the actual Auth phone number via a custom token or admin SDK
          // For this project, we just track it in Firestore.
          await firestore.collection('users').doc(uid).update({
            'phoneNumber': 'Verified', // We could store the actual number if passed
            'phoneVerified': true,
          });
       }
       return;
    }
    await firebaseAuth.currentUser?.linkWithCredential(credential);
  }

  @override
  Future<void> signOut() {
    return firebaseAuth.signOut();
  }

  @override
  User? getCurrentUser() => firebaseAuth.currentUser;

  @override
  Stream<User?> authStateChanges() => firebaseAuth.authStateChanges();
}
