import '../models/add_mother_form_data.dart';

class RiskAssessment {
  const RiskAssessment({
    required this.level,
    required this.score,
    required this.factors,
    required this.note,
  });

  final String level; // low | medium | high
  final int score;
  final List<String> factors;
  final String note;
}

class RiskEngine {
  static RiskAssessment evaluate(AddMotherFormData form) {
    final List<_Factor> factors = [];
    int score = 0;

    void add(String label, int points) {
      factors.add(_Factor(label: label, points: points));
      score += points;
    }

    // ===== Maternal Age =====
    final age = form.ageYears;
    if (age != null) {
      if (age < 18) {
        add('Young maternal age (<18)', 2);
      } else if (age >= 35) {
        add('Advanced maternal age (≥35)', 2);
      }
    }

    // ===== BMI =====
    final bmi = form.bmi;
    if (bmi != null) {
      if (bmi < 18.5) {
        add('Underweight BMI (<18.5)', 2);
      } else if (bmi >= 25 && bmi < 30) {
        add('Overweight BMI (25–29.9)', 1);
      } else if (bmi >= 30) {
        add('Obese BMI (≥30)', 2);
      }
    }

    // ===== Medical Conditions (active only) =====
    int activeConditions = 0;
    for (final cond in form.medicalConditions) {
      if (!cond.isActive) continue;
      activeConditions++;
      final name = cond.conditionName.toLowerCase();
      int points = 1;
      if (name.contains('anemia'))
        points = 2;
      else if (name.contains('diabetes'))
        points = 3;
      else if (name.contains('hypertension'))
        points = 3;
      else if (name.contains('asthma'))
        points = 1;
      else if (name.contains('smoking'))
        points = 2;
      else if (name.contains('alcohol'))
        points = 2;
      else if (name.contains('domestic'))
        points = 3;
      else if (name.contains('violence'))
        points = 3;
      else if (name.contains('other'))
        points = 1;

      add('${cond.conditionName} (active)', points);
    }
    if (activeConditions >= 2) {
      add('Multiple comorbidities', 1);
    }

    // ===== Allergies =====
    final hasActiveAllergy = form.allergies.any((a) => a.isActive);
    if (hasActiveAllergy) {
      add('Active allergy reported', 1);
    }

    // ===== Pregnancy History =====
    for (final p in form.pregnancyHistory) {
      switch (p.outcome) {
        case 'miscarriage':
          add('History of miscarriage', 2);
          break;
        case 'stillbirth':
          add('History of stillbirth', 3);
          break;
        case 'ectopic':
          add('History of ectopic pregnancy', 3);
          break;
        case 'abortion':
          add('History of abortion', 1);
          break;
      }
    }
    final totalPregnancies = form.pregnancyHistory.length + 1;
    if (totalPregnancies >= 3) {
      add('Gravida ≥3 (multiple pregnancies)', 1);
    }

    // ===== Prenatal Checkup Factors =====
    final prenatal = form.firstPrenatal;

    if ((prenatal.bloodPressureSystolic ?? 0) >= 140 ||
        (prenatal.bloodPressureDiastolic ?? 0) >= 90) {
      add('Elevated blood pressure (≥140/90)', 3);
    }

    switch (prenatal.edema) {
      case 'mild':
        add('Mild edema', 1);
        break;
      case 'moderate':
        add('Moderate edema', 2);
        break;
      case 'severe':
        add('Severe edema', 3);
        break;
    }

    final fetalBeat = prenatal.fetalHeartBeat;
    final heartbeatAbnormal =
        prenatal.abnormalFetalHeartBeat ||
        (fetalBeat != null && (fetalBeat < 110 || fetalBeat > 160));
    if (heartbeatAbnormal) {
      add('Abnormal fetal heartbeat', 3);
    }

    final aog =
        prenatal.ageOfGestationWeeks ??
        _weeksBetween(form.lmp, prenatal.checkupDateTime);
    final position = (prenatal.fetalPosition ?? '').toLowerCase();
    final isLatePregnancy = aog != null && aog >= 28;
    final positionAbnormal =
        prenatal.abnormalFetalPosition ||
        (position.isNotEmpty &&
            position != 'cephalic' &&
            position != 'vertex' &&
            position != 'unknown');
    if (isLatePregnancy && positionAbnormal) {
      add('Abnormal fetal position (late pregnancy)', 1);
    }

    if (aog != null && aog > 20) {
      add('First prenatal visit after 20 weeks', 2);
    }

    if (prenatal.missedScheduledCheckups) {
      add('Missed scheduled prenatal checkups', 1);
    }

    // ===== Risk Level =====
    final level = score >= 6
        ? 'high'
        : score >= 3
        ? 'medium'
        : 'low';

    // ===== Risk Note =====
    final sorted = [...factors]..sort((a, b) => b.points.compareTo(a.points));
    final topNotes = sorted.take(3).map((f) => f.label).toList();
    final note = topNotes.isNotEmpty
        ? 'Key factors: ${topNotes.join(', ')}.'
        : 'No significant risk factors identified so far.';

    final factorLabels = factors.isEmpty
        ? ['No significant risk factors identified so far.']
        : factors.map((f) => f.label).toList();

    return RiskAssessment(
      level: level,
      score: score,
      factors: factorLabels,
      note: note,
    );
  }

  static double? _weeksBetween(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final days = end.difference(start).inDays;
    return double.parse((days / 7).toStringAsFixed(1));
  }
}

class _Factor {
  _Factor({required this.label, required this.points});
  final String label;
  final int points;
}
