import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/clickable_text.dart';
import '../widgets/page_title.dart';
import '../widgets/password_constraints.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/dialog_box.dart';
import '../services/api_service.dart';

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

  bool get _isEmailValid =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+')
          .hasMatch(_emailController.text.trim());

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _canSubmit =>
      _isEmailValid &&
      !_emailExists &&
      _calculateStrength(_passwordController.text) ==
          PasswordStrength.strong &&
      _passwordsMatch;

  // ✅ WIRED TO PHP REGISTER
  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      _shakeController.forward(from: 0);
      return;
    }

    final res = await ApiService.post(
      'auth/register.php',
      {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      },
    );

    if (!res['success']) {
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogBox(
        title: 'Verification Code Sent',
        buttonText: 'Continue',
        type: DialogType.info,
        onPressed: () => Navigator.pop(context),
      ),
    );

    Navigator.pushNamed(
      context,
      '/verify-registration',
      arguments: _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(_passwordController.text);

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

              AppInputField(
                hintText: 'Enter Email Address*',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),

              AppInputField(
                hintText: 'Create Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                leadingIcon: Icons.lock_outline,
                trailingIcon: _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                onTrailingTap: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: PasswordStrengthIndicator(strength: strength),
              ),

              const SizedBox(height: 12),

              PasswordConstraints(password: _passwordController.text),

              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: AppInputField(
                  hintText: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  leadingIcon: Icons.lock_outline,
                  trailingIcon: _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  onTrailingTap: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),

              const SizedBox(height: 32),

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
                    style: TextStyle(fontSize: 14),
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
}
