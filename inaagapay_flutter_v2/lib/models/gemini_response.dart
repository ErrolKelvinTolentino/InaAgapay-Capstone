class GeminiResponse {
  final String description;
  final List<String>? measurements;
  final List<String>? labels;
  final double? confidence;
  
  // New fields for health assessment
  final String? healthStatus;
  final List<String>? normalFindings;
  final List<String>? concerns;
  final String? gestationalAge;
  final String? fetalWeight;
  final String? heartRate;

  GeminiResponse({
    required this.description,
    this.measurements,
    this.labels,
    this.confidence,
    this.healthStatus,
    this.normalFindings,
    this.concerns,
    this.gestationalAge,
    this.fetalWeight,
    this.heartRate,
  });

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    String text = "";

    try {
      if (json['candidates'] != null && json['candidates'].isNotEmpty) {
        final candidate = json['candidates'][0];
        
        if (candidate['content'] != null &&
            candidate['content']['parts'] != null &&
            candidate['content']['parts'].isNotEmpty) {
          
          text = candidate['content']['parts'][0]['text'] ?? "";
        }
      }
    } catch (e) {
      text = "Error parsing response";
    }

    // Extract health status from text
    String? healthStatus;
    if (text.contains('OVERALL HEALTH STATUS: HEALTHY/NORMAL')) {
      healthStatus = 'HEALTHY ✓';
    } else if (text.contains('OVERALL HEALTH STATUS: REQUIRES MONITORING')) {
      healthStatus = 'REQUIRES MONITORING ⚠️';
    } else if (text.contains('OVERALL HEALTH STATUS: CONSULT SPECIALIST')) {
      healthStatus = 'CONSULT SPECIALIST ⚠️⚠️';
    }

    // Extract measurements
    List<String> extractedMeasurements = [];
    List<String> normalList = [];
    List<String> concernsList = [];
    String? ga;
    String? fw;
    String? hr;

    if (text.isNotEmpty) {
      // Look for common ultrasound measurements
      final measurementPatterns = [
        RegExp(r'BPD[:\s]*(\d+(?:\.\d+)?\s*mm)', caseSensitive: false),
        RegExp(r'HC[:\s]*(\d+(?:\.\d+)?\s*mm)', caseSensitive: false),
        RegExp(r'AC[:\s]*(\d+(?:\.\d+)?\s*mm)', caseSensitive: false),
        RegExp(r'FL[:\s]*(\d+(?:\.\d+)?\s*mm)', caseSensitive: false),
        RegExp(r'Fetal Heart Rate[:\s]*(\d+(?:\.\d+)?\s*bpm)', caseSensitive: false),
        RegExp(r'Estimated Fetal Weight[:\s]*(\d+(?:\.\d+)?\s*(?:g|kg))', caseSensitive: false),
        RegExp(r'Amniotic Fluid[:\s]*(\d+(?:\.\d+)?\s*cm)', caseSensitive: false),
      ];

      for (var pattern in measurementPatterns) {
        final matches = pattern.allMatches(text);
        for (var match in matches) {
          if (match.group(0) != null) {
            extractedMeasurements.add(match.group(0)!);
            
            // Check if it's a heart rate
            if (match.group(0)!.contains('bpm')) {
              hr = match.group(0);
            }
            // Check if it's fetal weight
            else if (match.group(0)!.contains('kg') || match.group(0)!.contains('g')) {
              fw = match.group(0);
            }
          }
        }
      }

      // Extract gestational age
      final gaMatch = RegExp(r'Gestational Age[:\s]*(\d+\s*(?:weeks?|wks?)[^\n]*)', caseSensitive: false).firstMatch(text);
      if (gaMatch != null) {
        ga = gaMatch.group(1);
      }

      // Look for normal findings (lines with ✓)
      final normalMatches = RegExp(r'✓([^\n]+)').allMatches(text);
      for (var match in normalMatches) {
        if (match.group(1) != null) {
          normalList.add(match.group(1)!.trim());
        }
      }

      // Look for concerns
      if (text.contains('REQUIRES MONITORING') || text.contains('CONSULT SPECIALIST')) {
        final concernSection = text.split('KEY OBSERVATIONS:').last.split('HEALTH SUMMARY:').first;
        final concernLines = concernSection.split('\n').where((line) => 
          line.contains('⚠️') || line.contains('borderline') || line.contains('concerning')
        ).toList();
        concernsList = concernLines;
      }
    }

    return GeminiResponse(
      description: text.isEmpty ? "No description available" : text,
      measurements: extractedMeasurements.isNotEmpty ? extractedMeasurements.toSet().toList() : null,
      labels: [],
      confidence: 1.0,
      healthStatus: healthStatus,
      normalFindings: normalList.isNotEmpty ? normalList : null,
      concerns: concernsList.isNotEmpty ? concernsList : null,
      gestationalAge: ga,
      fetalWeight: fw,
      heartRate: hr,
    );
  }
}