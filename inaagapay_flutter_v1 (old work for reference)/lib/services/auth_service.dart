import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "https://inaagapay.alwaysdata.net/api/auth/";

class AuthService {
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}login.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200 || !response.body.trim().startsWith('{')) {
        return AuthResponse(
          success: false,
          message: 'Server error. Please try again.',
        );
      }

      final data = jsonDecode(response.body);

      return AuthResponse(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Login failed',
        user: data['user'],
        token: data['token'], // ✅ ADD THIS
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }
}

class AuthResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? user;
  final String? token; // ✅ ADD THIS

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });
}
