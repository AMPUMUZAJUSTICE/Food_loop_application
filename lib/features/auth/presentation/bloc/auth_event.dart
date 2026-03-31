import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  const AuthSignUpRequested(this.email, this.password, this.fullName);
  @override
  List<Object?> get props => [email, password, fullName];
}

class AuthEmailOTPSubmitted extends AuthEvent {
  final String code;
  const AuthEmailOTPSubmitted(this.code);
  @override
  List<Object?> get props => [code];
}

class AuthPhoneOTPRequested extends AuthEvent {
  final String phoneNumber;
  const AuthPhoneOTPRequested(this.phoneNumber);
  @override
  List<Object?> get props => [phoneNumber];
}

class AuthPhoneSMSOTPSubmitted extends AuthEvent {
  final String verificationId;
  final String smsCode;
  const AuthPhoneSMSOTPSubmitted(this.verificationId, this.smsCode);
  @override
  List<Object?> get props => [verificationId, smsCode];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthUserChecked extends AuthEvent {}
