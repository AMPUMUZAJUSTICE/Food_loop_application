import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserCredential>> signUpWithEmail(String email, String password, String fullName);
  Future<Either<Failure, UserCredential>> signInWithEmail(String email, String password);
  Future<Either<Failure, void>> sendEmailVerificationCode(String email);
  Future<Either<Failure, bool>> verifyEmailOTP(String code);
  Future<Either<Failure, void>> sendPhoneOTP(String phoneNumber);
  Future<Either<Failure, PhoneAuthCredential>> verifyPhoneOTP(String verificationId, String smsCode);
  Future<Either<Failure, void>> linkPhoneToAccount(PhoneAuthCredential credential);
  Future<Either<Failure, void>> signOut();
  Either<Failure, User?> getCurrentUser();
  Stream<User?> authStateChanges();
}
