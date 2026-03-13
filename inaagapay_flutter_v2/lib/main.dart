// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Services
import 'services/auth_storage.dart';

// Auth Screens
import 'screens/auth/login.dart';
import 'screens/auth/mother_registration.dart';
import 'screens/auth/account_verification_registration.dart';
import 'screens/auth/forgot_password.dart';
import 'screens/auth/forgot_password_verification.dart';
import 'screens/auth/change_forgot_password.dart';

// Mother Screens
import 'screens/mother/mother_dashboard_shell.dart';
import 'screens/mother/complete_profile.dart';
import 'screens/mother/welcome_screen.dart';
import 'screens/mother/due_date_setter.dart';
import 'screens/mother/congrats_page.dart';
import 'screens/mother/mother_profile_page.dart';
import 'screens/mother/mother_journal_screen.dart';
import 'screens/mother/mother_children_screen.dart';
import 'screens/mother/records_screen.dart';

// Midwife Screens
import 'screens/midwife/midwife_shell.dart';
import 'screens/midwife/midwife_mothers_screen.dart';
import 'screens/midwife/midwife_children_screen.dart';
import 'screens/midwife/midwife_schedules_screen.dart';
import 'screens/midwife/midwife_add_mother_screen.dart';
import 'screens/midwife/ultrasound_analyzer_screen.dart';
import 'screens/midwife/lab_test_analyzer_screen.dart';

// Admin Screens
import 'screens/admin/admin_dashboard.dart';

// Models
import 'models/due_date_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) print('✅ .env file loaded successfully');
  } catch (e) {
    if (kDebugMode) print('⚠️ Could not load .env: $e');
  }

  try {
    await Supabase.initialize(
      url: 'https://buvseyqcdacctlupznya.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
    );
    if (kDebugMode) print('✅ Supabase initialized successfully');
  } catch (e) {
    if (kDebugMode) print('❌ Supabase init error: $e');
  }

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    if (!isLoggedIn) return const LoginScreen();

    final role = await AuthStorage.getUserRole();
    final profileComplete = await AuthStorage.isProfileComplete();

    if (kDebugMode) {
      print('=== START SCREEN DETERMINATION ===');
      print('Is Logged In: $isLoggedIn');
      print('Role: $role');
      print('Profile Complete: $profileComplete');
    }

    if (role == 'mother' && !profileComplete) {
      return const CompleteProfileScreen();
    }

    switch (role) {
      case 'mother':
        return const MotherDashboardShell();
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
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 100,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite,
                        size: 80,
                        color: Color(0xFFFF68A5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF68A5)),
                    ),
                  ],
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
            // ===== AUTHENTICATION ROUTES =====
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const MotherRegistrationScreen(),
            '/verify-registration': (context) =>
                const AccountVerificationRegistration(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/forgot-password-verify': (context) =>
                const ForgotPasswordVerificationScreen(),
            '/change-forgot-password': (context) =>
                const ChangeForgotPasswordScreen(),

            // ===== MOTHER ONBOARDING ROUTES =====
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/due-date-setter': (context) {
              final mode = ModalRoute.of(context)!.settings.arguments as DueDateMode? ?? DueDateMode.pregnant;
              return DueDateSetter(mode: mode);
            },

            // ===== MOTHER DASHBOARD ROUTES =====
            '/mother-dashboard': (context) => const MotherDashboardShell(),
            '/mother-profile': (context) {
              final args = ModalRoute.of(context)!.settings.arguments;
              if (args is int) {
                return MotherProfilePage(motherId: args);
              }
              return const MotherProfilePage(motherId: 0);
            },
            '/mother-journal': (context) => const MotherJournalScreen(),
            '/mother-children': (context) => const MotherChildrenScreen(),
            '/mother-records': (context) => const RecordsScreen(),

            // ===== MIDWIFE ROUTES =====
            '/midwife-dashboard': (context) => const MidwifeShell(),
            '/midwife-mothers': (context) => const MidwifeMothersScreen(),
            '/midwife-children': (context) => const MidwifeChildrenScreen(),
            '/midwife-schedules': (context) => const MidwifeSchedulesScreen(),
            '/midwife-add-mother': (context) => const MidwifeAddMotherScreen(),
            '/ultrasound-analyzer': (context) => const UltrasoundAnalyzerScreen(),
            '/lab-test-analyzer': (context) => const LabTestAnalyzerScreen(),

            // ===== ADMIN ROUTES =====
            '/admin-dashboard': (context) => const AdminDashboard(),

            // ===== COMMON ROUTES =====
            '/profile': (context) => const Placeholder(), // TODO: Implement profile
            '/settings': (context) => const Placeholder(), // TODO: Implement settings
            '/help': (context) => const Placeholder(), // TODO: Implement help
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/congrats') {
              final mode = settings.arguments as DueDateMode? ?? DueDateMode.pregnant;
              return MaterialPageRoute(
                builder: (_) => CongratsPage(mode: mode),
              );
            }
            return null;
          },
        );
      },
    );
  }
}