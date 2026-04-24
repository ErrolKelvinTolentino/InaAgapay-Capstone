// lib/screens/auth/forgot_password_verification.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_button.dart';
import '../../widgets/otp_input_field.dart';
import '../../widgets/page_title.dart';
import '../../widgets/dialog_box.dart';
import '../../services/supabase_service.dart';

class ForgotPasswordVerificationScreen extends StatefulWidget {
  const ForgotPasswordVerificationScreen({super.key});

  @override
  State<ForgotPasswordVerificationScreen> createState() => _ForgotPasswordVerificationScreenState();
}

class _ForgotPasswordVerificationScreenState extends State<ForgotPasswordVerificationScreen> {
  static const int _initialSeconds = 300;

  late String email;
  int _secondsRemaining = _initialSeconds;
  Timer? _timer;

  String _code = '';
  bool _hasError = false;
  bool _isVerifying = false;
  String _errorMessage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is String) {
      email = args;
    } else {
      email = '';
    }
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
    if (_code.length != 6) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter the 6-digit verification code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _hasError = false;
      _errorMessage = '';
    });

    final isValid = await SupabaseService.verifyResetCode(email, _code);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _hasError = !isValid;
      if (!isValid) {
        _errorMessage = 'Invalid or expired code. Please try again.';
      }
    });

    if (isValid) {
      // ✅ Navigate to change password screen
      Navigator.pushNamed(
        context,
        '/reset-password',
        arguments: email,
      );
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isVerifying = true);

    final result = await SupabaseService.forgotPassword(email);

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (result['success'] == true) {
      _startTimer();
      // ✅ Show dialog instead of snackbar
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Code Resent',
          content: 'A new verification code has been sent to your email.',
          buttonText: 'OK',
          type: DialogType.success,
          onPressed: () => Navigator.pop(context),
        ),
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Resend Failed',
          content: result['message'] ?? 'Failed to resend code. Please try again.',
          buttonText: 'OK',
          type: DialogType.error,
          onPressed: () => Navigator.pop(context),
        ),
      );
    }
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
              const Text(
                'Inaagapay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF68A5),
                ),
              ),
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
                    _errorMessage = '';
                  });
                },
                showError: _hasError,
              ),
              if (_hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
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
              const SizedBox(height: 24),
              if (_isVerifying)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF68A5)),
                )
              else if (_secondsRemaining == 0)
                TextButton(
                  onPressed: _resendCode,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(color: AppColors.brandPrimary),
                  ),
                )
              else
                Text(
                  'Resend Code in $_formattedTime',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                child: const Text(
                  'Back to Login',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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