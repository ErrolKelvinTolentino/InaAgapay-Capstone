import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/main_button.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/validation_message.dart';
import '../widgets/clickable_text.dart';
import '../widgets/page_title.dart';

class ForgotPasswordVerificationScreen extends StatefulWidget {
  const ForgotPasswordVerificationScreen({super.key});

  @override
  State<ForgotPasswordVerificationScreen> createState() =>
      _ForgotPasswordVerificationScreenState();
}

class _ForgotPasswordVerificationScreenState
    extends State<ForgotPasswordVerificationScreen> {
  static const int _initialSeconds = 300;

  late String email;
  int _secondsRemaining = _initialSeconds;
  Timer? _timer;

  String _code = '';
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    email = ModalRoute.of(context)!.settings.arguments as String;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = _initialSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _verifyCode() {
    if (_code.length == 6) {
      // TODO: Verify code
      Navigator.pushNamed(context, '/change-forgot-password');
    } else {
      setState(() => _hasError = true);
    }
  }

  void _resendCode() {
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New code sent!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/images/logo.png', height: 110),
              const SizedBox(height: 16),
              Image.asset('assets/images/inaagapay_name.png', width: 240),
              const SizedBox(height: 32),
              const PageTitle(
                title: 'Verify Code',
                leadingIcon: Icons.mail,
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the 6-digit code sent to\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              OtpInputField(
                onChanged: (value) {
                  setState(() {
                    _code = value;
                    _hasError = false;
                  });
                },
                showError: _hasError,
              ),
              if (_hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: ValidationMessage(
                    message: 'Invalid code. Please try again.',
                  ),
                ),
              const SizedBox(height: 32),
              MainButton(
                label: 'Verify',
                showIcons: false,
                onPressed: _code.length == 6 ? _verifyCode : null,
              ),
              const SizedBox(height: 24),
              _secondsRemaining == 0
                  ? ClickableText(text: 'Resend Code', onTap: _resendCode)
                  : Text(
                      'Resend Code in $_formattedTime',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
