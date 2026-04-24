// lib/screens/midwife/midwife_mothers_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';
import '../mother/mother_profile_page.dart';
import 'midwife_add_mother_screen.dart';

class MidwifeMothersScreen extends StatefulWidget {
  const MidwifeMothersScreen({super.key});

  @override
  State<MidwifeMothersScreen> createState() => _MidwifeMothersScreenState();
}

class _MidwifeMothersScreenState extends State<MidwifeMothersScreen> {
  // Pagination variables
  List<Map<String, dynamic>> _allMothers = [];
  List<Map<String, dynamic>> _filteredMothers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 10;
  String? _error;
  
  // Search and Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRiskFilter = 'All';
  Timer? _searchDebounceTimer;
  
  // Filter options
  final List<String> _riskFilters = ['All', 'High Risk', 'Medium Risk', 'Low Risk', 'Due Soon'];
  
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
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> results = List.from(_allMothers);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      results = results.where((mother) {
        final fullName = mother['full_name']?.toString().toLowerCase() ?? '';
        final phone = mother['phone_number']?.toString().toLowerCase() ?? '';
        final email = mother['email_address']?.toString().toLowerCase() ?? '';
        return fullName.contains(_searchQuery) ||
               phone.contains(_searchQuery) ||
               email.contains(_searchQuery);
      }).toList();
    }
    
    // Apply risk filter
    if (_selectedRiskFilter != 'All') {
      results = results.where((mother) {
        final riskLevel = mother['risk_level']?.toString().toLowerCase() ?? 'low';
        final filterLower = _selectedRiskFilter.toLowerCase();
        
        if (filterLower == 'high risk') return riskLevel == 'high';
        if (filterLower == 'medium risk') return riskLevel == 'medium';
        if (filterLower == 'low risk') return riskLevel == 'low';
        if (filterLower == 'due soon') {
          final gestWeeks = mother['gest_weeks'] as int? ?? 0;
          return gestWeeks >= 36 && gestWeeks <= 40;
        }
        return true;
      }).toList();
    }
    
    setState(() {
      _filteredMothers = results;
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
        _allMothers = [];
      });
    }
    
    try {
      final int offset = _currentPage * _pageSize;
      
      var query = SupabaseService.client
          .from('accounts')
          .select('account_id, first_name, last_name, phone_number, email_address')
          .eq('account_type', 'mother')
          .eq('is_verified', true);
      
      if (_searchQuery.isNotEmpty && reset) {
        query = query.or(
          'first_name.ilike.%$_searchQuery%,'
          'last_name.ilike.%$_searchQuery%,'
          'phone_number.ilike.%$_searchQuery%,'
          'email_address.ilike.%$_searchQuery%'
        );
      }
      
      final List<dynamic> allResults = await query;
      final int totalCount = allResults.length;
      
      final List<dynamic> accountsResponse = await query
          .order('first_name', ascending: true)
          .range(offset, offset + _pageSize - 1);
      
      if (!mounted) return;
      
      _hasMoreData = (offset + _pageSize) < totalCount;
      
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
            .select('mother_id, account_id, birthdate, barangay, city_municipality, province, height, weight, blood_type')
            .inFilter('account_id', accountIds);
        
        mothersData = List<Map<String, dynamic>>.from(mothersResponse);
      }
      
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
            .select('mother_id, last_menstrual_period, pregnancy_risk_level')
            .eq('status', 'ongoing')
            .inFilter('mother_id', motherIds);
        
        for (var pregnancy in pregnanciesResponse) {
          final int? mid = pregnancy['mother_id'] as int?;
          if (mid != null) {
            pregnancyMap[mid] = pregnancy;
          }
        }
      }
      
      final Map<int, Map<String, dynamic>> motherMap = {};
      for (var mother in mothersData) {
        final int? aid = mother['account_id'] as int?;
        if (aid != null) {
          motherMap[aid] = mother;
        }
      }
      
      final List<Map<String, dynamic>> newMothers = [];
      
      for (var account in accountsResponse) {
        if (account is! Map<String, dynamic>) continue;
        
        final int accountId = account['account_id'] as int;
        final Map<String, dynamic>? motherInfo = motherMap[accountId];
        final int? motherId = motherInfo?['mother_id'] as int?;
        
        final String firstName = account['first_name']?.toString() ?? '';
        final String lastName = account['last_name']?.toString() ?? '';
        final String fullName = '$firstName $lastName'.trim();
        
        int age = 0;
        final String? birthdateStr = motherInfo?['birthdate']?.toString();
        if (birthdateStr != null && birthdateStr.isNotEmpty) {
          final DateTime? birthdate = DateTime.tryParse(birthdateStr);
          if (birthdate != null) {
            age = DateTime.now().difference(birthdate).inDays ~/ 365;
          }
        }
        
        int gestWeeks = 0;
        String riskLevel = 'low';
        if (motherId != null) {
          final Map<String, dynamic>? pregnancy = pregnancyMap[motherId];
          riskLevel = pregnancy?['pregnancy_risk_level'] as String? ?? 'low';
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
          'full_name': fullName.isEmpty ? 'Unknown Mother' : fullName,
          'phone_number': account['phone_number']?.toString() ?? '',
          'email_address': account['email_address']?.toString() ?? '',
          'mother_id': motherId,
          'age': age,
          'gest_weeks': gestWeeks,
          'risk_level': riskLevel,
          'has_pregnancy': motherId != null && pregnancyMap.containsKey(motherId),
          'barangay': motherInfo?['barangay']?.toString() ?? '',
        });
      }
      
      if (mounted) {
        setState(() {
          if (reset) {
            _allMothers = newMothers;
          } else {
            _allMothers.addAll(newMothers);
          }
          _applyFilters();
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
    _allMothers = [];
    _hasMoreData = true;
    await _loadMothers(reset: true);
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      default: return Colors.green;
    }
  }

  String _getRiskLabel(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high': return 'HIGH RISK';
      case 'medium': return 'MEDIUM RISK';
      default: return 'LOW RISK';
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
                          '${_filteredMothers.length} Mothers',
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
                hintText: 'Search Mother by name, phone, or email',
                controller: _searchController,
                leadingIcon: Icons.search,
                trailingIcon: _searchController.text.isNotEmpty ? Icons.clear : null,
                onTrailingTap: _searchController.text.isNotEmpty 
                    ? () {
                        _searchController.clear();
                        _searchQuery = '';
                        _currentPage = 0;
                        _allMothers = [];
                        _hasMoreData = true;
                        _loadMothers(reset: true);
                      }
                    : null,
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _riskFilters.length,
                itemBuilder: (context, index) {
                  final filter = _riskFilters[index];
                  final isSelected = filter == _selectedRiskFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRiskFilter = filter;
                          _applyFilters();
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.brandSecondary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.brandSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.brandSecondary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Results Count
            if (_searchQuery.isNotEmpty || _selectedRiskFilter != 'All')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_filteredMothers.length} of ${_allMothers.length} mothers',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _selectedRiskFilter = 'All';
                          _applyFilters();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
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
              child: _isLoading && _allMothers.isEmpty
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
                      : _filteredMothers.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _refreshMothers,
                              color: AppColors.brandPrimary,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _filteredMothers.length + (_hasMoreData ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _filteredMothers.length) {
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
                                  
                                  final mother = _filteredMothers[index];
                                  final int? motherId = mother['mother_id'] as int?;
                                  final riskLevel = mother['risk_level']?.toString() ?? 'low';
                                  final riskColor = _getRiskColor(riskLevel);
                                  final riskLabel = _getRiskLabel(riskLevel);
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _MotherCard(
                                      mother: mother,
                                      riskColor: riskColor,
                                      riskLabel: riskLabel,
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
  final Color riskColor;
  final String riskLabel;

  const _MotherCard({
    required this.mother,
    required this.riskColor,
    required this.riskLabel,
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
    final String barangay = mother['barangay']?.toString() ?? '';

    final String displayName = fullName.isEmpty ? 'Unknown Mother' : fullName;
    
    final StringBuffer subtitleBuffer = StringBuffer();
    if (age > 0) {
      subtitleBuffer.write('$age Years old');
    } else {
      subtitleBuffer.write('Age unknown');
    }

    if (hasPregnancy && gestWeeks > 0) {
      subtitleBuffer.write(' • $gestWeeks weeks pregnant');
    }
    
    if (barangay.isNotEmpty) {
      subtitleBuffer.write(' • $barangay');
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
                        riskColor.withValues(alpha: 0.3),
                        riskColor.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(displayName),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              riskLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: riskColor,
                              ),
                            ),
                          ),
                        ],
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