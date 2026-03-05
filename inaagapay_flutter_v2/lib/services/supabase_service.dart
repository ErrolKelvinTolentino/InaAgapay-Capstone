// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart'; // Add this for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // You can add methods here for saving growth assessments to the database
  static Future<void> saveGrowthAssessment(Map<String, dynamic> data) async {
    try {
      await client.from('growth_assessments').insert(data);
    } catch (e) {
      // Use debugPrint instead of print for production code
      debugPrint('Error saving growth assessment: $e');
    }
  }
}