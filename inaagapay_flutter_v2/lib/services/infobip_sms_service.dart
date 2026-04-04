// lib/services/infobip_sms_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class InfobipSmsService {
  static Future<bool> sendOTP(String phoneNumber, String code) async {
    final apiKey = dotenv.env['INFOBIP_API_KEY'];
    final baseUrl = dotenv.env['INFOBIP_BASE_URL'];
    
    if (apiKey == null || baseUrl == null) {
      if (kDebugMode) print('❌ Infobip credentials missing');
      return false;
    }
    
    final formattedNumber = _formatToInternational(phoneNumber);
    final message = 'Your Inaagapay verification code is: $code. Valid for 10 minutes.';
    
    if (kDebugMode) {
      print('📱 Sending SMS to: $formattedNumber');
      print('📱 Code: $code');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sms/2/text/advanced'),
        headers: {
          'Authorization': 'App $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messages': [
            {
              'from': 'Inaagapay',
              'destinations': [{'to': formattedNumber}],
              'text': message,
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (kDebugMode) {
        print('📱 Response: ${response.statusCode} - ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['messages'][0]['status']['groupId'];
        // Group ID 1 = delivered, 2 = pending
        return status == 1 || status == 2;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Infobip error: $e');
      return false;
    }
  }
  
  static String _formatToInternational(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length == 10 && cleaned.startsWith('9')) {
      return '63$cleaned';
    } else if (cleaned.length == 11 && cleaned.startsWith('09')) {
      return '63${cleaned.substring(1)}';
    } else if (cleaned.length == 12 && cleaned.startsWith('63')) {
      return cleaned;
    }
    return cleaned;
  }
}