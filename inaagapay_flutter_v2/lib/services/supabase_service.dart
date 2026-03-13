// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';

class SupabaseService {
  // This ensures we always get the current client
  static SupabaseClient get client => Supabase.instance.client;

  // Generate 6-digit OTP code
  static String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Hash password using bcrypt
  static String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  // Verify password against bcrypt hash
  static bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return password == hash;
    }
  }

  // Test connection
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) debugPrint('Testing Supabase connection...');
      final result = await client.from('accounts').select('count').limit(1);
      if (kDebugMode) debugPrint('Connection test result: $result');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // Login - Using custom authentication with accounts table
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      if (kDebugMode) debugPrint('Attempting login for: $email');

      // Test connection first
      final isConnected = await testConnection();
      if (!isConnected) {
        return {
          'success': false,
          'message':
              'Cannot connect to server. Please check your internet connection.'
        };
      }

      // Get the account with personal info
      final accountResponse = await client.from('accounts').select('''
            account_id,
            email_address,
            password_hash,
            account_type,
            is_verified,
            status,
            first_name,
            middle_name,
            last_name,
            extension_name,
            phone_number
          ''').eq('email_address', email).maybeSingle();

      if (kDebugMode) debugPrint('Account query response: $accountResponse');

      if (accountResponse == null) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      // Block admin accounts from mobile login
      if (accountResponse['account_type'] == 'admin') {
        return {
          'success': false,
          'message': 'Admin accounts must use the administrative web portal.'
        };
      }

      // Check password using bcrypt
      if (!_verifyPassword(password, accountResponse['password_hash'] ?? '')) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      if (!accountResponse['is_verified']) {
        return {'success': false, 'message': 'Account not verified'};
      }

      if (accountResponse['status'] != 'active') {
        return {'success': false, 'message': 'Account inactive'};
      }

      // If mother, check if mother record exists
      Map<String, dynamic>? motherData;
      bool profileComplete = false;

      if (accountResponse['account_type'] == 'mother') {
        try {
          // Get mother data
          motherData = await client
              .from('mothers')
              .select('''
                mother_id,
                birthdate,
                house_number,
                street,
                barangay,
                city_municipality,
                province,
                height,
                weight,
                blood_type
              ''')
              .eq('account_id', accountResponse['account_id'])
              .maybeSingle();

          if (kDebugMode) debugPrint('Mother data: $motherData');

          if (motherData != null) {
            profileComplete = accountResponse['first_name'] != null &&
                accountResponse['last_name'] != null &&
                motherData['birthdate'] != null;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error fetching mother data: $e');
        }
      }

      // Generate a custom token (just a random string for session management)
      final token = _generateOTP() + DateTime.now().millisecondsSinceEpoch.toString();

      // Update last login token in accounts table
      try {
        await client.from('accounts').update({
          'last_login_token': token,
          'last_login_at': DateTime.now().toIso8601String(),
        }).eq('account_id', accountResponse['account_id']);
      } catch (e) {
        if (kDebugMode) debugPrint('Error updating last login token: $e');
      }

      // Prepare user response
      final userData = {
        'id': accountResponse['account_id'],
        'role': accountResponse['account_type'],
      };

      if (accountResponse['account_type'] == 'mother') {
        userData['profile_complete'] = profileComplete;
        userData['mother_id'] = motherData?['mother_id'];
      }

      return {
        'success': true,
        'message': 'Login successful',
        'token': token,
        'user': userData,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Login error details: $e');
      return {'success': false, 'message': 'Login failed. Please try again.'};
    }
  }

  // Ensure session is active (simplified version without Supabase Auth)
  static Future<bool> ensureSession() async {
    try {
      final token = await AuthStorage.getToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) debugPrint('✅ Session token exists');
        return true;
      }
      if (kDebugMode) debugPrint('❌ No session token');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error ensuring session: $e');
      return false;
    }
  }

  // Send OTP email via Edge Function
  static Future<bool> sendOTPEmail(String email, String code) async {
    try {
      if (kDebugMode)
        debugPrint('Sending OTP email to: $email with code: $code');

      final response = await client.functions.invoke(
        'send-otp',
        body: {
          'email': email,
          'code': code,
          'type': 'verification',
        },
      );

      if (kDebugMode) debugPrint('Email send response: $response');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending OTP email: $e');
      return false;
    }
  }

  // Register
  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    try {
      // Check if account exists
      final existing = await client
          .from('accounts')
          .select('account_id, is_verified')
          .eq('email_address', email)
          .maybeSingle();

      final code = _generateOTP();
      final expires =
          DateTime.now().add(const Duration(minutes: 10)).toIso8601String();

      if (existing != null) {
        if (existing['is_verified']) {
          return {
            'success': false,
            'message': 'Account already verified. Please log in.',
          };
        }

        // Update existing unverified account
        await client.from('accounts').update({
          'password_hash': _hashPassword(password),
          'verification_code': code,
          'verification_expires': expires,
        }).eq('email_address', email);
      } else {
        // Create new account
        await client.from('accounts').insert({
          'email_address': email,
          'password_hash': _hashPassword(password),
          'account_type': 'mother',
          'verification_code': code,
          'verification_expires': expires,
          'is_verified': false,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Send email with OTP using Edge Function
      final emailSent = await sendOTPEmail(email, code);

      if (!emailSent) {
        return {
          'success': true,
          'message':
              'Account created but email failed to send. Please use "Resend Code" on the next screen.',
          'email_failed': true,
        };
      }

      return {
        'success': true,
        'message': 'Verification code sent to your email.',
        'email_sent': true,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Registration error: $e');
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // Resend verification code
  static Future<Map<String, dynamic>> resendVerificationCode(
      String email) async {
    try {
      final code = _generateOTP();
      final expires =
          DateTime.now().add(const Duration(minutes: 10)).toIso8601String();

      await client
          .from('accounts')
          .update({
            'verification_code': code,
            'verification_expires': expires,
          })
          .eq('email_address', email)
          .eq('is_verified', false);

      final emailSent = await sendOTPEmail(email, code);

      return {
        'success': emailSent,
        'message': emailSent
            ? 'New verification code sent to your email.'
            : 'Failed to send email. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to resend code: ${e.toString()}',
      };
    }
  }

  // Verify OTP code
  static Future<bool> verifyCode(String email, String code) async {
    try {
      final account = await client
          .from('accounts')
          .select('verification_code, verification_expires')
          .eq('email_address', email)
          .maybeSingle();

      if (account == null) return false;

      if (account['verification_code'] != code) return false;

      final expires = DateTime.parse(account['verification_expires']);
      if (expires.isBefore(DateTime.now())) return false;

      await client.from('accounts').update({
        'is_verified': true,
        'verification_code': null,
        'verification_expires': null,
      }).eq('email_address', email);

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Verification error: $e');
      return false;
    }
  }

  // Reset Password - Send reset email
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      if (kDebugMode) {
        debugPrint('📧 Sending password reset email to: $email');
      }

      final account = await client
          .from('accounts')
          .select('account_id')
          .eq('email_address', email)
          .maybeSingle();

      if (account == null) {
        return {
          'success': false,
          'message': 'No account found with this email address.',
        };
      }

      final code = _generateOTP();
      final expires =
          DateTime.now().add(const Duration(minutes: 10)).toIso8601String();

      await client.from('accounts').update({
        'reset_code': code,
        'reset_expires': expires,
      }).eq('email_address', email);

      final emailSent = await sendOTPEmail(email, code);

      return {
        'success': emailSent,
        'message': emailSent
            ? 'Password reset code sent to your email.'
            : 'Failed to send email. Please try again.',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending reset email: $e');
      }
      return {
        'success': false,
        'message': 'Failed to send reset email. Please try again.',
      };
    }
  }

  // Complete mother profile
  static Future<Map<String, dynamic>> completeMotherProfile(
    int accountId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      await client.from('accounts').update({
        'first_name': profileData['first_name'],
        'middle_name': profileData['middle_name'],
        'last_name': profileData['last_name'],
        'extension_name': profileData['extension_name'],
        'phone_number': profileData['contact_number'],
      }).eq('account_id', accountId);

      final existingMother = await client
          .from('mothers')
          .select('mother_id')
          .eq('account_id', accountId)
          .maybeSingle();

      String? birthDateStr;
      if (profileData['birth_date'] != null &&
          profileData['birth_date'].isNotEmpty) {
        try {
          if (profileData['birth_date'].contains('/')) {
            final parts = profileData['birth_date'].split('/');
            if (parts.length == 3) {
              final month = int.parse(parts[0]);
              final day = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              birthDateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            }
          } else {
            birthDateStr = profileData['birth_date'];
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Date parsing error: $e');
          birthDateStr = profileData['birth_date'];
        }
      }

      if (existingMother == null) {
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
        await client.from('mothers').update({
          'birthdate': birthDateStr,
          'house_number': profileData['house_no'],
          'street': profileData['street'],
          'barangay': profileData['barangay'],
          'city_municipality': profileData['city'],
          'province': profileData['province'],
        }).eq('account_id', accountId);
      }

      return {'success': true, 'message': 'Profile completed successfully'};
    } catch (e) {
      if (kDebugMode) debugPrint('Profile completion error: $e');
      return {
        'success': false,
        'message': 'Failed to complete profile: ${e.toString()}'
      };
    }
  }

  // Get greeting data
  static Future<Map<String, dynamic>> getGreeting(
      int accountId, String role) async {
    try {
      final accountResponse = await client.from('accounts').select('''
            first_name,
            middle_name,
            last_name,
            extension_name
          ''').eq('account_id', accountId).maybeSingle();

      if (role == 'mother') {
        final motherResponse = await client.from('mothers').select('''
              assigned_bhc_id,
              bhc!inner (
                bhc_name
              )
            ''').eq('account_id', accountId).maybeSingle();

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
        final midwifeResponse = await client.from('midwives').select('''
              assigned_bhc_id,
              bhc!inner (
                bhc_name
              )
            ''').eq('account_id', accountId).maybeSingle();

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
      if (kDebugMode) debugPrint('Greeting error: $e');
      return {'success': false, 'message': 'Failed to fetch greeting'};
    }
  }

  // Midwife creates a new mother account
  static Future<Map<String, dynamic>> createMotherByMidwife({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final existing = await client
          .from('accounts')
          .select('account_id')
          .eq('email_address', email)
          .maybeSingle();

      if (existing != null) {
        return {
          'success': false,
          'message': 'An account with this email already exists.',
        };
      }

      final inserted = await client
          .from('accounts')
          .insert({
            'email_address': email,
            'password_hash': _hashPassword(password),
            'account_type': 'mother',
            'first_name': firstName,
            'last_name': lastName,
            'phone_number': phoneNumber,
            'is_verified': true,
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('account_id')
          .single();

      final accountId = inserted['account_id'] as int;

      await client.from('mothers').insert({
        'account_id': accountId,
        'status': 'active',
      });

      return {
        'success': true,
        'message': 'Mother account created successfully.',
        'account_id': accountId,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('createMotherByMidwife error: $e');
      return {
        'success': false,
        'message': 'Failed to create account: ${e.toString()}',
      };
    }
  }

  // Get midwife context
  static Future<Map<String, dynamic>> getMidwifeContext(int accountId) async {
    try {
      if (kDebugMode) {
        debugPrint('=== GET MIDWIFE CONTEXT ===');
        debugPrint('Account ID: $accountId');
      }

      final result = await client
          .from('midwives')
          .select('midwife_id, assigned_bhc_id, bhc!inner(bhc_name)')
          .eq('account_id', accountId)
          .single();

      final bhc = result['bhc'] as Map?;
      return {
        'success': true,
        'midwife_id': result['midwife_id'] as int,
        'assigned_bhc_id': result['assigned_bhc_id'] as int,
        'bhc_name': (bhc?['bhc_name'] as String?) ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check email availability
  static Future<bool> isEmailAvailable(String email) async {
    try {
      final result = await client
          .from('accounts')
          .select('account_id')
          .eq('email_address', email)
          .maybeSingle();
      return result == null;
    } catch (_) {
      return true;
    }
  }

  // Add mother full by midwife
  static Future<Map<String, dynamic>> addMotherFullByMidwife({
    required int midwifeId,
    required int assignedBhcId,
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extensionName,
    required String phone,
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
    DateTime? birthdate,
    double? heightCm,
    double? weightKg,
    String? bloodType,
    DateTime? lmp,
    DateTime? edd,
    List<Map<String, dynamic>> emergencyContacts = const [],
    List<Map<String, dynamic>> medicalConditions = const [],
    List<Map<String, dynamic>> allergies = const [],
    List<Map<String, dynamic>> pastPregnancies = const [],
  }) async {
    try {
      final emailFree = await isEmailAvailable(email);
      if (!emailFree) {
        return {'success': false, 'message': 'This email is already in use.'};
      }

      final accountRow = await client
          .from('accounts')
          .insert({
            'email_address': email,
            'password_hash': _hashPassword(password),
            'account_type': 'mother',
            'first_name': firstName,
            'middle_name': middleName,
            'last_name': lastName,
            'extension_name': extensionName,
            'phone_number': phone,
            'is_verified': true,
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('account_id')
          .single();

      final accountId = accountRow['account_id'] as int;

      final motherRow = await client
          .from('mothers')
          .insert({
            'account_id': accountId,
            'assigned_bhc_id': assignedBhcId,
            'birthdate': birthdate?.toIso8601String().split('T')[0],
            'house_number': houseNumber,
            'street': street,
            'barangay': barangay,
            'city_municipality': city,
            'province': province,
            'height': heightCm,
            'weight': weightKg,
            'blood_type': bloodType,
            'status': 'active',
          })
          .select('mother_id')
          .single();

      final motherId = motherRow['mother_id'] as int;

      if (emergencyContacts.isNotEmpty) {
        await client.from('emergency_contacts').insert(
              emergencyContacts
                  .map((ec) => {'mother_id': motherId, ...ec})
                  .toList(),
            );
      }

      if (medicalConditions.isNotEmpty) {
        await client.from('medical_conditions').insert(
              medicalConditions
                  .map((mc) => {'mother_id': motherId, ...mc})
                  .toList(),
            );
      }

      if (allergies.isNotEmpty) {
        await client.from('allergies').insert(
              allergies.map((al) => {'mother_id': motherId, ...al}).toList(),
            );
      }

      int? pregnancyId;
      if (lmp != null && edd != null) {
        final pregRow = await client
            .from('pregnancies')
            .insert({
              'mother_id': motherId,
              'last_menstrual_period': lmp.toIso8601String().split('T')[0],
              'expected_date_of_delivery': edd.toIso8601String().split('T')[0],
              'status': 'ongoing',
            })
            .select('pregnancy_id')
            .single();
        pregnancyId = pregRow['pregnancy_id'] as int;
      }

      for (final pp in pastPregnancies) {
        final pastPregRow = await client
            .from('pregnancies')
            .insert({
              'mother_id': motherId,
              'status': 'ended',
              'outcome': pp['outcome'],
              'outcome_date': pp['outcome_date'],
              'is_outcome_date_estimated':
                  pp['is_outcome_date_estimated'] ?? false,
              'gestational_age_at_end': pp['gestational_age_at_end'],
            })
            .select('pregnancy_id')
            .single();

        final pastPregId = pastPregRow['pregnancy_id'] as int;

        if (pp['place_of_delivery'] != null || pp['delivery_method'] != null) {
          await client.from('deliveries').insert({
            'pregnancy_id': pastPregId,
            'delivery_date': pp['outcome_date'],
            'is_delivery_date_estimated':
                pp['is_outcome_date_estimated'] ?? false,
            'place_of_delivery': pp['place_of_delivery'],
            'delivery_method': pp['delivery_method'],
          });
        }
      }

      return {
        'success': true,
        'mother_id': motherId,
        'pregnancy_id': pregnancyId,
        'account_id': accountId,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('addMotherFullByMidwife error: $e');
      return {
        'success': false,
        'message': 'Failed to add mother: ${e.toString()}',
      };
    }
  }
}