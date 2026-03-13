import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';
import '../models/journal_model.dart';

class JournalService {
  static const String baseUrl =
      'https://inaagapay.alwaysdata.net/api/mother/journal';

  // =============================
  // 📥 FETCH JOURNALS
  // =============================
  static Future<List<JournalEntry>> fetchJournals() async {
    final motherId = await AuthStorage.getMotherId();

    final response = await http.get(
      Uri.parse('$baseUrl/index.php?mother_id=$motherId'),
    );

    final List data = json.decode(response.body);
    return data.map((e) => JournalEntry.fromJson(e)).toList();
  }

  // =============================
  // ➕ ADD JOURNAL (SAVES TO DB)
  // =============================
  static Future<bool> addJournal({
    required int motherId,
    required String title,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/index.php'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mother_id': motherId,
        'title': title,
        'content': content,
      }),
    );

    final res = json.decode(response.body);
    return res['success'] == true;
  }

  // =============================
  // ✏️ UPDATE JOURNAL
  // =============================
  static Future<bool> updateJournal({
    required int entryId,
    required String title,
    required String content,
  }) async {
    final motherId = await AuthStorage.getMotherId();

    final response = await http.put(
      Uri.parse(
        '$baseUrl/entry.php?entry_id=$entryId&mother_id=$motherId',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'content': content,
      }),
    );

    final res = json.decode(response.body);
    return res['success'] == true;
  }

  // =============================
  // 🗑 DELETE JOURNAL
  // =============================
  static Future<bool> deleteJournal(int entryId) async {
    final motherId = await AuthStorage.getMotherId();

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/entry.php?entry_id=$entryId&mother_id=$motherId',
      ),
    );

    final res = json.decode(response.body);
    return res['success'] == true;
  }
}
