// lib/screens/midwife/add_prenatal_checkup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_storage.dart';
import '../../services/groq_service.dart';
import '../../services/weight_gain_engine.dart';
import '../../models/weight_gain_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/confirmation_dialog_box.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_button.dart';
import '../../widgets/app_dropdown_field.dart';

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
    this.isInitialRegistration = false,
  });

  final int motherId;
  final int pregnancyId;
  final DateTime? lmp;
  final double? motherWeight;
  final String? motherEmail;
  final String? generatedPassword;
  final List<String> takenTdDoses;
  final bool isInitialRegistration;

  @override
  State<AddPrenatalCheckupScreen> createState() =>
      _AddPrenatalCheckupScreenState();
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
    required this.factors,
    required this.notableRecords,
    required this.suggestedActions,
    required this.aiAssessment,
    required this.aiGenerated,
    this.aiModel,
  });

  final String level;
  final List<_RiskFactorItem> factors;
  final List<String> notableRecords;
  final List<String> suggestedActions;
  final String aiAssessment;
  final bool aiGenerated;
  final String? aiModel;

  _RiskSnapshot copyWith({
    String? level,
    List<_RiskFactorItem>? factors,
    List<String>? notableRecords,
    List<String>? suggestedActions,
    String? aiAssessment,
    bool? aiGenerated,
    String? aiModel,
  }) {
    return _RiskSnapshot(
      level: level ?? this.level,
      factors: factors ?? this.factors,
      notableRecords: notableRecords ?? this.notableRecords,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      aiAssessment: aiAssessment ?? this.aiAssessment,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      aiModel: aiModel ?? this.aiModel,
    );
  }
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
  final _groqService = GroqService();
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

  int? _fetalCount;
  int? _originalFetalCount;
  bool _loadingFetalCount = true;

  String _edema = 'none';

  final List<_SymptomEntry> _symptoms = [];
  List<SymptomType> _symptomTypes = [];

  bool _aiAnalysisSkipped = false;

  DateTime _checkupDateTime = DateTime.now();
  DateTime? _nextSchedule;

  String? _fetalTone;
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
  String? _lastRiskAiPrompt;
  Map<String, dynamic>? _motherRiskContext;
  String? _aiOriginalAssessment;
  bool _aiAssessmentEdited = false;
  bool _aiResponseApproved = false;
  bool _isEditingAiAssessment = false;
  String _editableRiskLevel = 'low';
  List<_RiskFactorItem> _editableRiskFactors = [];
  List<String> _editableSuggestedActions = [];

  static const List<String> _fetalTones = [
    'Normal',
    'Tachycardia',
    'Bradycardia',
    'Irregular',
    'Muffled',
    'Absent',
    'Other',
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
    _loadLatestCheckupWeight();
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
          .maybeSingle(); // ← FIXED: Changed from .single()

      if (res != null && mounted) {
        final dbFetalCount = res['fetal_count'] as int?;
        setState(() {
          _originalFetalCount = dbFetalCount;
          _fetalCount = dbFetalCount;
          _loadingFetalCount = false;
        });
      } else {
        if (mounted) setState(() => _loadingFetalCount = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFetalCount = false);
    }
  }

  Future<void> _loadLatestCheckupWeight() async {
    try {
      final res = await Supabase.instance.client
          .from('prenatal_checkups')
          .select('checkup_weight')
          .eq('pregnancy_id', widget.pregnancyId)
          .order('checkup_datetime', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && res['checkup_weight'] != null && mounted) {
        final latestWeight = double.tryParse(res['checkup_weight'].toString());
        if (latestWeight != null) {
          setState(() {
            _weightCtrl.text = latestWeight.toStringAsFixed(1);
          });
        }
      }
    } catch (_) {
      // Non-critical: fall back to widget.motherWeight which is already set
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
          .maybeSingle(); // ← FIXED: Changed from .single()

      if (result != null && mounted) {
        setState(() => _midwifeId = result['midwife_id'] as int);
      }
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
            blood_type
          ''').eq('mother_id', widget.motherId).maybeSingle();

      final pregnancy = await client.from('pregnancies').select('''
            pregnancy_id,
            status,
            pregnancy_risk_level,
            last_menstrual_period,
            expected_date_of_delivery,
            pre_pregnancy_weight,
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
              'pregnancy_id, fetal_count, status, created_at')
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
                is_outcome_date_estimated
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
    } catch (e, st) {
      debugPrint('Error loading mother risk context: $e\n$st');
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
      (_fetalCount?.toString() ?? 'null'),
      _edema,
      _weightCtrl.text.trim(),
      _sysCtrl.text.trim(),
      _diaCtrl.text.trim(),
      _fetalBeatCtrl.text.trim(),
      _fetalTone ?? '-',
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
    final cleanedAiText = _sanitizeAiText(aiText);
    if (cleanedAiText.isNotEmpty) {
      // Strip "AI INSIGHTS:" prefix and any section headers that the AI might have added
      return _stripAiSectionHeaders(cleanedAiText);
    }

    return _buildRuleBasedAssessmentText(snapshot);
  }

  String _stripAiSectionHeaders(String text) {
    var result = text;

    // Remove "AI INSIGHTS:" prefix (case insensitive)
    if (result.toUpperCase().startsWith('AI INSIGHTS:')) {
      result = result.substring('AI INSIGHTS:'.length).trim();
    }

    // Remove common section headers that AI might generate
    final sectionHeaders = [
      'OVERALL ASSESSMENT:',
      'OVERALL HEALTH STATUS:',
      'KEY OBSERVATIONS:',
      'RECOMMENDATIONS:',
      'RECOMMENDED NEXT ACTIONS:',
      'CLINICAL IMPRESSION:',
      'FOLLOW-UP SUGGESTIONS:',
      'DETAILED MEASUREMENTS ASSESSMENT:',
      'ANATOMICAL ASSESSMENT:',
      'GESTATIONAL AGE ASSESSMENT:',
      'LABORATORY RESULTS:',
      'ABNORMAL FINDINGS:',
      'NORMAL RANGES:',
      'SUMMARY:',
    ];

    for (final header in sectionHeaders) {
      if (result.toUpperCase().startsWith(header)) {
        result = result.substring(header.length).trim();
        break;
      }
    }

    return result.trim();
  }

  // Replace the _sanitizeAiText method with this:

  String _sanitizeAiText(String? aiText) {
    final trimmed = aiText?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }

    final lower = trimmed.toLowerCase();

    // Check for fallback indicators
    if (lower.contains('ai insight fallback') ||
        lower.contains('ai insight unavailable') ||
        lower.contains('showing rule-based assessment') ||
        lower.contains('unable to generate') ||
        lower.contains('error generating')) {
      return '';
    }

    return trimmed;
  }

  String _buildRuleBasedAssessmentText(_RiskSnapshot snapshot) {
    final currentBp =
        _sysCtrl.text.trim().isEmpty || _diaCtrl.text.trim().isEmpty
            ? 'not recorded'
            : '${_sysCtrl.text.trim()}/${_diaCtrl.text.trim()} mmHg';
    final gaNote = snapshot.notableRecords.firstWhere(
      (note) =>
          note.toLowerCase().contains('current gestational age estimate:'),
      orElse: () => 'Gestational age estimate not available',
    );
    final gaText =
        gaNote.contains(':') ? gaNote.split(':').last.trim() : gaNote;
    final highFactors = snapshot.factors
        .where((f) => f.influence == 'high')
        .map((f) => f.factor)
        .toList();
    final factorSummary =
        snapshot.factors.take(3).map((f) => f.factor).join('; ');
    final keyAction = snapshot.suggestedActions.isNotEmpty
        ? snapshot.suggestedActions.first
        : 'Continue routine prenatal follow-up and monitor for new warning signs.';

    final riskIntro =
        'Risk classification: ${_riskLevelLabel(snapshot.level)} based on current prenatal checkup findings.';
    final findings =
        'Current prenatal findings: gestational age $gaText, blood pressure $currentBp.';
    final concernText = highFactors.isEmpty
        ? 'No abnormal findings are currently detected from available records.'
        : 'Finding(s): ${highFactors.join(', ')}.';
    final summaryText =
        factorSummary.isNotEmpty ? 'Notable items: $factorSummary.' : '';

    return '$riskIntro $findings $concernText $summaryText Priority next step: $keyAction';
  }

  void _syncEditableRiskState(_RiskSnapshot snapshot, String mergedText) {
    _editableRiskLevel = snapshot.level;
    _editableRiskFactors = List<_RiskFactorItem>.from(snapshot.factors);
    _editableSuggestedActions = List<String>.from(snapshot.suggestedActions);
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
    final factors = <_RiskFactorItem>[];
    final notable = <String>[];
    final actions = <String>[];

    final mother = _motherRiskContext?['mother'] as Map<String, dynamic>?;
    final pregnancy = _motherRiskContext?['pregnancy'] as Map<String, dynamic>?;
    final conditions =
        (_motherRiskContext?['medical_conditions'] as List? ?? const [])
            .cast<dynamic>();
    final pastPregnancies =
        (_motherRiskContext?['past_pregnancies'] as List? ?? const [])
            .cast<dynamic>();
    final pastPregnancyOutcomes =
        (_motherRiskContext?['past_pregnancy_outcomes'] as List? ?? const [])
            .cast<dynamic>();

    final currentLmp =
        _tryDate(pregnancy?['last_menstrual_period']) ?? widget.lmp;
    final today = DateTime.now();

    final systolic = int.tryParse(_sysCtrl.text.trim());
    final diastolic = int.tryParse(_diaCtrl.text.trim());
    final fetalBeat = int.tryParse(_fetalBeatCtrl.text.trim());
    final gaCurrent =
        currentLmp != null ? today.difference(currentLmp).inDays ~/ 7 : null;

    if (gaCurrent != null) {
      notable.add('Current gestational age estimate: $gaCurrent weeks');
    }

    // High Risk Triggers (Binary)
    bool isHigh = false;

    // 1. Blood Pressure Thresholds
    if (systolic != null && diastolic != null) {
      notable.add('Current BP: $systolic/$diastolic mmHg');
      if (systolic >= 140 || diastolic >= 90) {
        isHigh = true;
        factors.add(_RiskFactorItem(
          factor: 'High blood pressure (>=140/90)',
          influence: 'high',
        ));
        actions
            .add('Monitor blood pressure closely and screen for preeclampsia.');
      }
    }

    // 2. Fetal Heart Rate Thresholds
    if (fetalBeat != null) {
      notable.add('Fetal heart rate: $fetalBeat bpm');
      if (fetalBeat < 110 || fetalBeat > 160) {
        isHigh = true;
        factors.add(_RiskFactorItem(
          factor: 'Abnormal fetal heart rate ($fetalBeat bpm)',
          influence: 'high',
        ));
        actions.add(
            'Repeat fetal heart monitoring; correlate with fetal movement.');
      }
    }

    // 3. Danger Symptoms
    final dangerSymptomsFiltered =
        _symptoms.where((s) => s.riskCategory == 'danger').toList();
    if (dangerSymptomsFiltered.isNotEmpty) {
      isHigh = true;
      for (final s in dangerSymptomsFiltered) {
        factors.add(_RiskFactorItem(
          factor: 'Danger symptom: ${s.name}',
          influence: 'high',
        ));
      }
      actions.add(
          'Prioritize immediate danger sign protocol and referral if needed.');
    }

    // 5. Medical History & Pregnancy Context (Watch Items)
    final age = _ageFromBirthdate(_tryDate(mother?['birthdate']));
    if (age != null) {
      if (age < 18 || age >= 35) {
        factors.add(_RiskFactorItem(
          factor: 'Maternal age factor ($age years)',
          influence: 'low',
        ));
      }
    }

    if (_fetalCount != null && _fetalCount! > 1) {
      factors.add(_RiskFactorItem(
        factor: 'Multifetal gestation ($_fetalCount)',
        influence: 'low',
      ));
      actions.add(
          'Monitor closely for preterm labor and growth in multifetal pregnancy.');
    }

    for (final row in conditions) {
      final map = row as Map<String, dynamic>;
      if ((map['status'] ?? '').toString().toLowerCase() == 'active') {
        factors.add(_RiskFactorItem(
          factor: 'Condition: ${map['condition_name']}',
          influence: 'low',
        ));
      }
    }

    // 6. IOM Weight Gain — handled by WeightGainEngine (see AI prompt builder)

    final level = isHigh ? 'high' : 'low';

    final dedupedActions = actions.toSet().toList();
    if (dedupedActions.isEmpty) {
      dedupedActions.add('Continue routine prenatal follow-up and monitoring.');
    }

    final fallbackSnapshot = _RiskSnapshot(
      level: level,
      factors: factors,
      notableRecords: notable,
      suggestedActions: dedupedActions,
      aiAssessment: '',
      aiGenerated: false,
      aiModel: null,
    );

    final fallbackAiText = _buildRuleBasedAssessmentText(fallbackSnapshot);

    return _RiskSnapshot(
      level: level,
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
          final method = (o['delivery_method'] ?? '').toString();
          return 'F${e.key + 1}: $outcome on $date${method.isEmpty ? '' : ', method: $method'}';
        }).join(' | ');
        return '- pregnancy ${pid ?? 'unknown'} (fetal_count: $fetalCount): $details';
      }

      final outcome = (p['outcome'] ?? 'unknown').toString();
      final date = (p['outcome_date'] ?? 'unknown').toString();
      return '- pregnancy ${pid ?? 'unknown'} (fetal_count: $fetalCount): $outcome on $date';
    }).toList();

    final previousCheckupLines = previousCheckups.map((c) {
      final date = (c['checkup_datetime'] ?? 'unknown').toString();
      final weight = (c['checkup_weight'] ?? 'n/a').toString();
      final sys = (c['blood_pressure_systolic'] ?? 'n/a').toString();
      final dia = (c['blood_pressure_diastolic'] ?? 'n/a').toString();
      final fhr = (c['fetal_heart_beat'] ?? 'n/a').toString();
      return '- $date | wt: $weight kg | BP: $sys/$dia | FHR: $fhr';
    }).toList();

    final symptomLines = _symptoms
        .map((s) =>
            '- ${s.name} [${s.riskCategory}]${(s.notes ?? '').trim().isEmpty ? '' : ' | note: ${s.notes!.trim()}'}')
        .toList();

    // Calculate Maternal Age
    final maternalAge = _ageFromBirthdate(_tryDate(mother?['birthdate']));

    // Calculate Weight Gain Evaluation inline
    WeightGainResult? wgResult;
    try {
      final currentWeight = double.tryParse(_weightCtrl.text.trim());
      if (currentWeight != null && _aogWeeks != null && _aogWeeks! > 0) {
        final heightCm = mother?['height'] != null ? double.tryParse(mother!['height'].toString()) : null;
        final prePregnancyWeight = pregnancy?['pre_pregnancy_weight'] != null ? double.tryParse(pregnancy!['pre_pregnancy_weight'].toString()) : null;
        final motherWeight = mother?['weight'] != null ? double.tryParse(mother!['weight'].toString()) : null;
        final baselineWeight = prePregnancyWeight ?? motherWeight;
        
        final checkupList = previousCheckups.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        // Ensure the current checkup is part of the longitudinal history so the engine can calculate trends properly.
        checkupList.add({
           'checkup_datetime': _checkupDateTime.toIso8601String(),
           'age_of_gestation': _aogWeeks,
           'checkup_weight': currentWeight,
        });
        checkupList.sort((a, b) => DateTime.parse(a['checkup_datetime']).compareTo(DateTime.parse(b['checkup_datetime'])));
        
        wgResult = WeightGainEngine.evaluate(
          currentWeight: currentWeight,
          aogWeeks: _aogWeeks!,
          allCheckups: checkupList,
          prePregnancyWeight: baselineWeight,
          heightCm: heightCm,
          fetalCount: _fetalCount ?? 1,
        );
      }
    } catch (_) {
      // ignore
    }

    // Compute trimester from gestational age
    final String trimester;
    if (_aogWeeks != null) {
      if (_aogWeeks! <= 12) {
        trimester = '1st trimester';
      } else if (_aogWeeks! <= 27) {
        trimester = '2nd trimester';
      } else {
        trimester = '3rd trimester';
      }
    } else {
      trimester = 'unknown';
    }

    // Compute weight gain trend from previous checkups
    final weightTrendLines = <String>[];
    if (previousCheckups.length >= 2) {
      for (int i = 1; i < previousCheckups.length; i++) {
        final prev = previousCheckups[i - 1];
        final curr = previousCheckups[i];
        final prevW = double.tryParse((prev['checkup_weight'] ?? '').toString());
        final currW = double.tryParse((curr['checkup_weight'] ?? '').toString());
        if (prevW != null && currW != null) {
          final diff = currW - prevW;
          final prevDate = (prev['checkup_datetime'] ?? '').toString();
          final currDate = (curr['checkup_datetime'] ?? '').toString();
          weightTrendLines.add('- $prevDate to $currDate: ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg');
        }
      }
    }

    return '''You are a caring, knowledgeable midwife assistant in the Philippines. You genuinely care about this mother and her baby.

Write as if you are sitting beside the mother, gently explaining what her checkup results mean. Your tone should feel like a trusted ate (older sister) who also happens to be medically trained — warm, personal, but informative.

STYLE GUIDE:
- Start by acknowledging the mother: "Based on your checkup today..."
- When results are normal, celebrate it: "Great news — your blood pressure is looking healthy at 120/80."
- When something needs attention, be honest but gentle: "Your blood pressure is a bit elevated today. This doesn't mean something is wrong, but it's something your midwife will want to keep an eye on."
- Explain WHY things matter, not just WHAT they are: "Your baby's heartbeat at 140 bpm is right in the healthy range — this tells us your little one is active and doing well."
- Include practical advice a Filipino mother can act on: "Try to rest more, eat malunggay and green leafy vegetables, and drink plenty of water."
- End with encouragement and a clear next step.

MATERNAL WEIGHT INTERPRETATION RULES:
- You do NOT compute BMI or weight gain — the system provides those values. You only explain them.
- NEVER use "ideal weight", "perfect weight", "required weight", or "normal pregnancy weight".
- Use softer wording: "commonly expected range", "appears within range", "appears slightly lower/higher than expected".
- NEVER present exact target weights or rigid expectations.
- If pre-pregnancy weight is unavailable (shown as 'unknown'), do NOT mention BMI categories or overweight/obese labels. Add: "Since pre-pregnancy weight was not recorded, these insights are partially estimated."
- For FIRST TRIMESTER (weeks 1-13): note that small weight changes are common. Do NOT judge weight gain/loss harshly.
- For SECOND/THIRD TRIMESTER: you may reference the Weight Gain Engine Assessment if provided, but explain it gently.
- Be weight-sensitive — never shame. Guide positively: "Your weight appears slightly lower than the commonly expected range. Adding an extra nutritious snack each day can help."
- End every weight-related observation with: "This interpretation is for monitoring support only and does not replace professional medical advice."

Always mention the actual measured values (e.g., 'your blood pressure reading of 120/80', 'your weight of 58 kg', 'your baby's heart rate of 142 bpm') and explain what they mean in simple terms.

FORMAT: Write 5-8 sentences as flowing text (not bullet points). End with one sentence starting with "Priority next step:".
DO NOT use section headers, markdown, or structured data. Just write naturally.

Use ONLY the data provided below. State uncertainty clearly when data is missing.
Never invent data.

PATIENT CONTEXT
- Mother ID: ${widget.motherId}
- Pregnancy ID: ${widget.pregnancyId}
- Maternal age: ${maternalAge ?? 'unknown'} years
- Maternal birthdate: ${mother?['birthdate'] ?? 'unknown'}
- Maternal height: ${mother?['height'] ?? 'unknown'} cm
- Pre-pregnancy weight (or baseline): ${pregnancy?['pre_pregnancy_weight'] ?? mother?['weight'] ?? 'unknown'} kg
- Blood type: ${mother?['blood_type'] ?? 'unknown'}
- Current pregnancy fetal count: ${_fetalCount ?? 'unconfirmed'}
- Active medical conditions:
${activeConditionLines.isEmpty ? '- none recorded' : activeConditionLines.join('\n')}
- Active allergies:
${activeAllergyLines.isEmpty ? '- none recorded' : activeAllergyLines.join('\n')}
- Past pregnancy records (including outcomes):
${pastPregnancyLines.isEmpty ? '- none recorded' : pastPregnancyLines.join('\n')}
- Previous prenatal checkups (${previousCheckups.length} total):
${previousCheckupLines.isEmpty ? '- none recorded' : previousCheckupLines.join('\n')}
- Weight gain trend between checkups:
${weightTrendLines.isEmpty ? '- not enough data' : weightTrendLines.join('\n')}
- LMP: ${_formatDate(_effectiveLmp(pregnancy))}
- EDD: ${_formatDate(_effectiveEdd(pregnancy))}
- Age of gestation: ${_aogWeeks?.toStringAsFixed(1) ?? 'unknown'} weeks ($trimester)
- Planned follow-up date: ${_nextSchedule != null ? DateFormat('yyyy-MM-dd').format(_nextSchedule!) : 'none'}

CURRENT CHECKUP DRAFT
- Checkup datetime: ${_checkupDateTime.toIso8601String()}
- Current pregnancy fetal count: ${_fetalCount ?? 'unconfirmed'}
- Weight: ${_weightCtrl.text.trim()} kg
- Weight Gain Engine Assessment: ${wgResult != null ? '${wgResult.status.name.toUpperCase()} - ${wgResult.message}' : 'Not evaluated'}
- Blood pressure: ${_sysCtrl.text.trim()}/${_diaCtrl.text.trim()} mmHg
- Fetal heart beat: ${_fetalBeatCtrl.text.trim().isEmpty ? 'not recorded' : '${_fetalBeatCtrl.text.trim()} bpm'}
- Fetal heart tone: ${_fetalTone ?? 'not recorded'}
- TD dose today: ${_tdDose ?? 'none'}
- Symptoms:
${symptomLines.isEmpty ? '- none recorded' : symptomLines.join('\n')}
- Remarks: ${_remarksCtrl.text.trim().isEmpty ? 'none' : _remarksCtrl.text.trim()}

RULE BASED PRE-ASSESSMENT
- Level: ${draft.level}
- Factors: ${draft.factors.map((f) => '${f.factor} [${f.influence}]').join('; ')}
- Notable records: ${draft.notableRecords.join('; ')}
- Suggested actions: ${draft.suggestedActions.join('; ')}

IMPORTANT: Your response must be PLAIN TEXT with NO SECTION HEADERS. Just write your analysis directly.''';
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
      _lastRiskAiPrompt = prompt;
      final aiText = await _groqService.generateTextInsight(
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

  DateTime? _effectiveLmp([Map<String, dynamic>? pregnancy]) {
    final lmpFromPregnancy = _tryDate(pregnancy?['last_menstrual_period']);
    return lmpFromPregnancy ??
        widget.lmp ??
        _tryDate((_motherRiskContext?['pregnancy']
            as Map<String, dynamic>?)?['last_menstrual_period']);
  }

  DateTime? _effectiveEdd([Map<String, dynamic>? pregnancy]) {
    final eddFromPregnancy = _tryDate(pregnancy?['expected_date_of_delivery']);
    if (eddFromPregnancy != null) return eddFromPregnancy;
    final lmp = _effectiveLmp(pregnancy);
    return lmp?.add(const Duration(days: 280));
  }

  String _formatDate(DateTime? date) {
    return date == null ? 'unknown' : DateFormat('yyyy-MM-dd').format(date);
  }

  double? get _aogWeeks {
    final lmp = _effectiveLmp();
    if (lmp == null) return null;
    final days = _normalizedDate(_checkupDateTime)
        .difference(_normalizedDate(lmp))
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

  void _showMessage(String message,
      {AppSnackType type = AppSnackType.warning}) {
    AppSnackbar.show(context, message, type: type);
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
        return 'Severe';
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
    if (_step == 0) {
      // Date is auto-locked to now, no date validation needed.

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
      // Hypertension warning (non-blocking)
      if (systolic >= 140 || diastolic >= 90) {
        _showMessage(
          'Warning: BP $systolic/$diastolic suggests hypertension. Proceed with caution.',
          type: AppSnackType.warning,
        );
      }
    }

    if (_step == 1) {
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

  Future<void> _openSymptomNotesDialog(SymptomType symptomType) async {
    if (_isSymptomSelected(symptomType.id)) {
      _showMessage('${symptomType.name} is already recorded.');
      return;
    }

    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.brandText),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Add Symptom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.brandText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  symptomType.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _riskColor(symptomType.riskCategory).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _riskColor(symptomType.riskCategory).withValues(alpha: 0.35),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary, width: 1.5),
                  ),
                  child: TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Notes (optional)',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Add Symptom', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
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
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.brandText),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Edit Symptom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.brandText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary, width: 1.5),
                  ),
                  child: TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Notes (optional)',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
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
              return ActionChip(
                label: Text(
                  symptomType.name,
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: selected ? color : Colors.white,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  if (!selected) {
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

    // Ensure initialDate is not on a blocked weekend day
    var initialDate =
        (_nextSchedule != null && _nextSchedule!.isAfter(baseDate))
            ? _nextSchedule!
            : baseDate;
    bool isHoliday(DateTime date) {
      final holidays = <String>[
        '01-01', // New Year's Day
        '02-25', // EDSA Revolution Anniversary
        '04-09', // Araw ng Kagitingan
        '05-01', // Labor Day
        '06-12', // Independence Day
        '08-21', // Ninoy Aquino Day
        '11-01', // All Saints' Day
        '11-02', // All Souls' Day
        '11-30', // Bonifacio Day
        '12-08', // Feast of the Immaculate Conception
        '12-24', // Christmas Eve
        '12-25', // Christmas Day
        '12-30', // Rizal Day
        '12-31', // Last Day of the Year
      ];
      final monthStr = date.month.toString().padLeft(2, '0');
      final dayStr = date.day.toString().padLeft(2, '0');
      return holidays.contains('$monthStr-$dayStr');
    }

    // Advance past weekends and holidays so the picker opens on a valid day
    while (initialDate.weekday == DateTime.saturday ||
        initialDate.weekday == DateTime.sunday ||
        isHoliday(initialDate)) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: baseDate,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Must be after ${_prettyDate(_checkupDateTime)}',
      selectableDayPredicate: (date) {
        // Block weekends — BHCs are typically closed on Sat/Sun
        if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) return false;
        // Block Philippine regular holidays
        if (isHoliday(date)) return false;
        
        return true;
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              onSurface: AppColors.brandText,
              secondary: AppColors.brandPrimary,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: Colors.white,
              elevation: 4,
              surfaceTintColor: Colors.transparent,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: Colors.white,
              headerForegroundColor: AppColors.brandText,
              headerHeadlineStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.brandText,
              ),
              headerHelpStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _nextSchedule = picked);
  }


  Future<void> _insertSupplementRecords() async {
    final client = Supabase.instance.client;
    final checkupDate = _normalizedDate(_checkupDateTime);

    final givenRows = <Map<String, dynamic>>[];

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
    final aiStatus =
        _aiResponseApproved ? 'approved' : (wasEdited ? 'edited' : 'generated');
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
    final bool aiResponseUpdated = aiRow != null;
    if (aiRow != null) {
      aiResponseId = aiRow['ai_response_id'] as int;
      await client.from('ai_responses').update({
        'ai_model': snapshot.aiModel ?? 'Rule Engine',
        'response': finalAiText,
        'response_category': 'analysis',
        'status': aiStatus,
        'generated_by_ai': snapshot.aiGenerated,
        'approved_by': _aiResponseApproved ? _accountId : null,
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
            'approved_by': _aiResponseApproved ? _accountId : null,
          })
          .select('ai_response_id')
          .maybeSingle();

      if (insertedAi == null) return;
      aiResponseId = insertedAi['ai_response_id'] as int;
    }

    if (snapshot.aiGenerated && (_lastRiskAiPrompt ?? '').trim().isNotEmpty) {
      await client.from('ai_prompt_logs').insert({
        'ai_response_id': aiResponseId,
        'prompt': _lastRiskAiPrompt,
        'model_used': snapshot.aiModel ?? 'Rule Engine',
      });
    }

    await client.from('audit_trail').insert({
      'action': aiResponseUpdated ? 'UPDATE' : 'INSERT',
      'table_name': 'ai_responses',
      'account_id': _accountId,
      'old_data': aiResponseUpdated
          ? {
              'status': wasEdited ? 'edited' : 'generated',
              'approved_by': null,
            }
          : null,
      'new_data': {
        'ai_response_id': aiResponseId,
        'status': aiStatus,
        'approved_by': _aiResponseApproved ? _accountId : null,
      },
      'description':
          'Saved AI risk assessment for prenatal checkup $prenatalCheckupId.',
    });

    if (wasEdited) {
      await client.from('ai_edit_history').insert({
        'ai_response_id': aiResponseId,
        'old_content': originalText,
        'new_content': finalAiText,
        'edited_by': _accountId,
        'edit_reason':
            'Midwife updated AI risk assessment before saving checkup.',
      });

      await client.from('audit_trail').insert({
        'action': 'UPDATE',
        'table_name': 'ai_edit_history',
        'account_id': _accountId,
        'old_data': {'content': originalText},
        'new_data': {'content': finalAiText, 'ai_response_id': aiResponseId},
        'description':
            'Midwife edited AI risk assessment content before approval.',
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
        .maybeSingle();

    if (riskInsert == null) return;

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

  /// Evaluates and persists maternal weight gain analysis for this checkup.
  Future<void> _persistWeightGainEvaluation(
      int prenatalCheckupId, double currentWeight) async {
    try {
      // Guard: skip if gestational age is unknown
      final aog = _aogWeeks;
      if (aog == null || aog <= 0) {
        debugPrint(
            'Weight gain evaluation skipped: gestational age unavailable.');
        return;
      }

      final client = Supabase.instance.client;

      // Fetch mother's height from mothers table
      final motherData = await client
          .from('mothers')
          .select('height')
          .eq('mother_id', widget.motherId)
          .maybeSingle();

      // Fetch pre-pregnancy weight and fetal count from pregnancies table
      final pregnancyData = await client
          .from('pregnancies')
          .select('pre_pregnancy_weight, fetal_count')
          .eq('pregnancy_id', widget.pregnancyId)
          .maybeSingle();

      final heightCm = _wgeToDouble(motherData?['height']);
      final prePregnancyWeight =
          _wgeToDouble(pregnancyData?['pre_pregnancy_weight']);
      final fetalCount = (pregnancyData?['fetal_count'] as num?)?.toInt() ?? 1;

      // Fetch all checkups for this pregnancy (ascending order)
      final rawCheckups = await client
          .from('prenatal_checkups')
          .select('checkup_weight, age_of_gestation, checkup_datetime')
          .eq('pregnancy_id', widget.pregnancyId)
          .order('checkup_datetime', ascending: true);

      final checkupList = (rawCheckups as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Run the weight gain engine
      final result = WeightGainEngine.evaluate(
        currentWeight: currentWeight,
        aogWeeks: aog,
        allCheckups: checkupList,
        prePregnancyWeight: prePregnancyWeight,
        heightCm: heightCm,
        fetalCount: fetalCount,
      );

      // Persist evaluation result
      await client.from('weight_gain_evaluations').insert({
        'pregnancy_id': widget.pregnancyId,
        'prenatal_checkup_id': prenatalCheckupId,
        'mode': result.mode == WeightGainMode.full ? 'FULL' : 'TREND',
        'bmi_category': result.bmiCategory,
        'baseline_weight': result.baselineWeight,
        'baseline_week': result.baselineWeek,
        'current_weight': result.currentWeight,
        'current_week': result.currentWeek,
        'expected_gain': result.expectedGain,
        'actual_gain': result.actualGain,
        'weekly_gain': result.weeklyGain,
        'status': result.statusLabel,
        'confidence': result.confidenceLabel,
        'message': result.message,
        'flags': result.flags,
      });

      // Store in ai_responses for AI explanation layer
      await client.from('ai_responses').insert({
        'response_type': 'weight_gain_analysis',
        'reference_table': 'prenatal_checkups',
        'reference_id': prenatalCheckupId,
        'ai_model': 'Weight Gain Engine (IOM 2009)',
        'confidence_score': null,
        'response': result.message,
        'response_category': 'analysis',
        'status': 'generated',
        'generated_by_ai': false,
        'approved_by': null,
      });
    } catch (e) {
      // Non-critical: log but don't block checkup save
      debugPrint('Weight gain evaluation error (non-critical): $e');
    }
  }

  static double? _wgeToDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;

    if (_isEditingAiAssessment) {
      _showMessage('Save or discard your risk assessment edits first.');
      return;
    }

    if (!_aiResponseApproved && !_aiAnalysisSkipped) {
      _showMessage('Approve the AI response or skip AI analysis before saving.');
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

    // Lock checkup datetime to now at submission
    setState(() {
      _submitting = true;
      _checkupDateTime = DateTime.now();
    });
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
            'fetal_heart_beat': fetalBeat,
            'fetal_heart_tone': _fetalTone,
            'td_vaccine_dose': _tdDose,
            'edema': _edema == 'none' ? null : _edema,
            'remarks': _remarksCtrl.text.trim().isEmpty
                ? null
                : _remarksCtrl.text.trim(),
            'checkup_datetime': _checkupDateTime.toIso8601String(),
            'next_schedule': _nextSchedule?.toIso8601String().split('T')[0],
          })
          .select('prenatal_checkup_id')
          .maybeSingle();

      if (checkup == null) {
        throw Exception('Failed to create prenatal checkup record');
      }

      final prenatalCheckupId = checkup['prenatal_checkup_id'] as int;

      await _insertSymptomRecords(prenatalCheckupId);

      await _insertSupplementRecords();

      await _persistRiskAssessment(prenatalCheckupId);

      // Weight Gain Monitoring — evaluate and persist
      await _persistWeightGainEvaluation(prenatalCheckupId, weight);

      if (!mounted) return;
      _showMessage('Prenatal checkup saved.', type: AppSnackType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to save prenatal checkup: $e',
          type: AppSnackType.error);
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
      'Supplements & TD',
      'Schedule & Remarks',
      'Summary',
      'Risk Assessment',
    ];
    const subtitles = [
      'Date, weight, and blood pressure',
      'Fetal heart rate and tone',
      'Record symptoms and identify serious warning signs',
      'Supplements and TD vaccine',
      'Next visit and remarks',
      'Review before saving',
      'Review and edit AI risk analysis before final save',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            labels[_step],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitles[_step],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
    final motherData = _motherRiskContext?['mother'] as Map<String, dynamic>?;
    final motherHeight = motherData?['height']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Date & Time (auto-locked to now)',
          child: Row(
            children: [
              const Icon(Icons.lock_clock,
                  size: 20, color: AppColors.textSecondary),
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
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Height',
          child: AppInputField(
            hintText: 'Height (cm)',
            controller: TextEditingController(text: motherHeight ?? 'Not recorded'),
            readOnly: true,
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
          title: 'Fetal Count (from ultrasound records)',
          child: AppInputField(
            hintText: 'Fetal Count',
            controller: TextEditingController(
                text: _fetalCount == null
                    ? 'Unknown'
                    : '$_fetalCount Fetus${_fetalCount! > 1 ? 'es' : ''}'),
            readOnly: true,
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
          child: AppDropdownField<String>(
            hintText: 'Select tone',
            value: _fetalTone,
            options: _fetalTones,
            displayStringForOption: (t) => t,
            onSelected: (value) => setState(() => _fetalTone = value),
          ),
        ),
      ],
    );
  }

  Widget _iconAvatar(IconData icon, {Color? color}) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1),
            shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color ?? AppColors.brandPrimary),
      );

  Widget _itemCard(
          {required Widget leading,
          required String title,
          required String subtitle,
          required VoidCallback onDelete,
          VoidCallback? onEdit}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: leading,
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.brandPrimary, size: 20),
                    onPressed: onEdit),
              IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  onPressed: onDelete),
            ],
          ),
        ),
      );

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
          title: 'Edema Level',
          child: DropdownButtonFormField<String>(
            value: _edema,
            decoration: const InputDecoration(
              hintText: 'Select edema level',
              border: InputBorder.none,
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'mild', child: Text('Mild (+)')),
              DropdownMenuItem(value: 'moderate', child: Text('Moderate (++)')),
              DropdownMenuItem(value: 'severe', child: Text('Severe (+++)')),
            ],
            onChanged: (value) => setState(() => _edema = value ?? 'none'),
          ),
        ),
        const SizedBox(height: 12),
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
                        AppInputField(
                          hintText: 'Search symptom name',
                          controller: _symptomSearchCtrl,
                          leadingIcon: Icons.search,
                          trailingIcon: _symptomSearchCtrl.text.isEmpty
                              ? null
                              : Icons.clear,
                          onTrailingTap: _symptomSearchCtrl.text.isEmpty
                              ? null
                              : () {
                                  _symptomSearchCtrl.clear();
                                  setState(() {});
                                },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: _symptomRiskFilter == 'all',
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.brandPrimary,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _symptomRiskFilter == 'all' ? Colors.white : AppColors.brandPrimary,
                                ),
                                side: const BorderSide(color: AppColors.brandPrimary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'all');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Normal'),
                                selected: _symptomRiskFilter == 'normal',
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.success,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _symptomRiskFilter == 'normal' ? Colors.white : AppColors.success,
                                ),
                                side: const BorderSide(color: AppColors.success),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'normal');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Warning'),
                                selected: _symptomRiskFilter == 'warning',
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.warning,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _symptomRiskFilter == 'warning' ? Colors.white : AppColors.warning,
                                ),
                                side: const BorderSide(color: AppColors.warning),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onSelected: (_) {
                                  setState(() => _symptomRiskFilter = 'warning');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Severe'),
                                selected: _symptomRiskFilter == 'danger',
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.error,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _symptomRiskFilter == 'danger' ? Colors.white : AppColors.error,
                                ),
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          title: 'SEVERE SIGNS',
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
                          '⚠️ $_dangerSymptomCount severe ${_dangerSymptomCount == 1 ? 'symptom' : 'symptoms'} detected. Consider urgent follow-up.',
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
                  return _itemCard(
                    leading: _iconAvatar(Icons.healing_outlined, color: riskColor),
                    title: item.name,
                    subtitle: '${_riskLabel(item.riskCategory)}${(item.notes?.isNotEmpty == true) ? ' - ${item.notes}' : ''}',
                    onEdit: () => _editSymptomNotesDialog(index),
                    onDelete: () => setState(() => _symptoms.removeAt(index)),
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
                    AppDropdownField<String>(
                      hintText: 'Select dose given today',
                      value: _tdDose,
                      options: _availableTdDoses,
                      displayStringForOption: (t) => t,
                      onSelected: (value) => setState(() => _tdDose = value),
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
              AppInputField(
                hintText: 'Tap to set next schedule (optional)',
                controller: TextEditingController(
                  text: _nextSchedule == null
                      ? ''
                      : DateFormat('MMMM d, yyyy').format(_nextSchedule!),
                ),
                readOnly: true,
                onTap: _pickNextSchedule,
                leadingIcon: Icons.calendar_month,
                trailingIcon: _nextSchedule != null ? Icons.clear : null,
                onTrailingTap: _nextSchedule != null
                    ? () => setState(() => _nextSchedule = null)
                    : null,
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
            color: AppColors.brandPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.brandText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review all entered values below before proceeding.',
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
          title: 'VITALS',
          child: Column(
            children: [
              _summaryRow('Checkup Date',
                  DateFormat('MMM d, yyyy h:mm a').format(_checkupDateTime)),
              if (_aogWeeks != null)
                _summaryRow(
                  'AOG',
                  '${_aogWeeks!.toStringAsFixed(1)} weeks',
                  valueColor: AppColors.brandPrimary,
                ),
              _summaryRow('Weight',
                  _weightCtrl.text.trim().isEmpty ? 'Not recorded' : '${_weightCtrl.text.trim()} kg'),
              _summaryRow('Blood Pressure', bpText),
              _summaryRow(
                'Fetal Heart Rate',
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
              _summaryRow('Heart Tone', _fetalTone ?? 'Not recorded'),
              const SizedBox(height: 6),
              _bpBadge(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'SYMPTOMS & EDEMA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Edema Level', _edema == 'none'
                  ? 'None'
                  : '${_edema[0].toUpperCase()}${_edema.substring(1)}'),
              const SizedBox(height: 4),
              if (_symptoms.isEmpty)
                _summaryRow('Symptoms', 'None recorded')
              else ...[
                const Text(
                  'Symptoms:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ..._symptoms.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _riskColor(s.riskCategory),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s.name} -- ${_riskLabel(s.riskCategory)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _riskColor(s.riskCategory),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              if (_dangerSymptomCount > 0) ...[
                const SizedBox(height: 6),
                _summaryRow(
                  'Danger Flagged',
                  '$_dangerSymptomCount: ${_dangerSymptomNames.join(", ")}',
                  valueColor: AppColors.error,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'SUPPLEMENTS & TD VACCINE',
          child: Column(
            children: [
              _summaryRow(
                'Ferrous + FA',
                _ferrousQtyCtrl.text.trim().isEmpty
                    ? 'Not given'
                    : '${_ferrousQtyCtrl.text.trim()} tablet${(int.tryParse(_ferrousQtyCtrl.text.trim()) ?? 0) != 1 ? 's' : ''}',
              ),
              _summaryRow(
                'Calcium',
                _calciumQtyCtrl.text.trim().isEmpty
                    ? 'Not given'
                    : '${_calciumQtyCtrl.text.trim()} tablet${(int.tryParse(_calciumQtyCtrl.text.trim()) ?? 0) != 1 ? 's' : ''}',
              ),
              _summaryRow(
                'TD Vaccine Dose',
                _tdDose ??
                    (_availableTdDoses.isEmpty ? 'Complete (all doses given)' : 'None given today'),
                valueColor:
                    _availableTdDoses.isEmpty ? AppColors.success : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'SCHEDULE & REMARKS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow(
                'Next Appointment',
                _nextSchedule == null
                    ? 'Not set'
                    : DateFormat('MMMM d, yyyy').format(_nextSchedule!),
                valueColor:
                    _nextSchedule != null ? AppColors.brandPrimary : null,
              ),
              _summaryRow(
                'Remarks',
                _remarksCtrl.text.trim().isEmpty
                    ? 'None'
                    : _remarksCtrl.text.trim(),
              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.faintWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.brandText),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review the risk summary and care plan before saving this prenatal checkup.',
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
          title: 'Assessment Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
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
                      icon: Icons.checklist_rtl_rounded,
                      label:
                          '${_riskSnapshot!.factors.where((f) => f.influence == "high").length} Major Concerns',
                      color: _riskSnapshot!.level == 'high'
                          ? AppColors.error
                          : AppColors.brandPrimary,
                    ),
                  statPill(
                    icon: Icons.fact_check_outlined,
                    label: 'Risk Factors ${_editableRiskFactors.length}',
                    color: AppColors.brandAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Review the AI assessment, care priority, and recommended action plan for this visit.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loadingRiskPreview
                        ? null
                        : () => _refreshRiskPreview(force: true),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh AI Assessment'),
                  ),
                ],
              ),
              if (_loadingRiskPreview) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (_riskPreviewError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _riskPreviewError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.faintWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Risk Level',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Low'),
                          selected: _editableRiskLevel == 'low',
                          selectedColor:
                              AppColors.success.withValues(alpha: 0.14),
                          labelStyle:
                              const TextStyle(color: AppColors.textPrimary),
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
                          selectedColor:
                              AppColors.error.withValues(alpha: 0.14),
                          labelStyle:
                              const TextStyle(color: AppColors.textPrimary),
                          onSelected: _isEditingAiAssessment
                              ? (_) => setState(() {
                                    _editableRiskLevel = 'high';
                                    _aiResponseApproved = false;
                                  })
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.faintWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Factors & Actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_editableRiskFactors.isEmpty)
                      const Text(
                        'No major risk factors identified from current records.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _editableRiskFactors.asMap().entries.map(
                          (e) {
                            final f = e.value;
                            final idx = e.key;
                            final isHigh = f.influence == 'high';
                            return InputChip(
                              label: Text('${f.factor} (${f.influence})'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isHigh ? FontWeight.w700 : FontWeight.w500,
                                color: isHigh
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                              ),
                              backgroundColor: isHigh
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : AppColors.success.withValues(alpha: 0.12),
                              side: BorderSide(
                                color: isHigh
                                    ? AppColors.error.withValues(alpha: 0.35)
                                    : AppColors.success.withValues(alpha: 0.35),
                              ),
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
                          },
                        ).toList(),
                      ),
                    if (_isEditingAiAssessment) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _openAddRiskFactorDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Risk Factor'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'AI Insights (Editable)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              if (!_isEditingAiAssessment)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.faintWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Text(
                    content.isEmpty
                        ? 'AI insights will appear here once the assessment is generated.'
                        : content,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: TextField(
                    controller: _aiAssessmentEditCtrl,
                    minLines: editorLines,
                    maxLines: editorLines,
                    decoration: const InputDecoration(
                      hintText:
                          'Edit AI insights only (no duplicate system lists).',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
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
                            label: const Text('Edit Insights'),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isEditingAiAssessment
                        ? FilledButton(
                            onPressed: () {
                              final nextText =
                                  _aiAssessmentEditCtrl.text.trim();
                              if (nextText.isEmpty) {
                                _showMessage('AI insights cannot be empty.');
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
                            child: const Text('Save Insights'),
                          )
                        : FilledButton.icon(
                            onPressed: (_riskSnapshot == null ||
                                    _aiAssessmentCtrl.text.trim().isEmpty ||
                                    _isEditingAiAssessment)
                                ? null
                                : () {
                                    setState(() => _aiResponseApproved = true);
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
              const SizedBox(height: 12),
              // Chip: AI Generated / Reviewed by Midwife
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (_aiAssessmentEdited || _aiResponseApproved)
                          ? AppColors.brandPrimary.withValues(alpha: 0.12)
                          : (_riskSnapshot?.aiGenerated == true
                              ? AppColors.info.withValues(alpha: 0.12)
                              : AppColors.textSecondary.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_aiAssessmentEdited || _aiResponseApproved)
                            ? AppColors.brandPrimary.withValues(alpha: 0.4)
                            : (_riskSnapshot?.aiGenerated == true
                                ? AppColors.info.withValues(alpha: 0.4)
                                : AppColors.textSecondary.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (_aiAssessmentEdited || _aiResponseApproved)
                              ? Icons.verified_user_rounded
                              : Icons.smart_toy_outlined,
                          size: 14,
                          color: (_aiAssessmentEdited || _aiResponseApproved)
                              ? AppColors.brandPrimary
                              : (_riskSnapshot?.aiGenerated == true
                                  ? AppColors.info
                                  : AppColors.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (_aiAssessmentEdited || _aiResponseApproved)
                              ? 'Reviewed by Midwife'
                              : 'AI Generated',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (_aiAssessmentEdited || _aiResponseApproved)
                                ? AppColors.brandPrimary
                                : (_riskSnapshot?.aiGenerated == true
                                    ? AppColors.info
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _aiResponseApproved
                        ? Icons.verified_rounded
                        : (_aiAnalysisSkipped
                            ? Icons.skip_next_rounded
                            : (_aiAssessmentEdited
                                ? Icons.edit_note_rounded
                                : Icons.smart_toy_outlined)),
                    size: 14,
                    color: _aiResponseApproved
                        ? AppColors.success
                        : (_aiAnalysisSkipped
                            ? AppColors.warning
                            : (_aiAssessmentEdited
                                ? AppColors.brandAccent
                                : AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aiResponseApproved
                          ? 'AI response approved for final save.'
                          : (_aiAnalysisSkipped
                              ? 'AI analysis skipped. Rule-based assessment will be saved.'
                              : (_aiAssessmentEdited
                                  ? 'Edited by midwife. Press Approve to enable saving. Changes are logged in AI edit history.'
                                  : 'Review then press Approve AI Response, or skip AI analysis to save with rule-based assessment only.')),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_aiResponseApproved && !_aiAnalysisSkipped) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isEditingAiAssessment
                        ? null
                        : () {
                            setState(() {
                              _aiAnalysisSkipped = true;
                              // Use rule-based snapshot if no AI was generated
                              final ruleSnapshot = _buildRuleBasedRiskSnapshot();
                              _syncEditableRiskState(ruleSnapshot, ruleSnapshot.aiAssessment);
                              _riskSnapshot = ruleSnapshot;
                            });
                            _showMessage(
                                'AI analysis skipped. You can now save with rule-based assessment.',
                                type: AppSnackType.warning);
                          },
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('Skip AI Analysis'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
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
                    initialValue: influence,
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

  Future<void> _openAddSuggestedActionDialog() async {
    final actionCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Suggested Action'),
          content: TextField(
            controller: actionCtrl,
            decoration: const InputDecoration(
              labelText: 'Action',
              hintText: 'e.g. Schedule follow-up in 2 weeks',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (actionCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == true && mounted) {
      setState(() {
        _editableSuggestedActions.add(actionCtrl.text.trim());
        _riskSnapshot = _riskSnapshot?.copyWith(
          suggestedActions: List<String>.from(_editableSuggestedActions),
        );
        _aiResponseApproved = false;
      });
    }
    actionCtrl.dispose();
  }

  bool get _hasEnteredData =>
      _weightCtrl.text.trim().isNotEmpty ||
      _sysCtrl.text.trim().isNotEmpty ||
      _diaCtrl.text.trim().isNotEmpty ||
      _fetalBeatCtrl.text.trim().isNotEmpty ||
      _symptoms.isNotEmpty ||
      _remarksCtrl.text.trim().isNotEmpty ||
      _ferrousQtyCtrl.text.trim().isNotEmpty ||
      _calciumQtyCtrl.text.trim().isNotEmpty;

  Future<bool> _showSkipCheckupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialogBox(
        title: 'Skip Initial Checkup?',
        subtitle:
            'The initial prenatal checkup is required to complete the '
            'mother\'s registration. Skipping will leave her record '
            'incomplete.\n\nAre you sure you want to skip?',
        cancelText: 'Continue Checkup',
        confirmText: 'Skip',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showDiscardCheckupDialog() async {
    if (!_hasEnteredData) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialogBox(
        title: 'Discard changes?',
        subtitle:
            'You have unsaved prenatal checkup data. Are you sure you want to go back?',
        cancelText: 'Cancel',
        confirmText: 'Discard',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  void _backOrPop() async {
    if (widget.isInitialRegistration) {
      final shouldSkip = await _showSkipCheckupDialog();
      if (shouldSkip && mounted) Navigator.pop(context);
    } else {
      final shouldDiscard = await _showDiscardCheckupDialog();
      if (shouldDiscard && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _backOrPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              SecondaryHeader(
                title: 'Add Prenatal Checkup',
                onBack: _backOrPop,
              ),
              LinearProgressIndicator(
                value: (_step + 1) / _totalSteps,
                backgroundColor: AppColors.borderPrimary,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                minHeight: 3,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _stepTitle(),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, -4))
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: MainButton(
                        label: 'Back',
                        leftIcon: Icons.arrow_back_ios_new_rounded,
                        isWhiteVariant: true,
                        onPressed: _submitting ? null : _back,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: (_step > 0) ? 2 : 1,
                    child: _step == _totalSteps - 1
                        ? MainButton(
                            label: (_aiResponseApproved || _aiAnalysisSkipped)
                                ? 'Save Checkup'
                                : 'Approve AI to Save',
                            rightIcon: (_aiResponseApproved || _aiAnalysisSkipped)
                                ? Icons.check_rounded
                                : Icons.arrow_forward_ios_rounded,
                            onPressed: _submitting
                                ? null
                                : ((_aiResponseApproved || _aiAnalysisSkipped)
                                    ? _submit
                                    : null),
                          )
                        : MainButton(
                            label: 'Next',
                            rightIcon: Icons.arrow_forward_ios_rounded,
                            onPressed: _submitting ? null : _next,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
