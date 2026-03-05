// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'screens/menu_page.dart';
import 'screens/child_management_page.dart';
import 'screens/growth_tracker_page.dart';
import 'screens/ai_analysis_page.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Environment variables loaded successfully');
  } catch (e) {
    debugPrint("Warning: .env file not found. Using default configuration.");
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://buvseyqcdacctlupznya.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SessionService(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Inaagapay Growth Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const MenuPage(),
          '/child-management': (context) => const ChildManagementPage(),
          '/growth-tracker': (context) => const GrowthTrackerPage(),
          '/ai-analysis': (context) => const AIAnalysisPage(),
        },
      ),
    );
  }
}