// lib/services/groq_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/groq_response.dart';
import '../models/ocr_result.dart';

class GroqService {
  static const String _model = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const int _maxBase64Size = 4 * 1024 * 1024;
  static const int _maxImagesPerRequest = 5;

  String _getApiKey() {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not found in .env');
    }
    return apiKey;
  }

  Future<GroqResponse> analyzeUltrasoundImages(
    List<XFile> imageFiles, {
    String? clinicalContext,
  }) async {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }

    if (imageFiles.length > _maxImagesPerRequest) {
      throw Exception(
          'A maximum of $_maxImagesPerRequest images is allowed per request.');
    }

    final apiKey = _getApiKey();
    final normalizedContext = (clinicalContext ?? '').trim();

    final String prompt = """
You are an AI assistant that helps summarize ultrasound findings for maternal and child health support.

IMPORTANT DISCLAIMER:
- You are not making a diagnosis.
- Use only what is visible in images and provided context. Make sure to provide the complete values from the images.
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

  Future<GroqResponse> analyzeLabTestImages(
    List<XFile> imageFiles, {
    String? selectedLabType,
    String? notes,
  }) async {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }

    if (imageFiles.length > _maxImagesPerRequest) {
      throw Exception(
          'A maximum of $_maxImagesPerRequest images is allowed per request.');
    }

    final apiKey = _getApiKey();
    final normalizedType = (selectedLabType ?? '').trim();
    final normalizedNotes = (notes ?? '').trim();

    final String prompt = """
You are an AI assistant that helps summarize laboratory test records for maternal and child health support.

IMPORTANT DISCLAIMER:
- You are not making a diagnosis.
- Extract and organize values for healthcare worker review.
- Use only visible evidence and provided context. Make sure to provide the complete values from the images.

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

  Future<String> generateTextInsight({
    required String prompt,
    double temperature = 0.2,
    int maxOutputTokens = 2048,
  }) async {
    final apiKey = _getApiKey();

    return _sendChatCompletion(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      apiKey: apiKey,
      model: _model,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }

  Future<OcrResult> extractMotherRegistrationData(XFile imageFile) async {
    final apiKey = _getApiKey();
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
- Return ONLY the JSON � no extra text.
''';

    final preparedImage = await _prepareImageForGroq(imageFile);
    final base64Image = base64Encode(preparedImage.bytes);

    final raw = await _sendChatCompletion(
      messages: [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${preparedImage.mimeType};base64,$base64Image'
              }
            }
          ]
        }
      ],
      apiKey: apiKey,
      model: _model,
      temperature: 0.1,
      maxOutputTokens: 4096,
    );

    final cleaned = _stripMarkdownFences(raw);
    final json = _parseJsonResponse(cleaned);
    return OcrResult.fromJson(json);
  }

  Future<GroqResponse> _makeMultiImageRequest(
    List<XFile> imageFiles,
    String apiKey,
    String customPrompt,
  ) async {
    return _sendMultiImageRequest(imageFiles, apiKey, customPrompt);
  }

  Future<GroqResponse> _sendMultiImageRequest(
    List<XFile> imageFiles,
    String apiKey,
    String customPrompt,
  ) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': customPrompt},
    ];

    for (final imageFile in imageFiles) {
      final preparedImage = await _prepareImageForGroq(imageFile);
      final base64Image = base64Encode(preparedImage.bytes);
      content.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:${preparedImage.mimeType};base64,$base64Image'
        }
      });
    }

    final raw = await _sendChatCompletion(
      messages: [
        {'role': 'user', 'content': content}
      ],
      apiKey: apiKey,
      model: _model,
      temperature: 0.1,
      maxOutputTokens: 8192,
    );

    final wrapped = {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': raw}
            ]
          }
        }
      ]
    };

    return GroqResponse.fromJson(wrapped);
  }

  Future<_PreparedGroqImage> _prepareImageForGroq(XFile imageFile) async {
    final rawBytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();
    String mimeType;
    Uint8List bytes;

    if (extension == 'jpg' || extension == 'jpeg') {
      mimeType = 'image/jpeg';
      bytes = Uint8List.fromList(rawBytes);
    } else if (extension == 'png') {
      mimeType = 'image/png';
      bytes = Uint8List.fromList(rawBytes);
    } else if (extension == 'webp') {
      mimeType = 'image/webp';
      bytes = Uint8List.fromList(rawBytes);
    } else {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        throw Exception(
            'Unsupported image format. Please upload JPG, PNG, WEBP, or a convertible image.');
      }
      bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
      mimeType = 'image/jpeg';
    }

    final originalBase64Length = base64Encode(bytes).length;
    final limited = await _ensureBase64WithinLimit(bytes, mimeType);
    if (originalBase64Length > _maxBase64Size && mimeType != 'image/jpeg') {
      mimeType = 'image/jpeg';
    }
    return _PreparedGroqImage(bytes: limited, mimeType: mimeType);
  }

  Future<Uint8List> _ensureBase64WithinLimit(
    Uint8List bytes,
    String mimeType,
  ) async {
    var encoded = base64Encode(bytes);
    if (encoded.length <= _maxBase64Size) {
      return bytes;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception(
          'Image exceeds the 4MB base64 limit and cannot be compressed further.');
    }

    img.Image current = decoded;
    int quality = 88;
    Uint8List compressed =
        Uint8List.fromList(img.encodeJpg(current, quality: quality));
    encoded = base64Encode(compressed);

    while (encoded.length > _maxBase64Size && quality >= 30) {
      quality -= 10;
      compressed = Uint8List.fromList(img.encodeJpg(current, quality: quality));
      encoded = base64Encode(compressed);
    }

    while (encoded.length > _maxBase64Size &&
        (current.width > 640 || current.height > 640)) {
      current = img.copyResize(
        current,
        width: (current.width * 0.8).round(),
        height: (current.height * 0.8).round(),
      );
      compressed = Uint8List.fromList(img.encodeJpg(current, quality: quality));
      encoded = base64Encode(compressed);
    }

    if (encoded.length > _maxBase64Size) {
      throw Exception(
          'Image exceeds the 4MB base64 limit after compression. Please use a smaller image.');
    }

    return compressed;
  }

  Future<String> _sendChatCompletion({
    required List<Map<String, dynamic>> messages,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final bool useJsonMode = messages.any((msg) {
      final content = msg['content'];
      if (content is String) {
        return content.toLowerCase().contains('return only valid json') ||
            content
                .toLowerCase()
                .contains('return only a single json object') ||
            content.toLowerCase().contains('output schema');
      }
      if (content is List) {
        return content.any((item) {
          if (item is Map && item['type'] == 'text' && item['text'] is String) {
            final text = (item['text'] as String).toLowerCase();
            return text.contains('return only valid json') ||
                text.contains('return only a single json object') ||
                text.contains('output schema');
          }
          return false;
        });
      }
      return false;
    });

    final requestBody = {
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxOutputTokens,
      'top_p': 1,
      'stream': false,
      if (useJsonMode) 'response_format': {'type': 'json_object'},
    };

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? response.body;
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractChatCompletionText(data);
    } on http.ClientException {
      throw Exception(
          'Network error: Unable to reach Groq API. Please check your connection.');
    } on FormatException catch (e) {
      throw Exception('Invalid response format from Groq API: $e');
    }
  }

  String _extractChatCompletionText(Map<String, dynamic> data) {
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq returned no choices in response');
    }

    final message = choices[0]['message'];
    if (message == null) {
      throw Exception('Groq returned no message in response');
    }

    final content = message['content'];
    if (content == null) {
      throw Exception('Groq returned empty content');
    }

    if (content is String) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) {
        throw Exception('Groq returned empty content');
      }
      return trimmed;
    }

    try {
      return jsonEncode(content).trim();
    } catch (_) {
      throw Exception('Unable to parse Groq chat completion content.');
    }
  }

  Map<String, dynamic> _parseJsonResponse(String raw) {
    final cleaned = _stripMarkdownFences(raw);
    if (cleaned.isEmpty) {
      throw Exception('Groq returned empty JSON response');
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Groq returned JSON that is not an object');
    } catch (e) {
      throw Exception('Failed to parse Groq JSON response: $e');
    }
  }

  String _stripMarkdownFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```[a-zA-Z0-9_-]*\n?'), '')
          .replaceAll(RegExp(r'\n?```$'), '')
          .trim();
    }
    return text;
  }
}

class _PreparedGroqImage {
  const _PreparedGroqImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
