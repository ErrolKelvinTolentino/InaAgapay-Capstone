import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://inaagapay.alwaysdata.net/api/auth/';

class ForgotPasswordService {
  static Future<bool> sendCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}forgot_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      // 👇 DEBUG SAFETY CHECK
      if (!response.body.trim().startsWith('{')) {
        print('INVALID RESPONSE (NOT JSON)');
        print(response.body);
        return false;
      }

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('SEND CODE ERROR: $e');
      return false;
    }
  }

  static Future<bool> verifyCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}forgot_password_verify.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (!response.body.trim().startsWith('{')) {
        print('INVALID RESPONSE (NOT JSON)');
        print(response.body);
        return false;
      }

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('VERIFY CODE ERROR: $e');
      return false;
    }
  }

  static Future<bool> resetPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}forgot_password_reset.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (!response.body.trim().startsWith('{')) {
        print('INVALID RESPONSE (NOT JSON)');
        print(response.body);
        return false;
      }

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('RESET PASSWORD ERROR: $e');
      return false;
    }
  }
}
