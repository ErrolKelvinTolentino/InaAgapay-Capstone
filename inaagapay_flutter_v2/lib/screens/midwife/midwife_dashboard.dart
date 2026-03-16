// lib/screens/midwife/midwife_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../widgets/main_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/overview_info.dart';
import '../../widgets/midwife_statistics_card.dart';
import '../../widgets/midwife_history_card.dart';
import '../../widgets/chart_card.dart';
import '../../services/supabase_service.dart';

class MidwifeDashboard extends StatefulWidget {
  const MidwifeDashboard({super.key});

  @override
  State<MidwifeDashboard> createState() => _MidwifeDashboardState();
}

class _MidwifeDashboardState extends State<MidwifeDashboard> {
  bool _isLoading = true;
  String? _errorMessage;
  
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
  
  // BHC Visit data for chart
  List<double> _bhcVisitValues = [0, 0, 0, 0, 0, 0, 0];
  final List<String> _bhcVisitDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  // Midwife info
  String _midwifeName = 'Midwife';
  String _bhcName = 'Loading...';
  int? _assignedBhcId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
      _assignedBhcId = assignedBhcId;
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

      // Get registered mothers count for this BHC
      final mothersResponse = await SupabaseService.client
          .from('mothers')
          .select('mother_id')
          .eq('assigned_bhc_id', assignedBhcId)  // Use the non-null variable
          .eq('status', 'active');
      
      _registeredMothers = mothersResponse.length;

      // Get registered children count (through mothers in this BHC)
      if (_registeredMothers > 0) {
        final motherIds = mothersResponse.map<int>((m) => m['mother_id'] as int).toList();
        
        final childrenResponse = await SupabaseService.client
            .from('children')
            .select('child_id')
            .inFilter('mother_id', motherIds);
        
        _registeredChildren = childrenResponse.length;
      }

      // Get medication statistics for this BHC
      if (_registeredMothers > 0) {
        final motherIds = mothersResponse.map<int>((m) => m['mother_id'] as int).toList();
        
        // Ferrous FA
        final ferrousResponse = await SupabaseService.client
            .from('given_medications')
            .select('given_medication_id')
            .eq('given_medication_name', 'Ferrous FA')
            .inFilter('mother_id', motherIds);
        _ferrousGiven = ferrousResponse.length;

        // Calcium
        final calciumResponse = await SupabaseService.client
            .from('given_medications')
            .select('given_medication_id')
            .eq('given_medication_name', 'Calcium')
            .inFilter('mother_id', motherIds);
        _calciumGiven = calciumResponse.length;

        // Get pregnancy IDs for these mothers
        final pregnanciesResponse = await SupabaseService.client
            .from('pregnancies')
            .select('pregnancy_id')
            .inFilter('mother_id', motherIds);
        
        final pregnancyIds = pregnanciesResponse.map<int>((p) => p['pregnancy_id'] as int).toList();

        // Get TD vaccine doses given
        if (pregnancyIds.isNotEmpty) {
          final tdResponse = await SupabaseService.client
              .from('prenatal_checkups')
              .select('prenatal_checkup_id')
              .inFilter('pregnancy_id', pregnancyIds)
              .not('td_vaccine_dose', 'is', null);
          _tdDosesGiven = tdResponse.length;
        }

        // Get pregnancy statistics
        final pregnancies = await SupabaseService.client
            .from('pregnancies')
            .select('pregnancy_id, last_menstrual_period, status')
            .eq('status', 'ongoing')
            .inFilter('mother_id', motherIds);
        
        _totalPregnancies = pregnancies.length;
        
        // Calculate trimesters
        _firstTrimester = 0;
        _secondTrimester = 0;
        _thirdTrimester = 0;
        
        final now = DateTime.now();
        for (var pregnancy in pregnancies) {
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

        // Get recent visits (prenatal checkups in last 7 days)
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
            final pregnancyId = checkup['pregnancy_id'] as int;
            
            // Get mother_id from pregnancy
            final pregnancyData = await SupabaseService.client
                .from('pregnancies')
                .select('mother_id')
                .eq('pregnancy_id', pregnancyId)
                .maybeSingle();
            
            if (pregnancyData == null) continue;
            
            final motherId = pregnancyData['mother_id'] as int;
            
            // Get mother's account info
            final motherData = await SupabaseService.client
                .from('mothers')
                .select('account_id')
                .eq('mother_id', motherId)
                .maybeSingle();
            
            if (motherData == null) continue;
            
            final accountId = motherData['account_id'] as int;
            
            final accountData = await SupabaseService.client
                .from('accounts')
                .select('first_name, last_name')
                .eq('account_id', accountId)
                .maybeSingle();
            
            if (accountData == null) continue;
            
            final firstName = accountData['first_name'] as String? ?? '';
            final lastName = accountData['last_name'] as String? ?? '';
            final fullName = '$firstName $lastName'.trim();
            
            final dateTime = DateTime.parse(checkup['checkup_datetime']);
            final now = DateTime.now();
            final difference = now.difference(dateTime);
            
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

        // Get BHC visit data for the last 7 days
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
            
            // Sunday is index 6, Monday is index 0, etc.
            // We want Monday first in the chart
            final dayOfWeek = day.weekday; // 1 = Monday, 7 = Sunday
            int chartIndex;
            if (dayOfWeek == 7) { // Sunday
              chartIndex = 6;
            } else {
              chartIndex = dayOfWeek - 1; // Monday = 0, Tuesday = 1, etc.
            }
            
            dailyVisits[chartIndex] = dayVisitsResponse.length.toDouble();
          }
          
          _bhcVisitValues = dailyVisits;
        }
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

  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning, $_midwifeName! 🌅';
    } else if (hour < 18) {
      return 'Good Afternoon, $_midwifeName! ☀️';
    } else {
      return 'Good Evening, $_midwifeName! 🌙';
    }
  }

  String _getChartInsight() {
    // Find the day with highest visits
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          MainHeader(
            title: 'Home',
            onViewProfile: () => Navigator.pushNamed(context, '/profile'),
            onSettings: () => Navigator.pushNamed(context, '/settings'),
            onHelp: () => Navigator.pushNamed(context, '/help'),
            onLogout: () async {
              await AuthStorage.clearAll();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
          Expanded(
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
                              
                              // Hero Card with dynamic data
                              HeroCard(
                                image: null,
                                title: _getWelcomeMessage(),
                                subtitle: _bhcName,
                                showWeekBadge: false,
                                showHeartRow: false,
                              ),

                              const SizedBox(height: 20),

                              // Quick Overview - Children and Mothers
                              Row(
                                children: [
                                  Expanded(
                                    child: OverviewInfo(
                                      value: _registeredChildren,
                                      label: 'Registered\nChildren',
                                      icon: Icons.child_care_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OverviewInfo(
                                      value: _registeredMothers,
                                      label: 'Registered\nMothers',
                                      icon: Icons.pregnant_woman,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Medication Statistics
                              Row(
                                children: [
                                  Expanded(
                                    child: OverviewInfo(
                                      value: _ferrousGiven,
                                      label: 'Ferrous FA\ngiven',
                                      icon: Icons.medication,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OverviewInfo(
                                      value: _calciumGiven,
                                      label: 'Calcium\ngiven',
                                      icon: Icons.local_pharmacy,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OverviewInfo(
                                      value: _tdDosesGiven,
                                      label: 'TD Vaccine\ndoses given',
                                      icon: Icons.vaccines,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Active Pregnancies Card with real data
                              MidwifeStatisticsCard(
                                totalPregnancies: _totalPregnancies,
                                firstTrimester: _firstTrimester,
                                secondTrimester: _secondTrimester,
                                thirdTrimester: _thirdTrimester,
                              ),

                              const SizedBox(height: 20),

                              // Recent Visits with real data
                              if (_recentVisits.isNotEmpty)
                                MidwifeHistoryCard(
                                  visits: _recentVisits,
                                  onTapItem: () {
                                    Navigator.pushNamed(context, '/midwife-mothers');
                                  },
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
                                        Icons.history,
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

                              // BHC Visits Chart with real data
                              if (_bhcVisitValues.any((v) => v > 0))
                                ChartCard(
                                  title: 'BHC Daily Visits (Last 7 Days)',
                                  headerIcon: Icons.show_chart_rounded,
                                  values: _bhcVisitValues,
                                  labels: _bhcVisitDays,
                                  unit: 'visits',
                                  lineColor: AppColors.brandPrimary,
                                  startingLabel: 'Lowest',
                                  startingValue: '${_bhcVisitValues.reduce((a, b) => a < b ? a : b).toInt()} visits',
                                  latestLabel: 'Highest',
                                  latestValue: '${_bhcVisitValues.reduce((a, b) => a > b ? a : b).toInt()} visits',
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
        ],
      ),
    );
  }
}