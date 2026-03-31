import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthUserChecked>(_onAuthUserChecked);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthEmailOTPSubmitted>(_onEmailOTPSubmitted);
    on<AuthPhoneOTPRequested>(_onPhoneOTPRequested);
    on<AuthPhoneSMSOTPSubmitted>(_onPhoneSMSOTPSubmitted);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  void _onAuthUserChecked(AuthUserChecked event, Emitter<AuthState> emit) {
    final userEither = _authRepository.getCurrentUser();
    userEither.fold(
      (failure) => emit(AuthUnauthenticated()),
      (user) {
        if (user != null) {
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthUnauthenticated());
        }
      },
    );
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.signInWithEmail(event.email, event.password);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (credential) => emit(AuthAuthenticated(credential.user!)),
    );
  }

  Future<void> _onSignUpRequested(AuthSignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.signUpWithEmail(event.email, event.password, event.fullName);
    await result.fold(
      (failure) async => emit(AuthFailure(failure.message)),
      (credential) async {
        await _authRepository.sendEmailVerificationCode(event.email);
        emit(AuthEmailVerificationPending(event.email));
      },
    );
  }

  Future<void> _onEmailOTPSubmitted(AuthEmailOTPSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.verifyEmailOTP(event.code);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (success) {
        if (success) {
          final userEither = _authRepository.getCurrentUser();
          userEither.fold(
            (_) => emit(AuthUnauthenticated()),
            (user) => emit(AuthAuthenticated(user!)),
          );
        } else {
          emit(const AuthFailure("Invalid OTP code"));
        }
      },
    );
  }

  Future<void> _onPhoneOTPRequested(AuthPhoneOTPRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.sendPhoneOTP(event.phoneNumber);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (_) {
        // Emit our custom provider string so the UI can transition to OTP input
        emit(const AuthPhoneVerificationPending('FCM_PROVIDER'));
      },
    );
  }

  Future<void> _onPhoneSMSOTPSubmitted(AuthPhoneSMSOTPSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.verifyPhoneOTP(event.verificationId, event.smsCode);
    await result.fold(
      (failure) async => emit(AuthFailure(failure.message)),
      (credential) async {
        final linkResult = await _authRepository.linkPhoneToAccount(credential);
        linkResult.fold(
          (failure) => emit(AuthFailure(failure.message)),
          (_) {
            final userEither = _authRepository.getCurrentUser();
            userEither.fold(
              (_) => emit(AuthUnauthenticated()),
              (user) => emit(AuthAuthenticated(user!)),
            );
          },
        );
      },
    );
  }

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }
}
