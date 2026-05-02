// lib/screens/auth/forgot_password.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/page_title.dart';
import '../../widgets/dialog_box.dart';
import '../../services/supabase_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await SupabaseService.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // ✅ FIX: Show Dialog Box instead of snackbar
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Verification Code Sent',
          content: 'A 6-digit verification code has been sent to $email.\nPlease check your email inbox.',
          buttonText: 'Continue',
          type: DialogType.success,
          onPressed: () {
            Navigator.pop(context);
            // ✅ Navigate to verification page
            Navigator.pushNamed(
              context,
              '/forgot-password-verify',
              arguments: email,
            );
          },
        ),
      );
    } else {
      // ✅ FIX: Show validation message for non-existent email
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogBox(
          title: 'Email Not Found',
          content: result['message'] ?? 'No account found with this email address.',
          buttonText: 'OK',
          type: DialogType.warning,
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
              const SizedBox(height: 40),
              const PageTitle(
                title: 'Reset Password',
                leadingIcon: Icons.lock_reset,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter your email address and we\'ll send you a verification code',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              AppInputField(
                hintText: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
                errorText: _errorMessage,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 32),
              MainButton(
                label: _isLoading ? 'Sending...' : 'Send Reset Code',
                onPressed: _isLoading ? null : _handleSubmit,
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
}