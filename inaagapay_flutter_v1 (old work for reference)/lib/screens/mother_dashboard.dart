// lib/screens/mother/mother_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_header.dart';
import '../../widgets/main_bottom_navigation.dart';
import '../../widgets/headline.dart';
import '../../widgets/small_description.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/small_info_box.dart';
import '../../widgets/long_info_box.dart';
import '../../widgets/comparison_card.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../models/baby_growth_model.dart';
import '../../services/auth_storage.dart';

class MotherDashboard extends StatefulWidget {
  const MotherDashboard({super.key});

  @override
  State<MotherDashboard> createState() => _MotherDashboardState();
}

class _MotherDashboardState extends State<MotherDashboard> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // Dashboard data
  int _week = 0;
  int _weeksLeft = 0;
  String _trimester = '—';
  String _dueDate = '—';
  String _firstName = '';
  bool _hasPregnancy = false;

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
      // Get mother ID from storage
      final motherId = await AuthStorage.getMotherId();
      debugPrint('=== DASHBOARD DEBUG ===');
      debugPrint('Mother ID: $motherId');
      
      if (motherId == null) {
        throw Exception('Mother ID not found. Please log out and log in again.');
      }

      // Get account info for name
      final accountId = await AuthStorage.getUserId();
      debugPrint('Account ID: $accountId');
      
      if (accountId != null) {
        final accountResponse = await SupabaseService.client
            .from('accounts')
            .select('first_name, last_name')
            .eq('account_id', accountId)
            .maybeSingle();
        
        debugPrint('Account response: $accountResponse');
        
        if (accountResponse != null) {
          final firstName = accountResponse['first_name']?.toString() ?? '';
          final lastName = accountResponse['last_name']?.toString() ?? '';
          _firstName = '$firstName $lastName'.trim();
          if (_firstName.isEmpty) _firstName = firstName;
        }
      }

      // Get current pregnancy data
      final pregnancyResponse = await SupabaseService.client
          .from('pregnancies')
          .select('*')
          .eq('mother_id', motherId)
          .eq('status', 'ongoing')
          .maybeSingle();
      
      debugPrint('Pregnancy response: $pregnancyResponse');

      if (pregnancyResponse != null) {
        _hasPregnancy = true;
        final lmpStr = pregnancyResponse['last_menstrual_period'] as String?;
        final eddStr = pregnancyResponse['expected_date_of_delivery'] as String?;
        
        debugPrint('LMP: $lmpStr, EDD: $eddStr');
        
        if (lmpStr != null && lmpStr.isNotEmpty) {
          final lmp = DateTime.parse(lmpStr);
          final now = DateTime.now();
          _week = now.difference(lmp).inDays ~/ 7;
          debugPrint('Current week: $_week');
          
          // Calculate EDD if not set
          DateTime edd;
          if (eddStr != null && eddStr.isNotEmpty) {
            edd = DateTime.parse(eddStr);
          } else {
            edd = lmp.add(const Duration(days: 280));
          }
          
          // Format due date
          _dueDate = DateFormat('MMMM d, yyyy').format(edd);
          
          // Calculate weeks left
          final daysLeft = edd.difference(now).inDays;
          _weeksLeft = daysLeft > 0 ? daysLeft ~/ 7 : 0;
          
          // Determine trimester
          if (_week <= 13) {
            _trimester = 'First Trimester';
          } else if (_week <= 27) {
            _trimester = 'Second Trimester';
          } else {
            _trimester = 'Third Trimester';
          }
          
          debugPrint('Due date: $_dueDate, Weeks left: $_weeksLeft, Trimester: $_trimester');
        } else {
          debugPrint('No LMP found for pregnancy');
          _hasPregnancy = false;
        }
      } else {
        debugPrint('No ongoing pregnancy found for mother ID: $motherId');
        _hasPregnancy = false;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthStorage.clearAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () async {
                Navigator.pop(context);
                final motherId = await AuthStorage.getMotherId();
                if (motherId != null && mounted) {
                  Navigator.pushNamed(
                    context, 
                    '/mother-profile', 
                    arguments: motherId
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help coming soon')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'HOME',
          onNotificationTap: () {},
          onAvatarTap: () => _showProfileSheet(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDashboardData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                            ),
                            child: const Text('Retry'),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Welcome Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Headline(
                                  text: 'Welcome, ${_firstName.isNotEmpty ? _firstName.split(' ').first : 'Nanay'}! 🌸',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                SmallDescription(
                                  icon: Icons.calendar_today,
                                  text: _hasPregnancy && _week > 0
                                      ? 'Week $_week • $_trimester'
                                      : 'No active pregnancy',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          HeroCard(
                            image: const AssetImage('assets/images/pregnant1.png'),
                            week: _hasPregnancy && _week > 0 ? _week : null,
                            showWeekBadge: _hasPregnancy && _week > 0,
                            showHeartRow: _hasPregnancy && _week > 0,
                          ),

                          const SizedBox(height: 20),

                          // Baby Growth Info (only show if pregnancy is set)
                          if (_hasPregnancy && _week > 0) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SmallInfoBox(
                                    icon: Icons.straighten,
                                    title: 'Ideal Baby Size',
                                    value: BabyGrowthData.getForWeek(_week).size,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SmallInfoBox(
                                    icon: Icons.monitor_weight,
                                    title: 'Ideal Baby Weight',
                                    value: BabyGrowthData.getForWeek(_week).weight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Due Date Info
                          LongInfoBox(
                            icon: Icons.calendar_month,
                            text: [
                              const TextSpan(
                                text: 'Due Date: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: _hasPregnancy && _dueDate != '—' ? '$_dueDate\n' : 'Not set\n',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              if (_hasPregnancy && _week > 0) ...[
                                const TextSpan(
                                  text: 'You are ',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: '$_weeksLeft weeks away',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' from meeting!',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ] else if (!_hasPregnancy) ...[
                                const TextSpan(
                                  text: 'No active pregnancy',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Comparison Card (only show if pregnancy is set)
                          if (_hasPregnancy && _week > 0) ComparisonCard(week: _week),

                          const SizedBox(height: 24),

                          // Action Buttons
                          MainButton(
                            label: 'More Info',
                            showIcons: true,
                            leftIcon: Icons.info_outline,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('More info coming soon!')),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          SecondaryButton(
                            label: 'Conclude Pregnancy',
                            showIcons: true,
                            leadingIcon: Icons.check,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Conclude pregnancy coming soon!')),
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 0),
    );
  }
}