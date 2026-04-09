// lib/screens/auth/login.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/clickable_text.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/validation_message.dart';

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

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    if (email.isEmpty) return true;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

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

    if (!_isEmailValid) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a valid email address';
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

      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }
      
      setState(() => _isLoading = false);

      if (kDebugMode) {
        debugPrint('=== LOGIN RESPONSE ===');
        debugPrint('Success: ${response['success']}');
        debugPrint('User data: ${response['user']}');
      }

      if (response['success'] == true && response['token'] != null) {
        await AuthStorage.saveToken(response['token']);
        await AuthStorage.saveUserRole(response['user']['role']);
        await AuthStorage.saveUserId(response['user']['id']);

        if (response['user']['role'] == 'mother') {
          final motherId = response['user']['mother_id'];
          if (motherId != null) {
            await AuthStorage.saveMotherId(motherId);
            if (kDebugMode) {
              debugPrint('Mother ID saved during login: $motherId');
            }
          } else {
            if (kDebugMode) {
              debugPrint('WARNING: mother_id is null in login response');
            }
          }
          
          final needsPasswordChange = response['user']['needs_password_change'] == true;
          final createdBy = response['user']['created_by'] as String? ?? 'self';
          final profileCompleteFromResponse = response['user']['profile_complete'] == true;
          
          if (kDebugMode) {
            debugPrint('=== ACCOUNT TYPE DETECTION ===');
            debugPrint('createdBy: $createdBy');
            debugPrint('needsPasswordChange: $needsPasswordChange');
            debugPrint('profileCompleteFromResponse: $profileCompleteFromResponse');
          }
          
          // For midwife-created or midwife-updated accounts: skip Complete Profile
          if (createdBy == 'midwife') {
            if (kDebugMode) {
              debugPrint('✅ Midwife-managed account detected - Skipping Complete Profile');
            }
            
            // Mark profile as complete since midwife filled all data
            await AuthStorage.saveProfileComplete(true);
            
            if (needsPasswordChange) {
              if (kDebugMode) {
                debugPrint('➡️ Redirecting to Change Temporary Password screen');
              }
              await AuthStorage.saveTemporaryPasswordChanged(false);
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/change-temporary-password',
                (route) => false,
              );
            } else {
              if (kDebugMode) {
                debugPrint('➡️ Redirecting to Mother Dashboard');
              }
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/mother-dashboard',
                (route) => false,
              );
            }
          } 
          // For self-registered accounts: check if profile needs completion
          else {
            if (kDebugMode) {
              debugPrint('⚠️ Self-registered account detected - Checking profile completeness');
            }
            
            // Verify if profile is actually complete by checking database
            final isActuallyComplete = await _checkProfileCompleteness(motherId);
            
            if (kDebugMode) {
              debugPrint('Profile completeness result: $isActuallyComplete');
            }
            
            if (!isActuallyComplete) {
              if (kDebugMode) {
                debugPrint('❌ Profile incomplete - Redirecting to Complete Profile');
              }
              await AuthStorage.saveProfileComplete(false);
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/complete-profile',
                (route) => false,
              );
            } else {
              if (kDebugMode) {
                debugPrint('✅ Profile complete - Redirecting to Mother Dashboard');
              }
              await AuthStorage.saveProfileComplete(true);
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/mother-dashboard',
                (route) => false,
              );
            }
          }
        } else if (response['user']['role'] == 'midwife') {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/midwife-dashboard',
            (route) => false,
          );
        } else if (response['user']['role'] == 'admin') {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _errorMessage = 'Admin accounts must use the administrative web portal.';
          });
        } else {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _errorMessage = 'Unknown user role';
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = response['message'] ?? 'Login failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  Future<bool> _checkProfileCompleteness(int? motherId) async {
    if (motherId == null) return false;
    
    try {
      if (kDebugMode) {
        debugPrint('=== CHECKING PROFILE COMPLETENESS ===');
        debugPrint('Mother ID: $motherId');
      }
      
      // Check birthdate in mothers table
      final response = await SupabaseService.client
          .from('mothers')
          .select('birthdate')
          .eq('mother_id', motherId)
          .maybeSingle();
      
      if (kDebugMode) {
        debugPrint('Mother record: $response');
      }
      
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) {
        if (kDebugMode) debugPrint('Account ID is null');
        return false;
      }
      
      // Check personal info in accounts table
      final accountResponse = await SupabaseService.client
          .from('accounts')
          .select('first_name, last_name, phone_number, created_by')
          .eq('account_id', accountId)
          .maybeSingle();
      
      if (kDebugMode) {
        debugPrint('Account record: $accountResponse');
      }
      
      // Check ONLY essential fields (not address fields)
      final hasFirstName = accountResponse != null && 
                           accountResponse['first_name'] != null && 
                           accountResponse['first_name'].toString().isNotEmpty;
      final hasLastName = accountResponse != null && 
                          accountResponse['last_name'] != null && 
                          accountResponse['last_name'].toString().isNotEmpty;
      final hasBirthdate = response != null && response['birthdate'] != null;
      final hasPhone = accountResponse != null && 
                       accountResponse['phone_number'] != null && 
                       accountResponse['phone_number'].toString().isNotEmpty;
      
      final isComplete = hasFirstName && hasLastName && hasBirthdate && hasPhone;
      
      if (kDebugMode) {
        debugPrint('Profile completeness check results:');
        debugPrint('  hasFirstName: $hasFirstName');
        debugPrint('  hasLastName: $hasLastName');
        debugPrint('  hasBirthdate: $hasBirthdate');
        debugPrint('  hasPhone: $hasPhone');
        debugPrint('  isComplete: $isComplete');
      }
      
      return isComplete;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking profile completeness: $e');
      }
      return false;
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
                  setState(() {});
                  if (_hasError) setState(() => _hasError = false);
                },
              ),

              if (_emailController.text.isNotEmpty && !_isEmailValid) ...[
                const SizedBox(height: 8),
                const ValidationMessage(
                  message: 'Please enter a valid email address',
                  type: ValidationType.error,
                ),
              ],

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
                ValidationMessage(
                  message: _errorMessage,
                  type: ValidationType.error,
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