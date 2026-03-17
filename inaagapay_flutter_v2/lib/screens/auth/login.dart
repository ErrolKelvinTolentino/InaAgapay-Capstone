// lib/screens/auth/login.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/clickable_text.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';

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
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('=== LOGIN SCREEN INITIALIZED ===');
    }
  }

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
      final response = await SupabaseService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (response['success'] && response['token'] != null) {
        await AuthStorage.saveToken(response['token']);
        await AuthStorage.saveUserRole(response['user']['role']);
        await AuthStorage.saveUserId(response['user']['id']);

        if (response['user']['role'] == 'mother') {
          if (response['user']['mother_id'] != null) {
            await AuthStorage.saveMotherId(response['user']['mother_id']);
          }
          await AuthStorage.saveProfileComplete(
            response['user']['profile_complete'] == true,
          );
        }

        final role = response['user']['role'];
        final profileComplete = response['user']['profile_complete'] == true;

        if (!mounted) return;

        if (role == 'mother') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            profileComplete ? '/mother-dashboard' : '/complete-profile',
            (route) => false,
          );
        } else if (role == 'midwife') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/midwife-dashboard',
            (route) => false,
          );
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = role == 'admin'
                ? 'Admin accounts must use the administrative web portal.'
                : 'Unknown user role';
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = response['message'] ?? 'Login failed';
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

              // Logo
              Image.asset('assets/images/logo.png', height: 146),

              const SizedBox(height: 20),

              // App name
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
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 56),

              // Email
              AppInputField(
                hintText: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.email_outlined,
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
              ),

              const SizedBox(height: 20),

              // Password
              AppInputField(
                hintText: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                leadingIcon: Icons.lock_outline,
                trailingIcon:
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                onTrailingTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
              ),

              // Error message
              if (_hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 20),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: ClickableText(
                  text: 'Forgot Password?',
                  onTap: () => Navigator.pushNamed(context, '/forgot-password'),
                ),
              ),

              const SizedBox(height: 56),

              // Sign in button
              MainButton(
                label: _isLoading ? 'Signing in...' : 'Sign in',
                showIcons: false,
                onPressed: _isLoading ? null : _handleLogin,
              ),

              const SizedBox(height: 32),

              // Register link
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
                    onTap: () => Navigator.pushNamed(context, '/register'),
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
