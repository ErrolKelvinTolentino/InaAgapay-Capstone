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
import '../../widgets/secondary_header.dart';
import 'add_prenatal_checkup_screen.dart';

// Extension name options
const List<String> _extensionOptions = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];
// Blood type options
const List<String> _bloodTypeOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
// Relationship options for emergency contacts
const List<String> _relationshipOptions = [
  'Spouse/Partner',
  'Parent',
  'Child',
  'Sibling',
  'Relative',
  'Friend',
  'Neighbor',
  'Coworker',
  'Other',
];
// Common medical conditions
const List<String> _commonConditions = [
  'Anemia',
  'Diabetes',
  'Hypertension',
  'Asthma',
  'Thyroid Disorder',
  'Heart Disease',
  'Kidney Disease',
  'Epilepsy',
  'Hepatitis',
  'Other',
];

enum _GestationMethod { lmp, edd, aog }
enum _OcrDialogState { loading, results, error }

class _EmergencyContact {
  String firstName = '';
  String? middleName;
  String lastName = '';
  String? extensionName;
  String phoneNumber = '';
  String? relationship;

  bool get isValid =>
      firstName.isNotEmpty && lastName.isNotEmpty && phoneNumber.isNotEmpty && relationship != null && relationship!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'extension_name': extensionName?.isEmpty == true ? null : extensionName,
        'phone_number': phoneNumber,
        'affiliation': relationship,
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
  double? gestationalAgeAtEnd;

  _PastFetalOutcome({required this.outcome, required this.outcomeDate});

  Map<String, dynamic> toMap() => {
        'outcome': outcome,
        'outcome_date': outcomeDate.toIso8601String().split('T')[0],
        'is_outcome_date_estimated': isEstimated,
        'place_of_delivery': placeOfDelivery,
        'delivery_method': deliveryMethod,
        'gestational_age_at_end': gestationalAgeAtEnd,
      };
}

class _PastPregnancy {
  int fetalCount = 1;
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

  String get primaryOutcome => outcomes.isNotEmpty ? _latestOutcomeRef().outcome : 'live_birth';
  DateTime get primaryOutcomeDate => latestOutcomeDate;

  String get outcome => primaryOutcome;
  set outcome(String value) => _latestOutcomeRef().outcome = value;

  DateTime get outcomeDate => primaryOutcomeDate;
  set outcomeDate(DateTime value) => _latestOutcomeRef().outcomeDate = value;

  bool get isEstimated => outcomes.isNotEmpty ? _latestOutcomeRef().isEstimated : false;
  set isEstimated(bool value) => _latestOutcomeRef().isEstimated = value;

  String? get placeOfDelivery => outcomes.isNotEmpty ? _latestOutcomeRef().placeOfDelivery : null;
  set placeOfDelivery(String? value) => _latestOutcomeRef().placeOfDelivery = value;

  String? get deliveryMethod => outcomes.isNotEmpty ? _latestOutcomeRef().deliveryMethod : null;
  set deliveryMethod(String? value) => _latestOutcomeRef().deliveryMethod = value;

  double? get gestationalAgeAtEnd => outcomes.isNotEmpty ? _latestOutcomeRef().gestationalAgeAtEnd : null;
  set gestationalAgeAtEnd(double? value) => _latestOutcomeRef().gestationalAgeAtEnd = value;

  Map<String, dynamic> toMap() => {
        'fetal_count': fetalCount,
        'outcomes': outcomes.map((o) => o.toMap()).toList(),
      };
}

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
  final PageController _pageController = PageController();

  // ── Formatters ───────────────────────────────────────
  final DateFormat _dateFmt = DateFormat('MMMM d, yyyy');

  // ── Step 0 : Personal & Account (with Birthdate) ─────
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _middleNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  String _selectedExtension = '';
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  
  DateTime? _birthdate;
  final TextEditingController _birthdateCtrl = TextEditingController();
  String? _birthdateError;
  String? _riskWarning;
  int? _calculatedAge;
  
  String? _phoneError;
  String? _emailError;
  bool _emailChecking = false;
  bool _emailExists = false;
  Timer? _emailTimer;
  String? _lastEmailChecked;
  bool _isEmailReadOnly = false;
  bool _isExistingSelfRegistered = false;
  String? _firstNameError;
  String? _lastNameError;

  // ── Auto-fill existing account ──────────────────────
  int? _existingAccountId;
  int? _existingMotherId;
  bool _isUpdatingExisting = false;
  bool _checkingAccount = false;

  // ── Step 1 : Address ────────────────────────────────
  bool _addressSameAsBhc = true;
  final TextEditingController _houseCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _barangayCtrl = TextEditingController();
  String? _selectedBarangay;
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _provinceCtrl = TextEditingController();
  String? _houseError;
  String? _streetError;
  String? _barangayError;
  String? _cityError;
  String? _provinceError;

  static const List<String> _bhcBarangays = [
    'San Jose',
    'Tarcan',
    'Sta. Barbara',
    'Tiaong',
    'Pinagbarilan',
  ];

  // ── Step 2 : Emergency Contacts ─────────────────────
  final List<_EmergencyContact> _emergencyContacts = [];

  // ── Step 3 : Vitals ─────────────────────────────────
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  String? _bloodType;
  String? _heightError;
  String? _weightError;
  double? _calculatedBMI;
  String? _bmiClassification;
  String? _bmiWarning;

  // ── Step 4 : Medical Conditions ─────────────────────
  final List<_MedicalCondition> _medicalConditions = [];

  // ── Step 5 : Allergies ──────────────────────────────
  final List<_Allergy> _allergies = [];

  // ── Step 6 : Pregnancy History ──────────────────────
  bool _hasPastPregnancy = false;
  final List<_PastPregnancy> _pastPregnancies = [];

  // ── Step 7 : Gestational Info ───────────────────────
  _GestationMethod _gestationMethod = _GestationMethod.lmp;
  final TextEditingController _lmpCtrl = TextEditingController();
  final TextEditingController _eddCtrl = TextEditingController();
  final TextEditingController _aogWeeksCtrl = TextEditingController();
  final TextEditingController _aogDaysCtrl = TextEditingController();
  final TextEditingController _fetalCountCtrl = TextEditingController(text: '1');
  DateTime? _lmp;
  DateTime? _edd;
  String? _gestationError;

  // ── OCR ─────────────────────────────────────────────
  final GeminiService _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    _loadContext();
    _phoneCtrl.addListener(_onPhoneChanged);
    _heightCtrl.addListener(_validateHeightWeight);
    _weightCtrl.addListener(_validateHeightWeight);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailTimer?.cancel();
    for (final c in [
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _birthdateCtrl,
      _houseCtrl,
      _streetCtrl,
      _barangayCtrl,
      _cityCtrl,
      _provinceCtrl,
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

  // ── Validation Methods ──────────────────────────────────────────

  void _onPhoneChanged() {
    final normalized = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final valid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(
      () => _phoneError = _phoneCtrl.text.trim().isEmpty 
          ? null 
          : (valid ? null : 'Enter a valid PH number (e.g., 09123456789 or +639123456789)'),
    );
  }

  void _validateHeightWeight() {
    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());

    if (height != null) {
      if (height < 100 || height > 220) {
        setState(() => _heightError = 'Height must be between 100-220 cm');
      } else {
        setState(() => _heightError = null);
      }
    } else {
      setState(() => _heightError = _heightCtrl.text.trim().isEmpty ? null : 'Enter a valid number');
    }

    if (weight != null) {
      if (weight < 30 || weight > 200) {
        setState(() => _weightError = 'Weight must be between 30-200 kg');
      } else {
        setState(() => _weightError = null);
      }
    } else {
      setState(() => _weightError = _weightCtrl.text.trim().isEmpty ? null : 'Enter a valid number');
    }

    _calculateBMI();
  }

  void _calculateBMI() {
    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());

    if (height != null && weight != null && height > 0) {
      final heightM = height / 100;
      final bmi = weight / (heightM * heightM);
      _calculatedBMI = bmi;

      if (bmi < 18.5) {
        _bmiClassification = 'Underweight';
        _bmiWarning = 'Underweight: May increase risk of complications.';
      } else if (bmi < 25) {
        _bmiClassification = 'Normal';
        _bmiWarning = null;
      } else if (bmi < 30) {
        _bmiClassification = 'Overweight';
        _bmiWarning = 'Overweight: Monitor weight gain during pregnancy.';
      } else {
        _bmiClassification = 'Obese';
        _bmiWarning = 'Obese: Higher risk of pregnancy complications. Close monitoring advised.';
      }
    } else {
      _calculatedBMI = null;
      _bmiClassification = null;
      _bmiWarning = null;
    }
    setState(() {});
  }

  void _validateBirthdate() {
    if (_birthdate == null) {
      setState(() => _birthdateError = null);
      return;
    }
    
    if (_birthdate!.isAfter(DateTime.now())) {
      setState(() => _birthdateError = 'Birthdate cannot be in the future');
      return;
    }
    
    final age = (DateTime.now().difference(_birthdate!).inDays / 365.25).floor();
    _calculatedAge = age;
    
    if (age < 10 || age > 50) {
      setState(() => _birthdateError = 'Maternal age ($age years) must be between 10 and 50');
    } else {
      setState(() => _birthdateError = null);
    }

    if (age < 18) {
      setState(() => _riskWarning = '⚠️ High-risk: Adolescent pregnancy (under 18). Close monitoring required.');
    } else if (age > 35) {
      setState(() => _riskWarning = '⚠️ High-risk: Advanced maternal age (over 35). Regular checkups recommended.');
    } else {
      setState(() => _riskWarning = null);
    }
  }

  String? _validatePregnancyInterval(DateTime newLmp) {
    const minGapDays = 42;
    for (final past in _pastPregnancies) {
      final gap = newLmp.difference(past.latestOutcomeDate).inDays;
      if (gap > 0 && gap < minGapDays) {
        return 'Pregnancy interval too short ($gap days). Minimum interval is $minGapDays days after previous pregnancy outcome.';
      }
    }
    return null;
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
            _loadExistingData(existingData);
            _isUpdatingExisting = true;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Existing data loaded. Please complete the missing information.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            _existingAccountId = null;
            _existingMotherId = null;
            _isExistingSelfRegistered = false;
          }
        } else {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => DialogBox(
              title: 'Email Already Registered',
              content: 'This mother is already registered to a Barangay Health Center (BHC).\n\n'
                       'Please verify if this is the correct mother or contact support for assistance.',
              buttonText: 'OK',
              type: DialogType.warning,
              onPressed: () => Navigator.pop(context),
            ),
          );
          setState(() {
            _emailExists = true;
            _emailError = 'This mother is already registered to a BHC';
          });
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

  void _loadExistingData(Map<String, dynamic> existingData) {
    _firstNameCtrl.text = existingData['first_name'] ?? '';
    _middleNameCtrl.text = existingData['middle_name'] ?? '';
    _lastNameCtrl.text = existingData['last_name'] ?? '';
    _selectedExtension = existingData['extension_name'] ?? '';
    _phoneCtrl.text = existingData['phone_number'] ?? '';
    _isEmailReadOnly = true;

    if (existingData['birthdate'] != null) {
      _birthdate = DateTime.tryParse(existingData['birthdate']);
      if (_birthdate != null) {
        _birthdateCtrl.text = _dateFmt.format(_birthdate!);
        _validateBirthdate();
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

    if (existingData['house_number'] != null && existingData['house_number'].toString().isNotEmpty) {
      _houseCtrl.text = existingData['house_number'].toString();
    }
    if (existingData['street'] != null && existingData['street'].toString().isNotEmpty) {
      _streetCtrl.text = existingData['street'].toString();
    }
    if (existingData['barangay'] != null && existingData['barangay'].toString().isNotEmpty) {
      _selectedBarangay = existingData['barangay'].toString();
      _barangayCtrl.text = existingData['barangay'].toString();
      _addressSameAsBhc = false;
    }
    if (existingData['city_municipality'] != null && existingData['city_municipality'].toString().isNotEmpty) {
      _cityCtrl.text = existingData['city_municipality'].toString();
      _addressSameAsBhc = false;
    }
    if (existingData['province'] != null && existingData['province'].toString().isNotEmpty) {
      _provinceCtrl.text = existingData['province'].toString();
      _addressSameAsBhc = false;
    }

    if (_existingMotherId != null) {
      SupabaseService.client
          .from('pregnancies')
          .select('last_menstrual_period, expected_date_of_delivery, status')
          .eq('mother_id', _existingMotherId!)
          .eq('status', 'ongoing')
          .maybeSingle()
          .then((pregnancyData) {
            if (pregnancyData != null && mounted) {
              final lmpStr = pregnancyData['last_menstrual_period'] as String?;
              final eddStr = pregnancyData['expected_date_of_delivery'] as String?;

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
              setState(() {});
            }
          });
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

  // ── Address ──────────────────────────────────────────

  void _applyBhcAddress() {
    _selectedBarangay = _bhcName;
    _barangayCtrl.text = _bhcName;
    _cityCtrl.text = 'Baliwag';
    _provinceCtrl.text = 'Bulacan';
  }

  // ── Gestation ────────────────────────────────────────

  void _updateFromLmp(DateTime lmp) {
    setState(() {
      _lmp = lmp;
      _edd = lmp.add(const Duration(days: 280));
      _lmpCtrl.text = _dateFmt.format(lmp);
      _eddCtrl.text = _dateFmt.format(_edd!);
      _gestationMethod = _GestationMethod.lmp;
      _gestationError = _validatePregnancyInterval(lmp);
    });
  }

  void _updateFromEdd(DateTime edd) {
    setState(() {
      _edd = edd;
      _lmp = edd.subtract(const Duration(days: 280));
      _eddCtrl.text = _dateFmt.format(edd);
      _lmpCtrl.text = _dateFmt.format(_lmp!);
      _gestationMethod = _GestationMethod.edd;
      _gestationError = _validatePregnancyInterval(_lmp!);
    });
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

  // ── Validation (inline only, no toasts) ──────────────

  bool _validateStepInline(int step) {
    switch (step) {
      case 0:
        final firstNameEmpty = _firstNameCtrl.text.trim().isEmpty;
        final lastNameEmpty = _lastNameCtrl.text.trim().isEmpty;
        final phoneEmpty = _phoneCtrl.text.trim().isEmpty;
        final emailEmpty = _emailCtrl.text.trim().isEmpty;
        final birthdateEmpty = _birthdate == null;
        
        setState(() {
          _firstNameError = firstNameEmpty ? 'First name is required' : null;
          _lastNameError = lastNameEmpty ? 'Last name is required' : null;
        });
        
        return !firstNameEmpty && !lastNameEmpty && !phoneEmpty && !emailEmpty && !birthdateEmpty && _birthdateError == null;
        
      case 1:
        final houseEmpty = _houseCtrl.text.trim().isEmpty;
        final streetEmpty = _streetCtrl.text.trim().isEmpty;
        
        setState(() {
          _houseError = houseEmpty ? 'House number is required' : null;
          _streetError = streetEmpty ? 'Street is required' : null;
          if (!_addressSameAsBhc) {
            _barangayError = (_selectedBarangay ?? '').isEmpty ? 'Barangay is required' : null;
            _cityError = _cityCtrl.text.trim().isEmpty ? 'City/Municipality is required' : null;
            _provinceError = _provinceCtrl.text.trim().isEmpty ? 'Province is required' : null;
          } else {
            _barangayError = null;
            _cityError = null;
            _provinceError = null;
          }
        });
        
        return !houseEmpty && !streetEmpty && 
               (_addressSameAsBhc || ((_selectedBarangay ?? '').isNotEmpty && _cityCtrl.text.trim().isNotEmpty && _provinceCtrl.text.trim().isNotEmpty));
        
      case 3:
        final heightValid = double.tryParse(_heightCtrl.text.trim()) != null;
        final weightValid = double.tryParse(_weightCtrl.text.trim()) != null;
        return heightValid && weightValid;
        
      case 7:
        if (_gestationMethod == _GestationMethod.lmp && _lmp == null) return false;
        if (_gestationMethod == _GestationMethod.edd && _edd == null) return false;
        if (_gestationMethod == _GestationMethod.aog && _aogWeeksCtrl.text.trim().isEmpty && _aogDaysCtrl.text.trim().isEmpty) return false;
        if (_gestationError != null) return false;
        return true;
        
      default:
        return true;
    }
  }

  // ── Navigation ───────────────────────────────────────

  void _goNext() {
    if (_validateStepInline(_step)) {
      if (_step < _totalSteps - 1) {
        _pageController.animateToPage(
          _step + 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        setState(() => _step++);
      }
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

  void _jumpToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step = step);
    }
  }

  // ── Submit ───────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validateStepInline(8)) return;

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
          province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
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
          middleName: _middleNameCtrl.text.trim().isEmpty ? null : _middleNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          extensionName: _selectedExtension.isEmpty ? null : _selectedExtension,
          phone: _phoneCtrl.text.trim(),
          houseNumber: _houseCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          barangay: _selectedBarangay,
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
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
                ? 'Mother account created successfully!\n\n'
                  'A temporary password has been sent to ${_emailCtrl.text.trim()}.\n\n'
                  '⚠️ The mother will be prompted to change their password on first login.'
                : 'Mother account created but email failed to send.\n\n'
                  '🔑 TEMPORARY PASSWORD: ${result['generated_password']}\n\n'
                  '⚠️ Please provide this password to the mother. '
                  'They will be prompted to change it on first login.\n\n'
                  '📝 Make sure to save this password securely.');

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogBox(
            type: DialogType.success,
            title: _isUpdatingExisting ? 'Account Updated' : 'Mother Account Created',
            content: successMessage,
            buttonText: 'Continue',
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
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => DialogBox(
              type: DialogType.error,
              title: 'Failed to Save',
              content: result['message'] ?? 'Failed to save mother record. Please try again.',
              buttonText: 'OK',
              onPressed: () => Navigator.pop(context),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogBox(
            type: DialogType.error,
            title: 'Error',
            content: 'An error occurred: $e',
            buttonText: 'OK',
            onPressed: () => Navigator.pop(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Modal Dialogs ─────────────────────────────────────

  Future<void> _showAddEmergencyContact() async {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? relationship;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  hint: const Text('Relationship *'),
                  items: _relationshipOptions.map((rel) {
                    return DropdownMenuItem(value: rel, child: Text(rel));
                  }).toList(),
                  onChanged: (value) {
                    setS(() => relationship = value);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (firstNameCtrl.text.trim().isNotEmpty &&
                    lastNameCtrl.text.trim().isNotEmpty &&
                    phoneCtrl.text.trim().isNotEmpty &&
                    relationship != null) {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _emergencyContacts.add(_EmergencyContact()
          ..firstName = firstNameCtrl.text.trim()
          ..lastName = lastNameCtrl.text.trim()
          ..phoneNumber = phoneCtrl.text.trim()
          ..relationship = relationship);
      });
    }
  }

  Future<void> _confirmDeleteEmergencyContact(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Contact'),
        content: const Text('Are you sure you want to remove this emergency contact?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _emergencyContacts.removeAt(index);
      });
    }
  }

  Future<void> _showAddMedicalCondition({String? prefill}) async {
    final nameCtrl = TextEditingController(text: prefill ?? '');
    DateTime? diagDate;
    String status = 'active';
    final remarksCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Medical Condition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Condition Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setS(() => diagDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderPrimary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          diagDate == null ? 'Diagnosis Date (optional)' : _dateFmt.format(diagDate!),
                          style: TextStyle(
                            color: diagDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameCtrl.text.trim().isNotEmpty ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      setState(() {
        _medicalConditions.add(_MedicalCondition(nameCtrl.text.trim())
          ..diagnosisDate = diagDate
          ..status = status
          ..remarks = remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim());
      });
    }
  }

  Future<void> _confirmDeleteMedicalCondition(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Condition'),
        content: const Text('Are you sure you want to remove this medical condition?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _medicalConditions.removeAt(index);
      });
    }
  }

  Future<void> _showAddAllergy() async {
    final allergenCtrl = TextEditingController();
    DateTime? diagDate;
    String status = 'active';
    final treatmentCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Allergy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: allergenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Allergen *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setS(() => diagDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderPrimary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          diagDate == null ? 'Diagnosis Date (optional)' : _dateFmt.format(diagDate!),
                          style: TextStyle(
                            color: diagDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: treatmentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Treatment (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: allergenCtrl.text.trim().isNotEmpty ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && allergenCtrl.text.trim().isNotEmpty) {
      setState(() {
        _allergies.add(_Allergy(allergenCtrl.text.trim())
          ..diagnosisDate = diagDate
          ..status = status
          ..treatment = treatmentCtrl.text.trim().isEmpty ? null : treatmentCtrl.text.trim());
      });
    }
  }

  Future<void> _confirmDeleteAllergy(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Allergy'),
        content: const Text('Are you sure you want to remove this allergy?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _allergies.removeAt(index);
      });
    }
  }

  Future<void> _showAddPastPregnancy() async {
    int fetalCount = 1;
    final gaCtrl = TextEditingController();
    bool gaEstimated = false;
    List<String> outcomes = ['live_birth'];
    List<DateTime?> outcomeDates = [null];
    List<bool> isEstimated = [false];
    List<TextEditingController> placeCtrls = [TextEditingController()];
    List<String?> deliveryMethods = [null];

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          bool allValid = true;
          for (int i = 0; i < fetalCount; i++) {
            if (outcomeDates[i] == null) allValid = false;
            if (outcomes[i] == 'live_birth' || outcomes[i] == 'stillbirth') {
              if (placeCtrls[i].text.trim().isEmpty) allValid = false;
              if (deliveryMethods[i] == null) allValid = false;
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Past Pregnancy'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: gaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Gestational Age (weeks)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: gaEstimated,
                            onChanged: (v) => setS(() => gaEstimated = v ?? false),
                          ),
                          const Text('Estimated'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Fetal Count:'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (fetalCount > 1) {
                            setS(() {
                              fetalCount--;
                              outcomes.removeLast();
                              outcomeDates.removeLast();
                              isEstimated.removeLast();
                              placeCtrls.removeLast();
                              deliveryMethods.removeLast();
                            });
                          }
                        },
                      ),
                      Text('$fetalCount'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          if (fetalCount < 5) {
                            setS(() {
                              fetalCount++;
                              outcomes.add('live_birth');
                              outcomeDates.add(null);
                              isEstimated.add(false);
                              placeCtrls.add(TextEditingController());
                              deliveryMethods.add(null);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  for (int i = 0; i < fetalCount; i++) ...[
                    if (fetalCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Fetus ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: outcomes[i],
                      decoration: const InputDecoration(
                        labelText: 'Outcome',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'live_birth', child: Text('Live Birth')),
                        DropdownMenuItem(value: 'stillbirth', child: Text('Stillbirth')),
                        DropdownMenuItem(value: 'miscarriage', child: Text('Miscarriage')),
                        DropdownMenuItem(value: 'abortion', child: Text('Abortion')),
                        DropdownMenuItem(value: 'ectopic', child: Text('Ectopic')),
                      ],
                      onChanged: (v) => setS(() => outcomes[i] = v ?? 'live_birth'),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: outcomeDates[i] ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setS(() => outcomeDates[i] = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderPrimary),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(
                              outcomeDates[i] == null ? 'Outcome Date' : _dateFmt.format(outcomeDates[i]!),
                              style: TextStyle(
                                color: outcomeDates[i] == null ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: isEstimated[i],
                          onChanged: (v) => setS(() => isEstimated[i] = v ?? false),
                        ),
                        const Text('Date is estimated'),
                      ],
                    ),
                    if (outcomes[i] == 'live_birth' || outcomes[i] == 'stillbirth') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: placeCtrls[i],
                        decoration: const InputDecoration(
                          labelText: 'Place of Delivery',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: deliveryMethods[i],
                        decoration: const InputDecoration(
                          labelText: 'Delivery Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Normal Spontaneous Vaginal Delivery', child: Text('Normal Spontaneous Vaginal Delivery')),
                          DropdownMenuItem(value: 'Cesarean Section', child: Text('Cesarean Section')),
                          DropdownMenuItem(value: 'Assisted Vaginal Delivery', child: Text('Assisted Vaginal Delivery')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setS(() => deliveryMethods[i] = v),
                      ),
                    ],
                    if (i < fetalCount - 1) const Divider(height: 24),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: allValid ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        final pastPreg = _PastPregnancy();
        pastPreg.fetalCount = fetalCount;
        for (int i = 0; i < fetalCount; i++) {
          pastPreg.outcomes.add(_PastFetalOutcome(
            outcome: outcomes[i],
            outcomeDate: outcomeDates[i]!,
          )
            ..isEstimated = isEstimated[i]
            ..placeOfDelivery = placeCtrls[i].text.trim().isEmpty ? null : placeCtrls[i].text.trim()
            ..deliveryMethod = deliveryMethods[i]
            ..gestationalAgeAtEnd = double.tryParse(gaCtrl.text.trim()));
        }
        _pastPregnancies.add(pastPreg);
        _hasPastPregnancy = true;
      });
    }
  }

  Future<void> _confirmDeletePastPregnancy(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Pregnancy Record'),
        content: const Text('Are you sure you want to remove this past pregnancy record?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _pastPregnancies.removeAt(index);
        if (_pastPregnancies.isEmpty) {
          _hasPastPregnancy = false;
        }
      });
    }
  }

  // ── Step Content Builders ────────────────────────────

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _stepPersonal();
      case 1:
        return _stepAddress();
      case 2:
        return _stepEmergencyContacts();
      case 3:
        return _stepVitals();
      case 4:
        return _stepMedicalConditions();
      case 5:
        return _stepAllergies();
      case 6:
        return _stepPregnancyHistory();
      case 7:
        return _stepGestational();
      default:
        return _stepSummary();
    }
  }

  // ──────────────── Step 0 : Personal ────────────────

  Widget _stepPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Full Name'),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'First Name *',
                controller: _firstNameCtrl,
                isRequired: true,
                errorText: _firstNameError,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-'’]")),
                  LengthLimitingTextInputFormatter(100),
                ],
                onChanged: (_) => _validateStepInline(0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Middle',
                controller: _middleNameCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-'’]")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'Last Name *',
                controller: _lastNameCtrl,
                isRequired: true,
                errorText: _lastNameError,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-'’]")),
                  LengthLimitingTextInputFormatter(100),
                ],
                onChanged: (_) => _validateStepInline(0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildExtensionDropdown(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _sectionLabel('Birthdate'),
        AppInputField(
          hintText: 'Birthdate',
          controller: _birthdateCtrl,
          isRequired: true,
          leadingIcon: Icons.cake_outlined,
          readOnly: true,
          errorText: _birthdateError,
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
              _validateBirthdate();
            }
          },
        ),
        if (_calculatedAge != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Age: $_calculatedAge years old',
              style: TextStyle(
                fontSize: 12,
                color: (_calculatedAge! < 10 || _calculatedAge! > 50) ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
        ],
        if (_riskWarning != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(_riskWarning!, style: const TextStyle(fontSize: 12, color: AppColors.warning))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        
        _sectionLabel('Contact'),
        AppInputField(
          hintText: 'Phone Number *',
          controller: _phoneCtrl,
          isRequired: true,
          leadingIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
          onChanged: (_) => _validateStepInline(0),
        ),
        const SizedBox(height: 24),
        
        _sectionLabel('Account Credentials'),
        AppInputField(
          hintText: 'Email Address',
          controller: _emailCtrl,
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
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A secure temporary password will be sent to the mother\'s email address.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

  Widget _buildExtensionDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExtension.isEmpty ? null : _selectedExtension,
          hint: const Text('Extension Name (Jr., III)', style: TextStyle(color: AppColors.textSecondary)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: _extensionOptions.map((ext) {
            return DropdownMenuItem(
              value: ext.isEmpty ? null : ext,
              child: Text(ext.isEmpty ? 'None' : ext),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedExtension = value ?? '';
            });
          },
        ),
      ),
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
              const Icon(Icons.home_work_outlined, color: AppColors.brandAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assigned BHC: ${_bhcName.isEmpty ? '-' : _bhcName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Address Type'),
        _addressOption(
          title: 'Same as BHC address',
          subtitle: 'Bulacan - Baliwag - ${_bhcName.isEmpty ? 'Assigned barangay' : _bhcName}',
          selected: _addressSameAsBhc,
          onTap: () => setState(() {
            _addressSameAsBhc = true;
            _applyBhcAddress();
            _validateStepInline(1);
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
            _validateStepInline(1);
          }),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Address Details'),
        AppInputField(
          hintText: 'House No. *',
          controller: _houseCtrl,
          isRequired: true,
          leadingIcon: Icons.home_outlined,
          errorText: _houseError,
          onChanged: (_) => _validateStepInline(1),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Street *',
          controller: _streetCtrl,
          isRequired: true,
          leadingIcon: Icons.streetview_outlined,
          errorText: _streetError,
          onChanged: (_) => _validateStepInline(1),
        ),
        const SizedBox(height: 12),
        if (_addressSameAsBhc)
          AppInputField(
            hintText: 'Barangay',
            controller: _barangayCtrl,
            leadingIcon: Icons.location_on_outlined,
            readOnly: true,
          )
        else
          _styledDropdown(
            hint: 'Barangay *',
            value: _selectedBarangay,
            items: _bhcBarangays,
            icon: Icons.location_on_outlined,
            errorText: _barangayError,
            onChanged: (v) => setState(() {
              _selectedBarangay = v;
              _validateStepInline(1);
            }),
          ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'City / Municipality',
          controller: _cityCtrl,
          readOnly: _addressSameAsBhc,
          errorText: _cityError,
          onChanged: (_) => _validateStepInline(1),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Province',
          controller: _provinceCtrl,
          readOnly: _addressSameAsBhc,
          errorText: _provinceError,
          onChanged: (_) => _validateStepInline(1),
        ),
      ],
    );
  }

  // ──────────────── Step 2 : Emergency Contacts ────────────────

  Widget _stepEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Emergency Contacts'),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: _showAddEmergencyContact,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_emergencyContacts.isEmpty)
          _emptyState(Icons.contacts_outlined, 'No emergency contacts added.\nTap "Add Contact" to add one.')
        else
          ..._emergencyContacts.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.person_outline),
                  title: '${e.value.firstName} ${e.value.lastName}',
                  subtitle: '${e.value.phoneNumber} - ${e.value.relationship ?? "No relationship"}',
                  onDelete: () => _confirmDeleteEmergencyContact(e.key),
                ),
              ),
      ],
    );
  }

  // ──────────────── Step 3 : Vitals ────────────────

  Widget _stepVitals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Body Measurements'),
        Row(
          children: [
            Expanded(
              child: AppInputField(
                hintText: 'Height (cm)',
                controller: _heightCtrl,
                isRequired: true,
                leadingIcon: Icons.straighten_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                errorText: _heightError,
                onChanged: (_) => _validateStepInline(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInputField(
                hintText: 'Weight (kg)',
                controller: _weightCtrl,
                isRequired: true,
                leadingIcon: Icons.monitor_weight_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                errorText: _weightError,
                onChanged: (_) => _validateStepInline(3),
              ),
            ),
          ],
        ),
        if (_calculatedBMI != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Text('BMI: ${_calculatedBMI!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                _bmiTag(_calculatedBMI!),
              ],
            ),
          ),
          if (_bmiWarning != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_bmiWarning!, style: const TextStyle(fontSize: 12, color: AppColors.warning))),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        _sectionLabel('Blood Type'),
        _styledDropdown(
          hint: 'Select Blood Type',
          value: _bloodType,
          items: _bloodTypeOptions,
          icon: Icons.bloodtype_outlined,
          onChanged: (v) => setState(() => _bloodType = v),
        ),
      ],
    );
  }

  // ──────────────── Step 4 : Medical Conditions ────────────────

  Widget _stepMedicalConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Quick Add - Common Conditions'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _commonConditions.map((condition) => FilterChip(
            label: Text(condition, style: const TextStyle(fontSize: 12)),
            onSelected: (_) => _showAddMedicalCondition(prefill: condition),
            backgroundColor: Colors.white,
            side: BorderSide(color: AppColors.borderPrimary),
          )).toList(),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Medical Conditions List'),
        Center(
          child: SizedBox(
            width: 180,
            child: ElevatedButton.icon(
              onPressed: () => _showAddMedicalCondition(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Custom'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_medicalConditions.isEmpty)
          _emptyState(Icons.medical_services_outlined, 'No medical conditions added.\nTap "Add Custom" to add one.')
        else
          ..._medicalConditions.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.medical_services_outlined),
                  title: e.value.conditionName,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.diagnosisDate != null) _dateFmt.format(e.value.diagnosisDate!),
                    if (e.value.remarks != null) e.value.remarks!,
                  ].join(' - '),
                  onDelete: () => _confirmDeleteMedicalCondition(e.key),
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
        _sectionLabel('Allergies List'),
        Center(
          child: SizedBox(
            width: 180,
            child: ElevatedButton.icon(
              onPressed: _showAddAllergy,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Allergy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_allergies.isEmpty)
          _emptyState(Icons.no_food_outlined, 'No allergies recorded.\nTap "Add Allergy" to add one.')
        else
          ..._allergies.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.warning_amber_outlined, color: AppColors.warning),
                  title: e.value.allergen,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.treatment != null) e.value.treatment!,
                  ].join(' - '),
                  onDelete: () => _confirmDeleteAllergy(e.key),
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
            activeColor: AppColors.brandPrimary,
            activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onChanged: (v) => setState(() {
              _hasPastPregnancy = v;
              if (!v) _pastPregnancies.clear();
            }),
          ),
        ),
        if (_hasPastPregnancy) ...[
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: _showAddPastPregnancy,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Pregnancy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_pastPregnancies.isEmpty)
            _emptyState(Icons.history_outlined, 'No past pregnancies recorded.\nTap "Add Pregnancy" to add one.')
          else
            ..._pastPregnancies.asMap().entries.map((e) {
              final p = e.value;
              return _itemCard(
                leading: _iconAvatar(Icons.pregnant_woman_outlined),
                title: _pastPregnancyTitle(p),
                subtitle: _pastPregnancySubtitle(p),
                onDelete: () => _confirmDeletePastPregnancy(e.key),
              );
            }),
        ],
      ],
    );
  }

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

    final gaText = p.gestationalAgeAtEnd != null 
        ? ' - ${p.gestationalAgeAtEnd!.toStringAsFixed(1)} weeks'
        : '';

    return '$dateText\n$outcomeText$gaText';
  }

  String _outcomeLabel(String outcome) {
    switch (outcome) {
      case 'live_birth': return 'Live Birth';
      case 'stillbirth': return 'Stillbirth';
      case 'miscarriage': return 'Miscarriage';
      case 'abortion': return 'Abortion';
      case 'ectopic': return 'Ectopic';
      default: return outcome;
    }
  }

  // ──────────────── Step 7 : Gestational ────────────────

  Widget _stepGestational() {
    const methodItems = ['lmp', 'edd', 'aog'];
    const methodLabels = [
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
              _gestationMethod = _GestationMethod.values.firstWhere((e) => e.name == v);
              _gestationError = null;
            });
          },
        ),
        const SizedBox(height: 20),
        _sectionLabel('Date Entry'),
        if (_gestationMethod == _GestationMethod.lmp)
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _lmp ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _updateFromLmp(picked));
            },
            child: AppInputField(
              hintText: 'Last Menstrual Period',
              controller: _lmpCtrl,
              isRequired: true,
              leadingIcon: Icons.calendar_today_outlined,
              readOnly: true,
              errorText: _gestationError,
            ),
          )
        else if (_gestationMethod == _GestationMethod.edd)
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _edd ?? DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 300)),
              );
              if (picked != null) setState(() => _updateFromEdd(picked));
            },
            child: AppInputField(
              hintText: 'Estimated Delivery Date',
              controller: _eddCtrl,
              isRequired: true,
              leadingIcon: Icons.event_available_outlined,
              readOnly: true,
              errorText: _gestationError,
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          onChanged: (_) => _validateStepInline(7),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Computed Values'),
        _derivedRow(Icons.calendar_today_outlined, 'LMP', _lmpCtrl.text.isEmpty ? '-' : _lmpCtrl.text),
        const SizedBox(height: 8),
        _derivedRow(Icons.event_available_outlined, 'EDD', _eddCtrl.text.isEmpty ? '-' : _eddCtrl.text),
        const SizedBox(height: 8),
        _derivedRow(Icons.timer_outlined, 'AOG', _formatAog()),
      ],
    );
  }

  // ──────────────── Step 8 : Summary ────────────────

  Widget _stepSummary() {
    final fullName = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim()[0] + '.',
      _lastNameCtrl.text.trim(),
      if (_selectedExtension.isNotEmpty) _selectedExtension,
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
                  'Tap on any field below to edit it directly.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Personal Information Section - Clickable
        _buildClickableSummarySection(
          'Personal Information',
          [
            _summaryRow('Full Name', fullName.isEmpty ? '-' : fullName),
            _summaryRow('Birthdate', _birthdate != null ? _dateFmt.format(_birthdate!) : '-'),
            _summaryRow('Age', _calculatedAge != null ? '$_calculatedAge years' : '-'),
            _summaryRow('Phone', _phoneCtrl.text.trim().isEmpty ? '-' : _phoneCtrl.text.trim()),
            _summaryRow('Email', _emailCtrl.text.trim().isEmpty ? '-' : _emailCtrl.text.trim()),
          ],
          onTap: () => _jumpToStep(0),
        ),
        const SizedBox(height: 12),
        
        // Address Section - Clickable
        _buildClickableSummarySection(
          'Address',
          [
            _summaryRow('Full Address', address.isEmpty ? '-' : address),
          ],
          onTap: () => _jumpToStep(1),
        ),
        const SizedBox(height: 12),
        
        // Vitals Section - Clickable
        _buildClickableSummarySection(
          'Vital Statistics',
          [
            _summaryRow('Height / Weight', '${_heightCtrl.text.trim().isEmpty ? '-' : _heightCtrl.text.trim()} cm / ${_weightCtrl.text.trim().isEmpty ? '-' : _weightCtrl.text.trim()} kg'),
            _summaryRow('BMI', _calculatedBMI != null ? '${_calculatedBMI!.toStringAsFixed(1)} ($_bmiClassification)' : '-'),
            _summaryRow('Blood Type', _bloodType ?? '-'),
          ],
          onTap: () => _jumpToStep(3),
        ),
        const SizedBox(height: 12),
        
        // Gestation Section - Clickable
        _buildClickableSummarySection(
          'Gestational Information',
          [
            _summaryRow('LMP', _lmp != null ? _dateFmt.format(_lmp!) : '-'),
            _summaryRow('EDD', _edd != null ? _dateFmt.format(_edd!) : '-'),
            _summaryRow('AOG', _formatAog()),
            _summaryRow('Fetal Count', _fetalCountCtrl.text.trim()),
          ],
          onTap: () => _jumpToStep(7),
        ),
        const SizedBox(height: 12),
        
        // Records Section
        _buildExpandableRecordsSection(
          'Emergency Contacts',
          _emergencyContacts.map((c) => '${c.firstName} ${c.lastName} - ${c.phoneNumber} (${c.relationship ?? "No relationship"})').toList(),
          onTap: () => _jumpToStep(2),
        ),
        const SizedBox(height: 12),
        
        _buildExpandableRecordsSection(
          'Medical Conditions',
          _medicalConditions.map((c) => '${c.conditionName} (${c.status})').toList(),
          onTap: () => _jumpToStep(4),
        ),
        const SizedBox(height: 12),
        
        _buildExpandableRecordsSection(
          'Allergies',
          _allergies.map((a) => '${a.allergen} (${a.status})').toList(),
          onTap: () => _jumpToStep(5),
        ),
        const SizedBox(height: 12),
        
        _buildExpandableRecordsSection(
          'Past Pregnancies',
          _pastPregnancies.map((p) => _pastPregnancyTitle(p)).toList(),
          onTap: () => _jumpToStep(6),
        ),
        const SizedBox(height: 12),
        
        // Risk Alert if any
        if (_riskWarning != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(_riskWarning!, style: const TextStyle(color: AppColors.warning))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildClickableSummarySection(String title, List<Widget> rows, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandPrimary)),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, size: 16, color: AppColors.brandPrimary),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: rows),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableRecordsSection(String title, List<String> items, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandPrimary)),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, size: 16, color: AppColors.brandPrimary),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(12),
              child: items.isEmpty
                  ? const Text('No records added', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                  : Column(
                      children: items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.brandPrimary, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: AppColors.brandPrimary, borderRadius: BorderRadius.circular(2)),
        ),
        Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.3)),
      ],
    ),
  );

  Widget _addressOption({required String title, required String subtitle, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.brandPrimary : AppColors.borderPrimary, width: selected ? 1.5 : 1),
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
                border: Border.all(color: selected ? AppColors.brandPrimary : AppColors.textSecondary, width: 2),
              ),
              child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? errorText,
  }) {
    final labels = itemLabels ?? items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
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
                    hint: Text(hint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: List.generate(items.length, (i) => DropdownMenuItem<String>(
                      value: items[i],
                      child: Text(labels[i], overflow: TextOverflow.ellipsis),
                    )),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(errorText, style: const TextStyle(fontSize: 11, color: AppColors.error)),
          ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    ),
  );

  Widget _iconAvatar(IconData icon, {Color? color}) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1), shape: BoxShape.circle),
    child: Icon(icon, size: 18, color: color ?? AppColors.brandPrimary),
  );

  Widget _itemCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
        onPressed: onDelete,
      ),
    ),
  );

  Widget _derivedRow(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.brandAccent, size: 17),
        const SizedBox(width: 10),
        Text('$label:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary))),
      ],
    ),
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        const SizedBox(width: 8),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ──────────────── OCR (placeholder) ────────────────

  Future<void> _startOcrFlow() async {
    // OCR implementation - will be added in future iteration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR feature coming soon'), backgroundColor: AppColors.info),
    );
  }

  // ──────────────── Build ────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Add Mother',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: AppColors.borderPrimary,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            minHeight: 3,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                ProgressiveStepIndicator(currentStep: _step, totalSteps: _totalSteps),
                const SizedBox(height: 10),
                Text(_stepTitles[_step], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brandText)),
                const SizedBox(height: 4),
                Text(_stepSubtitles[_step], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('Step ${_step + 1} of $_totalSteps', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalSteps,
              itemBuilder: (_, i) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: _buildStepContent(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.brandAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : (_step < _totalSteps - 1 ? _goNext : _submit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_step < _totalSteps - 1 ? 'Next' : 'Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _stepTitles = [
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

  static const List<String> _stepSubtitles = [
    'Name, birthdate, phone, email and login credentials',
    'Current place of residence',
    'Who to contact in an emergency',
    'Height, weight and blood type',
    'Known diagnoses and health conditions',
    'Known allergens and reactions',
    'Previous pregnancy outcomes',
    'Current pregnancy dating',
    'Review before saving',
  ];
}