import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/progressive_step_indicator.dart';
import '../widgets/page_title.dart';
import '../services/supabase_service.dart';
import '../services/auth_storage.dart';
import 'welcome_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  int _currentStep = 0;

  // Controllers
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _middleName = TextEditingController();
  final _extensionName = TextEditingController();
  final _birthDate = TextEditingController();
  final _contactNumber = TextEditingController();

  final _province = TextEditingController();
  final _city = TextEditingController();
  final _barangay = TextEditingController();
  final _street = TextEditingController();
  final _houseNo = TextEditingController();

  late final TextEditingController _addressSummary;

  @override
  void initState() {
    super.initState();
    print('=== COMPLETE PROFILE SCREEN INITIALIZED ===');
    _addressSummary = TextEditingController();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _middleName.dispose();
    _extensionName.dispose();
    _birthDate.dispose();
    _contactNumber.dispose();
    _province.dispose();
    _city.dispose();
    _barangay.dispose();
    _street.dispose();
    _houseNo.dispose();
    _addressSummary.dispose();
    super.dispose();
  }

  void _nextStep() {
    print('=== NEXT STEP CALLED ===');
    print('Current step: $_currentStep');
    
    if (_currentStep == 1) {
      _addressSummary.text =
          '${_province.text}, ${_city.text}, ${_barangay.text}';
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      print('New step: $_currentStep');
    }
  }

  void _previousStep() {
    print('Previous step called');
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _jumpToStep(int step) {
    print('Jump to step: $step');
    setState(() => _currentStep = step);
  }

  Future<void> _handlePrimaryAction() async {
    print('=== HANDLE PRIMARY ACTION ===');
    print('Current step: $_currentStep');
    
    if (_currentStep < 2) {
      _nextStep();
      return;
    }

    await _saveProfileAndContinue();
  }

  Future<void> _saveProfileAndContinue() async {
    print('=== SAVING PROFILE ===');
    
    final userId = await AuthStorage.getUserId();
    print('User ID: $userId');
    
    if (userId == null) {
      print('ERROR: No user ID found');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please login again.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    final profileData = {
      'first_name': _firstName.text,
      'middle_name': _middleName.text,
      'last_name': _lastName.text,
      'extension_name': _extensionName.text,
      'birth_date': _birthDate.text,
      'contact_number': _contactNumber.text,
      'province': _province.text,
      'city': _city.text,
      'barangay': _barangay.text,
      'street': _street.text,
      'house_no': _houseNo.text,
    };
    
    print('Profile data: $profileData');

    final res = await SupabaseService.completeMotherProfile(
      userId,
      profileData,
    );

    print('Profile save response: $res');

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

    await AuthStorage.saveProfileComplete(true);

    if (!mounted) return;

    print('Navigating to welcome screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  bool get _canProceedFromStep0 {
    final isValid = _firstName.text.isNotEmpty &&
        _lastName.text.isNotEmpty &&
        _birthDate.text.isNotEmpty &&
        _contactNumber.text.isNotEmpty;
    
    print('=== STEP 0 VALIDATION ===');
    print('First name: ${_firstName.text.isNotEmpty} (${_firstName.text})');
    print('Last name: ${_lastName.text.isNotEmpty} (${_lastName.text})');
    print('Birth date: ${_birthDate.text.isNotEmpty} (${_birthDate.text})');
    print('Contact: ${_contactNumber.text.isNotEmpty} (${_contactNumber.text})');
    print('Can proceed: $isValid');
    
    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    print('=== COMPLETE PROFILE BUILD ===');
    print('Current step: $_currentStep');
    print('Step 0 button enabled: ${_currentStep == 0 ? _canProceedFromStep0 : true}');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            SecondaryHeader(
              title: 'Complete Your Profile',
              onBack: _currentStep == 0 ? null : _previousStep,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _stepHeader(),
            ),
            const SizedBox(height: 16),
            ProgressiveStepIndicator(
              currentStep: _currentStep,
              totalSteps: 3,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _personalInfoStep(),
                  _addressStep(),
                  _reviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: MainButton(
                label: _currentStep == 2 ? 'Save Profile' : 'Next',
                showIcons: false,
                onPressed: _currentStep == 0
                    ? (_canProceedFromStep0 ? _handlePrimaryAction : null)
                    : _handlePrimaryAction,
              ),
            ),
          ],
        ),
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
      case 1:
        return const PageTitle(
          title: 'Address (Optional)',
          leadingIcon: Icons.home,
          trailingIcon: Icons.check,
        );
      default:
        return const PageTitle(
          title: 'Review Information',
          leadingIcon: Icons.edit,
          trailingIcon: Icons.check,
        );
    }
  }

  Widget _personalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AppInputField(
            hintText: 'First Name*',
            controller: _firstName,
            isRequired: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Last Name*',
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
          AppInputField(
            hintText: 'Extension Name',
            controller: _extensionName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Birthdate*',
            controller: _birthDate,
            isRequired: true,
            leadingIcon: Icons.calendar_today,
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );

              if (pickedDate != null) {
                setState(() {
                  _birthDate.text =
                      '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                });
              }
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: '+63 Contact Number*',
            controller: _contactNumber,
            isRequired: true,
            keyboardType: TextInputType.phone,
            leadingIcon: Icons.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _addressStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AppInputField(
            hintText: 'Province',
            controller: _province,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'City / Municipality',
            controller: _city,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Barangay',
            controller: _barangay,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Street Name',
            controller: _street,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'House No.',
            controller: _houseNo,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _reviewField('First Name', _firstName, () => _jumpToStep(0)),
          const SizedBox(height: 12),
          _reviewField('Middle Name', _middleName, () => _jumpToStep(0)),
          const SizedBox(height: 12),
          _reviewField('Last Name', _lastName, () => _jumpToStep(0)),
          const SizedBox(height: 12),
          _reviewField('Birthdate', _birthDate, () => _jumpToStep(0)),
          const SizedBox(height: 12),
          _reviewField(
            '+63 Contact Number',
            _contactNumber,
            () => _jumpToStep(0),
          ),
          const SizedBox(height: 12),
          _reviewField('Address', _addressSummary, () => _jumpToStep(1)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _reviewField(
    String label,
    TextEditingController controller,
    VoidCallback onEdit,
  ) {
    return AppInputField(
      hintText: label,
      controller: controller,
      readOnly: true,
      trailingIcon: Icons.edit,
      onTrailingTap: onEdit,
    );
  }
}