import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/clickable_text.dart';
import '../services/supabase_service.dart';
import '../services/auth_storage.dart';

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
    print('=== LOGIN SCREEN INITIALIZED ===');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('=== LOGIN ATTEMPT ===');
    print('Email: ${_emailController.text}');
    print('Password length: ${_passwordController.text.length}');
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      print('ERROR: Empty fields');
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

      print('Login response: $response');
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response['success'] && response['token'] != null) {
        // Save auth data
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
          print('Profile complete: ${response['user']['profile_complete']}');
        }

        // Navigate based on role
        final role = response['user']['role'];
        final profileComplete = response['user']['profile_complete'] == true;

        if (role == 'mother') {
          if (profileComplete) {
            print('Navigating to mother dashboard');
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/mother-dashboard',
              (route) => false,
            );
          } else {
            print('Navigating to complete profile');
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/complete-profile',
              (route) => false,
            );
          }
        } else if (role == 'midwife') {
          print('Navigating to midwife dashboard');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/midwife-dashboard',
            (route) => false,
          );
        } else if (role == 'admin') {
          print('Navigating to admin dashboard');
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
          _errorMessage = response['message'];
        });
      }
    } catch (e) {
      print('Login exception: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Login screen build - Button enabled: ${!_isLoading}');
    
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              
              // App Name
              const Text(
                'Inaagapay',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDE3A53),
                ),
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
                    print('Navigating to forgot password');
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
                      print('Navigating to register');
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