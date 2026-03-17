import 'dart:math';

import '../models/add_mother_form_data.dart';

class RiskResult {
  const RiskResult({
    required this.riskLevel,
    required this.riskScore,
    required this.riskFactors,
    required this.riskNote,
  });

  final String riskLevel; // low | medium | high
  final int riskScore;
  final List<String> riskFactors;
  final String riskNote;
}

class PrenatalCheckupSnapshot {
  PrenatalCheckupSnapshot({
    this.systolic,
    this.diastolic,
    this.edemaLevel,
    this.fetalHeartBeat,
    this.fetalPosition,
    this.ageOfGestationWeeks,
  });

  final int? systolic;
  final int? diastolic;
  final String? edemaLevel;
  final int? fetalHeartBeat;
  final String? fetalPosition;
  final double? ageOfGestationWeeks;
}

class RiskAssessor {
  static RiskResult compute(
    AddMotherFormData form, {
    PrenatalCheckupSnapshot? latestCheckup,
    DateTime? now,
  }) {
    final DateTime refNow = now ?? DateTime.now();

    int total = 0;
    final List<_RiskFactor> factors = [];

    void addFactor(String description, int points) {
      total += points;
      factors.add(_RiskFactor(description: description, points: points));
    }

    // ------- RULE GROUP 1: Maternal Demographics -------
    final ageYears = form.ageInYears(onDate: refNow);
    if (ageYears != null) {
      if (ageYears < 18) addFactor('Teenage pregnancy', 2);
      if (ageYears >= 35) addFactor('Advanced maternal age', 2);
    }

    // ------- RULE GROUP 2: Vital Statistics -------
    final bmi = form.bmi;
    if (bmi != null) {
      if (bmi < 18.5) {
        addFactor('Underweight (BMI < 18.5)', 2);
      } else if (bmi >= 30) {
        addFactor('Obese (BMI ≥ 30)', 2);
      } else if (bmi >= 25 && bmi < 30) {
        addFactor('Overweight (BMI 25–29.9)', 1);
      }
    }

    // ------- RULE GROUP 3: Medical Conditions -------
    for (final cond in form.medicalConditions.where((c) => c.isActive)) {
      final name = cond.conditionName.trim().toLowerCase();
      switch (name) {
        case 'anemia':
          addFactor('Anemia', 2);
          break;
        case 'diabetes':
          addFactor('Diabetes', 3);
          break;
        case 'hypertension':
          addFactor('Hypertension', 3);
          break;
        case 'asthma':
          addFactor('Asthma', 1);
          break;
        case 'smoking':
          addFactor('Smoking', 2);
          break;
        case 'alcohol':
        case 'alcohol use':
          addFactor('Alcohol use', 2);
          break;
        case 'domestic violence':
          addFactor('Domestic violence', 3);
          break;
        default:
          addFactor('Other medical condition', 1);
      }
    }
    if (form.activeMedicalConditionCount >= 2) {
      addFactor('Multiple comorbidities', 1);
    }

    // ------- RULE GROUP 4: Allergies -------
    if (form.hasActiveAllergy) {
      addFactor('Active allergy', 1);
    }

    // ------- RULE GROUP 5: Pregnancy History -------
    for (final p in form.pastPregnancies) {
      final outcome = p.outcome.toLowerCase();
      if (outcome == 'miscarriage') addFactor('Previous miscarriage', 2);
      if (outcome == 'stillbirth') addFactor('Previous stillbirth', 3);
      if (outcome == 'ectopic') addFactor('Previous ectopic pregnancy', 3);
      if (outcome == 'abortion') addFactor('Previous abortion', 1);
    }
    if (form.totalEndedPregnancies >= 3) {
      addFactor('Three or more past pregnancies', 1);
    }

    // ------- RULE GROUP 6: Current Pregnancy (Prenatal Checkups) -------
    if (latestCheckup != null) {
      if ((latestCheckup.systolic ?? 0) >= 140 ||
          (latestCheckup.diastolic ?? 0) >= 90) {
        addFactor('High blood pressure', 3);
      }

      final edema = latestCheckup.edemaLevel?.toLowerCase();
      if (edema == 'mild') addFactor('Mild edema', 1);
      if (edema == 'moderate') addFactor('Moderate edema', 2);
      if (edema == 'severe') addFactor('Severe edema', 3);

      if (latestCheckup.fetalHeartBeat != null &&
          latestCheckup.fetalHeartBeat! <= 0) {
        addFactor('Absent/abnormal fetal heartbeat', 3);
      }

      if (latestCheckup.fetalPosition != null &&
          latestCheckup.fetalPosition!.toLowerCase() != 'vertex' &&
          latestCheckup.ageOfGestationWeeks != null &&
          latestCheckup.ageOfGestationWeeks! >= 36) {
        addFactor('Non-vertex fetal position (late pregnancy)', 1);
      }
    }

    // ------- RULE GROUP 7: Gestational Timing -------
    final aog = form.ageOfGestationWeeks(onDate: refNow);
    if (aog != null && aog >= 20 && latestCheckup == null) {
      addFactor('No prenatal checkup by 20 weeks', 2);
    }

    // TODO: Missed scheduled checkups requires schedule/attendance data.

    // ------- Final Level -------
    String level;
    if (total >= 6) {
      level = 'high';
    } else if (total >= 3) {
      level = 'medium';
    } else {
      level = 'low';
    }

    // ------- Risk note construction -------
    factors.sort((a, b) => b.points.compareTo(a.points));
    final top3 = factors.take(3).map((f) => f.description).toList();
    final note = _buildRiskNote(level, top3);

    return RiskResult(
      riskLevel: level,
      riskScore: total,
      riskFactors: factors.map((f) => f.description).toList(),
      riskNote: note,
    );
  }

  static String _buildRiskNote(String level, List<String> topFactors) {
    if (topFactors.isEmpty) {
      switch (level) {
        case 'medium':
          return 'Medium risk with observed factors.';
        case 'high':
          return 'High risk based on current assessment.';
        default:
          return 'Low risk based on current assessment.';
      }
    }

    if (topFactors.length == 1) {
      return '${_label(level)} due to ${topFactors.first}.';
    }
    if (topFactors.length == 2) {
      return '${_label(level)} due to ${topFactors[0]} and ${topFactors[1]}.';
    }
    return '${_label(level)} due to ${topFactors[0]}, ${topFactors[1]}, and ${topFactors[2]}.';
  }

  static String _label(String level) {
    switch (level) {
      case 'high':
        return 'High risk';
      case 'medium':
        return 'Medium risk';
      default:
        return 'Low risk';
    }
  }
}

class _RiskFactor {
  _RiskFactor({required this.description, required this.points});

  final String description;
  final int points;
}
