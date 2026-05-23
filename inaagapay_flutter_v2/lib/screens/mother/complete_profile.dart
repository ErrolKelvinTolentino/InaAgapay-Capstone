// lib/screens/mother/complete_profile.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/progressive_step_indicator.dart';
import '../../widgets/page_title.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';
import '../../services/push_notification_service.dart';
import '../../models/due_date_basis.dart';
import 'welcome_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  int _currentStep = 0;

  // Controllers - Personal Info
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _middleName = TextEditingController();
  final _birthDate = TextEditingController();
  final _contactNumber = TextEditingController();
  final _emailAddress = TextEditingController();

  String _selectedExtension = '';
  bool _showExtensionDropdown = false;
  final List<String> _extensionOptions = [
    '',
    'Jr.',
    'Sr.',
    'II',
    'III',
    'IV',
    'V'
  ];

  bool _registeredWithEmail = false;

  // Date format for presentation
  final DateFormat _dateFmt = DateFormat('MMMM d, yyyy');

  DateTime? _selectedBirthdate;
  String? _birthdateError;

  // Contact validations
  String? _phoneError;
  String? _emailError;
  bool _emailChecking = false;
  Timer? _emailTimer;
  String? _lastEmailChecked;

  // Due Date / Gestation
  DueDateBasis _dueDateBasis = DueDateBasis.lmp;
  final _lmpDate = TextEditingController();
  final _eddDate = TextEditingController();
  final _aogWeeks = TextEditingController();
  final _aogDays = TextEditingController();
  DateTime? _selectedLmp;
  DateTime? _selectedEdd;

  // Gestation validations
  String? _gestationError;
  String? _weeksError;
  String? _daysError;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccount();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _middleName.dispose();
    _birthDate.dispose();
    _contactNumber.dispose();
    _emailAddress.dispose();
    _lmpDate.dispose();
    _eddDate.dispose();
    _aogWeeks.dispose();
    _aogDays.dispose();
    _emailTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _loadCurrentAccount() async {
    final accountId = await AuthStorage.getUserId();
    if (accountId == null) return;
    try {
      final acc = await SupabaseService.client
          .from('accounts')
          .select(
              'first_name, middle_name, last_name, extension_name, phone_number, email_address')
          .eq('account_id', accountId)
          .maybeSingle();
      if (acc != null && mounted) {
        setState(() {
          _firstName.text = acc['first_name'] ?? '';
          _middleName.text = acc['middle_name'] ?? '';
          _lastName.text = acc['last_name'] ?? '';
          _selectedExtension = acc['extension_name'] ?? '';
          _contactNumber.text = acc['phone_number'] ?? '';
          _emailAddress.text = acc['email_address'] ?? '';

          if (acc['email_address'] != null &&
              acc['email_address'].toString().trim().isNotEmpty) {
            _registeredWithEmail = true;
          } else {
            _registeredWithEmail = false;
          }

          if (_contactNumber.text.isNotEmpty) {
            _onPhoneChanged();
          }
        });
      }

      final moth = await SupabaseService.client
          .from('mothers')
          .select('birthdate')
          .eq('account_id', accountId)
          .maybeSingle();
      if (moth != null && moth['birthdate'] != null && mounted) {
        final bdate = DateTime.tryParse(moth['birthdate']);
        if (bdate != null) {
          setState(() {
            _selectedBirthdate = bdate;
            _birthDate.text = _dateFmt.format(bdate);
            _validateBirthdate();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current account: $e');
    }
  }

  void _validateBirthdate() {
    if (_selectedBirthdate == null) {
      setState(() => _birthdateError = null);
      return;
    }

    if (_selectedBirthdate!.isAfter(DateTime.now())) {
      setState(() => _birthdateError = 'Birthdate cannot be in the future');
      return;
    }

    final age = (DateTime.now().difference(_selectedBirthdate!).inDays / 365.25)
        .floor();

    if (age < 5) {
      setState(() => _birthdateError =
          'Maternal age ($age years) is too young for registration.');
    } else {
      setState(() => _birthdateError = null);
    }
  }

  void _onPhoneChanged() {
    final normalized =
        _contactNumber.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final valid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(() => _phoneError = _contactNumber.text.trim().isEmpty
        ? null
        : (valid ? null : 'Enter a valid PH number'));
  }

  void _onEmailChanged(String v) {
    final value = v.trim();
    if (value.isEmpty) {
      _emailTimer?.cancel();
      setState(() {
        _emailChecking = false;
        _emailError = null;
      });
      return;
    }
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    setState(() => _emailError = valid ? null : 'Enter a valid email');
    if (!valid) {
      _emailTimer?.cancel();
      _emailChecking = false;
      return;
    }
    _emailTimer?.cancel();
    setState(() => _emailChecking = true);
    _emailTimer =
        Timer(const Duration(milliseconds: 600), () => _checkEmail(value));
  }

  Future<void> _checkEmail(String email) async {
    _lastEmailChecked = email;
    final accountId = await AuthStorage.getUserId();
    String? currentEmail;
    if (accountId != null) {
      final acc = await SupabaseService.client
          .from('accounts')
          .select('email_address')
          .eq('account_id', accountId)
          .maybeSingle();
      if (acc != null) {
        currentEmail = acc['email_address'] as String?;
      }
    }

    if (currentEmail != null &&
        currentEmail.toLowerCase() == email.toLowerCase()) {
      if (_lastEmailChecked != email || !mounted) return;
      setState(() {
        _emailChecking = false;
        _emailError = null;
      });
      return;
    }

    final available = await SupabaseService.isEmailAvailable(email);
    if (_lastEmailChecked != email || !mounted) return;
    setState(() {
      _emailChecking = false;
      _emailError = available ? null : 'Email already in use';
    });
  }

  String? _validateLmp(DateTime lmp) {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 2 * 7));
    if (lmp.isAfter(twoWeeksAgo)) {
      return 'LMP must be at least 2 weeks ago.';
    }
    final daysSinceLmp = now.difference(lmp).inDays;
    if (daysSinceLmp > 42 * 7) {
      return 'LMP is more than 42 weeks ago. Please verify the date.';
    }
    return null;
  }

  String? _validateEdd(DateTime edd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eddDate = DateTime(edd.year, edd.month, edd.day);
    if (eddDate.isBefore(today)) {
      return 'EDD cannot be in the past.';
    }
    final maxEdd = today.add(const Duration(days: 43 * 7));
    if (eddDate.isAfter(maxEdd)) {
      return 'EDD cannot be more than 43 weeks from today.';
    }
    return null;
  }

  void _updateFromLmp(DateTime lmp) {
    setState(() {
      _selectedLmp = lmp;
      _lmpDate.text = _dateFmt.format(lmp);
      _selectedEdd = lmp.add(const Duration(days: 280));
      _eddDate.text = _dateFmt.format(_selectedEdd!);
      _gestationError = _validateLmp(lmp);
    });
  }

  void _updateFromEdd(DateTime edd) {
    setState(() {
      _selectedEdd = edd;
      _eddDate.text = _dateFmt.format(edd);
      _selectedLmp = edd.subtract(const Duration(days: 280));
      _lmpDate.text = _dateFmt.format(_selectedLmp!);
      _gestationError = _validateEdd(edd) ?? _validateLmp(_selectedLmp!);
    });
  }

  void _updateFromAog() {
    final wStr = _aogWeeks.text.trim();
    final dStr = _aogDays.text.trim();

    if (wStr.isEmpty && dStr.isEmpty) {
      setState(() {
        _weeksError = null;
        _daysError = null;
        _gestationError = null;
        _selectedLmp = null;
        _selectedEdd = null;
        _lmpDate.clear();
        _eddDate.clear();
      });
      return;
    }

    final w = int.tryParse(wStr);
    final d = int.tryParse(dStr);

    String? wErr;
    String? dErr;

    if (w == null && wStr.isNotEmpty) {
      wErr = 'Enter a valid number';
    } else if (w != null && (w < 2 || w > 42)) {
      wErr = 'Must be 2-42';
    }

    if (d == null && dStr.isNotEmpty) {
      dErr = 'Enter a valid number';
    } else if (d != null && (d < 0 || d > 6)) {
      dErr = 'Must be 0-6';
    }

    setState(() {
      _weeksError = wErr;
      _daysError = dErr;
      _gestationError =
          (wErr != null || dErr != null) ? 'Invalid AOG weeks or days' : null;
    });

    if (wErr == null && dErr == null && w != null && d != null) {
      final lmp = DateTime.now().subtract(Duration(days: w * 7 + d));
      setState(() {
        _selectedLmp = lmp;
        _selectedEdd = lmp.add(const Duration(days: 280));
        _lmpDate.text = _dateFmt.format(lmp);
        _eddDate.text = _dateFmt.format(_selectedEdd!);
        _gestationError = _validateLmp(lmp);
      });
    }
  }

  String _getFormattedAog() {
    if (_selectedLmp == null) return '';
    final days = DateTime.now().difference(_selectedLmp!).inDays;
    if (days < 0) return '';
    final weeks = days ~/ 7;
    final remainingDays = days % 7;
    return '$weeks weeks, $remainingDays days';
  }

  Future<void> _handlePrimaryAction() async {
    if (_currentStep < 1) {
      _nextStep();
      return;
    }

    await _saveProfileAndContinue();
  }

  Future<void> _saveProfileAndContinue() async {
    final userId = await AuthStorage.getUserId();
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please login again.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    // Validate required fields
    if (_firstName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your first name'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_lastName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your last name'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_birthDate.text.trim().isEmpty || _birthdateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_birthdateError ?? 'Please enter your birth date'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_registeredWithEmail) {
      if (_contactNumber.text.trim().isEmpty || _phoneError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_phoneError ?? 'Please enter your contact number'),
              backgroundColor: AppColors.error),
        );
        return;
      }
    } else {
      if (_emailAddress.text.trim().isEmpty ||
          _emailError != null ||
          _emailChecking) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_emailError ?? 'Please enter a valid email address'),
              backgroundColor: AppColors.error),
        );
        return;
      }
    }

    // Prepare profile data
    final profileData = {
      'first_name': _firstName.text.trim(),
      'middle_name': _middleName.text.trim(),
      'last_name': _lastName.text.trim(),
      'extension_name': _selectedExtension.isEmpty ? null : _selectedExtension,
      'birth_date': _selectedBirthdate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedBirthdate!)
          : '',
      'contact_number': _contactNumber.text.trim(),
      'email_address':
          _emailAddress.text.trim().isEmpty ? null : _emailAddress.text.trim(),
      'lmp': _selectedLmp?.toIso8601String().split('T')[0],
      'edd': _selectedEdd?.toIso8601String().split('T')[0],
    };

    final res =
        await SupabaseService.completeMotherProfile(userId, profileData);

    if (!res['success']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (res['mother_id'] != null) {
      await AuthStorage.saveMotherId(res['mother_id'] as int);
    }

    await AuthStorage.saveProfileComplete(true);

    if (!mounted) return;

    // Navigate directly to WelcomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  // Emergency exit
  Future<void> _emergencyExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Profile Setup'),
        content: const Text(
          'Are you sure you want to exit?\n\n'
          'Your profile information will NOT be saved.\n'
          'You will be logged out and need to log in again.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await PushNotificationService.removeToken();
      await AuthStorage.clearAll();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    }
  }

  bool get _canProceedFromStep0 {
    final baseFields = _firstName.text.isNotEmpty &&
        _lastName.text.isNotEmpty &&
        _birthDate.text.isNotEmpty &&
        _birthdateError == null;
    if (_registeredWithEmail) {
      return baseFields &&
          _contactNumber.text.isNotEmpty &&
          _phoneError == null;
    } else {
      return baseFields &&
          _emailAddress.text.isNotEmpty &&
          _emailError == null &&
          !_emailChecking;
    }
  }

  bool get _canProceedFromStep1 {
    if (_gestationError != null) return false;
    if (_dueDateBasis == DueDateBasis.lmp && _selectedLmp == null) return false;
    if (_dueDateBasis == DueDateBasis.edd && _selectedEdd == null) return false;
    if (_dueDateBasis == DueDateBasis.aog) {
      if (_weeksError != null || _daysError != null) return false;
      final weeks = int.tryParse(_aogWeeks.text.trim()) ?? 0;
      final days = int.tryParse(_aogDays.text.trim()) ?? 0;
      if (weeks == 0 && days == 0) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Complete Profile'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep == 0 ? _emergencyExit : _previousStep,
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _stepHeader(),
          ),
          const SizedBox(height: 16),
          ProgressiveStepIndicator(
            currentStep: _currentStep,
            totalSteps: 2,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _personalInfoStep(),
                _gestationStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                MainButton(
                  label: _currentStep == 1 ? 'Save Profile' : 'Next',
                  showIcons: false,
                  onPressed: _currentStep == 0
                      ? (_canProceedFromStep0 ? _handlePrimaryAction : null)
                      : (_canProceedFromStep1 ? _handlePrimaryAction : null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader() {
    switch (_currentStep) {
      case 0:
        return const PageTitle(
          title: 'Personal Details',
          leadingIcon: Icons.person,
          trailingIcon: Icons.check,
        );
      default:
        return const PageTitle(
          title: 'Pregnancy Details',
          leadingIcon: Icons.pregnant_woman,
          trailingIcon: Icons.check,
        );
    }
  }

  Widget _buildExtensionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInputField(
          controller: TextEditingController(
              text: _selectedExtension.isEmpty ? 'None' : _selectedExtension),
          hintText: 'Extension',
          readOnly: true,
          trailingIcon: Icons.keyboard_arrow_down_rounded,
          onTap: () {
            setState(() {
              _showExtensionDropdown = !_showExtensionDropdown;
            });
          },
        ),
        if (_showExtensionDropdown) ...[
          const SizedBox(height: 4),
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _extensionOptions.length,
                itemBuilder: (context, idx) {
                  final ext = _extensionOptions[idx];
                  return ListTile(
                    title: Text(ext.isEmpty ? 'None' : ext,
                        style: const TextStyle(fontSize: 14)),
                    dense: true,
                    onTap: () {
                      setState(() {
                        _selectedExtension = ext;
                        _showExtensionDropdown = false;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _personalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AppInputField(
            hintText: 'First Name',
            controller: _firstName,
            isRequired: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Last Name',
            controller: _lastName,
            isRequired: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Middle Name',
            controller: _middleName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildExtensionDropdown(),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedBirthdate ?? DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedBirthdate = pickedDate;
                  _birthDate.text = _dateFmt.format(pickedDate);
                  _validateBirthdate();
                });
              }
            },
            child: AbsorbPointer(
              child: AppInputField(
                hintText: 'Birthdate',
                controller: _birthDate,
                isRequired: true,
                leadingIcon: Icons.calendar_today,
                errorText: _birthdateError,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_registeredWithEmail) ...[
            const SizedBox(height: 12),
            AppInputField(
              hintText: 'Contact Number',
              controller: _contactNumber,
              isRequired: true,
              keyboardType: TextInputType.phone,
              leadingIcon: Icons.phone,
              errorText: _phoneError,
              onChanged: (_) => _onPhoneChanged(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            AppInputField(
              hintText: 'Email Address*',
              controller: _emailAddress,
              isRequired: true,
              keyboardType: TextInputType.emailAddress,
              leadingIcon: Icons.email,
              errorText: _emailError,
              onChanged: _onEmailChanged,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _gestationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Due Date Basis Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How would you like to calculate your due date?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBasisOption(
                  title: 'Last Menstrual Period (LMP)',
                  subtitle: 'Based on the first day of your last period',
                  basis: DueDateBasis.lmp,
                  selected: _dueDateBasis == DueDateBasis.lmp,
                  onTap: () => setState(() => _dueDateBasis = DueDateBasis.lmp),
                ),
                const SizedBox(height: 8),
                _buildBasisOption(
                  title: 'Estimated Delivery Date (EDD)',
                  subtitle: 'If you already know your due date',
                  basis: DueDateBasis.edd,
                  selected: _dueDateBasis == DueDateBasis.edd,
                  onTap: () => setState(() => _dueDateBasis = DueDateBasis.edd),
                ),
                const SizedBox(height: 8),
                _buildBasisOption(
                  title: 'Age of Gestation (AOG)',
                  subtitle: 'Enter how many weeks and days pregnant you are',
                  basis: DueDateBasis.aog,
                  selected: _dueDateBasis == DueDateBasis.aog,
                  onTap: () => setState(() => _dueDateBasis = DueDateBasis.aog),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Date Entry based on selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dueDateBasis == DueDateBasis.lmp) ...[
                  const Text(
                    'Last Menstrual Period',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedLmp ??
                            DateTime.now().subtract(const Duration(days: 14)),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 43 * 7)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _updateFromLmp(picked));
                      }
                    },
                    child: AbsorbPointer(
                      child: AppInputField(
                        hintText: 'Select LMP date',
                        controller: _lmpDate,
                        isRequired: true,
                        leadingIcon: Icons.calendar_today,
                        readOnly: true,
                        errorText: _gestationError,
                      ),
                    ),
                  ),
                ] else if (_dueDateBasis == DueDateBasis.edd) ...[
                  const Text(
                    'Estimated Delivery Date',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedEdd ??
                            DateTime.now().add(const Duration(days: 280)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _updateFromEdd(picked));
                      }
                    },
                    child: AbsorbPointer(
                      child: AppInputField(
                        hintText: 'Select EDD date',
                        controller: _eddDate,
                        isRequired: true,
                        leadingIcon: Icons.event_available,
                        readOnly: true,
                        errorText: _gestationError,
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Age of Gestation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppInputField(
                          hintText: 'Weeks',
                          controller: _aogWeeks,
                          keyboardType: TextInputType.number,
                          errorText: _weeksError,
                          onChanged: (_) => _updateFromAog(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppInputField(
                          hintText: 'Days',
                          controller: _aogDays,
                          keyboardType: TextInputType.number,
                          errorText: _daysError,
                          onChanged: (_) => _updateFromAog(),
                        ),
                      ),
                    ],
                  ),
                  if (_gestationError != null &&
                      _weeksError == null &&
                      _daysError == null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        _gestationError!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderPrimary),
                const SizedBox(height: 16),
                _infoRow(
                  Icons.calendar_today,
                  'LMP',
                  _lmpDate.text.isEmpty ? 'Not set' : _lmpDate.text,
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.event_available,
                  'EDD',
                  _eddDate.text.isEmpty ? 'Not set' : _eddDate.text,
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.timer,
                  'Current AOG',
                  _getFormattedAog().isEmpty
                      ? 'Not calculated'
                      : _getFormattedAog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBasisOption({
    required String title,
    required String subtitle,
    required DueDateBasis basis,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.borderPrimary,
          ),
        ),
        child: Row(
          children: [
            Radio<DueDateBasis>(
              value: basis,
              groupValue: _dueDateBasis,
              onChanged: (_) => onTap(),
              activeColor: AppColors.brandPrimary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
