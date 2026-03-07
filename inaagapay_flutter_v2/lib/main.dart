import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
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
import 'screens/due_date_setter.dart';
import 'screens/mother_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/midwife_shell.dart';
import 'models/due_date_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://buvseyqcdacctlupznya.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
      // Remove authFlowType parameter as it's not in your version
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Supabase initialization error: $e');
  }

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    
    if (!isLoggedIn) {
      return const LoginScreen();
    }
    
    final role = await AuthStorage.getUserRole();
    final profileComplete = await AuthStorage.isProfileComplete();
    
    if (role == 'mother' && !profileComplete) {
      return const CompleteProfileScreen();
    }
    
    switch (role) {
      case 'mother':
        return const MotherDashboard();
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
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFDE3A53)),
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Inaagapay',
          theme: ThemeData(
            primaryColor: const Color(0xFFDE3A53),
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFFDE3A53),
              secondary: const Color(0xFF1B998B),
            ),
            fontFamily: 'Inter',
          ),
          home: snapshot.data ?? const LoginScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const MotherRegistrationScreen(),
            '/verify-registration': (context) => const AccountVerificationRegistration(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/forgot-password-verify': (context) => const ForgotPasswordVerificationScreen(),
            '/change-forgot-password': (context) => const ChangeForgotPasswordScreen(),
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/mother-dashboard': (context) => const MotherDashboard(),
            '/midwife-dashboard': (context) => const MidwifeShell(),
            '/admin-dashboard': (context) => const AdminDashboard(),
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