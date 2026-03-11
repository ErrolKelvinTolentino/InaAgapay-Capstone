// lib/services/risk_engine.dart

import '../models/add_mother_form_data.dart';

class RiskAssessment {
  final String level; // 'low', 'medium', 'high'
  final double score;
  final List<String> factors;
  final String note;

  const RiskAssessment({
    required this.level,
    required this.score,
    required this.factors,
    required this.note,
  });
}

class RiskEngine {
  static RiskAssessment evaluate(AddMotherFormData form) {
    double score = 0;
    final List<String> factors = [];

    // Age risk
    if (form.ageYears != null) {
      if (form.ageYears! < 18) {
        score += 30;
        factors.add('Teenage pregnancy (under 18)');
      } else if (form.ageYears! > 35) {
        score += 20;
        factors.add('Advanced maternal age (over 35)');
      }
    }

    // BMI risk
    if (form.bmi != null) {
      if (form.bmi! < 18.5) {
        score += 15;
        factors.add('Underweight (BMI < 18.5)');
      } else if (form.bmi! > 30) {
        score += 25;
        factors.add('Obese (BMI > 30)');
      }
    }

    // Medical conditions
    for (final condition in form.medicalConditions) {
      if (condition.status == 'active') {
        final conditionScore = _getConditionScore(condition.conditionName);
        score += conditionScore;
        factors.add('Active: ${condition.conditionName}');
      }
    }

    // Pregnancy history
    for (final history in form.pregnancyHistory) {
      if (history.outcome == 'stillbirth' || history.outcome == 'miscarriage') {
        score += 25;
        factors.add('Previous ${history.outcome}');
      }
    }

    // Determine level
    String level;
    if (score >= 50) {
      level = 'high';
    } else if (score >= 20) {
      level = 'medium';
    } else {
      level = 'low';
    }

    String note = _generateNote(level, factors);

    return RiskAssessment(
      level: level,
      score: score,
      factors: factors.isEmpty ? ['No significant risk factors identified'] : factors,
      note: note,
    );
  }

  static double _getConditionScore(String condition) {
    final highRisk = ['diabetes', 'hypertension', 'heart disease', 'kidney disease'];
    final mediumRisk = ['anemia', 'asthma', 'thyroid'];
    
    final lower = condition.toLowerCase();
    
    if (highRisk.any((h) => lower.contains(h))) return 25;
    if (mediumRisk.any((m) => lower.contains(m))) return 15;
    return 10;
  }

  static String _generateNote(String level, List<String> factors) {
    switch (level) {
      case 'high':
        return 'High-risk pregnancy detected. Close monitoring required. Consult with specialist.';
      case 'medium':
        return 'Moderate risk factors present. Regular monitoring recommended.';
      default:
        return 'No significant risk factors identified so far.';
    }
  }
}