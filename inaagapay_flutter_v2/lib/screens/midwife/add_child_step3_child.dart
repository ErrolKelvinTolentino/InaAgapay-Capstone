import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/main_button.dart';
import '../../widgets/small_description.dart';
import '../../widgets/app_input_field.dart';
import 'add_child_step4_birth.dart';

enum ChildParentMode {
  registeredMother,
  newGuardian,
}

const List<String> _extensionOptions = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

class AddChildStep3Child extends StatefulWidget {
  final ChildParentMode mode;

  const AddChildStep3Child({
    super.key,
    required this.mode,
  });

  @override
  State<AddChildStep3Child> createState() => _AddChildStep3ChildState();
}

class _AddChildStep3ChildState extends State<AddChildStep3Child> {
  final _formKey = GlobalKey<FormState>();

  // Child fields
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final middleNameCtrl = TextEditingController();
  String _selectedExtension = '';
  String sex = 'male';

  // For REGISTERED MOTHER mode - list of ALL mothers in database
  List<Map<String, dynamic>> _allMothers = [];
  Map<String, dynamic>? _selectedMother;
  bool _loadingMothers = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredMothers = [];

  // For NEW GUARDIAN mode - guardian details
  final guardianFirstNameCtrl = TextEditingController();
  final guardianLastNameCtrl = TextEditingController();
  final guardianMiddleNameCtrl = TextEditingController();
  String _guardianSelectedExtension = '';
  final guardianPhoneCtrl = TextEditingController();
  final guardianAddressCtrl = TextEditingController();
  String _guardianRelationship = 'Guardian';

  final List<String> _relationshipOptions = [
    'Mother',
    'Father',
    'Guardian',
    'Grandparent',
    'Sibling',
    'Aunt',
    'Uncle',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.mode == ChildParentMode.registeredMother) {
      _loadAllMothers();
    }
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    middleNameCtrl.dispose();
    guardianFirstNameCtrl.dispose();
    guardianLastNameCtrl.dispose();
    guardianMiddleNameCtrl.dispose();
    guardianPhoneCtrl.dispose();
    guardianAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllMothers() async {
    setState(() => _loadingMothers = true);

    try {
      // Step 1: Get ALL mother accounts from accounts table
      final accountsResponse = await Supabase.instance.client
          .from('accounts')
          .select('''
            account_id,
            email_address,
            first_name,
            last_name,
            middle_name,
            extension_name,
            phone_number,
            status,
            is_verified
          ''')
          .eq('account_type', 'mother')
          .eq('is_verified', true)
          .eq('status', 'active');

      debugPrint('=== TOTAL MOTHER ACCOUNTS FOUND: ${accountsResponse.length} ===');
      
      if (accountsResponse.isEmpty) {
        debugPrint('No mother accounts found in accounts table!');
        setState(() {
          _allMothers = [];
          _filteredMothers = [];
          _loadingMothers = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No registered mothers found. Please add mothers first.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Step 2: Get mother records to get mother_id
      final accountIds = accountsResponse.map<int>((a) => a['account_id'] as int).toList();
      
      final mothersResponse = await Supabase.instance.client
          .from('mothers')
          .select('mother_id, account_id')
          .inFilter('account_id', accountIds);

      // Create a map for quick lookup
      final Map<int, int> motherIdByAccountId = {};
      for (var mother in mothersResponse) {
        motherIdByAccountId[mother['account_id'] as int] = mother['mother_id'] as int;
      }

      // Step 3: Combine the data
      final List<Map<String, dynamic>> mothers = [];
      for (var account in accountsResponse) {
        final accountId = account['account_id'] as int;
        final motherId = motherIdByAccountId[accountId];
        
        if (motherId != null) {
          final firstName = account['first_name']?.toString() ?? '';
          final lastName = account['last_name']?.toString() ?? '';
          final displayName = '$firstName $lastName'.trim();
          
          mothers.add({
            'mother_id': motherId,
            'account_id': accountId,
            'first_name': firstName,
            'last_name': lastName,
            'middle_name': account['middle_name']?.toString() ?? '',
            'extension_name': account['extension_name']?.toString() ?? '',
            'phone_number': account['phone_number']?.toString() ?? '',
            'email_address': account['email_address']?.toString() ?? '',
            'display_name': displayName.isEmpty ? 'Unknown Mother' : displayName,
          });
          
          debugPrint('Loaded mother: $displayName (ID: $motherId, Phone: ${account['phone_number']})');
        } else {
          debugPrint('Warning: Account ${account['email_address']} has no mother record');
        }
      }

      setState(() {
        _allMothers = mothers;
        _filteredMothers = mothers;
        _loadingMothers = false;
      });
      
      debugPrint('=== TOTAL MOTHERS WITH VALID RECORDS: ${mothers.length} ===');
      
    } catch (e) {
      debugPrint('Error loading mothers: $e');
      setState(() => _loadingMothers = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading mothers: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _filterMothers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMothers = _allMothers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredMothers = _allMothers.where((mother) {
          final name = mother['display_name'].toLowerCase();
          final phone = mother['phone_number'].toLowerCase();
          final email = mother['email_address'].toLowerCase();
          return name.contains(lowerQuery) || 
                 phone.contains(lowerQuery) || 
                 email.contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _showMotherSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Select Registered Mother',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandText,
                      ),
                    ),
                  ),
                  
                  // Count info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      '${_filteredMothers.length} mother${_filteredMothers.length != 1 ? 's' : ''} available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  
                  // Search field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (value) {
                        setModalState(() {
                          _filterMothers(value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or email...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: () {
                                  setModalState(() {
                                    _searchQuery = '';
                                    _filteredMothers = _allMothers;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.brandPrimary),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // List of mothers
                  Expanded(
                    child: _loadingMothers
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brandPrimary,
                            ),
                          )
                        : _filteredMothers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty 
                                          ? Icons.person_off 
                                          : Icons.search_off,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No registered mothers found'
                                          : 'No matching mothers found',
                                      style: const TextStyle(color: AppColors.textSecondary),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          setModalState(() {
                                            _searchQuery = '';
                                            _filteredMothers = _allMothers;
                                          });
                                        },
                                        child: const Text('Clear search'),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredMothers.length,
                                itemBuilder: (context, index) {
                                  final mother = _filteredMothers[index];
                                  final isSelected = _selectedMother?['mother_id'] == mother['mother_id'];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                                      child: Text(
                                        mother['first_name'].isNotEmpty 
                                            ? mother['first_name'][0].toUpperCase()
                                            : 'M',
                                        style: TextStyle(
                                          color: AppColors.brandPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      mother['display_name'],
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (mother['phone_number'].isNotEmpty)
                                          Text(
                                            mother['phone_number'],
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        if (mother['email_address'].isNotEmpty)
                                          Text(
                                            mother['email_address'],
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                      ],
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: AppColors.success)
                                        : null,
                                    tileColor: isSelected 
                                        ? AppColors.success.withValues(alpha: 0.05)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedMother = mother;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get isFormValid {
    if (firstNameCtrl.text.trim().isEmpty) return false;
    if (lastNameCtrl.text.trim().isEmpty) return false;

    if (widget.mode == ChildParentMode.registeredMother) {
      return _selectedMother != null;
    } else {
      return guardianFirstNameCtrl.text.trim().isNotEmpty && 
             guardianLastNameCtrl.text.trim().isNotEmpty;
    }
  }

  String get _selectedMotherName {
    if (_selectedMother == null) return '';
    return _selectedMother!['display_name'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isRegisteredMode = widget.mode == ChildParentMode.registeredMother;
    
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: isRegisteredMode ? 'Link to Mother' : 'Add Guardian',
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
                    title: 'Child Information',
                    leadingIcon: Icons.child_care,
                    trailingIcon: Icons.check_circle,
                  ),
                ),
                const SizedBox(height: 16),
                SmallDescription(
                  text: isRegisteredMode
                      ? 'Enter child details and select the registered mother'
                      : 'Enter child details and guardian information',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Child Information Card
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
                        hintText: 'First Name *',
                        controller: firstNameCtrl,
                        isRequired: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'Last Name *',
                        controller: lastNameCtrl,
                        isRequired: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      AppInputField(
                        hintText: 'Middle Name (Optional)',
                        controller: middleNameCtrl,
                      ),
                      const SizedBox(height: 16),

                      _buildExtensionDropdown(),
                      const SizedBox(height: 16),

                      // Sex Selection
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
                              'Sex *',
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
                                            ? AppColors.brandPrimary.withValues(alpha: 0.1) 
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
                                            ? AppColors.brandPrimary.withValues(alpha: 0.1) 
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

                const SizedBox(height: 24),

                if (isRegisteredMode)
                  _buildRegisteredMotherSection()
                else
                  _buildNewGuardianSection(),

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
                        label: 'Continue',
                        onPressed: isFormValid ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddChildStep4Birth(
                                mode: widget.mode,
                                motherId: isRegisteredMode && _selectedMother != null
                                    ? _selectedMother!['mother_id'] as int
                                    : null,
                                motherName: isRegisteredMode && _selectedMother != null
                                    ? _selectedMotherName
                                    : null,
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                middleName: middleNameCtrl.text.trim(),
                                extensionName: _selectedExtension,
                                sex: sex,
                                guardianFirstName: !isRegisteredMode 
                                    ? guardianFirstNameCtrl.text.trim() 
                                    : null,
                                guardianLastName: !isRegisteredMode 
                                    ? guardianLastNameCtrl.text.trim() 
                                    : null,
                                guardianMiddleName: !isRegisteredMode 
                                    ? guardianMiddleNameCtrl.text.trim() 
                                    : null,
                                guardianExtensionName: !isRegisteredMode 
                                    ? _guardianSelectedExtension 
                                    : null,
                                guardianPhone: !isRegisteredMode 
                                    ? guardianPhoneCtrl.text.trim() 
                                    : null,
                                guardianAddress: !isRegisteredMode 
                                    ? guardianAddressCtrl.text.trim() 
                                    : null,
                                guardianRelationship: !isRegisteredMode 
                                    ? _guardianRelationship 
                                    : null,
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

  Widget _buildExtensionDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExtension.isEmpty ? null : _selectedExtension,
          hint: const Text('Extension Name (Jr., III)', style: TextStyle(color: AppColors.textSecondary)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: _extensionOptions.map((ext) {
            return DropdownMenuItem(
              value: ext.isEmpty ? null : ext,
              child: Text(ext.isEmpty ? 'None' : ext),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedExtension = value ?? '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildRegisteredMotherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pregnant_woman, color: AppColors.brandPrimary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Select Registered Mother',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tappable container that opens the bottom sheet
          GestureDetector(
            onTap: _loadingMothers ? null : _showMotherSelectionSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.borderPrimary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_loadingMothers)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  else
                    const Icon(Icons.person_outline, color: AppColors.brandPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _loadingMothers
                          ? 'Loading mothers...'
                          : (_selectedMother == null 
                              ? 'Tap to select a mother' 
                              : _selectedMotherName),
                      style: TextStyle(
                        color: _selectedMother == null && !_loadingMothers
                            ? AppColors.textSecondary 
                            : AppColors.textPrimary,
                        fontWeight: _selectedMother == null 
                            ? FontWeight.normal 
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!_loadingMothers)
                    const Icon(Icons.arrow_drop_down, color: AppColors.brandPrimary),
                ],
              ),
            ),
          ),

          if (_selectedMother != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected: $_selectedMotherName',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (_selectedMother!['phone_number'] != null && _selectedMother!['phone_number'].isNotEmpty)
                          Text(
                            _selectedMother!['phone_number'],
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewGuardianSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Guardian Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: AppInputField(
                  hintText: 'First Name *',
                  controller: guardianFirstNameCtrl,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  hintText: 'Last Name *',
                  controller: guardianLastNameCtrl,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          AppInputField(
            hintText: 'Middle Name (Optional)',
            controller: guardianMiddleNameCtrl,
          ),
          const SizedBox(height: 12),
          
          _buildGuardianExtensionDropdown(),
          const SizedBox(height: 12),
          
          AppInputField(
            hintText: 'Phone Number',
            controller: guardianPhoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          
          AppInputField(
            hintText: 'Address',
            controller: guardianAddressCtrl,
          ),
          const SizedBox(height: 12),
          
          _buildRelationshipDropdown(),
          
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This guardian will be saved in the guardians table and can be linked to multiple children.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianExtensionDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _guardianSelectedExtension.isEmpty ? null : _guardianSelectedExtension,
          hint: const Text('Extension Name (Optional)', style: TextStyle(color: AppColors.textSecondary)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: _extensionOptions.map((ext) {
            return DropdownMenuItem(
              value: ext.isEmpty ? null : ext,
              child: Text(ext.isEmpty ? 'None' : ext),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _guardianSelectedExtension = value ?? '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildRelationshipDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _guardianRelationship,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: _relationshipOptions.map((rel) {
            return DropdownMenuItem(
              value: rel,
              child: Text(rel),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _guardianRelationship = value ?? 'Guardian';
            });
          },
        ),
      ),
    );
  }
}