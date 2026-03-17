import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/page_title.dart';
import '../widgets/app_input_field.dart';
import '../widgets/main_button.dart';
import '../widgets/small_description.dart';
import 'add_child_step2.dart';
import 'add_child_step3.dart';

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

  // ================= CONTROLLERS =================
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
      final token = await AuthStorage.getToken();

      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/search_mothers.php',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final decoded = jsonDecode(res.body);

      if (decoded['success'] == true) {
        setState(() {
          mothers = List<Map<String, dynamic>>.from(decoded['data']);
          filteredMothers = List.from(mothers);
          mothersLoaded = true;
        });
      } else {
        setState(() => mothersLoaded = true);
      }
    } catch (e) {
      setState(() => mothersLoaded = true);
    }
  }

  void filterMothers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredMothers = List.from(mothers);
      } else {
        filteredMothers = mothers.where((mother) {
          final name = mother['name']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🧬 SECTION TITLE
              Center(
                child: PageTitle(
                  title: 'Parent Information',
                  leadingIcon: Icons.person_outline,
                  trailingIcon: Icons.check_circle,
                ),
              ),

              const SizedBox(height: 16),

              /// 📝 DESCRIPTION
              const SmallDescription(
                text: 'Select an existing mother or add a new one',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              /// 🔘 TOGGLE BUTTONS
              Container(
                padding: const EdgeInsets.all(12),
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
                /// 🔍 SEARCH EXISTING MOTHER
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
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
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
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
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
                          color: Colors.black.withOpacity(0.05),
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
                          height: 200,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredMothers.length,
                            itemBuilder: (context, index) {
                              final mother = filteredMothers[index];
                              final isSelected = selectedMother?['mother_id'] == mother['mother_id'];
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.brandPrimary.withOpacity(0.1) : Colors.transparent,
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
                                      mother['name']?.toString().substring(0, 1).toUpperCase() ?? 'M',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    mother['name']?.toString() ?? 'Unknown Mother',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    mother['barangay']?.toString() ?? 'No address',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
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
                /// 📝 NEW MOTHER FORM
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
                      Text(
                        'Mother Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: motherFirstNameCtrl,
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
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: motherLastNameCtrl,
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
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: motherMiddleNameCtrl,
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
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: motherExtensionCtrl,
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
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: motherPhoneCtrl,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
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
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              /// ➕ CONTINUE BUTTON
              MainButton(
                label: 'Continue',
                onPressed: isFormValid ? () {
                  if (!manualEntry) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddChildStep3Child(
                          motherId: selectedMother!['mother_id'],
                          isExistingMother: true,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddChildStep2(
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