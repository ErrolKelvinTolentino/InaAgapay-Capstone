// lib/screens/midwife/midwife_children_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../services/auth_storage.dart';
import 'child_profile_page.dart';
import 'add_child_step3_child.dart';

class MidwifeChildrenScreen extends StatefulWidget {
  const MidwifeChildrenScreen({super.key});

  @override
  State<MidwifeChildrenScreen> createState() => _MidwifeChildrenScreenState();
}

class _MidwifeChildrenScreenState extends State<MidwifeChildrenScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _filteredChildren = [];
  bool _loading = true;
  String? _errorMessage;
  int? _assignedBhcId;

  @override
  void initState() {
    super.initState();
    _loadMidwifeContext();
    _searchController.addListener(_filterChildren);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMidwifeContext() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) throw Exception('Not authenticated');
      
      final result = await Supabase.instance.client
          .from('midwives')
          .select('midwife_id, assigned_bhc_id')
          .eq('account_id', accountId)
          .single();

      _assignedBhcId = result['assigned_bhc_id'] as int;
      
      await _fetchChildren();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchChildren() async {
    if (_assignedBhcId == null) return;
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final mothersResponse = await Supabase.instance.client
          .from('mothers')
          .select('mother_id')
          .eq('assigned_bhc_id', _assignedBhcId!);
      
      final List<int> motherIds = [];
      for (var mother in mothersResponse) {
        motherIds.add(mother['mother_id'] as int);
      }
      
      if (motherIds.isEmpty) {
        setState(() {
          _children = [];
          _filteredChildren = [];
          _loading = false;
        });
        return;
      }
      
      final childrenResponse = await Supabase.instance.client
          .from('children')
          .select('''
            *,
            mother:mother_id (
              mother_id,
              account:account_id (
                first_name,
                last_name
              )
            ),
            birth_details (
              birthdate,
              birth_weight,
              birth_length
            )
          ''')
          .inFilter('mother_id', motherIds)
          .order('added_at', ascending: false);
      
      setState(() {
        _children = List<Map<String, dynamic>>.from(childrenResponse);
        _filteredChildren = List<Map<String, dynamic>>.from(childrenResponse);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  void _filterChildren() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredChildren = List.from(_children);
      });
    } else {
      setState(() {
        _filteredChildren = _children.where((child) {
          final firstName = (child['first_name'] ?? '').toString().toLowerCase();
          final lastName = (child['last_name'] ?? '').toString().toLowerCase();
          final fullName = '$firstName $lastName';
          return fullName.contains(query) || firstName.contains(query) || lastName.contains(query);
        }).toList();
      });
    }
  }

  String _formatAge(DateTime? birthdate) {
    if (birthdate == null) return 'Age unknown';
    final now = DateTime.now();
    int years = now.year - birthdate.year;
    int months = now.month - birthdate.month;
    
    if (months < 0) {
      years--;
      months += 12;
    }
    
    if (years <= 0) {
      return '$months month${months != 1 ? 's' : ''} old';
    } else {
      return '$years year${years != 1 ? 's' : ''} ${months > 0 ? '$months month${months != 1 ? 's' : ''}' : ''} old'.trim();
    }
  }

  String _getMotherName(Map<String, dynamic> child) {
    final mother = child['mother'] as Map<String, dynamic>?;
    if (mother == null) return 'Unknown';
    final account = mother['account'] as Map<String, dynamic>?;
    if (account == null) return 'Unknown';
    final firstName = account['first_name']?.toString() ?? '';
    final lastName = account['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim();
  }

  Future<void> _addChild() async {
    if (_assignedBhcId == null) return;
    
    final mothersResponse = await Supabase.instance.client
        .from('mothers')
        .select('mother_id, account:account_id (first_name, last_name)')
        .eq('assigned_bhc_id', _assignedBhcId!);
    
    if (mothersResponse.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No mothers found in your BHC. Please add a mother first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    final List<Map<String, dynamic>> mothers = List.from(mothersResponse);
    
    final int? selectedMotherId = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Mother'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: mothers.length,
            itemBuilder: (ctx, index) {
              final mother = mothers[index];
              final account = mother['account'] as Map<String, dynamic>?;
              final name = account != null
                  ? '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}'.trim()
                  : 'Mother ${mother['mother_id']}';
              final motherIdValue = mother['mother_id'] as int;
              return ListTile(
                title: Text(name),
                onTap: () => Navigator.pop(ctx, motherIdValue),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selectedMotherId != null && mounted) {
      final selectedMother = mothers.firstWhere((m) => m['mother_id'] == selectedMotherId);
      final account = selectedMother['account'] as Map<String, dynamic>?;
      final motherFirstName = account != null
          ? (account['first_name']?.toString() ?? '')
          : '';
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddChildStep3Child(
            motherId: selectedMotherId,
            isExistingMother: true,
            motherFirstName: motherFirstName,
          ),
        ),
      );
      if (result == true && mounted) {
        _fetchChildren();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Stats Card - Pink background with baby image
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 110,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/pinkbg.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    top: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0, top: 4.0, bottom: 4.0),
                      child: Image.asset(
                        'assets/images/baby.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'There are',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${_filteredChildren.length} Children',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppInputField(
                hintText: 'Search child by name',
                controller: _searchController,
                leadingIcon: Icons.search,
              ),
            ),

            const SizedBox(height: 16),

            // Helper Text
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                'Tap a child to view health records',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Children List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchChildren,
                color: AppColors.brandPrimary,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchChildren,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredChildren.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.child_care_outlined,
                                      size: 64,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No children found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Children will appear here once registered',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: _filteredChildren.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final child = _filteredChildren[index];
                                  final firstName = child['first_name']?.toString() ?? '';
                                  final lastName = child['last_name']?.toString() ?? '';
                                  final birthDetails = child['birth_details'] as Map<String, dynamic>?;
                                  final birthdate = birthDetails != null && birthDetails['birthdate'] != null
                                      ? DateTime.parse(birthDetails['birthdate'])
                                      : null;
                                  final age = _formatAge(birthdate);
                                  final motherName = _getMotherName(child);
                                  
                                  return _ChildCard(
                                    firstName: firstName,
                                    lastName: lastName,
                                    age: age,
                                    motherName: motherName,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChildProfilePage(
                                            childId: child['child_id'] as int,
                                          ),
                                        ),
                                      ).then((_) {
                                        _fetchChildren();
                                      });
                                    },
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChild,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Add Child',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String age;
  final String motherName;
  final VoidCallback onTap;

  const _ChildCard({
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.motherName,
    required this.onTap,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get _initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    if (firstInitial.isNotEmpty && lastInitial.isNotEmpty) {
      return '$firstInitial$lastInitial';
    }
    return firstInitial.isNotEmpty ? firstInitial : 'C';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
              child: Row(
                children: [
                  // Avatar - Pink background with pink text initials (matching mother list)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Child Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          age,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                motherName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Arrow
                  const Icon(
                    Icons.chevron_right,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}