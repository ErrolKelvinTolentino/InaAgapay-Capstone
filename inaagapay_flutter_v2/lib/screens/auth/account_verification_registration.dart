import 'dart:async';
import 'package:flutter/material.dart';
// Change these:
import '../../theme/app_colors.dart';
import '../../widgets/main_button.dart';
import '../../widgets/otp_input_field.dart';
import '../../widgets/validation_message.dart';
import '../../widgets/clickable_text.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/page_title.dart';
import '../../services/supabase_service.dart';

class AccountVerificationRegistration extends StatefulWidget {
  const AccountVerificationRegistration({super.key});

  @override
  State<AccountVerificationRegistration> createState() =>
      _AccountVerificationRegistrationState();
}

class _AccountVerificationRegistrationState
    extends State<AccountVerificationRegistration> {
  static const int _initialSeconds = 300; // 5 minutes

  late String email;
  int _secondsRemaining = _initialSeconds;
  Timer? _timer;
  bool _isResending = false;

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
    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    final success = await SupabaseService.verifyCode(email, _code);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _hasError = !success;
    });

    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Verification Successful',
          content: 'Your account has been verified. You can now log in.',
          buttonText: 'Go to Login',
          type: DialogType.success,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
    });

    final result = await SupabaseService.resendVerificationCode(email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (result['success']) {
      _startTimer();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppColors.error,
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              // App Name (text instead of image)
              const Text(
                'Inaagapay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDE3A53),
                ),
              ),
              
              const SizedBox(height: 32),
              
              const PageTitle(
                title: 'VERIFY EMAIL',
                leadingIcon: Icons.mail,
                trailingIcon: Icons.check,
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
                    message: 'Incorrect or expired code. Please try again.',
                    type: ValidationType.error,
                  ),
                ),
              const SizedBox(height: 32),
              MainButton(
                label: _isVerifying ? 'Verifying...' : 'Verify',
                showIcons: false,
                onPressed: _code.length == 6 && !_isVerifying
                    ? _verifyCode
                    : null,
              ),
              const SizedBox(height: 32),
              if (_isResending)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDE3A53)),
                )
              else if (_secondsRemaining == 0)
                ClickableText(
                  text: 'Resend Code',
                  onTap: _resendCode,
                )
              else
                Text(
                  'Resend Code in $_formattedTime',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 24),
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