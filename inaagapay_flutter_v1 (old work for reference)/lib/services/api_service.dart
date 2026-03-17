import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://inaagapay.alwaysdata.net/api';

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      print('🌐 API GET: $endpoint');
      print('🔐 Token provided: ${token != null && token.isNotEmpty}');
      
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      );

      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body Length: ${response.body.length}');
      
      // Check if response body is empty
      if (response.body.isEmpty) {
        print('⚠️ Empty response body received');
        return {
          'success': false,
          'message': 'Empty response from server',
          'statusCode': response.statusCode,
        };
      }
      
      try {
        final decoded = jsonDecode(response.body);
        print('✅ JSON decoded successfully');
        return decoded;
      } catch (e) {
        print('❌ JSON decode error: $e');
        print('❌ Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Invalid JSON response: $e',
          'rawResponse': response.body,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('❌ Network/HTTP error: $e');
      print('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Network error: $e',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      print('🌐 API POST: $endpoint');
      print('📦 Request body: $body');
      
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body Length: ${response.body.length}');
      
      // Check if response body is empty
      if (response.body.isEmpty) {
        print('⚠️ Empty response body received');
        return {
          'success': false,
          'message': 'Empty response from server',
          'statusCode': response.statusCode,
        };
      }
      
      try {
        final decoded = jsonDecode(response.body);
        print('✅ JSON decoded successfully');
        return decoded;
      } catch (e) {
        print('❌ JSON decode error: $e');
        print('❌ Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Invalid JSON response: $e',
          'rawResponse': response.body,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('❌ Network/HTTP error: $e');
      print('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Network error: $e',
        'error': e.toString(),
      };
    }
  }
}