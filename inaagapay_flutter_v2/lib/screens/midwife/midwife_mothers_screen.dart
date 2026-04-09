// lib/screens/midwife/midwife_mothers_screen.dart

import 'dart:async';  // ← ADD THIS IMPORT FOR Timer
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../services/supabase_service.dart';
import '../mother/mother_profile_page.dart';
import 'midwife_add_mother_screen.dart';

class MidwifeMothersScreen extends StatefulWidget {
  const MidwifeMothersScreen({super.key});

  @override
  State<MidwifeMothersScreen> createState() => _MidwifeMothersScreenState();
}

class _MidwifeMothersScreenState extends State<MidwifeMothersScreen> {
  // Pagination variables
  List<Map<String, dynamic>> _mothers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 8;
  String? _error;
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  
  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMothers();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchDebounceTimer?.isActive ?? false) {
      _searchDebounceTimer?.cancel();
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _currentPage = 0;
        _mothers = [];
        _hasMoreData = true;
        _loadMothers(reset: true);
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreMothers();
      }
    }
  }

  Future<void> _loadMoreMothers() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadMothers(reset: false);
    
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMothers({bool reset = true}) async {
    if (!mounted) return;
    
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
        _mothers = [];
      });
    }
    
    try {
      // Calculate offset for pagination
      final int offset = _currentPage * _pageSize;
      
      // Step 1: Get mother accounts with pagination
      var query = SupabaseService.client
          .from('accounts')
          .select('account_id, first_name, last_name, phone_number, email_address')
          .eq('account_type', 'mother')
          .eq('is_verified', true);
      
      // Apply search filter if exists
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'first_name.ilike.%$_searchQuery%,'
          'last_name.ilike.%$_searchQuery%,'
          'phone_number.ilike.%$_searchQuery%,'
          'email_address.ilike.%$_searchQuery%'
        );
      }
      
      // Get total count first for pagination
      final List<dynamic> allResults = await query;
      final int totalCount = allResults.length;
      
      // Apply pagination
      final List<dynamic> accountsResponse = await query
          .order('first_name', ascending: true)
          .range(offset, offset + _pageSize - 1);
      
      if (!mounted) return;
      
      // Check if we have more data
      _hasMoreData = (offset + _pageSize) < totalCount;
      
      // Step 2: Get all mother records for these accounts
      final List<int> accountIds = [];
      for (var account in accountsResponse) {
        if (account is Map<String, dynamic>) {
          accountIds.add(account['account_id'] as int);
        }
      }
      
      List<Map<String, dynamic>> mothersData = [];
      if (accountIds.isNotEmpty) {
        final mothersResponse = await SupabaseService.client
            .from('mothers')
            .select('mother_id, account_id, birthdate, barangay, city_municipality, province')
            .inFilter('account_id', accountIds);
        
        if (mothersResponse is List) {
          mothersData = List<Map<String, dynamic>>.from(mothersResponse);
        }
      }
      
      // Step 3: Get all ongoing pregnancies
      final List<int> motherIds = [];
      for (var mother in mothersData) {
        final int? mid = mother['mother_id'] as int?;
        if (mid != null) {
          motherIds.add(mid);
        }
      }
      
      Map<int, Map<String, dynamic>> pregnancyMap = {};
      if (motherIds.isNotEmpty) {
        final pregnanciesResponse = await SupabaseService.client
            .from('pregnancies')
            .select('mother_id, last_menstrual_period')
            .eq('status', 'ongoing')
            .inFilter('mother_id', motherIds);
        
        if (pregnanciesResponse is List) {
          for (var pregnancy in pregnanciesResponse) {
            if (pregnancy is Map<String, dynamic>) {
              final int? mid = pregnancy['mother_id'] as int?;
              if (mid != null) {
                pregnancyMap[mid] = pregnancy;
              }
            }
          }
        }
      }
      
      // Step 4: Build mother map for quick lookup
      final Map<int, Map<String, dynamic>> motherMap = {};
      for (var mother in mothersData) {
        final int? aid = mother['account_id'] as int?;
        if (aid != null) {
          motherMap[aid] = mother;
        }
      }
      
      // Step 5: Process all accounts
      final List<Map<String, dynamic>> newMothers = [];
      
      for (var account in accountsResponse) {
        if (account is! Map<String, dynamic>) continue;
        
        final int accountId = account['account_id'] as int;
        final Map<String, dynamic>? motherInfo = motherMap[accountId];
        final int? motherId = motherInfo?['mother_id'] as int?;
        
        final String firstName = account['first_name']?.toString() ?? '';
        final String lastName = account['last_name']?.toString() ?? '';
        final String fullName = '$firstName $lastName'.trim();
        
        // Calculate age
        int age = 0;
        final String? birthdateStr = motherInfo?['birthdate']?.toString();
        if (birthdateStr != null && birthdateStr.isNotEmpty) {
          final DateTime? birthdate = DateTime.tryParse(birthdateStr);
          if (birthdate != null) {
            age = DateTime.now().difference(birthdate).inDays ~/ 365;
          }
        }
        
        // Get pregnancy info
        int gestWeeks = 0;
        if (motherId != null) {
          final Map<String, dynamic>? pregnancy = pregnancyMap[motherId];
          final String? lmpString = pregnancy?['last_menstrual_period'] as String?;
          if (lmpString != null && lmpString.isNotEmpty) {
            final DateTime? lmpDate = DateTime.tryParse(lmpString);
            if (lmpDate != null) {
              gestWeeks = DateTime.now().difference(lmpDate).inDays ~/ 7;
            }
          }
        }
        
        newMothers.add({
          'account_id': accountId,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': account['phone_number']?.toString() ?? '',
          'email_address': account['email_address']?.toString() ?? '',
          'full_name': fullName.isEmpty ? 'Unknown Mother' : fullName,
          'mother_id': motherId,
          'age': age,
          'gest_weeks': gestWeeks,
          'has_pregnancy': motherId != null && pregnancyMap.containsKey(motherId),
          'barangay': motherInfo?['barangay']?.toString() ?? '',
          'city': motherInfo?['city_municipality']?.toString() ?? '',
          'province': motherInfo?['province']?.toString() ?? '',
        });
      }
      
      if (mounted) {
        setState(() {
          if (reset) {
            _mothers = newMothers;
          } else {
            _mothers.addAll(newMothers);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading mothers: $e');
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshMothers() async {
    _currentPage = 0;
    _mothers = [];
    _hasMoreData = true;
    await _loadMothers(reset: true);
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
            // Header Banner
            Container(
              width: double.infinity,
              height: 110,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: AssetImage('assets/images/pinkbg.png'),
                  fit: BoxFit.cover,
                ),
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
                        'assets/images/pregnant1.png',
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
                          '${_mothers.length} Mothers',
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AppInputField(
                hintText: 'Search Mother',
                controller: _searchController,
                trailingIcon: _searchController.text.isNotEmpty ? Icons.clear : Icons.search,
                onTrailingTap: _searchController.text.isNotEmpty 
                    ? () {
                        _searchController.clear();
                        _searchQuery = '';
                        _currentPage = 0;
                        _mothers = [];
                        _hasMoreData = true;
                        _loadMothers(reset: true);
                      }
                    : null,
              ),
            ),

            // Helper Text
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                'Tap a mother to view health records',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Main Content with Pagination
            Expanded(
              child: _isLoading && _mothers.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brandPrimary),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                const Text(
                                  'Failed to load mothers',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _refreshMothers(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _mothers.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _refreshMothers,
                              color: AppColors.brandPrimary,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _mothers.length + (_hasMoreData ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Show loading indicator at the bottom
                                  if (index == _mothers.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.brandPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  final Map<String, dynamic> mother = _mothers[index];
                                  final int? motherId = mother['mother_id'] as int?;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _MotherCard(
                                      mother: mother,
                                      onTap: motherId != null
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => MotherProfilePage(
                                                    motherId: motherId,
                                                  ),
                                                ),
                                              ).then((_) {
                                                if (mounted) {
                                                  _refreshMothers();
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MidwifeAddMotherScreen(),
            ),
          );
          if (added == true && mounted) {
            _refreshMothers();
          }
        },
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Add Mother',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildEmpty() {
    final bool isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching
                ? Icons.search_off_rounded
                : Icons.pregnant_woman_rounded,
            size: 64,
            color: AppColors.brandPrimary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching ? 'No results found' : 'No mothers registered yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSearching
                ? 'Try a different search term'
                : 'Tap + to register the first mother',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MotherCard extends StatelessWidget {
  final Map<String, dynamic> mother;
  final VoidCallback? onTap;

  const _MotherCard({
    required this.mother,
    this.onTap,
  });

  String _getInitials(String fullName) {
    if (fullName.isEmpty || fullName == 'Unknown Mother') return '?';
    
    final String trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    
    final List<String> parts = trimmed.split(' ');
    if (parts.isEmpty) return '?';
    
    final String firstPart = parts[0];
    if (firstPart.isEmpty) return '?';
    final String firstInitial = firstPart[0].toUpperCase();
    
    if (parts.length > 1) {
      final String secondPart = parts[1];
      if (secondPart.isNotEmpty) {
        return '$firstInitial${secondPart[0].toUpperCase()}';
      }
    }
    
    return firstInitial;
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = mother['full_name']?.toString() ?? '';
    final int age = mother['age'] as int? ?? 0;
    final int gestWeeks = mother['gest_weeks'] as int? ?? 0;
    final bool hasPregnancy = mother['has_pregnancy'] as bool? ?? false;

    final String displayName = fullName.isEmpty ? 'Unknown Mother' : fullName;
    
    final StringBuffer subtitleBuffer = StringBuffer();
    if (age > 0) {
      subtitleBuffer.write('$age Years old');
    } else {
      subtitleBuffer.write('Age unknown');
    }

    if (hasPregnancy && gestWeeks > 0) {
      subtitleBuffer.write(' - $gestWeeks weeks pregnant');
    }

    return Container(
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
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary.withValues(alpha: 0.3),
                        AppColors.brandAccent.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(displayName),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
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
                        subtitleBuffer.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.brandPrimary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}