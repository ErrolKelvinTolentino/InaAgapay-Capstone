import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/main_button.dart';
import '../../widgets/small_description.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/app_input_field.dart';
import 'add_child_step3_child.dart';
import 'midwife_children_screen.dart';

class AddChildStep4Birth extends StatefulWidget {
  final ChildParentMode mode;

  // Child info
  final String firstName;
  final String lastName;
  final String middleName;
  final String extensionName;
  final String sex;

  // Registered Mother mode
  final int? motherId;
  final String? motherName;

  // New Guardian mode
  final String? guardianFirstName;
  final String? guardianLastName;
  final String? guardianMiddleName;
  final String? guardianExtensionName;
  final String? guardianPhone;
  final String? guardianAddress;
  final String? guardianRelationship;

  const AddChildStep4Birth({
    super.key,
    required this.mode,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.extensionName,
    required this.sex,
    this.motherId,
    this.motherName,
    this.guardianFirstName,
    this.guardianLastName,
    this.guardianMiddleName,
    this.guardianExtensionName,
    this.guardianPhone,
    this.guardianAddress,
    this.guardianRelationship,
  });

  @override
  State<AddChildStep4Birth> createState() => _AddChildStep4BirthState();
}

class _AddChildStep4BirthState extends State<AddChildStep4Birth> {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  final birthdateCtrl = TextEditingController();
  final birthWeightCtrl = TextEditingController();
  final birthLengthCtrl = TextEditingController();
  final headCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final complicationsCtrl = TextEditingController();
  final birthplaceCtrl = TextEditingController();

  DateTime? selectedBirthdate;
  bool _isEstimatedBirthdate = false;

  bool get isFormValid {
    final birthdateValid = birthdateCtrl.text.isNotEmpty;
    final birthWeightValid = birthWeightCtrl.text.isNotEmpty &&
        double.tryParse(birthWeightCtrl.text) != null;
    final birthLengthValid = birthLengthCtrl.text.isNotEmpty &&
        double.tryParse(birthLengthCtrl.text) != null;
    final birthplaceValid = birthplaceCtrl.text.trim().isNotEmpty;

    return birthdateValid &&
        birthWeightValid &&
        birthLengthValid &&
        birthplaceValid;
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedBirthdate = picked;
        birthdateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      int? guardianId;

      if (widget.mode == ChildParentMode.newGuardian) {
        final guardianResponse = await Supabase.instance.client
            .from('guardians')
            .insert({
              'first_name': widget.guardianFirstName,
              'last_name': widget.guardianLastName,
              'middle_name': widget.guardianMiddleName?.isEmpty == true
                  ? null
                  : widget.guardianMiddleName,
              'extension_name': widget.guardianExtensionName?.isEmpty == true
                  ? null
                  : widget.guardianExtensionName,
              'phone_number': widget.guardianPhone?.isEmpty == true
                  ? null
                  : widget.guardianPhone,
              'address': widget.guardianAddress?.isEmpty == true
                  ? null
                  : widget.guardianAddress,
              'relationship': widget.guardianRelationship ?? 'Guardian',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('guardian_id')
            .single();

        guardianId = guardianResponse['guardian_id'] as int;
      }

      final Map<String, dynamic> childData = {
        'first_name': widget.firstName,
        'last_name': widget.lastName,
        'middle_name': widget.middleName.isEmpty ? null : widget.middleName,
        'extension_name':
            widget.extensionName.isEmpty ? null : widget.extensionName,
        'sex': widget.sex,
        'added_at': DateTime.now().toIso8601String(),
      };

      if (widget.mode == ChildParentMode.registeredMother &&
          widget.motherId != null) {
        childData['mother_id'] = widget.motherId;
        childData['guardian_id'] = null;
        childData['has_guardian_only'] = false;
      } else if (guardianId != null) {
        childData['mother_id'] = null;
        childData['guardian_id'] = guardianId;
        childData['has_guardian_only'] = true;
      } else {
        childData['mother_id'] = null;
        childData['guardian_id'] = null;
        childData['has_guardian_only'] = false;
      }

      debugPrint('Inserting child with data: $childData');

      final childResponse = await Supabase.instance.client
          .from('children')
          .insert(childData)
          .select('child_id')
          .single();

      final childId = childResponse['child_id'] as int;

      await Supabase.instance.client.from('birth_details').insert({
        'child_id': childId,
        'birthdate': birthdateCtrl.text,
        'is_birthdate_estimated': _isEstimatedBirthdate,
        'birth_weight': double.parse(birthWeightCtrl.text),
        'birth_length': double.parse(birthLengthCtrl.text),
        'head_circumference':
            headCtrl.text.isEmpty ? null : double.parse(headCtrl.text),
        'birthplace_city_municipality': cityCtrl.text,
        'birthplace_province': provinceCtrl.text,
        'birthplace_facility': birthplaceCtrl.text.trim(),
        'birth_complications':
            complicationsCtrl.text.isEmpty ? null : complicationsCtrl.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      String successMessage;
      if (widget.mode == ChildParentMode.registeredMother) {
        successMessage =
            'Child has been successfully registered to ${widget.motherName ?? 'the mother'}.';
      } else {
        successMessage =
            'Child has been successfully registered with guardian ${widget.guardianFirstName} ${widget.guardianLastName} (${widget.guardianRelationship ?? 'Guardian'}).';
      }

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return DialogBox(
            type: DialogType.success,
            title: 'Child Added',
            content: successMessage,
            buttonText: 'OK',
            onPressed: () {
              Navigator.pop(context);
            },
          );
        },
      );

      // After dialog closes, pop back to the children screen (preserves bottom nav)
      if (mounted) {
        // Pop twice to go back to the children screen (once for birth details, once for child info)
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving child: $e');
      setState(() => isSaving = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add child: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    birthdateCtrl.dispose();
    birthWeightCtrl.dispose();
    birthLengthCtrl.dispose();
    headCtrl.dispose();
    provinceCtrl.dispose();
    cityCtrl.dispose();
    complicationsCtrl.dispose();
    birthplaceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String parentDisplayName;
    if (widget.mode == ChildParentMode.registeredMother &&
        widget.motherName != null) {
      parentDisplayName = widget.motherName!;
    } else if (widget.guardianFirstName != null &&
        widget.guardianLastName != null) {
      parentDisplayName =
          '${widget.guardianFirstName} ${widget.guardianLastName}';
    } else {
      parentDisplayName = 'Guardian';
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Add Child',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: isSaving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.brandPrimary),
                    SizedBox(height: 20),
                    Text(
                      'Adding child...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait a moment',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: PageTitle(
                          title: 'Birth Information',
                          leadingIcon: Icons.cake_outlined,
                          trailingIcon: Icons.check_circle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SmallDescription(
                        text: widget.mode == ChildParentMode.registeredMother
                            ? 'Enter the child\'s birth details (Mother: $parentDisplayName)'
                            : 'Enter the child\'s birth details (Guardian: $parentDisplayName)',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickBirthdate,
                              child: AbsorbPointer(
                                child: AppInputField(
                                  hintText: 'Birth Date *',
                                  controller: birthdateCtrl,
                                  isRequired: true,
                                  readOnly: true,
                                  trailingIcon: Icons.calendar_today,
                                  onTrailingTap: _pickBirthdate,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isEstimatedBirthdate,
                                  onChanged: (value) {
                                    setState(() {
                                      _isEstimatedBirthdate = value ?? false;
                                    });
                                  },
                                  activeColor: AppColors.brandPrimary,
                                ),
                                const Text(
                                  'Birth date is estimated',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Birth Weight (kg) *',
                              controller: birthWeightCtrl,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Birth Length (cm) *',
                              controller: birthLengthCtrl,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Head Circumference (cm)',
                              controller: headCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Birth Province *',
                              controller: provinceCtrl,
                              isRequired: true,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Birth City/Municipality *',
                              controller: cityCtrl,
                              isRequired: true,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInputField(
                              hintText: 'Birthplace (Hospital/Clinic/Home) *',
                              controller: birthplaceCtrl,
                              isRequired: true,
                              leadingIcon: Icons.location_on_outlined,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(28),
                                border:
                                    Border.all(color: AppColors.borderPrimary),
                              ),
                              child: TextField(
                                controller: complicationsCtrl,
                                maxLines: 3,
                                minLines: 1,
                                decoration: const InputDecoration(
                                  hintText: 'Birth Complications (Optional)',
                                  border: InputBorder.none,
                                  icon: Icon(Icons.medical_information,
                                      color: AppColors.brandPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: AppColors.brandPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'Back',
                                style: TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MainButton(
                              label: 'Add Child',
                              onPressed: isFormValid ? _saveChild : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
