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
import 'screens/auth/reset_password_screen.dart';
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

  const fallbackSupabaseUrl = 'https://buvseyqcdacctlupznya.supabase.co';
  const fallbackSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw';

  // Load environment variables with fallback for non-production environments
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) print('Could not load .env: $e');
  }

  final envSupabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final envSupabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  final supabaseUrl = (envSupabaseUrl != null && envSupabaseUrl.isNotEmpty)
      ? envSupabaseUrl
      : fallbackSupabaseUrl;
  final supabaseAnonKey =
      (envSupabaseAnonKey != null && envSupabaseAnonKey.isNotEmpty)
          ? envSupabaseAnonKey
          : fallbackSupabaseAnonKey;

  // Initialize Supabase with the determined credentials
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    if (kDebugMode) print('Supabase initialized successfully');
  } catch (e) {
    if (kDebugMode) print('Supabase init error: $e');
    // Attempt fallback initialization if primary failed
    try {
      await Supabase.initialize(
        url: fallbackSupabaseUrl,
        anonKey: fallbackSupabaseAnonKey,
      );
      if (kDebugMode) print('Supabase initialized with fallback credentials');
    } catch (fallbackError) {
      if (kDebugMode)
        print('Fallback Supabase init also failed: $fallbackError');
    }
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
      final needsPasswordChange =
          await AuthStorage.isTemporaryPasswordChanged();
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

      if (motherId != null && accountId != null) {
        try {
          final accountResponse = await SupabaseService.client
              .from('accounts')
              .select('created_by, first_name, last_name, phone_number')
              .eq('account_id', accountId)
              .maybeSingle();

          final createdBy = accountResponse?['created_by'] as String? ?? 'self';

          if (kDebugMode) {
            debugPrint('Startup check - created_by: $createdBy');
          }

          // For midwife-created or midwife-updated accounts, always skip Complete Profile
          if (createdBy == 'midwife') {
            if (!profileComplete) {
              await AuthStorage.saveProfileComplete(true);
            }

            if (kDebugMode) {
              debugPrint('Midwife-managed account - skipping Complete Profile');
            }

            if (needsPasswordChange) {
              if (kDebugMode) {
                debugPrint(
                    'Midwife account needs password change - redirecting to ChangeTemporaryPasswordScreen');
              }
              return const ChangeTemporaryPasswordScreen();
            }

            if (kDebugMode) {
              debugPrint('Midwife account ready - going to dashboard');
            }
            return const MotherDashboardShell();
          }

          // For self-registered accounts, check if profile is actually complete
          final response = await SupabaseService.client
              .from('mothers')
              .select('birthdate')
              .eq('mother_id', motherId)
              .maybeSingle();

          final hasFirstName = accountResponse?['first_name'] != null &&
              (accountResponse?['first_name']?.toString() ?? '').isNotEmpty;
          final hasLastName = accountResponse?['last_name'] != null &&
              (accountResponse?['last_name']?.toString() ?? '').isNotEmpty;
          final hasBirthdate =
              response != null && response['birthdate'] != null;
          final hasPhone = accountResponse?['phone_number'] != null &&
              (accountResponse?['phone_number']?.toString() ?? '').isNotEmpty;

          final isActuallyComplete =
              hasFirstName && hasLastName && hasBirthdate && hasPhone;

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
              debugPrint(
                  'Self-registered account incomplete - showing CompleteProfileScreen');
            }
            return const CompleteProfileScreen();
          }

          if (needsPasswordChange) {
            if (kDebugMode) {
              debugPrint(
                  'Self-registered account needs password change - redirecting to ChangeTemporaryPasswordScreen');
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
        debugPrint('Missing motherId or accountId - defaulting to dashboard');
      }
      return const MotherDashboardShell();
    }

    switch (role) {
      case 'midwife':
        return const MidwifeShell();
      case 'admin':
        return const AdminDashboard();
      default:
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
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const MotherRegistrationScreen(),
            '/verify-registration': (context) =>
                const AccountVerificationRegistration(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/forgot-password-verify': (context) =>
                const ForgotPasswordVerificationScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/change-forgot-password': (context) =>
                const ChangeForgotPasswordScreen(),
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/change-password': (context) => const ChangePasswordScreen(),
            '/change-temporary-password': (context) =>
                const ChangeTemporaryPasswordScreen(),

            // Dashboard Routes
            '/mother-dashboard': (context) => const MotherDashboardShell(),
            '/midwife-dashboard': (context) => const MidwifeShell(),
            '/admin-dashboard': (context) => const AdminDashboard(),
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
            '/midwife-mothers': (context) => const MidwifeMothersScreen(),
            '/midwife-children': (context) => const MidwifeChildrenScreen(),
            '/midwife-schedules': (context) => const MidwifeSchedulesScreen(),
            '/midwife-add-mother': (context) => const MidwifeAddMotherScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/ultrasound-analyzer') {
              final args = settings.arguments as Map<String, int>?;
              if (args != null) {
                return MaterialPageRoute(
                  builder: (_) => UltrasoundAnalyzerScreen(
                    motherId: args['motherId']!,
                    pregnancyId: args['pregnancyId']!,
                  ),
                );
              }
            }

            if (settings.name == '/lab-test-analyzer') {
              final args = settings.arguments as Map<String, int>?;
              if (args != null) {
                return MaterialPageRoute(
                  builder: (_) => LabTestAnalyzerScreen(
                    motherId: args['motherId']!,
                    pregnancyId: args['pregnancyId']!,
                  ),
                );
              }
            }

            return null;
          },
        );
      },
    );
  }
}
