import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
// Add to SupabaseService class
static Future<Map<String, dynamic>> getMidwifeContext(int accountId) async {
  try {
    if (kDebugMode) {
      print('=== GET MIDWIFE CONTEXT ===');
      print('Account ID: $accountId');
    }

    // Get midwife details
    final midwifeResponse = await client
        .from('midwives')
        .select('''
          midwife_id,
          assigned_bhc_id,
          bhc!inner (
            bhc_name
          )
        ''')
        .eq('account_id', accountId)
        .maybeSingle();

    if (midwifeResponse == null) {
      return {
        'success': false,
        'message': 'Midwife record not found',
      };
    }

    final bhc = midwifeResponse['bhc'] as Map?;

    return {
      'success': true,
      'midwife_id': midwifeResponse['midwife_id'],
      'assigned_bhc_id': midwifeResponse['assigned_bhc_id'],
      'bhc_name': bhc?['bhc_name'] ?? '',
    };
  } catch (e) {
    if (kDebugMode) {
      print('Error getting midwife context: $e');
    }
    return {
      'success': false,
      'message': 'Failed to get midwife context: ${e.toString()}',
    };
  }
}

// Add email availability check
static Future<bool> isEmailAvailable(String email) async {
  try {
    final result = await client
        .from('accounts')
        .select('account_id')
        .eq('email_address', email)
        .maybeSingle();
    
    return result == null;
  } catch (e) {
    if (kDebugMode) {
      print('Error checking email: $e');
    }
    return false;
  }
}

  // Generate 6-digit OTP code
  static String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Test connection
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('Testing Supabase connection...');
      }
      final result = await client.from('accounts').select('count').limit(1);
      if (kDebugMode) {
        print('Connection test result: $result');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Connection test failed: $e');
      }
      return false;
    }
  }

  // Login - Using Supabase Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (kDebugMode) {
        print('Attempting login for: $email');
      }
      
      // Test connection first
      final isConnected = await testConnection();
      if (!isConnected) {
        return {
          'success': false,
          'message': 'Cannot connect to server. Please check your internet connection.'
        };
      }
      
      // Use Supabase Auth to sign in
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        if (kDebugMode) {
          print('✅ Auth login successful');
          print('User ID: ${response.user!.id}');
          print('Email confirmed: ${response.user!.emailConfirmedAt}');
        }
        
        // Get user details from accounts table using email
        final accountResponse = await client
            .from('accounts')
            .select('''
              account_id,
              account_type,
              first_name,
              middle_name,
              last_name,
              extension_name,
              phone_number,
              is_verified,
              status
            ''')
            .eq('email_address', email)
            .maybeSingle();

        // If account doesn't exist in accounts table, create it
        if (accountResponse == null) {
          if (kDebugMode) {
            print('Account not found in accounts table, creating...');
          }
          
          final newAccount = await client.from('accounts').insert({
            'email_address': email,
            'account_type': 'mother',
            'is_verified': response.user!.emailConfirmedAt != null,
            'status': response.user!.emailConfirmedAt != null ? 'active' : 'inactive',
            'created_at': DateTime.now().toIso8601String(),
          }).select('account_id, account_type, first_name, last_name, is_verified, status').single();
              
          // Generate token
          final token = _generateOTP() + DateTime.now().millisecondsSinceEpoch.toString();
          
          return {
            'success': true,
            'message': 'Login successful',
            'token': token,
            'user': {
              'id': newAccount['account_id'],
              'role': newAccount['account_type'],
              'first_name': newAccount['first_name'],
              'last_name': newAccount['last_name'],
              'profile_complete': false,
              'mother_id': null,
            },
          };
        }

        // Check if email is verified
        final isEmailVerified = response.user!.emailConfirmedAt != null;
        
        if (!isEmailVerified) {
          return {'success': false, 'message': 'Please verify your email first'};
        }

        // Check account status
        if (accountResponse['status'] != 'active') {
          // Auto-fix status if email is verified
          if (isEmailVerified) {
            await client
                .from('accounts')
                .update({'status': 'active', 'is_verified': true})
                .eq('email_address', email);
                
            if (kDebugMode) {
              print('✅ Auto-fixed account status to active');
            }
          } else {
            return {'success': false, 'message': 'Account is inactive'};
          }
        }

        // Check if mother profile is complete
        Map<String, dynamic>? motherData;
        bool profileComplete = false;
        
        if (accountResponse['account_type'] == 'mother') {
          try {
            motherData = await client
                .from('mothers')
                .select('''
                  mother_id,
                  birthdate,
                  house_number,
                  street,
                  barangay,
                  city_municipality,
                  province
                ''')
                .eq('account_id', accountResponse['account_id'])
                .maybeSingle();
            
            if (motherData != null) {
              profileComplete = 
                  accountResponse['first_name'] != null && 
                  accountResponse['last_name'] != null && 
                  motherData['birthdate'] != null;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching mother data: $e');
            }
          }
        }

        // Generate token
        final token = _generateOTP() + DateTime.now().millisecondsSinceEpoch.toString();

        return {
          'success': true,
          'message': 'Login successful',
          'token': token,
          'user': {
            'id': accountResponse['account_id'],
            'role': accountResponse['account_type'],
            'first_name': accountResponse['first_name'],
            'last_name': accountResponse['last_name'],
            'profile_complete': profileComplete,
            'mother_id': motherData?['mother_id'],
          },
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid email or password',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      
      // Handle specific error cases
      if (e.toString().contains('Invalid login credentials')) {
        return {
          'success': false,
          'message': 'Invalid email or password',
        };
      }
      
      if (e.toString().contains('Email not confirmed')) {
        return {
          'success': false,
          'message': 'Please verify your email first',
        };
      }
      
      return {
        'success': false,
        'message': 'Login failed. Please try again.',
      };
    }
  }

  // Register with Supabase Auth
  static Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      if (kDebugMode) {
        print('=== REGISTRATION ATTEMPT ===');
        print('Email: $email');
      }
      
      // Use Supabase Auth to sign up
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Generate OTP for database
        final code = _generateOTP();
        final expires = DateTime.now().add(const Duration(minutes: 10)).toIso8601String();
        
        // Check if account already exists in accounts table
        final existing = await client
            .from('accounts')
            .select('account_id')
            .eq('email_address', email)
            .maybeSingle();

        if (existing == null) {
          // Create new account record
          await client.from('accounts').insert({
            'email_address': email,
            'account_type': 'mother',
            'is_verified': false,
            'status': 'inactive',
            'verification_code': code,
            'verification_expires': expires,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        if (kDebugMode) {
          print('✅ Registration successful');
          print('🔐 Verification code: $code');
        }

        return {
          'success': true,
          'message': 'Verification email sent. Please check your inbox.',
          'code': kDebugMode ? code : null,
        };
      } else {
        return {
          'success': false,
          'message': 'Registration failed',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Registration error: $e');
      }
      
      if (e.toString().contains('User already registered')) {
        return {
          'success': false,
          'message': 'Email already registered. Please login.',
        };
      }
      
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // Send OTP via email using Supabase Auth
  static Future<Map<String, dynamic>> sendOTPEmail(String email) async {
    try {
      if (kDebugMode) {
        print('📧 Sending OTP via Supabase Auth to: $email');
      }
      
      // Generate OTP for database
      final otpCode = _generateOTP();
      
      // Use Supabase to send OTP email
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      // Check if account exists
      final existingAccount = await client
          .from('accounts')
          .select('account_id')
          .eq('email_address', email)
          .maybeSingle();

      // Store OTP in your accounts table for verification
      if (existingAccount == null) {
        // Create new account record
        await client.from('accounts').insert({
          'email_address': email,
          'account_type': 'mother',
          'is_verified': false,
          'status': 'inactive',
          'verification_code': otpCode,
          'verification_expires': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing account with new OTP
        await client
            .from('accounts')
            .update({
              'verification_code': otpCode,
              'verification_expires': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
              'status': 'inactive',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('email_address', email);
      }

      if (kDebugMode) {
        print('✅ OTP sent successfully');
        print('🔐 OTP Code for testing: $otpCode');
      }

      return {
        'success': true,
        'message': 'OTP sent to your email',
        'code': kDebugMode ? otpCode : null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error sending OTP: $e');
      }
      
      if (e.toString().contains('rate limit')) {
        return {
          'success': false,
          'message': 'Too many attempts. Please wait a few minutes.',
          'rate_limited': true,
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to send OTP. Please try again.',
      };
    }
  }

  // Verify OTP code
  static Future<bool> verifyCode(String email, String code) async {
    try {
      if (kDebugMode) {
        print('=== VERIFYING CODE ===');
        print('Email: $email');
        print('Code: $code');
      }
      
      // First try to verify with Supabase Auth
      try {
        final response = await client.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.email,
        );
        
        if (response.user != null) {
          if (kDebugMode) {
            print('✅ OTP verified via Supabase Auth');
          }
          
          // Update account in database
          await client
              .from('accounts')
              .update({
                'is_verified': true,
                'status': 'active',
                'verification_code': null,
                'verification_expires': null,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('email_address', email);
              
          return true;
        }
      } catch (authError) {
        if (kDebugMode) {
          print('Supabase Auth verification failed, checking database: $authError');
        }
      }
      
      // Fallback: Check against database directly
      final account = await client
          .from('accounts')
          .select('verification_code, verification_expires')
          .eq('email_address', email)
          .maybeSingle();

      if (account == null) return false;

      // Check if code matches
      if (account['verification_code'] != code) return false;

      // Check if code is expired
      final expires = DateTime.parse(account['verification_expires']);
      if (expires.isBefore(DateTime.now())) return false;

      // Mark as verified
      await client
          .from('accounts')
          .update({
            'is_verified': true,
            'status': 'active',
            'verification_code': null,
            'verification_expires': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('email_address', email);

      if (kDebugMode) {
        print('✅ Code verified via database');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Verification error: $e');
      }
      return false;
    }
  }

  // Resend verification code
  static Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    try {
      final code = _generateOTP();
      final expires = DateTime.now().add(const Duration(minutes: 10)).toIso8601String();

      if (kDebugMode) {
        print('Resending code: $code to: $email');
      }

      // Update the code in database
      await client
          .from('accounts')
          .update({
            'verification_code': code,
            'verification_expires': expires,
          })
          .eq('email_address', email)
          .eq('is_verified', false);

      // Send email via Supabase Auth
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      return {
        'success': true,
        'message': 'New verification code sent to your email.',
        'code': kDebugMode ? code : null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error resending code: $e');
      }
      return {
        'success': false,
        'message': 'Failed to resend code. Please try again.',
      };
    }
  }

  // Reset Password - Send reset email
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      if (kDebugMode) {
        print('📧 Sending password reset email to: $email');
      }
      
      await client.auth.resetPasswordForEmail(email);

      return {
        'success': true,
        'message': 'Password reset email sent. Please check your inbox.',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error sending reset email: $e');
      }
      
      if (e.toString().contains('rate limit')) {
        return {
          'success': false,
          'message': 'Too many attempts. Please wait a few minutes.',
          'rate_limited': true,
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to send reset email. Please try again.',
      };
    }
  }

  // Update password after reset
  static Future<Map<String, dynamic>> updatePassword(String newPassword) async {
    try {
      if (kDebugMode) {
        print('Updating password...');
      }
      
      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      return {
        'success': true,
        'message': 'Password updated successfully.',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error updating password: $e');
      }
      return {
        'success': false,
        'message': 'Failed to update password. Please try again.',
      };
    }
  }

  // Complete mother profile
  static Future<Map<String, dynamic>> completeMotherProfile(
    int accountId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      if (kDebugMode) {
        print('=== COMPLETING MOTHER PROFILE ===');
        print('Account ID: $accountId');
      }
      
      // Update accounts table with personal info
      await client
          .from('accounts')
          .update({
            'first_name': profileData['first_name'],
            'middle_name': profileData['middle_name'],
            'last_name': profileData['last_name'],
            'extension_name': profileData['extension_name'],
            'phone_number': profileData['contact_number'],
          })
          .eq('account_id', accountId);

      // Check if mother record exists
      final existingMother = await client
          .from('mothers')
          .select('mother_id')
          .eq('account_id', accountId)
          .maybeSingle();

      // Parse birth date
      String? birthDateStr;
      if (profileData['birth_date'] != null && profileData['birth_date'].isNotEmpty) {
        try {
          if (profileData['birth_date'].contains('/')) {
            final parts = profileData['birth_date'].split('/');
            if (parts.length == 3) {
              final month = int.parse(parts[0]);
              final day = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              birthDateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            }
          } else {
            birthDateStr = profileData['birth_date'];
          }
        } catch (e) {
          if (kDebugMode) {
            print('Date parsing error: $e');
          }
          birthDateStr = profileData['birth_date'];
        }
      }

      if (existingMother == null) {
        // Insert mother record
        await client.from('mothers').insert({
          'account_id': accountId,
          'birthdate': birthDateStr,
          'house_number': profileData['house_no'],
          'street': profileData['street'],
          'barangay': profileData['barangay'],
          'city_municipality': profileData['city'],
          'province': profileData['province'],
        });
      } else {
        // Update mother record
        await client
            .from('mothers')
            .update({
              'birthdate': birthDateStr,
              'house_number': profileData['house_no'],
              'street': profileData['street'],
              'barangay': profileData['barangay'],
              'city_municipality': profileData['city'],
              'province': profileData['province'],
            })
            .eq('account_id', accountId);
      }

      return {'success': true, 'message': 'Profile completed successfully'};
    } catch (e) {
      if (kDebugMode) {
        print('Profile completion error: $e');
      }
      return {'success': false, 'message': 'Failed to complete profile: ${e.toString()}'};
    }
  }

  // Get greeting data
  static Future<Map<String, dynamic>> getGreeting(int accountId, String role) async {
    try {
      final accountResponse = await client
          .from('accounts')
          .select('''
            first_name,
            middle_name,
            last_name,
            extension_name
          ''')
          .eq('account_id', accountId)
          .maybeSingle();

      if (role == 'mother') {
        final motherResponse = await client
            .from('mothers')
            .select('''
              assigned_bhc_id,
              bhc!inner (
                bhc_name
              )
            ''')
            .eq('account_id', accountId)
            .maybeSingle();

        final bhc = motherResponse?['bhc'] as Map?;

        return {
          'success': true,
          'first_name': accountResponse?['first_name'],
          'middle_name': accountResponse?['middle_name'],
          'last_name': accountResponse?['last_name'],
          'extension_name': accountResponse?['extension_name'],
          'bhc_name': bhc?['bhc_name'] ?? 'No Barangay Assigned',
        };
      }
      
      if (role == 'midwife') {
        final midwifeResponse = await client
            .from('midwives')
            .select('''
              assigned_bhc_id,
              bhc!inner (
                bhc_name
              )
            ''')
            .eq('account_id', accountId)
            .maybeSingle();

        final bhc = midwifeResponse?['bhc'] as Map?;

        return {
          'success': true,
          'first_name': accountResponse?['first_name'],
          'middle_name': accountResponse?['middle_name'],
          'last_name': accountResponse?['last_name'],
          'extension_name': accountResponse?['extension_name'],
          'bhc_name': bhc?['bhc_name'],
        };
      }

      return {
        'success': true,
        'first_name': accountResponse?['first_name'],
        'middle_name': accountResponse?['middle_name'],
        'last_name': accountResponse?['last_name'],
        'extension_name': accountResponse?['extension_name'],
        'bhc_name': null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Greeting error: $e');
      }
      return {'success': false, 'message': 'Failed to fetch greeting'};
    }
  }

  // Logout
  static Future<void> logout() async {
    await client.auth.signOut();
  }
}

