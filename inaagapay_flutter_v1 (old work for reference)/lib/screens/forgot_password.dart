import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/validation_message.dart';
import '../widgets/page_title.dart';
import '../widgets/dialog_box.dart';
import '../services/forgot_password_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _hasError = false;
  bool _isLoading = false;

  Future<void> _sendResetCode() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final success = await ForgotPasswordService.sendCode(
      _emailController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!success) {
      setState(() => _hasError = true);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogBox(
        title: 'Verification Code Sent',
        subtitle: 'A 6-digit verification code has been sent to your email.',
        buttonText: 'Continue',
        type: DialogType.success,
        onPressed: () => Navigator.pop(context),
      ),
    );

    if (!mounted) return;

    // ✅ Pass email to next screen for verification
    Navigator.pushNamed(
      context,
      '/forgot-password-verify',
      arguments: _emailController.text.trim(),
    );
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
                title: 'Forgot Password',
                leadingIcon: Icons.key,
                trailingIcon: Icons.check,
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter your email to reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              AppInputField(
                hintText: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: ValidationMessage(
                    message: 'Email not found',
                    type: ValidationType.error,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              MainButton(
                label: _isLoading ? 'Sending...' : 'Send Reset Code',
                showIcons: false,
                onPressed: _isLoading ? null : _sendResetCode,
              ),

              const SizedBox(height: 16),

              SecondaryButton(
                label: 'Back to Login',
                showIcons: false,
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
