import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_loop/core/errors/failures.dart';
import 'package:food_loop/features/auth/domain/repositories/auth_repository.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_event.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_state.dart';

class FakeUser extends Fake implements User {}
class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user = FakeUser();
}

class ManualMockAuthRepository implements AuthRepository {
  bool shouldFailSignIn = false;
  int signInCalled = 0;
  int signOutCalled = 0;

  @override
  Future<Either<Failure, UserCredential>> signInWithEmail(String email, String password) async {
    signInCalled++;
    if (shouldFailSignIn) {
      return const Left(ServerFailure('Invalid credentials'));
    }
    return Right(FakeUserCredential());
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOutCalled++;
    return const Right(null);
  }

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Either<Failure, User?> getCurrentUser() => const Right(null);

  @override
  Future<Either<Failure, void>> linkPhoneToAccount(PhoneAuthCredential credential) async => const Right(null);

  @override
  Future<Either<Failure, void>> sendEmailVerificationCode(String email) async => const Right(null);

  @override
  Future<Either<Failure, void>> sendPhoneOTP(String phoneNumber) async => const Right(null);

  @override
  Future<Either<Failure, UserCredential>> signUpWithEmail(String email, String password, String fullName) async => Right(FakeUserCredential());

  @override
  Future<Either<Failure, bool>> verifyEmailOTP(String code) async => const Right(true);

  @override
  Future<Either<Failure, PhoneAuthCredential>> verifyPhoneOTP(String verificationId, String smsCode) async {
    throw UnimplementedError();
  }
}

void main() {
  late AuthBloc authBloc;
  late ManualMockAuthRepository mockRepo;

  setUp(() {
    mockRepo = ManualMockAuthRepository();
    authBloc = AuthBloc(mockRepo);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(AuthInitial()));
    });

    test('AuthLoginRequested with valid creds -> emits [AuthLoading, AuthAuthenticated]', () async {
      mockRepo.shouldFailSignIn = false;
      
      final expected = [
        AuthLoading(),
        isA<AuthAuthenticated>(),
      ];
      expectLater(authBloc.stream, emitsInOrder(expected));
      
      authBloc.add(const AuthLoginRequested('test@must.ac.ug', 'password123'));
      
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.signInCalled, 1);
    });

    test('AuthLoginRequested with invalid creds -> emits [AuthLoading, AuthFailure]', () async {
      mockRepo.shouldFailSignIn = true;
      
      final expected = [
        AuthLoading(),
        const AuthFailure('Invalid credentials'),
      ];
      expectLater(authBloc.stream, emitsInOrder(expected));
      
      authBloc.add(const AuthLoginRequested('test@must.ac.ug', 'wrongpass'));
      
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.signInCalled, 1);
    });

    test('AuthSignOutRequested -> emits [AuthLoading, AuthUnauthenticated]', () async {
      final expected = [
        AuthLoading(),
        AuthUnauthenticated(),
      ];
      expectLater(authBloc.stream, emitsInOrder(expected));
      
      authBloc.add(AuthSignOutRequested());
      
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.signOutCalled, 1);
    });
  });
}
