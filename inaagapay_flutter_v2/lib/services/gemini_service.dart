// lib/services/gemini_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gemini_response.dart';
import '../models/ocr_result.dart';

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
        'https://generativelanguage.googleapis.com/v1/models?key=$apiKey');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List? ?? [];

        _availableModels = models
            .map<String>(
                (model) => model['name'].toString().replaceFirst('models/', ''))
            .where(
                (name) => name.contains('flash') || name.contains('pro-vision'))
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

  // ─── OCR: Extract mother registration data from image ───────────────────────
  /// Sends [imageFile] to Gemini and returns a structured [OcrResult] with
  /// all fields that could be read from the document / handwritten form.
  Future<OcrResult> extractMotherRegistrationData(XFile imageFile) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not found in .env');
    }

    if (_availableModels.isEmpty) {
      await checkAvailableModels();
    }

    const prompt = r'''
You are an OCR assistant that reads maternal health / patient registration forms (printed or handwritten).
Extract every visible field and return ONLY a single JSON object — no markdown, no prose, no code fence.

Output schema (all fields optional, omit if not found):
{
  "first_name": "string",
  "middle_name": "string",
  "last_name": "string",
  "extension_name": "string",
  "phone": "string",
  "email": "string",
  "house_number": "string",
  "street": "string",
  "barangay": "string",
  "city": "string",
  "province": "string",
  "birthdate": "YYYY-MM-DD",
  "height_cm": number,
  "weight_kg": number,
  "blood_type": "A+|A-|B+|B-|AB+|AB-|O+|O-|Unknown",
  "lmp_date": "YYYY-MM-DD",
  "edd_date": "YYYY-MM-DD",
  "emergency_contacts": [
    {
      "first_name": "string",
      "middle_name": "string",
      "last_name": "string",
      "extension_name": "string",
      "phone_number": "string",
      "affiliation": "string"
    }
  ],
  "medical_conditions": [
    {
      "condition_name": "string",
      "diagnosis_date": "YYYY-MM-DD",
      "status": "active|resolved",
      "remarks": "string"
    }
  ],
  "allergies": [
    {
      "allergen": "string",
      "diagnosis_date": "YYYY-MM-DD",
      "status": "active|resolved",
      "treatment": "string",
      "remarks": "string"
    }
  ],
  "past_pregnancies": [
    {
      "outcome": "live_birth|stillbirth|miscarriage|abortion|ectopic",
      "outcome_date": "YYYY-MM-DD",
      "is_estimated": false,
      "gestational_age_at_end": number,
      "place_of_delivery": "string",
      "delivery_method": "Normal Spontaneous Vaginal Delivery|Cesarean Section|Assisted Vaginal Delivery|Other"
    }
  ]
}
Rules:
- Dates must be ISO format (YYYY-MM-DD); infer year if only month/day visible.
- For phone numbers keep Filipino format (09XXXXXXXXX or +639XXXXXXXXX).
- outcome must be exactly one of the listed enum values in lowercase_with_underscores.
- If a field is not visible or illegible, omit it entirely.
- Return ONLY the JSON — no extra text.
''';

    // Build request parts
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    String mimeType = 'image/jpeg';
    final ext = imageFile.path.split('.').last.toLowerCase();
    if (ext == 'png')
      mimeType = 'image/png';
    else if (ext == 'webp') mimeType = 'image/webp';

    final parts = [
      {"text": prompt},
      {
        "inline_data": {"mime_type": mimeType, "data": base64Image}
      },
    ];

    final requestBody = {
      "contents": [
        {"parts": parts}
      ],
      "generationConfig": {
        "temperature": 0.1,
        "topK": 32,
        "topP": 1,
        "maxOutputTokens": 4096,
        "responseMimeType": "application/json",
      }
    };

    Exception? lastError;
    for (final model in _modelsToTry) {
      for (final apiVersion in ['v1beta', 'v1']) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey',
          );
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 60));

          if (response.statusCode != 200) {
            lastError = Exception('API Error (${response.statusCode})');
            continue;
          }

          final data = jsonDecode(response.body);
          String raw = '';
          try {
            raw =
                data['candidates'][0]['content']['parts'][0]['text'] as String;
          } catch (_) {
            lastError = Exception('Unexpected Gemini response shape');
            continue;
          }

          // Strip any accidental markdown fences
          raw = raw.trim();
          if (raw.startsWith('```')) {
            raw = raw
                .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
                .replaceAll(RegExp(r'\n?```$'), '')
                .trim();
          }

          final json = jsonDecode(raw) as Map<String, dynamic>;
          _workingModel = model;
          _workingApiVersion = apiVersion;
          return OcrResult.fromJson(json);
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
    }

    throw lastError ??
        Exception('OCR failed. Please check your API key and try again.');
  }

  Future<GeminiResponse> _makeMultiImageRequest(
    List<XFile> imageFiles,
    String apiKey,
    String customPrompt,
  ) async {
    if (_workingModel != null && _workingApiVersion != null) {
      return _sendMultiImageRequest(imageFiles, apiKey, _workingModel!,
          _workingApiVersion!, customPrompt);
    }

    Exception? lastError;

    for (String model in _modelsToTry) {
      for (String apiVersion in ['v1', 'v1beta']) {
        try {
          final result = await _sendMultiImageRequest(
              imageFiles, apiKey, model, apiVersion, customPrompt);
          _workingModel = model;
          _workingApiVersion = apiVersion;
          return result;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
    }

    throw lastError ??
        Exception('All models failed. Please check your API key permissions.');
  }

  Future<GeminiResponse> _sendMultiImageRequest(
      List<XFile> imageFiles,
      String apiKey,
      String model,
      String apiVersion,
      String customPrompt) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey');

    List<Map<String, dynamic>> parts = [
      {"text": customPrompt}
    ];

    for (int i = 0; i < imageFiles.length; i++) {
      final bytes = await imageFiles[i].readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';
      final extension = imageFiles[i].path.split('.').last.toLowerCase();
      if (extension == 'png')
        mimeType = 'image/png';
      else if (extension == 'jpg' || extension == 'jpeg')
        mimeType = 'image/jpeg';
      else if (extension == 'webp') mimeType = 'image/webp';

      parts.add({
        "inline_data": {"mime_type": mimeType, "data": base64Image}
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

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GeminiResponse.fromJson(data);
    } else {
      throw Exception('API Error (${response.statusCode})');
    }
  }
}
