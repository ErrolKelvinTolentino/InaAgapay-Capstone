// lib/screens/midwife/add_immunization_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/confirmation_dialog_box.dart';
import '../../widgets/validation_message.dart';

class AddImmunizationPage extends StatefulWidget {
  final int childId;

  const AddImmunizationPage({
    super.key,
    required this.childId,
  });

  @override
  State<AddImmunizationPage> createState() => _AddImmunizationPageState();
}

class _AddImmunizationPageState extends State<AddImmunizationPage> {
  final TextEditingController _vaccineController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  int? _selectedVaccineId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _vaccines = [];
  bool _vaccinesLoading = true;
  Set<int> _takenVaccineIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _vaccinesLoading = true;
      _errorMessage = null;
    });
    
    await _loadVaccines();
    await _loadTakenVaccines();
    
    setState(() => _vaccinesLoading = false);
    
    // Debug output
    debugPrint('Vaccines loaded: ${_vaccines.length}');
    debugPrint('Taken vaccines: ${_takenVaccineIds.length}');
    debugPrint('Available vaccines: ${_getAvailableVaccines().length}');
  }

  Future<void> _loadVaccines() async {
    try {
      final response = await Supabase.instance.client
          .from('vaccines')
          .select('*')
          .eq('target_recipients', 'child')
          .order('recommended_age_months')
          .order('vaccine_name');

      _vaccines = List<Map<String, dynamic>>.from(response);
      
      if (_vaccines.isEmpty) {
        setState(() {
          _errorMessage = 'No vaccines found in the database. Please add vaccines first.';
        });
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading vaccines: $e');
      setState(() {
        _errorMessage = 'Failed to load vaccines: $e';
      });
    }
  }

  Future<void> _loadTakenVaccines() async {
    try {
      final response = await Supabase.instance.client
          .from('immunization_record')
          .select('vaccine_id')
          .eq('child_id', widget.childId);

      final taken = List<Map<String, dynamic>>.from(response);
      setState(() {
        _takenVaccineIds = taken.map((t) => t['vaccine_id'] as int).toSet();
      });
    } catch (e) {
      debugPrint('Error loading taken vaccines: $e');
    }
  }

  List<Map<String, dynamic>> _getAvailableVaccines() {
    return _vaccines.where((v) {
      final vaccineId = v['vaccine_id'] as int;
      return !_takenVaccineIds.contains(vaccineId);
    }).toList();
  }

  bool get _isFormValid =>
      _selectedVaccineId != null && _selectedDate != null;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _formatRecommendedAge(double? months) {
    if (months == null) return '';
    if (months == 0) return 'At birth';
    if (months < 1) {
      final weeks = (months * 4).round();
      return '$weeks weeks';
    }
    return '${months.toStringAsFixed(0)} months';
  }

  void _openVaccineDropdown() {
    if (_vaccinesLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading vaccines, please wait...')),
      );
      return;
    }
    
    if (_vaccines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vaccines available in the system.')),
      );
      return;
    }
    
    final availableVaccines = _getAvailableVaccines();

    if (availableVaccines.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => DialogBox(
          type: DialogType.info,
          title: 'No Vaccines Available',
          content: 'All recommended vaccines have already been administered to this child.',
          buttonText: 'OK',
          onPressed: () => Navigator.pop(context),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Vaccine',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: availableVaccines.length,
                  itemBuilder: (context, index) {
                    final vaccine = availableVaccines[index];
                    final vaccineName = vaccine['vaccine_name']?.toString() ?? '';
                    final doseNumber = vaccine['dose_number']?.toString() ?? '';
                    final notes = vaccine['notes']?.toString() ?? '';
                    final recommendedAge = (vaccine['recommended_age_months'] as num?)?.toDouble() ?? 0;
                    final ageText = _formatRecommendedAge(recommendedAge);
                    final displayName = '$vaccineName (Dose $doseNumber) - $ageText - $notes';

                    return ListTile(
                      leading: const Icon(Icons.vaccines, color: AppColors.brandPrimary),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedVaccineId = vaccine['vaccine_id'] as int;
                          _vaccineController.text = displayName;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _submitImmunization() async {
    if (_selectedVaccineId == null) {
      return false;
    }
    
    if (_selectedDate == null) {
      return false;
    }

    try {
      // Check if vaccine already given to this child
      final existing = await Supabase.instance.client
          .from('immunization_record')
          .select('immunization_record_id')
          .eq('child_id', widget.childId)
          .eq('vaccine_id', _selectedVaccineId!)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This vaccine has already been administered to this child.');
      }

      await Supabase.instance.client
          .from('immunization_record')
          .insert({
            'child_id': widget.childId,
            'vaccine_id': _selectedVaccineId!,
            'vaccination_date': _selectedDate!.toIso8601String().split('T')[0],
            'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('Error saving immunization: $e');
      return false;
    }
  }

  void _submit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmationDialogBox(
        title: 'Confirm Immunization',
        subtitle: 'Please review the details carefully. Immunization records cannot be edited once added.',
        confirmText: 'Confirm',
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          Navigator.pop(context);
          
          setState(() => _isLoading = true);
          
          final success = await _submitImmunization();
          
          setState(() => _isLoading = false);
          
          if (success && mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogBox(
                type: DialogType.success,
                title: 'Immunization Added',
                content: 'The immunization record has been successfully saved.',
                buttonText: 'OK',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
              ),
            );
          } else if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogBox(
                type: DialogType.error,
                title: 'Failed to Add',
                content: 'There was an error saving the immunization record. Please try again.',
                buttonText: 'OK',
                onPressed: () => Navigator.pop(context),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableVaccines = _getAvailableVaccines();
    final hasAvailableVaccines = availableVaccines.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Add Immunization',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: PageTitle(
                  title: 'Vaccine Details',
                  leadingIcon: Icons.vaccines_rounded,
                  trailingIcon: Icons.check_circle,
                ),
              ),
              const SizedBox(height: 16),

              // Show error if any
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (_vaccinesLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),

              // Debug info - shows counts (can be removed after testing)
              if (!_vaccinesLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Vaccines: ${_vaccines.length} total, ${_takenVaccineIds.length} taken, ${availableVaccines.length} available',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              // Select Vaccine
              GestureDetector(
                onTap: _vaccinesLoading ? null : _openVaccineDropdown,
                child: AbsorbPointer(
                  child: AppInputField(
                    hintText: 'Select Vaccine',
                    controller: _vaccineController,
                    leadingIcon: Icons.vaccines_outlined,
                    trailingIcon: Icons.keyboard_arrow_down_rounded,
                    isRequired: true,
                  ),
                ),
              ),

              if (!_vaccinesLoading && !hasAvailableVaccines && _vaccines.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Text(
                    'All recommended vaccines have already been administered.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Select Date
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: AppInputField(
                    hintText: 'Vaccination Date',
                    controller: _dateController,
                    leadingIcon: Icons.calendar_month_rounded,
                    isRequired: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remarks
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Remarks (optional)',
                    border: InputBorder.none,
                    icon: Icon(Icons.notes_rounded, color: AppColors.brandPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (!_isFormValid)
                const ValidationMessage(
                  message: 'Please complete all required fields before submitting.',
                  type: ValidationType.info,
                ),

              const SizedBox(height: 28),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : MainButton(
                      label: 'Add Immunization Record',
                      onPressed: (_isFormValid && hasAvailableVaccines && !_vaccinesLoading) ? _submit : null,
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}