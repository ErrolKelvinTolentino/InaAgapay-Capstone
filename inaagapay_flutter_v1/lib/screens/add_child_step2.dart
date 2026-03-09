import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/page_title.dart';
import '../widgets/main_button.dart';
import '../widgets/small_description.dart';
import 'add_child_step3.dart';

class AddChildStep2 extends StatefulWidget {
  // ================= FROM STEP 1 =================
  final String motherFirstName;
  final String motherLastName;
  final String motherMiddleName;
  final String motherExtension;
  final String motherPhone;

  const AddChildStep2({
    super.key,
    required this.motherFirstName,
    required this.motherLastName,
    required this.motherMiddleName,
    required this.motherExtension,
    required this.motherPhone,
  });

  @override
  State<AddChildStep2> createState() => _AddChildStep2State();
}

class _AddChildStep2State extends State<AddChildStep2> {
  final _formKey = GlobalKey<FormState>();

  // ================= ADDRESS CONTROLLERS =================
  final houseCtrl = TextEditingController();
  final streetCtrl = TextEditingController();
  final barangayCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();

  bool isSaving = false;

  bool get isFormValid =>
      barangayCtrl.text.isNotEmpty &&
      cityCtrl.text.isNotEmpty &&
      provinceCtrl.text.isNotEmpty;

  @override
  void dispose() {
    houseCtrl.dispose();
    streetCtrl.dispose();
    barangayCtrl.dispose();
    cityCtrl.dispose();
    provinceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final token = await AuthStorage.getToken();

    // 🔥🔥🔥 FIXED PAYLOAD (MATCHES add_mother.php EXACTLY) 🔥🔥🔥
    final payload = {
      "account": {
        "first_name": widget.motherFirstName,
        "middle_name": widget.motherMiddleName,
        "last_name": widget.motherLastName,
        "extension_name": widget.motherExtension,
        "phone_number": widget.motherPhone,
        // backend auto-generates if null
        "email_address": null,
      },
      "address": {
        "house_number": houseCtrl.text.trim(),
        "street": streetCtrl.text.trim(),
        "barangay": barangayCtrl.text.trim(),
        "city_municipality": cityCtrl.text.trim(),
        "province": provinceCtrl.text.trim(),
      }
    };

    final res = await http.post(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/add_mother.php',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(res.body);
    setState(() => isSaving = false);

    if (decoded['success'] == true) {
      final int motherId = decoded['mother_id'];

      // ✅ PROCEED TO CHILD STEP 3 WITH REAL mother_id
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddChildStep3Child(
            motherId: motherId,
            isExistingMother: false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message'] ?? 'Failed to add mother'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🧬 SECTION TITLE
                Center(
                  child: PageTitle(
                    title: 'Mother Address',
                    leadingIcon: Icons.home_outlined,
                    trailingIcon: Icons.check_circle,
                  ),
                ),

                const SizedBox(height: 16),

                /// 📝 DESCRIPTION
                const SmallDescription(
                  text: 'Enter the mother\'s complete address',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                /// 🏠 ADDRESS FORM
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
                      // House Number
                      TextFormField(
                        controller: houseCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'House Number (Optional)',
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
                      ),
                      const SizedBox(height: 16),

                      // Street
                      TextFormField(
                        controller: streetCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Street (Optional)',
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
                      ),
                      const SizedBox(height: 16),

                      // Barangay with validation
                      TextFormField(
                        controller: barangayCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Barangay',
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
                        validator: (value) => value == null || value.isEmpty ? 'Barangay is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // City with validation
                      TextFormField(
                        controller: cityCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'City / Municipality',
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
                        validator: (value) => value == null || value.isEmpty ? 'City is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Province with validation
                      TextFormField(
                        controller: provinceCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Province',
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
                        validator: (value) => value == null || value.isEmpty ? 'Province is required' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                /// ➕ CONTINUE BUTTON
                if (isSaving)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.brandPrimary),
                        const SizedBox(height: 16),
                        Text(
                          'Saving mother information...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
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
                          label: 'Continue',
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