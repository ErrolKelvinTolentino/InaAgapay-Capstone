import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Allow app to run even if .env is missing in debug builds.
  }

  await Supabase.initialize(
    url: 'https://buvseyqcdacctlupznya.supabase.co',
    anonKey: 'YOUR_ANON_KEY_HERE',
  );

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AiFormScreen(),
    );
  }
}
