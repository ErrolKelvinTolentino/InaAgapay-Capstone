import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/clickable_text.dart';
import '../widgets/page_title.dart';
import '../widgets/password_constraints.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/dialog_box.dart';
import '../services/supabase_service.dart';
import '../models/password_strength.dart';

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
  bool _isLoading = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    print('=== REGISTRATION SCREEN INITIALIZED ===');

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
    final isValid = RegExp(r'^[^@]+@[^@]+\.[^@]+')
        .hasMatch(_emailController.text.trim());
    print('Email valid check: $isValid for ${_emailController.text}');
    return isValid;
  }

  bool get _passwordsMatch {
    final match = _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
    print('Passwords match: $match');
    return match;
  }

  bool get _canSubmit {
    final canSubmit = _isEmailValid &&
        _calculateStrength(_passwordController.text) == PasswordStrength.strong &&
        _passwordsMatch &&
        !_isLoading;
    
    print('=== CAN SUBMIT CHECK ===');
    print('Email valid: $_isEmailValid');
    print('Password strength: ${_calculateStrength(_passwordController.text)}');
    print('Passwords match: $_passwordsMatch');
    print('Loading: $_isLoading');
    print('Can submit: $canSubmit');
    
    return canSubmit;
  }

  Future<void> _handleSubmit() async {
    print('=== HANDLE SUBMIT CALLED ===');
    
    if (!_canSubmit) {
      print('Cannot submit - validation failed');
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _isLoading = true);

    final res = await SupabaseService.register(
      _emailController.text.trim(),
      _passwordController.text,
    );

    print('Registration response: $res');
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!res['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (res['email_failed'] == true) {
      await showDialog(
        context: context,
        builder: (_) => DialogBox(
          title: 'Warning',
          content: 'Account created but we couldn\'t send the verification email. Please use "Resend Code" on the next screen.',
          buttonText: 'Continue',
          type: DialogType.warning,
          onPressed: () => Navigator.pop(context),
        ),
      );
    } else {
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
    }

    if (mounted) {
      print('Navigating to verification screen');
      Navigator.pushNamed(
        context,
        '/verify-registration',
        arguments: _emailController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(_passwordController.text);
    
    print('=== REGISTRATION BUILD ===');
    print('Button enabled: $_canSubmit');

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
                  color: Color(0xFFDE3A53),
                ),
              ),
              
              const SizedBox(height: 24),
              
              const PageTitle(
                title: 'Create Account',
                leadingIcon: Icons.person,
                trailingIcon: Icons.check,
              ),
              const SizedBox(height: 24),
              
              AppInputField(
                hintText: 'Enter Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
                isRequired: true,
                onChanged: (_) {
                  setState(() {});
                  print('Email changed: ${_emailController.text}');
                },
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
                isRequired: true,
                onChanged: (_) {
                  setState(() {});
                  print('Password changed, length: ${_passwordController.text.length}');
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
                  isRequired: true,
                  onChanged: (_) {
                    setState(() {});
                    print('Confirm password changed, match: $_passwordsMatch');
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Debug button to test navigation
              if (true) // Set to false to hide
                ElevatedButton(
                  onPressed: () {
                    print('TEST BUTTON PRESSED - Force navigation');
                    Navigator.pushNamed(
                      context,
                      '/verify-registration',
                      arguments: 'test@example.com',
                    );
                  },
                  child: const Text('TEST NAVIGATION'),
                ),
              
              const SizedBox(height: 8),
              
              MainButton(
                label: _isLoading ? 'Sending...' : 'Send Verification Code',
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
                      print('Navigating to login');
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