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
  // ── Model Configuration ─────────────────────────────────────────────────

  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';
  static const String _reasoningModel = 'openai/gpt-oss-120b';
  static const String _firstFallbackReasoningModel = 'openai/gpt-oss-20b';
  static const String _secondFallbackReasoningModel = 'qwen/qwen3-32b';

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
    String? clinicalContext,
  }) async {
    _validateImageInput(imageFiles);

    final apiKey = _getApiKey();
    final normalizedType = (selectedLabType ?? '').trim();
    final normalizedNotes = (notes ?? '').trim();
    final normalizedContext = (clinicalContext ?? '').trim();

    // ── Step 1: Vision Extraction ──────────────────────────────────────
    _log('📸 Step 1/2: Extracting lab test data...');

    final String extractionPrompt = _buildLabExtractionPrompt(
      imageCount: imageFiles.length,
      labType: normalizedType,
      notes: normalizedNotes,
      clinicalContext: normalizedContext,
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
      clinicalContext: normalizedContext,
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
        {
          'role': 'system',
          'content': 'You are a caring, knowledgeable midwife assistant in the Philippines who genuinely cares about every mother and child. '
              'Write as if you are a trusted ate (older sister) sitting beside the mother, gently explaining things. '
              'Celebrate good news warmly. When something needs attention, be honest but gentle and always offer practical next steps. '
              'Use simple Filipino-context language. Explain medical terms by what they mean for the mother and baby. '
              'Give culturally relevant advice (e.g., local foods like malunggay, kangkong, dilis for nutrition). '
              'Never be cold or clinical. Always end with encouragement.\n\n'
              'MATERNAL WEIGHT INTERPRETATION RULES (apply when weight/BMI data is present):\n'
              '- You are NOT responsible for computing BMI or weight gain formulas — the system provides those.\n'
              '- You translate maternal monitoring information into understandable explanations.\n'
              '- NEVER use words like "ideal weight", "perfect weight", "required weight", or "normal pregnancy weight".\n'
              '- Use softer wording: "commonly expected range", "estimated expected range", "appears within range", "appears slightly lower/higher than expected".\n'
              '- NEVER present exact target weights, guaranteed healthy weights, or rigid expectations.\n'
              '- If pre-pregnancy weight is unavailable, do NOT display BMI classifications or overweight/obese labels to the mother. Include disclaimer: "Pre-pregnancy weight information was not provided. Current insights are partially estimated and may have limited BMI-based interpretation."\n'
              '- For FIRST TRIMESTER: note that small weight changes are common in early pregnancy. Do NOT apply weekly rate references yet.\n'
              '- Every weight interpretation must end with: "This AI-assisted interpretation is intended only for healthcare monitoring support and does not replace professional medical consultation."'
        },
        {'role': 'user', 'content': prompt}
      ],
      apiKey: apiKey,
      model: _reasoningModel,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }

  // ── TTS API ─────────────────────────────────────────────────────────────
  /// Calls the Groq text-to-speech endpoint and returns concatenated WAV bytes.
  /// Uses canopylabs/orpheus-v1-english with "diana" voice.
  /// Handles the 200-char limit by splitting into sentence chunks automatically.
  static const int _ttsMaxChunkChars = 190; // safely under the 200-char limit
  static const int _wavHeaderSize = 44; // standard WAV header bytes

  Future<List<int>> speakWithGroqTts(String text) async {
    final apiKey = _getApiKey();

    // 1. Sanitise markdown
    final clean = text
        .replaceAll(RegExp(r'\*{1,2}'), '')
        .replaceAll(RegExp(r'#{1,6} ?'), '')
        .replaceAll(RegExp(r'-{3,}'), '')
        .replaceAll(RegExp(r'[_`]'), '')
        .replaceAll(RegExp(r'\n{2,}'), '. ')
        .replaceAll('\n', ' ')
        .trim();

    // 2. Split into ≤190-char chunks on sentence boundaries
    final chunks = _splitIntoTtsChunks(clean);
    _log('🔊 Groq TTS: ${clean.length} chars → ${chunks.length} chunk(s)');

    // 3. Fetch each chunk sequentially and combine the audio
    List<int> combinedAudio = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.trim().isEmpty) continue;

      _log(
          '   Chunk ${i + 1}/${chunks.length}: "${chunk.substring(0, chunk.length.clamp(0, 50))}..." (${chunk.length} chars)');

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/audio/speech'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'canopylabs/orpheus-v1-english',
              'input': '[cheerful] $chunk',
              'voice': 'autumn',
              'response_format': 'wav',
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        String errMsg;
        try {
          final errData = jsonDecode(response.body);
          errMsg = errData['error']?['message'] ?? response.body;
        } catch (_) {
          errMsg = response.body;
        }
        _log('❌ Groq TTS chunk $i failed (${response.statusCode}): $errMsg');
        throw Exception('Groq TTS Error (${response.statusCode}): $errMsg');
      }

      final bytes = response.bodyBytes;
      _log('   ✅ Chunk ${i + 1}: ${bytes.length} bytes received');

      if (i == 0) {
        // First chunk: keep the full WAV including header
        combinedAudio.addAll(bytes);
      } else {
        // Subsequent chunks: skip the 44-byte WAV header to avoid duplicates
        if (bytes.length > _wavHeaderSize) {
          combinedAudio.addAll(bytes.sublist(_wavHeaderSize));
        }
      }
    }

    _log('✅ Groq TTS complete: ${combinedAudio.length} total bytes');
    return combinedAudio;
  }

  /// Splits text into chunks of at most [_ttsMaxChunkChars] characters,
  /// preferring to break on sentence-ending punctuation (. ! ?) or commas.
  List<String> _splitIntoTtsChunks(String text) {
    if (text.length <= _ttsMaxChunkChars) return [text];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = (start + _ttsMaxChunkChars).clamp(0, text.length);
      if (end == text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      // Walk back to find a good break point: ". ", "! ", "? ", ", "
      int breakAt = -1;
      for (int j = end; j > start + 30; j--) {
        final ch = text[j];
        if ((ch == '.' || ch == '!' || ch == '?') &&
            j + 1 < text.length &&
            text[j + 1] == ' ') {
          breakAt = j + 1; // include the punctuation, break after it
          break;
        }
        if (ch == ',' && j + 1 < text.length && text[j + 1] == ' ') {
          breakAt = j + 1;
          // don't break yet — prefer sentence-ending punctuation
        }
      }

      if (breakAt == -1) {
        // No good punct found — fall back to last space
        breakAt = text.lastIndexOf(' ', end);
        if (breakAt <= start) breakAt = end; // hard cut
      }

      chunks.add(text.substring(start, breakAt).trim());
      start = breakAt;
      while (start < text.length && text[start] == ' ') {
        start++;
      }
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  Future<String> getChatResponse({
    required List<Map<String, dynamic>> chatHistory,
    double temperature = 0.5,
    int maxOutputTokens = 2048,
  }) async {
    final apiKey = _getApiKey();
    _log('💬 Generating chat response...');

    return _sendChatCompletion(
      messages: chatHistory,
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
  "patient_info_visible": {
    "patient_name": "patient name if visible or null",
    "clinic_location": "clinic or hospital name if visible or null",
    "attending_professional": "doctor or sonographer name if visible or null"
  },
  "image_quality": "CLEAR|MODERATE|POOR",
  "raw_observations": "Detailed paragraph describing absolutely everything visible. Include ALL abnormalities, even subtle ones. Describe each structure's appearance."
}

CRITICAL:
- List ALL measurements you can see, even if uncertain. Mark unclear ones with value 'unclear'.
- List ALL structures visible, not just the main ones.
- The abnormal_indicators field is MANDATORY - list any visual cues that might indicate pathology.
- If the image is completely unrelated or unreadable, set image_quality to POOR and explain why.
- If clinical context includes gestational age, trimester, or medical conditions, keep those in mind when listing observations.
""";
  }

  String _buildUltrasoundReasoningPrompt({
    required String rawExtraction,
    required int imageCount,
    required String clinicalContext,
  }) {
    // Clean the extraction but preserve its content
    final cleaned = _stripMarkdownFences(rawExtraction);

    return """You are a caring, knowledgeable midwife assistant in the Philippines. You genuinely care about this mother and her baby.

You are helping explain ultrasound findings. Write as if you are sitting beside the mother, showing her the ultrasound images and gently explaining what you see. Your tone should feel like a trusted ate (older sister) who also happens to be medically trained.

IMPORTANT GUIDELINES:
- You are NOT making a diagnosis — only summarizing what the ultrasound shows.
- When things look good, celebrate: "Your baby's head is measuring right on track for this stage — everything looks wonderful!"
- When something needs attention, be honest but gentle: "One measurement came in a little different than expected. This doesn't necessarily mean something is wrong, but your midwife may want to do a follow-up scan to be sure."
- Explain what measurements actually mean: "BPD is your baby's head width — at 45mm, this tells us your little one's brain is developing nicely."
- Give practical, Filipino-context advice: "Make sure you're eating well — fish, malunggay, and eggs are great for baby's growth."
- If evidence is unclear or missing, say so honestly but reassuringly.
- Pay special attention to any abnormal indicators reported.

I am providing $imageCount ultrasound image(s) of the same pregnancy.
Clinical context: ${clinicalContext.isEmpty ? 'Not provided' : clinicalContext}

RAW OBSERVATIONS FROM ULTRASOUND IMAGES:
$cleaned

First do a relevance check.
If images are unrelated, unreadable, or not suitable for interpretation, set relevance_check to UNRELATED and explain briefly.

Then carefully analyze ALL findings, especially any abnormal indicators or measurements outside normal ranges.

Structure your analysis so it can be clearly presented as:
SUMMARY: [1-2 sentence plain language summary of the ultrasound]
KEY FINDINGS: [bullet points of what was seen]
RECOMMENDATIONS: [bullet points of what to do next]

Return ONLY valid JSON in this exact schema:
{
  "relevance_check": "RELATED|UNRELATED",
  "relevance_reason": "string",
  "overall_health_status": "HEALTHY_NORMAL|REQUIRES_MONITORING|CONSULT_SPECIALIST|INSUFFICIENT_DATA",
  "summary": "1-2 sentence caring summary for the mother — celebrate what's good, gently note any concerns (e.g. 'Your baby is growing beautifully! Everything looks healthy and right on track.')",
  "measurements": [
   {
    "name": "string",
    "value": "string",
    "status": "NORMAL|BORDERLINE|CONCERNING|UNKNOWN",
    "evidence": "string explaining what this measurement means for the mother and baby in warm, simple language (e.g. 'This measures your baby's head size — it's perfectly normal for this stage!')"
   }
  ],
  "gestational_age_assessment": "string in personal language (e.g. 'Your little one is about 28 weeks along — you're in the home stretch of your third trimester, mama!')",
  "anatomical_findings": [
   {
    "structure": "string",
    "status": "NORMAL|UNCERTAIN|CONCERNING",
    "note": "string describing the finding warmly (e.g. 'Your baby's heart has all four chambers and is beating strong — beautiful!')"
   }
  ],
  "key_observations": ["string — warm, personal language explaining what was seen and what it means for mama and baby"],
  "recommendations": ["string — practical, caring advice the mother can act on (e.g. 'Your next scan in 4 weeks will let us see how much your baby has grown — exciting!' not 'Follow-up recommended')"],
  "patient_info_visible": {
    "patient_name": "patient name if found in raw observations or null",
    "clinic_location": "clinic or hospital name if found in raw observations or null",
    "attending_professional": "doctor or sonographer name if found in raw observations or null"
  },
  "confidence_score": 0.0
}

Rules:
- Base ALL findings ONLY on the raw observations provided above.
- Include EVERY measurement from the raw observations in the measurements array.
- Include EVERY structure mentioned in the raw observations in anatomical_findings.
- If abnormal_indicators were reported, address each one in key_observations clearly and honestly.
- Do not fabricate measurements not found in raw observations.
- Keep confidence_score between 0 and 1 (reflects data quality and completeness).
- If uncertain, use INSUFFICIENT_DATA and include what is missing.
- For any CONCERNING or BORDERLINE findings, explain clearly but gently what it means, why it matters, and what the mother can do. Never alarm — always pair concern with a practical next step.
- When things look normal, celebrate warmly (e.g. "Everything looks wonderful, mama — your baby is growing strong!")
- If fetal weight estimates are mentioned, NEVER use "ideal weight" or "normal weight". Use "commonly expected range" or "appears within range".
- Always end on an encouraging note.
- End with: "This AI-assisted interpretation is for monitoring support only and does not replace professional medical consultation."
""";
  }

  String _buildLabExtractionPrompt({
    required int imageCount,
    required String labType,
    required String notes,
    String clinicalContext = '',
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
Clinical context: ${clinicalContext.isEmpty ? 'Not provided' : clinicalContext}

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
    "lab_name": "laboratory name if visible or null",
    "attending_professional": "requesting or attending doctor name if visible or null"
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
    String clinicalContext = '',
  }) {
    final cleaned = _stripMarkdownFences(rawExtraction);

    return """You are a caring, knowledgeable midwife assistant in the Philippines. You genuinely care about this mother and her baby.

You are helping explain laboratory test results. Write as if you are sitting beside the mother, going through her lab results together. Your tone should feel like a trusted ate (older sister) who also happens to be medically trained.

IMPORTANT GUIDELINES:
- You are NOT making a diagnosis — only summarizing what the lab results show.
- When results are normal, reassure warmly: "Your hemoglobin is at a healthy level — this means your blood is carrying plenty of oxygen to you and your baby. Well done, mama!"
- When something is off, be gentle and practical: "Your iron is a little low. This is actually very common during pregnancy. The good news is we can improve it — try eating more malunggay, kangkong, and lean meat, and your midwife may give you iron supplements."
- Explain what each test actually measures in simple terms: "Hemoglobin tells us how well your blood can carry oxygen. Think of it like your body's delivery system for your baby."
- Give Filipino-context dietary and lifestyle advice, not generic medical recommendations.
- Use ONLY the extracted data provided below. Do not fabricate anything.

I am providing $imageCount laboratory image(s).
Selected lab test type: ${labType.isEmpty ? 'Not specified' : labType}
Notes entered by user: ${notes.isEmpty ? 'None provided' : notes}
Clinical context: ${clinicalContext.isEmpty ? 'Not provided' : clinicalContext}

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

Structure your analysis so it can be clearly presented as:
SUMMARY: [1-2 sentence plain language summary of the lab results]
KEY FINDINGS: [bullet points of notable results]
RECOMMENDATIONS: [bullet points of what to do next]

Return ONLY valid JSON in this exact schema:
{
  "relevance_check": "RELATED|UNRELATED",
  "relevance_reason": "string",
  "summary": "1-2 sentence caring summary (e.g. 'Great news, mama — most of your lab results look healthy! There's just one thing we'll want to work on together.')",
  "lab_results": [
    {
      "test_name": "string",
      "value": "string",
      "unit": "string",
      "reference_range": "string",
      "status": "NORMAL|BORDERLINE|ABNORMAL|UNKNOWN",
      "evidence": "string explaining what this means for the mother personally (e.g. 'Your hemoglobin is healthy — this means your blood is carrying plenty of oxygen to your baby. Keep it up!')"
    }
  ],
  "abnormal_findings": ["string — explain gently what it means and give practical advice (e.g. 'Your iron is a little low — this is very common in pregnancy. Try eating more malunggay, kangkong, and dilis. Your midwife may also give you supplements.')"],
  "normal_ranges": ["string — celebrate warmly (e.g. 'Your blood sugar is looking perfect — your body is handling pregnancy well!')"],
  "overall_assessment": "string — warm, personal summary like a caring ate would give (e.g. 'Overall, you're doing well, mama. Your body is taking good care of your baby.')",
  "recommendations": ["string — practical Filipino-context advice (e.g. 'Add an egg and a handful of malunggay to your meals each day — simple pero malaking tulong sa baby mo!')"],
  "patient_info_visible": {
    "name": "patient name if found in extracted data or null",
    "lab_name": "laboratory name if found in extracted data or null",
    "attending_professional": "requesting or attending doctor name if found in extracted data or null"
  },
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
- Max 4 items in recommendations — each must be actionable (tell the mother what to DO, not just what to watch).
- Do not repeat the same finding across multiple arrays.
- Include all distinct detected laboratory results in lab_results.
- Use warm, caring phrasing — like a trusted ate talking to her bunso. Be honest about concerns but always pair them with encouragement and practical advice.
- If lab results relate to maternal nutrition/weight (iron, glucose, etc.), NEVER use "ideal" or "normal" labels. Use "commonly expected range" or "appears within range".
- Always end on an encouraging note (e.g. "You're doing a great job taking care of yourself and your baby, mama!").
- End with: "This AI-assisted interpretation is for monitoring support only and does not replace professional medical consultation."
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
    bool allowModelFallback = true,
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
        String errorMessage = response.body;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? response.body;
        } catch (_) {}

        if (allowModelFallback && _isTokenLimitError(errorMessage)) {
          final nextModel = _nextReasoningFallbackModel(model);
          if (nextModel != null) {
            _log(
                '⚠️ ${model.split('/').last} token limit reached; retrying with ${nextModel.split('/').last}');
            return _sendChatCompletion(
              messages: messages,
              apiKey: apiKey,
              model: nextModel,
              temperature: temperature,
              maxOutputTokens: maxOutputTokens,
              forceJsonMode: forceJsonMode,
              allowModelFallback: true,
            );
          }
        }

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

  bool _isTokenLimitError(String message) {
    final normalized = message.toLowerCase();
    return (normalized.contains('token') || normalized.contains('context')) &&
        (normalized.contains('limit') ||
            normalized.contains('maximum') ||
            normalized.contains('exceeded') ||
            normalized.contains('too long') ||
            normalized.contains('max tokens') ||
            normalized.contains('context length'));
  }

  String? _nextReasoningFallbackModel(String currentModel) {
    if (currentModel == _reasoningModel) {
      return _firstFallbackReasoningModel;
    }
    if (currentModel == _firstFallbackReasoningModel) {
      return _secondFallbackReasoningModel;
    }
    return null;
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
