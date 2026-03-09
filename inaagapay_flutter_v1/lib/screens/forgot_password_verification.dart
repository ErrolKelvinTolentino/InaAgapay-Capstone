import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/main_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/validation_message.dart';
import '../widgets/clickable_text.dart';
import '../widgets/dialog_box.dart';
import '../widgets/page_title.dart';
import '../services/forgot_password_service.dart';

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
  bool _isVerifying = false;

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

  Future<void> _verifyCode() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    try {
      final success = await ForgotPasswordService.verifyCode(email, _code);

      if (!success) {
        setState(() {
          _hasError = true;
          _isVerifying = false;
        });
        return;
      }

      // Store parent context before any async operations
      final parentContext = context;

      // Use a small delay to ensure state updates complete
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Code Verified',
          buttonText: 'Continue',
          type: DialogType.success,
          onPressed: () {
            Navigator.of(parentContext, rootNavigator: true).pop();
            Navigator.pushReplacementNamed(
              parentContext,
              '/change-forgot-password',
              arguments: email,
            );
          },
        ),
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _isVerifying = false;
      });
    }
  }

  void _resendCode() {
    _startTimer();
    ForgotPasswordService.sendCode(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              Image.asset('assets/images/logo.png', height: 100),
              const SizedBox(height: 12),
              Image.asset('assets/images/inaagapay_name.png', height: 34),

              const SizedBox(height: 32),

              const PageTitle(
                title: 'CODE SENT',
                leadingIcon: Icons.mail,
                trailingIcon: Icons.check,
              ),

              const SizedBox(height: 16),

              const Text(
                'Enter the 6-digit code sent to your email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 28),

              OtpInputField(
                onChanged: (value) {
                  setState(() {
                    _code = value;
                    _hasError = false;
                  });
                },
                showError: _hasError,
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: ValidationMessage(
                    message: 'Incorrect code. Please try again.',
                    type: ValidationType.error,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              MainButton(
                label: _isVerifying ? 'Verifying...' : 'Verify',
                showIcons: false,
                onPressed: _code.length == 6 && !_isVerifying
                    ? _verifyCode
                    : null,
              ),

              const SizedBox(height: 16),

              SecondaryButton(
                label: 'Back to Login',
                showIcons: false,
                onPressed: _isVerifying
                    ? () {}
                    : () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
              ),

              const SizedBox(height: 16),

              _secondsRemaining == 0
                  ? ClickableText(
                      text: 'Resend Code',
                      onTap: _isVerifying ? () {} : _resendCode,
                    )
                  : Text(
                      'Resend Code in $_formattedTime',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isVerifying
                            ? AppColors.textSecondary.withOpacity(0.5)
                            : AppColors.textSecondary,
                      ),
                    ),

              const SizedBox(height: 24),
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
