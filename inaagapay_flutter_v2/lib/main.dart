import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_storage.dart';
import 'screens/login.dart';
import 'screens/mother_registration.dart';
import 'screens/account_verification_registration.dart';
import 'screens/forgot_password.dart';
import 'screens/forgot_password_verification.dart';
import 'screens/change_forgot_password.dart';
import 'screens/complete_profile.dart';
import 'screens/welcome_screen.dart';
import 'screens/congrats_page.dart';
import 'screens/mother_dashboard_shell.dart';
import 'screens/admin_dashboard.dart';
import 'screens/midwife_shell.dart';
import 'screens/ultrasound_analyzer_screen.dart';
import 'screens/lab_test_analyzer_screen.dart';
import 'screens/records_screen.dart';
import 'screens/mother_journal_screen.dart';
import 'screens/mother_children_screen.dart';
import 'screens/midwife_mothers_screen.dart';
import 'screens/midwife_children_screen.dart';
import 'screens/midwife_schedules_screen.dart';
import 'models/due_date_mode.dart';

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
    final profileComplete = await AuthStorage.isProfileComplete();

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
            '/change-forgot-password': (context) =>
                const ChangeForgotPasswordScreen(),
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/mother-dashboard': (context) => const MotherDashboardShell(),
            '/midwife-dashboard': (context) => const MidwifeShell(),
            '/admin-dashboard': (context) => const AdminDashboard(),
            '/ultrasound-analyzer': (context) =>
                const UltrasoundAnalyzerScreen(),
            '/lab-test-analyzer': (context) => const LabTestAnalyzerScreen(),
            '/mother-records': (context) => const RecordsScreen(),
            '/mother-journal': (context) => const MotherJournalScreen(),
            '/mother-children': (context) => const MotherChildrenScreen(),
            '/midwife-mothers': (context) => const MidwifeMothersScreen(),
            '/midwife-children': (context) => const MidwifeChildrenScreen(),
            '/midwife-schedules': (context) => const MidwifeSchedulesScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/congrats') {
              final mode = settings.arguments as DueDateMode;
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
