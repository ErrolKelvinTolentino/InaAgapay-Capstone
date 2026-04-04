// lib/services/sms_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SmsService {
  static const String _baseUrl = 'https://api.semaphore.co/api/v4';
  
  // Send OTP verification code
  static Future<bool> sendOTP(String phoneNumber, String code) async {
    final apiKey = dotenv.env['SEMAPHORE_API_KEY'];
    final senderName = dotenv.env['SEMAPHORE_SENDER_NAME'] ?? 'Inaagapay';
    
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) print('❌ SEMAPHORE_API_KEY not found in .env');
      return false;
    }
    
    final formattedNumber = _formatPhilippineNumber(phoneNumber);
    final message = 'Your Inaagapay verification code is: $code. Valid for 10 minutes.';
    
    if (kDebugMode) {
      print('📱 Sending SMS to: $formattedNumber');
      print('📱 Code: $code');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        body: {
          'apikey': apiKey,
          'number': formattedNumber,
          'message': message,
          'sendername': senderName,
        },
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(response.body);
      
      if (kDebugMode) {
        print('📱 SMS Response: $data');
      }
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        print('✅ SMS sent successfully');
        return true;
      } else {
        print('❌ SMS failed: ${data['message']}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ SMS error: $e');
      return false;
    }
  }
  
  // Format Philippine phone number to 09XXXXXXXXX
  static String _formatPhilippineNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length == 10 && cleaned.startsWith('9')) {
      return '0$cleaned';
    } else if (cleaned.length == 11 && cleaned.startsWith('09')) {
      return cleaned;
    } else if (cleaned.length == 12 && cleaned.startsWith('639')) {
      return '0${cleaned.substring(2)}';
    } else if (cleaned.length == 13 && cleaned.startsWith('+63')) {
      return '0${cleaned.substring(3)}';
    }
    
    return cleaned;
  }
  
  // Validate Philippine phone number
  static bool isValidPhilippineNumber(String phone) {
    final formatted = _formatPhilippineNumber(phone);
    return RegExp(r'^09\d{9}$').hasMatch(formatted);
  }
}