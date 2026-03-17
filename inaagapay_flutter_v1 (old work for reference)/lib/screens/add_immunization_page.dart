import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/page_title.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/dialog_box.dart';
import '../widgets/confirmation_dialog_box.dart';
import '../widgets/validation_message.dart';
import '../models/vaccine_model.dart';
import '../services/vaccine_service.dart';

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

  String? _selectedVaccineKey;
  int? _selectedVaccineId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  List<VaccineModel> _vaccines = [];
  bool _vaccinesLoading = true;
  Set<int> _takenVaccineIds = {};
  Set<String> _takenVaccineNames = {};

  @override
  void initState() {
    super.initState();
    _loadVaccines();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------
  /// LOAD VACCINES FROM API WITH TAKEN VACCINES CHECK
  /// --------------------------------------------------
  Future<void> _loadVaccines() async {
    try {
      // First, load available vaccines
      final data = await VaccineService.fetchVaccines();
      
      // Then, load already taken vaccines for this child
      final taken = await _fetchTakenVaccines();

      setState(() {
        _vaccines = data;
        _takenVaccineIds = taken.$1;
        _takenVaccineNames = taken.$2;
        _vaccinesLoading = false;
      });
    } catch (e) {
      // If API fails, use default vaccines
      _setDefaultVaccines();
    }
  }

  Future<(Set<int>, Set<String>)> _fetchTakenVaccines() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) return (<int>{}, <String>{});

      final response = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_immunization_list.php?child_id=${widget.childId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final records = decoded['records'] is List ? decoded['records'] : [];

        final ids = <int>{};
        final names = <String>{};
        for (final r in records) {
          final id = int.tryParse(r['vaccine_id']?.toString() ?? '');
          if (id != null) ids.add(id);
          final name = r['vaccine_name']?.toString().trim();
          if (name != null && name.isNotEmpty) names.add(name);
        }

        return (ids, names);
      }
      return (<int>{}, <String>{});
    } catch (_) {
      return (<int>{}, <String>{});
    }
  }

  /// --------------------------------------------------
  /// GET AVAILABLE VACCINES (EXCLUDE ALREADY TAKEN)
  /// --------------------------------------------------
  List<VaccineModel> _getAvailableVaccines() {
    return _vaccines.where((v) {
      final alreadyTaken = _takenVaccineIds.contains(v.vaccineId) ||
          _takenVaccineNames.contains(v.vaccineName);
      return !alreadyTaken;
    }).toList();
  }

  void _setDefaultVaccines() {
    // Convert default vaccines to VaccineModel format
    final defaultVaccines = [
      {
        'vaccine_id': '1',
        'vaccine_name': 'BCG',
        'dose_number': '1',
        'recommended_age_months': '0',
        'target_recipients': 'Infants at birth',
        'notes': 'At Birth'
      },
      {
        'vaccine_id': '2',
        'vaccine_name': 'Hepatitis B',
        'dose_number': '1',
        'recommended_age_months': '0',
        'target_recipients': 'Infants at birth',
        'notes': 'At Birth'
      },
      {
        'vaccine_id': '3',
        'vaccine_name': 'Pentavalent',
        'dose_number': '1',
        'recommended_age_months': '1.5',
        'target_recipients': 'Infants at 6 weeks',
        'notes': '6 Weeks'
      },
      {
        'vaccine_id': '4',
        'vaccine_name': 'OPV',
        'dose_number': '1',
        'recommended_age_months': '1.5',
        'target_recipients': 'Infants at 6 weeks',
        'notes': '6 Weeks'
      },
      {
        'vaccine_id': '5',
        'vaccine_name': 'PCV',
        'dose_number': '1',
        'recommended_age_months': '1.5',
        'target_recipients': 'Infants at 6 weeks',
        'notes': '6 Weeks'
      },
      {
        'vaccine_id': '6',
        'vaccine_name': 'Rotavirus',
        'dose_number': '1',
        'recommended_age_months': '1.5',
        'target_recipients': 'Infants at 6 weeks',
        'notes': '6 Weeks'
      },
      {
        'vaccine_id': '7',
        'vaccine_name': 'Pentavalent',
        'dose_number': '2',
        'recommended_age_months': '2.5',
        'target_recipients': 'Infants at 10 weeks',
        'notes': '10 Weeks'
      },
      {
        'vaccine_id': '8',
        'vaccine_name': 'OPV',
        'dose_number': '2',
        'recommended_age_months': '2.5',
        'target_recipients': 'Infants at 10 weeks',
        'notes': '10 Weeks'
      },
      {
        'vaccine_id': '9',
        'vaccine_name': 'PCV',
        'dose_number': '2',
        'recommended_age_months': '2.5',
        'target_recipients': 'Infants at 10 weeks',
        'notes': '10 Weeks'
      },
      {
        'vaccine_id': '10',
        'vaccine_name': 'Rotavirus',
        'dose_number': '2',
        'recommended_age_months': '2.5',
        'target_recipients': 'Infants at 10 weeks',
        'notes': '10 Weeks'
      },
    ];

    _vaccines = defaultVaccines.map((v) {
      return VaccineModel.fromJson(v);
    }).toList();
    
    _vaccinesLoading = false;
  }

  /// --------------------------------------------------
  /// FORM VALIDATION
  /// --------------------------------------------------
  bool get _isFormValid =>
      _selectedVaccineKey != null && _selectedDate != null;

  /// --------------------------------------------------
  /// DATE PICKER
  /// --------------------------------------------------
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
        _dateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  /// --------------------------------------------------
  /// GROUP VACCINES BY AGE (ONLY AVAILABLE ONES)
  /// --------------------------------------------------
  Map<String, List<VaccineModel>> _groupVaccinesByAge() {
    final Map<String, List<VaccineModel>> grouped = {};
    final availableVaccines = _getAvailableVaccines();
    
    for (final vaccine in availableVaccines) {
      // Use notes as age label if available, otherwise use target_recipients
      final ageLabel = vaccine.notes ?? vaccine.targetRecipients;
      grouped.putIfAbsent(ageLabel, () => []);
      grouped[ageLabel]!.add(vaccine);
    }
    
    return grouped;
  }

  /// --------------------------------------------------
  /// VACCINE DROPDOWN (CALCULATOR STYLE) - ONLY SHOW AVAILABLE
  /// --------------------------------------------------
  void _openVaccineDropdown() {
    if (_vaccinesLoading) return;
    
    final groupedVaccines = _groupVaccinesByAge();
    final availableVaccines = _getAvailableVaccines();

    if (availableVaccines.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => DialogBox(
          type: DialogType.info,
          title: 'No Vaccines Available',
          subtitle: 'All recorded vaccines are already taken for this child.',
          buttonText: 'OK',
          onPressed: () => Navigator.pop(context),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                /// NO DUPLICATES MESSAGE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Only showing vaccines not yet recorded for this child',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                /// FIXED: Removed unnecessary .toList() from spread
                ...groupedVaccines.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// AGE LABEL
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      /// VACCINES
                      ...entry.value.map((vaccine) {
                        final vaccineId = vaccine.vaccineId.toString();
                        final vaccineName = vaccine.vaccineName;
                        final doseNumber = vaccine.doseNumber;
                        final displayName = '$vaccineName (Dose $doseNumber)';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedVaccineKey = vaccineId;
                              _selectedVaccineId = vaccine.vaccineId;
                              _vaccineController.text = displayName;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle_outlined,
                                  size: 18,
                                  color: _selectedVaccineKey == vaccineId
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedVaccineKey == vaccineId
                                          ? AppColors.brandPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_selectedVaccineKey == vaccineId)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.brandPrimary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --------------------------------------------------
  /// SUBMIT IMMUNIZATION USING VACCINE SERVICE
  /// --------------------------------------------------
  Future<bool> _submitImmunization() async {
    if (_selectedVaccineId == null || _selectedDate == null) {
      return false;
    }

    try {
      final success = await VaccineService.addImmunization(
        childId: widget.childId,
        vaccineId: _selectedVaccineId!,
        vaccinationDate: _selectedDate!,
        remarks: _remarksController.text.trim(),
      );

      return success;
    } catch (e) {
      return false;
    }
  }

  /// --------------------------------------------------
  /// SUBMIT FLOW
  /// --------------------------------------------------
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
          
          if (success) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogBox(
                type: DialogType.success,
                title: 'Immunization Added',
                subtitle: 'The immunization record has been successfully saved.',
                buttonText: 'OK',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true); // Return true to refresh parent
                },
              ),
            );
          } else {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogBox(
                type: DialogType.error,
                title: 'Failed to Add',
                subtitle: 'There was an error saving the immunization record. Please try again.',
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

      /// HEADER
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

              /// LOADING INDICATOR FOR VACCINES
              if (_vaccinesLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                ),

              /// SELECT VACCINE
              AppInputField(
                hintText: 'Select Vaccine',
                controller: _vaccineController,
                leadingIcon: Icons.vaccines_outlined,
                trailingIcon: Icons.keyboard_arrow_down_rounded,
                readOnly: false,
                onTap: _vaccinesLoading ? null : _openVaccineDropdown,
                isRequired: true,
              ),

              /// NO AVAILABLE VACCINES MESSAGE
              if (!_vaccinesLoading && !hasAvailableVaccines)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Text(
                    'All recorded vaccines are already taken for this child.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              /// DATE
              AppInputField(
                hintText: 'Vaccination Date',
                controller: _dateController,
                leadingIcon: Icons.calendar_month_rounded,
                readOnly: false,
                onTap: _selectDate,
                isRequired: true,
              ),

              const SizedBox(height: 16),

              /// REMARKS
              AppInputField(
                hintText: 'Remarks (optional)',
                controller: _remarksController,
                leadingIcon: Icons.notes_rounded,
              ),

              const SizedBox(height: 12),

              if (!_isFormValid)
                const ValidationMessage(
                  message: 'Please complete all required fields before submitting.',
                  type: ValidationType.info,
                ),

              const SizedBox(height: 28),

              /// SUBMIT BUTTON
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : MainButton(
                      label: 'Add Immunization Record',
                      onPressed: (_isFormValid && hasAvailableVaccines) ? _submit : null,
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}