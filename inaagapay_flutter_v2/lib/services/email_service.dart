// lib/services/email_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Send verification code email
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

  // Send password reset code email
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
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Send account credentials email (for new mother accounts)
  static Future<bool> sendAccountCredentials({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      if (kDebugMode) print('Missing Supabase credentials');
      return false;
    }
    
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #FF68A5, #E6398D); padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .header h1 { color: white; margin: 0; font-size: 28px; }
          .content { background: #ffffff; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
          .password-box { background: #f5f5f5; padding: 15px; border-radius: 8px; text-align: center; margin: 20px 0; }
          .password { font-size: 24px; font-weight: bold; color: #FF68A5; letter-spacing: 2px; font-family: monospace; }
          .button { background: #FF68A5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 25px; display: inline-block; margin: 20px 0; }
          .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
          .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🌸 Welcome to Inaagapay!</h1>
          </div>
          <div class="content">
            <h2>Hello $firstName $lastName!</h2>
            <p>A midwife has created an account for you on the Inaagapay Maternal and Child Health Information System.</p>
            
            <div class="password-box">
              <p style="margin-bottom: 10px;">Your temporary password is:</p>
              <div class="password">$password</div>
            </div>
            
            <div class="warning">
              <strong>⚠️ Important:</strong> This is a temporary password. 
              For security reasons, you will be required to change it upon your first login.
            </div>
            
            <p>To access your account:</p>
            <ol>
              <li>Open the Inaagapay mobile app</li>
              <li>Log in using your email and the temporary password above</li>
              <li>You will be prompted to create a new password</li>
              <li>Set a password that you will remember</li>
            </ol>
            
            <center>
              <a href="inaagapay://login" class="button">Open Inaagapay App</a>
            </center>
            
            <p>If you didn't expect this email or have any questions, please contact your barangay health center.</p>
            
            <hr>
            <p style="font-size: 14px; color: #666;">This is an automated message, please do not reply to this email.</p>
          </div>
          <div class="footer">
            <p>© 2026 Inaagapay - Supporting mothers every step of the way</p>
          </div>
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
          'subject': 'Welcome to Inaagapay - Your Account Credentials',
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
}