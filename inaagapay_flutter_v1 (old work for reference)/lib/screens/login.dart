import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/clickable_text.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../utils/session.dart'; // For backward compatibility

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final response = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.success && response.token != null) {
        // 🔐 SAVE TOKEN (multiple ways for compatibility)
        await AuthStorage.saveToken(response.token!);
        Session.token = response.token!; // For backward compatibility

        final user = response.user;

        // 🔥🔥🔥 REQUIRED FIX: SAVE MOTHER ID 🔥🔥🔥
        if (user?['mother_id'] != null) {
          await AuthStorage.saveMotherId(user!['mother_id']);
        }

        // Check if profile is complete (from brent-ver-mother)
        final bool profileComplete = user?['profile_complete'] == true;

        // ✅ ROLE-BASED NAVIGATION WITH PROFILE COMPLETION CHECK
        if (user?['role'] == 'mother') {
          if (profileComplete) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/mother-dashboard',
              (route) => false,
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/complete-profile',
              (route) => false,
            );
          }
        } else if (user?['role'] == 'midwife') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/midwife-dashboard',
            (route) => false,
          );
        } else if (user?['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/admin-dashboard',
            (route) => false,
          );
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Unknown user role';
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = response.message;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // App Logo
              Image.asset('assets/images/logo.png', height: 146),

              const SizedBox(height: 20),

              // App Name
              Image.asset(
                'assets/images/inaagapay_name.png',
                width: 282,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Supporting you through every step',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 56),

              // Email Field
              AppInputField(
                hintText: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
                onChanged: (_) {
                  if (_hasError) {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              // Password Field
              AppInputField(
                hintText: 'Password',
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
                onChanged: (_) {
                  if (_hasError) {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    });
                  }
                },
              ),

              // Error Message
              if (_hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 20),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: ClickableText(
                  text: 'Forgot Password?',
                  onTap: () {
                    Navigator.pushNamed(context, '/forgot-password');
                  },
                ),
              ),

              const SizedBox(height: 56),

              // Sign In Button
              MainButton(
                label: _isLoading ? 'Signing in...' : 'Sign in',
                showIcons: false,
                onPressed: _isLoading ? null : _handleLogin,
              ),

              const SizedBox(height: 32),

              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No account yet? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ClickableText(
                    text: 'Register Here',
                    onTap: () {
                      Navigator.pushNamed(context, '/register');
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
