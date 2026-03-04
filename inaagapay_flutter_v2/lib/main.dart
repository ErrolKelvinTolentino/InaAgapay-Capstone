import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://buvseyqcdacctlupznya.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
  );

  runApp(const InaagapayApp());
}

class InaagapayApp extends StatelessWidget {
  const InaagapayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List bhcList = [];

  @override
  void initState() {
    super.initState();
    fetchBHC();
  }

  Future<void> fetchBHC() async {
    final data = await SupabaseService.client
        .from('bhc')
        .select();

    setState(() {
      bhcList = data;
    });

    print(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inaagapay"),
      ),
      body: bhcList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: bhcList.length,
              itemBuilder: (context, index) {
                final bhc = bhcList[index];

                return ListTile(
                  title: Text(bhc['bhc_name'] ?? 'No Name'),
                );
              },
            ),
    );
  }
}