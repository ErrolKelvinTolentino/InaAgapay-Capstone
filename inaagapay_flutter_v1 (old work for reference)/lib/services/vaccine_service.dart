import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vaccine_model.dart';

class VaccineService {
  static const String _baseUrl =
      'https://inaagapay.alwaysdata.net/api/midwife';

  /// Fetch vaccines (already working – unchanged)
  static Future<List<VaccineModel>> fetchVaccines() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/get_vaccines.php'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load vaccines');
    }

    final List data = jsonDecode(response.body);
    return data.map((e) => VaccineModel.fromJson(e)).toList();
  }

  /// ✅ ADD IMMUNIZATION (NEW – FIX)
  static Future<bool> addImmunization({
    required int childId,
    required int vaccineId,
    required DateTime vaccinationDate,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/add_immunization.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'child_id': childId,
        'vaccine_id': vaccineId,
        'vaccination_date':
            vaccinationDate.toIso8601String().split('T')[0],
        'remarks': remarks,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    return decoded['success'] == true;
  }
}
