// lib/screens/mother/mother_children_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/child_card.dart';
import '../../widgets/small_description.dart';
import '../../widgets/vaccine_schedule_status.dart';
import 'mother_child_stack.dart';

class MotherChildrenScreen extends StatefulWidget {
  const MotherChildrenScreen({super.key});

  @override
  State<MotherChildrenScreen> createState() => _MotherChildrenScreenState();
}

class _MotherChildrenScreenState extends State<MotherChildrenScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _filteredChildren = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _searchController.addListener(_filterChildren);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get stored IDs
      final motherId = await AuthStorage.getMotherId();
      final accountId = await AuthStorage.getUserId();
      
      print('🔍 ===== CHILDREN LOAD DEBUG =====');
      print('🔍 Account ID from storage: $accountId');
      print('🔍 Mother ID from storage: $motherId');
      
      if (motherId == null) {
        print('🔍 ❌ Mother ID is null! Trying to fetch from database...');
        
        // Try to get mother_id from database using account_id
        if (accountId != null) {
          final motherResponse = await SupabaseService.client
              .from('mothers')
              .select('mother_id')
              .eq('account_id', accountId)
              .maybeSingle();
          
          print('🔍 Mother query response: $motherResponse');
          
          if (motherResponse != null) {
            final fetchedMotherId = motherResponse['mother_id'] as int;
            print('🔍 Found mother_id in database: $fetchedMotherId');
            
            // Save it to storage for next time
            await AuthStorage.saveMotherId(fetchedMotherId);
            
            // Use this mother_id for the query
            await _fetchChildrenWithMotherId(fetchedMotherId);
            return;
          } else {
            print('🔍 ❌ No mother record found for account_id: $accountId');
            throw Exception('Mother record not found. Please complete your profile.');
          }
        } else {
          throw Exception('No account ID found. Please login again.');
        }
      } else {
        // We have mother_id from storage, use it
        await _fetchChildrenWithMotherId(motherId);
      }
    } catch (e) {
      print('🔍 ❌ Error in _loadChildren: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchChildrenWithMotherId(int motherId) async {
    try {
      print('🔍 Fetching children for mother_id: $motherId');

      // Ensure session is active
      await SupabaseService.ensureSession();

      // Try a VERY simple query first
      print('🔍 Trying simple query...');
      final simpleQuery = await SupabaseService.client
          .from('children')
          .select('*')
          .eq('mother_id', motherId);
      
      print('🔍 Simple query result: $simpleQuery');
      print('🔍 Simple query length: ${simpleQuery.length}');

      // If simple query works, try with birth details
      if (simpleQuery.isNotEmpty) {
        final response = await SupabaseService.client
            .from('children')
            .select('''
              *,
              birth_details (*)
            ''')
            .eq('mother_id', motherId)
            .order('added_at', ascending: false);

        print('🔍 Full query response: $response');
        
        setState(() {
          _children = List<Map<String, dynamic>>.from(response);
          _filteredChildren = _children;
          _isLoading = false;
        });
        
        print('🔍 State updated with ${_children.length} children');
      } else {
        print('🔍 No children found in simple query for mother_id: $motherId');
        
        // Check all children in database regardless of mother_id
        print('🔍 Fetching ALL children from database...');
        final allChildren = await SupabaseService.client
            .from('children')
            .select('child_id, mother_id, first_name, last_name, sex');
        
        print('🔍 ALL children in database: $allChildren');
        print('🔍 Total children in database: ${allChildren.length}');
        
        // Check specifically for children with first_name 'Juan' or 'Maria'
        final juanMaria = await SupabaseService.client
            .from('children')
            .select('child_id, mother_id, first_name, last_name, sex')
            .inFilter('first_name', ['Juan', 'Maria']);
        
        print('🔍 Juan/Maria records: $juanMaria');
        
        // Check what mother_ids exist in the children table
        final motherIds = await SupabaseService.client
            .from('children')
            .select('mother_id');
        
        print('🔍 All mother_ids in children table: $motherIds');
        
        setState(() {
          _children = [];
          _filteredChildren = [];
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('🔍 ❌ Error in _fetchChildrenWithMotherId: $e');
      setState(() {
        _error = 'Database error: $e';
        _isLoading = false;
      });
    }
  }

  void _filterChildren() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredChildren = _children;
      });
      return;
    }

    setState(() {
      _filteredChildren = _children.where((child) {
        final fullName = _getFullName(child).toLowerCase();
        return fullName.contains(query);
      }).toList();
    });
  }

  String _getFullName(Map<String, dynamic> child) {
    return [
      child['first_name'],
      child['middle_name'],
      child['last_name'],
      child['extension_name'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
  }

  String _getAgeText(Map<String, dynamic> child) {
    final birthDetails = child['birth_details'] as Map<String, dynamic>?;
    if (birthDetails == null || birthDetails['birthdate'] == null) {
      return 'Age not available';
    }

    try {
      final birthDate = DateTime.parse(birthDetails['birthdate']);
      final now = DateTime.now();
      final difference = now.difference(birthDate);

      if (difference.inDays < 30) {
        return '${difference.inDays} days old';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months month${months > 1 ? 's' : ''} old';
      } else {
        final years = (difference.inDays / 365).floor();
        final remainingMonths = ((difference.inDays % 365) / 30).floor();
        if (remainingMonths > 0) {
          return '$years year${years > 1 ? 's' : ''} $remainingMonths month${remainingMonths > 1 ? 's' : ''} old';
        }
        return '$years year${years > 1 ? 's' : ''} old';
      }
    } catch (e) {
      print('🔍 Error calculating age: $e');
      return 'Age not available';
    }
  }

  Future<String> _getStoredMotherId() async {
    final id = await AuthStorage.getMotherId();
    return id?.toString() ?? 'Not set';
  }

  void _openChildProfile(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MotherChildStack(
          childId: child['child_id'],
          childName: _getFullName(child),
          childAge: _getAgeText(child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brandPrimary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error Loading Children',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadChildren,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧸 TOP INFO CARD
          Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: const DecorationImage(
                image: AssetImage('assets/images/pinkbg.png'),
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'You have\n',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          TextSpan(
                            text:
                                '${_children.length} Beautiful Child${_children.length != 1 ? 'ren' : ''}!',
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
                  Image.asset(
                    'assets/images/baby.png',
                    height: 72,
                    width: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Icon(
                        Icons.child_care,
                        color: AppColors.brandPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔍 Search
          AppInputField(
            hintText: 'Search Child',
            controller: _searchController,
            trailingIcon: Icons.search,
            onTrailingTap: () {},
            onChanged: (_) => _filterChildren(),
          ),

          const SizedBox(height: 8),

          const SmallDescription(
            text: 'Tap a child to view health records',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 👶 CHILD LIST
          if (_filteredChildren.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.child_care_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _children.isEmpty
                        ? 'No children registered yet'
                        : 'No matching children found',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_children.isEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Column(
                        children: [
                          FutureBuilder<String>(
                            future: _getStoredMotherId(),
                            builder: (context, snapshot) {
                              String displayText = 'Mother ID from storage: ';
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                displayText += 'Loading...';
                              } else if (snapshot.hasError) {
                                displayText += 'Error';
                              } else {
                                displayText += snapshot.data ?? 'Not set';
                              }
                              return Text(
                                displayText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check debug console for more details',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: _filteredChildren.map((child) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ChildCard(
                    fullName: _getFullName(child),
                    ageText: _getAgeText(child),
                    vaccineStatus: VaccineScheduleStatus.onSchedule,
                    image: const AssetImage('assets/images/child.png'),
                    onTap: () => _openChildProfile(child),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}