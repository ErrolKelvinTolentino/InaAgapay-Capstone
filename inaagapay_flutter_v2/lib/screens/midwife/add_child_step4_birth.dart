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
import 'midwife_children_screen.dart';

class AddChildStep4Birth extends StatefulWidget {
  final int motherId;
  final String motherName;
  final String firstName;
  final String lastName;
  final String middleName;
  final String extensionName;
  final String sex;

  const AddChildStep4Birth({
    super.key,
    required this.motherId,
    required this.motherName,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.extensionName,
    required this.sex,
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

  DateTime? selectedBirthdate;

  bool get isFormValid =>
      birthdateCtrl.text.isNotEmpty &&
      birthWeightCtrl.text.isNotEmpty &&
      birthLengthCtrl.text.isNotEmpty &&
      provinceCtrl.text.isNotEmpty &&
      cityCtrl.text.isNotEmpty;

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
      // Insert child record
      final childResponse = await Supabase.instance.client
          .from('children')
          .insert({
            'mother_id': widget.motherId,
            'first_name': widget.firstName,
            'last_name': widget.lastName,
            'middle_name': widget.middleName.isEmpty ? null : widget.middleName,
            'extension_name': widget.extensionName.isEmpty ? null : widget.extensionName,
            'sex': widget.sex,
            'added_at': DateTime.now().toIso8601String(),
          })
          .select('child_id')
          .single();

      final childId = childResponse['child_id'] as int;

      // Insert birth details
      await Supabase.instance.client
          .from('birth_details')
          .insert({
            'child_id': childId,
            'birthdate': birthdateCtrl.text,
            'birth_weight': double.parse(birthWeightCtrl.text),
            'birth_length': double.parse(birthLengthCtrl.text),
            'head_circumference': headCtrl.text.isEmpty ? null : double.parse(headCtrl.text),
            'birthplace_city_municipality': cityCtrl.text,
            'birthplace_province': provinceCtrl.text,
            'birth_complications': complicationsCtrl.text.isEmpty ? null : complicationsCtrl.text,
            'created_at': DateTime.now().toIso8601String(),
          });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return DialogBox(
            type: DialogType.success,
            title: 'Child Added',
            content: 'The child has been successfully registered.',
            buttonText: 'OK',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MidwifeChildrenScreen(),
                ),
                (route) => false,
              );
            },
          );
        },
      );
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add child: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.brandPrimary),
                    const SizedBox(height: 20),
                    Text(
                      'Adding child...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      const SmallDescription(
                        text: 'Enter the child\'s birth details',
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
                            // Birth Date
                            AppInputField(
                              hintText: 'Birth Date',
                              controller: birthdateCtrl,
                              isRequired: true,
                              readOnly: true,
                              onTap: _pickBirthdate,
                              trailingIcon: Icons.calendar_today,
                              onTrailingTap: _pickBirthdate,
                            ),
                            const SizedBox(height: 16),

                            // Birth Weight
                            AppInputField(
                              hintText: 'Birth Weight (kg)',
                              controller: birthWeightCtrl,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // Birth Length
                            AppInputField(
                              hintText: 'Birth Length (cm)',
                              controller: birthLengthCtrl,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // Head Circumference
                            AppInputField(
                              hintText: 'Head Circumference (cm)',
                              controller: headCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // Birth Province
                            AppInputField(
                              hintText: 'Birth Province',
                              controller: provinceCtrl,
                              isRequired: true,
                            ),
                            const SizedBox(height: 16),

                            // Birth City
                            AppInputField(
                              hintText: 'Birth City/Municipality',
                              controller: cityCtrl,
                              isRequired: true,
                            ),
                            const SizedBox(height: 16),

                            // Birth Complications
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.borderPrimary),
                              ),
                              child: TextField(
                                controller: complicationsCtrl,
                                maxLines: 3,
                                minLines: 1,
                                decoration: const InputDecoration(
                                  hintText: 'Birth Complications (Optional)',
                                  border: InputBorder.none,
                                  icon: Icon(Icons.medical_information, color: AppColors.brandPrimary),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: AppColors.brandPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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