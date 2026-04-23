// lib/services/gemini_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
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
  Future<GeminiResponse> analyzeUltrasoundImages(
    List<XFile> imageFiles, {
    String? clinicalContext,
  }) async {
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

    final normalizedContext = (clinicalContext ?? '').trim();

    final String prompt = """
  You are an AI assistant that helps summarize ultrasound findings for maternal and child health support.

  IMPORTANT DISCLAIMER:
  - You are not making a diagnosis.
  - Use only what is visible in images and provided context.
  - If evidence is unclear or missing, say so explicitly.

  I am providing ${imageFiles.length} ultrasound image(s) of the same pregnancy.
  Clinical context: ${normalizedContext.isEmpty ? 'Not provided' : normalizedContext}

  First do a relevance check.
  If images are unrelated, unreadable, or not suitable for interpretation, set relevance_check to UNRELATED and explain briefly.

  Return ONLY valid JSON in this exact schema:
  {
    "relevance_check": "RELATED|UNRELATED",
    "relevance_reason": "string",
    "overall_health_status": "HEALTHY_NORMAL|REQUIRES_MONITORING|CONSULT_SPECIALIST|INSUFFICIENT_DATA",
    "measurements": [
     {
      "name": "string",
      "value": "string",
      "status": "NORMAL|BORDERLINE|CONCERNING|UNKNOWN",
      "evidence": "string"
     }
    ],
    "gestational_age_assessment": "string",
    "anatomical_findings": [
     {
      "structure": "string",
      "status": "NORMAL|UNCERTAIN|CONCERNING",
      "note": "string"
     }
    ],
    "key_observations": ["string"],
    "recommendations": ["string"],
    "confidence_score": 0.0
  }

  Rules:
  - Do not fabricate measurements.
  - Keep confidence_score between 0 and 1.
  - If uncertain, use INSUFFICIENT_DATA and include what is missing.
  """;

    return _makeMultiImageRequest(imageFiles, apiKey, prompt);
  }

  // Lab Test Analysis
  Future<GeminiResponse> analyzeLabTestImages(
    List<XFile> imageFiles, {
    String? selectedLabType,
    String? notes,
  }) async {
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

    final normalizedType = (selectedLabType ?? '').trim();
    final normalizedNotes = (notes ?? '').trim();

    final String prompt = """
You are an AI assistant that helps summarize laboratory test records for maternal and child health support.

IMPORTANT DISCLAIMER:
- You are not making a diagnosis.
- Extract and organize values for healthcare worker review.
- Use only visible evidence and provided context.

I am providing ${imageFiles.length} laboratory image(s).
Selected lab test type: ${normalizedType.isEmpty ? 'Not specified' : normalizedType}
Notes entered by user: ${normalizedNotes.isEmpty ? 'None provided' : normalizedNotes}

Perform strict relevance checking.
If unrelated or unreadable, set relevance_check to UNRELATED and do not fabricate values.

Return ONLY valid JSON in this exact schema:
{
  "relevance_check": "RELATED|UNRELATED",
  "relevance_reason": "string",
  "lab_results": [
    {
      "test_name": "string",
      "value": "string",
      "unit": "string",
      "reference_range": "string",
      "status": "NORMAL|BORDERLINE|ABNORMAL|UNKNOWN",
      "evidence": "string"
    }
  ],
  "abnormal_findings": ["string"],
  "normal_ranges": ["string"],
  "overall_assessment": "string",
  "recommendations": ["string"],
  "confidence_score": 0.0
}

Rules:
- Do not invent results.
- Keep confidence_score between 0 and 1.
- If image quality blocks extraction, say so in relevance_reason.
- Keep output concise and non-redundant.
- Max 5 items in abnormal_findings.
- Max 5 items in normal_ranges.
- Max 4 items in recommendations.
- Do not repeat the same finding across multiple arrays.
- Include all distinct detected laboratory results in lab_results.
- Prefer short, direct phrasing for quick midwife review.
""";

    return _makeMultiImageRequest(imageFiles, apiKey, prompt);
  }

  // Generic text analysis
  Future<String> generateTextInsight({
    required String prompt,
    double temperature = 0.2,
    int maxOutputTokens = 2048,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not found in .env');
    }

    if (_availableModels.isEmpty) {
      await checkAvailableModels();
    }

    Exception? lastError;

    if (_workingModel != null && _workingApiVersion != null) {
      try {
        return await _sendTextRequest(
          prompt: prompt,
          apiKey: apiKey,
          model: _workingModel!,
          apiVersion: _workingApiVersion!,
          temperature: temperature,
          maxOutputTokens: maxOutputTokens,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    for (final model in _modelsToTry) {
      for (final apiVersion in ['v1', 'v1beta']) {
        try {
          final text = await _sendTextRequest(
            prompt: prompt,
            apiKey: apiKey,
            model: model,
            apiVersion: apiVersion,
            temperature: temperature,
            maxOutputTokens: maxOutputTokens,
          );
          _workingModel = model;
          _workingApiVersion = apiVersion;
          return text;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
    }

    throw lastError ??
        Exception('All Gemini text models failed. Please check API access.');
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
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'webp') mimeType = 'image/webp';

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
      final preparedImage = await _prepareImageForGemini(imageFiles[i]);
      final base64Image = base64Encode(preparedImage.bytes);

      parts.add({
        "inline_data": {
          "mime_type": preparedImage.mimeType,
          "data": base64Image
        }
      });
    }

    final requestBody = {
      "contents": [
        {"parts": parts}
      ],
      "generationConfig": {
        "temperature": 0.1,
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

  Future<_PreparedGeminiImage> _prepareImageForGemini(XFile imageFile) async {
    final rawBytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();

    if (extension == 'jpg' || extension == 'jpeg') {
      return _PreparedGeminiImage(
        bytes: Uint8List.fromList(rawBytes),
        mimeType: 'image/jpeg',
      );
    }

    if (extension == 'png') {
      return _PreparedGeminiImage(
        bytes: Uint8List.fromList(rawBytes),
        mimeType: 'image/png',
      );
    }

    if (extension == 'webp') {
      return _PreparedGeminiImage(
        bytes: Uint8List.fromList(rawBytes),
        mimeType: 'image/webp',
      );
    }

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception(
          'Unsupported image format. Please upload JPG, PNG, WEBP, or a convertible image.');
    }

    final converted = Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
    return _PreparedGeminiImage(bytes: converted, mimeType: 'image/jpeg');
  }

  Future<String> _sendTextRequest({
    required String prompt,
    required String apiKey,
    required String model,
    required String apiVersion,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey',
    );

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': maxOutputTokens,
      }
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('API Error (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty Gemini response');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Unexpected Gemini response shape');
    }
    final text = parts.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned empty text');
    }

    return text.trim();
  }
}

class _PreparedGeminiImage {
  const _PreparedGeminiImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
