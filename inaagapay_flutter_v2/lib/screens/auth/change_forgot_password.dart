import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/page_title.dart';
import '../widgets/password_constraints.dart';
import '../widgets/password_strength_indicator.dart';
import '../models/password_strength.dart';

class ChangeForgotPasswordScreen extends StatefulWidget {
  const ChangeForgotPasswordScreen({super.key});

  @override
  State<ChangeForgotPasswordScreen> createState() => _ChangeForgotPasswordScreenState();
}

class _ChangeForgotPasswordScreenState extends State<ChangeForgotPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  PasswordStrength _calculateStrength(String password) {
    int met = 0;
    if (password.length >= 8) met++;
    if (RegExp(r'\d').hasMatch(password)) met++;
    if (RegExp(r'[A-Z]').hasMatch(password)) met++;
    if (RegExp(r'[a-z]').hasMatch(password)) met++;

    if (met <= 1) return PasswordStrength.weak;
    if (met <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _canSubmit =>
      _calculateStrength(_newPasswordController.text) == PasswordStrength.strong &&
      _passwordsMatch &&
      !_isLoading;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    
    setState(() => _isLoading = true);

    // TODO: Update password in Supabase
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call

    if (!mounted) return;
    setState(() => _isLoading = false);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate to login
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(_newPasswordController.text);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // App Name (text instead of image)
              const Text(
                'Inaagapay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDE3A53),
                ),
              ),
              
              const SizedBox(height: 40),
              
              const PageTitle(
                title: 'New Password',
                leadingIcon: Icons.lock,
              ),
              const SizedBox(height: 32),
              AppInputField(
                hintText: 'New Password',
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                leadingIcon: Icons.lock_outline,
                trailingIcon: _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                onTrailingTap: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PasswordStrengthIndicator(strength: strength),
              ),
              const SizedBox(height: 12),
              PasswordConstraints(password: _newPasswordController.text),
              const SizedBox(height: 20),
              AppInputField(
                hintText: 'Confirm Password',
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                leadingIcon: Icons.lock_outline,
                trailingIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                onTrailingTap: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              const SizedBox(height: 32),
              MainButton(
                label: _isLoading ? 'Updating...' : 'Update Password',
                showIcons: false,
                onPressed: _canSubmit ? _handleSubmit : null,
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