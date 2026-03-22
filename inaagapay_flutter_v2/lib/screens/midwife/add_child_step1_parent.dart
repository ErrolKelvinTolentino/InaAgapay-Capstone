import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/small_description.dart';
import 'add_child_step2_address.dart';
import 'add_child_step3_child.dart';

class AddChildStep1Parent extends StatefulWidget {
  const AddChildStep1Parent({super.key});

  @override
  State<AddChildStep1Parent> createState() => _AddChildStep1ParentState();
}

class _AddChildStep1ParentState extends State<AddChildStep1Parent> {
  bool manualEntry = false;
  Map<String, dynamic>? selectedMother;

  bool mothersLoaded = false;
  List<Map<String, dynamic>> mothers = [];
  List<Map<String, dynamic>> filteredMothers = [];

  final _searchController = TextEditingController();
  final motherFirstNameCtrl = TextEditingController();
  final motherLastNameCtrl = TextEditingController();
  final motherMiddleNameCtrl = TextEditingController();
  final motherExtensionCtrl = TextEditingController();
  final motherPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchMothers();
  }

  Future<void> fetchMothers() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) return;

      final response = await Supabase.instance.client
          .from('mothers')
          .select('''
            mother_id,
            account:accounts!inner(
              first_name,
              middle_name,
              last_name,
              extension_name,
              phone_number
            ),
            barangay,
            city_municipality
          ''')
          .eq('status', 'active');

      setState(() {
        mothers = List<Map<String, dynamic>>.from(response);
        filteredMothers = List.from(mothers);
        mothersLoaded = true;
      });
    } catch (e) {
      setState(() => mothersLoaded = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading mothers: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void filterMothers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredMothers = List.from(mothers);
      } else {
        filteredMothers = mothers.where((mother) {
          final account = mother['account'] as Map<String, dynamic>?;
          final firstName = account?['first_name']?.toString().toLowerCase() ?? '';
          final lastName = account?['last_name']?.toString().toLowerCase() ?? '';
          final fullName = '$firstName $lastName';
          return fullName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getMotherName(Map<String, dynamic> mother) {
    final account = mother['account'] as Map<String, dynamic>?;
    final firstName = account?['first_name']?.toString() ?? '';
    final lastName = account?['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim();
  }

  bool get isFormValid {
    if (manualEntry) {
      return motherFirstNameCtrl.text.isNotEmpty &&
          motherLastNameCtrl.text.isNotEmpty &&
          motherPhoneCtrl.text.isNotEmpty;
    } else {
      return selectedMother != null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    motherFirstNameCtrl.dispose();
    motherLastNameCtrl.dispose();
    motherMiddleNameCtrl.dispose();
    motherExtensionCtrl.dispose();
    motherPhoneCtrl.dispose();
    super.dispose();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: PageTitle(
                  title: 'Parent Information',
                  leadingIcon: Icons.person_outline,
                  trailingIcon: Icons.check_circle,
                ),
              ),
              const SizedBox(height: 16),
              const SmallDescription(
                text: 'Select an existing mother or add a new one',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Toggle Buttons
              Container(
                padding: const EdgeInsets.all(12),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            manualEntry = false;
                            selectedMother = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !manualEntry ? AppColors.brandPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Search Mother',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: !manualEntry ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            manualEntry = true;
                            selectedMother = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: manualEntry ? AppColors.brandPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'New Mother',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: manualEntry ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!manualEntry) ...[
                AppInputField(
                  hintText: 'Search mother by name',
                  controller: _searchController,
                  onChanged: filterMothers,
                  leadingIcon: Icons.search,
                ),
                const SizedBox(height: 16),

                if (!mothersLoaded)
                  const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
                else if (filteredMothers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Icon(Icons.person_search, size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No mothers found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term or add a new mother',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Select a mother (${filteredMothers.length} found)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredMothers.length,
                            itemBuilder: (context, index) {
                              final mother = filteredMothers[index];
                              final isSelected = selectedMother?['mother_id'] == mother['mother_id'];
                              final motherName = _getMotherName(mother);
                              final barangay = mother['barangay']?.toString() ?? '';
                              final city = mother['city_municipality']?.toString() ?? '';
                              // With this:
String address = '';
if (barangay.isNotEmpty && city.isNotEmpty) {
  address = '$barangay, $city';
} else if (barangay.isNotEmpty) {
  address = barangay;
} else if (city.isNotEmpty) {
  address = city;
}
address = address.trim();

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? AppColors.brandPrimary : AppColors.bgSecondary,
                                    child: Text(
                                      motherName.isNotEmpty ? motherName[0].toUpperCase() : 'M',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    motherName,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: address.isNotEmpty
                                      ? Text(
                                          address,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle, color: AppColors.brandPrimary)
                                      : null,
                                  onTap: () {
                                    setState(() => selectedMother = mother);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                // New Mother Form
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
                      Text(
                        'Mother Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      AppInputField(
                        hintText: 'First Name',
                        controller: motherFirstNameCtrl,
                        isRequired: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      AppInputField(
                        hintText: 'Last Name',
                        controller: motherLastNameCtrl,
                        isRequired: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      AppInputField(
                        hintText: 'Middle Name (Optional)',
                        controller: motherMiddleNameCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      AppInputField(
                        hintText: 'Extension Name (Optional)',
                        controller: motherExtensionCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      AppInputField(
                        hintText: 'Phone Number',
                        controller: motherPhoneCtrl,
                        isRequired: true,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              MainButton(
                label: 'Continue',
                onPressed: isFormValid ? () {
                  if (!manualEntry && selectedMother != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddChildStep3Child(
                          motherId: selectedMother!['mother_id'],
                          isExistingMother: true,
                          motherFirstName: _getMotherName(selectedMother!),
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddChildStep2Address(
                          motherFirstName: motherFirstNameCtrl.text.trim(),
                          motherLastName: motherLastNameCtrl.text.trim(),
                          motherMiddleName: motherMiddleNameCtrl.text.trim(),
                          motherExtension: motherExtensionCtrl.text.trim(),
                          motherPhone: motherPhoneCtrl.text.trim(),
                        ),
                      ),
                    );
                  }
                } : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}