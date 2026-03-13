import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_storage.dart';
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
  final _symptomSearchCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _sysCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _fetalBeatCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _ferrousQtyCtrl = TextEditingController();
  final _calciumQtyCtrl = TextEditingController();

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
  static const int _totalSteps = 6;
  bool _submitting = false;
  bool _loadingSymptomTypes = false;
  String _symptomRiskFilter = 'all';
  int? _midwifeId;

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

  Future<void> _loadMidwifeId() async {
    final accountId = await AuthStorage.getUserId();
    if (accountId == null) return;
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

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;

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

      await _insertSymptomRecords(prenatalCheckupId);

      await _insertMedicationRecords();

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

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
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
    ];
    const subtitles = [
      'Date, weight, and blood pressure',
      'Fetal position, heart rate, and edema',
      'Record symptoms and identify serious warning signs',
      'Medication plans, supplements, and TD vaccine',
      'Next visit and remarks',
      'Review before saving',
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
      default:
        return _buildStep5();
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
                    child: Text(
                      '⚠ Danger symptom detected. Consider urgent follow-up.',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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
          child: Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review the details below before saving.',
                  style: TextStyle(fontSize: 13, color: AppColors.info),
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
                          : (_step == _totalSteps - 1 ? _submit : _next),
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
                              ? 'Save Checkup'
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
