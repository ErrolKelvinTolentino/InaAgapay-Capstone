import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/clickable_text.dart';
import '../widgets/page_title.dart';
import '../widgets/password_constraints.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/dialog_box.dart';

class MotherRegistrationScreen extends StatefulWidget {
  const MotherRegistrationScreen({super.key});

  @override
  State<MotherRegistrationScreen> createState() =>
      _MotherRegistrationScreenState();
}

class _MotherRegistrationScreenState extends State<MotherRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _emailExists = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _emailController.addListener(() {
      final email = _emailController.text.trim().toLowerCase();
      setState(() {
        _emailExists = email == 'existing@gmail.com';
      });
    });

    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation =
        TweenSequence<double>([
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

  // 🔐 Password strength rules
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
      !_emailExists &&
      _calculateStrength(_passwordController.text) == PasswordStrength.strong &&
      _passwordsMatch;

  // ✅ Submit handler
  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      _shakeController.forward(from: 0);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogBox(
        title: 'Verification Code Sent',
        buttonText: 'Continue',
        type: DialogType.info,
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;

    Navigator.pushNamed(context, '/verify-registration');
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

              Image.asset('assets/images/logo.png', height: 110),
              const SizedBox(height: 16),
              Image.asset('assets/images/inaagapay_name.png', width: 240),

              const SizedBox(height: 24),

              const PageTitle(
                title: 'Create Account',
                leadingIcon: Icons.person,
                trailingIcon: Icons.check,
              ),

              const SizedBox(height: 24),

              // 📧 Email Field
              AppInputField(
                hintText: 'Enter Email Address*',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Builder(
                  builder: (_) {
                    if (_emailController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    if (!_isEmailValid) {
                      return _errorRow('Enter a valid email address');
                    }

                    if (_emailExists) {
                      return _errorRow('Email already exists');
                    }

                    return _successRow('Email looks good');
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 🔐 Password
              AppInputField(
                hintText: 'Create Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                leadingIcon: Icons.lock_outline,
                trailingIcon: _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                onTrailingTap: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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

              // 🔁 Confirm Password + Shake
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInputField(
                      hintText: 'Confirm Password',
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      leadingIcon: Icons.lock_outline,
                      trailingIcon: _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      onTrailingTap: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Builder(
                        builder: (_) {
                          if (_passwordsDoNotMatch) {
                            return _errorRow('Passwords do not match');
                          }

                          if (_passwordsMatch) {
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

              // 🚀 Submit Button
              MainButton(
                label: 'Send Verification Code',
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
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
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

  // 🔧 Helper rows
  Widget _errorRow(String text) {
    return Row(
      children: [
        const Icon(Icons.cancel, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.error),
        ),
      ],
    );
  }

  Widget _successRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.success),
        ),
      ],
    );
  }
}
