import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static Future<bool> sendVerificationCode(String email, String code) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      if (kDebugMode) print('Missing Supabase credentials');
      return false;
    }
    
    final html = '''
      <!DOCTYPE html>
      <html>
      <head><meta charset="UTF-8"></head>
      <body style="font-family: Arial, sans-serif;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #DE3A53;">Inaagapay</h2>
          <p>Your verification code is:</p>
          <div style="font-size: 32px; color: #DE3A53; letter-spacing: 5px; padding: 20px; background: #f5f5f5; text-align: center;">
            <strong>$code</strong>
          </div>
          <p>This code expires in 10 minutes.</p>
          <hr>
          <p style="font-size: 12px; color: #666;">© 2026 Inaagapay</p>
        </div>
      </body>
      </html>
    ''';
    
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'subject': 'Verify Your Email - Inaagapay',
          'htmlContent': html,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('Email sent: ${data['success']}');
        return data['success'] == true;
      }
      if (kDebugMode) print('Email failed: ${response.statusCode}');
      return false;
    } catch (e) {
      if (kDebugMode) print('Email error: $e');
      return false;
    }
  }

  static Future<bool> sendPasswordResetCode(String email, String code) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) return false;
    
    final html = '''
      <!DOCTYPE html>
      <html>
      <head><meta charset="UTF-8"></head>
      <body style="font-family: Arial, sans-serif;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #DE3A53;">Inaagapay</h2>
          <p>Your password reset code is:</p>
          <div style="font-size: 32px; color: #DE3A53; letter-spacing: 5px; padding: 20px; background: #f5f5f5; text-align: center;">
            <strong>$code</strong>
          </div>
          <p>This code expires in 10 minutes.</p>
          <hr>
          <p style="font-size: 12px; color: #666;">© 2026 Inaagapay</p>
        </div>
      </body>
      </html>
    ''';
    
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'subject': 'Reset Your Password - Inaagapay',
          'htmlContent': html,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}