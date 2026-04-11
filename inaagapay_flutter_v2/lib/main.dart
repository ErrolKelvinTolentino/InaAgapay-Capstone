// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_storage.dart';
import 'services/supabase_service.dart';
import 'screens/auth/login.dart';
import 'screens/auth/mother_registration.dart';
import 'screens/auth/account_verification_registration.dart';
import 'screens/auth/forgot_password.dart';
import 'screens/auth/forgot_password_verification.dart';
import 'screens/auth/change_forgot_password.dart';
import 'screens/mother/complete_profile.dart';
import 'screens/mother/welcome_screen.dart';
import 'screens/mother/mother_dashboard_shell.dart';
import 'screens/mother/mother_profile_page.dart';
import 'screens/mother/change_password_screen.dart';
import 'screens/mother/change_temporary_password.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/midwife/midwife_shell.dart';
import 'screens/midwife/ultrasound_analyzer_screen.dart';
import 'screens/midwife/lab_test_analyzer_screen.dart';
import 'screens/mother/records_screen.dart';
import 'screens/mother/mother_journal_screen.dart';
import 'screens/mother/mother_children_screen.dart';
import 'screens/midwife/midwife_mothers_screen.dart';
import 'screens/midwife/midwife_children_screen.dart';
import 'screens/midwife/midwife_schedules_screen.dart';
import 'screens/midwife/midwife_add_mother_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) print('Could not load .env: $e');
  }

  try {
    await Supabase.initialize(
      url: 'https://buvseyqcdacctlupznya.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
    );
  } catch (e) {
    if (kDebugMode) print('Supabase init error: $e');
  }

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    if (!isLoggedIn) return const LoginScreen();

    final role = await AuthStorage.getUserRole();
    
    if (role == 'mother') {
      final profileComplete = await AuthStorage.isProfileComplete();
      final needsPasswordChange = await AuthStorage.isTemporaryPasswordChanged();
      final motherId = await AuthStorage.getMotherId();
      final accountId = await AuthStorage.getUserId();
      
      if (kDebugMode) {
        debugPrint('=== STARTUP SCREEN DETERMINATION ===');
        debugPrint('Role: $role');
        debugPrint('profileComplete flag: $profileComplete');
        debugPrint('needsPasswordChange flag: $needsPasswordChange');
        debugPrint('motherId: $motherId');
        debugPrint('accountId: $accountId');
      }
      
      if (accountId != null) {
        try {
          // Get the created_by field and check if mother record exists
          final accountResponse = await SupabaseService.client
              .from('accounts')
              .select('created_by, first_name, last_name, phone_number')
              .eq('account_id', accountId)
              .maybeSingle();
          
          final createdBy = accountResponse?['created_by'] as String? ?? 'self';
          
          // Check if mother record exists with BHC assignment
          final motherResponse = await SupabaseService.client
              .from('mothers')
              .select('mother_id, assigned_bhc_id, birthdate')
              .eq('account_id', accountId)
              .maybeSingle();
          
          final hasValidMother = motherResponse != null;
          final hasBHC = hasValidMother && motherResponse['assigned_bhc_id'] != null;
          
          if (kDebugMode) {
            debugPrint('Startup check - created_by: $createdBy');
            debugPrint('Startup check - hasValidMother: $hasValidMother');
            debugPrint('Startup check - hasBHC: $hasBHC');
            debugPrint('Startup check - motherResponse: $motherResponse');
          }
          
          // If mother exists but no mother_id in storage, save it
          if (hasValidMother && motherId == null) {
            final newMotherId = motherResponse['mother_id'] as int;
            await AuthStorage.saveMotherId(newMotherId);
            if (kDebugMode) {
              debugPrint('Saved missing mother_id: $newMotherId');
            }
          }
          
          // For midwife-created accounts, always allow access
          if (createdBy == 'midwife') {
            if (!profileComplete) {
              await AuthStorage.saveProfileComplete(true);
            }
            
            if (needsPasswordChange) {
              if (kDebugMode) {
                debugPrint('Midwife account needs password change - redirecting to ChangeTemporaryPasswordScreen');
              }
              return const ChangeTemporaryPasswordScreen();
            }
            
            if (kDebugMode) {
              debugPrint('Midwife account ready - going to dashboard');
            }
            return const MotherDashboardShell();
          }
          
          // For self-registered accounts
          // If mother doesn't have BHC assigned, show the dashboard shell which will show the warning dialog
          if (!hasBHC) {
            if (kDebugMode) {
              debugPrint('Self-registered account without BHC - showing dashboard with warning');
            }
            return const MotherDashboardShell();
          }
          
          // Check if profile is complete (has all required fields)
          final hasFirstName = accountResponse?['first_name'] != null && 
                               (accountResponse?['first_name']?.toString() ?? '').isNotEmpty;
          final hasLastName = accountResponse?['last_name'] != null && 
                              (accountResponse?['last_name']?.toString() ?? '').isNotEmpty;
          final hasBirthdate = motherResponse != null && motherResponse['birthdate'] != null;
          final hasPhone = accountResponse?['phone_number'] != null && 
                           (accountResponse?['phone_number']?.toString() ?? '').isNotEmpty;
          
          final isActuallyComplete = hasFirstName && hasLastName && hasBirthdate && hasPhone;
          
          if (kDebugMode) {
            debugPrint('Self-registered profile completeness check:');
            debugPrint('  hasFirstName: $hasFirstName');
            debugPrint('  hasLastName: $hasLastName');
            debugPrint('  hasBirthdate: $hasBirthdate');
            debugPrint('  hasPhone: $hasPhone');
            debugPrint('  isActuallyComplete: $isActuallyComplete');
            debugPrint('  stored profileComplete flag: $profileComplete');
          }
          
          if (isActuallyComplete && !profileComplete) {
            await AuthStorage.saveProfileComplete(true);
          }
          
          if (!isActuallyComplete && !profileComplete) {
            if (kDebugMode) {
              debugPrint('Self-registered account incomplete - showing CompleteProfileScreen');
            }
            return const CompleteProfileScreen();
          }
          
          if (needsPasswordChange) {
            if (kDebugMode) {
              debugPrint('Self-registered account needs password change - redirecting to ChangeTemporaryPasswordScreen');
            }
            return const ChangeTemporaryPasswordScreen();
          }
          
          if (kDebugMode) {
            debugPrint('Self-registered account ready - going to dashboard');
          }
          return const MotherDashboardShell();
        } catch (e) {
          if (kDebugMode) {
            print('Error checking mother profile: $e');
          }
          return const MotherDashboardShell();
        }
      }
      
      if (kDebugMode) {
        debugPrint('Missing accountId - defaulting to login');
      }
      return const LoginScreen();
    }

    switch (role) {
      case 'midwife':
        if (kDebugMode) {
          debugPrint('Midwife role - going to MidwifeShell');
        }
        return const MidwifeShell();
      case 'admin':
        if (kDebugMode) {
          debugPrint('Admin role - going to AdminDashboard');
        }
        return const AdminDashboard();
      default:
        if (kDebugMode) {
          debugPrint('Unknown role - going to LoginScreen');
        }
        return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _determineStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF68A5)),
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Inaagapay',
          theme: ThemeData(
            primaryColor: const Color(0xFFFF68A5),
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFFFF68A5),
              secondary: const Color(0xFFE6398D),
            ),
            fontFamily: 'Poppins',
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: true,
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              selectedItemColor: const Color(0xFFFF68A5),
              unselectedItemColor: Colors.grey.shade600,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
            ),
          ),
          home: snapshot.data ?? const LoginScreen(),
          routes: {
            // ============================================
            // AUTHENTICATION ROUTES
            // ============================================
            
            // Login & Registration
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const MotherRegistrationScreen(),
            '/verify-registration': (context) => const AccountVerificationRegistration(),
            
            // Forgot Password Flow
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/forgot-password-verify': (context) => const ForgotPasswordVerificationScreen(),
            '/change-forgot-password': (context) => const ChangeForgotPasswordScreen(),

            // ============================================
            // MOTHER ONBOARDING ROUTES
            // ============================================
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/change-password': (context) => const ChangePasswordScreen(),
            '/change-temporary-password': (context) => const ChangeTemporaryPasswordScreen(),

            // ============================================
            // DASHBOARD ROUTES
            // ============================================
            '/mother-dashboard': (context) => const MotherDashboardShell(),
            '/midwife-dashboard': (context) => const MidwifeShell(),
            '/admin-dashboard': (context) => const AdminDashboard(),

            // ============================================
            // MOTHER FEATURE ROUTES
            // ============================================
            '/mother-profile': (context) {
              final args = ModalRoute.of(context)!.settings.arguments;
              if (args is int) {
                return MotherProfilePage(motherId: args);
              }
              return const MotherProfilePage(motherId: 0);
            },
            '/mother-records': (context) => const RecordsScreen(),
            '/mother-journal': (context) => const MotherJournalScreen(),
            '/mother-children': (context) => const MotherChildrenScreen(),

            // ============================================
            // MIDWIFE FEATURE ROUTES
            // ============================================
            '/midwife-mothers': (context) => const MidwifeMothersScreen(),
            '/midwife-children': (context) => const MidwifeChildrenScreen(),
            '/midwife-schedules': (context) => const MidwifeSchedulesScreen(),
            '/midwife-add-mother': (context) => const MidwifeAddMotherScreen(),
          },
          onGenerateRoute: (settings) {
            // Handle ultrasound analyzer route with parameters
            if (settings.name == '/ultrasound-analyzer') {
              final args = settings.arguments as Map<String, int>;
              return MaterialPageRoute(
                builder: (_) => UltrasoundAnalyzerScreen(
                  motherId: args['motherId']!,
                  pregnancyId: args['pregnancyId']!,
                ),
              );
            }
            
            // Handle lab test analyzer route with parameters
            if (settings.name == '/lab-test-analyzer') {
              final args = settings.arguments as Map<String, int>;
              return MaterialPageRoute(
                builder: (_) => LabTestAnalyzerScreen(
                  motherId: args['motherId']!,
                  pregnancyId: args['pregnancyId']!,
                ),
              );
            }
            
            // Handle child profile route
            if (settings.name == '/child-profile') {
              final childId = settings.arguments as int;
              return MaterialPageRoute(
                builder: (_) => const MidwifeChildrenScreen(),
              );
            }
            
            return null;
          },
        );
      },
    );
  }
}