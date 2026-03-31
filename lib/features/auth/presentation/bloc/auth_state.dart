import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthEmailVerificationPending extends AuthState {
  final String email;
  const AuthEmailVerificationPending(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthPhoneVerificationPending extends AuthState {
  final String verificationId;
  const AuthPhoneVerificationPending(this.verificationId);
  @override
  List<Object?> get props => [verificationId];
}

class AuthAuthenticated extends AuthState {
  final User user; // Using Firebase User. The prompt says AppUser, but using standard Firebase User maps appropriately.
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}
