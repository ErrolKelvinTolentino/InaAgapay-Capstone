import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gemini_response.dart';

class GeminiService {
  // Start with base models, will be updated after checking available models
  final List<String> _modelsToTry = [
    'gemini-pro-vision',
    'gemini-1.5-flash',
    'gemini-1.5-flash-001',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro',
    'gemini-1.0-pro-vision',
  ];
  
  String? _workingModel;
  String? _workingApiVersion;
  List<String> _availableModels = [];

  // For debugging - set to false in production
  final bool _debugMode = true;

  void _log(String message) {
    if (_debugMode && kDebugMode) {
      debugPrint(message);
    }
  }

  // Method to check available models from the API
  Future<void> checkAvailableModels() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _log('No API key found for checking models');
      return;
    }
    
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models?key=$apiKey'
    );
    
    try {
      _log('Checking available Gemini models...');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List? ?? [];
        
        _availableModels = models
            .map<String>((model) => model['name'].toString().replaceFirst('models/', ''))
            .where((name) => name.contains('vision') || name.contains('flash') || name.contains('pro'))
            .toList();
        
        _log('Available vision-capable models: ${_availableModels.join(', ')}');
        
        // Update _modelsToTry with actually available models
        if (_availableModels.isNotEmpty) {
          _modelsToTry.clear();
          _modelsToTry.addAll(_availableModels);
          _log('Updated models to try: ${_modelsToTry.join(', ')}');
        }
      } else {
        _log('Failed to get models: HTTP ${response.statusCode}');
        _log('Response: ${response.body}');
      }
    } catch (e) {
      _log('Error checking available models: $e');
    }
  }

  // Method for analyzing multiple ultrasound images with health assessment
  Future<GeminiResponse> analyzeUltrasoundImages(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw Exception('No images selected');
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not found in .env');
    }

    // Check available models first if we haven't already
    if (_availableModels.isEmpty) {
      await checkAvailableModels();
    }

    _log('Analyzing ${imageFiles.length} ultrasound images together...');
    
    return _analyzeCombinedUltrasound(imageFiles, apiKey);
  }

  Future<GeminiResponse> _analyzeCombinedUltrasound(
    List<XFile> imageFiles, 
    String apiKey
  ) async {
    final String combinedPrompt = """
You are an AI assistant that helps summarize ultrasound images for record-keeping purposes and provides health assessments based on standard medical guidelines.

IMPORTANT DISCLAIMER: You are not making a medical diagnosis. You are providing observations based on standard fetal biometry reference ranges. Always consult with a healthcare professional.

I am providing you with ${imageFiles.length} ultrasound images of the same patient/pregnancy. 
Please analyze ALL images together and provide a COMPREHENSIVE HEALTH ASSESSMENT that includes:

1. OVERALL HEALTH STATUS: Based on all images, provide a clear assessment of whether the pregnancy appears:
   - HEALTHY/NORMAL: All measurements within normal ranges
   - REQUIRES MONITORING: Some measurements slightly outside normal ranges
   - CONSULT SPECIALIST: Multiple measurements significantly outside normal ranges

2. DETAILED ANALYSIS:
   a) FETAL BIOMETRY ASSESSMENT:
      - For each measurement found (BPD, HC, AC, FL), indicate if it's:
        * Normal (within 5th-95th percentile)
        * Borderline (just outside normal range)
        * Concerning (significantly outside normal range)
   
   b) GESTATIONAL AGE: Provide the most consistent estimate and indicate if it matches expected dates
   
   c) FETAL WEIGHT: Provide estimate and indicate if it's appropriate for gestational age
   
   d) HEART RATE: Provide reading and indicate if it's within normal range (120-160 bpm)

3. KEY FINDINGS:
   - List all visible anatomical structures and indicate if they appear normal
   - Note any visible abnormalities or concerns
   - Assess amniotic fluid volume (normal, low, high)
   - Assess placental position and appearance

4. HEALTH SUMMARY:
   - Overall assessment in 2-3 sentences
   - Specific recommendations for monitoring if any concerns noted
   - Clear disclaimer that this is not a medical diagnosis

Format your response exactly like this example:

"COMPREHENSIVE ULTRASOUND HEALTH ASSESSMENT
=============================================

OVERALL HEALTH STATUS: HEALTHY/NORMAL ✓
All measured parameters are within normal ranges for gestational age. The pregnancy appears to be progressing normally.

DETAILED MEASUREMENTS ASSESSMENT:
• BPD (Biparietal Diameter): 80 mm - NORMAL (appropriate for 32 weeks)
• HC (Head Circumference): 290 mm - NORMAL (appropriate for 32 weeks)
• AC (Abdominal Circumference): 270 mm - NORMAL (appropriate for 32 weeks)
• FL (Femur Length): 62 mm - NORMAL (appropriate for 32 weeks)
• Fetal Heart Rate: 142 bpm - NORMAL (within 120-160 bpm range)
• Estimated Fetal Weight: 2.3 kg - NORMAL for gestational age
• Amniotic Fluid Index: 14 cm - NORMAL
• Placenta: Anterior, Grade II - NORMAL for this stage

GESTATIONAL AGE ASSESSMENT:
• Consistent at 32 weeks 1 day across all measurements
• Matches expected dates based on measurements

ANATOMICAL ASSESSMENT:
✓ Fetal head: Normal shape and anatomy visualized
✓ Fetal brain: Normal ventricular appearance
✓ Fetal spine: Intact, normal alignment
✓ Fetal heart: Four-chamber view normal, regular rhythm
✓ Fetal abdomen: Stomach and bladder visualized
✓ Fetal limbs: All present, normal movement observed
✓ Umbilical cord: Three vessels visualized

KEY OBSERVATIONS:
• Good fetal movements noted throughout exam
• Fetal position: Cephalic (head-down)
• Posterior neck: Normal appearance

HEALTH SUMMARY:
This ultrasound shows a normally developing fetus at 32 weeks gestation with all biometric measurements within expected ranges. Fetal anatomy appears normal and amniotic fluid volume is adequate. The pregnancy is progressing as expected for gestational age.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ IMPORTANT DISCLAIMER: This assessment is based on standard fetal growth references and visible anatomical structures. It is NOT a medical diagnosis. Always consult with your healthcare provider for proper interpretation of ultrasound findings and medical advice.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""";

    return _makeMultiImageRequest(imageFiles, apiKey, combinedPrompt);
  }

  // Method for analyzing lab test images
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
    // If we already found a working model, use it
    if (_workingModel != null && _workingApiVersion != null) {
      return _sendMultiImageRequest(imageFiles, apiKey, _workingModel!, _workingApiVersion!, customPrompt);
    }
    
    Exception? lastError;
    
    // Try all models until one works
    for (String model in _modelsToTry) {
      for (String apiVersion in ['v1', 'v1beta']) {
        try {
          _log('Trying $apiVersion/$model for multi-image analysis...');
          final result = await _sendMultiImageRequest(imageFiles, apiKey, model, apiVersion, customPrompt);
          // Save working model
          _workingModel = model;
          _workingApiVersion = apiVersion;
          _log('✅ SUCCESS! Using model: $model with API version: $apiVersion');
          return result;
        } catch (e) {
          _log('❌ $apiVersion/$model failed: ${e.toString()}');
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
    }
    
    // If all models failed, show helpful error message
    _log('❌ All models failed. Available models on your account: ${_availableModels.join(', ')}');
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

    // Build parts array with text prompt + all images
    List<Map<String, dynamic>> parts = [
      {"text": customPrompt}
    ];

    // Add all images as inline_data
    for (int i = 0; i < imageFiles.length; i++) {
      final bytes = await imageFiles[i].readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Determine mime type
      String mimeType = 'image/jpeg';
      final extension = imageFiles[i].path.split('.').last.toLowerCase();
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      parts.add({
        "inline_data": {
          "mime_type": mimeType,
          "data": base64Image
        }
      });
      
      _log('Image ${i + 1} added: ${(bytes.length / 1024).toStringAsFixed(2)} KB');
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

    _log('Sending ${imageFiles.length} images together for health assessment...');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _log('✅ Health assessment successful!');
      return GeminiResponse.fromJson(data);
    } else {
      _log('❌ HTTP ${response.statusCode}: ${response.body}');
      throw Exception('API Error (${response.statusCode})');
    }
  }

  // Method to get model information
  String getCurrentModelInfo() {
    if (_workingModel != null) {
      return "✅ Using model: $_workingModel (API: $_workingApiVersion)";
    }
    return "⏳ No active model yet. Available models: ${_availableModels.join(', ')}";
  }
  
  // Method to get available models
  List<String> getAvailableModels() {
    return List.from(_availableModels);
  }
}