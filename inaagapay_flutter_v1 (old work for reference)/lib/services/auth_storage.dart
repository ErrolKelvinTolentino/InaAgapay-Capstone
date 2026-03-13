import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ================= TOKEN =================
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ================= MOTHER ID =================
  static Future<void> saveMotherId(int motherId) async {
    await _storage.write(key: 'mother_id', value: motherId.toString());
  }

  static Future<int?> getMotherId() async {
    final value = await _storage.read(key: 'mother_id');
    if (value == null) return null;
    return int.tryParse(value);
  }

  static Future<void> clearMotherId() async {
    await _storage.delete(key: 'mother_id');
  }

  // ================= CLEAR ALL =================
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
