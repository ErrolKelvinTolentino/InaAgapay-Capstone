// lib/screens/midwife/midwife_add_mother_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/progressive_step_indicator.dart';

// Enums & Data Models
enum _GestationMethod { lmp, edd, aog }

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

class _PastPregnancy {
  String outcome;
  DateTime outcomeDate;
  bool isEstimated = false;
  double? gestationalAgeAtEnd;
  String? placeOfDelivery;
  String? deliveryMethod;

  _PastPregnancy({required this.outcome, required this.outcomeDate});

  Map<String, dynamic> toMap() => {
        'outcome': outcome,
        'outcome_date': outcomeDate.toIso8601String().split('T')[0],
        'is_outcome_date_estimated': isEstimated,
        'gestational_age_at_end': gestationalAgeAtEnd,
        'place_of_delivery': placeOfDelivery,
        'delivery_method': deliveryMethod,
      };
}

class MidwifeAddMotherScreen extends StatefulWidget {
  const MidwifeAddMotherScreen({super.key});

  @override
  State<MidwifeAddMotherScreen> createState() => _MidwifeAddMotherScreenState();
}

class _MidwifeAddMotherScreenState extends State<MidwifeAddMotherScreen> {
  // Context
  int? _midwifeId;
  int? _assignedBhcId;
  String _bhcName = '';
  bool _loadingContext = true;

  // Navigation
  int _step = 0;
  static const int _totalSteps = 9;
  bool _submitting = false;
  final _pageController = PageController();

  // Formatters
  final _dateFmt = DateFormat('MMMM d, yyyy');

  // Step 0: Personal & Account
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _phoneError, _emailError;
  bool _emailChecking = false, _emailExists = false;
  Timer? _emailTimer;
  String? _lastEmailChecked;

  // Step 1: Address
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

  // Step 2: Emergency Contacts
  final List<_EmergencyContact> _emergencyContacts = [];

  // Step 3: Vital Statistics
  DateTime? _birthdate;
  final _birthdateCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodType;

  // Step 4: Medical Conditions
  final List<_MedicalCondition> _medicalConditions = [];

  // Step 5: Allergies
  final List<_Allergy> _allergies = [];

  // Step 6: Pregnancy History
  bool _hasPastPregnancy = false;
  final List<_PastPregnancy> _pastPregnancies = [];

  // Step 7: Gestational Info
  _GestationMethod _gestationMethod = _GestationMethod.lmp;
  final _lmpCtrl = TextEditingController();
  final _eddCtrl = TextEditingController();
  final _aogWeeksCtrl = TextEditingController();
  final _aogDaysCtrl = TextEditingController();
  DateTime? _lmp;
  DateTime? _edd;

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
      _passwordCtrl,
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) throw Exception('Not authenticated');
      final result = await SupabaseService.getMidwifeContext(accountId);
      if (result['success'] == true) {
        setState(() {
          _midwifeId = result['midwife_id'] as int;
          _assignedBhcId = result['assigned_bhc_id'] as int;
          _bhcName = result['bhc_name'] as String;
        });
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

  void _applyBhcAddress() {
    _selectedBarangay = _bhcName;
    _barangayCtrl.text = _bhcName;
    _cityCtrl.text = 'Baliwag';
    _provinceCtrl.text = 'Bulacan';
  }

  void _onEmailChanged(String v) {
    final value = v.trim();
    if (value.isEmpty) {
      _emailTimer?.cancel();
      setState(() {
        _emailChecking = false;
        _emailExists = false;
        _emailError = null;
      });
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
  }

  Future<void> _checkEmail(String email) async {
    _lastEmailChecked = email;
    final available = await SupabaseService.isEmailAvailable(email);
    if (_lastEmailChecked != email || !mounted) return;
    setState(() {
      _emailChecking = false;
      _emailExists = !available;
      _emailError = available ? null : 'Email already in use';
    });
  }

  void _onPhoneChanged(String v) {
    final normalized = v.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final valid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(
      () => _phoneError =
          v.trim().isEmpty ? null : (valid ? null : 'Enter a valid PH number'),
    );
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final rng = Random.secure();
    final pw =
        List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
    setState(() {
      _passwordCtrl.text = pw;
      _obscurePassword = false;
    });
  }

  void _updateFromLmp(DateTime lmp) {
    _lmp = lmp;
    _edd = lmp.add(const Duration(days: 280));
    _lmpCtrl.text = _dateFmt.format(lmp);
    _eddCtrl.text = _dateFmt.format(_edd!);
  }

  void _updateFromEdd(DateTime edd) {
    _edd = edd;
    _lmp = edd.subtract(const Duration(days: 280));
    _eddCtrl.text = _dateFmt.format(edd);
    _lmpCtrl.text = _dateFmt.format(_lmp!);
  }

  void _updateFromAog() {
    final w = int.tryParse(_aogWeeksCtrl.text.trim()) ?? 0;
    final d = int.tryParse(_aogDaysCtrl.text.trim()) ?? 0;
    if (w <= 0 && d <= 0) return;
    final lmp = DateTime.now().subtract(Duration(days: w * 7 + d));
    _updateFromLmp(lmp);
  }

  String _formatAog() {
    if (_lmp == null) return '-';
    final days = DateTime.now().difference(_lmp!).inDays;
    if (days < 0) return '-';
    return '${days ~/ 7}w ${days % 7}d';
  }

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
        } else if (_emailExists) {
          issues.add('Email (already in use)');
        } else if (_emailError != null) {
          issues.add('Email (invalid)');
        }
        if (_passwordCtrl.text.isEmpty) {
          issues.add('Password');
        } else if (_passwordCtrl.text.length < 8) {
          issues.add('Password (min 8 chars)');
        }
        if (issues.isNotEmpty) msg = 'Please fix: ${issues.join(', ')}.';
        break;

      case 1:
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
        if (_birthdate == null) issues.add('Birthdate');
        if (double.tryParse(_heightCtrl.text.trim()) == null) {
          issues.add('Height (cm)');
        }
        if (double.tryParse(_weightCtrl.text.trim()) == null) {
          issues.add('Weight (kg)');
        }
        if (issues.isNotEmpty) msg = 'Please provide: ${issues.join(', ')}.';
        break;

      case 6:
        if (_hasPastPregnancy && _pastPregnancies.isEmpty) {
          msg = 'Add at least one past pregnancy or disable the toggle.';
        } else {
          for (final p in _pastPregnancies) {
            if ((p.outcome == 'live_birth' || p.outcome == 'stillbirth') &&
                (p.placeOfDelivery == null || p.deliveryMethod == null)) {
              msg =
                  'Provide delivery place & method for live birth / stillbirth records.';
              break;
            }
          }
        }
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

  Future<void> _submit() async {
    if (!_validateStep(8)) return;
    setState(() => _submitting = true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      _showSuccessDialog(
        name: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String password,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Mother Added'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name has been registered successfully.'),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Email', value: email),
            const SizedBox(height: 6),
            _CredentialRow(label: 'Password', value: password),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Share these credentials securely with the mother.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dismiss dialog
              Navigator.pop(context, true); // return to mothers list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Add Mother',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderPrimary),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: AppColors.borderPrimary,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.brandPrimary,
            ),
            minHeight: 3,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                ProgressiveStepIndicator(
                  currentStep: _step,
                  totalSteps: _totalSteps,
                ),
                const SizedBox(height: 10),
                Text(
                  _stepTitles[_step],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${_step + 1} of $_totalSteps',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
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
                child: _buildStepContent(i),
              ),
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
              offset: const Offset(0, -4),
            ),
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
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 13,
                    ),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      side: const BorderSide(color: AppColors.brandAccent),
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _step < _totalSteps - 1
                        ? ElevatedButton.icon(
                            onPressed: _submitting ? null : _goNext,
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                            ),
                            label: const Text('Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 17),
                            label: Text(
                              _submitting ? 'Saving...' : 'Finalize & Save',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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

  Widget _buildStepContent(int index) {
    switch (index) {
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
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Middle',
                controller: _middleNameCtrl,
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
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Ext. (Jr., III)',
                controller: _extNameCtrl,
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
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _phoneError!,
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _sectionLabel('Account Credentials'),
        AppInputField(
          hintText: 'Email Address',
          controller: _emailCtrl,
          isRequired: true,
          leadingIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
        ),
        if (_emailError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _emailError!,
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ),
        ],
        if (_emailChecking) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
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
        ],
        const SizedBox(height: 12),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: AppColors.brandAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Temporary Password *',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: AppColors.brandAccent,
                  size: 20,
                ),
                tooltip: 'Auto-generate password',
                onPressed: _generatePassword,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'Tap the wand icon to auto-generate a secure password.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInputField(
                hintText: 'House No.',
                controller: _houseCtrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Street',
                controller: _streetCtrl,
              ),
            ),
          ],
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
      ],
    );
  }

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
            if (picked != null && mounted) {
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
              ),
            ),
          ],
        ),
        if (bmi != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'BMI: ${bmi.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
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
                        const Icon(
                          Icons.add,
                          size: 13,
                          color: AppColors.brandAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          c,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                title: _outcomeLabel(p.outcome),
                subtitle: [
                  _dateFmt.format(p.outcomeDate),
                  if (p.placeOfDelivery != null) p.placeOfDelivery!,
                  if (p.deliveryMethod != null) p.deliveryMethod!,
                ].join(' - '),
                onDelete: () =>
                    setState(() => _pastPregnancies.removeAt(e.key)),
              );
            }),
        ],
      ],
    );
  }

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
              _lmp = null;
              _edd = null;
              _lmpCtrl.clear();
              _eddCtrl.clear();
              _aogWeeksCtrl.clear();
              _aogDaysCtrl.clear();
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
              if (picked != null && mounted) setState(() => _updateFromLmp(picked));
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
              if (picked != null && mounted) setState(() => _updateFromEdd(picked));
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  hintText: 'Days',
                  controller: _aogDaysCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        _sectionLabel('Computed Values'),
        _derivedRow(
          Icons.calendar_today_outlined,
          'LMP',
          _lmpCtrl.text.isEmpty ? '-' : _lmpCtrl.text,
        ),
        const SizedBox(height: 8),
        _derivedRow(
          Icons.event_available_outlined,
          'EDD',
          _eddCtrl.text.isEmpty ? '-' : _eddCtrl.text,
        ),
        const SizedBox(height: 8),
        _derivedRow(Icons.timer_outlined, 'AOG', _formatAog()),
      ],
    );
  }

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
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.brandAccent,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review all details. Navigate back to make changes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
          _summaryRow('Address', address.isEmpty ? '-' : address),
        ]),
        const SizedBox(height: 12),
        _summarySection('Vitals', [
          _summaryRow(
            'Birthdate',
            _birthdate != null ? _dateFmt.format(_birthdate!) : '-',
          ),
          _summaryRow(
            'Height / Weight',
            '${_heightCtrl.text.trim().isEmpty ? '-' : _heightCtrl.text.trim()} cm / ${_weightCtrl.text.trim().isEmpty ? '-' : _weightCtrl.text.trim()} kg',
          ),
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
            'Emergency Contacts',
            '${_emergencyContacts.length} added',
          ),
          _summaryRow(
            'Medical Conditions',
            '${_medicalConditions.length} added',
          ),
          _summaryRow('Allergies', '${_allergies.length} added'),
          _summaryRow(
            'Past Pregnancies',
            _hasPastPregnancy ? '${_pastPregnancies.length} added' : 'None',
          ),
        ]),
      ],
    );
  }

  // Helper Methods
  String _outcomeLabel(String outcome) => switch (outcome) {
        'live_birth' => 'Live Birth',
        'stillbirth' => 'Stillbirth',
        'miscarriage' => 'Miscarriage',
        'abortion' => 'Abortion',
        'ectopic' => 'Ectopic',
        _ => outcome,
      };

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.3,
          ),
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
              width: selected ? 1.5 : 1,
            ),
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
                    width: 2,
                  ),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
            offset: const Offset(0, 6),
          ),
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
                hint: Text(
                  hint,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: List.generate(
                  items.length,
                  (i) => DropdownMenuItem<String>(
                    value: items[i],
                    child: Text(
                      labels[i],
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandAccent,
            ),
          ),
        ],
      );

  Widget _emptyState(IconData icon, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _iconAvatar(IconData icon, {Color? color}) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? AppColors.brandPrimary,
        ),
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: leading,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandAccent, size: 17),
            const SizedBox(width: 10),
            Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _summarySection(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
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
              children: rows
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        e.value,
                        if (e.key < rows.length - 1)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.borderPrimary,
                          ),
                      ],
                    ),
                  )
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
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

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
                  TextField(
                    controller: firstCtrl,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      border: const OutlineInputBorder(),
                      errorText: phoneEntered && !phoneValid
                          ? 'Enter a valid PH number (e.g. 09XXXXXXXXX)'
                          : null,
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: affiliationValue,
                    decoration: const InputDecoration(
                      labelText: 'Relationship / Affiliation',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Spouse / Partner', child: Text('Spouse / Partner')),
                      DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                      DropdownMenuItem(value: 'Child', child: Text('Child')),
                      DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                      DropdownMenuItem(value: 'Relative', child: Text('Relative')),
                      DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                      DropdownMenuItem(value: 'Neighbor', child: Text('Neighbor')),
                      DropdownMenuItem(value: 'Coworker', child: Text('Coworker')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setS(() => affiliationValue = v),
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
                onPressed: canAdd ? () => Navigator.pop(ctx, true) : null,
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

    if (confirmed == true && mounted) {
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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Condition Name *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    diagDate == null
                        ? 'Diagnosis Date (optional)'
                        : _dateFmt.format(diagDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
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
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
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

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty && mounted) {
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
                TextField(
                  controller: allergenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Allergen *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    diagDate == null
                        ? 'Diagnosis Date (optional)'
                        : _dateFmt.format(diagDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
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
              onPressed: allergenCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
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

    if (confirmed == true && allergenCtrl.text.trim().isNotEmpty && mounted) {
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
    String outcome = 'live_birth';
    DateTime? outcomeDate;
    bool isEstimated = false;
    final gaCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    String? deliveryMethod;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final needsDelivery =
              outcome == 'live_birth' || outcome == 'stillbirth';
          final isValid = outcomeDate != null &&
              (!needsDelivery ||
                  (placeCtrl.text.trim().isNotEmpty && deliveryMethod != null));

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Past Pregnancy'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: outcome,
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
                    onChanged: (v) => setS(() => outcome = v ?? 'live_birth'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      outcomeDate == null
                          ? 'Outcome Date *'
                          : _dateFmt.format(outcomeDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: outcomeDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setS(() => outcomeDate = d);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isEstimated,
                    onChanged: (v) => setS(() => isEstimated = v ?? false),
                    title: const Text(
                      'Date is estimated',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: gaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gestational age at outcome (weeks)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (needsDelivery) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: placeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Place of delivery *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: deliveryMethod,
                      decoration: const InputDecoration(
                        labelText: 'Delivery method *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Normal Spontaneous Vaginal Delivery', child: Text('Normal Spontaneous Vaginal Delivery')),
                        DropdownMenuItem(value: 'Cesarean Section', child: Text('Cesarean Section')),
                        DropdownMenuItem(value: 'Assisted Vaginal Delivery', child: Text('Assisted Vaginal Delivery')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setS(() => deliveryMethod = v),
                    ),
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
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
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

    if (confirmed == true && outcomeDate != null && mounted) {
      final pp = _PastPregnancy(outcome: outcome, outcomeDate: outcomeDate!)
        ..isEstimated = isEstimated
        ..gestationalAgeAtEnd = double.tryParse(gaCtrl.text.trim())
        ..placeOfDelivery =
            placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim()
        ..deliveryMethod = deliveryMethod;
      setState(() => _pastPregnancies.add(pp));
    }
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}