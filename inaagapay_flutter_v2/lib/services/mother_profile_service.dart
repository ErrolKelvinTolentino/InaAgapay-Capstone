import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class MotherProfileService {
  static SupabaseClient get client => Supabase.instance.client;

  // Fetch complete mother profile with all related data
  static Future<Map<String, dynamic>> fetchMotherProfile(int motherId) async {
    try {
      if (kDebugMode) {
        print('=== FETCHING MOTHER PROFILE ===');
        print('Mother ID: $motherId');
      }

      // Get account ID from mother record
      final motherResponse = await client
          .from('mothers')
          .select('''
            *,
            account:account_id (
              account_id,
              email_address,
              first_name,
              middle_name,
              last_name,
              extension_name,
              phone_number,
              status,
              created_at
            )
          ''')
          .eq('mother_id', motherId)
          .single();

      if (kDebugMode) {
        print('Mother data fetched');
      }

      final account = motherResponse['account'] as Map<String, dynamic>? ?? {};

      // Get all pregnancies for this mother
      final pregnanciesResponse = await client
          .from('pregnancies')
          .select('''
            *,
            checkups:prenatal_checkups (
              prenatal_checkup_id,
              age_of_gestation,
              checkup_weight,
              blood_pressure_systolic,
              blood_pressure_diastolic,
              fetal_position,
              fetal_heart_beat,
              fetal_heart_tone,
              td_vaccine_dose,
              edema,
              remarks,
              checkup_datetime,
              next_schedule
            ),
            ultrasounds (
              ultrasound_id,
              ultrasound_date,
              ultrasound_location,
              ultrasound_image,
              remarks,
              health_worker_name,
              health_worker_institution,
              health_worker_profession,
              created_at
            ),
            lab_tests (
              lab_test_id,
              lab_test_type,
              lab_test_date,
              lab_test_location,
              lab_test_image,
              remarks,
              health_worker_name,
              health_worker_institution,
              health_worker_profession,
              created_at
            ),
            delivery:deliveries (
              delivery_id,
              delivery_date,
              place_of_delivery,
              delivery_method
            )
          ''')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);

      final List<dynamic> pregnancies = pregnanciesResponse as List<dynamic>;

      // Separate current and past pregnancies
      Map<String, dynamic>? currentPregnancy;
      final List<Map<String, dynamic>> pastPregnancies = [];
      
      for (var p in pregnancies) {
        final pregnancy = Map<String, dynamic>.from(p as Map);
        if (pregnancy['status'] == 'ongoing') {
          currentPregnancy = pregnancy;
        } else {
          pastPregnancies.add(pregnancy);
        }
      }

      // Get medical conditions
      final medicalConditionsResponse = await client
          .from('medical_conditions')
          .select('*')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);
      
      final List<dynamic> medicalConditions = medicalConditionsResponse as List<dynamic>;

      // Get allergies
      final allergiesResponse = await client
          .from('allergies')
          .select('*')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);
      
      final List<dynamic> allergies = allergiesResponse as List<dynamic>;

      // Get emergency contacts
      final emergencyContactsResponse = await client
          .from('emergency_contacts')
          .select('*')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);
      
      final List<dynamic> emergencyContacts = emergencyContactsResponse as List<dynamic>;

      // Get children
      final childrenResponse = await client
          .from('children')
          .select('''
            *,
            birth_details (*),
            child_details (*)
          ''')
          .eq('mother_id', motherId)
          .order('added_at', ascending: false);
      
      final List<dynamic> children = childrenResponse as List<dynamic>;

      // Get medications
      final medicationsResponse = await client
          .from('mother_medications')
          .select('*')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);
      
      final List<dynamic> medications = medicationsResponse as List<dynamic>;

      // Get given medications
      final givenMedicationsResponse = await client
          .from('given_medications')
          .select('*')
          .eq('mother_id', motherId)
          .order('date_given', ascending: false);
      
      final List<dynamic> givenMedications = givenMedicationsResponse as List<dynamic>;

      // Get journal entries
      final journalEntriesResponse = await client
          .from('journal_entries')
          .select('*')
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);
      
      final List<dynamic> journalEntries = journalEntriesResponse as List<dynamic>;

      // Calculate children count
      final childrenCount = children.length;

      // Build complete profile
      final profile = <String, dynamic>{
        'mother_id': motherId,
        'account_id': motherResponse['account_id'],
        'assigned_bhc_id': motherResponse['assigned_bhc_id'],
        'birthdate': motherResponse['birthdate'],
        'house_number': motherResponse['house_number'],
        'street': motherResponse['street'],
        'barangay': motherResponse['barangay'],
        'city_municipality': motherResponse['city_municipality'],
        'province': motherResponse['province'],
        'height': motherResponse['height'],
        'weight': motherResponse['weight'],
        'blood_type': motherResponse['blood_type'],
        'status': motherResponse['status'],
        
        // Account info
        'first_name': account['first_name'],
        'middle_name': account['middle_name'],
        'last_name': account['last_name'],
        'extension_name': account['extension_name'],
        'email_address': account['email_address'],
        'phone_number': account['phone_number'],
        'account_status': account['status'],
        'created_at': account['created_at'],
        
        // Full name
        'full_name': [
          account['first_name'],
          account['middle_name'],
          account['last_name'],
          account['extension_name']
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' '),
        
        // Pregnancies
        'current_pregnancy': currentPregnancy,
        'past_pregnancies': pastPregnancies,
        'pregnancies_count': pregnancies.length,
        
        // Medical info
        'medical_conditions': medicalConditions,
        'allergies': allergies,
        'emergency_contacts': emergencyContacts,
        
        // Children
        'children': children,
        'children_count': childrenCount,
        
        // Medications
        'mother_medications': medications,
        'given_medications': givenMedications,
        
        // Journal
        'journal_entries': journalEntries,
      };

      if (kDebugMode) {
        print('✅ Profile fetched successfully');
      }

      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching mother profile: $e');
      }
      throw Exception('Failed to load mother profile: $e');
    }
  }

  // Conclude pregnancy
  static Future<bool> concludePregnancy(int pregnancyId, Map<String, dynamic> data) async {
    try {
      await client
          .from('pregnancies')
          .update({
            'status': 'ended',
            'outcome': data['outcome'],
            'outcome_date': data['outcome_date'],
            'gestational_age_at_end': data['gestational_age_at_end'],
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('pregnancy_id', pregnancyId);

      // If live birth or stillbirth, add delivery record
      if (data['outcome'] == 'live_birth' || data['outcome'] == 'stillbirth') {
        await client.from('deliveries').insert({
          'pregnancy_id': pregnancyId,
          'delivery_date': data['delivery_date'],
          'place_of_delivery': data['place_of_delivery'],
          'delivery_method': data['delivery_method'],
        });
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error concluding pregnancy: $e');
      }
      return false;
    }
  }

  // Start new pregnancy
  static Future<bool> startNewPregnancy(int motherId, DateTime lmp, DateTime edd) async {
    try {
      await client.from('pregnancies').insert({
        'mother_id': motherId,
        'last_menstrual_period': lmp.toIso8601String().split('T')[0],
        'expected_date_of_delivery': edd.toIso8601String().split('T')[0],
        'status': 'ongoing',
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting pregnancy: $e');
      }
      return false;
    }
  }

  // Get AI analysis for checkup
  static Future<String?> getCheckupAIAnalysis(int checkupId) async {
    try {
      final response = await client
          .from('ai_responses')
          .select('response')
          .eq('reference_table', 'prenatal_checkups')
          .eq('reference_id', checkupId)
          .eq('response_type', 'checkup_analysis')
          .maybeSingle();
      
      return response?['response'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get AI analysis for ultrasound
  static Future<String?> getUltrasoundAIAnalysis(int ultrasoundId) async {
    try {
      final response = await client
          .from('ai_responses')
          .select('response')
          .eq('reference_table', 'ultrasounds')
          .eq('reference_id', ultrasoundId)
          .eq('response_type', 'ultrasound_analysis')
          .maybeSingle();
      
      return response?['response'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get AI analysis for lab test
  static Future<String?> getLabTestAIAnalysis(int labTestId) async {
    try {
      final response = await client
          .from('ai_responses')
          .select('response')
          .eq('reference_table', 'lab_tests')
          .eq('reference_id', labTestId)
          .eq('response_type', 'lab_analysis')
          .maybeSingle();
      
      return response?['response'] as String?;
    } catch (e) {
      return null;
    }
  }
}