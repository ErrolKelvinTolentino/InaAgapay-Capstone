// lib/services/auth_storage.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // User Role
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  // User ID
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  static Future<int?> getUserId() async {
    final value = await _storage.read(key: 'user_id');
    return value != null ? int.tryParse(value) : null;
  }

  // Mother ID
  static Future<void> saveMotherId(int motherId) async {
    await _storage.write(key: 'mother_id', value: motherId.toString());
  }

  static Future<int?> getMotherId() async {
    final value = await _storage.read(key: 'mother_id');
    return value != null ? int.tryParse(value) : null;
  }

  static Future<void> clearMotherId() async {
    await _storage.delete(key: 'mother_id');
  }

  // Profile Complete
  static Future<void> saveProfileComplete(bool isComplete) async {
    await _storage.write(key: 'profile_complete', value: isComplete.toString());
  }

  static Future<bool> isProfileComplete() async {
    final value = await _storage.read(key: 'profile_complete');
    return value == 'true';
  }

  // Login Status
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear All
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}