import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/main_button.dart';
import '../../widgets/small_description.dart';
import '../../widgets/app_input_field.dart';
import 'add_child_step3_child.dart';

class AddChildStep2Address extends StatefulWidget {
  final String motherFirstName;
  final String motherLastName;
  final String motherMiddleName;
  final String motherExtension;
  final String motherPhone;

  const AddChildStep2Address({
    super.key,
    required this.motherFirstName,
    required this.motherLastName,
    required this.motherMiddleName,
    required this.motherExtension,
    required this.motherPhone,
  });

  @override
  State<AddChildStep2Address> createState() => _AddChildStep2AddressState();
}

class _AddChildStep2AddressState extends State<AddChildStep2Address> {
  final _formKey = GlobalKey<FormState>();

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

    try {
      // Create account first
      final accountResponse = await Supabase.instance.client
          .from('accounts')
          .insert({
            'email_address': '${widget.motherFirstName.toLowerCase()}.${widget.motherLastName.toLowerCase()}@temp.com',
            'password_hash': '', // Will be set later when mother logs in
            'account_type': 'mother',
            'first_name': widget.motherFirstName,
            'middle_name': widget.motherMiddleName.isEmpty ? null : widget.motherMiddleName,
            'last_name': widget.motherLastName,
            'extension_name': widget.motherExtension.isEmpty ? null : widget.motherExtension,
            'phone_number': widget.motherPhone,
            'is_verified': true,
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('account_id')
          .single();

      final accountId = accountResponse['account_id'] as int;

      // Create mother record
      final motherResponse = await Supabase.instance.client
          .from('mothers')
          .insert({
            'account_id': accountId,
            'house_number': houseCtrl.text.trim().isEmpty ? null : houseCtrl.text.trim(),
            'street': streetCtrl.text.trim().isEmpty ? null : streetCtrl.text.trim(),
            'barangay': barangayCtrl.text.trim(),
            'city_municipality': cityCtrl.text.trim(),
            'province': provinceCtrl.text.trim(),
            'status': 'active',
          })
          .select('mother_id')
          .single();

      final motherId = motherResponse['mother_id'] as int;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddChildStep3Child(
            motherId: motherId,
            isExistingMother: false,
            motherFirstName: widget.motherFirstName,
          ),
        ),
      );
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add mother: $e'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: PageTitle(
                    title: 'Mother Address',
                    leadingIcon: Icons.home_outlined,
                    trailingIcon: Icons.check_circle,
                  ),
                ),
                const SizedBox(height: 16),
                const SmallDescription(
                  text: 'Enter the mother\'s complete address',
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
                      AppInputField(
                        hintText: 'House Number (Optional)',
                        controller: houseCtrl,
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'Street (Optional)',
                        controller: streetCtrl,
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'Barangay',
                        controller: barangayCtrl,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'City / Municipality',
                        controller: cityCtrl,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'Province',
                        controller: provinceCtrl,
                        isRequired: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

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