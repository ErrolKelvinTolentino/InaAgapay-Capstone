import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

// 🔐 AUTH STORAGE
import 'services/auth_storage.dart';

// ================= AUTH & COMMON SCREENS =================
import 'screens/login.dart';
import 'screens/mother_registration.dart';
import 'screens/account_verification_registration.dart';
import 'screens/forgot_password.dart';
import 'screens/forgot_password_verification.dart';
import 'screens/change_forgot_password.dart';
import 'screens/complete_profile.dart';
import 'screens/welcome_screen.dart';
import 'screens/congrats_page.dart';
import 'screens/due_date_setter.dart'; // gives access to DueDateMode
import 'screens/mother_children_page.dart';
import 'screens/mother_child_stack.dart';
import 'screens/mother_prenatal_stack.dart';
import 'screens/mother_ultrasound_stack.dart';
import 'screens/mother_lab_stack.dart';
import 'screens/pregnancy_details.dart';
import 'screens/mother_records.dart';
import 'screens/mother_more_info_page.dart';


// 📝 JOURNAL
import 'screens/journal_list_page.dart';

// 📘 MORE INFO (NEW)
import 'screens/mother_more_info_page.dart';

// ================= DASHBOARDS / SHELLS ===================
import 'screens/mother_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/midwife_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final isLoggedIn = await AuthStorage.isLoggedIn();

    if (!isLoggedIn) {
      return const LoginScreen();
    }

    // ⚠️ TEMP DEFAULT (role-based routing later)
    return const MidwifeShell();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _determineStartScreen(),
      builder: (context, snapshot) {
        // ⏳ Loading while checking token
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,

          // ✅ guarantee a widget
          home: snapshot.data ?? const LoginScreen(),

          routes: {
            // ================= AUTH =================
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const MotherRegistrationScreen(),
            '/verify-registration': (context) =>
                const AccountVerificationRegistration(),

            // ============== PASSWORD RESET ==========
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/forgot-password-verify': (context) =>
                const ForgotPasswordVerificationScreen(),
            '/change-forgot-password': (context) =>
                const ChangeForgotPasswordScreen(),

            // ============== ONBOARDING ==============
            '/complete-profile': (context) => const CompleteProfileScreen(),
            '/welcome': (context) => const WelcomeScreen(),

            // ============== MOTHER FEATURES =========
'/mother-dashboard': (context) => const MotherDashboard(),
'/mother-journal': (context) => JournalListPage(),
'/mother-more-info': (context) => MotherMoreInfoPage(),
'/mother-children': (context) => MotherChildrenPage(),
'/mother-records': (context) => MotherRecordsPage(),
'/mother-prenatal-stack': (context) => MotherPrenatalStack(),
'/mother-ultrasound-stack': (context) => MotherUltrasoundStack(),
'/mother-lab-stack': (context) => MotherLabStack(),
'/mother-pregnancy': (context) => PregnancyDetailsPage(),
'/mother-more-info': (context) => MotherMoreInfoPage(),



            // ============== DASHBOARDS ===============
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
