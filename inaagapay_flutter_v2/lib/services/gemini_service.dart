import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gemini_response.dart';

class GeminiService {
  final List<String> _modelsToTry = [
    'gemini-1.5-flash',
    'gemini-1.5-flash-001',
    'gemini-1.5-flash-latest',
    'gemini-pro-vision',
  ];
  
  String? _workingModel;
  String? _workingApiVersion;
  List<String> _availableModels = [];
  final bool _debugMode = true;

  void _log(String message) {
    if (_debugMode && kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> checkAvailableModels() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;
    
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models?key=$apiKey'
    );
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List? ?? [];
        
        _availableModels = models
            .map<String>((model) => model['name'].toString().replaceFirst('models/', ''))
            .where((name) => name.contains('flash') || name.contains('pro-vision'))
            .toList();
        
        if (_availableModels.isNotEmpty) {
          _modelsToTry.clear();
          _modelsToTry.addAll(_availableModels);
        }
      }
    } catch (e) {
      _log('Error checking available models: $e');
    }
  }

  // Ultrasound Analysis
  Future<GeminiResponse> analyzeUltrasoundImages(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not found in .env');
    }

    if (_availableModels.isEmpty) {
      await checkAvailableModels();
    }

    final String prompt = """
You are an AI assistant that helps analyze ultrasound images for maternal and child health.

IMPORTANT DISCLAIMER: You are not making a medical diagnosis. You are providing observations based on standard fetal biometry reference ranges. Always consult with a healthcare professional.

I am providing you with ${imageFiles.length} ultrasound images of the same patient/pregnancy. 
Please analyze ALL images together and provide a COMPREHENSIVE HEALTH ASSESSMENT that includes:

1. OVERALL HEALTH STATUS: Based on all images, provide a clear assessment:
   - HEALTHY/NORMAL: All measurements within normal ranges
   - REQUIRES MONITORING: Some measurements slightly outside normal ranges
   - CONSULT SPECIALIST: Multiple measurements significantly outside normal ranges

2. DETAILED MEASUREMENTS ASSESSMENT:
   List all visible measurements (BPD, HC, AC, FL, Heart Rate, etc.) and indicate if they are NORMAL, BORDERLINE, or CONCERNING

3. GESTATIONAL AGE ASSESSMENT:
   Provide estimated gestational age based on measurements

4. ANATOMICAL ASSESSMENT:
   List visible structures and indicate if they appear normal (use ✓ for normal)

5. KEY OBSERVATIONS:
   Note any important findings

6. HEALTH SUMMARY:
   Overall assessment and recommendations

Format your response with clear sections and use ✓ for normal findings.
""";

    return _makeMultiImageRequest(imageFiles, apiKey, prompt);
  }

  // Lab Test Analysis
  Future<GeminiResponse> analyzeLabTestImages(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not found in .env');
    }

    if (_availableModels.isEmpty) {
      await checkAvailableModels();
    }

    final String prompt = """
You are an AI assistant that helps analyze laboratory test results for maternal and child health.

IMPORTANT DISCLAIMER: You are not making a medical diagnosis. You are extracting and organizing lab values for healthcare provider review. Always consult with a healthcare professional.

I am providing you with ${imageFiles.length} laboratory test result images.
Please analyze ALL images and provide a COMPREHENSIVE LABORATORY ANALYSIS that includes:

1. LABORATORY RESULTS:
   List each test and its value in this format:
   • [Test Name]: [Value] [Unit] [Status]
   Status should be:
   - NORMAL if within reference range
   - ⚠️ ABNORMAL if outside reference range

2. ABNORMAL FINDINGS:
   List all abnormal values and their potential implications

3. NORMAL RANGES:
   Provide standard reference ranges for pregnant women where applicable

4. OVERALL ASSESSMENT:
   Brief summary of key findings

5. RECOMMENDATIONS:
   General recommendations based on findings

Format your response with clear sections and use bullet points for easy reading.
""";

    return _makeMultiImageRequest(imageFiles, apiKey, prompt);
  }

  Future<GeminiResponse> _makeMultiImageRequest(
    List<XFile> imageFiles, 
    String apiKey,
    String customPrompt
  ) async {
    if (_workingModel != null && _workingApiVersion != null) {
      return _sendMultiImageRequest(imageFiles, apiKey, _workingModel!, _workingApiVersion!, customPrompt);
    }
    
    Exception? lastError;
    
    for (String model in _modelsToTry) {
      for (String apiVersion in ['v1', 'v1beta']) {
        try {
          final result = await _sendMultiImageRequest(imageFiles, apiKey, model, apiVersion, customPrompt);
          _workingModel = model;
          _workingApiVersion = apiVersion;
          return result;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
    }
    
    throw lastError ?? Exception('All models failed. Please check your API key permissions.');
  }

  Future<GeminiResponse> _sendMultiImageRequest(
    List<XFile> imageFiles, 
    String apiKey, 
    String model,
    String apiVersion,
    String customPrompt
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey'
    );

    List<Map<String, dynamic>> parts = [
      {"text": customPrompt}
    ];

    for (int i = 0; i < imageFiles.length; i++) {
      final bytes = await imageFiles[i].readAsBytes();
      final base64Image = base64Encode(bytes);
      
      String mimeType = 'image/jpeg';
      final extension = imageFiles[i].path.split('.').last.toLowerCase();
      if (extension == 'png') mimeType = 'image/png';
      else if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
      else if (extension == 'webp') mimeType = 'image/webp';

      parts.add({
        "inline_data": {
          "mime_type": mimeType,
          "data": base64Image
        }
      });
    }

    final requestBody = {
      "contents": [
        {"parts": parts}
      ],
      "generationConfig": {
        "temperature": 0.2,
        "topK": 32,
        "topP": 1,
        "maxOutputTokens": 8192,
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GeminiResponse.fromJson(data);
    } else {
      throw Exception('API Error (${response.statusCode})');
    }
  }
}