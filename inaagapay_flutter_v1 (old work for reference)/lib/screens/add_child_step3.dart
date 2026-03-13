import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/page_title.dart';
import '../widgets/main_button.dart';
import '../widgets/small_description.dart';
import 'add_child_step4.dart';

class AddChildStep3Child extends StatefulWidget {
  final int motherId;
  final bool isExistingMother;

  const AddChildStep3Child({
    super.key,
    required this.motherId,
    required this.isExistingMother,
  });

  @override
  State<AddChildStep3Child> createState() => _AddChildStep3ChildState();
}

class _AddChildStep3ChildState extends State<AddChildStep3Child> {
  final _formKey = GlobalKey<FormState>();

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final middleNameCtrl = TextEditingController();
  final extensionCtrl = TextEditingController();

  String sex = 'male';

  bool get isFormValid =>
      firstNameCtrl.text.isNotEmpty &&
      lastNameCtrl.text.isNotEmpty;

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    middleNameCtrl.dispose();
    extensionCtrl.dispose();
    super.dispose();
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
                    title: 'Child Information',
                    leadingIcon: Icons.child_care,
                    trailingIcon: Icons.check_circle,
                  ),
                ),

                const SizedBox(height: 16),

                /// 📝 DESCRIPTION
                const SmallDescription(
                  text: 'Enter the child\'s basic information',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                /// 👶 CHILD FORM
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
                      // First Name with validation
                      TextFormField(
                        controller: firstNameCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'First Name',
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
                        validator: (value) => value == null || value.isEmpty ? 'First name is required' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Last Name with validation
                      TextFormField(
                        controller: lastNameCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
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
                        validator: (value) => value == null || value.isEmpty ? 'Last name is required' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Middle Name (Optional)
                      TextFormField(
                        controller: middleNameCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Middle Name (Optional)',
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
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Extension Name (Optional)
                      TextFormField(
                        controller: extensionCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Extension Name (Optional)',
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
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      /// 🚻 SEX SELECTION
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sex',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => sex = 'male'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: sex == 'male' 
                                            ? AppColors.brandPrimary.withOpacity(0.1) 
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sex == 'male' 
                                              ? AppColors.brandPrimary 
                                              : AppColors.borderPrimary,
                                          width: sex == 'male' ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.male,
                                            color: sex == 'male' 
                                                ? AppColors.brandPrimary 
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Male',
                                            style: TextStyle(
                                              fontWeight: sex == 'male' ? FontWeight.bold : FontWeight.normal,
                                              color: sex == 'male' 
                                                  ? AppColors.brandPrimary 
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => sex = 'female'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: sex == 'female' 
                                            ? AppColors.brandPrimary.withOpacity(0.1) 
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sex == 'female' 
                                              ? AppColors.brandPrimary 
                                              : AppColors.borderPrimary,
                                          width: sex == 'female' ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.female,
                                            color: sex == 'female' 
                                                ? AppColors.brandPrimary 
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Female',
                                            style: TextStyle(
                                              fontWeight: sex == 'female' ? FontWeight.bold : FontWeight.normal,
                                              color: sex == 'female' 
                                                  ? AppColors.brandPrimary 
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                /// ➕ CONTINUE BUTTON
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
                        onPressed: isFormValid ? () {
                          if (!_formKey.currentState!.validate()) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddChildStep4Birth(
                                motherId: widget.motherId,
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                middleName: middleNameCtrl.text.trim(),
                                extensionName: extensionCtrl.text.trim(),
                                sex: sex,
                              ),
                            ),
                          );
                        } : null,
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