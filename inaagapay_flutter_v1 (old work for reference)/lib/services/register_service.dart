import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = "https://inaagapay.alwaysdata.net/api/auth/";

class RegisterService {
  /// Register a mother or link an existing passwordless account.
  /// Returns a record with success flag, optional code, linkedExisting flag, and message.
  static Future<
    ({bool success, String? code, String message, bool linkedExisting})
  >
  registerMother({required String email, required String password}) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}register.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200 ||
          response.body.isEmpty ||
          !response.body.trim().startsWith('{')) {
        return (
          success: false,
          code: 'HTTP_ERROR',
          message: 'Unable to contact server. Please try again.',
          linkedExisting: false,
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final bool success = data['success'] == true;
      final bool linkedExisting = data['linked_existing'] == true;
      final String? code = data['code'] as String?;
      final String message =
          (data['message'] ??
                  (success
                      ? 'Verification code sent to your email.'
                      : 'Registration failed.'))
              .toString();

      return (
        success: success,
        code: code,
        message: message,
        linkedExisting: linkedExisting,
      );
    } catch (_) {
      return (
        success: false,
        code: 'NETWORK_ERROR',
        message: 'Network error. Please try again.',
        linkedExisting: false,
      );
    }
  }

  /// Verify OTP for registration/linking.
  static Future<({bool success, String message})> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}verify.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.body.isEmpty || !response.body.trim().startsWith('{')) {
        return (success: false, message: 'Unexpected server response.');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return (
        success: data['success'] == true,
        message: (data['message'] ?? 'Verification failed').toString(),
      );
    } catch (_) {
      return (success: false, message: 'Network error. Please try again.');
    }
  }
}
