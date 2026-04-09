// lib/screens/midwife/midwife_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../widgets/midwife_statistics_card.dart';
import '../../widgets/midwife_history_card.dart';
import '../../widgets/chart_card.dart';
import 'child_profile_page.dart';

class MidwifeDashboard extends StatefulWidget {
  const MidwifeDashboard({super.key});

  @override
  State<MidwifeDashboard> createState() => _MidwifeDashboardState();
}

class _MidwifeDashboardState extends State<MidwifeDashboard> {
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Dashboard data
  int _registeredMothers = 0;
  int _registeredChildren = 0;
  int _ferrousGiven = 0;
  int _calciumGiven = 0;
  int _tdDosesGiven = 0;
  
  // Pregnancy statistics
  int _totalPregnancies = 0;
  int _firstTrimester = 0;
  int _secondTrimester = 0;
  int _thirdTrimester = 0;
  
  // Recent visits
  List<MidwifeVisitItem> _recentVisits = [];
  
  // Priority Tasks
  List<PriorityTask> _priorityTasks = [];
  
  // Search data
  List<Map<String, dynamic>> _allMothers = [];
  List<Map<String, dynamic>> _allChildren = [];
  
  // Search results
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  
  // BHC Visit data for chart
  List<double> _bhcVisitValues = [0, 0, 0, 0, 0, 0, 0];
  final List<String> _bhcVisitDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  // Computed RHU Visits this week
  int get _rhuVisitsThisWeek => _bhcVisitValues.fold(0, (sum, val) => sum + val.toInt());

  // Midwife info
  String _midwifeName = 'Midwife';
  String _bhcName = 'Loading...';
  List<int> _motherIds = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    _performLocalSearch(query);
  }

  void _performLocalSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    final results = <Map<String, dynamic>>[];

    // Search through cached mothers
    for (var mother in _allMothers) {
      final firstName = (mother['first_name'] ?? '').toLowerCase();
      final lastName = (mother['last_name'] ?? '').toLowerCase();
      final fullName = '$firstName $lastName'.toLowerCase();
      final phone = (mother['phone_number'] ?? '').toLowerCase();
      final email = (mother['email_address'] ?? '').toLowerCase();
      
      if (fullName.contains(query) || 
          firstName.contains(query) || 
          lastName.contains(query) ||
          phone.contains(query) ||
          email.contains(query)) {
        results.add({
          'type': 'mother',
          'id': mother['mother_id'],
          'title': '${mother['first_name'] ?? ''} ${mother['last_name'] ?? ''}'.trim(),
          'subtitle': email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'No contact'),
          'icon': Icons.pregnant_woman,
          'matchText': fullName,
        });
      }
    }

    // Search through cached children
    for (var child in _allChildren) {
      final firstName = (child['first_name'] ?? '').toLowerCase();
      final lastName = (child['last_name'] ?? '').toLowerCase();
      final fullName = '$firstName $lastName'.toLowerCase();
      
      if (fullName.contains(query) || 
          firstName.contains(query) || 
          lastName.contains(query)) {
        results.add({
          'type': 'child',
          'id': child['child_id'],
          'title': '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim(),
          'subtitle': 'Child record',
          'icon': Icons.child_care,
          'matchText': fullName,
        });
      }
    }

    // Sort results by relevance
    results.sort((a, b) {
      final aMatch = a['matchText'] as String;
      final bMatch = b['matchText'] as String;
      final aExact = aMatch == query;
      final bExact = bMatch == query;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return aMatch.compareTo(bMatch);
    });

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get midwife context
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) throw Exception('Not authenticated');
      
      final contextResult = await SupabaseService.getMidwifeContext(accountId);
      if (!contextResult['success']) throw Exception('Failed to load midwife context');
      
      final assignedBhcId = contextResult['assigned_bhc_id'] as int?;
      _bhcName = contextResult['bhc_name']?.toString() ?? 'Unknown BHC';
      
      // Get midwife name from accounts
      final accountResponse = await SupabaseService.client
          .from('accounts')
          .select('first_name, last_name')
          .eq('account_id', accountId)
          .maybeSingle();
      
      if (accountResponse != null) {
        _midwifeName = '${accountResponse['first_name'] ?? ''} ${accountResponse['last_name'] ?? ''}'.trim();
        if (_midwifeName.isEmpty) _midwifeName = 'Midwife';
      }

      if (assignedBhcId == null) {
        throw Exception('No BHC assigned to this midwife');
      }

      // Get registered mothers for this BHC
      final mothersData = await SupabaseService.client
          .from('mothers')
          .select('''
            mother_id,
            account_id,
            birthdate,
            assigned_bhc_id,
            accounts!inner (
              account_id,
              first_name,
              last_name,
              phone_number,
              email_address
            )
          ''')
          .eq('assigned_bhc_id', assignedBhcId)
          .eq('status', 'active');
      
      _registeredMothers = mothersData.length;
      _motherIds = mothersData.map<int>((m) => m['mother_id'] as int).toList();
      
      // Load all mothers for search
      _allMothers = [];
      for (var mother in mothersData) {
        final account = mother['accounts'];
        if (account != null) {
          _allMothers.add({
            'mother_id': mother['mother_id'],
            'first_name': account['first_name'] ?? '',
            'last_name': account['last_name'] ?? '',
            'phone_number': account['phone_number'] ?? '',
            'email_address': account['email_address'] ?? '',
          });
        }
      }

      // Get registered children count and load for search
      if (_motherIds.isNotEmpty) {
        final childrenResponse = await SupabaseService.client
            .from('children')
            .select('''
              child_id,
              first_name,
              last_name,
              mother_id
            ''')
            .inFilter('mother_id', _motherIds);
        
        _registeredChildren = childrenResponse.length;
        _allChildren = List<Map<String, dynamic>>.from(childrenResponse);
      } else {
        _registeredChildren = 0;
        _allChildren = [];
      }

      // Get medication statistics
      if (_motherIds.isNotEmpty) {
        // Ferrous FA
        final ferrousResponse = await SupabaseService.client
            .from('given_medications')
            .select('given_medication_id')
            .eq('given_medication_name', 'Ferrous FA')
            .inFilter('mother_id', _motherIds);
        _ferrousGiven = ferrousResponse.length;

        // Calcium
        final calciumResponse = await SupabaseService.client
            .from('given_medications')
            .select('given_medication_id')
            .eq('given_medication_name', 'Calcium')
            .inFilter('mother_id', _motherIds);
        _calciumGiven = calciumResponse.length;

        // Get pregnancy IDs for these mothers
        final pregnanciesResponse = await SupabaseService.client
            .from('pregnancies')
            .select('pregnancy_id, last_menstrual_period, status')
            .eq('status', 'ongoing')
            .inFilter('mother_id', _motherIds);
        
        _totalPregnancies = pregnanciesResponse.length;
        final pregnancyIds = pregnanciesResponse.map<int>((p) => p['pregnancy_id'] as int).toList();

        // Calculate trimesters
        _firstTrimester = 0;
        _secondTrimester = 0;
        _thirdTrimester = 0;
        
        final now = DateTime.now();
        for (var pregnancy in pregnanciesResponse) {
          final lmp = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
          if (lmp != null) {
            final weeks = now.difference(lmp).inDays / 7;
            if (weeks <= 13) {
              _firstTrimester++;
            } else if (weeks <= 27) {
              _secondTrimester++;
            } else {
              _thirdTrimester++;
            }
          }
        }

        // Get TD vaccine doses given
        if (pregnancyIds.isNotEmpty) {
          final tdResponse = await SupabaseService.client
              .from('prenatal_checkups')
              .select('prenatal_checkup_id')
              .inFilter('pregnancy_id', pregnancyIds)
              .not('td_vaccine_dose', 'is', null);
          _tdDosesGiven = tdResponse.length;
        } else {
          _tdDosesGiven = 0;
        }

        // Get recent visits (last 7 days)
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        
        final checkupsResponse = await SupabaseService.client
            .from('prenatal_checkups')
            .select('''
              checkup_datetime,
              pregnancy_id
            ''')
            .gte('checkup_datetime', sevenDaysAgo.toIso8601String())
            .order('checkup_datetime', ascending: false)
            .limit(10);
        
        _recentVisits = [];
        
        for (var checkup in checkupsResponse) {
          try {
            final pregnancyIdValue = checkup['pregnancy_id'] as int;
            
            final pregnancyData = await SupabaseService.client
                .from('pregnancies')
                .select('mother_id')
                .eq('pregnancy_id', pregnancyIdValue)
                .maybeSingle();
            
            if (pregnancyData == null) continue;
            
            final motherId = pregnancyData['mother_id'] as int;
            
            // Find mother in our cached data
            final motherInfo = _allMothers.firstWhere(
              (m) => m['mother_id'] == motherId,
              orElse: () => {},
            );
            
            final fullName = motherInfo.isNotEmpty 
                ? '${motherInfo['first_name']} ${motherInfo['last_name']}'.trim()
                : 'Unknown Mother';
            
            final dateTime = DateTime.parse(checkup['checkup_datetime']);
            final nowTime = DateTime.now();
            final difference = nowTime.difference(dateTime);
            
            String timeLabel;
            if (difference.inDays == 0) {
              timeLabel = 'Today';
            } else if (difference.inDays == 1) {
              timeLabel = 'Yesterday';
            } else {
              timeLabel = '${difference.inDays} days ago';
            }
            
            _recentVisits.add(MidwifeVisitItem(
              fullName: fullName.isNotEmpty ? fullName : 'Unknown Mother',
              visitType: 'Prenatal Check-up',
              timeLabel: timeLabel,
            ));
          } catch (e) {
            continue;
          }
        }

        // Get BHC visit data
        if (pregnancyIds.isNotEmpty) {
          final List<double> dailyVisits = List.filled(7, 0);
          
          for (int i = 0; i < 7; i++) {
            final day = DateTime.now().subtract(Duration(days: i));
            final startOfDay = DateTime(day.year, day.month, day.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));
            
            final dayVisitsResponse = await SupabaseService.client
                .from('prenatal_checkups')
                .select('prenatal_checkup_id')
                .gte('checkup_datetime', startOfDay.toIso8601String())
                .lt('checkup_datetime', endOfDay.toIso8601String())
                .inFilter('pregnancy_id', pregnancyIds);
            
            int chartIndex;
            if (day.weekday == 7) {
              chartIndex = 6;
            } else {
              chartIndex = day.weekday - 1;
            }
            
            dailyVisits[chartIndex] = dayVisitsResponse.length.toDouble();
          }
          
          _bhcVisitValues = dailyVisits;
        } else {
          _bhcVisitValues = [0, 0, 0, 0, 0, 0, 0];
        }

        // Load priority tasks
        await _loadPriorityTasks(pregnancyIds);
      } else {
        // No mothers found - set default values
        _registeredChildren = 0;
        _ferrousGiven = 0;
        _calciumGiven = 0;
        _tdDosesGiven = 0;
        _totalPregnancies = 0;
        _firstTrimester = 0;
        _secondTrimester = 0;
        _thirdTrimester = 0;
        _recentVisits = [];
        _priorityTasks = [];
        _bhcVisitValues = [0, 0, 0, 0, 0, 0, 0];
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (kDebugMode) {
        print('Error loading dashboard: $e');
      }
    }
  }

  Future<void> _loadPriorityTasks(List<int> pregnancyIds) async {
    _priorityTasks = [];
    
    if (pregnancyIds.isEmpty) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Task 1: Check for upcoming scheduled checkups (next 7 days)
      final upcomingCheckups = await SupabaseService.client
          .from('prenatal_checkups')
          .select('''
            prenatal_checkup_id,
            next_schedule,
            pregnancy_id
          ''')
          .inFilter('pregnancy_id', pregnancyIds)
          .not('next_schedule', 'is', null)
          .gte('next_schedule', today.toIso8601String().split('T')[0]);

      for (var checkup in upcomingCheckups) {
        final nextDate = DateTime.parse(checkup['next_schedule']);
        final daysUntil = nextDate.difference(today).inDays;
        
        if (daysUntil <= 7) {
          String urgency = daysUntil == 0 ? 'urgent' : (daysUntil <= 2 ? 'warning' : 'normal');
          
          final pregnancyData = await SupabaseService.client
              .from('pregnancies')
              .select('mother_id')
              .eq('pregnancy_id', checkup['pregnancy_id'])
              .maybeSingle();
          
          if (pregnancyData != null) {
            final motherInfo = _allMothers.firstWhere(
              (m) => m['mother_id'] == pregnancyData['mother_id'],
              orElse: () => {},
            );
            
            final name = motherInfo.isNotEmpty 
                ? '${motherInfo['first_name']} ${motherInfo['last_name']}'.trim()
                : 'Unknown Mother';
            
            _priorityTasks.add(PriorityTask(
              id: checkup['prenatal_checkup_id'],
              title: 'Prenatal Checkup Scheduled',
              description: '$name has a checkup scheduled for ${DateFormat('MMM d, yyyy').format(nextDate)}',
              urgency: urgency,
              type: 'checkup',
              action: 'View Schedule',
            ));
          }
        }
      }

      // Task 2: Check for high-risk pregnancies
      final highRiskPregnancies = await SupabaseService.client
          .from('pregnancies')
          .select('''
            pregnancy_id,
            pregnancy_risk_level,
            mother_id
          ''')
          .inFilter('pregnancy_id', pregnancyIds)
          .eq('pregnancy_risk_level', 'high');

      for (var pregnancy in highRiskPregnancies) {
        final motherInfo = _allMothers.firstWhere(
          (m) => m['mother_id'] == pregnancy['mother_id'],
          orElse: () => {},
        );
        
        final name = motherInfo.isNotEmpty 
            ? '${motherInfo['first_name']} ${motherInfo['last_name']}'.trim()
            : 'Unknown Mother';
        
        _priorityTasks.add(PriorityTask(
          id: pregnancy['pregnancy_id'],
          title: 'High-Risk Pregnancy',
          description: '$name requires close monitoring and follow-up',
          urgency: 'urgent',
          type: 'high_risk',
          action: 'View Details',
        ));
      }

      // Sort tasks by urgency
      _priorityTasks.sort((a, b) {
        final urgencyOrder = {'urgent': 0, 'warning': 1, 'normal': 2};
        return urgencyOrder[a.urgency]!.compareTo(urgencyOrder[b.urgency]!);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading priority tasks: $e');
      }
    }

    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _navigateToSearchResult(Map<String, dynamic> result) {
    _clearSearch();
    if (result['type'] == 'mother') {
      Navigator.pushNamed(context, '/mother-profile', arguments: result['id']);
    } else if (result['type'] == 'child') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChildProfilePage(childId: result['id']),
        ),
      );
    }
  }

  String _getWelcomeMessage() {
    return 'Welcome, ${_midwifeName.split(' ').first}! 🌸';
  }

  String _getChartInsight() {
    int maxIndex = 0;
    int maxValue = 0;
    for (int i = 0; i < _bhcVisitValues.length; i++) {
      if (_bhcVisitValues[i] > maxValue) {
        maxValue = _bhcVisitValues[i].toInt();
        maxIndex = i;
      }
    }
    
    final bestDay = _bhcVisitDays[maxIndex];
    
    if (maxValue == 0) {
      return 'No visits recorded in the last 7 days.';
    } else if (maxValue == 1) {
      return '$bestDay had 1 prenatal visit this week.';
    } else {
      return '$bestDay had the most prenatal visits ($maxValue visits) this week!';
    }
  }

  Widget _buildStatCard({required int value, required String label, required IconData iconData}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            color: AppColors.brandPrimary,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadDashboardData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    color: AppColors.brandPrimary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          
                          // Hero Card with Search
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: 110,
                                  width: 110,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFFF0F5),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/midwife.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 60, color: AppColors.brandPrimary),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _getWelcomeMessage(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _bhcName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Global Search Bar
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSecondary,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: AppColors.borderPrimary),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Search mothers, children...',
                                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                              onPressed: _clearSearch,
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Search Results
                          if (_showSearchResults && _searchResults.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'Search Results',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ..._searchResults.map((result) => ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                                      child: Icon(result['icon'], color: AppColors.brandPrimary),
                                    ),
                                    title: Text(
                                      result['title'],
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      result['subtitle'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, size: 20),
                                    onTap: () => _navigateToSearchResult(result),
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_showSearchResults && _searchResults.isEmpty && _searchController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
                                    SizedBox(height: 12),
                                    Text(
                                      'No results found',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Try a different search term',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 24),

                          // Health Center Overview Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.local_hospital, color: AppColors.brandPrimary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Health Center Overview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Quick Overview
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(value: _registeredChildren, label: 'Registered\nChildren', iconData: Icons.child_care),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(value: _registeredMothers, label: 'Registered\nMothers', iconData: Icons.pregnant_woman),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(value: _rhuVisitsThisWeek, label: 'RHU Visits\nThis week', iconData: Icons.medical_services),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Active Pregnancies Card
                          MidwifeStatisticsCard(
                            totalPregnancies: _totalPregnancies,
                            firstTrimester: _firstTrimester,
                            secondTrimester: _secondTrimester,
                            thirdTrimester: _thirdTrimester,
                          ),

                          const SizedBox(height: 20),

                          // Medication Statistics
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(value: _ferrousGiven, label: 'Ferrous FA\ngiven', iconData: Icons.medication),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(value: _calciumGiven, label: 'Calcium\ngiven', iconData: Icons.local_pharmacy),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(value: _tdDosesGiven, label: 'TD Vaccine\ndoses given', iconData: Icons.vaccines),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Priority Tasks Section
                          if (_priorityTasks.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderPrimary),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.priority_high, color: AppColors.brandPrimary, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'Priority Tasks',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ..._priorityTasks.take(5).map((task) => _PriorityTaskTile(task: task)),
                                  if (_priorityTasks.length > 5)
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Center(
                                        child: Text(
                                          '+${_priorityTasks.length - 5} more tasks',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Recent Visits
                          if (_recentVisits.isNotEmpty)
                            MidwifeHistoryCard(
                              visits: _recentVisits,
                              onTapItem: () {},
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderPrimary),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No recent visits',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Checkups in the last 7 days will appear here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // BHC Visits Chart
                          if (_bhcVisitValues.any((v) => v > 0))
                            ChartCard(
                              title: 'BHC Visits Chart',
                              titleColor: AppColors.brandPrimary,
                              headerIcon: null,
                              values: _bhcVisitValues,
                              labels: _bhcVisitDays,
                              unit: 'visits',
                              lineColor: AppColors.brandPrimary,
                              startingLabel: null,
                              startingValue: null,
                              latestLabel: null,
                              latestValue: null,
                              insightText: _getChartInsight(),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderPrimary),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.show_chart,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No visit data available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Visits in the last 7 days will appear here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

// Priority Task Model
class PriorityTask {
  final int id;
  final String title;
  final String description;
  final String urgency;
  final String type;
  final String action;

  PriorityTask({
    required this.id,
    required this.title,
    required this.description,
    required this.urgency,
    required this.type,
    required this.action,
  });
}

// Priority Task Tile Widget
class _PriorityTaskTile extends StatelessWidget {
  final PriorityTask task;

  const _PriorityTaskTile({required this.task});

  Color _getUrgencyColor() {
    switch (task.urgency) {
      case 'urgent': return AppColors.error;
      case 'warning': return AppColors.warning;
      default: return AppColors.info;
    }
  }

  IconData _getTaskIcon() {
    switch (task.type) {
      case 'checkup': return Icons.medical_services;
      case 'high_risk': return Icons.warning_amber;
      case 'vaccine': return Icons.vaccines;
      default: return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderPrimary.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getUrgencyColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTaskIcon(), color: _getUrgencyColor(), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getUrgencyColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task.urgency.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getUrgencyColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}