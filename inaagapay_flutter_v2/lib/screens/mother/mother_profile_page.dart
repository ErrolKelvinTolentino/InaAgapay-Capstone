// lib/screens/mother/mother_profile_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/mother_profile_service.dart';
import '../../services/auth_storage.dart';
import '../midwife/ultrasound_analyzer_screen.dart';
import '../midwife/lab_test_analyzer_screen.dart';
import '../midwife/add_prenatal_checkup_screen.dart';
import '../../widgets/headline.dart';
import '../../widgets/page_title.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/overview_info.dart';
import '../../widgets/risk_panel.dart';
import '../../services/risk_engine.dart';
import '../../models/add_mother_form_data.dart';
import '../../widgets/full_screen_image_viewer.dart';

class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({super.key, required this.motherId});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _profileFuture;
  late TabController _tabController;

  // Sort states
  String _checkupSort = 'desc';
  String _ultrasoundSort = 'desc';
  String _labSort = 'desc';
  String _childQuery = '';
  String _childSort = 'recent';
  final Set<String> _expandedLabInsightAspects = <String>{};
  StateSetter? _recordDetailsModalSetState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
    });
  }

  Future<void> _logout() async {
    await AuthStorage.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _refreshRecordDetailsUi() {
    final modalSetState = _recordDetailsModalSetState;
    if (modalSetState != null) {
      modalSetState(() {});
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  // Navigate to ultrasound analyzer
  void _goToUltrasoundAnalyzer(Map<String, dynamic> pregnancy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UltrasoundAnalyzerScreen(
          motherId: widget.motherId,
          pregnancyId: pregnancy['pregnancy_id'],
        ),
      ),
    ).then((_) => _refresh());
  }

  // Navigate to lab test analyzer
  void _goToLabTestAnalyzer(Map<String, dynamic> pregnancy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabTestAnalyzerScreen(
          motherId: widget.motherId,
          pregnancyId: pregnancy['pregnancy_id'],
        ),
      ),
    ).then((_) => _refresh());
  }

  // Helper methods for formatting
  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return date.toString();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      final parsed = DateTime.tryParse(dateTime.toString());
      if (parsed == null) return dateTime.toString();
      return DateFormat('MMM d, yyyy h:mm a').format(parsed);
    } catch (e) {
      return dateTime.toString();
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    final str = value.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  String _formatOutcome(String? outcome) {
    if (outcome == null) return '-';
    switch (outcome.toLowerCase()) {
      case 'live_birth':
        return 'Live Birth';
      case 'stillbirth':
        return 'Stillbirth';
      case 'miscarriage':
        return 'Miscarriage';
      case 'abortion':
        return 'Abortion';
      case 'ectopic':
        return 'Ectopic';
      default:
        return outcome;
    }
  }

  // Build risk assessment from DB-stored values (preferred) with local engine fallback.
  // Reads `pregnancy_risk_level` from the pregnancies row and risk factors from
  // the most recent checkup that has stored risk_factors.
  RiskAssessment _buildRiskAssessmentFromDb(
      Map<String, dynamic> profile, Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return RiskAssessment(
        level: 'low',
        score: 0,
        factors: ['No ongoing pregnancy'],
        note: 'No ongoing pregnancy to assess.',
      );
    }

    //  1. Try to use the stored DB risk level 
    final dbLevel =
        (pregnancy['pregnancy_risk_level'] as String?)?.toLowerCase();

    //  2. Collect risk factors from stored checkup risk assessments 
    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final List<String> dbFactors = [];
    String? dbAiNote;

    // Walk checkups newest-first to find the most recent one with risk data
    final sortedCheckups = List<Map<String, dynamic>>.from(
        checkups.whereType<Map<String, dynamic>>())
      ..sort((a, b) {
        final da = DateTime.tryParse(a['checkup_datetime'] ?? '');
        final db = DateTime.tryParse(b['checkup_datetime'] ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da); // newest first
      });

    for (final checkup in sortedCheckups) {
      final factors = checkup['risk_factors'] as List?;
      if (factors != null && factors.isNotEmpty) {
        for (final f in factors) {
          final fMap = f as Map<String, dynamic>;
          final factor = fMap['factor']?.toString() ?? '';
          if (factor.isNotEmpty) dbFactors.add(factor);
        }
        // Also grab the AI response text if available
        final aiResp = checkup['risk_ai_response'] as Map<String, dynamic>?;
        if (aiResp != null) {
          final resp = aiResp['response']?.toString();
          if (resp != null && resp.isNotEmpty) dbAiNote = resp;
        }
        break; // Only use the most recent checkup's risk data
      }
    }

    //  3. Build baseline risk from DB level (if present) or fallback engine 
    String baselineLevel = 'low';
    double baselineScore = 5;
    String baselineNote = 'No significant risk factors identified.';
    final baselineFactors = <String>[];

    if (dbLevel != null && dbLevel.isNotEmpty) {
      baselineLevel =
          (dbLevel == 'high' || dbLevel == 'medium' || dbLevel == 'low')
              ? dbLevel
              : 'low';
      baselineScore = baselineLevel == 'high'
          ? 60
          : baselineLevel == 'medium'
              ? 30
              : 5;
      baselineFactors.addAll(
          dbFactors.isNotEmpty ? dbFactors : ['No risk factors recorded yet']);

      switch (baselineLevel) {
        case 'high':
          baselineNote = dbAiNote ??
              'High-risk pregnancy. Close monitoring required. Consult with specialist.';
          break;
        case 'medium':
          baselineNote = dbAiNote ??
              'Moderate risk factors present. Regular monitoring recommended.';
          break;
        default:
          baselineNote = dbAiNote ?? 'No significant risk factors identified.';
      }
    } else {
      final formData = AddMotherFormData();
      if (profile['birthdate'] != null) {
        try {
          formData.birthdate = DateTime.parse(profile['birthdate']);
        } catch (_) {}
      }
      if (profile['height'] != null && profile['weight'] != null) {
        formData.heightCm = (profile['height'] as num?)?.toDouble();
        formData.weightKg = (profile['weight'] as num?)?.toDouble();
      }
      final conditions = profile['medical_conditions'] as List? ?? [];
      for (final condition in conditions) {
        formData.medicalConditions.add(
          MedicalConditionEntry(
            conditionName: condition['condition_name'] ?? '',
            status: condition['status'] ?? 'active',
          )..diagnosisDate =
              DateTime.tryParse(condition['diagnosis_date'] ?? ''),
        );
      }
      final pastPregnancies = profile['past_pregnancies'] as List? ?? [];
      for (final pg in pastPregnancies) {
        final date = DateTime.tryParse(pg['outcome_date'] ?? '');
        if (date != null) {
          formData.pregnancyHistory.add(
            PregnancyHistoryEntry(
              outcome: pg['outcome'] ?? 'live_birth',
              outcomeDate: date,
            ),
          );
        }
      }

      final fallback = RiskEngine.evaluate(formData);
      baselineLevel = fallback.level;
      baselineScore = fallback.score;
      baselineNote = fallback.note;
      baselineFactors.addAll(fallback.factors);
    }

    //  4. Add latest ultrasound and lab-test signals to risk level 
    int supplementalScore = 0;
    bool hasSevereSupplementalSignal = false;
    final supplementalFactors = <String>[];

    final ultrasounds = (pregnancy['ultrasounds'] as List?) ?? const [];
    final latestUltrasound =
        _latestRecordByDate(ultrasounds, 'ultrasound_date');
    if (latestUltrasound != null) {
      final usDate = _formatDate(latestUltrasound['ultrasound_date']);
      final remarks = _formatValue(latestUltrasound['remarks']).toLowerCase();
      if (remarks != '-') {
        if (RegExp(r'critical|urgent|severe|fetal distress|placenta previa',
                caseSensitive: false)
            .hasMatch(remarks)) {
          supplementalScore += 3;
          hasSevereSupplementalSignal = true;
          supplementalFactors.add(
              'Ultrasound ($usDate): severe/urgent finding mentioned in remarks');
        } else if (RegExp(r'abnormal|concern|suspicious', caseSensitive: false)
            .hasMatch(remarks)) {
          supplementalScore += 2;
          supplementalFactors
              .add('Ultrasound ($usDate): abnormal or concerning finding');
        } else if (RegExp(r'follow|monitor|repeat', caseSensitive: false)
            .hasMatch(remarks)) {
          supplementalScore += 1;
          supplementalFactors
              .add('Ultrasound ($usDate): requires follow-up monitoring');
        }
      }
    }

    final labTests = (pregnancy['lab_tests'] as List?) ?? const [];
    final latestLab = _latestRecordByDate(labTests, 'lab_test_date');
    if (latestLab != null) {
      final labDate = _formatDate(latestLab['lab_test_date']);
      final split = _splitLabRemarksAndAi(latestLab['remarks']?.toString());
      final labText = '${split.cleanRemarks} ${split.extractedAi ?? ''}'
          .toLowerCase()
          .trim();

      if (labText.isNotEmpty) {
        if (RegExp(
          r'critical|abnormal \(review\)|positive \(review\)|outside normal range|higher than normal|lower than normal',
          caseSensitive: false,
        ).hasMatch(labText)) {
          supplementalScore += 2;
          supplementalFactors
              .add('Lab test ($labDate): review-level laboratory finding');
        } else if (RegExp(r'borderline|observe|monitor', caseSensitive: false)
            .hasMatch(labText)) {
          supplementalScore += 1;
          supplementalFactors
              .add('Lab test ($labDate): borderline/monitoring finding');
        }
      }
    }

    int rankOf(String level) {
      switch (level) {
        case 'high':
          return 2;
        case 'medium':
          return 1;
        default:
          return 0;
      }
    }

    String levelFromRank(int rank) {
      if (rank >= 2) return 'high';
      if (rank == 1) return 'medium';
      return 'low';
    }

    final supplementalRank =
        hasSevereSupplementalSignal || supplementalScore >= 3
            ? 2
            : supplementalScore >= 1
                ? 1
                : 0;

    final finalRank = rankOf(baselineLevel) >= supplementalRank
        ? rankOf(baselineLevel)
        : supplementalRank;
    final finalLevel = levelFromRank(finalRank);

    double finalScore = baselineScore + (supplementalScore * 8);
    if (finalLevel == 'high' && finalScore < 60) finalScore = 60;
    if (finalLevel == 'medium' && finalScore < 30) finalScore = 30;
    if (finalLevel == 'low' && finalScore < 5) finalScore = 5;
    if (finalScore > 95) finalScore = 95;

    final allFactors = <String>[];
    allFactors.addAll(baselineFactors);
    for (final f in supplementalFactors) {
      if (!allFactors.contains(f)) allFactors.add(f);
    }
    if (allFactors.isEmpty) {
      allFactors.add('No risk factors recorded yet');
    }

    var finalNote = baselineNote;
    if (supplementalFactors.isNotEmpty) {
      finalNote =
          '$baselineNote Latest ultrasound/lab records also influenced this risk level.';
    }

    return RiskAssessment(
      level: finalLevel,
      score: finalScore,
      factors: allFactors,
      note: finalNote,
    );
  }

  // AI Analysis Generators
  String _generatePrenatalAIInsights(Map<String, dynamic> checkup) {
    final bpSys = _toDouble(checkup['blood_pressure_systolic']);
    final bpDia = _toDouble(checkup['blood_pressure_diastolic']);
    final weight = _toDouble(checkup['checkup_weight']);
    final edemaRaw = _formatValue(checkup['edema']);
    final edema = edemaRaw.toLowerCase();
    final tdDose = _formatValue(checkup['td_vaccine_dose']);

    final fhrRaw = _formatValue(checkup['fetal_heart_beat']);
    final fhr = int.tryParse(fhrRaw);

    String overallAssessment =
        'Current prenatal checkup findings appear stable overall.';
    if (bpSys != null && bpDia != null && (bpSys >= 140 || bpDia >= 90)) {
      overallAssessment =
          'Blood pressure is elevated and needs closer monitoring for hypertensive disorders of pregnancy.';
    } else if (bpSys != null && bpDia != null && (bpSys < 90 || bpDia < 60)) {
      overallAssessment =
          'Blood pressure is lower than typical range; monitor hydration, symptoms, and follow-up trends.';
    } else if (fhr != null && (fhr < 120 || fhr > 160)) {
      overallAssessment =
          'Fetal heart rate is outside the usual expected range and should be reviewed clinically.';
    } else if (edema != '-' && edema != 'none') {
      overallAssessment =
          'Mild edema is noted; monitor progression and correlate with blood pressure and symptoms.';
    }

    final buffer = StringBuffer();
    buffer.write('OVERALL ASSESSMENT: $overallAssessment\n\n');

    buffer.write('KEY OBSERVATIONS:\n');

    if (bpSys != null && bpDia != null) {
      if (bpSys >= 140 || bpDia >= 90) {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [REVIEW].\n');
      } else if (bpSys < 90 || bpDia < 60) {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [MONITOR].\n');
      } else {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [WITHIN NORMAL LIMITS].\n');
      }
    } else {
      buffer.write(
          '- Maternal Vitals - Blood Pressure: Not documented in this record.\n');
    }

    if (weight != null) {
      buffer.write(
          '- Maternal Vitals - Weight: ${weight.toStringAsFixed(1)} kg.\n');
    }

    if (fhr != null) {
      if (fhr >= 120 && fhr <= 160) {
        buffer.write(
            '- Fetal Status - Heart Rate: $fhr bpm [WITHIN NORMAL LIMITS].\n');
      } else {
        buffer.write('- Fetal Status - Heart Rate: $fhr bpm [REVIEW].\n');
      }
    } else if (fhrRaw != '-') {
      buffer.write('- Fetal Status - Heart Rate: $fhrRaw [REVIEW MANUALLY].\n');
    }

    final fetalPosition = _formatValue(checkup['fetal_position']);
    if (fetalPosition != '-') {
      buffer.write('- Fetal Status - Position: $fetalPosition.\n');
    }

    if (edemaRaw != '-') {
      if (edema == 'none') {
        buffer.write('- Maternal Observation - Edema: None reported.\n');
      } else {
        buffer.write('- Maternal Observation - Edema: $edemaRaw [MONITOR].\n');
      }
    }

    if (tdDose != '-') {
      buffer.write('- Preventive Care - TD Vaccine: $tdDose documented.\n');
    }

    final nextSchedule = _formatDate(checkup['next_schedule']);
    if (nextSchedule != '-') {
      buffer.write('- Follow-up - Next Schedule: $nextSchedule.\n');
    }

    buffer.write('\nRECOMMENDATIONS:\n');
    buffer.write('- Continue scheduled prenatal follow-up visits.\n');
    buffer
        .write('- Monitor maternal warning signs and fetal movement daily.\n');
    if ((bpSys != null && bpDia != null && (bpSys >= 140 || bpDia >= 90)) ||
        (fhr != null && (fhr < 120 || fhr > 160))) {
      buffer.write(
          '- Prioritize clinician review for blood pressure and/or fetal heart findings.\n');
    }
    if (edema != '-' && edema != 'none') {
      buffer.write('- Reassess edema severity in next checkup.\n');
    }

    return buffer.toString().trim();
  }

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final buffer = StringBuffer();
    buffer.write('Ultrasound AI Insights:\n\n');

    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final date = _formatDate(ultrasound['ultrasound_date']);

    buffer.write('Ultrasound conducted on $date');

    final location = ultrasound['ultrasound_location'];
    if (location != null && location.toString().isNotEmpty) {
      buffer.write(' at $location');
    }

    final worker = ultrasound['health_worker_name'];
    if (worker != null && worker.toString().isNotEmpty) {
      buffer.write(' by $worker');
    }
    buffer.write(':\n\n');

    // Analyze remarks
    if (remarks.contains('normal') || remarks.contains('healthy')) {
      buffer.write(
          '**Normal Findings**: Ultrasound appears normal with healthy fetal development.\n\n');
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      buffer.write(
          '**Follow-up Recommended**: Some findings require additional observation.\n\n');
    } else if (remarks.contains('concern') || remarks.contains('abnormal')) {
      buffer.write(
          '**Further Evaluation Needed**: Discuss findings with healthcare provider.\n\n');
    } else {
      buffer.write(
          '**Diagnostic Information**: The ultrasound provides important diagnostic information.\n\n');
    }

        buffer.write('**Key Recommendations**:\n');
    buffer.write('- Discuss findings with your healthcare provider\n');
    buffer.write('- Continue all scheduled prenatal appointments\n');

    return buffer.toString();
  }

  ({String cleanRemarks, String? extractedAi}) _splitLabRemarksAndAi(
      String? rawRemarks) {
    final source = rawRemarks?.trim() ?? '';
    if (source.isEmpty) {
      return (cleanRemarks: '', extractedAi: null);
    }

    final marker = RegExp(r'\bAI\s*Analysis\s*:', caseSensitive: false);
    final match = marker.firstMatch(source);
    if (match == null) {
      return (cleanRemarks: source, extractedAi: null);
    }

    final notesPart = source.substring(0, match.start).trim();
    final aiPart = source.substring(match.end).trim();

    return (
      cleanRemarks: notesPart,
      extractedAi: aiPart.isEmpty ? null : aiPart,
    );
  }

  Map<String, dynamic>? _latestRecordByDate(List records, String dateField) {
    if (records.isEmpty) return null;
    final typed = List<Map<String, dynamic>>.from(
      records.whereType<Map<String, dynamic>>(),
    );
    if (typed.isEmpty) return null;

    typed.sort((a, b) {
      final da = _parseDateForSort(a[dateField]);
      final db = _parseDateForSort(b[dateField]);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return typed.first;
  }

  ({String level, String structuredText}) _buildUnifiedMaternalInsight(
      Map<String, dynamic> pregnancy) {
    final checkups = (pregnancy['checkups'] as List?) ?? const [];
    final ultrasounds = (pregnancy['ultrasounds'] as List?) ?? const [];
    final labTests = (pregnancy['lab_tests'] as List?) ?? const [];

    final latestCheckup = _latestRecordByDate(checkups, 'checkup_datetime');
    final latestUltrasound =
        _latestRecordByDate(ultrasounds, 'ultrasound_date');
    final latestLab = _latestRecordByDate(labTests, 'lab_test_date');

    final observations = <String>[];
    final recommendations = <String>[];
    int riskScore = 0;
    bool hasSevereSignal = false;

    if (latestCheckup != null) {
      final checkupDate = _formatDateTime(latestCheckup['checkup_datetime']);
      final bpSys = _toDouble(latestCheckup['blood_pressure_systolic']);
      final bpDia = _toDouble(latestCheckup['blood_pressure_diastolic']);
      if (bpSys != null && bpDia != null) {
        if (bpSys >= 160 || bpDia >= 110) {
          riskScore += 4;
          hasSevereSignal = true;
          observations.add(
              'Latest Checkup ($checkupDate): BP $bpSys/$bpDia mmHg is severely elevated.');
          recommendations.add(
              'Urgent clinician review is advised for severe blood pressure elevation.');
        } else if (bpSys >= 140 || bpDia >= 90) {
          riskScore += 3;
          observations.add(
              'Latest Checkup ($checkupDate): BP $bpSys/$bpDia mmHg is elevated.');
          recommendations.add(
              'Increase BP monitoring frequency and assess warning signs.');
        } else if (bpSys < 90 || bpDia < 60) {
          riskScore += 1;
          observations.add(
              'Latest Checkup ($checkupDate): BP $bpSys/$bpDia mmHg is lower than expected.');
          recommendations.add(
              'Review hydration status and monitor dizziness/syncope symptoms.');
        } else {
          observations.add(
              'Latest Checkup ($checkupDate): Blood pressure is within expected range.');
        }
      }

      final fhrRaw = _formatValue(latestCheckup['fetal_heart_beat']);
      final fhr = int.tryParse(fhrRaw);
      if (fhr != null) {
        if (fhr < 120 || fhr > 160) {
          riskScore += 2;
          observations.add(
              'Latest Checkup ($checkupDate): Fetal heart rate $fhr bpm is outside expected range.');
          recommendations.add(
              'Correlate fetal heart findings with repeat assessment and clinical exam.');
        } else {
          observations.add(
              'Latest Checkup ($checkupDate): Fetal heart rate $fhr bpm is within expected range.');
        }
      }

      final edema = _formatValue(latestCheckup['edema']).toLowerCase();
      if (edema != '-' && edema != 'none') {
        riskScore += 1;
        observations.add(
            'Latest Checkup ($checkupDate): Edema is reported (${_formatValue(latestCheckup['edema'])}).');
        recommendations.add('Track edema progression in succeeding checkups.');
      }
    } else {
      observations.add('No prenatal checkup records are currently available.');
      recommendations.add(
          'Schedule a prenatal checkup to refresh current maternal status.');
    }

    if (latestUltrasound != null) {
      final usDate = _formatDate(latestUltrasound['ultrasound_date']);
      final remarks = _formatValue(latestUltrasound['remarks']).toLowerCase();
      if (remarks != '-') {
        if (RegExp(r'abnormal|concern|urgent|critical', caseSensitive: false)
            .hasMatch(remarks)) {
          riskScore += 3;
          observations.add(
              'Latest Ultrasound ($usDate): Findings indicate concern/abnormality in remarks.');
          recommendations.add(
              'Review latest ultrasound report with obstetric interpretation.');
        } else if (RegExp(r'follow|monitor', caseSensitive: false)
            .hasMatch(remarks)) {
          riskScore += 1;
          observations.add(
              'Latest Ultrasound ($usDate): Follow-up monitoring is recommended.');
          recommendations
              .add('Maintain ultrasound follow-up schedule as advised.');
        } else if (RegExp(r'normal|healthy', caseSensitive: false)
            .hasMatch(remarks)) {
          observations.add(
              'Latest Ultrasound ($usDate): Remarks suggest stable/normal findings.');
        } else {
          observations.add(
              'Latest Ultrasound ($usDate): Report available; review detailed notes for context.');
        }
      }
    }

    if (latestLab != null) {
      final labDate = _formatDate(latestLab['lab_test_date']);
      final split = _splitLabRemarksAndAi(latestLab['remarks']?.toString());
      final labText = '${split.cleanRemarks} ${split.extractedAi ?? ''}'
          .toLowerCase()
          .trim();

      if (labText.isNotEmpty) {
        if (RegExp(
          r'critical|abnormal \(review\)|positive \(review\)|outside normal range|higher than normal|lower than normal',
          caseSensitive: false,
        ).hasMatch(labText)) {
          riskScore += 3;
          observations.add(
              'Latest Lab Test ($labDate): Review-level laboratory findings are present.');
          recommendations.add(
              'Prioritize clinical correlation of latest laboratory findings.');
        } else if (RegExp(r'borderline|observe|monitor', caseSensitive: false)
            .hasMatch(labText)) {
          riskScore += 1;
          observations.add(
              'Latest Lab Test ($labDate): Borderline/observe findings were noted.');
          recommendations
              .add('Trend repeat labs if symptoms persist or worsen.');
        } else if (RegExp(r'within normal limits|normal', caseSensitive: false)
            .hasMatch(labText)) {
          observations.add(
              'Latest Lab Test ($labDate): Findings are generally within normal limits.');
        } else {
          observations.add(
              'Latest Lab Test ($labDate): Result available; interpret with clinical context.');
        }
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
          'Continue routine prenatal surveillance and document new symptoms promptly.');
    }

    final level = hasSevereSignal || riskScore >= 6
        ? 'HIGH ALERT'
        : riskScore >= 3
            ? 'MODERATE ALERT'
            : 'STABLE';

    final overall = level == 'HIGH ALERT'
        ? 'High-priority review is advised based on the latest combined records (checkup, ultrasound, and lab test).'
        : level == 'MODERATE ALERT'
            ? 'Some risk signals are present across recent records and should be monitored closely.'
            : 'Latest combined records suggest a relatively stable maternal state at this time.';

    final buffer = StringBuffer();
    buffer.write('OVERALL ASSESSMENT: $overall\n\n');
    buffer.write('KEY OBSERVATIONS:\n');
    for (final item in observations) {
      buffer.write('- $item\n');
    }
    buffer.write('\nRECOMMENDATIONS:\n');
    for (final item in recommendations.take(4)) {
      buffer.write('- $item\n');
    }

    return (level: level, structuredText: buffer.toString().trim());
  }

  Widget _buildUnifiedMaternalInsightCard(Map<String, dynamic> pregnancy) {
    final unified = _buildUnifiedMaternalInsight(pregnancy);

    Color levelColor;
    IconData levelIcon;
    switch (unified.level) {
      case 'HIGH ALERT':
        levelColor = Colors.red;
        levelIcon = Icons.notification_important_rounded;
        break;
      case 'MODERATE ALERT':
        levelColor = Colors.orange.shade700;
        levelIcon = Icons.warning_amber_rounded;
        break;
      default:
        levelColor = Colors.green;
        levelIcon = Icons.verified_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Current Maternal AI Insight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: levelColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(levelIcon, size: 14, color: levelColor),
                    const SizedBox(width: 6),
                    Text(
                      unified.level,
                      style: TextStyle(
                        color: levelColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStructuredAiInsights(unified.structuredText),
        ],
      ),
    );
  }

// Show full screen image
  void _showFullScreenImage(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  String _normalizeMarkdownLine(String input) {
    var line = input;
    line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*(?:[-*]|-)\s+'), '');
    return line;
  }

  String _cleanResidualMarkdown(String input) {
    var text = input;
    text = text.replaceAll('**', '');
    text = text.replaceAll('##', '');
    text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
    return text;
  }

  List<TextSpan> _parseInlineMarkdown(String input) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int current = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > current) {
        spans.add(TextSpan(
          text: _cleanResidualMarkdown(input.substring(current, match.start)),
        ));
      }

      final boldText = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      current = match.end;
    }

    if (current < input.length) {
      spans.add(TextSpan(
        text: _cleanResidualMarkdown(input.substring(current)),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: _cleanResidualMarkdown(input)));
    }

    return spans;
  }

  Widget _buildFormattedAiText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final normalizedLine = _normalizeMarkdownLine(lines[i]);
      spans.addAll(_parseInlineMarkdown(normalizedLine));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style:
            const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
        children: spans,
      ),
    );
  }

  Map<String, List<String>> _extractAiSections(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => _cleanResidualMarkdown(_normalizeMarkdownLine(l)).trim())
        .toList();

    final Map<String, List<String>> sections = {};
    String currentSection = 'Summary';
    sections[currentSection] = [];

    final headingPattern = RegExp(
      r'^(?:\d+\.\s*)?(RELEVANCE CHECK|RELEVANCE REASON|LABORATORY RESULTS|ABNORMAL FINDINGS|NORMAL RANGES|REFERENCE RANGES|OVERALL ASSESSMENT|RECOMMENDATIONS|KEY OBSERVATIONS)\s*:\s*(.*)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.toUpperCase() == 'COMPREHENSIVE LABORATORY ANALYSIS') continue;
      if (RegExp(r'^[-_=]{2,}$').hasMatch(line.replaceAll(' ', ''))) {
        continue;
      }

      final heading = headingPattern.firstMatch(line);
      if (heading != null) {
        currentSection = heading.group(1)!.toUpperCase();
        if (currentSection == 'REFERENCE RANGES') {
          currentSection = 'NORMAL RANGES';
        }
        sections.putIfAbsent(currentSection, () => []);
        final inlineContent = heading.group(2)?.trim() ?? '';
        if (inlineContent.isNotEmpty) {
          sections[currentSection]!.add(inlineContent);
        }
        continue;
      }

      sections.putIfAbsent(currentSection, () => []);
      sections[currentSection]!.add(line);
    }

    sections.removeWhere((_, value) => value.isEmpty);
    return sections;
  }

  bool _isConcerningAnalyte(String text) {
    final t = text.toLowerCase();
    return RegExp(
      r'protein|glucose|ketone|nitrite|leukocyte|blood|pus|bacteria|bilirubin|hiv|hbsag|vdrl|rpr|syphilis|infection|pathogen',
      caseSensitive: false,
    ).hasMatch(t);
  }

  String _classifyLabStatus(String testName, String rawValue) {
    final test = testName.toLowerCase();
    final value = rawValue.toLowerCase();
    final merged = '$test $value';

    final hasWithinNormal = RegExp(
      r'within normal limits|within normal range|normal range|wnl',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasWithinNormal) return 'WITHIN NORMAL LIMITS';

    final isColorFinding = test.contains('color') || test.contains('colour');
    if (isColorFinding) {
      if (RegExp(r'\byellow\b|\bstraw\b|\bpale\b|\bclear\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'WITHIN NORMAL LIMITS';
      }
      if (RegExp(r'\bdark\b|\bamber\b|\bbrown\b|\bred\b|\bbloody\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'ABNORMAL (REVIEW)';
      }
      return 'OBSERVE';
    }

    if (RegExp(r'\bpositive\b', caseSensitive: false).hasMatch(value)) {
      if (_isConcerningAnalyte(merged)) return 'POSITIVE (REVIEW)';
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'POSITIVE (EXPECTED)';
      }
      return 'POSITIVE';
    }

    if (RegExp(r'\bnegative\b', caseSensitive: false).hasMatch(value)) {
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'NEGATIVE (REVIEW)';
      }
      if (_isConcerningAnalyte(merged)) return 'NEGATIVE (REASSURING)';
      return 'NEGATIVE';
    }

    if (RegExp(r'\btrace\b|\bfew\b|\bslight\b|\bmild\b|\bborderline\b',
            caseSensitive: false)
        .hasMatch(value)) {
      return 'BORDERLINE';
    }

    if (RegExp(
      r'\babnormal\b|\bcritical\b|outside normal range|higher than normal|lower than normal|\belevated\b|\bdecreased\b|\bincreased\b|!',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'ABNORMAL (REVIEW)';
    }

    if (RegExp(r'\bnormal\b', caseSensitive: false).hasMatch(value)) {
      return 'NORMAL';
    }

    return 'OBSERVE';
  }

  bool _isConcerningStatus(String status) {
    final s = status.toUpperCase();
    return s.contains('REVIEW') || s == 'ABNORMAL';
  }

  bool _isCautionStatus(String status) {
    final s = status.toUpperCase();
    return s == 'OBSERVE' || s == 'BORDERLINE' || s == 'POSITIVE';
  }

  Color _statusChipBackground(String status) {
    if (_isConcerningStatus(status)) return Colors.red.shade50;
    if (_isCautionStatus(status)) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _statusChipBorder(String status) {
    if (_isConcerningStatus(status)) return Colors.red.shade200;
    if (_isCautionStatus(status)) return Colors.orange.shade200;
    return Colors.green.shade200;
  }

  Color _statusChipTextColor(String status) {
    if (_isConcerningStatus(status)) return Colors.red;
    if (_isCautionStatus(status)) return Colors.orange.shade800;
    return Colors.green;
  }

  String _statusMeaning(String status) {
    switch (status.toUpperCase()) {
      case 'WITHIN NORMAL LIMITS':
        return 'Consistent with expected findings for this test.';
      case 'NORMAL':
        return 'Reported as normal for this parameter.';
      case 'ABNORMAL (REVIEW)':
      case 'ABNORMAL':
        return 'May need clinician review with symptoms and history.';
      case 'BORDERLINE':
        return 'Near threshold. Monitor trends and correlate clinically.';
      case 'OBSERVE':
        return 'Not clearly high-risk. Observe and compare with references.';
      case 'POSITIVE (REVIEW)':
        return 'Positive finding that may be clinically significant.';
      case 'POSITIVE (EXPECTED)':
        return 'Positive finding can be expected for this test context.';
      case 'NEGATIVE (REASSURING)':
        return 'No concerning marker detected for this parameter.';
      case 'NEGATIVE (REVIEW)':
        return 'Negative may be unexpected for this context; verify clinically.';
      case 'POSITIVE':
      case 'NEGATIVE':
        return 'Interpret this result based on the specific test context.';
      default:
        return 'Interpret this result together with reference ranges and overall assessment.';
    }
  }

  ({String testName, String value, String status}) _parseLabResultLine(
      String line) {
    final cleaned =
        _safeText(line).replaceFirst(RegExp(r'^[-\-*]\s*'), '').trim();
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex == -1) {
      return (testName: cleaned, value: '', status: 'UNKNOWN');
    }

    final testName = cleaned.substring(0, colonIndex).trim();
    final rawValue = _safeText(cleaned.substring(colonIndex + 1)).trim();
    final status = _classifyLabStatus(testName, rawValue);

    final value = rawValue
      .replaceAll('!', '')
        .replaceAll(RegExp(r'\bABNORMAL\b', caseSensitive: false), '')
        .trim();

    return (
      testName: _stripDecorativeDashes(testName),
      value: _stripDecorativeDashes(value),
      status: status
    );
  }

  String _safeText(Object? value) => value?.toString() ?? '';

  String _stripDecorativeDashes(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^[-_=]{2,}$').hasMatch(trimmed)) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'\s+--+\s+'), ' ').trim();
  }

  String _normalizeAspectKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _lineMatchesAspect(String line, String aspect) {
    final a = _normalizeAspectKey(_safeText(aspect));
    final l = _normalizeAspectKey(_safeText(line));
    return a.isNotEmpty && l.contains(a);
  }

  String _buildAspectDetails(
      String aspect, List<String> abnormalLines, List<String> rangeLines) {
    final matches = <String>[];
    for (final line in abnormalLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add(line);
      }
    }
    for (final line in rangeLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add('Reference: $line');
      }
    }
    return matches.join('\n\n').trim();
  }

  Widget _buildLabResultsSummaryCard(Map<String, List<String>> sections) {
    final labLines = sections['LABORATORY RESULTS'] ?? const <String>[];
    final abnormalLines = sections['ABNORMAL FINDINGS'] ?? const <String>[];
    final rangeLines = sections['NORMAL RANGES'] ?? const <String>[];

    final rows = labLines
        .map(_parseLabResultLine)
        .where((r) => r.testName.isNotEmpty && r.status != 'UNKNOWN')
        .toList();

    if (rows.isEmpty) {
      return _buildAiSectionCard('LABORATORY RESULTS', labLines);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science_outlined,
                  size: 18, color: AppColors.brandPrimary),
              SizedBox(width: 8),
              Text(
                'Laboratory Results',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Status guide: REVIEW = needs clinician review, BORDERLINE/OBSERVE = monitor and correlate, WITHIN NORMAL LIMITS = reassuring in context.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final details = _buildAspectDetails(
              row.testName,
              abnormalLines,
              rangeLines,
            );
            final aspectKey = _normalizeAspectKey(row.testName);
            final isExpanded = _expandedLabInsightAspects.contains(aspectKey);
            final hasDetails = details.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.testName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          onPressed: hasDetails
                              ? () {
                                  if (isExpanded) {
                                    _expandedLabInsightAspects
                                        .remove(aspectKey);
                                  } else {
                                    _expandedLabInsightAspects.add(aspectKey);
                                  }
                                  _refreshRecordDetailsUi();
                                }
                              : null,
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusChipBackground(row.status),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _statusChipBorder(row.status),
                          ),
                        ),
                        child: Text(
                          row.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusChipTextColor(row.status),
                          ),
                        ),
                      ),
                      if (row.value.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            row.value,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusMeaning(row.status),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (isExpanded && hasDetails)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildFormattedAiText(details),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _friendlyAiSectionTitle(String title) {
    switch (title) {
      case 'LABORATORY RESULTS':
        return 'Laboratory Results';
      case 'ABNORMAL FINDINGS':
        return 'Abnormal Findings';
      case 'NORMAL RANGES':
        return 'Reference Ranges';
      case 'OVERALL ASSESSMENT':
        return 'Overall Assessment';
      case 'RECOMMENDATIONS':
        return 'Recommendations';
      case 'RELEVANCE CHECK':
        return 'Relevance Check';
      case 'RELEVANCE REASON':
        return 'Relevance Reason';
      case 'KEY OBSERVATIONS':
        return 'Key Observations';
      default:
        return title
            .split(' ')
            .map(
                (w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  Widget _buildAiSectionCard(String title, List<String> lines) {
    final safeTitle = _safeText(title).toUpperCase();
    final isAbnormal = safeTitle.contains('ABNORMAL');
    final isRecommendation = safeTitle.contains('RECOMMENDATION');
    final isAssessment = safeTitle.contains('ASSESSMENT');

    final Color accent = isAbnormal
        ? Colors.red
        : isRecommendation
            ? Colors.blue
            : isAssessment
                ? Colors.deepPurple
                : AppColors.brandPrimary;

    final IconData icon = isAbnormal
        ? Icons.warning_amber_rounded
        : isRecommendation
            ? Icons.lightbulb_outline
            : isAssessment
                ? Icons.health_and_safety_outlined
                : Icons.article_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _friendlyAiSectionTitle(safeTitle),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (safeTitle == 'LABORATORY RESULTS')
            _buildLabResultRows(lines)
          else
            ...lines.map((line) {
              final cleaned =
                  line.replaceFirst(RegExp(r'^[-\-*]\s*'), '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: _buildFormattedAiText(cleaned)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLabResultRows(List<String> lines) {
    return Column(
      children: lines.map((line) {
        final parsed = _parseLabResultLine(line);
        final concerning = _isConcerningStatus(parsed.status);
        final caution = _isCautionStatus(parsed.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: concerning
                ? Colors.red.shade50
                : caution
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: concerning
                  ? Colors.red.shade200
                  : caution
                      ? Colors.orange.shade200
                      : Colors.green.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.testName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (parsed.value.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        parsed.value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _statusMeaning(parsed.status),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: concerning
                      ? Colors.red
                      : caution
                          ? Colors.orange.shade700
                          : Colors.green,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  parsed.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStructuredAiInsights(String text) {
    final sections = _extractAiSections(text);
    if (sections.isEmpty) return _buildFormattedAiText(text);

    const sectionOrder = [
      'OVERALL ASSESSMENT',
      'LABORATORY RESULTS',
      'ABNORMAL FINDINGS',
      'NORMAL RANGES',
      'KEY OBSERVATIONS',
      'RECOMMENDATIONS',
      'SUMMARY',
    ];

    final orderedEntries = <MapEntry<String, List<String>>>[];
    for (final key in sectionOrder) {
      if (sections.containsKey(key)) {
        orderedEntries.add(MapEntry(key, sections[key]!));
      }
    }
    for (final entry in sections.entries) {
      if (!sectionOrder.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    final widgets = <Widget>[];
    for (final entry in orderedEntries) {
      if (entry.key == 'RELEVANCE CHECK' || entry.key == 'RELEVANCE REASON') {
        continue;
      }

      if (entry.key == 'LABORATORY RESULTS') {
        widgets.add(_buildLabResultsSummaryCard(sections));
        continue;
      }

      if (entry.key == 'ABNORMAL FINDINGS' || entry.key == 'NORMAL RANGES') {
        continue;
      }

      widgets.add(_buildAiSectionCard(entry.key, entry.value));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Show record details modal
  void _showRecordDetails({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    List<String>? imageUrls,
    String? aiAnalysis,
    bool useStructuredAiInsights = false,
  }) {
    _expandedLabInsightAspects.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, modalSetState) {
          _recordDetailsModalSetState = modalSetState;
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: AppColors.brandPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (subtitle != null && subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Image Gallery if available
                        if (imageUrls != null && imageUrls.isNotEmpty) ...[
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () =>
                                      _showFullScreenImage(imageUrls, index),
                                  child: Container(
                                    width: 200,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            imageUrls[index],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: AppColors.bgSecondary,
                                              child: const Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.broken_image,
                                                        size: 32,
                                                        color: Colors.grey),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      'Image not available',
                                                      style: TextStyle(
                                                          fontSize: 10),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return Container(
                                                color: AppColors.bgSecondary,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            AppColors
                                                                .brandPrimary),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          // Image counter overlay
                                          if (imageUrls.length > 1 &&
                                              index == 0)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '+${imageUrls.length - 1} more',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Details
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: Column(
                            children: rows
                                .map((entry) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              entry.key,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),

                        // AI Analysis if available
                        if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          if (useStructuredAiInsights)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.borderPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgSecondary,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.medical_information,
                                          color: AppColors.brandPrimary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Clinical Assessment',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStructuredAiInsights(aiAnalysis),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFF7E57C2)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.psychology_rounded,
                                          color: const Color(0xFF7E57C2),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'AI-Powered Insights',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF5E35B1),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    aiAnalysis,
                                    style: const TextStyle(
                                        fontSize: 13, height: 1.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Note: This is AI-generated analysis for informational purposes only.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _recordDetailsModalSetState = null;
      _expandedLabInsightAspects.clear();
    });
  }

  // Show conclude pregnancy dialog
  Future<void> _showConcludePregnancyDialog(
      Map<String, dynamic> pregnancy) async {
    final int fetalCount = pregnancy['fetal_count'] as int? ?? 1;

    List<String> outcomes = List.filled(fetalCount, 'live_birth');
    List<DateTime> outcomeDates = List.filled(fetalCount, DateTime.now());
    List<DateTime?> deliveryDates = List.filled(fetalCount, null);
    List<String?> placesOfDelivery = List.filled(fetalCount, null);
    List<String?> deliveryMethods = List.filled(fetalCount, null);

    double? gestationalAge;
    final lmpDate = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
    final gestAgeController = TextEditingController();
    final placeControllers =
        List.generate(fetalCount, (_) => TextEditingController());

    if (lmpDate != null) {
      final weeks = DateTime.now().difference(lmpDate).inDays / 7;
      gestationalAge = double.parse(weeks.toStringAsFixed(1));
      gestAgeController.text = gestationalAge.toString();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                        top: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child:
                                    const Icon(Icons.flag, color: Colors.red),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Conclude Pregnancy',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          for (int i = 0; i < fetalCount; i++) ...[
                            if (fetalCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Fetus ${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: outcomes[i],
                                decoration: const InputDecoration(
                                  labelText: 'Outcome',
                                  border: InputBorder.none,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'live_birth',
                                      child: Text('Live Birth')),
                                  DropdownMenuItem(
                                      value: 'stillbirth',
                                      child: Text('Stillbirth')),
                                  DropdownMenuItem(
                                      value: 'miscarriage',
                                      child: Text('Miscarriage')),
                                  DropdownMenuItem(
                                      value: 'abortion',
                                      child: Text('Abortion')),
                                  DropdownMenuItem(
                                      value: 'ectopic', child: Text('Ectopic')),
                                ],
                                onChanged: (v) => setModal(
                                    () => outcomes[i] = v ?? outcomes[i]),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: outcomeDates[i],
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModal(() {
                                    outcomeDates[i] = picked;
                                    if (outcomes[i] == 'live_birth' ||
                                        outcomes[i] == 'stillbirth') {
                                      deliveryDates[i] = picked;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 20,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Outcome Date',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMMM d, yyyy')
                                                .format(outcomeDates[i]),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down,
                                        color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                            if (outcomes[i] == 'live_birth' ||
                                outcomes[i] == 'stillbirth') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: placeControllers[i],
                                decoration: InputDecoration(
                                  labelText: 'Place of Delivery',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.bgSecondary,
                                ),
                                onChanged: (v) => placesOfDelivery[i] = v,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: deliveryMethods[i],
                                  decoration: const InputDecoration(
                                    labelText: 'Delivery Method',
                                    border: InputBorder.none,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'NSD',
                                        child: Text(
                                            'Normal Spontaneous Delivery')),
                                    DropdownMenuItem(
                                        value: 'CS',
                                        child: Text('Cesarean Section')),
                                    DropdownMenuItem(
                                        value: 'Instrumental',
                                        child: Text('Instrumental')),
                                  ],
                                  onChanged: (v) =>
                                      setModal(() => deliveryMethods[i] = v),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (i < fetalCount - 1) const Divider(height: 24),
                          ],
                          TextField(
                            controller: gestAgeController,
                            decoration: InputDecoration(
                              labelText: 'Gestational Age at End (weeks)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.bgSecondary,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) =>
                                gestationalAge = double.tryParse(v),
                          ),
                          const SizedBox(height: 24),
                          MainButton(
                            label: 'Conclude Pregnancy',
                            onPressed: () async {
                              for (int i = 0; i < fetalCount; i++) {
                                if (outcomes[i] == 'live_birth' ||
                                    outcomes[i] == 'stillbirth') {
                                  if (deliveryMethods[i] == null) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Please select delivery method for Fetus ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }
                                }
                              }

                              final fetalOutcomes = <Map<String, dynamic>>[];
                              for (int i = 0; i < fetalCount; i++) {
                                fetalOutcomes.add({
                                  'fetus_number': i + 1,
                                  'outcome': outcomes[i],
                                  'outcome_date': outcomeDates[i]
                                      .toIso8601String()
                                      .split('T')[0],
                                  'delivery_date': deliveryDates[i]
                                      ?.toIso8601String()
                                      .split('T')[0],
                                  'place_of_delivery': placesOfDelivery[i] ??
                                      placeControllers[i].text,
                                  'delivery_method': deliveryMethods[i],
                                });
                              }

                              final success =
                                  await MotherProfileService.concludePregnancy(
                                pregnancy['pregnancy_id'],
                                gestationalAge,
                                fetalOutcomes,
                              );

                              if (success && mounted) {
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Pregnancy concluded successfully')),
                                );
                                _refresh();
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Failed to conclude pregnancy')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    gestAgeController.dispose();
    for (final pc in placeControllers) {
      pc.dispose();
    }
  }

  // Start new pregnancy
  Future<void> _startNewPregnancy() async {
    DateTime? lmp;
    DateTime? edd;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PageTitle(
                title: 'Start New Pregnancy',
                leadingIcon: Icons.pregnant_woman,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    lmp = picked;
                    edd = picked.add(const Duration(days: 280));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Menstrual Period',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lmp == null
                                  ? 'Select date'
                                  : DateFormat('MMMM d, yyyy').format(lmp!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (lmp != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          color: AppColors.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated Due Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMMM d, yyyy').format(edd!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                      showIcons: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MainButton(
                      label: 'Start',
                      onPressed: lmp == null
                          ? null
                          : () async {
                              final success =
                                  await MotherProfileService.startNewPregnancy(
                                widget.motherId,
                                lmp!,
                                edd!,
                              );
                              if (success && mounted) {
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('New pregnancy started')),
                                );
                                _refresh();
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                    ),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Headline(text: 'Error Loading Profile'),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          MainButton(
                            label: 'Retry',
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(child: Text('No profile data found')),
                ),
              ],
            );
          }

          final profile = snapshot.data!;
          final currentPregnancy =
              profile['current_pregnancy'] as Map<String, dynamic>?;
          final pastPregnancies = profile['past_pregnancies'] as List? ?? [];
          final medicalConditions =
              profile['medical_conditions'] as List? ?? [];
          final allergies = profile['allergies'] as List? ?? [];
          final emergencyContacts =
              profile['emergency_contacts'] as List? ?? [];
          final children = profile['children'] as List? ?? [];

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.brandPrimary,
                          labelColor: AppColors.brandPrimary,
                          unselectedLabelColor: AppColors.textSecondary,
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Current'),
                            Tab(text: 'History'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // OVERVIEW TAB
                            _buildOverviewTab(
                                profile,
                                medicalConditions,
                                allergies,
                                emergencyContacts,
                                children,
                                currentPregnancy),

                            // CURRENT PREGNANCY TAB
                            _buildCurrentPregnancyTab(
                                profile, currentPregnancy),

                            // HISTORY TAB
                            _buildHistoryTab(pastPregnancies),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),

              // Logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.favorite,
                      color: AppColors.brandPrimary,
                      size: 30),
                ),
              ),

              // Title
              const Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandText,
                  letterSpacing: 0.4,
                ),
              ),

              const Spacer(),

              // Notifications
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  // Handle notifications
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(width: 14),

              // Avatar with profile menu
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          /// FULLSCREEN OVERLAY
          GestureDetector(
            onTap: () => entry.remove(),
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          /// PROFILE MENU
          Positioned(
            top: 90,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'View Profile',
                      onTap: () {
                        entry.remove();
                        // Already on profile
                      },
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _MenuItem(
                      icon: Icons.help_outline,
                      label: 'Help',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/help');
                      },
                    ),
                    const Divider(height: 8),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      isDanger: true,
                      onTap: () {
                        entry.remove();
                        _confirmLogout(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      showIcons: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MainButton(
                      label: 'Log out',
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // OVERVIEW TAB
  Widget _buildOverviewTab(
    Map<String, dynamic> profile,
    List medicalConditions,
    List allergies,
    List emergencyContacts,
    List children,
    Map<String, dynamic>? currentPregnancy,
  ) {
    final riskAssessment =
        _buildRiskAssessmentFromDb(profile, currentPregnancy);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile['full_name']
                                ?.toString()
                                .substring(0, 1)
                                .toUpperCase() ??
                            'M',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['full_name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                profile['email_address'] ?? '-',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              profile['phone_number'] ?? '-',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: OverviewInfo(
                    value: profile['birthdate'] != null
                        ? DateTime.now()
                                .difference(
                                    DateTime.parse(profile['birthdate']))
                                .inDays ~/
                            365
                        : 0,
                    label: 'Age',
                    icon: Icons.cake,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OverviewInfo(
                    value: profile['children_count'] ?? 0,
                    label: 'Children',
                    icon: Icons.child_care,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OverviewInfo(
                    value: profile['pregnancies_count'] ?? 0,
                    label: 'Pregnancies',
                    icon: Icons.pregnant_woman,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Risk Panel
            if (currentPregnancy != null) RiskPanel(assessment: riskAssessment),

            const SizedBox(height: 16),
            const SizedBox(height: 16),

            // Personal Information
            _buildExpandableSection(
              'Personal Information',
              Icons.person_outline,
              [
                _buildInfoRow('Birthdate', _formatDate(profile['birthdate'])),
                _buildInfoRow('Blood Type', profile['blood_type'] ?? '-'),
                _buildInfoRow(
                    'Height',
                    profile['height'] != null
                        ? '${profile['height']} cm'
                        : '-'),
                _buildInfoRow(
                    'Weight',
                    profile['weight'] != null
                        ? '${profile['weight']} kg'
                        : '-'),
              ],
            ),

            const SizedBox(height: 12),

            // Address
            _buildExpandableSection(
              'Address',
              Icons.home_outlined,
              [
                _buildInfoRow('House No.', profile['house_number'] ?? '-'),
                _buildInfoRow('Street', profile['street'] ?? '-'),
                _buildInfoRow('Barangay', profile['barangay'] ?? '-'),
                _buildInfoRow('City', profile['city_municipality'] ?? '-'),
                _buildInfoRow('Province', profile['province'] ?? '-'),
              ],
            ),

            const SizedBox(height: 12),

            // Medical Conditions
            _buildExpandableSection(
              'Medical Conditions',
              Icons.medical_services_outlined,
              medicalConditions.isEmpty
                  ? [const Text('No medical conditions recorded')]
                  : medicalConditions
                      .map<Widget>((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: c['status'] == 'active'
                                        ? Colors.orange
                                        : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['condition_name'] ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${c['status'] ?? 'active'} - ${_formatDate(c['diagnosis_date'])}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
            ),

            const SizedBox(height: 12),

            // Allergies
            _buildExpandableSection(
              'Allergies',
              Icons.warning_amber_outlined,
              allergies.isEmpty
                  ? [const Text('No allergies recorded')]
                  : allergies
                      .map<Widget>((a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: a['status'] == 'active'
                                        ? Colors.orange
                                        : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['allergen'] ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${a['status'] ?? 'active'} - ${_formatDate(a['diagnosis_date'])}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
            ),

            const SizedBox(height: 12),

            // Emergency Contacts
            _buildExpandableSection(
              'Emergency Contacts',
              Icons.contacts_outlined,
              emergencyContacts.isEmpty
                  ? [const Text('No emergency contacts')]
                  : emergencyContacts
                      .map<Widget>((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    c['first_name'],
                                    c['middle_name'],
                                    c['last_name'],
                                    c['extension_name'],
                                  ].where((e) => e != null).join(' '),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(c['phone_number'] ?? '-'),
                                  ],
                                ),
                                if (c['affiliation'] != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.business,
                                          size: 14,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(c['affiliation']),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
            ),

            const SizedBox(height: 12),

            // Children
            _buildExpandableSection(
              'Children',
              Icons.child_care_outlined,
              [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search children...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.bgSecondary,
                  ),
                  onChanged: (v) => setState(() => _childQuery = v),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _childSort,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'recent', child: Text('Most recent')),
                      DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                    ],
                    onChanged: (v) =>
                        setState(() => _childSort = v ?? 'recent'),
                  ),
                ),
                const SizedBox(height: 12),
                ..._filterAndSortChildren(children).map((c) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.brandPrimary.withValues(alpha: 0.1),
                          child: Text(
                            c['first_name']
                                    ?.toString()
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'C',
                            style: TextStyle(color: AppColors.brandPrimary),
                          ),
                        ),
                        title: Text([
                          c['first_name'],
                          c['middle_name'],
                          c['last_name'],
                        ].where((e) => e != null).join(' ')),
                        subtitle: Text('Added: ${_formatDate(c['added_at'])}'),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                        onTap: () {
                          // Navigate to child profile (to be implemented)
                        },
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CURRENT PREGNANCY TAB
  Widget _buildCurrentPregnancyTab(
      Map<String, dynamic> profile, Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pregnant_woman,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Ongoing Pregnancy'),
              const SizedBox(height: 8),
              const Text(
                'Start a new pregnancy to begin tracking',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MainButton(
                label: 'Start New Pregnancy',
                onPressed: _startNewPregnancy,
              ),
            ],
          ),
        ),
      );
    }

    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final ultrasounds = (pregnancy['ultrasounds'] as List?) ?? [];
    final labTests = (pregnancy['lab_tests'] as List?) ?? [];

    // Sort checkups
    final sortedCheckups = List<Map<String, dynamic>>.from(checkups);
    sortedCheckups.sort((a, b) {
      final dateA = DateTime.tryParse(a['checkup_datetime'] ?? '');
      final dateB = DateTime.tryParse(b['checkup_datetime'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return _checkupSort == 'desc'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    // Calculate gestation
    final lmp = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
    final edd = DateTime.tryParse(pregnancy['expected_date_of_delivery'] ?? '');
    final now = DateTime.now();
    final gestWeeks =
        lmp != null ? (now.difference(lmp).inDays / 7).floor() : null;
    final daysToEdd = edd != null ? edd.difference(now).inDays : null;

    // Generate risk assessment
    final riskAssessment = _buildRiskAssessmentFromDb(profile, pregnancy);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk Panel
            RiskPanel(assessment: riskAssessment),

            const SizedBox(height: 16),

            // Unified AI insight from latest checkup, ultrasound, and lab test records.
            _buildUnifiedMaternalInsightCard(pregnancy),

            const SizedBox(height: 16),

            // Quick Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              gestWeeks != null ? '$gestWeeks' : '-',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const Text(
                              'Weeks',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: AppColors.borderPrimary,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              daysToEdd != null ? daysToEdd.toString() : '-',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const Text(
                              'Days to EDD',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Checkups',
                            sortedCheckups.length.toString(), Icons.fact_check),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Risk Level',
                          pregnancy['pregnancy_risk_level']
                                  ?.toString()
                                  .toUpperCase() ??
                              '-',
                          Icons.warning,
                          color: pregnancy['pregnancy_risk_level'] == 'high'
                              ? Colors.red
                              : pregnancy['pregnancy_risk_level'] == 'medium'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Add Checkup',
                          Icons.add,
                          AppColors.brandPrimary,
                          () async {
                            final pregnancyId = pregnancy['pregnancy_id'];
                            if (pregnancyId == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPrenatalCheckupScreen(
                                  motherId: widget.motherId,
                                  pregnancyId: pregnancyId as int,
                                  lmp: DateTime.tryParse(
                                      pregnancy['last_menstrual_period'] ?? ''),
                                  motherWeight: _toDouble(profile['weight']),
                                ),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Ultrasound',
                          Icons.photo,
                          Colors.purple,
                          () => _goToUltrasoundAnalyzer(pregnancy),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Lab Test',
                          Icons.science,
                          Colors.orange,
                          () => _goToLabTestAnalyzer(pregnancy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Conclude',
                          Icons.flag,
                          Colors.red,
                          () => _showConcludePregnancyDialog(pregnancy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pregnancy Details
            _buildExpandableSection(
              'Pregnancy Details',
              Icons.info_outline,
              [
                _buildInfoRow(
                    'LMP', _formatDate(pregnancy['last_menstrual_period'])),
                _buildInfoRow(
                    'EDD', _formatDate(pregnancy['expected_date_of_delivery'])),
                _buildInfoRow('Status',
                    pregnancy['status']?.toString().toUpperCase() ?? '-'),
              ],
            ),

            const SizedBox(height: 12),

            // Checkups
            _buildExpandableSection(
              'Prenatal Checkups',
              Icons.medical_services_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _checkupSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) =>
                            setState(() => _checkupSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sortedCheckups.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No checkups recorded'),
                    ),
                  )
                else
                  ...sortedCheckups.map((c) => _buildCheckupCard(c)),
              ],
            ),

            const SizedBox(height: 12),

            // Ultrasounds
            _buildExpandableSection(
              'Ultrasounds',
              Icons.photo_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _ultrasoundSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) =>
                            setState(() => _ultrasoundSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (ultrasounds.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No ultrasounds recorded'),
                    ),
                  )
                else
                  ..._sortByDate(
                          ultrasounds, 'ultrasound_date', _ultrasoundSort)
                      .map(
                    (u) => _buildUltrasoundCard(u),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Lab Tests
            _buildExpandableSection(
              'Lab Tests',
              Icons.science_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _labSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) =>
                            setState(() => _labSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (labTests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No lab tests recorded'),
                    ),
                  )
                else
                  ..._sortByDate(labTests, 'lab_test_date', _labSort).map(
                    (l) => _buildLabTestCard(l),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // HISTORY TAB
  Widget _buildHistoryTab(List pastPregnancies) {
    if (pastPregnancies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Past Pregnancies'),
              const SizedBox(height: 8),
              const Text(
                'Past pregnancies will appear here',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pastPregnancies.length,
        itemBuilder: (context, index) {
          final p = pastPregnancies[index] as Map<String, dynamic>;
          final deliveries =
              (p['delivery'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                  [];
          final outcomesList =
              (p['outcomes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                  [];

          final normalizedOutcomes = outcomesList.isNotEmpty
              ? outcomesList
              : (p['outcome'] != null || p['outcome_date'] != null)
                  ? [
                      {
                        'fetus_number': 1,
                        'outcome': p['outcome'],
                        'outcome_date': p['outcome_date'],
                      }
                    ]
                  : <Map<String, dynamic>>[];

          final primaryOutcomeStr = normalizedOutcomes.isNotEmpty
              ? outcomesList
                  .map((o) => _formatOutcome(o['outcome'] as String?))
                  .join(', ')
              : '-';
          final primaryOutcomeDate = normalizedOutcomes.isNotEmpty
              ? _formatDate(normalizedOutcomes.first['outcome_date'] as String?)
              : '-';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                child:
                    Icon(Icons.pregnant_woman, color: AppColors.brandPrimary),
              ),
              title: Text(primaryOutcomeStr),
              subtitle: Text('Ended: $primaryOutcomeDate'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                          'Gestational Age',
                          p['gestational_age_at_end'] != null
                              ? '${p['gestational_age_at_end']} weeks'
                              : '-'),
                      const SizedBox(height: 8),
                      for (int i = 0; i < normalizedOutcomes.length; i++) ...[
                        if (normalizedOutcomes.length > 1)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                  'Fetus ${normalizedOutcomes[i]['fetus_number'] ?? (i + 1)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                        _buildInfoRow(
                            'Outcome',
                            _formatOutcome(
                                normalizedOutcomes[i]['outcome'] as String?)),
                        _buildInfoRow(
                            'Date',
                            _formatDate(normalizedOutcomes[i]['outcome_date']
                                as String?)),
                        ...() {
                          final deliveryList = deliveries
                              .where((d) =>
                                  d['fetus_number'] ==
                                  normalizedOutcomes[i]['fetus_number'])
                              .toList();
                          if (deliveryList.isNotEmpty) {
                            final delivery = deliveryList.first;
                            return [
                              _buildInfoRow(
                                  'Place',
                                  delivery['place_of_delivery']?.toString() ??
                                      '-'),
                              _buildInfoRow(
                                  'Method',
                                  delivery['delivery_method']?.toString() ??
                                      '-'),
                            ];
                          }
                          return <Widget>[];
                        }()
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper Widgets

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandableSection(
      String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.brandPrimary, size: 18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupCard(Map<String, dynamic> checkup) {
    final date = _formatDateTime(checkup['checkup_datetime']);
    final bpSys = _formatValue(checkup['blood_pressure_systolic']);
    final bpDia = _formatValue(checkup['blood_pressure_diastolic']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.medical_services,
              color: AppColors.brandPrimary, size: 20),
        ),
        title: Text('Checkup',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            if (bpSys != '-' && bpDia != '-')
              Text('BP: $bpSys/$bpDia', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () async {
          final aog = _formatValue(checkup['age_of_gestation']);
          final weight = _formatValue(checkup['checkup_weight']);

          _showRecordDetails(
            title: 'Prenatal Checkup',
            subtitle: date,
            icon: Icons.medical_services,
            rows: [
              MapEntry('Date', _formatDateTime(checkup['checkup_datetime'])),
              MapEntry('Age of Gestation', aog),
              MapEntry('Weight (kg)', weight),
              MapEntry('Blood Pressure', '$bpSys/$bpDia'),
              MapEntry(
                  'Fetal Position', _formatValue(checkup['fetal_position'])),
              MapEntry('Fetal Heart Beat',
                  _formatValue(checkup['fetal_heart_beat'])),
              MapEntry('TD Vaccine', _formatValue(checkup['td_vaccine_dose'])),
              MapEntry('Edema', _formatValue(checkup['edema'])),
              MapEntry('Remarks', _formatValue(checkup['remarks'])),
              MapEntry('Next Schedule', _formatDate(checkup['next_schedule'])),
            ],
            aiAnalysis: _generatePrenatalAIInsights(checkup),
            useStructuredAiInsights: true,
          );
        },
      ),
    );
  }

  Widget _buildUltrasoundCard(Map<String, dynamic> ultrasound) {
    final date = _formatDate(ultrasound['ultrasound_date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.photo, color: Colors.purple, size: 20),
        ),
        title: Text('Ultrasound',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () async {
          // Get all image URLs
          List<String> imageUrls = [];

          if (ultrasound['ultrasound_image'] != null) {
            final imageField = ultrasound['ultrasound_image'].toString();
            if (imageField.contains(',')) {
              // Multiple URLs separated by commas
              imageUrls =
                  imageField.split(',').map((url) => url.trim()).toList();
            } else if (imageField.isNotEmpty) {
              // Single URL
              imageUrls = [imageField];
            }
          }

          _showRecordDetails(
            title: 'Ultrasound',
            subtitle: date,
            icon: Icons.monitor_heart,
            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
            rows: [
              MapEntry('Date', _formatDate(ultrasound['ultrasound_date'])),
              MapEntry(
                  'Location', _formatValue(ultrasound['ultrasound_location'])),
              MapEntry('Health Worker',
                  _formatValue(ultrasound['health_worker_name'])),
              MapEntry('Institution',
                  _formatValue(ultrasound['health_worker_institution'])),
              MapEntry('Remarks', _formatValue(ultrasound['remarks'])),
            ],
            aiAnalysis: _generateUltrasoundAIInsights(ultrasound),
          );
        },
      ),
    );
  }

  Widget _buildLabTestCard(Map<String, dynamic> labTest) {
    final date = _formatDate(labTest['lab_test_date']);
    final type = labTest['lab_test_type'] ?? 'Lab Test';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.science, color: Colors.orange, size: 20),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () async {
          // Get all image URLs
          List<String> imageUrls = [];

          if (labTest['lab_test_image'] != null) {
            final imageField = labTest['lab_test_image'].toString();
            if (imageField.contains(',')) {
              // Multiple URLs separated by commas
              imageUrls =
                  imageField.split(',').map((url) => url.trim()).toList();
            } else if (imageField.isNotEmpty) {
              // Single URL
              imageUrls = [imageField];
            }
          }

          final split = _splitLabRemarksAndAi(labTest['remarks']?.toString());

          String? aiAnalysis;
          final labTestId = labTest['lab_test_id'];
          if (labTestId is int) {
            aiAnalysis = await MotherProfileService.getLabTestAIAnalysis(
              labTestId,
            );
          }

          aiAnalysis = (aiAnalysis != null && aiAnalysis.trim().isNotEmpty)
              ? aiAnalysis.trim()
              : split.extractedAi;

          _showRecordDetails(
            title: type,
            subtitle: date,
            icon: Icons.science,
            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
            rows: [
              MapEntry('Type', type),
              MapEntry('Date', _formatDate(labTest['lab_test_date'])),
              MapEntry('Location', _formatValue(labTest['lab_test_location'])),
              MapEntry(
                  'Health Worker', _formatValue(labTest['health_worker_name'])),
              MapEntry('Remarks', _formatValue(split.cleanRemarks)),
            ],
            aiAnalysis: aiAnalysis,
            useStructuredAiInsights:
                aiAnalysis != null && aiAnalysis.isNotEmpty,
          );
        },
      ),
    );
  }

  // Helper methods
  DateTime? _parseDateForSort(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _sortByDate(
      List list, String field, String order) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final dateA = _parseDateForSort(a[field]);
      final dateB = _parseDateForSort(b[field]);
      if (dateA == null || dateB == null) return 0;
      return order == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });
    return sorted;
  }

  List<Map<String, dynamic>> _filterAndSortChildren(List children) {
    var filtered = List<Map<String, dynamic>>.from(children).where((c) {
      final name = [
        c['first_name'],
        c['middle_name'],
        c['last_name'],
      ].where((e) => e != null).join(' ').toLowerCase();
      return name.contains(_childQuery.toLowerCase());
    }).toList();

    if (_childSort == 'name') {
      filtered.sort((a, b) {
        final nameA = (a['last_name'] ?? '') + (a['first_name'] ?? '');
        final nameB = (b['last_name'] ?? '') + (b['first_name'] ?? '');
        return nameA.compareTo(nameB);
      });
    }

    return filtered;
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

