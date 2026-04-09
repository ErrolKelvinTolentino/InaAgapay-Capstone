// lib/screens/mother/complete_profile.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/progressive_step_indicator.dart';
import '../../widgets/page_title.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';
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
  final _extensionName = TextEditingController();
  final _birthDate = TextEditingController();
  final _contactNumber = TextEditingController();

  // Due Date / Gestation
  DueDateBasis _dueDateBasis = DueDateBasis.lmp;
  final _lmpDate = TextEditingController();
  final _eddDate = TextEditingController();
  final _aogWeeks = TextEditingController();
  final _aogDays = TextEditingController();
  DateTime? _selectedLmp;
  DateTime? _selectedEdd;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _middleName.dispose();
    _extensionName.dispose();
    _birthDate.dispose();
    _contactNumber.dispose();
    _lmpDate.dispose();
    _eddDate.dispose();
    _aogWeeks.dispose();
    _aogDays.dispose();
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

  void _updateFromLmp(DateTime lmp) {
    _selectedLmp = lmp;
    _lmpDate.text = _formatDate(lmp);
    _selectedEdd = lmp.add(const Duration(days: 280));
    _eddDate.text = _formatDate(_selectedEdd!);
  }

  void _updateFromEdd(DateTime edd) {
    _selectedEdd = edd;
    _eddDate.text = _formatDate(edd);
    _selectedLmp = edd.subtract(const Duration(days: 280));
    _lmpDate.text = _formatDate(_selectedLmp!);
  }

  void _updateFromAog() {
    final weeks = int.tryParse(_aogWeeks.text.trim()) ?? 0;
    final days = int.tryParse(_aogDays.text.trim()) ?? 0;
    if (weeks == 0 && days == 0) return;
    final totalDays = (weeks * 7) + days;
    final lmp = DateTime.now().subtract(Duration(days: totalDays));
    _updateFromLmp(lmp);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

    if (_birthDate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your birth date'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_contactNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your contact number'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    // Prepare profile data
    final profileData = {
      'first_name': _firstName.text.trim(),
      'middle_name': _middleName.text.trim(),
      'last_name': _lastName.text.trim(),
      'extension_name': _extensionName.text.trim(),
      'birth_date': _birthDate.text.trim(),
      'contact_number': _contactNumber.text.trim(),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
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
    return _firstName.text.isNotEmpty &&
        _lastName.text.isNotEmpty &&
        _birthDate.text.isNotEmpty &&
        _contactNumber.text.isNotEmpty;
  }

  bool get _canProceedFromStep1 {
    if (_dueDateBasis == DueDateBasis.lmp && _selectedLmp == null) return false;
    if (_dueDateBasis == DueDateBasis.edd && _selectedEdd == null) return false;
    if (_dueDateBasis == DueDateBasis.aog) {
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
        actions: [
          TextButton.icon(
            onPressed: _emergencyExit,
            icon: const Icon(Icons.exit_to_app, size: 20),
            label: const Text('Exit'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _emergencyExit,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Emergency Exit to Login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
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
            hintText: 'Extension Name (Jr., III, etc.)',
            controller: _extensionName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _birthDate.text = _formatDate(pickedDate);
                });
              }
            },
            child: AbsorbPointer(
              child: AppInputField(
                hintText: 'Birthdate*',
                controller: _birthDate,
                isRequired: true,
                leadingIcon: Icons.calendar_today,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppInputField(
            hintText: 'Contact Number*',
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
                        initialDate: _selectedLmp ?? DateTime.now(),
                        firstDate: DateTime(2020),
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
                    children: [
                      Expanded(
                        child: AppInputField(
                          hintText: 'Weeks',
                          controller: _aogWeeks,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateFromAog(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppInputField(
                          hintText: 'Days',
                          controller: _aogDays,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateFromAog(),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
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
