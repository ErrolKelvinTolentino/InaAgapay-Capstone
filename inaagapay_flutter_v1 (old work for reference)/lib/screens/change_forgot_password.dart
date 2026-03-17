import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/page_title.dart';
import '../widgets/password_constraints.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/dialog_box.dart';
import '../services/forgot_password_service.dart';

class ChangeForgotPasswordScreen extends StatefulWidget {
  const ChangeForgotPasswordScreen({super.key});

  @override
  State<ChangeForgotPasswordScreen> createState() =>
      _ChangeForgotPasswordScreenState();
}

class _ChangeForgotPasswordScreenState extends State<ChangeForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
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

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _passwordsDoNotMatch =>
      _confirmPasswordController.text.isNotEmpty && !_passwordsMatch;

  bool get _canSubmit =>
      _calculateStrength(_passwordController.text) == PasswordStrength.strong &&
      _passwordsMatch;

  // ✅ FINAL submit handler (NO SILENT FAILS)
  Future<void> _handleChangePassword() async {
    if (!_canSubmit) {
      _shakeController.forward(from: 0);
      return;
    }

    final email = ModalRoute.of(context)!.settings.arguments as String;

    setState(() => _isLoading = true);

    final success = await ForgotPasswordService.resetPassword(
      email,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update password')),
      );
      return;
    }

    // ✅ Success dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogBox(
        title: 'Password Updated',
        buttonText: 'Continue',
        type: DialogType.success,
        onPressed: () => Navigator.pop(context),
      ),
    );

    // ✅ Redirect to login
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                title: 'Change Password',
                leadingIcon: Icons.lock,
                trailingIcon: Icons.check,
              ),

              const SizedBox(height: 24),

              AppInputField(
                hintText: 'New Password',
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
                      hintText: 'Confirm New Password',
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
                            return Row(
                              children: const [
                                Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Passwords do not match',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            );
                          }

                          if (_passwordsMatch) {
                            return Row(
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Passwords match',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            );
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
                label: _isLoading ? 'Updating...' : 'Change Password',
                showIcons: false,
                onPressed: _isLoading ? null : _handleChangePassword,
              ),

              const SizedBox(height: 16),

              SecondaryButton(
                label: 'Back to Login',
                showIcons: false,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
