import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SmsService {
  static String get apiKey => dotenv.env['SEMAPHORE_API_KEY'] ?? '';
  static String get baseUrl => dotenv.env['SEMAPHORE_BASE_URL'] ?? 'https://api.semaphore.co/api/v4';
  static String get senderName => dotenv.env['SEMAPHORE_SENDER_NAME'] ?? 'SEMAPHORE';

  // Send general SMS message
  static Future<bool> sendSmsMessage(String phoneNumber, String message) async {
    try {
      // Validate Philippine phone number
      if (!isValidPhilippineNumber(phoneNumber)) {
        if (kDebugMode) print('Invalid Philippine phone number: $phoneNumber');
        return false;
      }

      // Format to international format
      final formattedNumber = formatPhilippineNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'apikey': apiKey,
          'number': formattedNumber,
          'message': message,
          'sendername': senderName,
        },
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('SMS API Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Check for success in response
        if (data is List && data.isNotEmpty) {
          final firstMessage = data[0];
          if (firstMessage['status'] == 'Pending' || 
              firstMessage['status'] == 'Sent' ||
              firstMessage['message_id'] != null) {
            return true;
          }
        }
        return false;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) print('Error sending SMS message: $e');
      return false;
    }
  }

  // Send OTP via SMS
  static Future<bool> sendOtp(String phoneNumber, String code) async {
    try {
      // Validate Philippine phone number
      if (!isValidPhilippineNumber(phoneNumber)) {
        if (kDebugMode) print('Invalid Philippine phone number: $phoneNumber');
        return false;
      }

      // Format to international format
      final formattedNumber = formatPhilippineNumber(phoneNumber);
      
      final message = 'Your INAAGAPAY verification code is: $code\n\nThis code expires in 10 minutes.';
      
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'apikey': apiKey,
          'number': formattedNumber,
          'message': message,
          'sendername': senderName,  // Your approved sender name
        },
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('SMS API Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Check for success in response
        if (data is List && data.isNotEmpty) {
          final firstMessage = data[0];
          if (firstMessage['status'] == 'Pending' || 
              firstMessage['status'] == 'Sent' ||
              firstMessage['message_id'] != null) {
            return true;
          }
        }
        return false;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) print('Error sending SMS: $e');
      return false;
    }
  }

  // Send OTP using the dedicated OTP endpoint (more reliable for verification codes)
  static Future<bool> sendOtpViaPriority(String phoneNumber, String code) async {
    try {
      if (!isValidPhilippineNumber(phoneNumber)) {
        return false;
      }

      final formattedNumber = formatPhilippineNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/otp'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'apikey': apiKey,
          'number': formattedNumber,
          'message': 'Your INAAGAPAY verification code is: {otp}. This code expires in 10 minutes.',
          'code': code, // Pass our own OTP code
          'sendername': senderName,
        },
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('SMS OTP API Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Error sending OTP via priority: $e');
      return false;
    }
  }

  // Check SMS credits/balance
  static Future<int?> getCreditBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/account?apikey=$apiKey'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['credit_balance'] as int?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error checking SMS balance: $e');
      return null;
    }
  }

  // Get approved sender names
  static Future<List<String>> getSenderNames() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/account/sendernames?apikey=$apiKey'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item['name'] as String).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting sender names: $e');
      return [];
    }
  }

  // Validate Philippine phone number
  static bool isValidPhilippineNumber(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check if it matches Philippine format:
    // 09XXXXXXXXX (11 digits starting with 09)
    // or +639XXXXXXXXX (13 digits)
    // or 639XXXXXXXXX (12 digits)
    final regex = RegExp(r'^(09|\+639|639)\d{9}$');
    return regex.hasMatch(cleaned);
  }

  // Format to standard Philippine international format
  static String formatPhilippineNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.startsWith('09')) {
      return '+63${cleaned.substring(1)}';
    } else if (cleaned.startsWith('639')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('63')) {
      return '+$cleaned';
    }
    
    return '+63$cleaned';
  }

  // Format for display (09XXXXXXXXX)
  static String formatDisplayNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.startsWith('63')) {
      return '0${cleaned.substring(2)}';
    } else if (cleaned.startsWith('9')) {
      return '0$cleaned';
    }
    
    return cleaned;
  }
}