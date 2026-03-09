import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _apiKey = 'YOUR_API_KEY'; // Get from https://resend.com
  static const String _fromEmail = 'noreply@inaagapay.com';

  static Future<bool> sendVerificationEmail(String to, String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Inaagapay <$_fromEmail>',
          'to': [to],
          'subject': 'Verify Your Email - Inaagapay',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #DE3A53;">Inaagapay</h2>
              <p>Your verification code is:</p>
              <h1 style="font-size: 32px; color: #DE3A53; letter-spacing: 5px;">$code</h1>
              <p>This code will expire in 10 minutes.</p>
              <p>If you didn't request this, please ignore this email.</p>
              <hr style="border: 1px solid #eee;" />
              <p style="color: #666; font-size: 12px;">© 2026 Inaagapay. All rights reserved.</p>
            </div>
          ''',
        }),
      );

      if (response.statusCode == 200) {
        print('Email sent successfully');
        return true;
      } else {
        print('Failed to send email: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}