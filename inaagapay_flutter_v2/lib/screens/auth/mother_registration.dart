// lib/screens/auth/mother_registration.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/clickable_text.dart';
import '../../widgets/page_title.dart';
import '../../widgets/password_constraints.dart';
import '../../widgets/password_strength_indicator.dart';
import '../../widgets/dialog_box.dart';
import '../../services/supabase_service.dart';
import '../../models/password_strength.dart';

class MotherRegistrationScreen extends StatefulWidget {
  const MotherRegistrationScreen({super.key});

  @override
  State<MotherRegistrationScreen> createState() =>
      _MotherRegistrationScreenState();
}

class _MotherRegistrationScreenState extends State<MotherRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('=== REGISTRATION SCREEN INITIALIZED ===');
    }

    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController.dispose();
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

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _passwordsDoNotMatch =>
      _confirmPasswordController.text.isNotEmpty && !_passwordsMatch;

  bool get _canSubmit =>
      _isEmailValid &&
      _calculateStrength(_passwordController.text) == PasswordStrength.strong &&
      _passwordsMatch &&
      !_isLoading;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call register method instead of sendOTPEmail directly
      final result = await SupabaseService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);
      
      if (!mounted) return;

      if (result['success'] == true) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogBox(
            title: 'Verification Code Sent',
            content: 'A 6-digit verification code has been sent to ${_emailController.text.trim()}',
            buttonText: 'Continue',
            type: DialogType.success,
            onPressed: () => Navigator.pop(context),
          ),
        );

        if (mounted) {
          // Navigate to verification screen
          Navigator.pushNamed(
            context,
            '/verify-registration',
            arguments: _emailController.text.trim(),
          );
        }
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;
    final strength = _calculateStrength(password);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // App Name
              const Text(
                'Inaagapay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF68A5),
                ),
              ),

              const SizedBox(height: 24),

              const PageTitle(
                title: 'Create Account',
                leadingIcon: Icons.person,
                trailingIcon: Icons.check,
              ),

              const SizedBox(height: 24),

              // Email
              AppInputField(
                hintText: 'Enter Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Builder(
                  builder: (context) {
                    if (_emailController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    if (!_isEmailValid) {
                      return _errorRow('Enter a valid email address');
                    }
                    return _successRow('Email looks good');
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Password
              AppInputField(
                hintText: 'Create Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                leadingIcon: Icons.lock_outline,
                isRequired: true,
                trailingIcon: _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                onTrailingTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PasswordStrengthIndicator(strength: strength),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: PasswordConstraints(password: password),
              ),

              const SizedBox(height: 20),

              // Confirm password + shake animation on error
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInputField(
                      hintText: 'Confirm Password',
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      leadingIcon: Icons.lock_outline,
                      isRequired: true,
                      trailingIcon: _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      onTrailingTap: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Builder(
                        builder: (context) {
                          if (_passwordsDoNotMatch) {
                            return _errorRow('Passwords do not match');
                          }
                          if (_passwordsMatch && _confirmPasswordController.text.isNotEmpty) {
                            return _successRow('Passwords match');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              MainButton(
                label: _isLoading ? 'Creating Account...' : 'Create Account',
                showIcons: false,
                onPressed: _canSubmit ? _handleSubmit : null,
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ClickableText(
                    text: 'Sign in Here',
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorRow(String text) {
    return Row(
      children: [
        const Icon(Icons.cancel, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text, 
            style: const TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _successRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text, 
            style: const TextStyle(fontSize: 13, color: AppColors.success),
          ),
        ),
      ],
    );
  }
}