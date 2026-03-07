import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://buvseyqcdacctlupznya.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
  );

  runApp(const InaAgapayAdminApp());
}

class InaAgapayAdminApp extends StatelessWidget {
  const InaAgapayAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InaAgapay Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          AppTheme.materialTheme.textTheme,
        ),
      ),
      routerConfig: adminRouter,
    );
  }
}
