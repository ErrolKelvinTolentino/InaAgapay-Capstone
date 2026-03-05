import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
