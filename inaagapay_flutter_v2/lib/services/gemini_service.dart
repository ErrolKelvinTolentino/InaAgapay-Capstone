// lib/services/gemini_service.dart - REAL Gemini AI Implementation
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/ai_analysis.dart';
import '../models/child.dart';
import '../models/growth_record.dart';

class GeminiService {
  // Using v1 instead of v1beta for better model compatibility
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models';
  
  // Available Gemini models:
  // - gemini-1.5-pro: Most capable model for complex tasks
  // - gemini-1.5-flash: Fast and versatile model
  // - gemini-1.0-pro: Previous generation model
  final String _model = 'gemini-1.5-flash';
  final String _fallbackModel = 'gemini-1.5-pro';
  final String _legacyModel = 'gemini-pro'; // Legacy model as last resort
  
  // Your provided API key
  static const String _apiKey = 'AIzaSyDdJTeDVhoe17VJU1YOujd-CGJqdHcjAwM';

  Future<AIAnalysis> analyzeGrowthData(
    Child child, 
    List<GrowthRecord> records
  ) async {
    // Try multiple models in sequence
    final List<String> modelsToTry = [
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro', // Legacy model
    ];
    
    Exception? lastError;
    
    for (String model in modelsToTry) {
      try {
        debugPrint('🌐 Trying Gemini model: $model');
        final result = await _tryModel(model, child, records);
        if (result != null) {
          debugPrint('✅ Successfully used model: $model');
          return result;
        }
      } catch (e) {
        debugPrint('❌ Model $model failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        // Continue to next model
      }
    }
    
    // If all models fail, throw the last error
    throw lastError ?? Exception('All Gemini models failed');
  }

  Future<AIAnalysis?> _tryModel(String model, Child child, List<GrowthRecord> records) async {
    try {
      final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');
      
      // Prepare growth data summary
      final growthSummary = _prepareGrowthSummary(child, records);
      
      // Create prompt for AI
      final prompt = _createAnalysisPrompt(child, growthSummary);

      debugPrint('📤 Sending request to Gemini AI using model: $model');
      debugPrint('Prompt length: ${prompt.length} characters');

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseGeminiResponse(data);
      } else {
        debugPrint('❌ Model $model failed with status ${response.statusCode}');
        if (response.statusCode == 404) {
          // Model not found, try next
          return null;
        }
        final error = jsonDecode(response.body);
        throw Exception('Gemini AI Error: ${error['error']['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('❌ Error with model $model: $e');
      return null;
    }
  }

  String _prepareGrowthSummary(Child child, List<GrowthRecord> records) {
    if (records.isEmpty) {
      return 'No growth records available for ${child.name}.';
    }

    final sortedRecords = List.from(records)..sort((a, b) => a.ageInWeeks.compareTo(b.ageInWeeks));
    
    StringBuffer summary = StringBuffer();
    summary.writeln('CHILD PROFILE:');
    summary.writeln('- Name: ${child.name}');
    summary.writeln('- Gender: ${child.gender}');
    summary.writeln('- Birth Date: ${child.birthDate.toIso8601String().split('T')[0]}');
    summary.writeln('- Current Age: ${child.getAgeInWeeks()} weeks');
    summary.writeln('- Total Growth Records: ${records.length}');
    
    summary.writeln('\nCOMPLETE GROWTH HISTORY (chronological order):');
    for (var record in sortedRecords) {
      summary.writeln(
        'Week ${record.ageInWeeks} (${_formatDate(record.dateRecorded)}): '
        'Weight=${record.weight}kg (${record.weightClassification}), '
        'Height=${record.height}cm (${record.heightClassification}), '
        'BMI=${record.bmi.toStringAsFixed(2)} (${record.bmiClassification})'
      );
    }

    // Calculate trends
    if (sortedRecords.length >= 2) {
      final first = sortedRecords.first;
      final last = sortedRecords.last;
      final weeksDiff = last.ageInWeeks - first.ageInWeeks;
      
      if (weeksDiff > 0) {
        final totalWeightGain = last.weight - first.weight;
        final totalHeightGain = last.height - first.height;
        final weeklyWeightGain = totalWeightGain / weeksDiff;
        final weeklyHeightGain = totalHeightGain / weeksDiff;
        
        summary.writeln('\nGROWTH METRICS:');
        summary.writeln('- Total weight gain: ${totalWeightGain.toStringAsFixed(2)} kg over $weeksDiff weeks');
        summary.writeln('- Total height gain: ${totalHeightGain.toStringAsFixed(2)} cm over $weeksDiff weeks');
        summary.writeln('- Average weekly weight gain: ${weeklyWeightGain.toStringAsFixed(3)} kg/week');
        summary.writeln('- Average weekly height gain: ${weeklyHeightGain.toStringAsFixed(2)} cm/week');
        summary.writeln('- Projected monthly weight gain: ${(weeklyWeightGain * 4).toStringAsFixed(2)} kg/month');
        summary.writeln('- Projected monthly height gain: ${(weeklyHeightGain * 4).toStringAsFixed(2)} cm/month');
      }
    }

    // Add latest measurements
    final latest = sortedRecords.last;
    summary.writeln('\nCURRENT STATUS (Most Recent - Week ${latest.ageInWeeks}):');
    summary.writeln('- Weight: ${latest.weight}kg (${latest.weightClassification})');
    summary.writeln('- Height: ${latest.height}cm (${latest.heightClassification})');
    summary.writeln('- BMI: ${latest.bmi.toStringAsFixed(2)} (${latest.bmiClassification})');

    // Add WHO standard comparisons
    summary.writeln('\nWHO STANDARD COMPARISONS:');
    summary.writeln('- Weight Z-Score: ${latest.weightZScore.toStringAsFixed(2)}');
    summary.writeln('- Height Z-Score: ${latest.heightZScore.toStringAsFixed(2)}');
    summary.writeln('- BMI Z-Score: ${latest.bmiZScore.toStringAsFixed(2)}');

    return summary.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _createAnalysisPrompt(Child child, String growthSummary) {
    return '''
You are a WHO-certified pediatric growth specialist and AI medical advisor. Analyze this infant's complete growth data and provide a professional, personalized assessment.

$growthSummary

Based on WHO growth standards and pediatric medical knowledge, provide a comprehensive AI analysis in this EXACT JSON format (no other text):

{
  "summary": "A detailed 3-4 sentence professional summary of the child's overall growth pattern, including key observations",
  "trend": "OVERALL_TREND",
  "recommendations": [
    "First specific, actionable medical recommendation",
    "Second specific, actionable medical recommendation",
    "Third specific, actionable medical recommendation",
    "Fourth specific, actionable medical recommendation"
  ],
  "insights": {
    "weightAnalysis": "Detailed analysis of weight trend, including comparison to WHO standards and percentile tracking",
    "heightAnalysis": "Detailed analysis of height trend, including growth velocity and proportionality",
    "bmiAnalysis": "Detailed analysis of BMI, including body composition implications",
    "growthVelocity": "Assessment of growth rate and acceleration/deceleration patterns",
    "riskFactors": "Identified risk factors or concerns based on the data",
    "positiveIndicators": "Positive growth indicators and strengths",
    "nutritionalImplications": "What the growth pattern suggests about nutrition",
    "developmentalCorrelations": "How growth correlates with typical developmental milestones"
  },
  "confidenceScore": 0.95
}

RULES FOR AI ANALYSIS:
1. trend MUST be one of: EXCELLENT, GOOD, NORMAL, CONCERNING, CRITICAL
2. Use professional medical language that parents can understand
3. Base ALL analysis on actual WHO growth standards
4. Reference specific Z-scores and percentiles from the data
5. Provide REAL medical insights, not generic statements
6. Consider the child's age, gender, and growth trajectory
7. Identify any patterns that deviate from normal growth curves
8. Suggest specific actions based on the data patterns
9. Return ONLY the JSON, no additional text or markdown
''';
  }

  AIAnalysis _parseGeminiResponse(Map<String, dynamic> data) {
    try {
      String text = "";
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final candidate = data['candidates'][0];
        if (candidate['content'] != null && candidate['content']['parts'] != null) {
          text = candidate['content']['parts'][0]['text'] ?? "";
        }
      }

      if (text.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      debugPrint('Raw Gemini AI response: $text');
      
      // Extract JSON from response
      final jsonStr = _extractJson(text);
      final Map<String, dynamic> jsonData = json.decode(jsonStr);
      
      return AIAnalysis.fromJson(jsonData);
    } catch (e) {
      debugPrint('Error parsing Gemini AI response: $e');
      rethrow;
    }
  }

  String _extractJson(String text) {
    // Clean the response and extract JSON
    text = text.trim();
    
    // Remove any markdown code blocks
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    
    // Find JSON boundaries
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    
    throw Exception('No valid JSON found in Gemini response');
  }
}