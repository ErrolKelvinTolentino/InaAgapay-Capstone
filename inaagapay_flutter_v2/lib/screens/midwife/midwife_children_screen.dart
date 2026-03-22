import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/small_description.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/child_card.dart';
import '../../widgets/floating_add_child_button.dart';
import 'add_child_step1_parent.dart';
import 'child_profile_page.dart';

class MidwifeChildrenScreen extends StatefulWidget {
  const MidwifeChildrenScreen({super.key});

  @override
  State<MidwifeChildrenScreen> createState() => _MidwifeChildrenScreenState();
}

class _MidwifeChildrenScreenState extends State<MidwifeChildrenScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allChildren = [];
  List<Map<String, dynamic>> _filteredChildren = [];
  bool _isLoading = true;
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);

    try {
      // First, fetch all children with mother info
      final childrenResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            middle_name,
            extension_name,
            sex,
            added_at,
            mother:mother_id (
              mother_id,
              account:account_id (
                first_name,
                last_name
              )
            )
          ''')
          .order('added_at', ascending: false);

      final List<Map<String, dynamic>> children = List<Map<String, dynamic>>.from(childrenResponse);
      
      // Then fetch birth details for each child separately
      final List<Map<String, dynamic>> enrichedChildren = [];
      
      for (var child in children) {
        final birthDetailsResponse = await Supabase.instance.client
            .from('birth_details')
            .select('birthdate')
            .eq('child_id', child['child_id'])
            .maybeSingle();
        
        enrichedChildren.add({
          ...child,
          'birthdate': birthDetailsResponse?['birthdate'],
        });
      }
      
      setState(() {
        _allChildren = enrichedChildren;
        _filteredChildren = enrichedChildren;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading children: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String calculateAge(String? birthdate) {
    if (birthdate == null || birthdate.isEmpty) return '-';

    final birth = DateTime.tryParse(birthdate);
    if (birth == null) return '-';

    final now = DateTime.now();
    int years = now.year - birth.year;
    int months = now.month - birth.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years <= 0) {
      return '$months month${months != 1 ? 's' : ''}';
    } else {
      return '$years year${years != 1 ? 's' : ''}${months > 0 ? ' $months month${months != 1 ? 's' : ''}' : ''}';
    }
  }

  String getMotherName(Map<String, dynamic> child) {
    final mother = child['mother'] as Map<String, dynamic>?;
    if (mother == null) return 'Unknown Mother';
    final account = mother['account'] as Map<String, dynamic>?;
    if (account == null) return 'Unknown Mother';
    final firstName = account['first_name']?.toString() ?? '';
    final lastName = account['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim();
  }

  void _filterChildren(String query) {
    final searchLower = query.toLowerCase();
    setState(() {
      _filteredChildren = _allChildren.where((child) {
        final fullName = '${child['first_name']} ${child['last_name']}'.toLowerCase();
        final motherName = getMotherName(child).toLowerCase();
        return fullName.contains(searchLower) || motherName.contains(searchLower);
      }).toList();

      if (_sortBy == 'name') {
        _filteredChildren.sort((a, b) {
          final nameA = '${a['last_name']}${a['first_name']}'.toLowerCase();
          final nameB = '${b['last_name']}${b['first_name']}'.toLowerCase();
          return nameA.compareTo(nameB);
        });
      } else {
        _filteredChildren.sort((a, b) {
          final dateA = DateTime.tryParse(a['added_at']?.toString() ?? '');
          final dateB = DateTime.tryParse(b['added_at']?.toString() ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });
      }
    });
  }

  void _changeSort(String newSort) {
    setState(() => _sortBy = newSort);
    _filterChildren(_searchController.text);
  }

  void _openChildProfile(Map<String, dynamic> child) {
    final id = child['child_id'] as int?;
    if (id != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChildProfilePage(childId: id)),
      ).then((_) => _loadChildren());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadChildren,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Card
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'There are\n',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                                TextSpan(
                                  text: '${_filteredChildren.length} Children!',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.child_care,
                          size: 72,
                          color: AppColors.brandPrimary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Search and Filter Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Column(
                    children: [
                      AppInputField(
                        hintText: 'Search Child',
                        controller: _searchController,
                        trailingIcon: Icons.search,
                        onTrailingTap: () {},
                        onChanged: _filterChildren,
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            items: const [
                              DropdownMenuItem(
                                value: 'recent',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Sort: Most Recent', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'name',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Sort: Name A-Z', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) _changeSort(value);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing ${_filteredChildren.length} of ${_allChildren.length} children',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap a child to view health records',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Child List
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredChildren.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'No children match your search'
                            : 'No children found',
                        style: const TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    ),
                  )
                else
                  ..._filteredChildren.map((child) {
                    final birthdate = child['birthdate']?.toString();
                    final age = calculateAge(birthdate);
                    final fullName = '${child['first_name']} ${child['last_name']}'.trim();
                    final motherName = getMotherName(child);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChildCard(
                        fullName: fullName,
                        ageText: age,
                        motherName: motherName,
                        image: null,
                        onTap: () => _openChildProfile(child),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingAddChildButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddChildStep1Parent()),
          );
        },
      ),
    );
  }
}