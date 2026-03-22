import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_storage.dart';
import '../../services/gemini_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/progressive_step_indicator.dart';

class AddPrenatalCheckupScreen extends StatefulWidget {
  const AddPrenatalCheckupScreen({
    super.key,
    required this.motherId,
    required this.pregnancyId,
    this.lmp,
    this.motherWeight,
    this.motherEmail,
    this.generatedPassword,
    this.takenTdDoses = const [],
  });

  final int motherId;
  final int pregnancyId;
  final DateTime? lmp;
  final double? motherWeight;
  final String? motherEmail;
  final String? generatedPassword;
  final List<String> takenTdDoses;

  @override
  State<AddPrenatalCheckupScreen> createState() =>
      _AddPrenatalCheckupScreenState();
}

class _MedicationPlanEntry {
  _MedicationPlanEntry({
    required this.name,
    this.quantity,
    this.frequency,
    this.startDate,
    this.endDate,
  });

  final String name;
  final int? quantity;
  final String? frequency;
  final DateTime? startDate;
  final DateTime? endDate;
}

class _GivenMedicationEntry {
  _GivenMedicationEntry({
    required this.name,
    required this.quantity,
    required this.dateGiven,
  });

  final String name;
  final int quantity;
  final DateTime dateGiven;
}

class SymptomType {
  SymptomType({
    required this.id,
    required this.name,
    required this.riskCategory,
    this.description,
  });

  final int id;
  final String name;
  final String riskCategory;
  final String? description;
}

class _SymptomEntry {
  _SymptomEntry({
    required this.symptomTypeId,
    required this.name,
    required this.riskCategory,
    this.notes,
  });

  final int symptomTypeId;
  final String name;
  final String riskCategory;
  final String? notes;
}

class _RiskFactorItem {
  _RiskFactorItem({
    required this.factor,
    required this.influence,
    this.sourceTable,
    this.sourceId,
  });

  final String factor;
  final String influence; // low | high
  final String? sourceTable;
  final int? sourceId;
}

class _RiskSnapshot {
  _RiskSnapshot({
    required this.level,
    required this.score,
    required this.factors,
    required this.notableRecords,
    required this.suggestedActions,
    required this.aiAssessment,
    required this.aiGenerated,
    this.aiModel,
  });

  final String level;
  final double score;
  final List<_RiskFactorItem> factors;
  final List<String> notableRecords;
  final List<String> suggestedActions;
  final String aiAssessment;
  final bool aiGenerated;
  final String? aiModel;
}

// ── BP classification ────────────────────────────────────────────────────────

enum _BpStatus {
  unknown,
  low,
  normal,
  elevated,
  stage1,
  stage2,
  severe;

  String get label {
    switch (this) {
      case _BpStatus.low:
        return 'Low BP';
      case _BpStatus.normal:
        return 'Normal';
      case _BpStatus.elevated:
        return 'Elevated';
      case _BpStatus.stage1:
        return 'HTN Stage 1';
      case _BpStatus.stage2:
        return 'HTN Stage 2';
      case _BpStatus.severe:
        return 'Hypertensive Crisis';
      default:
        return '';
    }
  }

  Color get color {
    switch (this) {
      case _BpStatus.low:
        return AppColors.info;
      case _BpStatus.normal:
        return AppColors.success;
      case _BpStatus.elevated:
        return AppColors.warning;
      case _BpStatus.stage1:
        return const Color(0xFFE65100);
      case _BpStatus.stage2:
        return AppColors.error;
      case _BpStatus.severe:
        return const Color(0xFFB71C1C);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case _BpStatus.low:
        return Icons.arrow_downward_rounded;
      case _BpStatus.normal:
        return Icons.check_circle_rounded;
      case _BpStatus.unknown:
        return Icons.help_outline;
      default:
        return Icons.warning_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddPrenatalCheckupScreenState extends State<AddPrenatalCheckupScreen> {
  final _geminiService = GeminiService();
  final _aiAssessmentCtrl = TextEditingController();
  final _aiAssessmentEditCtrl = TextEditingController();
  final _symptomSearchCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _sysCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _fetalBeatCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _ferrousQtyCtrl = TextEditingController();
  final _calciumQtyCtrl = TextEditingController();

  int _fetalCount = 1;
  int _originalFetalCount = 1;
  final _fetalCountReasonCtrl = TextEditingController();
  bool _loadingFetalCount = true;
  String? _fetalCountError;

  final List<_MedicationPlanEntry> _medicationPlans = [];
  final List<_GivenMedicationEntry> _givenMedications = [];
  final List<_SymptomEntry> _symptoms = [];
  List<SymptomType> _symptomTypes = [];

  DateTime _checkupDateTime = DateTime.now();
  DateTime? _nextSchedule;

  String? _fetalPosition;
  String? _fetalTone;
  String _edema = 'none';
  String? _tdDose;

  // inline error texts
  String? _weightError;
  String? _sysError;
  String? _diaError;
  String? _fetalBeatError;
  String? _ferrousError;
  String? _calciumError;

  int _step = 0;
  static const int _totalSteps = 7;
  bool _submitting = false;
  bool _loadingSymptomTypes = false;
  String _symptomRiskFilter = 'all';
  int? _midwifeId;
  int? _accountId;
  bool _loadingRiskPreview = false;
  String? _riskPreviewError;
  _RiskSnapshot? _riskSnapshot;
  String? _lastRiskSignature;
  Map<String, dynamic>? _motherRiskContext;
  String? _aiOriginalAssessment;
  bool _aiAssessmentEdited = false;
  bool _aiResponseApproved = false;
  bool _isEditingAiAssessment = false;
  String _editableRiskLevel = 'low';
  List<_RiskFactorItem> _editableRiskFactors = [];

  static const List<String> _fetalPositions = [
    'unknown',
    'cephalic',
    'vertex',
    'breech',
    'transverse',
  ];

  static const List<String> _fetalTones = [
    'Normal',
    'Tachycardia',
    'Bradycardia',
    'Irregular',
    'Muffled',
    'Absent',
    'Other',
  ];

  static const List<String> _edemaLevels = [
    'none',
    'mild',
    'moderate',
    'severe',
  ];

  static const List<String> _tdOptions = [
    'TD 1',
    'TD 2',
    'TD 3',
    'TD 4',
    'TD 5',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.motherWeight != null) {
      _weightCtrl.text = widget.motherWeight!.toStringAsFixed(1);
    }
    _loadMidwifeId();
    _loadSymptomTypes();
    _loadMotherRiskContext();
    _loadFetalCount();
    _weightCtrl.addListener(_validateWeightInline);
    _sysCtrl.addListener(_validateBpInline);
    _diaCtrl.addListener(_validateBpInline);
    _fetalBeatCtrl.addListener(_validateFetalBeatInline);
    _ferrousQtyCtrl.addListener(_validateFerrousInline);
    _calciumQtyCtrl.addListener(_validateCalciumInline);
  }

  void _validateWeightInline() {
    final t = _weightCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _weightError = null);
      return;
    }
    final v = double.tryParse(t);
    setState(() => _weightError = (v == null)
        ? 'Enter a valid number'
        : (v < 30 || v > 200)
            ? 'Must be 30 – 200 kg'
            : null);
  }

  void _validateBpInline() {
    final sys = int.tryParse(_sysCtrl.text.trim());
    final dia = int.tryParse(_diaCtrl.text.trim());
    setState(() {
      _sysError = _sysCtrl.text.trim().isEmpty
          ? null
          : (sys == null || sys < 70 || sys > 250)
              ? '70 – 250 mmHg'
              : null;
      _diaError = _diaCtrl.text.trim().isEmpty
          ? null
          : (dia == null || dia < 40 || dia > 150)
              ? '40 – 150 mmHg'
              : (sys != null && sys <= dia)
                  ? 'Must be < systolic'
                  : null;
    });
  }

  void _validateFetalBeatInline() {
    final t = _fetalBeatCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _fetalBeatError = null);
      return;
    }
    final v = int.tryParse(t);
    setState(() => _fetalBeatError =
        (v == null || v < 90 || v > 200) ? '90 – 200 bpm' : null);
  }

  void _validateFerrousInline() {
    final t = _ferrousQtyCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _ferrousError = null);
      return;
    }
    final v = int.tryParse(t);
    setState(() => _ferrousError =
        (v == null || v < 1 || v > 365) ? '1 – 365 tablets' : null);
  }

  void _validateCalciumInline() {
    final t = _calciumQtyCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _calciumError = null);
      return;
    }
    final v = int.tryParse(t);
    setState(() => _calciumError =
        (v == null || v < 1 || v > 365) ? '1 – 365 tablets' : null);
  }

  Future<void> _loadFetalCount() async {
    try {
      final res = await Supabase.instance.client
          .from('pregnancies')
          .select('fetal_count')
          .eq('pregnancy_id', widget.pregnancyId)
          .maybeSingle();
      if (res != null && res['fetal_count'] != null) {
        if (mounted) {
          setState(() {
            _originalFetalCount = res['fetal_count'] as int;
            _fetalCount = _originalFetalCount;
            _loadingFetalCount = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingFetalCount = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFetalCount = false);
    }
  }

  Future<void> _loadMidwifeId() async {
    final accountId = await AuthStorage.getUserId();
    if (accountId == null) return;
    if (mounted) setState(() => _accountId = accountId);
    try {
      final result = await Supabase.instance.client
          .from('midwives')
          .select('midwife_id')
          .eq('account_id', accountId)
          .single();
      if (mounted) setState(() => _midwifeId = result['midwife_id'] as int);
    } catch (_) {}
  }

  Future<void> _loadSymptomTypes() async {
    setState(() => _loadingSymptomTypes = true);
    try {
      final rows = await Supabase.instance.client
          .from('symptom_types')
          .select('symptom_type_id, symptom_name, risk_category, description')
          .order('risk_category')
          .order('symptom_name');

      final parsed = (rows as List)
          .map(
            (row) => SymptomType(
              id: row['symptom_type_id'] as int,
              name: row['symptom_name'] as String,
              riskCategory: row['risk_category'] as String,
              description: row['description'] as String?,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() => _symptomTypes = parsed);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to load symptom types. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingSymptomTypes = false);
    }
  }

  Future<void> _loadMotherRiskContext() async {
    try {
      final client = Supabase.instance.client;

      final mother = await client.from('mothers').select('''
            birthdate,
            height,
            weight,
            blood_type,
            accounts!inner(first_name, last_name)
          ''').eq('mother_id', widget.motherId).maybeSingle();

      final pregnancy = await client.from('pregnancies').select('''
            pregnancy_id,
            status,
            pregnancy_risk_level,
            last_menstrual_period,
            expected_date_of_delivery,
            created_at
          ''').eq('pregnancy_id', widget.pregnancyId).maybeSingle();

      final medicalConditions = await client
          .from('medical_conditions')
          .select('condition_name, status, diagnosis_date')
          .eq('mother_id', widget.motherId)
          .order('created_at', ascending: false);

      final allergies = await client
          .from('allergies')
          .select('allergen, status, diagnosis_date')
          .eq('mother_id', widget.motherId)
          .order('created_at', ascending: false);

      final pastPregnancies = await client
          .from('pregnancies')
          .select(
              'pregnancy_id, fetal_count, outcome, outcome_date, gestational_age_at_end, status, created_at')
          .eq('mother_id', widget.motherId)
          .neq('pregnancy_id', widget.pregnancyId)
          .order('created_at', ascending: false);

      final pastPregnancyIds = (pastPregnancies as List)
          .map((p) => p['pregnancy_id'])
          .whereType<int>()
          .toList();

      List<dynamic> pastPregnancyOutcomes = const [];
      if (pastPregnancyIds.isNotEmpty) {
        try {
          pastPregnancyOutcomes = await client
              .from('pregnancy_outcomes')
              .select('''
                pregnancy_id,
                outcome,
                outcome_date,
                is_outcome_date_estimated,
                gestational_age_at_end,
                place_of_delivery,
                delivery_method
              ''')
              .inFilter('pregnancy_id', pastPregnancyIds)
              .order('outcome_date', ascending: false);
        } catch (_) {
          // Optional table in some deployments; keep fallback logic.
        }
      }

      final previousCheckups = await client
          .from('prenatal_checkups')
          .select('''
            prenatal_checkup_id,
            checkup_datetime,
            age_of_gestation,
            checkup_weight,
            blood_pressure_systolic,
            blood_pressure_diastolic,
            fetal_heart_beat,
            edema,
            remarks
          ''')
          .eq('pregnancy_id', widget.pregnancyId)
          .order('checkup_datetime', ascending: false)
          .limit(6);

      if (!mounted) return;
      setState(() {
        _motherRiskContext = {
          'mother': mother,
          'pregnancy': pregnancy,
          'medical_conditions': medicalConditions,
          'allergies': allergies,
          'past_pregnancies': pastPregnancies,
          'past_pregnancy_outcomes': pastPregnancyOutcomes,
          'previous_checkups': previousCheckups,
        };
      });
    } catch (_) {
      // Risk preview should still work with form-only data.
    }
  }

  DateTime? _tryDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  int? _ageFromBirthdate(DateTime? birthdate) {
    if (birthdate == null) return null;
    return (DateTime.now().difference(birthdate).inDays / 365.25).floor();
  }

  Color _riskLevelColor(String level) {
    switch (level) {
      case 'high':
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  String _riskLevelLabel(String level) {
    switch (level) {
      case 'high':
        return 'High Risk';
      default:
        return 'Low Risk';
    }
  }

  String _currentRiskSignature() {
    return [
      _checkupDateTime.toIso8601String(),
      _fetalCount.toString(),
      _originalFetalCount.toString(),
      _fetalCountReasonCtrl.text.trim(),
      _weightCtrl.text.trim(),
      _sysCtrl.text.trim(),
      _diaCtrl.text.trim(),
      _fetalBeatCtrl.text.trim(),
      _fetalPosition ?? '-',
      _fetalTone ?? '-',
      _edema,
      _tdDose ?? '-',
      _ferrousQtyCtrl.text.trim(),
      _calciumQtyCtrl.text.trim(),
      _symptoms
          .map((s) => '${s.symptomTypeId}:${s.riskCategory}:${s.notes ?? ''}')
          .join('|'),
      _remarksCtrl.text.trim(),
      _nextSchedule?.toIso8601String() ?? '-',
      (_motherRiskContext?['previous_checkups'] as List? ?? const [])
          .length
          .toString(),
      (_motherRiskContext?['medical_conditions'] as List? ?? const [])
          .length
          .toString(),
      (_motherRiskContext?['allergies'] as List? ?? const []).length.toString(),
      (_motherRiskContext?['past_pregnancies'] as List? ?? const [])
          .length
          .toString(),
      (_motherRiskContext?['past_pregnancy_outcomes'] as List? ?? const [])
          .length
          .toString(),
    ].join('||');
  }

  String _buildMergedAssessmentText(_RiskSnapshot snapshot, String? aiText) {
    final systemFactors = snapshot.factors
        .map((f) => '- ${f.factor} (${f.influence})')
        .join('\n');
    final systemActions =
        snapshot.suggestedActions.map((a) => '- $a').join('\n');
    final systemNotable = snapshot.notableRecords.map((n) => '- $n').join('\n');

    if (snapshot.aiGenerated && aiText != null && aiText.trim().isNotEmpty) {
      return '''
${aiText.trim()}

SYSTEM-DETECTED RISK LEVEL: ${_riskLevelLabel(snapshot.level)}

SYSTEM-DETECTED NOTABLE RECORDS:
${systemNotable.isEmpty ? '- None recorded' : systemNotable}

SYSTEM-DETECTED RISK FACTORS:
${systemFactors.isEmpty ? '- No major factors detected' : systemFactors}

SYSTEM-DETECTED SUGGESTIVE ACTIONS:
${systemActions.isEmpty ? '- Continue routine prenatal follow-up.' : systemActions}
''';
    }

    return '''
RISK LEVEL: ${_riskLevelLabel(snapshot.level)}

NOTABLE RECORDS:
${systemNotable.isEmpty ? '- None recorded' : systemNotable}

RISK FACTORS:
${systemFactors.isEmpty ? '- No major factors detected' : systemFactors}

SUGGESTIVE ACTIONS:
${systemActions.isEmpty ? '- Continue routine prenatal follow-up.' : systemActions}
''';
  }

  void _syncEditableRiskState(_RiskSnapshot snapshot, String mergedText) {
    _editableRiskLevel = snapshot.level;
    _editableRiskFactors = List<_RiskFactorItem>.from(snapshot.factors);
    _aiOriginalAssessment = mergedText;
    _aiAssessmentCtrl.text = mergedText;
    _aiAssessmentEditCtrl.text = mergedText;
    _isEditingAiAssessment = false;
    _aiAssessmentEdited = false;
    _aiResponseApproved = false;
  }

  bool _sameFactorLists(List<_RiskFactorItem> a, List<_RiskFactorItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].factor != b[i].factor || a[i].influence != b[i].influence) {
        return false;
      }
    }
    return true;
  }

  _RiskSnapshot _buildRuleBasedRiskSnapshot() {
    double score = 0;
    final factors = <_RiskFactorItem>[];
    final notable = <String>[];
    final actions = <String>[];

    final mother = _motherRiskContext?['mother'] as Map<String, dynamic>?;
    final pregnancy = _motherRiskContext?['pregnancy'] as Map<String, dynamic>?;
    final conditions =
        (_motherRiskContext?['medical_conditions'] as List? ?? const [])
            .cast<dynamic>();
    final allergies =
        (_motherRiskContext?['allergies'] as List? ?? const []).cast<dynamic>();
    final pastPregnancies =
        (_motherRiskContext?['past_pregnancies'] as List? ?? const [])
            .cast<dynamic>();
    final pastPregnancyOutcomes =
        (_motherRiskContext?['past_pregnancy_outcomes'] as List? ?? const [])
            .cast<dynamic>();
    final previousCheckups =
        (_motherRiskContext?['previous_checkups'] as List? ?? const [])
            .cast<dynamic>();

    final currentLmp =
        _tryDate(pregnancy?['last_menstrual_period']) ?? widget.lmp;
    final today = DateTime.now();

    final Map<int, List<Map<String, dynamic>>> outcomesByPregnancy = {};
    for (final row in pastPregnancyOutcomes) {
      if (row is! Map<String, dynamic>) continue;
      final pid = row['pregnancy_id'] as int?;
      if (pid == null) continue;
      outcomesByPregnancy
          .putIfAbsent(pid, () => <Map<String, dynamic>>[])
          .add(row);
    }

    int recurrentLossCount = 0;
    int stillbirthCount = 0;
    int ectopicCount = 0;
    int pretermCount = 0;
    int priorMultifetalCount = 0;
    DateTime? latestHistoricalOutcome;
    final historicalOutcomes = <String>[];

    final systolic = int.tryParse(_sysCtrl.text.trim());
    final diastolic = int.tryParse(_diaCtrl.text.trim());
    final fetalBeat = int.tryParse(_fetalBeatCtrl.text.trim());
    final gaCurrent =
        currentLmp != null ? today.difference(currentLmp).inDays ~/ 7 : null;

    final age = _ageFromBirthdate(_tryDate(mother?['birthdate']));
    if (age != null) {
      notable.add('Maternal age: $age years');
      if (age < 18) {
        score += 30;
        factors.add(_RiskFactorItem(
          factor: 'Teenage pregnancy (<18 years)',
          influence: 'high',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
        actions.add(
            'Provide adolescent-focused high-risk counseling and close follow-up.');
      } else if (age >= 35) {
        score += 18;
        factors.add(_RiskFactorItem(
          factor: 'Advanced maternal age (>=35 years)',
          influence: 'high',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
        actions.add(
            'Monitor blood pressure and fetal growth more closely due to age-related risk.');
      } else if (age >= 30) {
        score += 6;
        factors.add(_RiskFactorItem(
          factor: 'Age 30-34 years (moderate baseline obstetric risk)',
          influence: 'low',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
      }
    }

    final height = (mother?['height'] as num?)?.toDouble();
    final weightNow = double.tryParse(_weightCtrl.text.trim()) ??
        (mother?['weight'] as num?)?.toDouble();
    if (height != null && weightNow != null && height > 0) {
      final bmi = weightNow / ((height / 100) * (height / 100));
      notable
          .add('Estimated BMI from height/weight: ${bmi.toStringAsFixed(1)}');
      if (bmi < 18.5) {
        score += 10;
        factors.add(_RiskFactorItem(
          factor: 'Underweight BMI (<18.5)',
          influence: 'low',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
      } else if (bmi >= 30) {
        score += 20;
        factors.add(_RiskFactorItem(
          factor: 'Obese BMI (>=30)',
          influence: 'high',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
      } else if (bmi >= 25) {
        score += 8;
        factors.add(_RiskFactorItem(
          factor: 'Overweight BMI (25-29.9)',
          influence: 'low',
          sourceTable: 'mothers',
          sourceId: widget.motherId,
        ));
      }
    }

    if (_fetalCount > 1) {
      // Multifetal gestation is treated as an automatic high-risk baseline.
      score = score < 40 ? 40 : score + 24;
      factors.add(_RiskFactorItem(
        factor: 'Current multifetal gestation (fetal count: $_fetalCount)',
        influence: 'high',
        sourceTable: 'pregnancies',
        sourceId: widget.pregnancyId,
      ));
      notable.add('Current pregnancy fetal count: $_fetalCount');
      actions.add(
          'Use closer surveillance for preterm labor, hypertensive disorders, and fetal growth in multifetal pregnancy.');
    }

    if (gaCurrent != null) {
      notable.add('Current gestational age estimate: $gaCurrent weeks');
      if (gaCurrent < 8) {
        score += 5;
        factors.add(_RiskFactorItem(
          factor:
              'Very early gestation (<8 weeks) with limited clinical trend data',
          influence: 'low',
          sourceTable: 'pregnancies',
          sourceId: widget.pregnancyId,
        ));
      }
    }

    for (final row in conditions) {
      final map = row as Map<String, dynamic>;
      final status = (map['status'] ?? '').toString().toLowerCase();
      if (status != 'active') continue;
      final name = (map['condition_name'] ?? '').toString();
      final lower = name.toLowerCase();
      int conditionScore = 10;
      String influence = 'low';
      if (lower.contains('hypertension') ||
          lower.contains('diabetes') ||
          lower.contains('heart') ||
          lower.contains('kidney') ||
          lower.contains('lupus') ||
          lower.contains('epilepsy') ||
          lower.contains('thyroid')) {
        conditionScore = 24;
        influence = 'high';
      } else if (lower.contains('anemia') || lower.contains('asthma')) {
        conditionScore = 14;
        influence = 'low';
      }
      score += conditionScore;
      factors.add(_RiskFactorItem(
        factor: 'Active medical condition: $name',
        influence: influence,
        sourceTable: 'medical_conditions',
        sourceId: widget.motherId,
      ));
    }

    final activeConditionCount = conditions.where((row) {
      final map = row as Map<String, dynamic>;
      return (map['status'] ?? '').toString().toLowerCase() == 'active';
    }).length;
    if (activeConditionCount >= 2) {
      score += 10;
      factors.add(_RiskFactorItem(
        factor: 'Multiple active chronic conditions ($activeConditionCount)',
        influence: 'high',
        sourceTable: 'medical_conditions',
        sourceId: widget.motherId,
      ));
      actions.add(
          'Coordinate integrated management plan for multiple comorbidities with physician review.');
    }

    final activeAllergies = allergies.where((row) {
      final map = row as Map<String, dynamic>;
      return (map['status'] ?? '').toString().toLowerCase() == 'active';
    }).toList();
    if (activeAllergies.isNotEmpty) {
      final severeAllergy = activeAllergies.any((row) {
        final map = row as Map<String, dynamic>;
        final allergen = (map['allergen'] ?? '').toString().toLowerCase();
        return allergen.contains('anaphyl') ||
            allergen.contains('penicillin') ||
            allergen.contains('drug') ||
            allergen.contains('antibiotic');
      });
      score += severeAllergy ? 10 : 4;
      factors.add(_RiskFactorItem(
        factor:
            'Active allergy history (${activeAllergies.length})${severeAllergy ? ' with potential severe trigger' : ''}',
        influence: severeAllergy ? 'high' : 'low',
        sourceTable: 'allergies',
        sourceId: widget.motherId,
      ));
      notable.add('Has active allergies (${activeAllergies.length})');
      actions.add(
          'Verify medication allergies before prescribing supplements or antibiotics.');
    }

    for (final row in pastPregnancies) {
      final map = row as Map<String, dynamic>;
      final pid = map['pregnancy_id'] as int?;
      final fetalCount = (map['fetal_count'] as num?)?.toInt() ?? 1;
      if (fetalCount > 1) {
        priorMultifetalCount++;
      }

      final outcomeRows = <Map<String, dynamic>>[];
      if (pid != null && outcomesByPregnancy.containsKey(pid)) {
        outcomeRows.addAll(outcomesByPregnancy[pid]!);
      }
      if (outcomeRows.isEmpty && map['outcome'] != null) {
        outcomeRows.add({
          'pregnancy_id': pid,
          'outcome': map['outcome'],
          'outcome_date': map['outcome_date'],
          'gestational_age_at_end': map['gestational_age_at_end'],
        });
      }

      for (final o in outcomeRows) {
        final outcome = (o['outcome'] ?? '').toString();
        final lower = outcome.toLowerCase();
        final outcomeDate = _tryDate(o['outcome_date']);
        final gaEnd = (o['gestational_age_at_end'] as num?)?.toDouble() ??
            (map['gestational_age_at_end'] as num?)?.toDouble();

        if (outcomeDate != null) {
          if (latestHistoricalOutcome == null ||
              outcomeDate.isAfter(latestHistoricalOutcome!)) {
            latestHistoricalOutcome = outcomeDate;
          }
        }

        historicalOutcomes.add(
            '$outcome${outcomeDate != null ? ' (${DateFormat('yyyy-MM-dd').format(outcomeDate)})' : ''}');

        if (lower == 'miscarriage' || lower == 'abortion') recurrentLossCount++;
        if (lower == 'stillbirth') stillbirthCount++;
        if (lower == 'ectopic') ectopicCount++;
        if ((lower == 'live_birth' || lower == 'stillbirth') &&
            gaEnd != null &&
            gaEnd < 37) {
          pretermCount++;
        }

        if (lower == 'stillbirth' ||
            lower == 'miscarriage' ||
            lower == 'ectopic') {
          score += 18;
          factors.add(_RiskFactorItem(
            factor: 'History of $lower pregnancy outcome',
            influence: 'high',
            sourceTable: 'pregnancies',
            sourceId: pid,
          ));
        }

        if (currentLmp != null && outcomeDate != null) {
          final daysGap = currentLmp.difference(outcomeDate).inDays;
          if (daysGap > 0 && daysGap < 180) {
            score += 20;
            factors.add(_RiskFactorItem(
              factor: 'Short interpregnancy interval (${daysGap} days)',
              influence: 'high',
              sourceTable: 'pregnancies',
              sourceId: pid,
            ));
          } else if (daysGap >= 180 && daysGap < 365) {
            score += 10;
            factors.add(_RiskFactorItem(
              factor:
                  'Interpregnancy interval under 12 months (${daysGap} days)',
              influence: 'low',
              sourceTable: 'pregnancies',
              sourceId: pid,
            ));
          }
        }
      }
    }

    if (historicalOutcomes.isNotEmpty) {
      notable
          .add('Historical outcomes: ${historicalOutcomes.take(8).join(', ')}');
    }
    if (recurrentLossCount >= 2) {
      score += 22;
      factors.add(_RiskFactorItem(
        factor: 'Recurrent pregnancy loss history ($recurrentLossCount)',
        influence: 'high',
        sourceTable: 'pregnancies',
        sourceId: widget.motherId,
      ));
      actions.add(
          'Assess recurrent loss workup history and monitor early-pregnancy viability closely.');
    }
    if (stillbirthCount >= 1) {
      actions.add(
          'Plan closer fetal surveillance due to prior stillbirth history.');
    }
    if (ectopicCount >= 1) {
      actions.add(
          'Confirm pregnancy location and dating details if early-gestation uncertainty exists.');
    }
    if (pretermCount >= 1) {
      score += 14;
      factors.add(_RiskFactorItem(
        factor: 'History of preterm delivery/preterm fetal loss',
        influence: 'high',
        sourceTable: 'pregnancies',
        sourceId: widget.motherId,
      ));
      actions.add(
          'Strengthen preterm labor counseling and symptom monitoring plan.');
    }
    if (priorMultifetalCount >= 1) {
      score += 8;
      factors.add(_RiskFactorItem(
        factor: 'Prior multifetal pregnancy history',
        influence: 'low',
        sourceTable: 'pregnancies',
        sourceId: widget.motherId,
      ));
    }

    if (systolic != null && diastolic != null) {
      notable.add('Current BP: $systolic/$diastolic mmHg');
      if (systolic >= 160 || diastolic >= 110) {
        score += 35;
        factors.add(_RiskFactorItem(
          factor: 'Severely elevated blood pressure at checkup',
          influence: 'high',
          sourceTable: 'prenatal_checkups',
        ));
        actions.add(
            'Recheck blood pressure and evaluate urgently for hypertensive disorders.');
      } else if (systolic >= 140 || diastolic >= 90) {
        score += 24;
        factors.add(_RiskFactorItem(
          factor: 'High blood pressure at checkup (>=140/90)',
          influence: 'high',
          sourceTable: 'prenatal_checkups',
        ));
        actions.add(
            'Check urine protein and preeclampsia warning signs due to hypertensive range BP.');
      } else if (systolic >= 130 || diastolic >= 80) {
        score += 12;
        factors.add(_RiskFactorItem(
          factor: 'Borderline elevated blood pressure',
          influence: 'low',
          sourceTable: 'prenatal_checkups',
        ));
      }
    }

    if (fetalBeat != null) {
      notable.add('Fetal heart rate: $fetalBeat bpm');
      if (fetalBeat < 110 || fetalBeat > 160) {
        score += 26;
        factors.add(_RiskFactorItem(
          factor: 'Abnormal fetal heart rate ($fetalBeat bpm)',
          influence: 'high',
          sourceTable: 'prenatal_checkups',
        ));
        actions.add(
            'Repeat fetal heart monitoring and correlate with fetal movement.');
      }
    } else if (gaCurrent != null && gaCurrent >= 20) {
      score += 8;
      factors.add(_RiskFactorItem(
        factor: 'Missing fetal heart rate at >=20 weeks gestation',
        influence: 'low',
        sourceTable: 'prenatal_checkups',
      ));
      actions.add(
          'Document fetal heart rate in this checkup to complete fetal surveillance.');
    }

    if (_edema == 'moderate' || _edema == 'severe') {
      score += _edema == 'severe' ? 20 : 12;
      factors.add(_RiskFactorItem(
        factor: '$_edema edema documented',
        influence: _edema == 'severe' ? 'high' : 'low',
        sourceTable: 'prenatal_checkups',
      ));
    }

    if ((systolic != null && diastolic != null) &&
        (systolic >= 140 || diastolic >= 90) &&
        (_edema == 'moderate' || _edema == 'severe')) {
      score += 16;
      factors.add(_RiskFactorItem(
        factor:
            'Hypertension with edema pattern (possible preeclampsia warning)',
        influence: 'high',
        sourceTable: 'prenatal_checkups',
      ));
      actions.add(
          'Escalate preeclampsia screening today (repeat BP, urine protein, severe symptom check).');
    }

    final warningSymptomsFiltered =
        _symptoms.where((s) => s.riskCategory == 'warning').toList();
    final dangerSymptomsFiltered =
        _symptoms.where((s) => s.riskCategory == 'danger').toList();

    double warningScoreAdded = 0;
    for (final s in warningSymptomsFiltered) {
      if (warningScoreAdded < 24) {
        score += 6;
        warningScoreAdded += 6;
      }
      factors.add(_RiskFactorItem(
        factor: 'Warning symptom: ${s.name}',
        influence: 'low',
        sourceTable: 'pregnancy_symptoms',
      ));
      notable.add(
          'Warning symptom: ${s.name}${(s.notes ?? '').trim().isEmpty ? '' : ' — ${s.notes!.trim()}'}');
    }

    double dangerScoreAdded = 0;
    for (final s in dangerSymptomsFiltered) {
      if (dangerScoreAdded < 36) {
        score += 12;
        dangerScoreAdded += 12;
      }
      factors.add(_RiskFactorItem(
        factor: 'Danger symptom: ${s.name}',
        influence: 'high',
        sourceTable: 'pregnancy_symptoms',
      ));
      notable.add(
          '⚠ Danger symptom: ${s.name}${(s.notes ?? '').trim().isEmpty ? '' : ' — ${s.notes!.trim()}'}');
    }

    if (dangerSymptomsFiltered.isNotEmpty) {
      actions.add(
          'Prioritize immediate danger sign protocol and referral if persistent.');
    }

    final dangerSymptomCount = dangerSymptomsFiltered.length;
    if (dangerSymptomCount >= 2) {
      score += 12;
      factors.add(_RiskFactorItem(
        factor:
            'Multiple danger symptoms in current visit ($dangerSymptomCount)',
        influence: 'high',
        sourceTable: 'pregnancy_symptoms',
      ));
      actions.add(
          'Consider urgent physician review due to multiple concurrent danger symptoms.');
    }

    if (previousCheckups.isNotEmpty) {
      final latest = previousCheckups.first as Map<String, dynamic>;
      final prevSys = latest['blood_pressure_systolic'] as int?;
      final prevDia = latest['blood_pressure_diastolic'] as int?;
      if (systolic != null &&
          diastolic != null &&
          prevSys != null &&
          prevDia != null) {
        final jumped =
            (systolic - prevSys >= 20) || (diastolic - prevDia >= 15);
        if (jumped) {
          score += 10;
          factors.add(_RiskFactorItem(
            factor: 'Blood pressure increased significantly from prior checkup',
            influence: 'low',
            sourceTable: 'prenatal_checkups',
            sourceId: latest['prenatal_checkup_id'] as int?,
          ));
          actions.add(
              'Compare with previous checkup trends and reinforce BP warning signs.');
        }
      }

      final highBpHistoryCount = previousCheckups.where((row) {
        final map = row as Map<String, dynamic>;
        final s = map['blood_pressure_systolic'] as int?;
        final d = map['blood_pressure_diastolic'] as int?;
        if (s == null || d == null) return false;
        return s >= 140 || d >= 90;
      }).length;
      final highBpTotal = highBpHistoryCount +
          (((systolic != null && diastolic != null) &&
                  (systolic >= 140 || diastolic >= 90))
              ? 1
              : 0);
      if (highBpTotal >= 2) {
        score += 16;
        factors.add(_RiskFactorItem(
          factor:
              'Repeated hypertensive readings across visits ($highBpTotal episodes)',
          influence: 'high',
          sourceTable: 'prenatal_checkups',
          sourceId: latest['prenatal_checkup_id'] as int?,
        ));
        actions.add(
            'Treat as persistent BP risk pattern and increase follow-up frequency.');
      }

      final priorFhrAbnormal = previousCheckups.where((row) {
        final map = row as Map<String, dynamic>;
        final fhr = map['fetal_heart_beat'] as int?;
        return fhr != null && (fhr < 110 || fhr > 160);
      }).length;
      if (priorFhrAbnormal >= 1 &&
          fetalBeat != null &&
          (fetalBeat < 110 || fetalBeat > 160)) {
        score += 14;
        factors.add(_RiskFactorItem(
          factor: 'Recurrent abnormal fetal heart rate trend',
          influence: 'high',
          sourceTable: 'prenatal_checkups',
          sourceId: latest['prenatal_checkup_id'] as int?,
        ));
      }

      final previousWeight = (latest['checkup_weight'] as num?)?.toDouble();
      final currentWeight = double.tryParse(_weightCtrl.text.trim());
      if (previousWeight != null && currentWeight != null) {
        final delta = currentWeight - previousWeight;
        if (delta >= 3.0) {
          score += 10;
          factors.add(_RiskFactorItem(
            factor:
                'Rapid weight gain since last checkup (+${delta.toStringAsFixed(1)} kg)',
            influence: 'low',
            sourceTable: 'prenatal_checkups',
            sourceId: latest['prenatal_checkup_id'] as int?,
          ));
        }
      }
    }

    if (latestHistoricalOutcome != null) {
      notable.add(
          'Most recent prior pregnancy outcome: ${DateFormat('yyyy-MM-dd').format(latestHistoricalOutcome!)}');
    }

    if (_weightCtrl.text.trim().isEmpty ||
        _sysCtrl.text.trim().isEmpty ||
        _diaCtrl.text.trim().isEmpty) {
      score += 8;
      factors.add(_RiskFactorItem(
        factor: 'Missing key vitals in current draft (weight/BP)',
        influence: 'low',
        sourceTable: 'prenatal_checkups',
      ));
      actions.add(
          'Complete missing vitals before finalizing risk interpretation.');
    }

    final highRiskTriggerCount =
        factors.where((f) => f.influence == 'high').length;
    final lowRiskMonitorCount =
        factors.where((f) => f.influence == 'low').length;
    final level = highRiskTriggerCount > 0 ? 'high' : 'low';
    score = highRiskTriggerCount.toDouble();

    notable.add('High-risk triggers: $highRiskTriggerCount');
    notable.add('Monitoring factors: $lowRiskMonitorCount');
    final dedupedActions = <String>[];
    for (final action in actions) {
      final normalized = action.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (dedupedActions
          .any((existing) => existing.trim().toLowerCase() == normalized)) {
        continue;
      }
      dedupedActions.add(action.trim());
    }

    final fallbackAiText = 'Risk level: ${_riskLevelLabel(level)}. '
        'Classification follows trigger-based DOH-style screening: any high-risk trait marks the pregnancy as high risk. '
        'Assessment is based on current checkup values, maternal demographics, full obstetric history, multifetal context, and prior checkup trends.';

    return _RiskSnapshot(
      level: level,
      score: score,
      factors: factors,
      notableRecords: notable,
      suggestedActions: dedupedActions,
      aiAssessment: fallbackAiText,
      aiGenerated: false,
      aiModel: null,
    );
  }

  String _buildAiPrompt(_RiskSnapshot draft) {
    final mother = _motherRiskContext?['mother'] as Map<String, dynamic>?;
    final pregnancy = _motherRiskContext?['pregnancy'] as Map<String, dynamic>?;
    final conditions =
        (_motherRiskContext?['medical_conditions'] as List? ?? const [])
            .cast<dynamic>();
    final allergies =
        (_motherRiskContext?['allergies'] as List? ?? const []).cast<dynamic>();
    final pastPregnancies =
        (_motherRiskContext?['past_pregnancies'] as List? ?? const [])
            .cast<dynamic>();
    final pastPregnancyOutcomes =
        (_motherRiskContext?['past_pregnancy_outcomes'] as List? ?? const [])
            .cast<dynamic>();
    final previousCheckups =
        (_motherRiskContext?['previous_checkups'] as List? ?? const [])
            .cast<dynamic>();

    final Map<int, List<Map<String, dynamic>>> outcomesByPregnancy = {};
    for (final row in pastPregnancyOutcomes) {
      if (row is! Map<String, dynamic>) continue;
      final pid = row['pregnancy_id'] as int?;
      if (pid == null) continue;
      outcomesByPregnancy
          .putIfAbsent(pid, () => <Map<String, dynamic>>[])
          .add(row);
    }

    final activeConditionLines = conditions
        .where((c) => (c['status'] ?? '').toString().toLowerCase() == 'active')
        .map((c) {
      final name = (c['condition_name'] ?? 'Unknown condition').toString();
      final diagnosis = (c['diagnosis_date'] ?? '').toString();
      return diagnosis.isEmpty ? '- $name' : '- $name (diagnosed: $diagnosis)';
    }).toList();

    final activeAllergyLines = allergies
        .where((a) => (a['status'] ?? '').toString().toLowerCase() == 'active')
        .map((a) {
      final name = (a['allergen'] ?? 'Unknown allergen').toString();
      final diagnosis = (a['diagnosis_date'] ?? '').toString();
      return diagnosis.isEmpty ? '- $name' : '- $name (noted: $diagnosis)';
    }).toList();

    final pastPregnancyLines = pastPregnancies.map((p) {
      final pid = p['pregnancy_id'] as int?;
      final fetalCount = p['fetal_count']?.toString() ?? '1';
      final linkedOutcomes = pid == null
          ? <Map<String, dynamic>>[]
          : (outcomesByPregnancy[pid] ?? <Map<String, dynamic>>[]);

      if (linkedOutcomes.isNotEmpty) {
        final details = linkedOutcomes.asMap().entries.map((e) {
          final o = e.value;
          final outcome = (o['outcome'] ?? 'unknown').toString();
          final date = (o['outcome_date'] ?? 'unknown').toString();
          final ga = o['gestational_age_at_end']?.toString() ??
              p['gestational_age_at_end']?.toString();
          final method = (o['delivery_method'] ?? '').toString();
          return 'F${e.key + 1}: $outcome on $date${ga == null ? '' : ', GA end: $ga weeks'}${method.isEmpty ? '' : ', method: $method'}';
        }).join(' | ');
        return '- pregnancy ${pid ?? 'unknown'} (fetal_count: $fetalCount): $details';
      }

      final outcome = (p['outcome'] ?? 'unknown').toString();
      final date = (p['outcome_date'] ?? 'unknown').toString();
      final ga = p['gestational_age_at_end']?.toString();
      return '- pregnancy ${pid ?? 'unknown'} (fetal_count: $fetalCount): $outcome on $date${ga == null ? '' : ', GA end: $ga weeks'}';
    }).toList();

    final previousCheckupLines = previousCheckups.map((c) {
      final date = (c['checkup_datetime'] ?? 'unknown').toString();
      final weight = (c['checkup_weight'] ?? 'n/a').toString();
      final sys = (c['blood_pressure_systolic'] ?? 'n/a').toString();
      final dia = (c['blood_pressure_diastolic'] ?? 'n/a').toString();
      final fhr = (c['fetal_heart_beat'] ?? 'n/a').toString();
      final edema = (c['edema'] ?? 'none').toString();
      return '- $date | wt: $weight kg | BP: $sys/$dia | FHR: $fhr | edema: $edema';
    }).toList();

    final symptomLines = _symptoms
        .map((s) =>
            '- ${s.name} [${s.riskCategory}]${(s.notes ?? '').trim().isEmpty ? '' : ' | note: ${s.notes!.trim()}'}')
        .toList();

    return '''
You are assisting a barangay midwife in the Philippines.
Generate a detailed prenatal risk assessment using ONLY the provided data.
Do not diagnose. Use supportive and safe language suitable for clinical handoff.
State uncertainty clearly when data is missing.
You must consider ALL records together: demographics, comorbidities, allergies, complete past pregnancy history, multifetal history, and prior prenatal trends.

Return plain text with exactly these sections:
RISK LEVEL:
NOTABLE RECORDS:
RISK FACTORS:
SUGGESTIVE ACTIONS:
AI SUMMARY:

Output rules:
- In RISK FACTORS: provide at least 8 bullet points, each tied to specific values/history.
- In SUGGESTIVE ACTIONS: provide 6 to 10 numbered actions, prioritized and concrete.
- In AI SUMMARY: write a 5-8 sentence synthesis referencing the strongest risk drivers, trend concerns, and immediate monitoring priorities.
- Explicitly mention multifetal implications when fetal_count > 1 in current or prior records.
- Explicitly mention recurrent pattern risks (repeated high BP, repeated danger symptoms, recurrent losses) when present.
- Never invent data; only use what is present below.

PATIENT CONTEXT
- Mother ID: ${widget.motherId}
- Pregnancy ID: ${widget.pregnancyId}
- Maternal birthdate: ${mother?['birthdate'] ?? 'unknown'}
- Maternal height: ${mother?['height'] ?? 'unknown'} cm
- Maternal weight baseline: ${mother?['weight'] ?? 'unknown'} kg
- Blood type: ${mother?['blood_type'] ?? 'unknown'}
- Current pregnancy fetal count: $_fetalCount
- Active medical conditions:
${activeConditionLines.isEmpty ? '- none recorded' : activeConditionLines.join('\n')}
- Active allergies:
${activeAllergyLines.isEmpty ? '- none recorded' : activeAllergyLines.join('\n')}
- Past pregnancy records:
${pastPregnancyLines.isEmpty ? '- none recorded' : pastPregnancyLines.join('\n')}
- Previous prenatal checkups:
${previousCheckupLines.isEmpty ? '- none recorded' : previousCheckupLines.join('\n')}
- LMP: ${pregnancy?['last_menstrual_period'] ?? widget.lmp?.toIso8601String().split('T')[0] ?? 'unknown'}
- EDD: ${pregnancy?['expected_date_of_delivery'] ?? 'unknown'}

CURRENT CHECKUP DRAFT
- Checkup datetime: ${_checkupDateTime.toIso8601String()}
- Weight: ${_weightCtrl.text.trim()} kg
- Blood pressure: ${_sysCtrl.text.trim()}/${_diaCtrl.text.trim()} mmHg
- Fetal heart beat: ${_fetalBeatCtrl.text.trim().isEmpty ? 'not recorded' : '${_fetalBeatCtrl.text.trim()} bpm'}
- Fetal position: ${_fetalPosition ?? 'not recorded'}
- Fetal heart tone: ${_fetalTone ?? 'not recorded'}
- Edema: $_edema
- TD dose today: ${_tdDose ?? 'none'}
- Symptoms:
${symptomLines.isEmpty ? '- none recorded' : symptomLines.join('\n')}
- Remarks: ${_remarksCtrl.text.trim().isEmpty ? 'none' : _remarksCtrl.text.trim()}

RULE BASED PRE-ASSESSMENT
- Level: ${draft.level}
- High-risk trigger count: ${draft.score.toStringAsFixed(0)}
- Trigger rule: any high-risk trait => High Risk
- Factors: ${draft.factors.map((f) => '${f.factor} [${f.influence}]').join('; ')}
- Notable records: ${draft.notableRecords.join('; ')}
- Suggested actions: ${draft.suggestedActions.join('; ')}

Make the response practical, accurate, and suitable for a midwife handoff note.
''';
  }

  Future<void> _refreshRiskPreview({bool force = false}) async {
    final signature = _currentRiskSignature();
    if (!force && _lastRiskSignature == signature && _riskSnapshot != null) {
      return;
    }

    final draft = _buildRuleBasedRiskSnapshot();
    setState(() {
      _loadingRiskPreview = true;
      _riskPreviewError = null;
      _riskSnapshot = draft;
    });

    try {
      final prompt = _buildAiPrompt(draft);
      final aiText = await _geminiService.generateTextInsight(
        prompt: prompt,
        temperature: 0.1,
        maxOutputTokens: 2600,
      );

      if (!mounted) return;
      final shouldSyncEditor = force ||
          !_aiAssessmentEdited ||
          _aiAssessmentCtrl.text.trim().isEmpty;
      setState(() {
        final mergedText = _buildMergedAssessmentText(draft, aiText);
        _riskSnapshot = _RiskSnapshot(
          level: draft.level,
          score: draft.score,
          factors: draft.factors,
          notableRecords: draft.notableRecords,
          suggestedActions: draft.suggestedActions,
          aiAssessment: mergedText,
          aiGenerated: true,
          aiModel: 'Gemini 1.5 Flash',
        );
        if (shouldSyncEditor) {
          _syncEditableRiskState(_riskSnapshot!, mergedText);
        }
        _aiResponseApproved = false;
        _lastRiskSignature = signature;
      });
      if (shouldSyncEditor) {
        _aiAssessmentEditCtrl.text = _aiAssessmentCtrl.text;
      }
    } catch (_) {
      if (!mounted) return;
      final shouldSyncEditor = force ||
          !_aiAssessmentEdited ||
          _aiAssessmentCtrl.text.trim().isEmpty;
      setState(() {
        final mergedText = _buildMergedAssessmentText(draft, null);
        _riskSnapshot = _RiskSnapshot(
          level: draft.level,
          score: draft.score,
          factors: draft.factors,
          notableRecords: draft.notableRecords,
          suggestedActions: draft.suggestedActions,
          aiAssessment: mergedText,
          aiGenerated: false,
          aiModel: null,
        );
        _riskPreviewError =
            'AI insight unavailable right now. Showing rule-based assessment.';
        if (shouldSyncEditor) {
          _syncEditableRiskState(_riskSnapshot!, mergedText);
        }
        _aiResponseApproved = false;
        _lastRiskSignature = signature;
      });
      if (shouldSyncEditor) {
        _aiAssessmentEditCtrl.text = _aiAssessmentCtrl.text;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRiskPreview = false);
      }
    }
  }

  @override
  void dispose() {
    _aiAssessmentCtrl.dispose();
    _aiAssessmentEditCtrl.dispose();
    _symptomSearchCtrl.dispose();
    _weightCtrl.dispose();
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _fetalBeatCtrl.dispose();
    _remarksCtrl.dispose();
    _ferrousQtyCtrl.dispose();
    _calciumQtyCtrl.dispose();
    super.dispose();
  }

  List<String> get _availableTdDoses {
    final taken = widget.takenTdDoses
        .map((d) => d.replaceAll(RegExp(r'\s+'), '').toUpperCase())
        .toSet();
    return _tdOptions
        .where((d) => !taken.contains(d.replaceAll(' ', '').toUpperCase()))
        .toList();
  }

  double? get _aogWeeks {
    if (widget.lmp == null) return null;
    final days = _normalizedDate(_checkupDateTime)
        .difference(_normalizedDate(widget.lmp!))
        .inDays;
    if (days < 0) return null;
    return double.parse((days / 7).toStringAsFixed(1));
  }

  _BpStatus get _bpStatus {
    final sys = int.tryParse(_sysCtrl.text.trim());
    final dia = int.tryParse(_diaCtrl.text.trim());

    if (sys == null || dia == null) return _BpStatus.unknown;
    if (sys <= 0 || dia <= 0) return _BpStatus.unknown;

    // Physiological validation
    if (sys <= dia) {
      print('Warning: Systolic ≤ Diastolic - possible measurement error');
      return _BpStatus.unknown;
    }

    // Hypertensive Crisis
    if (sys > 180 || dia > 120) {
      return _BpStatus.stage2;
    }

    // Stage 2 Hypertension
    if (sys > 140 || dia > 90) {
      return _BpStatus.stage2;
    }

    // Stage 1 Hypertension
    if (sys > 130 || dia > 80) {
      return _BpStatus.stage1;
    }

    // Elevated BP
    if (sys > 120 && dia < 80) {
      return _BpStatus.elevated;
    }

    // Hypotension
    if (sys < 90 || dia < 60) {
      return _BpStatus.low;
    }

    // Normal BP
    return _BpStatus.normal;
  }

  DateTime _normalizedDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _prettyDate(DateTime value) {
    return DateFormat('MMM d, yyyy').format(value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6)
          ],
          SizedBox(
            width: 138,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bpBadge() {
    final s = _bpStatus;
    if (s == _BpStatus.unknown) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.color),
          const SizedBox(width: 4),
          Text(s.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: s.color)),
        ],
      ),
    );
  }

  Color _edemaColor(String level) {
    switch (level) {
      case 'mild':
        return Colors.orange.shade300;
      case 'moderate':
        return Colors.orange.shade600;
      case 'severe':
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  Color _riskColor(String riskCategory) {
    switch (riskCategory) {
      case 'danger':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _riskLabel(String riskCategory) {
    switch (riskCategory) {
      case 'danger':
        return 'Danger';
      case 'warning':
        return 'Warning';
      default:
        return 'Normal';
    }
  }

  List<SymptomType> _symptomsByRisk(String riskCategory) {
    final query = _symptomSearchCtrl.text.trim().toLowerCase();
    final grouped = _symptomTypes.where((s) => s.riskCategory == riskCategory);
    if (query.isEmpty) return grouped.toList();

    return grouped
        .where((s) =>
            s.name.toLowerCase().contains(query) ||
            (s.description ?? '').toLowerCase().contains(query))
        .toList();
  }

  bool _isSymptomSelected(int symptomTypeId) {
    return _symptoms.any((s) => s.symptomTypeId == symptomTypeId);
  }

  int get _dangerSymptomCount =>
      _symptoms.where((s) => s.riskCategory == 'danger').length;

  List<String> get _dangerSymptomNames => _symptoms
      .where((s) => s.riskCategory == 'danger')
      .map((s) => s.name)
      .toList();

  bool _passesRiskFilter(String riskCategory) {
    return _symptomRiskFilter == 'all' || _symptomRiskFilter == riskCategory;
  }

  bool _validateCurrentStep() {
    final now = DateTime.now();

    if (_step == 0) {
      if (_checkupDateTime.isAfter(now)) {
        _showMessage('Checkup date and time cannot be in the future.');
        return false;
      }
      if (widget.lmp != null &&
          _normalizedDate(_checkupDateTime)
              .isBefore(_normalizedDate(widget.lmp!))) {
        _showMessage('Checkup date cannot be earlier than LMP.');
        return false;
      }

      final weight = double.tryParse(_weightCtrl.text.trim());
      if (weight == null) {
        setState(() => _weightError = 'Weight is required');
        _showMessage('Weight is required.');
        return false;
      }
      if (weight < 30 || weight > 200) {
        setState(() => _weightError = 'Must be 30 – 200 kg');
        _showMessage('Weight must be between 30 and 200 kg.');
        return false;
      }

      final systolic = int.tryParse(_sysCtrl.text.trim());
      final diastolic = int.tryParse(_diaCtrl.text.trim());
      if (systolic == null || diastolic == null) {
        _showMessage('Enter valid blood pressure values.');
        return false;
      }
      if (systolic < 70 ||
          systolic > 250 ||
          diastolic < 40 ||
          diastolic > 150) {
        _showMessage('Blood pressure values are outside valid clinical range.');
        return false;
      }
      if (systolic <= diastolic) {
        setState(() => _diaError = 'Must be < systolic');
        _showMessage('Systolic pressure must be higher than diastolic.');
        return false;
      }
    }

    if (_step == 1) {
      if (_fetalCount != _originalFetalCount &&
          _fetalCountReasonCtrl.text.trim().isEmpty) {
        setState(
            () => _fetalCountError = 'Required because fetal count changed');
        _showMessage('Please provide a reason for the fetal count change.');
        return false;
      }
      final fetalBeatText = _fetalBeatCtrl.text.trim();
      if (fetalBeatText.isNotEmpty) {
        final fetalBeat = int.tryParse(fetalBeatText);
        if (fetalBeat == null || fetalBeat < 90 || fetalBeat > 200) {
          _showMessage('Fetal heartbeat must be between 90 and 200 bpm.');
          return false;
        }
      }
    }

    if (_step == 3) {
      if (_ferrousError != null || _calciumError != null) {
        _showMessage('Please fix the highlighted field errors.');
        return false;
      }
      final ferrous = _ferrousQtyCtrl.text.trim();
      if (ferrous.isNotEmpty) {
        final qty = int.tryParse(ferrous);
        if (qty == null || qty < 1 || qty > 365) {
          _showMessage('Ferrous + FA quantity must be between 1 and 365.');
          return false;
        }
      }
      final calcium = _calciumQtyCtrl.text.trim();
      if (calcium.isNotEmpty) {
        final qty = int.tryParse(calcium);
        if (qty == null || qty < 1 || qty > 365) {
          _showMessage('Calcium quantity must be between 1 and 365.');
          return false;
        }
      }
    }

    if (_step == 4) {
      if (_nextSchedule != null &&
          !_normalizedDate(_nextSchedule!)
              .isAfter(_normalizedDate(_checkupDateTime))) {
        _showMessage('Next schedule must be after the checkup date.');
        return false;
      }
      if (_remarksCtrl.text.trim().length > 500) {
        _showMessage('Remarks must be 500 characters or less.');
        return false;
      }
    }

    return true;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _checkupDateTime.isAfter(now) ? now : _checkupDateTime,
      firstDate:
          widget.lmp != null ? _normalizedDate(widget.lmp!) : DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: widget.lmp != null
          ? 'Checkup date (LMP: ${_prettyDate(widget.lmp!)})'
          : 'Select checkup date',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_checkupDateTime),
      helpText: 'Select checkup time',
    );
    if (pickedTime == null) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selected.isAfter(now)) {
      _showMessage('Checkup date and time cannot be in the future.');
      return;
    }

    setState(() => _checkupDateTime = selected);
  }

  Future<void> _openSymptomNotesDialog(SymptomType symptomType) async {
    if (_isSymptomSelected(symptomType.id)) {
      _showMessage('${symptomType.name} is already recorded.');
      return;
    }

    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Symptom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symptomType.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _riskColor(symptomType.riskCategory)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _riskColor(symptomType.riskCategory)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _riskLabel(symptomType.riskCategory),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _riskColor(symptomType.riskCategory),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add short clinical note',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        _symptoms.add(
          _SymptomEntry(
            symptomTypeId: symptomType.id,
            name: symptomType.name,
            riskCategory: symptomType.riskCategory,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          ),
        );
      });
    }

    notesCtrl.dispose();
  }

  Future<void> _editSymptomNotesDialog(int index) async {
    final entry = _symptoms[index];
    final notesCtrl = TextEditingController(text: entry.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Symptom Notes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Update short clinical note',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        _symptoms[index] = _SymptomEntry(
          symptomTypeId: entry.symptomTypeId,
          name: entry.name,
          riskCategory: entry.riskCategory,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
      });
    }

    notesCtrl.dispose();
  }

  Future<void> _confirmClearAllSymptoms() async {
    if (_symptoms.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Recorded Symptoms?'),
          content: const Text(
              'This will remove all currently selected symptoms for this checkup form.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _symptoms.clear());
    }
  }

  Widget _buildSymptomGroup({
    required String title,
    required String riskCategory,
  }) {
    if (!_passesRiskFilter(riskCategory)) return const SizedBox.shrink();
    final color = _riskColor(riskCategory);
    final group = _symptomsByRisk(riskCategory);
    if (group.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.map((symptomType) {
              final selected = _isSymptomSelected(symptomType.id);
              return FilterChip(
                label: Text(symptomType.name),
                selected: selected,
                selectedColor: color.withValues(alpha: 0.18),
                checkmarkColor: color,
                side: BorderSide(
                  color: selected
                      ? color.withValues(alpha: 0.55)
                      : color.withValues(alpha: 0.30),
                ),
                labelStyle: TextStyle(
                  color: selected ? color : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (picked) {
                  if (picked) {
                    _openSymptomNotesDialog(symptomType);
                  } else {
                    setState(() => _symptoms.removeWhere(
                        (item) => item.symptomTypeId == symptomType.id));
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNextSchedule() async {
    final baseDate =
        _normalizedDate(_checkupDateTime).add(const Duration(days: 1));
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (_nextSchedule != null && _nextSchedule!.isAfter(baseDate))
          ? _nextSchedule!
          : baseDate,
      firstDate: baseDate,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Must be after ${_prettyDate(_checkupDateTime)}',
    );
    if (picked == null) return;
    setState(() => _nextSchedule = picked);
  }

  Future<void> _openAddMedicationPlanDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final freqCtrl = TextEditingController();

    DateTime? startDate;
    DateTime? endDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Medication Plan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medication name *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantity (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: freqCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Frequency (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startDate == null
                            ? 'Start date (optional)'
                            : 'Start: ${_prettyDate(startDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              startDate ?? _normalizedDate(_checkupDateTime),
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked == null) return;
                        setModalState(() => startDate = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        endDate == null
                            ? 'End date (optional)'
                            : 'End: ${_prettyDate(endDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ??
                              (startDate ?? _normalizedDate(_checkupDateTime)),
                          firstDate: startDate ?? DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked == null) return;
                        setModalState(() => endDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final medName = nameCtrl.text.trim();
                    if (medName.isEmpty) {
                      _showMessage('Medication name is required.');
                      return;
                    }
                    final qtyText = qtyCtrl.text.trim();
                    final qty = qtyText.isEmpty ? null : int.tryParse(qtyText);
                    if (qty != null && (qty < 1 || qty > 365)) {
                      _showMessage(
                          'Medication quantity must be between 1 and 365.');
                      return;
                    }
                    if (startDate != null &&
                        endDate != null &&
                        endDate!.isBefore(startDate!)) {
                      _showMessage(
                          'End date cannot be earlier than start date.');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() {
        _medicationPlans.add(
          _MedicationPlanEntry(
            name: nameCtrl.text.trim(),
            quantity: qtyCtrl.text.trim().isEmpty
                ? null
                : int.tryParse(qtyCtrl.text.trim()),
            frequency:
                freqCtrl.text.trim().isEmpty ? null : freqCtrl.text.trim(),
            startDate: startDate,
            endDate: endDate,
          ),
        );
      });
    }

    nameCtrl.dispose();
    qtyCtrl.dispose();
    freqCtrl.dispose();
  }

  Future<void> _openAddGivenMedicationDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    DateTime givenDate = _normalizedDate(_checkupDateTime);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Given Medication'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medication name *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${_prettyDate(givenDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: givenDate,
                          firstDate: widget.lmp != null
                              ? _normalizedDate(widget.lmp!)
                              : DateTime(2000),
                          lastDate: _normalizedDate(DateTime.now()),
                        );
                        if (picked == null) return;
                        setModalState(() => givenDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final medName = nameCtrl.text.trim();
                    final qty = int.tryParse(qtyCtrl.text.trim());
                    if (medName.isEmpty || qty == null) {
                      _showMessage(
                          'Medication name and quantity are required.');
                      return;
                    }
                    if (qty < 1 || qty > 365) {
                      _showMessage(
                          'Medication quantity must be between 1 and 365.');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() {
        _givenMedications.add(
          _GivenMedicationEntry(
            name: nameCtrl.text.trim(),
            quantity: int.parse(qtyCtrl.text.trim()),
            dateGiven: givenDate,
          ),
        );
      });
    }

    nameCtrl.dispose();
    qtyCtrl.dispose();
  }

  Future<void> _insertMedicationRecords() async {
    final client = Supabase.instance.client;
    final checkupDate = _normalizedDate(_checkupDateTime);

    if (_medicationPlans.isNotEmpty) {
      final payload = _medicationPlans
          .map(
            (entry) => {
              'mother_id': widget.motherId,
              'mother_medication_name': entry.name,
              'frequency': entry.frequency,
              'quantity': entry.quantity,
              'start_date': entry.startDate?.toIso8601String().split('T')[0],
              'end_date': entry.endDate?.toIso8601String().split('T')[0],
              'status': 'active',
            },
          )
          .toList();
      await client.from('mother_medications').insert(payload);
    }

    final givenRows = <Map<String, dynamic>>[];
    for (final entry in _givenMedications) {
      givenRows.add({
        'mother_id': widget.motherId,
        'given_medication_name': entry.name,
        'quantity': entry.quantity,
        'date_given': entry.dateGiven.toIso8601String().split('T')[0],
      });
    }

    final ferrousQty = int.tryParse(_ferrousQtyCtrl.text.trim());
    if (ferrousQty != null && ferrousQty > 0) {
      givenRows.add({
        'mother_id': widget.motherId,
        'given_medication_name': 'Ferrous + FA',
        'quantity': ferrousQty,
        'date_given': checkupDate.toIso8601String().split('T')[0],
      });
    }

    final calciumQty = int.tryParse(_calciumQtyCtrl.text.trim());
    if (calciumQty != null && calciumQty > 0) {
      givenRows.add({
        'mother_id': widget.motherId,
        'given_medication_name': 'Calcium',
        'quantity': calciumQty,
        'date_given': checkupDate.toIso8601String().split('T')[0],
      });
    }

    if (givenRows.isNotEmpty) {
      await client.from('given_medications').insert(givenRows);
    }
  }

  Future<void> _insertSymptomRecords(int prenatalCheckupId) async {
    if (_symptoms.isEmpty) return;
    final payload = _symptoms
        .map(
          (entry) => {
            'pregnancy_id': widget.pregnancyId,
            'prenatal_checkup_id': prenatalCheckupId,
            'symptom_type_id': entry.symptomTypeId,
            'notes': entry.notes,
          },
        )
        .toList();
    await Supabase.instance.client.from('pregnancy_symptoms').insert(payload);
  }

  Future<void> _persistRiskAssessment(int prenatalCheckupId) async {
    final snapshot = _riskSnapshot ?? _buildRuleBasedRiskSnapshot();
    final client = Supabase.instance.client;
    final originalText =
        (_aiOriginalAssessment ?? snapshot.aiAssessment).trim();
    final editedText = _aiAssessmentCtrl.text.trim();
    final finalAiText = editedText.isEmpty ? originalText : editedText;
    final wasEdited = finalAiText != originalText;
    final aiStatus = wasEdited ? 'edited' : 'generated';
    final finalRiskLevel = _editableRiskLevel;
    final finalRiskFactors = List<_RiskFactorItem>.from(_editableRiskFactors);
    final riskManuallyEdited = finalRiskLevel != snapshot.level ||
        !_sameFactorLists(finalRiskFactors, snapshot.factors);

    Map<String, dynamic>? aiRow = await client
        .from('ai_responses')
        .select('ai_response_id')
        .eq('reference_table', 'prenatal_checkups')
        .eq('reference_id', prenatalCheckupId)
        .eq('response_type', 'risk_assessment')
        .maybeSingle();

    int aiResponseId;
    if (aiRow != null) {
      aiResponseId = aiRow['ai_response_id'] as int;
      await client.from('ai_responses').update({
        'ai_model': snapshot.aiModel ?? 'Rule Engine',
        'response': finalAiText,
        'response_category': 'analysis',
        'status': aiStatus,
        'generated_by_ai': snapshot.aiGenerated,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('ai_response_id', aiResponseId);
    } else {
      final insertedAi = await client
          .from('ai_responses')
          .insert({
            'response_type': 'risk_assessment',
            'reference_table': 'prenatal_checkups',
            'reference_id': prenatalCheckupId,
            'ai_model': snapshot.aiModel ?? 'Rule Engine',
            'confidence_score': null,
            'response': finalAiText,
            'response_category': 'analysis',
            'status': aiStatus,
            'generated_by_ai': snapshot.aiGenerated,
          })
          .select('ai_response_id')
          .single();
      aiResponseId = insertedAi['ai_response_id'] as int;
    }

    if (wasEdited) {
      await client.from('ai_edit_history').insert({
        'ai_response_id': aiResponseId,
        'old_content': originalText,
        'new_content': finalAiText,
        'edited_by': _accountId,
        'edit_reason':
            'Midwife updated AI risk assessment before saving checkup.',
      });
    }

    final riskInsert = await client
        .from('pregnancy_risk_assessments')
        .insert({
          'pregnancy_id': widget.pregnancyId,
          'ai_response_id': aiResponseId,
          'risk_level': finalRiskLevel,
          'assessed_by_ai':
              !wasEdited && !riskManuallyEdited && snapshot.aiGenerated,
        })
        .select('pregnancy_risk_id')
        .single();

    final pregnancyRiskId = riskInsert['pregnancy_risk_id'] as int;

    if (finalRiskFactors.isNotEmpty) {
      final factorRows = finalRiskFactors
          .map(
            (f) => {
              'pregnancy_risk_id': pregnancyRiskId,
              'factor': f.factor,
              'risk_influence': f.influence,
              'source_table': f.sourceTable ?? 'prenatal_checkups',
              'source_id': f.sourceId ?? prenatalCheckupId,
            },
          )
          .toList();
      await client.from('pregnancy_risk_factors').insert(factorRows);
    }

    await client
        .from('pregnancies')
        .update({'pregnancy_risk_level': finalRiskLevel}).eq(
            'pregnancy_id', widget.pregnancyId);
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;

    if (_isEditingAiAssessment) {
      _showMessage('Save or discard your risk assessment edits first.');
      return;
    }

    if (!_aiResponseApproved) {
      _showMessage('Approve the AI response first before saving this checkup.');
      return;
    }

    final weight = double.tryParse(_weightCtrl.text.trim());
    final systolic = int.tryParse(_sysCtrl.text.trim());
    final diastolic = int.tryParse(_diaCtrl.text.trim());
    final fetalBeat = int.tryParse(_fetalBeatCtrl.text.trim());

    if (weight == null || systolic == null || diastolic == null) {
      _showMessage('Please complete all required fields.');
      return;
    }

    if (_midwifeId == null) {
      _showMessage(
          'Could not identify midwife. Please log out and log in again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _refreshRiskPreview();

      final checkup = await Supabase.instance.client
          .from('prenatal_checkups')
          .insert({
            'pregnancy_id': widget.pregnancyId,
            'midwife_id': _midwifeId,
            'age_of_gestation': _aogWeeks,
            'checkup_weight': weight,
            'blood_pressure_systolic': systolic,
            'blood_pressure_diastolic': diastolic,
            'fetal_position': _fetalPosition,
            'fetal_heart_beat': fetalBeat,
            'fetal_heart_tone': _fetalTone,
            'td_vaccine_dose': _tdDose,
            'edema': _edema,
            'remarks': _remarksCtrl.text.trim().isEmpty
                ? null
                : _remarksCtrl.text.trim(),
            'checkup_datetime': _checkupDateTime.toIso8601String(),
            'next_schedule': _nextSchedule?.toIso8601String().split('T')[0],
          })
          .select('prenatal_checkup_id')
          .single();

      final prenatalCheckupId = checkup['prenatal_checkup_id'] as int;

      if (_fetalCount != _originalFetalCount) {
        await Supabase.instance.client
            .from('pregnancies')
            .update({'fetal_count': _fetalCount}).eq(
                'pregnancy_id', widget.pregnancyId);

        await Supabase.instance.client.from('audit_trail').insert({
          'action': 'UPDATE',
          'table_name': 'pregnancies',
          'row_id': widget.pregnancyId,
          'old_data': {'fetal_count': _originalFetalCount},
          'new_data': {'fetal_count': _fetalCount},
          'changed_by': _accountId,
          'description':
              'Midwife modified fetal count during checkup. Reason: ${_fetalCountReasonCtrl.text.trim()}',
        });
      }

      await _insertSymptomRecords(prenatalCheckupId);

      await _insertMedicationRecords();

      await _persistRiskAssessment(prenatalCheckupId);

      if (!mounted) return;
      _showMessage('Prenatal checkup saved.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to save prenatal checkup: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      final nextStep = _step + 1;
      setState(() => _step = nextStep);
      if (nextStep == _totalSteps - 1) {
        await _refreshRiskPreview(force: true);
      }
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  Widget _stepTitle() {
    const labels = [
      'Vitals',
      'Fetal Assessment',
      'Pregnancy Symptoms',
      'Medications & TD',
      'Schedule & Remarks',
      'Summary',
      'Risk Assessment',
    ];
    const subtitles = [
      'Date, weight, and blood pressure',
      'Fetal position, heart rate, and edema',
      'Record symptoms and identify serious warning signs',
      'Medication plans, supplements, and TD vaccine',
      'Next visit and remarks',
      'Review before saving',
      'Review and edit AI risk analysis before final save',
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels[_step],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.brandText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitles[_step],
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return _buildStep6();
    }
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Date & Time',
          child: InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 20, color: AppColors.brandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(_checkupDateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(_checkupDateTime),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_aogWeeks != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandPrimary),
                    ),
                    child: Text(
                      '${_aogWeeks!.toStringAsFixed(1)} wks AOG',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Weight',
          child: AppInputField(
            hintText: 'Weight (kg)',
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}(\.\d{0,2})?$')),
            ],
            isRequired: true,
            errorText: _weightError,
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Blood Pressure',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppInputField(
                      hintText: 'Systolic (mmHg)',
                      controller: _sysCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      isRequired: true,
                      errorText: _sysError,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('/',
                      style: TextStyle(
                          fontSize: 22, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppInputField(
                      hintText: 'Diastolic (mmHg)',
                      controller: _diaCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      isRequired: true,
                      errorText: _diaError,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _bpBadge(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Fetal Count',
          child: _loadingFetalCount
              ? const SizedBox(
                  height: 48,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.brandPrimary),
                          onPressed: () {
                            if (_fetalCount > 1) {
                              setState(() {
                                _fetalCount--;
                                _fetalCountError = null;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            '$_fetalCount Fetus${_fetalCount > 1 ? 'es' : ''}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.brandPrimary),
                          onPressed: () {
                            if (_fetalCount < 5) {
                              setState(() {
                                _fetalCount++;
                                _fetalCountError = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_fetalCount != _originalFetalCount) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Reason for change *',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _fetalCountReasonCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'E.g., Vanishing twin, Demise',
                          errorText: _fetalCountError,
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: AppColors.borderPrimary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: AppColors.borderPrimary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: AppColors.brandPrimary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) {
                          if (_fetalCountError != null)
                            setState(() => _fetalCountError = null);
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This change will be logged in the audit trail.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Fetal Position',
          child: DropdownButtonFormField<String>(
            initialValue: _fetalPosition,
            decoration: const InputDecoration(
              hintText: 'Select position',
              border: InputBorder.none,
              isDense: true,
            ),
            items: _fetalPositions
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (value) => setState(() => _fetalPosition = value),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Fetal Heart Rate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInputField(
                hintText: 'Beats per minute (bpm)',
                controller: _fetalBeatCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                errorText: _fetalBeatError,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Normal range: 110 \u2013 160 bpm',
                    style: TextStyle(
                      fontSize: 12,
                      color: () {
                        final v = int.tryParse(_fetalBeatCtrl.text.trim());
                        if (v == null) return AppColors.textSecondary;
                        if (v >= 110 && v <= 160) return AppColors.success;
                        return AppColors.error;
                      }(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Fetal Heart Tone',
          child: DropdownButtonFormField<String>(
            initialValue: _fetalTone,
            decoration: const InputDecoration(
              hintText: 'Select tone',
              border: InputBorder.none,
              isDense: true,
            ),
            items: _fetalTones
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (value) => setState(() => _fetalTone = value),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Edema',
          child: DropdownButtonFormField<String>(
            initialValue: _edema,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
            items: _edemaLevels.map((e) {
              final color = _edemaColor(e);
              return DropdownMenuItem(
                value: e,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(e[0].toUpperCase() + e.substring(1)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _edema = value ?? 'none'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.privacy_tip_outlined,
                  size: 16, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap symptoms to record quickly. Categories are color-coded by risk.',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Symptom Picker',
          child: _loadingSymptomTypes
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _symptomTypes.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No symptom types available.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loadSymptomTypes,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reload Symptoms'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _symptomSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search symptom name',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _symptomSearchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _symptomSearchCtrl.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _symptomRiskFilter == 'all',
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'all');
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Normal'),
                                selected: _symptomRiskFilter == 'normal',
                                selectedColor:
                                    AppColors.success.withValues(alpha: 0.16),
                                side: BorderSide(
                                  color:
                                      AppColors.success.withValues(alpha: 0.35),
                                ),
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'normal');
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Warning'),
                                selected: _symptomRiskFilter == 'warning',
                                selectedColor:
                                    AppColors.warning.withValues(alpha: 0.16),
                                side: BorderSide(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.35),
                                ),
                                onSelected: (_) {
                                  setState(
                                      () => _symptomRiskFilter = 'warning');
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Danger'),
                                selected: _symptomRiskFilter == 'danger',
                                selectedColor:
                                    AppColors.error.withValues(alpha: 0.16),
                                side: BorderSide(
                                  color:
                                      AppColors.error.withValues(alpha: 0.35),
                                ),
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'danger');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSymptomGroup(
                          title: 'NORMAL SYMPTOMS',
                          riskCategory: 'normal',
                        ),
                        _buildSymptomGroup(
                          title: 'WARNING SIGNS',
                          riskCategory: 'warning',
                        ),
                        _buildSymptomGroup(
                          title: 'DANGER SIGNS',
                          riskCategory: 'danger',
                        ),
                      ],
                    ),
        ),
        _sectionCard(
          title: 'Recorded Symptoms',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_symptoms.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _confirmClearAllSymptoms,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear all'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ),
              if (_symptoms.isEmpty)
                Row(
                  children: const [
                    Icon(Icons.healing_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'No symptoms recorded yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else ...[
                if (_dangerSymptomCount > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ' $_dangerSymptomCount danger symptom(s) detected. Consider urgent follow-up.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dangerSymptomNames.join(', '),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._symptoms.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final riskColor = _riskColor(item.riskCategory);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: riskColor.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 52,
                          decoration: BoxDecoration(
                            color: riskColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      _riskLabel(item.riskCategory),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: riskColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor:
                                        riskColor.withValues(alpha: 0.10),
                                    side: BorderSide(
                                        color:
                                            riskColor.withValues(alpha: 0.35)),
                                  ),
                                ],
                              ),
                              if ((item.notes ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.notes!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () => _editSymptomNotesDialog(index),
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.brandPrimary, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Edit notes',
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _symptoms.removeAt(index)),
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove symptom',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Medication Plans',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_medicationPlans.isEmpty)
                Row(
                  children: const [
                    Icon(Icons.medication_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'No medication plans added yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else
                ..._medicationPlans.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final subtitle = [
                    if (item.quantity != null) 'Qty ${item.quantity}',
                    if (item.frequency != null) item.frequency!,
                    if (item.startDate != null)
                      'Start ${_prettyDate(item.startDate!)}',
                    if (item.endDate != null)
                      'End ${_prettyDate(item.endDate!)}',
                  ].join(' · ');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.medication_outlined,
                        color: AppColors.brandPrimary, size: 20),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _medicationPlans.removeAt(index)),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _openAddMedicationPlanDialog,
                  child: const Text('+ Add Plan'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Given Medications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_givenMedications.isEmpty)
                Row(
                  children: const [
                    Icon(Icons.vaccines_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'No medications dispensed yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else
                ..._givenMedications.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.vaccines_outlined,
                        color: AppColors.brandPrimary, size: 20),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Qty ${item.quantity} · ${_prettyDate(item.dateGiven)}'),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _givenMedications.removeAt(index)),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _openAddGivenMedicationDialog,
                  child: const Text('+ Dispense'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Supplements',
          child: Column(
            children: [
              AppInputField(
                hintText: 'Ferrous + FA quantity',
                controller: _ferrousQtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                errorText: _ferrousError,
              ),
              const SizedBox(height: 10),
              AppInputField(
                hintText: 'Calcium quantity',
                controller: _calciumQtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                errorText: _calciumError,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'TD Vaccine',
          child: _availableTdDoses.isEmpty
              ? Row(
                  children: const [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Complete TD vaccination received.',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _tdDose,
                      decoration: const InputDecoration(
                        hintText: 'Select dose given today',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      items: _availableTdDoses
                          .map((dose) =>
                              DropdownMenuItem(value: dose, child: Text(dose)))
                          .toList(),
                      onChanged: (value) => setState(() => _tdDose = value),
                    ),
                    if (widget.takenTdDoses.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: widget.takenTdDoses
                            .map((d) => Chip(
                                  label: Text(d,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppColors.bgSecondary,
                                  side: const BorderSide(
                                      color: AppColors.borderPrimary),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Already given doses shown above.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Next Visit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _pickNextSchedule,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        size: 20, color: AppColors.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nextSchedule == null
                            ? 'Tap to set next schedule (optional)'
                            : DateFormat('MMMM d, yyyy').format(_nextSchedule!),
                        style: TextStyle(
                          fontWeight: _nextSchedule != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _nextSchedule != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_nextSchedule != null)
                      IconButton(
                        onPressed: () => setState(() => _nextSchedule = null),
                        icon: const Icon(Icons.clear,
                            size: 18, color: AppColors.textSecondary),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Must be after today's checkup date.",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Remarks',
          child: TextField(
            controller: _remarksCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Clinical notes, observations (optional)',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderPrimary),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderPrimary),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.brandPrimary),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    final bpText =
        '${_sysCtrl.text.trim().isEmpty ? '-' : _sysCtrl.text.trim()}/'
        '${_diaCtrl.text.trim().isEmpty ? '-' : _diaCtrl.text.trim()} mmHg';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withAlpha(80)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.brandText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review the details below before saving.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brandText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Vitals',
          child: Column(
            children: [
              _summaryRow('Date',
                  DateFormat('MMM d, yyyy h:mm a').format(_checkupDateTime)),
              if (_aogWeeks != null)
                _summaryRow(
                  'AOG',
                  '${_aogWeeks!.toStringAsFixed(1)} weeks',
                  valueColor: AppColors.brandPrimary,
                ),
              _summaryRow('Weight', '${_weightCtrl.text.trim()} kg'),
              _summaryRow('Blood Pressure', bpText),
              const SizedBox(height: 6),
              _bpBadge(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Fetal Assessment',
          child: Column(
            children: [
              _summaryRow('Position', _fetalPosition ?? '-'),
              _summaryRow(
                'Heart Rate',
                _fetalBeatCtrl.text.trim().isEmpty
                    ? 'Not recorded'
                    : '${_fetalBeatCtrl.text.trim()} bpm',
                valueColor: () {
                  final v = int.tryParse(_fetalBeatCtrl.text.trim());
                  if (v == null) return null;
                  return (v >= 110 && v <= 160)
                      ? AppColors.success
                      : AppColors.error;
                }(),
              ),
              _summaryRow('Heart Tone', _fetalTone ?? '-'),
              _summaryRow(
                'Edema',
                _edema[0].toUpperCase() + _edema.substring(1),
                valueColor: _edemaColor(_edema),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Pregnancy Symptoms',
          child: Column(
            children: [
              _summaryRow('Recorded', '${_symptoms.length} symptom(s)'),
              _summaryRow(
                'Danger Flagged',
                '$_dangerSymptomCount symptom(s)',
                valueColor: _dangerSymptomCount > 0
                    ? AppColors.error
                    : AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Medications & Supplements',
          child: Column(
            children: [
              _summaryRow('Plans', '${_medicationPlans.length} item(s)'),
              _summaryRow('Dispensed', '${_givenMedications.length} item(s)'),
              _summaryRow(
                'Ferrous + FA',
                _ferrousQtyCtrl.text.trim().isEmpty
                    ? 'Not given'
                    : 'Qty ${_ferrousQtyCtrl.text.trim()}',
              ),
              _summaryRow(
                'Calcium',
                _calciumQtyCtrl.text.trim().isEmpty
                    ? 'Not given'
                    : 'Qty ${_calciumQtyCtrl.text.trim()}',
              ),
              _summaryRow(
                'TD Vaccine',
                _tdDose ??
                    (_availableTdDoses.isEmpty ? 'Complete' : 'None given'),
                valueColor:
                    _availableTdDoses.isEmpty ? AppColors.success : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Schedule & Remarks',
          child: Column(
            children: [
              _summaryRow(
                'Next Visit',
                _nextSchedule == null
                    ? 'Not set'
                    : DateFormat('MMM d, yyyy').format(_nextSchedule!),
                valueColor:
                    _nextSchedule != null ? AppColors.brandPrimary : null,
              ),
              if (_remarksCtrl.text.trim().isNotEmpty)
                _summaryRow('Remarks', _remarksCtrl.text.trim()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentPhaseChip() {
    if (_loadingRiskPreview) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          SizedBox(width: 6),
          Text(
            'System assessment ready \u2022 AI analysis loading\u2026',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    if (_riskSnapshot?.aiGenerated == true) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 13, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'AI-Enhanced Assessment',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.psychology_alt_outlined,
            size: 13, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Text(
          'System Assessment Only',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStep6() {
    final content = _aiAssessmentCtrl.text.trim().isEmpty
        ? (_riskSnapshot?.aiAssessment ?? '')
        : _aiAssessmentCtrl.text.trim();
    final lineCount = '\n'.allMatches(content).length + 1;
    final editorLines = (lineCount + 2).clamp(4, 22);

    Widget statPill({
      required IconData icon,
      required String label,
      Color? color,
    }) {
      final fg = color ?? AppColors.textSecondary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withAlpha(80)),
          ),
          child: const Row(
            children: [
              Icon(Icons.psychology_alt_outlined,
                  size: 16, color: AppColors.brandText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review and refine the AI risk note before final save.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brandText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Risk Decision Workspace',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_riskSnapshot != null)
                    statPill(
                      icon: Icons.flag_outlined,
                      label: _riskLevelLabel(_riskSnapshot!.level),
                      color: _riskLevelColor(_riskSnapshot!.level),
                    )
                  else
                    statPill(
                      icon: Icons.hourglass_empty_rounded,
                      label: 'Risk Pending',
                    ),
                  if (_riskSnapshot != null)
                    statPill(
                      icon: Icons.speed_rounded,
                      label:
                          'High-risk triggers ${_riskSnapshot!.score.toStringAsFixed(0)}',
                      color: AppColors.brandPrimary,
                    ),
                  statPill(
                    icon: Icons.fact_check_outlined,
                    label: 'Factors ${_editableRiskFactors.length}',
                    color: AppColors.brandAccent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadingRiskPreview
                      ? null
                      : () => _refreshRiskPreview(force: true),
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Refresh AI Assessment'),
                ),
              ),
              if (_loadingRiskPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_riskPreviewError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _riskPreviewError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (_riskSnapshot != null) ...[
                _buildAssessmentPhaseChip(),
                const SizedBox(height: 6),
                const Text(
                  'Triage Override',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Low'),
                      selected: _editableRiskLevel == 'low',
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      onSelected: _isEditingAiAssessment
                          ? (_) => setState(() {
                                _editableRiskLevel = 'low';
                                _aiResponseApproved = false;
                              })
                          : null,
                    ),
                    ChoiceChip(
                      label: const Text('High'),
                      selected: _editableRiskLevel == 'high',
                      selectedColor: AppColors.error.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      onSelected: _isEditingAiAssessment
                          ? (_) => setState(() {
                                _editableRiskLevel = 'high';
                                _aiResponseApproved = false;
                              })
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Signals',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_riskSnapshot!.notableRecords.isEmpty)
                        const Text(
                          'No notable records detected.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _riskSnapshot!.notableRecords.map((r) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.borderPrimary),
                              ),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Risk Factors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_editableRiskFactors.isEmpty)
                        const Text(
                          'No major risk factors identified from current records.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              _editableRiskFactors.asMap().entries.map((e) {
                            final f = e.value;
                            final idx = e.key;
                            final isHigh = f.influence == 'high';
                            return InputChip(
                              label: Text('${f.factor} (${f.influence})'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isHigh
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                              ),
                              selected: isHigh,
                              selectedColor: isHigh
                                  ? AppColors.error.withValues(alpha: 0.14)
                                  : Colors.white,
                              checkmarkColor: AppColors.error,
                              deleteIconColor: isHigh
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              onPressed: _isEditingAiAssessment
                                  ? () => setState(() {
                                        _editableRiskFactors[idx] =
                                            _RiskFactorItem(
                                          factor: f.factor,
                                          influence: isHigh ? 'low' : 'high',
                                          sourceTable: f.sourceTable,
                                          sourceId: f.sourceId,
                                        );
                                        _aiResponseApproved = false;
                                      })
                                  : null,
                              onDeleted: _isEditingAiAssessment
                                  ? () => setState(() {
                                        _editableRiskFactors.removeAt(idx);
                                        _aiResponseApproved = false;
                                      })
                                  : null,
                            );
                          }).toList(),
                        ),
                      if (_isEditingAiAssessment) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => _openAddRiskFactorDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Risk Factor'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Suggested Actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._riskSnapshot!.suggestedActions.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${entry.key + 1}. ${entry.value}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                if (_isEditingAiAssessment) ...[
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 12),
                const Text(
                  'Final Risk Assessment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (!_isEditingAiAssessment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: Text(
                      _aiAssessmentCtrl.text.trim().isEmpty
                          ? _riskSnapshot!.aiAssessment
                          : _aiAssessmentCtrl.text.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: TextField(
                      controller: _aiAssessmentEditCtrl,
                      minLines: editorLines,
                      maxLines: editorLines,
                      decoration: const InputDecoration(
                        hintText: 'Edit the final merged risk assessment note.',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: !_isEditingAiAssessment
                          ? OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _aiAssessmentEditCtrl.text =
                                      _aiAssessmentCtrl.text;
                                  _isEditingAiAssessment = true;
                                  _aiResponseApproved = false;
                                });
                              },
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit Note'),
                            )
                          : OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _aiAssessmentEditCtrl.text =
                                      _aiAssessmentCtrl.text;
                                  _editableRiskLevel = _riskSnapshot!.level;
                                  _editableRiskFactors =
                                      List<_RiskFactorItem>.from(
                                          _riskSnapshot!.factors);
                                  _isEditingAiAssessment = false;
                                });
                              },
                              child: const Text('Discard Changes'),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isEditingAiAssessment
                          ? FilledButton(
                              onPressed: () {
                                final nextText =
                                    _aiAssessmentEditCtrl.text.trim();
                                if (nextText.isEmpty) {
                                  _showMessage(
                                      'Risk assessment text cannot be empty.');
                                  return;
                                }
                                setState(() {
                                  _aiAssessmentCtrl.text = nextText;
                                  _aiAssessmentEdited =
                                      _aiAssessmentCtrl.text.trim() !=
                                          (_aiOriginalAssessment ?? '').trim();
                                  _aiResponseApproved = false;
                                  _isEditingAiAssessment = false;
                                });
                              },
                              child: const Text('Save Note'),
                            )
                          : FilledButton.icon(
                              onPressed: (_riskSnapshot == null ||
                                      _aiAssessmentCtrl.text.trim().isEmpty ||
                                      _isEditingAiAssessment)
                                  ? null
                                  : () {
                                      setState(
                                          () => _aiResponseApproved = true);
                                      _showMessage(
                                          'AI response approved. You can now save the checkup.');
                                    },
                              icon: Icon(_aiResponseApproved
                                  ? Icons.verified_rounded
                                  : Icons.check_circle_outline_rounded),
                              label: Text(
                                  _aiResponseApproved ? 'Approved' : 'Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _aiResponseApproved
                                    ? AppColors.success
                                    : AppColors.brandPrimary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _aiResponseApproved
                          ? Icons.verified_rounded
                          : (_aiAssessmentEdited
                              ? Icons.edit_note_rounded
                              : Icons.smart_toy_outlined),
                      size: 14,
                      color: _aiResponseApproved
                          ? AppColors.success
                          : (_aiAssessmentEdited
                              ? AppColors.brandAccent
                              : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _aiResponseApproved
                            ? 'AI response approved for final save.'
                            : (_aiAssessmentEdited
                                ? 'Edited by midwife. Press Approve to enable saving. Changes are logged in AI edit history.'
                                : 'Review then press Approve AI Response before saving.'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                const Text(
                  'Risk analysis will be prepared based on demographics, pregnancy history, prior checkups, and current values.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAddRiskFactorDialog() async {
    final factorCtrl = TextEditingController();
    String influence = 'low';
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text('Add Risk Factor Chip'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: factorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Risk factor',
                      hintText: 'e.g. Elevated BP trend',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: influence,
                    decoration: const InputDecoration(labelText: 'Influence'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (v) => setS(() => influence = v ?? 'low'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (factorCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true && mounted) {
      setState(() {
        _editableRiskFactors.add(_RiskFactorItem(
          factor: factorCtrl.text.trim(),
          influence: influence,
          sourceTable: 'prenatal_checkups',
        ));
        _aiResponseApproved = false;
      });
    }
    factorCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Add Prenatal Checkup'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              ProgressiveStepIndicator(
                  currentStep: _step, totalSteps: _totalSteps),
              const SizedBox(height: 10),
              _stepTitle(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: _buildStepContent(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _back,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : (_step == _totalSteps - 1
                              ? (_aiResponseApproved ? _submit : null)
                              : _next),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_step == _totalSteps - 1
                              ? (_aiResponseApproved
                                  ? 'Save Checkup'
                                  : 'Approve AI to Save')
                              : 'Next'),
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
}
