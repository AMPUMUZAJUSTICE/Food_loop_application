import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  
  bool _otpSent = false;
  String _currentVerificationId = '';
  
  late Timer _timer;
  int _secondsRemaining = 120;
  bool _canResend = false;

  void _startTimer() {
    setState(() {
      _secondsRemaining = 120;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    if (_otpSent) _timer.cancel();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      // Default to +256 if standard format used, though minimal logic applied here
      final formattedPhone = phone.startsWith('+') ? phone : '+256${phone.startsWith('0') ? phone.substring(1) : phone}';
      context.read<AuthBloc>().add(AuthPhoneOTPRequested(formattedPhone));
    }
  }

  void _onVerify() {
    if (_pinController.text.length == 6 && _currentVerificationId.isNotEmpty) {
      context.read<AuthBloc>().add(AuthPhoneSMSOTPSubmitted(_currentVerificationId, _pinController.text));
    }
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: AppColors.textDark, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryGreen),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.errorRed),
            );
          } else if (state is AuthPhoneVerificationPending && state.verificationId.isNotEmpty) {
             // Verification ID received (since we used pending to show sent status)
             if (state.verificationId != 'waiting...') {
                setState(() {
                  _otpSent = true;
                  _currentVerificationId = state.verificationId;
                });
                _startTimer();
             }
          } else if (state is AuthAuthenticated) {
            context.go('/feed');
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.phone_android_outlined, size: 80, color: AppColors.primaryGreen),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Phone Number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 12),
                Text(
                  _otpSent 
                    ? 'Enter the 6-digit code sent to your phone.'
                    : 'We\'ll send an SMS code to verify your phone number.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textGrey, height: 1.5),
                ),
                const SizedBox(height: 48),

                if (!_otpSent) ...[
                  // Phone Number Input
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.offWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('+256', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isLoading ? null : _onSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                       : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  // OTP Input
                  Pinput(
                    length: 6,
                    controller: _pinController,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    onCompleted: (pin) => _onVerify(),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: (_pinController.text.length == 6 && !isLoading) ? _onVerify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading 
                       ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                       : const Text('Verify & Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Didn\'t receive the code? ', style: TextStyle(color: AppColors.textGrey)),
                      if (_canResend)
                        TextButton(
                          onPressed: () {
                             _onSendOtp();
                             _startTimer();
                          },
                          child: const Text('Resend Code', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                        )
                      else
                        Text(
                          _formattedTime,
                          style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
