// lib/screens/midwife/midwife_add_mother_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/ocr_result.dart';
import '../../services/auth_storage.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/progressive_step_indicator.dart';
import '../../widgets/dialog_box.dart';
import 'add_prenatal_checkup_screen.dart';

// ──────────────── Enums & Data Models ────────────────

enum _GestationMethod { lmp, edd, aog }

enum _OcrDialogState { loading, results, error }

class _EmergencyContact {
  String firstName = '';
  String? middleName;
  String lastName = '';
  String? extensionName;
  String phoneNumber = '';
  String? affiliation;

  bool get isValid =>
      firstName.isNotEmpty && lastName.isNotEmpty && phoneNumber.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'extension_name': extensionName,
        'phone_number': phoneNumber,
        'affiliation': affiliation,
      };
}

class _MedicalCondition {
  final String conditionName;
  DateTime? diagnosisDate;
  String status = 'active';
  String? remarks;

  _MedicalCondition(this.conditionName);

  Map<String, dynamic> toMap() => {
        'condition_name': conditionName,
        'diagnosis_date': diagnosisDate?.toIso8601String().split('T')[0],
        'status': status,
        'remarks': remarks,
      };
}

class _Allergy {
  final String allergen;
  DateTime? diagnosisDate;
  String status = 'active';
  String? treatment;
  String? remarks;

  _Allergy(this.allergen);

  Map<String, dynamic> toMap() => {
        'allergen': allergen,
        'diagnosis_date': diagnosisDate?.toIso8601String().split('T')[0],
        'status': status,
        'treatment': treatment,
        'remarks': remarks,
      };
}

class _PastFetalOutcome {
  String outcome;
  DateTime outcomeDate;
  bool isEstimated = false;
  String? placeOfDelivery;
  String? deliveryMethod;

  _PastFetalOutcome({required this.outcome, required this.outcomeDate});

  Map<String, dynamic> toMap() => {
        'outcome': outcome,
        'outcome_date': outcomeDate.toIso8601String().split('T')[0],
        'is_outcome_date_estimated': isEstimated,
        'place_of_delivery': placeOfDelivery,
        'delivery_method': deliveryMethod,
      };
}

class _PastPregnancy {
  int fetalCount = 1;
  double? gestationalAgeAtEnd;
  List<_PastFetalOutcome> outcomes = [];

  _PastPregnancy({String? outcome, DateTime? outcomeDate}) {
    if (outcome != null && outcomeDate != null) {
      outcomes = [
        _PastFetalOutcome(outcome: outcome, outcomeDate: outcomeDate),
      ];
    }
  }

  _PastFetalOutcome _ensurePrimaryOutcome() {
    if (outcomes.isEmpty) {
      outcomes.add(
        _PastFetalOutcome(outcome: 'live_birth', outcomeDate: DateTime.now()),
      );
    }
    return outcomes.first;
  }

  _PastFetalOutcome _latestOutcomeRef() {
    final primary = _ensurePrimaryOutcome();
    if (outcomes.length == 1) return primary;
    return outcomes.reduce(
      (a, b) => a.outcomeDate.isAfter(b.outcomeDate) ? a : b,
    );
  }

  DateTime get earliestOutcomeDate {
    if (outcomes.isEmpty) return DateTime.now();
    return outcomes
        .map((o) => o.outcomeDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime get latestOutcomeDate {
    if (outcomes.isEmpty) return DateTime.now();
    return outcomes
        .map((o) => o.outcomeDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get primaryOutcome =>
      outcomes.isNotEmpty ? _latestOutcomeRef().outcome : 'live_birth';
  DateTime get primaryOutcomeDate => latestOutcomeDate;

  String get outcome => primaryOutcome;
  set outcome(String value) => _latestOutcomeRef().outcome = value;

  DateTime get outcomeDate => primaryOutcomeDate;
  set outcomeDate(DateTime value) => _latestOutcomeRef().outcomeDate = value;

  bool get isEstimated =>
      outcomes.isNotEmpty ? _latestOutcomeRef().isEstimated : false;
  set isEstimated(bool value) => _latestOutcomeRef().isEstimated = value;

  String? get placeOfDelivery =>
      outcomes.isNotEmpty ? _latestOutcomeRef().placeOfDelivery : null;
  set placeOfDelivery(String? value) =>
      _latestOutcomeRef().placeOfDelivery = value;

  String? get deliveryMethod =>
      outcomes.isNotEmpty ? _latestOutcomeRef().deliveryMethod : null;
  set deliveryMethod(String? value) =>
      _latestOutcomeRef().deliveryMethod = value;

  Map<String, dynamic> toMap() => {
        'fetal_count': fetalCount,
        'gestational_age_at_end': gestationalAgeAtEnd,
        'outcomes': outcomes.map((o) => o.toMap()).toList(),
      };
}

// ──────────────── Screen ────────────────

class MidwifeAddMotherScreen extends StatefulWidget {
  const MidwifeAddMotherScreen({super.key});

  @override
  State<MidwifeAddMotherScreen> createState() => _MidwifeAddMotherScreenState();
}

class _MidwifeAddMotherScreenState extends State<MidwifeAddMotherScreen> {
  // ── Context ──────────────────────────────────────────
  int? _midwifeId;
  int? _assignedBhcId;
  String _bhcName = '';
  bool _loadingContext = true;

  // ── Navigation ───────────────────────────────────────
  int _step = 0;
  static const int _totalSteps = 9;
  bool _submitting = false;
  final _pageController = PageController();

  // ── Formatters ───────────────────────────────────────
  final _dateFmt = DateFormat('MMMM d, yyyy');

  // ── Step 0 : Personal & Account ─────────────────────
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _phoneError, _emailError;
  bool _emailChecking = false, _emailExists = false;
  Timer? _emailTimer;
  String? _lastEmailChecked;
  bool _isEmailReadOnly = false;
  bool _isExistingSelfRegistered = false;

  // ── Auto-fill existing account ──────────────────────
  int? _existingAccountId;
  int? _existingMotherId;
  bool _isUpdatingExisting = false;
  bool _checkingAccount = false;

  // ── Step 1 : Address ────────────────────────────────
  bool _addressSameAsBhc = true;
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  String? _selectedBarangay;
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();

  static const _bhcBarangays = [
    'San Jose',
    'Tarcan',
    'Sta. Barbara',
    'Tiaong',
    'Pinagbarilan',
  ];

  // ── Step 2 : Emergency Contacts ─────────────────────
  final List<_EmergencyContact> _emergencyContacts = [];

  // ── Step 3 : Vital Statistics ───────────────────────
  DateTime? _birthdate;
  final _birthdateCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodType;

  // ── Step 4 : Medical Conditions ─────────────────────
  final List<_MedicalCondition> _medicalConditions = [];

  // ── Step 5 : Allergies ──────────────────────────────
  final List<_Allergy> _allergies = [];

  // ── Step 6 : Pregnancy History ──────────────────────
  bool _hasPastPregnancy = false;
  final List<_PastPregnancy> _pastPregnancies = [];

  // ── Step 7 : Gestational Info ───────────────────────
  _GestationMethod _gestationMethod = _GestationMethod.lmp;
  final _lmpCtrl = TextEditingController();
  final _eddCtrl = TextEditingController();
  final _aogWeeksCtrl = TextEditingController();
  final _aogDaysCtrl = TextEditingController();
  final _fetalCountCtrl = TextEditingController(text: '1');
  DateTime? _lmp;
  DateTime? _edd;

  // ── OCR ─────────────────────────────────────────────
  final _geminiService = GeminiService();

  // ── Lifecycle ───────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailTimer?.cancel();
    for (final c in [
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _extNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _houseCtrl,
      _streetCtrl,
      _barangayCtrl,
      _cityCtrl,
      _provinceCtrl,
      _birthdateCtrl,
      _heightCtrl,
      _weightCtrl,
      _lmpCtrl,
      _eddCtrl,
      _aogWeeksCtrl,
      _aogDaysCtrl,
      _fetalCountCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Context ──────────────────────────────────────────

  Future<void> _loadContext() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) throw Exception('Not authenticated');
      final result = await SupabaseService.getMidwifeContext(accountId);
      if (result['success'] == true) {
        _midwifeId = result['midwife_id'] as int;
        _assignedBhcId = result['assigned_bhc_id'] as int;
        _bhcName = result['bhc_name'] as String;
        _applyBhcAddress();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load context: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
  }

  // ── Auto-fill existing account ──────────────────────

  Future<void> _checkExistingAccount() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    if (_existingAccountId != null) return;

    setState(() => _checkingAccount = true);

    try {
      final result = await SupabaseService.getExistingMotherAccount(email);

      if (result['exists']) {
        if (!result['has_bhc']) {
          _existingAccountId = result['account_id'];
          _existingMotherId = result['mother_id'];
          _isExistingSelfRegistered = true;

          final existingData = result['data'];

// In _checkExistingAccount() method, find the AlertDialog and update:

final shouldLoad = await showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    title: const Text('Existing Account Found'),
    content: Text(
      'An account already exists for ${existingData['email_address']}.\n\n'
      'This account was created by the mother but is incomplete.\n\n'
      'Would you like to load the existing data and complete the missing information?'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(ctx, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Load & Continue', style: TextStyle(fontSize: 14)),
      ),
    ],
  ),
);
          if (shouldLoad == true) {
            // Personal Information
            _firstNameCtrl.text = existingData['first_name'] ?? '';
            _middleNameCtrl.text = existingData['middle_name'] ?? '';
            _lastNameCtrl.text = existingData['last_name'] ?? '';
            _extNameCtrl.text = existingData['extension_name'] ?? '';
            _phoneCtrl.text = existingData['phone_number'] ?? '';
            _isEmailReadOnly = true;

            // Vitals
            if (existingData['birthdate'] != null) {
              _birthdate = DateTime.tryParse(existingData['birthdate']);
              if (_birthdate != null) {
                _birthdateCtrl.text = _dateFmt.format(_birthdate!);
              }
            }
            if (existingData['height'] != null) {
              _heightCtrl.text = existingData['height'].toString();
            }
            if (existingData['weight'] != null) {
              _weightCtrl.text = existingData['weight'].toString();
            }
            if (existingData['blood_type'] != null) {
              _bloodType = existingData['blood_type'];
            }

            // Address
            if (existingData['house_number'] != null &&
                existingData['house_number'].toString().isNotEmpty) {
              _houseCtrl.text = existingData['house_number'].toString();
            }
            if (existingData['street'] != null &&
                existingData['street'].toString().isNotEmpty) {
              _streetCtrl.text = existingData['street'].toString();
            }
            if (existingData['barangay'] != null &&
                existingData['barangay'].toString().isNotEmpty) {
              _selectedBarangay = existingData['barangay'].toString();
              _barangayCtrl.text = existingData['barangay'].toString();
              _addressSameAsBhc = false;
            }
            if (existingData['city_municipality'] != null &&
                existingData['city_municipality'].toString().isNotEmpty) {
              _cityCtrl.text = existingData['city_municipality'].toString();
              _addressSameAsBhc = false;
            }
            if (existingData['province'] != null &&
                existingData['province'].toString().isNotEmpty) {
              _provinceCtrl.text = existingData['province'].toString();
              _addressSameAsBhc = false;
            }

            // Gestational information from existing pregnancy
            if (_existingMotherId != null) {
              final pregnancyData = await SupabaseService.client
                  .from('pregnancies')
                  .select(
                      'last_menstrual_period, expected_date_of_delivery, status')
                  .eq('mother_id', _existingMotherId!)
                  .eq('status', 'ongoing')
                  .maybeSingle();

              if (pregnancyData != null) {
                final lmpStr =
                    pregnancyData['last_menstrual_period'] as String?;
                final eddStr =
                    pregnancyData['expected_date_of_delivery'] as String?;

                if (lmpStr != null && lmpStr.isNotEmpty) {
                  final lmpDate = DateTime.tryParse(lmpStr);
                  if (lmpDate != null) {
                    _updateFromLmp(lmpDate);
                  }
                } else if (eddStr != null && eddStr.isNotEmpty) {
                  final eddDate = DateTime.tryParse(eddStr);
                  if (eddDate != null) {
                    _updateFromEdd(eddDate);
                  }
                }
              }
            }

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Existing data loaded. Please complete the missing information.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            _isUpdatingExisting = true;
          } else {
            _existingAccountId = null;
            _existingMotherId = null;
            _isExistingSelfRegistered = false;
          }
        } else {
          _emailExists = true;
          _emailError = 'This mother is already registered to a BHC';
        }
      }
    } catch (e) {
      _existingAccountId = null;
      _existingMotherId = null;
      _isUpdatingExisting = false;
      _isExistingSelfRegistered = false;
    } finally {
      if (mounted) {
        setState(() => _checkingAccount = false);
      }
    }
  }

  // ── Email ────────────────────────────────────────────

  void _onEmailChanged(String v) {
    final value = v.trim();
    if (value.isEmpty) {
      _emailTimer?.cancel();
      setState(() {
        _emailChecking = false;
        _emailExists = false;
        _emailError = null;
      });
      _existingAccountId = null;
      _existingMotherId = null;
      _isUpdatingExisting = false;
      _isEmailReadOnly = false;
      _isExistingSelfRegistered = false;
      return;
    }
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    setState(() => _emailError = valid ? null : 'Enter a valid email');
    if (!valid) {
      _emailTimer?.cancel();
      _emailChecking = false;
      _emailExists = false;
      return;
    }
    _emailTimer?.cancel();
    setState(() => _emailChecking = true);
    _emailTimer = Timer(
      const Duration(milliseconds: 600),
      () => _checkEmail(value),
    );
    _checkExistingAccount();
  }

  Future<void> _checkEmail(String email) async {
    _lastEmailChecked = email;
    final available = await SupabaseService.isEmailAvailable(email);
    if (_lastEmailChecked != email || !mounted) return;
    setState(() {
      _emailChecking = false;
      if (!_isUpdatingExisting && !_isExistingSelfRegistered) {
        _emailExists = !available;
        _emailError = available ? null : 'Email already in use';
      }
    });
  }

  // ── Phone ────────────────────────────────────────────

  void _onPhoneChanged(String v) {
    final normalized = v.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final valid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(
      () => _phoneError =
          v.trim().isEmpty ? null : (valid ? null : 'Enter a valid PH number'),
    );
  }

  // ── Address ──────────────────────────────────────────

  void _applyBhcAddress() {
    _selectedBarangay = _bhcName;
    _barangayCtrl.text = _bhcName;
    _cityCtrl.text = 'Baliwag';
    _provinceCtrl.text = 'Bulacan';
  }

  // ── Gestation ────────────────────────────────────────

  void _updateFromLmp(DateTime lmp) {
    _lmp = lmp;
    _edd = lmp.add(const Duration(days: 280));
    _lmpCtrl.text = _dateFmt.format(lmp);
    _eddCtrl.text = _dateFmt.format(_edd!);
    _gestationMethod = _GestationMethod.lmp;
  }

  void _updateFromEdd(DateTime edd) {
    _edd = edd;
    _lmp = edd.subtract(const Duration(days: 280));
    _eddCtrl.text = _dateFmt.format(edd);
    _lmpCtrl.text = _dateFmt.format(_lmp!);
    _gestationMethod = _GestationMethod.edd;
  }

  void _updateFromAog() {
    final w = int.tryParse(_aogWeeksCtrl.text.trim()) ?? 0;
    final d = int.tryParse(_aogDaysCtrl.text.trim()) ?? 0;
    if (w <= 0 && d <= 0) return;
    final lmp = DateTime.now().subtract(Duration(days: w * 7 + d));
    _updateFromLmp(lmp);
    _gestationMethod = _GestationMethod.aog;
  }

  String _formatAog() {
    if (_lmp == null) return '-';
    final days = DateTime.now().difference(_lmp!).inDays;
    if (days < 0) return '-';
    return '${days ~/ 7}w ${days % 7}d';
  }

  String? _computeIntervalError(DateTime date, {int? excludeIndex}) {
    const minGapDays = 42;
    for (int i = 0; i < _pastPregnancies.length; i++) {
      if (i == excludeIndex) continue;
      final gap =
          date.difference(_pastPregnancies[i].latestOutcomeDate).inDays.abs();
      if (gap < minGapDays) {
        return 'Only ${gap}d from another record (minimum: $minGapDays days)';
      }
    }
    return null;
  }

  // ── Validation ───────────────────────────────────────

  bool _validateStep(int step) {
    String? msg;
    switch (step) {
      case 0:
        final issues = <String>[];
        if (_firstNameCtrl.text.trim().isEmpty) issues.add('First Name');
        if (_lastNameCtrl.text.trim().isEmpty) issues.add('Last Name');
        if (_phoneCtrl.text.trim().isEmpty) {
          issues.add('Phone Number');
        } else if (_phoneError != null) {
          issues.add('Phone (invalid)');
        }
        if (_emailCtrl.text.trim().isEmpty) {
          issues.add('Email Address');
        } else if (_emailChecking) {
          issues.add('Email (still checking)');
        } else if (_emailExists &&
            !_isUpdatingExisting &&
            !_isExistingSelfRegistered) {
          issues.add('Email (already in use)');
        } else if (_emailError != null) {
          issues.add('Email (invalid)');
        }
        if (issues.isNotEmpty) msg = 'Please fix: ${issues.join(', ')}.';
        break;

      case 1:
        if (_houseCtrl.text.trim().isEmpty) {
          msg = 'House number is required.';
          break;
        }
        if (_streetCtrl.text.trim().isEmpty) {
          msg = 'Street is required.';
          break;
        }
        if (!_addressSameAsBhc) {
          if ((_selectedBarangay ?? '').isEmpty ||
              _cityCtrl.text.trim().isEmpty ||
              _provinceCtrl.text.trim().isEmpty) {
            msg = 'Barangay, city, and province are required.';
          }
        }
        break;

      case 3:
        final issues = <String>[];
        if (_birthdate == null) {
          issues.add('Birthdate');
        } else {
          final age =
              (DateTime.now().difference(_birthdate!).inDays / 365.25).floor();
          if (age < 10 || age > 50) {
            issues.add(
                'Maternal age ($age yrs) is outside the possible range for pregnancy (10–50 yrs)');
          }
        }
        if (double.tryParse(_heightCtrl.text.trim()) == null) {
          issues.add('Height (cm)');
        } else {
          final h = double.parse(_heightCtrl.text.trim());
          if (h < 100 || h > 220) {
            issues.add(
                'Height must be between 100–220 cm (entered: ${h.toStringAsFixed(0)} cm)');
          }
        }
        if (double.tryParse(_weightCtrl.text.trim()) == null) {
          issues.add('Weight (kg)');
        } else {
          final w = double.parse(_weightCtrl.text.trim());
          if (w < 30 || w > 200) {
            issues.add(
                'Weight must be between 30–200 kg (entered: ${w.toStringAsFixed(0)} kg)');
          }
        }
        if (issues.isNotEmpty) msg = 'Please fix: ${issues.join('; ')}.';
        break;

      case 7:
        if (_gestationMethod == _GestationMethod.lmp && _lmp == null) {
          msg = 'Select an LMP date.';
        } else if (_gestationMethod == _GestationMethod.edd && _edd == null) {
          msg = 'Select an EDD date.';
        } else if (_gestationMethod == _GestationMethod.aog &&
            _aogWeeksCtrl.text.trim().isEmpty &&
            _aogDaysCtrl.text.trim().isEmpty) {
          msg = 'Enter gestation in weeks or days.';
        } else if (_lmp == null || _edd == null) {
          msg = 'Unable to compute LMP and EDD. Please re-enter.';
        }
        break;

      case 8:
        if (_midwifeId == null || _assignedBhcId == null) {
          msg = 'Midwife context is missing. Please go back and retry.';
        }
        break;
    }

    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  // ── Navigation ───────────────────────────────────────

  void _goNext() {
    if (!_validateStep(_step)) return;
    if (_step < _totalSteps - 1) {
      _pageController.animateToPage(
        _step + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    }
  }

  void _goBack() {
    if (_step > 0) {
      _pageController.animateToPage(
        _step - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  // ── Submit ───────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validateStep(8)) return;

    if (_houseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('House number is required'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_streetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Street is required'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      Map<String, dynamic> result;

      if (_isUpdatingExisting && _existingMotherId != null) {
        result = await SupabaseService.updateExistingMotherAccount(
          motherId: _existingMotherId!,
          assignedBhcId: _assignedBhcId!,
          houseNumber: _houseCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          barangay: _selectedBarangay,
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty
              ? null
              : _provinceCtrl.text.trim(),
          heightCm: double.tryParse(_heightCtrl.text.trim()),
          weightKg: double.tryParse(_weightCtrl.text.trim()),
          bloodType: _bloodType,
          lmp: _lmp,
          edd: _edd,
          emergencyContacts: _emergencyContacts.map((e) => e.toMap()).toList(),
          medicalConditions: _medicalConditions.map((m) => m.toMap()).toList(),
          allergies: _allergies.map((a) => a.toMap()).toList(),
          pastPregnancies: _pastPregnancies.map((p) => p.toMap()).toList(),
          fetalCount: int.tryParse(_fetalCountCtrl.text.trim()) ?? 1,
        );
      } else {
        result = await SupabaseService.addMotherFullByMidwifeWithAutoPassword(
          midwifeId: _midwifeId!,
          assignedBhcId: _assignedBhcId!,
          email: _emailCtrl.text.trim(),
          firstName: _firstNameCtrl.text.trim(),
          middleName: _middleNameCtrl.text.trim().isEmpty
              ? null
              : _middleNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          extensionName: _extNameCtrl.text.trim().isEmpty
              ? null
              : _extNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          houseNumber: _houseCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          barangay: _selectedBarangay,
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty
              ? null
              : _provinceCtrl.text.trim(),
          birthdate: _birthdate,
          heightCm: double.tryParse(_heightCtrl.text.trim()),
          weightKg: double.tryParse(_weightCtrl.text.trim()),
          bloodType: _bloodType,
          lmp: _lmp,
          edd: _edd,
          emergencyContacts: _emergencyContacts.map((e) => e.toMap()).toList(),
          medicalConditions: _medicalConditions.map((m) => m.toMap()).toList(),
          allergies: _allergies.map((a) => a.toMap()).toList(),
          pastPregnancies: _pastPregnancies.map((p) => p.toMap()).toList(),
          fetalCount: int.tryParse(_fetalCountCtrl.text.trim()) ?? 1,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        final motherId = result['mother_id'] as int?;
        final pregnancyId = result['pregnancy_id'] as int?;

        final successMessage = _isUpdatingExisting
            ? 'Mother account updated successfully!'
            : (result['email_sent'] == true
                ? 'Mother account created successfully!\n\nA temporary password has been sent to ${_emailCtrl.text.trim()}.'
                : 'Mother account created but email failed to send.\n\nPassword: ${result['generated_password']}');

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogBox(
            type: DialogType.success,
            title: _isUpdatingExisting
                ? 'Account Updated'
                : 'Mother Account Created',
            content: successMessage,
            buttonText: 'OK',
            onPressed: () => Navigator.pop(context),
          ),
        );

        if (motherId != null && pregnancyId != null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddPrenatalCheckupScreen(
                  motherId: motherId,
                  pregnancyId: pregnancyId,
                  lmp: _lmp,
                  motherWeight: double.tryParse(_weightCtrl.text.trim()),
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to save.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step titles ──────────────────────────────────────

  static const _stepTitles = [
    'Personal Information',
    'Address Information',
    'Emergency Contacts',
    'Vital Statistics',
    'Medical Conditions',
    'Allergies',
    'Pregnancy History',
    'Gestational Information',
    'Summary & Submit',
  ];

  static const _stepSubtitles = [
    'Name, phone, email and login credentials',
    'Current place of residence',
    'Who to contact in an emergency',
    'Age, height, weight and blood type',
    'Known diagnoses and health conditions',
    'Known allergens and reactions',
    'Previous pregnancy outcomes',
    'Current pregnancy dating',
    'Review before saving',
  ];

  // ── Step content ─────────────────────────────────────

  Widget _pageFor(int index) {
    final content = switch (index) {
      0 => _stepPersonal(),
      1 => _stepAddress(),
      2 => _stepEmergencyContacts(),
      3 => _stepVitals(),
      4 => _stepMedicalConditions(),
      5 => _stepAllergies(),
      6 => _stepPregnancyHistory(),
      7 => _stepGestational(),
      _ => _stepSummary(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: content,
    );
  }

  // ──────────────── Step 0 : Personal ────────────────

  Widget _stepPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Full Name'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'First Name',
                controller: _firstNameCtrl,
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Middle',
                controller: _middleNameCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'Last Name',
                controller: _lastNameCtrl,
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Ext. (Jr., III)',
                controller: _extNameCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z\s\-\.\,]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel('Contact'),
        AppInputField(
          hintText: 'Phone Number',
          controller: _phoneCtrl,
          isRequired: true,
          leadingIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          errorText: _phoneError,
        ),
        const SizedBox(height: 24),
        _sectionLabel('Account Credentials'),
        AppInputField(
          hintText: 'Email Address',
          controller: _emailCtrl,
          isRequired: true,
          leadingIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
          errorText: _emailError,
          readOnly: _isEmailReadOnly,
        ),
        if (_emailChecking) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.brandAccent,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Checking availability...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_checkingAccount) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.brandAccent,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Checking for existing account...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Password will be auto-generated',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A secure temporary password will be sent to the mother\'s email address.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────── Step 1 : Address ────────────────

  Widget _stepAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_outlined,
                color: AppColors.brandAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assigned BHC: ${_bhcName.isEmpty ? '-' : _bhcName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Address Type'),
        _addressOption(
          title: 'Same as BHC address',
          subtitle:
              'Bulacan - Baliwag - ${_bhcName.isEmpty ? 'Assigned barangay' : _bhcName}',
          selected: _addressSameAsBhc,
          onTap: () => setState(() {
            _addressSameAsBhc = true;
            _applyBhcAddress();
          }),
        ),
        const SizedBox(height: 8),
        _addressOption(
          title: 'Custom address',
          subtitle: 'Enter a different barangay, city or province',
          selected: !_addressSameAsBhc,
          onTap: () => setState(() {
            _addressSameAsBhc = false;
            _selectedBarangay = null;
            _barangayCtrl.clear();
          }),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Address Details'),
        AppInputField(
          hintText: 'House No. *',
          controller: _houseCtrl,
          isRequired: true,
          leadingIcon: Icons.home_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Street *',
          controller: _streetCtrl,
          isRequired: true,
          leadingIcon: Icons.streetview_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_addressSameAsBhc)
          AppInputField(
            hintText: 'Barangay',
            controller: _barangayCtrl,
            leadingIcon: Icons.location_on_outlined,
            readOnly: true,
            onChanged: (_) {},
          )
        else
          _styledDropdown(
            hint: 'Barangay *',
            value: _selectedBarangay,
            items: _bhcBarangays,
            icon: Icons.location_on_outlined,
            onChanged: (v) => setState(() => _selectedBarangay = v),
          ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'City / Municipality',
          controller: _cityCtrl,
          readOnly: _addressSameAsBhc,
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Province',
          controller: _provinceCtrl,
          readOnly: _addressSameAsBhc,
          onChanged: (_) {},
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'House number and street are required fields for the mother\'s address.',
                  style: TextStyle(fontSize: 12, color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────── Step 2 : Emergency Contacts ────────────────

  Widget _stepEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Emergency Contacts',
          subtitle: 'Optional - skip if not available',
          actionLabel: 'Add Contact',
          onAction: _showAddEmergencyContact,
        ),
        const SizedBox(height: 12),
        if (_emergencyContacts.isEmpty)
          _emptyState(
            Icons.contacts_outlined,
            'No emergency contacts added.\nYou can skip this step.',
          )
        else
          ..._emergencyContacts.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.person_outline),
                  title: '${e.value.firstName} ${e.value.lastName}',
                  subtitle: [
                    e.value.phoneNumber,
                    if (e.value.affiliation != null) e.value.affiliation!,
                  ].join(' - '),
                  onDelete: () =>
                      setState(() => _emergencyContacts.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // ──────────────── Step 3 : Vitals ────────────────

  Widget _stepVitals() {
    final age = _birthdate != null
        ? (DateTime.now().difference(_birthdate!).inDays / 365.25).floor()
        : null;
    final h = double.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);
    final bmi =
        (h != null && w != null && h > 0) ? w / ((h / 100) * (h / 100)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Birthdate'),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthdate ?? DateTime(1990),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _birthdate = picked;
                _birthdateCtrl.text = _dateFmt.format(picked);
              });
            }
          },
          child: IgnorePointer(
            child: AppInputField(
              hintText: 'Birthdate',
              controller: _birthdateCtrl,
              isRequired: true,
              leadingIcon: Icons.cake_outlined,
              readOnly: true,
              onChanged: (_) {},
            ),
          ),
        ),
        if (age != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Age: $age years old',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (age < 10 || age > 50)
            _riskHint(
              'Maternal age ($age yrs) is outside the possible range (10–50).',
              isError: true,
            )
          else if (age < 18)
            _riskHint('High-risk: adolescent pregnancy (under 18).')
          else if (age > 35)
            _riskHint('Advanced maternal age (>35) — high-risk pregnancy.'),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Body Measurements'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInputField(
                hintText: 'Height (cm)',
                controller: _heightCtrl,
                isRequired: true,
                leadingIcon: Icons.straighten_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInputField(
                hintText: 'Weight (kg)',
                controller: _weightCtrl,
                isRequired: true,
                leadingIcon: Icons.monitor_weight_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (bmi != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Text(
                  'BMI: ${bmi.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _bmiTag(bmi),
              ],
            ),
          ),
          if (h != null && (h < 100 || h > 220))
            _riskHint(
              'Height (${h.toStringAsFixed(0)} cm) is outside the possible range (100–220 cm).',
              isError: true,
            )
          else if (h != null && h < 140)
            _riskHint('Unusually short height (<140 cm) — verify entry.'),
          if (w != null && (w < 30 || w > 200))
            _riskHint(
              'Weight (${w.toStringAsFixed(0)} kg) is outside the possible range (30–200 kg).',
              isError: true,
            )
          else if (w != null && w < 46)
            _riskHint('Low weight (<46 kg) — high-risk nutrition concern.')
          else if (w != null && w > 90)
            _riskHint('High weight (>90 kg) — high-risk for complications.'),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Blood Type (optional)'),
        _styledDropdown(
          hint: 'Select Blood Type',
          value: _bloodType,
          items: const [
            'A+',
            'A-',
            'B+',
            'B-',
            'AB+',
            'AB-',
            'O+',
            'O-',
            'Unknown'
          ],
          icon: Icons.bloodtype_outlined,
          onChanged: (v) => setState(() => _bloodType = v),
        ),
      ],
    );
  }

  // ──────────────── Step 4 : Medical Conditions ────────────────

  Widget _stepMedicalConditions() {
    const common = [
      'Anemia',
      'Diabetes',
      'Hypertension',
      'Smoking',
      'Alcohol Use',
      'Domestic Violence',
      'Bleeding Postpartum',
      'Prolonged Labor',
      'Other',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Medical Conditions',
          subtitle: 'Tap a chip to quick-add or use the button',
          actionLabel: 'Add',
          onAction: () => _showAddMedicalCondition(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: common
              .map(
                (c) => GestureDetector(
                  onTap: () => _showAddMedicalCondition(prefill: c),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderPrimary),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add,
                            size: 13, color: AppColors.brandAccent),
                        const SizedBox(width: 5),
                        Text(c,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        if (_medicalConditions.isEmpty)
          _emptyState(
            Icons.medical_services_outlined,
            'No conditions added.\nSkip if not applicable.',
          )
        else
          ..._medicalConditions.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.medical_services_outlined),
                  title: e.value.conditionName,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.diagnosisDate != null)
                      _dateFmt.format(e.value.diagnosisDate!),
                    if (e.value.remarks != null) e.value.remarks!,
                  ].join(' - '),
                  onDelete: () =>
                      setState(() => _medicalConditions.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // ──────────────── Step 5 : Allergies ────────────────

  Widget _stepAllergies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Allergies',
          subtitle: 'Optional - skip if none',
          actionLabel: 'Add Allergy',
          onAction: _showAddAllergy,
        ),
        const SizedBox(height: 12),
        if (_allergies.isEmpty)
          _emptyState(
            Icons.no_food_outlined,
            'No allergies recorded.\nSkip if not applicable.',
          )
        else
          ..._allergies.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.warning_amber_outlined,
                      color: AppColors.warning),
                  title: e.value.allergen,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.treatment != null) e.value.treatment!,
                  ].join(' - '),
                  onDelete: () => setState(() => _allergies.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // ──────────────── Step 6 : Pregnancy History ────────────────

  Widget _stepPregnancyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
          child: SwitchListTile(
            title: const Text(
              'Had previous pregnancies?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Toggle on to log past pregnancy records'),
            value: _hasPastPregnancy,
            activeThumbColor: AppColors.brandPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onChanged: (v) => setState(() {
              _hasPastPregnancy = v;
              if (!v) _pastPregnancies.clear();
            }),
          ),
        ),
        if (_hasPastPregnancy) ...[
          const SizedBox(height: 16),
          _listHeader(
            title: 'Past Pregnancies',
            subtitle: 'Add each previous pregnancy record',
            actionLabel: 'Add',
            onAction: _showAddPastPregnancy,
          ),
          const SizedBox(height: 8),
          if (_pastPregnancies.isEmpty)
            _emptyState(
              Icons.history_outlined,
              'No records yet. Add at least one.',
            )
          else
            ..._pastPregnancies.asMap().entries.map((e) {
              final p = e.value;
              return _itemCard(
                leading: _iconAvatar(Icons.pregnant_woman_outlined),
                title: _pastPregnancyTitle(p),
                subtitle: _pastPregnancySubtitle(p),
                onDelete: () =>
                    setState(() => _pastPregnancies.removeAt(e.key)),
              );
            }),
        ],
      ],
    );
  }

  // ──────────────── Step 7 : Gestational ────────────────

  Widget _stepGestational() {
    final methodItems = const ['lmp', 'edd', 'aog'];
    final methodLabels = const [
      'Last Menstrual Period (LMP)',
      'Estimated Delivery Date (EDD)',
      'Age of Gestation (AOG)',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Calculation Method'),
        _styledDropdown(
          hint: 'Select method',
          value: _gestationMethod.name,
          items: methodItems,
          itemLabels: methodLabels,
          icon: Icons.calculate_outlined,
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _gestationMethod =
                  _GestationMethod.values.firstWhere((e) => e.name == v);
            });
          },
        ),
        const SizedBox(height: 20),
        _sectionLabel('Date Entry'),
        if (_gestationMethod == _GestationMethod.lmp)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _lmp ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _updateFromLmp(picked));
            },
            child: IgnorePointer(
              child: AppInputField(
                hintText: 'Last Menstrual Period',
                controller: _lmpCtrl,
                isRequired: true,
                leadingIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onChanged: (_) {},
              ),
            ),
          )
        else if (_gestationMethod == _GestationMethod.edd)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _edd ?? DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 300)),
              );
              if (picked != null) setState(() => _updateFromEdd(picked));
            },
            child: IgnorePointer(
              child: AppInputField(
                hintText: 'Estimated Delivery Date',
                controller: _eddCtrl,
                isRequired: true,
                leadingIcon: Icons.event_available_outlined,
                readOnly: true,
                onChanged: (_) {},
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  hintText: 'Weeks',
                  controller: _aogWeeksCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _updateFromAog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  hintText: 'Days',
                  controller: _aogDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _updateFromAog(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        _sectionLabel('Fetal Details'),
        AppInputField(
          hintText: 'Fetal Count (e.g., 1 for single, 2 for twins)',
          controller: _fetalCountCtrl,
          keyboardType: TextInputType.number,
          isRequired: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {},
        ),
        const SizedBox(height: 20),
        _sectionLabel('Computed Values'),
        _derivedRow(Icons.calendar_today_outlined, 'LMP',
            _lmpCtrl.text.isEmpty ? '-' : _lmpCtrl.text),
        const SizedBox(height: 8),
        _derivedRow(Icons.event_available_outlined, 'EDD',
            _eddCtrl.text.isEmpty ? '-' : _eddCtrl.text),
        const SizedBox(height: 8),
        _derivedRow(Icons.timer_outlined, 'AOG', _formatAog()),
        if (_lmp != null && _lmp!.isAfter(DateTime.now()))
          _riskHint('LMP cannot be in the future. Please correct the date.',
              isError: true),
        if (_lmp != null && _edd != null && _edd!.isBefore(DateTime.now()))
          _riskHint('EDD has passed. Please verify the dates.', isError: true),
      ],
    );
  }

  // ──────────────── Step 8 : Summary ────────────────

  Widget _stepSummary() {
    final fullName = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty)
        '${_middleNameCtrl.text.trim()[0]}.',
      _lastNameCtrl.text.trim(),
      if (_extNameCtrl.text.trim().isNotEmpty) _extNameCtrl.text.trim(),
    ].join(' ');

    final address = [
      if (_houseCtrl.text.trim().isNotEmpty) _houseCtrl.text.trim(),
      if (_streetCtrl.text.trim().isNotEmpty) _streetCtrl.text.trim(),
      if (_selectedBarangay != null) _selectedBarangay!,
      if (_cityCtrl.text.trim().isNotEmpty) _cityCtrl.text.trim(),
      if (_provinceCtrl.text.trim().isNotEmpty) _provinceCtrl.text.trim(),
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.brandAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review all details. Navigate back to make changes.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _summarySection('Personal', [
          _summaryRow('Name', fullName.isEmpty ? '-' : fullName),
          _summaryRow('Phone',
              _phoneCtrl.text.trim().isEmpty ? '-' : _phoneCtrl.text.trim()),
          _summaryRow('Email',
              _emailCtrl.text.trim().isEmpty ? '-' : _emailCtrl.text.trim()),
        ]),
        const SizedBox(height: 12),
        _summarySection('Address', [
          _summaryRow('House No.',
              _houseCtrl.text.trim().isEmpty ? '-' : _houseCtrl.text.trim()),
          _summaryRow('Street',
              _streetCtrl.text.trim().isEmpty ? '-' : _streetCtrl.text.trim()),
          _summaryRow('Full Address', address.isEmpty ? '-' : address),
        ]),
        const SizedBox(height: 12),
        _summarySection('Vitals', [
          _summaryRow('Birthdate',
              _birthdate != null ? _dateFmt.format(_birthdate!) : '-'),
          _summaryRow('Height / Weight',
              '${_heightCtrl.text.trim().isEmpty ? '-' : _heightCtrl.text.trim()} cm / ${_weightCtrl.text.trim().isEmpty ? '-' : _weightCtrl.text.trim()} kg'),
          _summaryRow('Blood Type', _bloodType ?? '-'),
        ]),
        const SizedBox(height: 12),
        _summarySection('Gestation', [
          _summaryRow('LMP', _lmp != null ? _dateFmt.format(_lmp!) : '-'),
          _summaryRow('EDD', _edd != null ? _dateFmt.format(_edd!) : '-'),
          _summaryRow('AOG', _formatAog()),
        ]),
        const SizedBox(height: 12),
        _summarySection('Records', [
          _summaryRow(
              'Emergency Contacts', '${_emergencyContacts.length} added'),
          _summaryRow(
              'Medical Conditions', '${_medicalConditions.length} added'),
          _summaryRow('Allergies', '${_allergies.length} added'),
          _summaryRow('Past Pregnancies',
              _hasPastPregnancy ? '${_pastPregnancies.length} added' : 'None'),
        ]),
      ],
    );
  }

  // ──────────────── Modals ────────────────

  Future<void> _showAddEmergencyContact() async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? affiliationValue;

    bool isPhoneValid(String v) {
      final n = v.trim().replaceAll(RegExp(r'[^0-9+]'), '');
      return RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(n);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final phoneEntered = phoneCtrl.text.trim().isNotEmpty;
          final phoneValid = !phoneEntered || isPhoneValid(phoneCtrl.text);
          final canAdd = firstCtrl.text.trim().isNotEmpty &&
              lastCtrl.text.trim().isNotEmpty &&
              phoneEntered &&
              phoneValid;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Emergency Contact'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modalField(
                    'First Name *',
                    firstCtrl,
                    onChanged: (_) => setS(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s\-\']")),
                      LengthLimitingTextInputFormatter(100)
                    ],
                  ),
                  _modalField(
                    'Last Name *',
                    lastCtrl,
                    onChanged: (_) => setS(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s\-\']")),
                      LengthLimitingTextInputFormatter(100)
                    ],
                  ),
                  _modalField(
                    'Phone Number *',
                    phoneCtrl,
                    onChanged: (_) => setS(() {}),
                    keyboard: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                      LengthLimitingTextInputFormatter(15)
                    ],
                    errorText: phoneEntered && !phoneValid
                        ? 'Enter a valid PH number (e.g. 09XXXXXXXXX)'
                        : null,
                  ),
                  _modalDropdown(
                    ctx,
                    label: 'Relationship / Affiliation',
                    value: affiliationValue,
                    items: const {
                      'Spouse / Partner': 'Spouse / Partner',
                      'Parent': 'Parent',
                      'Child': 'Child',
                      'Sibling': 'Sibling',
                      'Relative': 'Relative',
                      'Friend': 'Friend',
                      'Neighbor': 'Neighbor',
                      'Coworker': 'Coworker',
                      'Other': 'Other',
                    },
                    onChanged: (v) => setS(() => affiliationValue = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: canAdd ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final ec = _EmergencyContact()
        ..firstName = firstCtrl.text.trim()
        ..lastName = lastCtrl.text.trim()
        ..phoneNumber = phoneCtrl.text.trim()
        ..affiliation = affiliationValue;
      setState(() => _emergencyContacts.add(ec));
    }
  }

  Future<void> _showAddMedicalCondition({String? prefill}) async {
    final nameCtrl = TextEditingController(text: prefill ?? '');
    DateTime? diagDate;
    String status = 'active';
    final remarksCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Medical Condition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modalField('Condition Name *', nameCtrl,
                    onChanged: (_) => setS(() {}), maxLength: 255),
                _modalDateTile(
                  ctx,
                  label: diagDate == null
                      ? 'Diagnosis Date (optional)'
                      : _dateFmt.format(diagDate!),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => diagDate = d);
                  },
                ),
                _modalDropdown(
                  ctx,
                  label: 'Status',
                  value: status,
                  items: const {'active': 'Active', 'resolved': 'Resolved'},
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                _modalField('Remarks (optional)', remarksCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final mc = _MedicalCondition(nameCtrl.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..remarks =
            remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim();
      setState(() => _medicalConditions.add(mc));
    }
  }

  Future<void> _showAddAllergy() async {
    final allergenCtrl = TextEditingController();
    DateTime? diagDate;
    String status = 'active';
    final treatmentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Allergy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modalField('Allergen *', allergenCtrl,
                    onChanged: (_) => setS(() {}), maxLength: 255),
                _modalDateTile(
                  ctx,
                  label: diagDate == null
                      ? 'Diagnosis Date (optional)'
                      : _dateFmt.format(diagDate!),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => diagDate = d);
                  },
                ),
                _modalDropdown(
                  ctx,
                  label: 'Status',
                  value: status,
                  items: const {'active': 'Active', 'resolved': 'Resolved'},
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                _modalField('Treatment (optional)', treatmentCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: allergenCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && allergenCtrl.text.trim().isNotEmpty) {
      final al = _Allergy(allergenCtrl.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..treatment = treatmentCtrl.text.trim().isEmpty
            ? null
            : treatmentCtrl.text.trim();
      setState(() => _allergies.add(al));
    }
  }

  Future<void> _showAddPastPregnancy() async {
    int fetalCount = 1;
    final gaCtrl = TextEditingController();

    List<String> outcomes = ['live_birth'];
    List<DateTime?> outcomeDates = [null];
    List<bool> isEstimatedList = [false];
    List<TextEditingController> placeCtrls = [TextEditingController()];
    List<String?> deliveryMethods = [null];
    List<String?> intervalErrors = [null];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final gaWeeks = int.tryParse(gaCtrl.text.trim());
          final gaEntered = gaCtrl.text.trim().isNotEmpty;

          bool allValid = gaEntered && gaWeeks != null;
          String? gaError = !gaEntered
              ? 'Gestational age is required'
              : (gaWeeks == null ? 'Enter a whole number of weeks' : null);

          if (gaError == null && gaWeeks != null) {
            for (int i = 0; i < fetalCount; i++) {
              final err = _gaConstraintErrorFor(outcomes[i], gaWeeks);
              if (err != null) {
                gaError = err;
                allValid = false;
                break;
              }
            }
          }

          for (int i = 0; i < fetalCount; i++) {
            final needsDelivery =
                outcomes[i] == 'live_birth' || outcomes[i] == 'stillbirth';
            final hasOutcomeDate = outcomeDates[i] != null;
            final noIntervalError = intervalErrors[i] == null;
            final hasDeliveryInfo = !needsDelivery ||
                (placeCtrls[i].text.trim().isNotEmpty &&
                    deliveryMethods[i] != null);

            if (!hasOutcomeDate || !noIntervalError || !hasDeliveryInfo) {
              allValid = false;
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Past Pregnancy'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modalField(
                    'Gestational age at outcome (weeks) *',
                    gaCtrl,
                    keyboard: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2)
                    ],
                    onChanged: (_) => setS(() {}),
                    errorText: gaError,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: Row(
                      children: [
                        const Text('Fetal Count:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.brandPrimary),
                          onPressed: () {
                            if (fetalCount > 1) {
                              setS(() {
                                fetalCount--;
                                outcomes.removeLast();
                                outcomeDates.removeLast();
                                isEstimatedList.removeLast();
                                placeCtrls.removeLast();
                                deliveryMethods.removeLast();
                                intervalErrors.removeLast();
                              });
                            }
                          },
                        ),
                        Text('$fetalCount',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.brandPrimary),
                          onPressed: () {
                            if (fetalCount < 5) {
                              setS(() {
                                fetalCount++;
                                outcomes.add('live_birth');
                                outcomeDates.add(null);
                                isEstimatedList.add(false);
                                placeCtrls.add(TextEditingController());
                                deliveryMethods.add(null);
                                intervalErrors.add(null);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  for (int i = 0; i < fetalCount; i++) ...[
                    if (fetalCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text('Fetus ${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary)),
                      ),
                    _modalDropdown(
                      ctx,
                      label: 'Outcome',
                      value: outcomes[i],
                      items: const {
                        'live_birth': 'Live Birth',
                        'stillbirth': 'Stillbirth',
                        'miscarriage': 'Miscarriage',
                        'abortion': 'Abortion',
                        'ectopic': 'Ectopic',
                      },
                      onChanged: (v) =>
                          setS(() => outcomes[i] = v ?? 'live_birth'),
                    ),
                    _modalDateTile(
                      ctx,
                      label: outcomeDates[i] == null
                          ? 'Outcome Date *'
                          : _dateFmt.format(outcomeDates[i]!),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: outcomeDates[i] ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) {
                          setS(() {
                            outcomeDates[i] = d;
                            intervalErrors[i] = _computeIntervalError(d);
                          });
                        }
                      },
                    ),
                    if (intervalErrors[i] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 13, color: AppColors.error),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(intervalErrors[i]!,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.error))),
                          ],
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isEstimatedList[i],
                      onChanged: (v) =>
                          setS(() => isEstimatedList[i] = v ?? false),
                      title: const Text('Date is estimated',
                          style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.brandPrimary,
                    ),
                    if (outcomes[i] == 'live_birth' ||
                        outcomes[i] == 'stillbirth') ...[
                      _modalField('Place of delivery *', placeCtrls[i],
                          onChanged: (_) => setS(() {})),
                      _modalDropdown(
                        ctx,
                        label: 'Delivery method *',
                        value: deliveryMethods[i],
                        items: const {
                          'Normal Spontaneous Vaginal Delivery':
                              'Normal Spontaneous Vaginal Delivery',
                          'Cesarean Section': 'Cesarean Section',
                          'Assisted Vaginal Delivery':
                              'Assisted Vaginal Delivery',
                          'Other': 'Other',
                        },
                        onChanged: (v) => setS(() => deliveryMethods[i] = v),
                      ),
                    ],
                    if (i < fetalCount - 1) const Divider(height: 32),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: allValid ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && outcomeDates.every((d) => d != null)) {
      final pp = _PastPregnancy()
        ..fetalCount = fetalCount
        ..gestationalAgeAtEnd = double.tryParse(gaCtrl.text.trim());
      for (int i = 0; i < fetalCount; i++) {
        pp.outcomes.add(_PastFetalOutcome(
            outcome: outcomes[i], outcomeDate: outcomeDates[i]!)
          ..isEstimated = isEstimatedList[i]
          ..placeOfDelivery = placeCtrls[i].text.trim().isEmpty
              ? null
              : placeCtrls[i].text.trim()
          ..deliveryMethod = deliveryMethods[i]);
      }
      setState(() => _pastPregnancies.add(pp));
    }
  }

  // ──────────────── UI Helpers ────────────────

  String _outcomeLabel(String outcome) => switch (outcome) {
        'live_birth' => 'Live Birth',
        'stillbirth' => 'Stillbirth',
        'miscarriage' => 'Miscarriage',
        'abortion' => 'Abortion',
        'ectopic' => 'Ectopic',
        _ => outcome,
      };

  String _pastPregnancyTitle(_PastPregnancy p) {
    if (p.outcomes.isEmpty) return 'Past Pregnancy';
    if (p.outcomes.length == 1) return _outcomeLabel(p.outcomes.first.outcome);
    return '${p.outcomes.length} fetal outcomes';
  }

  String _pastPregnancySubtitle(_PastPregnancy p) {
    if (p.outcomes.isEmpty) return 'No outcomes recorded';

    final dateText = p.earliestOutcomeDate == p.latestOutcomeDate
        ? _dateFmt.format(p.latestOutcomeDate)
        : '${_dateFmt.format(p.earliestOutcomeDate)} to ${_dateFmt.format(p.latestOutcomeDate)}';

    final outcomeText = p.outcomes
        .asMap()
        .entries
        .map((e) => p.outcomes.length > 1
            ? 'F${e.key + 1}: ${_outcomeLabel(e.value.outcome)}'
            : _outcomeLabel(e.value.outcome))
        .join(' | ');

    final hasMissingDelivery = p.outcomes.any(
      (o) =>
          (o.outcome == 'live_birth' || o.outcome == 'stillbirth') &&
          ((o.placeOfDelivery == null || o.placeOfDelivery!.isEmpty) ||
              (o.deliveryMethod == null || o.deliveryMethod!.isEmpty)),
    );

    return [
      dateText,
      outcomeText,
      if (hasMissingDelivery) 'Incomplete delivery details'
    ].join(' - ');
  }

  String? _gaConstraintErrorFor(String outcome, int weeks) {
    switch (outcome) {
      case 'live_birth':
        if (weeks < 22) return 'Live birth is not possible before 22 weeks';
        if (weeks > 45) return 'Live birth beyond 45 weeks is not possible';
        break;
      case 'stillbirth':
        if (weeks < 20) return 'Stillbirth is defined at 20+ weeks';
        break;
      case 'miscarriage':
        if (weeks > 19)
          return 'At $weeks weeks this is classified as Stillbirth';
        break;
      case 'ectopic':
        if (weeks > 15)
          return 'Ectopic pregnancy cannot survive beyond 15 weeks';
        break;
    }
    return null;
  }

  Widget _riskHint(String text, {bool isError = false}) => Padding(
        padding: const EdgeInsets.only(left: 16, top: 3),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.warning_amber_rounded,
                size: 13, color: isError ? AppColors.error : AppColors.warning),
            const SizedBox(width: 4),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 11,
                        color: isError ? AppColors.error : AppColors.warning))),
          ],
        ),
      );

  Widget _bmiTag(double bmi) {
    final String label;
    final Color color;
    if (bmi < 18.5) {
      label = 'Underweight';
      color = AppColors.warning;
    } else if (bmi < 25) {
      label = 'Normal';
      color = const Color(0xFF4CAF50);
    } else if (bmi < 30) {
      label = 'Overweight';
      color = AppColors.warning;
    } else {
      label = 'Obese';
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(2))),
            Text(text.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.3)),
          ],
        ),
      );

  Widget _addressOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    selected ? AppColors.brandPrimary : AppColors.borderPrimary,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.brandPrimary : Colors.transparent,
                  border: Border.all(
                      color: selected
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                      width: 2),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _styledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final labels = itemLabels ?? items;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(hint,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: List.generate(
                    items.length,
                    (i) => DropdownMenuItem<String>(
                        value: items[i],
                        child:
                            Text(labels[i], overflow: TextOverflow.ellipsis))),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader({
    required String title,
    String? subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandText)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: Text(actionLabel),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandAccent),
          ),
        ],
      );

  Widget _emptyState(IconData icon, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(icon,
                  size: 40,
                  color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _iconAvatar(IconData icon, {Color? color}) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1),
            shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color ?? AppColors.brandPrimary),
      );

  Widget _itemCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) =>
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
          ],
        ),
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
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ),
      );

  Widget _derivedRow(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandAccent, size: 17),
            const SizedBox(width: 10),
            Text('$label:',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary))),
          ],
        ),
      );

  Widget _summarySection(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.3)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: rows
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          e.value,
                          if (e.key < rows.length - 1)
                            const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: AppColors.borderPrimary),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(value.isEmpty ? '-' : value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary))),
          ],
        ),
      );

  // ── Modal helpers ───────────────────────────────────

  Widget _modalField(
    String label,
    TextEditingController ctrl, {
    ValueChanged<String>? onChanged,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            filled: true,
            fillColor: AppColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPrimary)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPrimary)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.brandPrimary, width: 1.5)),
          ),
        ),
      );

  Widget _modalDateTile(BuildContext ctx,
          {required String label, required VoidCallback onTap}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary))),
                const Icon(Icons.calendar_today_outlined,
                    size: 17, color: AppColors.brandAccent),
              ],
            ),
          ),
        ),
      );

  Widget _modalDropdown(
    BuildContext ctx, {
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPrimary)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPrimary)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.brandPrimary, width: 1.5)),
          ),
          isExpanded: true,
          items: items.entries
              .map((e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      );

  // ──────────────── OCR methods ────────────────

  Future<void> _startOcrFlow() async {
    final source = await _showOcrSourcePicker();
    if (source == null || !mounted) return;

    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    await _showOcrProcessDialog(file);
  }

  Future<ImageSource?> _showOcrSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borderPrimary,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Scan Document',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Choose an image source to extract patient data',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x1AFF68A5),
                  child: Icon(Icons.camera_alt_outlined,
                      color: AppColors.brandPrimary)),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo of the document'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x1AFF68A5),
                  child: Icon(Icons.photo_library_outlined,
                      color: AppColors.brandPrimary)),
              title: const Text('Gallery'),
              subtitle: const Text('Choose an existing photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showOcrProcessDialog(XFile imageFile) async {
    var dialogState = _OcrDialogState.loading;
    OcrResult? ocrResult;
    String? ocrError;
    StateSetter? setS;

    void startOcr() {
      _geminiService.extractMotherRegistrationData(imageFile).then((r) {
        setS?.call(() {
          if (!r.hasAnyValue) {
            ocrError =
                'No recognisable patient data found in the image.\nTry a clearer or higher-quality photo.';
            dialogState = _OcrDialogState.error;
          } else {
            ocrResult = r;
            dialogState = _OcrDialogState.results;
          }
        });
      }).catchError((dynamic e) {
        setS?.call(() {
          ocrError = e.toString().replaceFirst('Exception: ', '');
          dialogState = _OcrDialogState.error;
        });
      });
    }

    startOcr();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateCallback) {
          setS = setStateCallback;
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.brandPrimary, Color(0xFFE91E8C)]),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          switch (dialogState) {
                            _OcrDialogState.loading =>
                              Icons.cloud_upload_outlined,
                            _OcrDialogState.results =>
                              Icons.check_circle_outline_rounded,
                            _OcrDialogState.error =>
                              Icons.error_outline_rounded,
                          },
                          color: Colors.white,
                          size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                switch (dialogState) {
                                  _OcrDialogState.loading =>
                                    'Scanning Document...',
                                  _OcrDialogState.results => 'Data Extracted',
                                  _OcrDialogState.error => 'Scan Failed',
                                },
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text(
                                switch (dialogState) {
                                  _OcrDialogState.loading =>
                                    'Uploading and analysing with Gemini...',
                                  _OcrDialogState.results =>
                                    'Review the extracted fields below',
                                  _OcrDialogState.error =>
                                    'An error occurred during scanning',
                                },
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (dialogState != _OcrDialogState.loading)
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: switch (dialogState) {
                      _OcrDialogState.loading => _ocrLoadingBody(imageFile),
                      _OcrDialogState.results => _buildOcrFieldList(ocrResult!),
                      _OcrDialogState.error => _ocrErrorBody(ocrError!),
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.borderPrimary))),
                  child: switch (dialogState) {
                    _OcrDialogState.loading => const SizedBox.shrink(),
                    _OcrDialogState.results => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                    color: AppColors.borderPrimary),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Apply to Form'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    _OcrDialogState.error => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                    color: AppColors.borderPrimary),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setStateCallback(() {
                                  dialogState = _OcrDialogState.loading;
                                  ocrError = null;
                                });
                                startOcr();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true && mounted && ocrResult != null) {
      _applyOcrResult(ocrResult!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Form autofilled from OCR scan. Please review & edit as needed.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  Widget _ocrLoadingBody(XFile imageFile) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: imageFile.readAsBytes(),
              builder: (ctx, snap) {
                if (snap.hasData) {
                  return Image.memory(snap.data!,
                      height: 180, width: double.infinity, fit: BoxFit.cover);
                }
                return Container(
                  height: 180,
                  color: AppColors.bgSecondary,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.brandPrimary)),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
              color: AppColors.brandPrimary, strokeWidth: 3),
          const SizedBox(height: 16),
          const Text('Analysing with Gemini AI...',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Extracting patient data from the image',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _ocrStep(number: 1, label: 'Image uploaded', done: true),
          _ocrStep(
              number: 2, label: 'Gemini reading document...', loading: true),
          _ocrStep(number: 3, label: 'Populating form fields'),
        ],
      );

  Widget _ocrStep(
          {required int number,
          required String label,
          bool done = false,
          bool loading = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: done
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 20)
                  : loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brandPrimary))
                      : CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.borderPrimary,
                          child: Text('$number',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary))),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: (done || loading)
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: loading ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      );

  Widget _ocrErrorBody(String message) => Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          const Text('Scan Failed',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.error)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error)),
          ),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Tips for better results:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 6),
          _ocrTip('Ensure the document is well lit'),
          _ocrTip('Keep the camera steady and in focus'),
          _ocrTip('Make sure all text is visible and unobstructed'),
        ],
      );

  Widget _ocrTip(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 14, color: AppColors.brandAccent),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
          ],
        ),
      );

  Widget _buildOcrFieldList(OcrResult r) {
    final rows = <Widget>[];

    void section(String title) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(_ocrSectionHeader(title));
    }

    void field(String label, String? value) {
      if (value == null) return;
      rows.add(_ocrFieldRow(label, value));
    }

    section('Personal Information');
    field('First Name', r.firstName);
    field('Middle Name', r.middleName);
    field('Last Name', r.lastName);
    field('Extension', r.extensionName);
    field('Phone', r.phone);
    field('Email', r.email);

    section('Address');
    field('House No.', r.houseNumber);
    field('Street', r.street);
    field('Barangay', r.barangay);
    field('City', r.city);
    field('Province', r.province);

    section('Vital Statistics');
    field('Birthdate', r.birthdate);
    field('Height', r.heightCm != null ? '${r.heightCm} cm' : null);
    field('Weight', r.weightKg != null ? '${r.weightKg} kg' : null);
    field('Blood Type', r.bloodType);

    section('Gestational Info');
    field('LMP', r.lmpDate);
    field('EDD', r.eddDate);

    if (r.emergencyContacts.isNotEmpty) {
      section('Emergency Contacts (${r.emergencyContacts.length})');
      for (final c in r.emergencyContacts) {
        rows.add(_ocrFieldRow('${c.firstName} ${c.lastName}',
            '${c.phoneNumber}${c.affiliation != null ? ' · ${c.affiliation}' : ''}'));
      }
    }

    if (r.medicalConditions.isNotEmpty) {
      section('Medical Conditions (${r.medicalConditions.length})');
      for (final m in r.medicalConditions) {
        rows.add(_ocrFieldRow(m.conditionName,
            '${m.status}${m.diagnosisDate != null ? ' · ${m.diagnosisDate}' : ''}'));
      }
    }

    if (r.allergies.isNotEmpty) {
      section('Allergies (${r.allergies.length})');
      for (final a in r.allergies) {
        rows.add(_ocrFieldRow(a.allergen,
            '${a.status}${a.treatment != null ? ' · ${a.treatment}' : ''}'));
      }
    }

    if (r.pastPregnancies.isNotEmpty) {
      section('Past Pregnancies (${r.pastPregnancies.length})');
      for (final p in r.pastPregnancies) {
        final parsedDate = DateTime.tryParse(p.outcomeDate);
        rows.add(_ocrFieldRow(_outcomeLabel(p.outcome),
            parsedDate != null ? _dateFmt.format(parsedDate) : p.outcomeDate));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _ocrSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(2))),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2)),
          ],
        ),
      );

  Widget _ocrFieldRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 15, color: Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
          ],
        ),
      );

  void _applyOcrResult(OcrResult r) {
    setState(() {
      if (r.firstName != null) _firstNameCtrl.text = r.firstName!;
      if (r.middleName != null) _middleNameCtrl.text = r.middleName!;
      if (r.lastName != null) _lastNameCtrl.text = r.lastName!;
      if (r.extensionName != null) _extNameCtrl.text = r.extensionName!;
      if (r.phone != null) {
        _phoneCtrl.text = r.phone!;
        _onPhoneChanged(r.phone!);
      }
      if (r.email != null) {
        _emailCtrl.text = r.email!;
        _onEmailChanged(r.email!);
      }

      if (r.houseNumber != null) _houseCtrl.text = r.houseNumber!;
      if (r.street != null) _streetCtrl.text = r.street!;
      if (r.barangay != null) {
        final match = _bhcBarangays
            .where((b) =>
                b.toLowerCase().contains(r.barangay!.toLowerCase()) ||
                r.barangay!.toLowerCase().contains(b.toLowerCase()))
            .firstOrNull;
        if (match != null) {
          _selectedBarangay = match;
          _barangayCtrl.text = match;
          _addressSameAsBhc = false;
        } else {
          _addressSameAsBhc = false;
          _selectedBarangay = null;
          _barangayCtrl.text = r.barangay!;
        }
      }
      if (r.city != null) {
        _cityCtrl.text = r.city!;
        _addressSameAsBhc = false;
      }
      if (r.province != null) {
        _provinceCtrl.text = r.province!;
        _addressSameAsBhc = false;
      }

      if (r.birthdate != null) {
        final parsed = DateTime.tryParse(r.birthdate!);
        if (parsed != null) {
          _birthdate = parsed;
          _birthdateCtrl.text = _dateFmt.format(parsed);
        }
      }
      if (r.heightCm != null) _heightCtrl.text = r.heightCm!.toStringAsFixed(1);
      if (r.weightKg != null) _weightCtrl.text = r.weightKg!.toStringAsFixed(1);
      if (r.bloodType != null) _bloodType = r.bloodType;

      for (final m in r.medicalConditions) {
        if (m.conditionName.isEmpty) continue;
        final mc = _MedicalCondition(m.conditionName)
          ..status = m.status
          ..remarks = m.remarks;
        if (m.diagnosisDate != null)
          mc.diagnosisDate = DateTime.tryParse(m.diagnosisDate!);
        _medicalConditions.add(mc);
      }

      for (final a in r.allergies) {
        if (a.allergen.isEmpty) continue;
        final al = _Allergy(a.allergen)
          ..status = a.status
          ..treatment = a.treatment
          ..remarks = a.remarks;
        if (a.diagnosisDate != null)
          al.diagnosisDate = DateTime.tryParse(a.diagnosisDate!);
        _allergies.add(al);
      }

      for (final ec in r.emergencyContacts) {
        if (ec.firstName.isEmpty ||
            ec.lastName.isEmpty ||
            ec.phoneNumber.isEmpty) continue;
        _emergencyContacts.add(
          _EmergencyContact()
            ..firstName = ec.firstName
            ..middleName = ec.middleName
            ..lastName = ec.lastName
            ..extensionName = ec.extensionName
            ..phoneNumber = ec.phoneNumber
            ..affiliation = ec.affiliation,
        );
      }

      for (final p in r.pastPregnancies) {
        if (p.outcomeDate.trim().isEmpty) continue;
        final date = DateTime.tryParse(p.outcomeDate);
        if (date == null) continue;
        final imported = _PastPregnancy()
          ..fetalCount = 1
          ..gestationalAgeAtEnd = p.gestationalAgeAtEnd;
        imported.outcomes.add(
          _PastFetalOutcome(outcome: p.outcome, outcomeDate: date)
            ..isEstimated = p.isEstimated
            ..placeOfDelivery = p.placeOfDelivery
            ..deliveryMethod = p.deliveryMethod,
        );
        _pastPregnancies.add(imported);
      }
      if (_pastPregnancies.isNotEmpty) _hasPastPregnancy = true;

      if (r.lmpDate != null) {
        final lmp = DateTime.tryParse(r.lmpDate!);
        if (lmp != null) _updateFromLmp(lmp);
      } else if (r.eddDate != null) {
        final edd = DateTime.tryParse(r.eddDate!);
        if (edd != null) _updateFromEdd(edd);
      }
    });
  }

  // ──────────────── Build ────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.brandPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Add Mother',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _startOcrFlow,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('OCR'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.brandPrimary),
            ),
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.borderPrimary)),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: AppColors.borderPrimary,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            minHeight: 3,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                ProgressiveStepIndicator(
                    currentStep: _step, totalSteps: _totalSteps),
                const SizedBox(height: 10),
                Text(_stepTitles[_step],
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandText)),
                const SizedBox(height: 4),
                Text(_stepSubtitles[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('Step ${_step + 1} of $_totalSteps',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalSteps,
              itemBuilder: (_, i) => _pageFor(i),
            ),
          ),
        ],
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
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _goBack,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 13),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      side: const BorderSide(color: AppColors.brandAccent),
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _step < _totalSteps - 1
                        ? ElevatedButton(
                            onPressed: _submitting ? null : _goNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Next'),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_ios_rounded, size: 13),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 17),
                            label: Text(
                                _submitting ? 'Saving...' : 'Finalize & Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
