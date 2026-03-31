import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  int _secondsRemaining = 120; // 2:00
  bool _canResend = false;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

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
    _timer.cancel();
    _pinController.dispose();
    super.dispose();
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return "${name.substring(0, 1)}***@$domain";
    return "${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain";
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _onVerify() {
    if (_pinController.text.length == 6) {
      context.read<AuthBloc>().add(AuthEmailOTPSubmitted(_pinController.text));
    }
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
        title: const Text('Verify Email'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AuthAuthenticated) {
            context.go('/feed');
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               const Icon(Icons.mark_email_read_outlined, size: 80, color: AppColors.primaryGreen),
               const SizedBox(height: 24),
               const Text(
                'Enter Verification Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 16, color: AppColors.textGrey, height: 1.5),
                  children: [
                    const TextSpan(text: 'We\'ve sent a 6-digit code to\n'),
                    TextSpan(
                      text: _maskEmail(widget.email),
                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
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
              
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return ElevatedButton(
                    onPressed: (_pinController.text.length == 6 && !isLoading) ? _onVerify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading 
                       ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                       : const Text('Verify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Didn\'t receive the code? ', style: TextStyle(color: AppColors.textGrey)),
                  if (_canResend)
                    TextButton(
                      // Mock implementation as requested
                      onPressed: () {
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
          ),
        ),
      ),
    );
  }
}
