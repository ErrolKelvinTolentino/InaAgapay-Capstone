// lib/services/groq_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/groq_response.dart';
import '../models/ocr_result.dart';

class GroqService {
  // ── Model Configuration ─────────────────────────────────────────────────

  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';
  static const String _reasoningModel = 'openai/gpt-oss-120b';

  // ── API Constraints ─────────────────────────────────────────────────────

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxBase64Size = 4 * 1024 * 1024;
  static const int _maxImagesPerRequest = 5;

  // ── Debug ───────────────────────────────────────────────────────────────

  final bool _debugMode = true;

  void _log(String message) {
    if (_debugMode && kDebugMode) {
      debugPrint('[GroqService] $message');
    }
  }

  // ── API Key ─────────────────────────────────────────────────────────────

  String _getApiKey() {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not found in .env');
    }
    return apiKey;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════

  Future<GroqResponse> analyzeUltrasoundImages(
    List<XFile> imageFiles, {
    String? clinicalContext,
  }) async {
    _validateImageInput(imageFiles);

    final apiKey = _getApiKey();
    final normalizedContext = (clinicalContext ?? '').trim();

    // ── Step 1: Vision Extraction ──────────────────────────────────────
    _log('📸 Step 1/2: Extracting ultrasound observations...');

    final String extractionPrompt = _buildUltrasoundExtractionPrompt(
      imageCount: imageFiles.length,
      clinicalContext: normalizedContext,
    );

    final String rawExtraction = await _sendVisionRequest(
      imageFiles: imageFiles,
      apiKey: apiKey,
      prompt: extractionPrompt,
      maxTokens: 4096,
    );

    // Log what the vision model actually saw
    _log(
        '📋 Raw extraction (first 500 chars): ${rawExtraction.length > 500 ? '${rawExtraction.substring(0, 500)}...' : rawExtraction}');

    // Validate the extraction contains actual data
    if (!rawExtraction.contains('visible_features') &&
        !rawExtraction.contains('visible_measurements')) {
      _log(
          '⚠️ Warning: Vision model may not have returned expected JSON structure');
    }

    // ── Step 2: Reasoning Analysis ─────────────────────────────────────
    _log('🧠 Step 2/2: Analyzing findings...');

    final String reasoningPrompt = _buildUltrasoundReasoningPrompt(
      rawExtraction: rawExtraction,
      imageCount: imageFiles.length,
      clinicalContext: normalizedContext,
    );

    final result = await _sendReasoningRequest(
      apiKey: apiKey,
      prompt: reasoningPrompt,
    );

    _log('✅ Analysis complete');
    return result;
  }

  Future<GroqResponse> analyzeLabTestImages(
    List<XFile> imageFiles, {
    String? selectedLabType,
    String? notes,
  }) async {
    _validateImageInput(imageFiles);

    final apiKey = _getApiKey();
    final normalizedType = (selectedLabType ?? '').trim();
    final normalizedNotes = (notes ?? '').trim();

    // ── Step 1: Vision Extraction ──────────────────────────────────────
    _log('📸 Step 1/2: Extracting lab test data...');

    final String extractionPrompt = _buildLabExtractionPrompt(
      imageCount: imageFiles.length,
      labType: normalizedType,
      notes: normalizedNotes,
    );

    final String rawExtraction = await _sendVisionRequest(
      imageFiles: imageFiles,
      apiKey: apiKey,
      prompt: extractionPrompt,
      maxTokens: 4096,
    );

    _log(
        '📋 Raw extraction (first 500 chars): ${rawExtraction.length > 500 ? '${rawExtraction.substring(0, 500)}...' : rawExtraction}');

    // ── Step 2: Reasoning Analysis ─────────────────────────────────────
    _log('🧠 Step 2/2: Analyzing lab results...');

    final String reasoningPrompt = _buildLabReasoningPrompt(
      rawExtraction: rawExtraction,
      imageCount: imageFiles.length,
      labType: normalizedType,
      notes: normalizedNotes,
    );

    final result = await _sendReasoningRequest(
      apiKey: apiKey,
      prompt: reasoningPrompt,
    );

    _log('✅ Analysis complete');
    return result;
  }

  Future<String> generateTextInsight({
    required String prompt,
    double temperature = 0.2,
    int maxOutputTokens = 2048,
  }) async {
    final apiKey = _getApiKey();
    _log('💬 Generating text insight...');

    return _sendChatCompletion(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      apiKey: apiKey,
      model: _reasoningModel,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }

  Future<OcrResult> extractMotherRegistrationData(XFile imageFile) async {
    final apiKey = _getApiKey();
    _log('📄 Extracting registration data...');

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
      model: _visionModel,
      temperature: 0.1,
      maxOutputTokens: 4096,
    );

    final cleaned = _stripMarkdownFences(raw);
    final json = _parseJsonResponse(cleaned);
    _log('✅ Registration data extracted');
    return OcrResult.fromJson(json);
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ════════════════════════════════════════════════════════════════════════

  String _buildUltrasoundExtractionPrompt({
    required int imageCount,
    required String clinicalContext,
  }) {
    return """
You are a medical imaging observer. Your ONLY job is to describe EXACTLY what you see in these ultrasound images.
Do NOT interpret, diagnose, or make recommendations.
Just list EVERY visible feature, measurement, structure, and text annotation you can see.

CRITICAL: Pay special attention to ANY abnormalities, unusual findings, or annotations marked with flags, arrows, or measurements that appear outside normal ranges. Report EVERYTHING you observe, even subtle details.

I am providing $imageCount ultrasound image(s) of the same pregnancy.
Clinical context: ${clinicalContext.isEmpty ? 'Not provided' : clinicalContext}

Return ONLY valid JSON (no markdown, no explanation outside the JSON):
{
  "visible_features": ["list EVERY feature you see - be exhaustive"],
  "visible_measurements": [
    {
      "name": "measurement name exactly as shown or described",
      "value": "numerical value exactly as shown or 'unclear'",
      "unit": "mm, cm, weeks, days, bpm, etc."
    }
  ],
  "visible_structures": ["list ALL anatomical structures visible - be exhaustive"],
  "text_annotations": ["any text, numbers, labels, or flags visible on the image"],
  "abnormal_indicators": ["any arrows, markers, color highlights, or annotations suggesting abnormalities"],
  "image_quality": "CLEAR|MODERATE|POOR",
  "raw_observations": "Detailed paragraph describing absolutely everything visible. Include ALL abnormalities, even subtle ones. Describe each structure's appearance."
}

CRITICAL:
- List ALL measurements you can see, even if uncertain. Mark unclear ones with value 'unclear'.
- List ALL structures visible, not just the main ones.
- The abnormal_indicators field is MANDATORY - list any visual cues that might indicate pathology.
- If the image is completely unrelated or unreadable, set image_quality to POOR and explain why.
""";
  }

  String _buildUltrasoundReasoningPrompt({
    required String rawExtraction,
    required int imageCount,
    required String clinicalContext,
  }) {
    // Clean the extraction but preserve its content
    final cleaned = _stripMarkdownFences(rawExtraction);

    return """You are an AI assistant that helps summarize ultrasound findings for maternal and child health support.

IMPORTANT DISCLAIMER:
- You are not making a diagnosis.
- Use ONLY the raw observations provided below.
- If evidence is unclear or missing, say so explicitly.
- Pay special attention to any abnormal indicators reported.

I am providing $imageCount ultrasound image(s) of the same pregnancy.
Clinical context: ${clinicalContext.isEmpty ? 'Not provided' : clinicalContext}

RAW OBSERVATIONS FROM ULTRASOUND IMAGES:
$cleaned

First do a relevance check.
If images are unrelated, unreadable, or not suitable for interpretation, set relevance_check to UNRELATED and explain briefly.

Then carefully analyze ALL findings, especially any abnormal indicators or measurements outside normal ranges.

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
    "evidence": "string explaining why this status was assigned"
   }
  ],
  "gestational_age_assessment": "string",
  "anatomical_findings": [
   {
    "structure": "string",
    "status": "NORMAL|UNCERTAIN|CONCERNING",
    "note": "string describing the finding"
   }
  ],
  "key_observations": ["string"],
  "recommendations": ["string"],
  "confidence_score": 0.0
}

Rules:
- Base ALL findings ONLY on the raw observations provided above.
- Include EVERY measurement from the raw observations in the measurements array.
- Include EVERY structure mentioned in the raw observations in anatomical_findings.
- If abnormal_indicators were reported, address each one in key_observations.
- Do not fabricate measurements not found in raw observations.
- Keep confidence_score between 0 and 1 (reflects data quality and completeness).
- If uncertain, use INSUFFICIENT_DATA and include what is missing.
- For any CONCERNING or BORDERLINE findings, provide specific evidence from the raw observations.
""";
  }

  String _buildLabExtractionPrompt({
    required int imageCount,
    required String labType,
    required String notes,
  }) {
    return """
You are a laboratory report data extractor. Your ONLY job is to extract EVERY single test result visible in these lab report images.

CRITICAL INSTRUCTIONS:
- Extract ALL test results EXHAUSTIVELY. Do NOT skip any.
- Include EVERY row, every test, every value you can read.
- Read both printed text AND handwritten notes.
- Include tests even if the value seems normal.
- Include tests even if the reference range is not visible.
- If you can't read a value clearly, write "unreadable" as the value.
- Pay special attention to any values marked with H (High), L (Low), asterisks (*), or other abnormal flags.
- Do NOT interpret results or flag abnormalities. Just extract raw data.

I am providing $imageCount laboratory report image(s).
Selected lab test type: ${labType.isEmpty ? 'Not specified' : labType}
Notes entered by user: ${notes.isEmpty ? 'None provided' : notes}

Return ONLY valid JSON (no markdown, no explanation outside the JSON):
{
  "extracted_tests": [
    {
      "test_name": "EXACT test name as written on the report",
      "value": "EXACT value as written - numbers and symbols only",
      "unit": "unit if shown (mg/dL, g/dL, %, etc.)",
      "reference_range": "reference range if shown, otherwise null",
      "flag": "H, L, *, or null if abnormal flag is shown",
      "comment": "any footnote or comment associated with this test"
    }
  ],
  "patient_info_visible": {
    "name": "patient name if visible or null",
    "date": "report date if visible or null",
    "lab_name": "laboratory name if visible or null"
  },
  "image_quality": "CLEAR|MODERATE|POOR",
  "total_tests_found": number,
  "raw_text_observed": "Transcribe all text you can read from the report. Be exhaustive."
}

ABSOLUTE REQUIREMENT:
- extracted_tests array MUST contain EVERY test found. If there are 20 tests, list all 20.
- Do NOT summarize or group tests. List each one individually.
- If the image is not a lab report or is completely unreadable, set image_quality to POOR and total_tests_found to 0.
""";
  }

  String _buildLabReasoningPrompt({
    required String rawExtraction,
    required int imageCount,
    required String labType,
    required String notes,
  }) {
    final cleaned = _stripMarkdownFences(rawExtraction);

    return """You are an AI assistant that helps summarize laboratory test records for maternal and child health support.

IMPORTANT DISCLAIMER:
- You are not making a diagnosis.
- Extract and organize values for healthcare worker review.
- Use ONLY the extracted data provided below. Do not fabricate anything.

I am providing $imageCount laboratory image(s).
Selected lab test type: ${labType.isEmpty ? 'Not specified' : labType}
Notes entered by user: ${notes.isEmpty ? 'None provided' : notes}

EXTRACTED LABORATORY DATA:
$cleaned

Step-by-step, analyze these lab values:

Step 1: Check if the extracted data is relevant (is it actually a lab report?)
If irrelevant or unreadable (image_quality: POOR with 0 tests found), set relevance_check to UNRELATED.

Step 2: For EACH extracted test, determine its status by comparing the value to the reference range:
- NORMAL: value within reference range
- BORDERLINE: value slightly outside range or at the boundary
- ABNORMAL: value significantly outside range OR has H/L/* flag
- UNKNOWN: no reference range available or value is unreadable

Step 3: Identify truly abnormal findings (flag H or L, or clearly outside range)

Step 4: Group tests that are within normal ranges

Step 5: Provide an overall assessment and actionable recommendations

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
      "evidence": "string explaining the status classification"
    }
  ],
  "abnormal_findings": ["string"],
  "normal_ranges": ["string"],
  "overall_assessment": "string",
  "recommendations": ["string"],
  "confidence_score": 0.0
}

Rules:
- Include EVERY test from the extracted data in lab_results. NEVER skip a test because it's normal.
- Do not invent results not present in the extracted data.
- Keep confidence_score between 0 and 1 (reflects data quality).
- If image quality blocks extraction, say so in relevance_reason.
- Keep output concise and non-redundant.
- Max 5 items in abnormal_findings.
- Max 5 items in normal_ranges.
- Max 4 items in recommendations.
- Do not repeat the same finding across multiple arrays.
- Include all distinct detected laboratory results in lab_results.
- Prefer short, direct phrasing for quick midwife review.
""";
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE API METHODS
  // ════════════════════════════════════════════════════════════════════════

  void _validateImageInput(List<XFile> imageFiles) {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }
    if (imageFiles.length > _maxImagesPerRequest) {
      throw Exception(
          'A maximum of $_maxImagesPerRequest images is allowed per request.');
    }
  }

  Future<String> _sendVisionRequest({
    required List<XFile> imageFiles,
    required String apiKey,
    required String prompt,
    required int maxTokens,
  }) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
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

    return _sendChatCompletion(
      messages: [
        {'role': 'user', 'content': content}
      ],
      apiKey: apiKey,
      model: _visionModel,
      temperature: 0.1,
      maxOutputTokens: maxTokens,
    );
  }

  Future<GroqResponse> _sendReasoningRequest({
    required String apiKey,
    required String prompt,
  }) async {
    // GPT-OSS does NOT support reasoning_format parameter
    // It includes reasoning by default via include_reasoning
    final raw = await _sendChatCompletion(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      apiKey: apiKey,
      model: _reasoningModel,
      temperature: 0.6,
      maxOutputTokens: 4096,
      forceJsonMode: true,
      // NO reasoningFormat - not supported by GPT-OSS
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

  // ════════════════════════════════════════════════════════════════════════
  // IMAGE PROCESSING
  // ════════════════════════════════════════════════════════════════════════

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

    final limited = await _ensureBase64WithinLimit(bytes);
    if (mimeType != 'image/jpeg' &&
        base64Encode(bytes).length > _maxBase64Size) {
      mimeType = 'image/jpeg';
    }
    return _PreparedGroqImage(bytes: limited, mimeType: mimeType);
  }

  Future<Uint8List> _ensureBase64WithinLimit(Uint8List bytes) async {
    var encoded = base64Encode(bytes);
    if (encoded.length <= _maxBase64Size) return bytes;

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

  // ════════════════════════════════════════════════════════════════════════
  // HTTP COMMUNICATION
  // ════════════════════════════════════════════════════════════════════════

  Future<String> _sendChatCompletion({
    required List<Map<String, dynamic>> messages,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxOutputTokens,
    bool forceJsonMode = false,
  }) async {
    final bool useJsonMode = forceJsonMode || _detectJsonMode(messages);

    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxOutputTokens,
      'top_p': 0.95,
      'stream': false,
      if (useJsonMode) 'response_format': {'type': 'json_object'},
    };

    _log(
        '🌐 Sending request to ${model.split('/').last} (${messages.toString().length} chars)...');

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 120));

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

  bool _detectJsonMode(List<Map<String, dynamic>> messages) {
    for (final msg in messages) {
      final content = msg['content'];
      String? textToCheck;

      if (content is String) {
        textToCheck = content;
      } else if (content is List) {
        for (final item in content) {
          if (item is Map && item['type'] == 'text' && item['text'] is String) {
            textToCheck = item['text'] as String;
            break;
          }
        }
      }

      if (textToCheck != null) {
        final lower = textToCheck.toLowerCase();
        if (lower.contains('return only valid json') ||
            lower.contains('return only a single json object') ||
            lower.contains('output schema')) {
          return true;
        }
      }
    }
    return false;
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

  // ════════════════════════════════════════════════════════════════════════
  // JSON PARSING HELPERS
  // ════════════════════════════════════════════════════════════════════════

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
    } on FormatException catch (e) {
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

// ════════════════════════════════════════════════════════════════════════════
// HELPER CLASSES
// ════════════════════════════════════════════════════════════════════════════

class _PreparedGroqImage {
  const _PreparedGroqImage({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}
