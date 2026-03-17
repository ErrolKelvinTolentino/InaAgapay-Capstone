import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/page_title.dart';
import '../widgets/main_button.dart';
import '../widgets/small_description.dart';
import '../widgets/dialog_box.dart';
import '../widgets/confirmation_dialog_box.dart';
import 'midwife_children_page.dart';

class AddChildStep4Birth extends StatefulWidget {
  final int motherId;

  // 🔥 CHILD DATA FROM STEP 3
  final String firstName;
  final String lastName;
  final String middleName;
  final String extensionName;
  final String sex;

  const AddChildStep4Birth({
    super.key,
    required this.motherId,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ConfirmationDialogBox(
          title: 'Add Child',
          subtitle: 'Please review all information before saving. This cannot be undone.',
          confirmText: 'Confirm',
          cancelText: 'Review',
          onCancel: () => Navigator.pop(context),
          onConfirm: () async {
            Navigator.pop(context);
            await _saveChild();
          },
        );
      },
    );
  }

  Future<void> _saveChild() async {
    setState(() => isSaving = true);

    final token = await AuthStorage.getToken();

    final payload = {
      "mother_id": widget.motherId,
      "child": {
        "first_name": widget.firstName,
        "last_name": widget.lastName,
        "middle_name": widget.middleName,
        "extension_name": widget.extensionName,
        "sex": widget.sex
      },
      "birth": {
        "birthdate": birthdateCtrl.text,
        "birth_weight": double.parse(birthWeightCtrl.text),
        "birth_length": double.parse(birthLengthCtrl.text),
        "head_circumference":
            headCtrl.text.isEmpty ? null : double.parse(headCtrl.text),
        "birthplace_city_municipality": cityCtrl.text,
        "birthplace_province": provinceCtrl.text,
        "birth_complications": complicationsCtrl.text
      }
    };

    try {
      final res = await http.post(
        Uri.parse('https://inaagapay.alwaysdata.net/api/midwife/add_child.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(res.body);
      setState(() => isSaving = false);

      if (decoded['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return DialogBox(
              type: DialogType.success,
              title: 'Child Added',
              subtitle: 'The child has been successfully registered.',
              buttonText: 'OK',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MidwifeChildrenPage(),
                  ),
                  (route) => false,
                );
              },
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Failed to add child'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Network error. Please try again.'),
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
      
      /// 🔝 HEADER
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
                      /// 🧬 SECTION TITLE
                      Center(
                        child: PageTitle(
                          title: 'Birth Information',
                          leadingIcon: Icons.cake_outlined,
                          trailingIcon: Icons.check_circle,
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// 📝 DESCRIPTION
                      const SmallDescription(
                        text: 'Enter the child\'s birth details',
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      /// 🎂 BIRTH FORM
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Birth Date with validation
                            TextFormField(
                              controller: birthdateCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth Date',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.calendar_today, color: AppColors.brandPrimary),
                                  onPressed: _pickBirthdate,
                                ),
                              ),
                              readOnly: true,
                              onTap: _pickBirthdate,
                              validator: (value) => value == null || value.isEmpty ? 'Birth date is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Birth Weight with validation
                            TextFormField(
                              controller: birthWeightCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth Weight (kg)',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value == null || value.isEmpty ? 'Birth weight is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Birth Length with validation
                            TextFormField(
                              controller: birthLengthCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth Length (cm)',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value == null || value.isEmpty ? 'Birth length is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Head Circumference (Optional)
                            TextFormField(
                              controller: headCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Head Circumference (cm)',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // Birth Province with validation
                            TextFormField(
                              controller: provinceCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth Province',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Birth province is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Birth City with validation
                            TextFormField(
                              controller: cityCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth City/Municipality',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Birth city is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Birth Complications
                            TextFormField(
                              controller: complicationsCtrl,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Birth Complications (Optional)',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.borderPrimary),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
                                ),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      /// ➕ ADD CHILD BUTTON
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
                              onPressed: isFormValid ? _submit : null,
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