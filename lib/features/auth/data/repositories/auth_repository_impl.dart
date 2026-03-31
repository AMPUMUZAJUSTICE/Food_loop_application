import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  Failure _mapExceptionToFailure(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email': return InvalidEmailFailure(e.message ?? 'Invalid email');
        case 'user-not-found': return UserNotFoundFailure(e.message ?? 'User not found');
        case 'wrong-password': return WrongPasswordFailure(e.message ?? 'Wrong password');
        case 'invalid-credential': return WrongPasswordFailure(e.message ?? 'Invalid credentials provided');
        case 'email-already-in-use': return EmailAlreadyInUseFailure(e.message ?? 'Email already in use');
        case 'weak-password': return WeakPasswordFailure(e.message ?? 'Weak password');
        case 'network-request-failed': return NetworkFailure(e.message ?? 'Network request failed');
        default: return ServerFailure(e.message ?? 'An unknown error occurred');
      }
    }
    if (e is Exception) {
      return ServerFailure(e.toString());
    }
    return ServerFailure('Unexpected: $e');
  }

  @override
  Future<Either<Failure, UserCredential>> signUpWithEmail(String email, String password, String fullName) async {
    if (!email.endsWith('.ac.ug')) {
      return const Left(InvalidEmailDomainFailure('Only .ac.ug emails are allowed.'));
    }
    try {
      final result = await remoteDataSource.signUpWithEmail(email, password, fullName);
      return Right(result);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, UserCredential>> signInWithEmail(String email, String password) async {
    if (!email.endsWith('.ac.ug')) {
      return const Left(InvalidEmailDomainFailure('Only .ac.ug emails are allowed.'));
    }
    try {
      final result = await remoteDataSource.signInWithEmail(email, password);
      return Right(result);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerificationCode(String email) async {
    try {
      await remoteDataSource.sendEmailVerificationCode(email);
      return const Right(null);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyEmailOTP(String code) async {
    try {
      final result = await remoteDataSource.verifyEmailOTP(code);
      return Right(result);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> sendPhoneOTP(String phoneNumber) async {
    try {
      await remoteDataSource.sendPhoneOTP(phoneNumber);
      return const Right(null);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, PhoneAuthCredential>> verifyPhoneOTP(String verificationId, String smsCode) async {
    try {
      final credential = await remoteDataSource.verifyPhoneOTP(verificationId, smsCode);
      return Right(credential);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> linkPhoneToAccount(PhoneAuthCredential credential) async {
    try {
      await remoteDataSource.linkPhoneToAccount(credential);
      return const Right(null);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Either<Failure, User?> getCurrentUser() {
    try {
      return Right(remoteDataSource.getCurrentUser());
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Stream<User?> authStateChanges() {
    return remoteDataSource.authStateChanges();
  }
}
