// lib/screens/mother/mother_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../models/baby_growth_model.dart';
import '../../widgets/headline.dart';
import '../../widgets/small_description.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/small_info_box.dart';
import '../../widgets/long_info_box.dart';
import '../../widgets/comparison_card.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';

class MotherDashboard extends StatefulWidget {
  const MotherDashboard({super.key});

  @override
  State<MotherDashboard> createState() => _MotherDashboardState();
}

class _MotherDashboardState extends State<MotherDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final motherId = await AuthStorage.getMotherId();
      final accountId = await AuthStorage.getUserId();

      if (motherId == null || accountId == null) {
        throw Exception('User not properly authenticated');
      }

      // Get account info
      final accountResponse = await SupabaseService.client
          .from('accounts')
          .select('first_name, middle_name, last_name, extension_name')
          .eq('account_id', accountId)
          .single();

      // Get mother info
      final motherResponse = await SupabaseService.client
          .from('mothers')
          .select('''
            birthdate,
            assigned_bhc_id,
            bhc!inner(bhc_name)
          ''')
          .eq('mother_id', motherId)
          .single();

      // Get current pregnancy
      final pregnancyResponse = await SupabaseService.client
          .from('pregnancies')
          .select('''
            pregnancy_id,
            last_menstrual_period,
            expected_date_of_delivery,
            status
          ''')
          .eq('mother_id', motherId)
          .eq('status', 'ongoing')
          .maybeSingle();

      // Get latest checkup for AOG
      int? latestAOG;
      DateTime? nextCheckup;
      if (pregnancyResponse != null) {
        final checkupResponse = await SupabaseService.client
            .from('prenatal_checkups')
            .select('age_of_gestation, next_schedule')
            .eq('pregnancy_id', pregnancyResponse['pregnancy_id'])
            .order('checkup_datetime', ascending: false)
            .limit(1)
            .maybeSingle();

        if (checkupResponse != null) {
          latestAOG = checkupResponse['age_of_gestation']?.toInt();
          if (checkupResponse['next_schedule'] != null) {
            nextCheckup = DateTime.tryParse(checkupResponse['next_schedule']);
          }
        }
      }

      // Calculate dashboard values
      final firstName = accountResponse['first_name'] ?? 'Mother';
      final bhcName = motherResponse['bhc']?['bhc_name'] ?? 'No Barangay Assigned';

      int week = 0;
      int weeksLeft = 0;
      String trimester = '—';
      String dueDate = '—';

      if (pregnancyResponse != null) {
        // Use LMP if available, otherwise use latest checkup AOG
        if (pregnancyResponse['last_menstrual_period'] != null) {
          final lmp = DateTime.parse(pregnancyResponse['last_menstrual_period']);
          final today = DateTime.now();
          week = (today.difference(lmp).inDays / 7).floor();
          week = week.clamp(1, 42);
        } else if (latestAOG != null && latestAOG > 0) {
          week = latestAOG;
        }

        if (pregnancyResponse['expected_date_of_delivery'] != null) {
          final edd = DateTime.parse(pregnancyResponse['expected_date_of_delivery']);
          dueDate = DateFormat('MMMM d, yyyy').format(edd);
          final today = DateTime.now();
          weeksLeft = (edd.difference(today).inDays / 7).ceil();
          weeksLeft = weeksLeft.clamp(0, 42);
        }

        // Determine trimester
        if (week <= 13) {
          trimester = 'First Trimester';
        } else if (week <= 26) {
          trimester = 'Second Trimester';
        } else {
          trimester = 'Third Trimester';
        }
      }

      setState(() {
        _dashboardData = {
          'first_name': firstName,
          'bhc_name': bhcName,
          'week': week,
          'weeks_left': weeksLeft,
          'trimester': trimester,
          'due_date': dueDate,
          'has_pregnancy': pregnancyResponse != null,
          'next_checkup': nextCheckup,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        _buildWelcomeCard(),

                        const SizedBox(height: 20),

                        // Hero Card
                        HeroCard(
                          image: const AssetImage('assets/images/pregnant1.png'),
                          week: _dashboardData?['week'] ?? 0,
                          showWeekBadge: _dashboardData?['has_pregnancy'] ?? false,
                          showHeartRow: _dashboardData?['has_pregnancy'] ?? false,
                        ),

                        const SizedBox(height: 20),

                        // Baby Stats - FIXED: This now shows ideal baby size and weight
                        _buildBabyGrowthInfo(),

                        const SizedBox(height: 16),

                        // Due Date Info
                        _buildDueDateInfo(),

                        const SizedBox(height: 16),

                        // Comparison Card (only show if pregnancy is set and week is valid)
                        if ((_dashboardData?['has_pregnancy'] ?? false) && 
                            (_dashboardData?['week'] ?? 0) > 0)
                          ComparisonCard(week: _dashboardData?['week'] ?? 0),

                        const SizedBox(height: 16),

                        // Next Check-up
                        _buildNextCheckup(),

                        const SizedBox(height: 24),

                        // Action Buttons
                        MainButton(
                          label: 'More Info',
                          showIcons: true,
                          leadingIcon: Icons.info_outline,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('More info coming soon')),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        SecondaryButton(
                          label: 'Conclude Pregnancy',
                          showIcons: true,
                          leadingIcon: Icons.check,
                          onPressed: (_dashboardData?['has_pregnancy'] ?? false)
                              ? _showConcludePregnancyDialog
                              : () {},
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
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

  Widget _buildWelcomeCard() {
    final firstName = _dashboardData?['first_name'] ?? 'Mother';
    final week = _dashboardData?['week'] ?? 0;
    final trimester = _dashboardData?['trimester'] ?? '—';
    final hasPregnancy = _dashboardData?['has_pregnancy'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Headline(
            text: 'Welcome, $firstName! 🌸',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SmallDescription(
            icon: Icons.calendar_today,
            text: hasPregnancy
                ? 'Week $week • $trimester'
                : 'No active pregnancy',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // FIXED: This now properly shows baby's ideal size and weight
  Widget _buildBabyGrowthInfo() {
    final week = _dashboardData?['week'] ?? 0;
    final hasPregnancy = _dashboardData?['has_pregnancy'] ?? false;

    if (!hasPregnancy || week <= 0) {
      return Row(
        children: [
          Expanded(
            child: SmallInfoBox(
              icon: Icons.straighten,
              title: 'Ideal Baby Size',
              value: '—',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SmallInfoBox(
              icon: Icons.monitor_weight,
              title: 'Ideal Baby Weight',
              value: '—',
            ),
          ),
        ],
      );
    }

    // Get baby growth data for the current week
    final babyGrowth = BabyGrowthData.getForWeek(week);

    return Row(
      children: [
        Expanded(
          child: SmallInfoBox(
            icon: Icons.straighten,
            title: 'Ideal Baby Size',
            value: babyGrowth.size,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SmallInfoBox(
            icon: Icons.monitor_weight,
            title: 'Ideal Baby Weight',
            value: babyGrowth.weight,
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateInfo() {
    final dueDate = _dashboardData?['due_date'] ?? '—';
    final weeksLeft = _dashboardData?['weeks_left'] ?? 0;
    final week = _dashboardData?['week'] ?? 0;
    final hasPregnancy = _dashboardData?['has_pregnancy'] ?? false;

    if (!hasPregnancy) {
      return LongInfoBox(
        icon: Icons.info_outline,
        borderColor: AppColors.borderPrimary,
        iconColor: AppColors.brandPrimary,
        text: [
          const TextSpan(
            text: 'No Active Pregnancy',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const TextSpan(
            text: '\n\nPlease consult your midwife to register your pregnancy.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return LongInfoBox(
      icon: Icons.calendar_month,
      borderColor: AppColors.borderPrimary,
      iconColor: AppColors.brandPrimary,
      text: [
        const TextSpan(
          text: 'Due Date: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        TextSpan(
          text: '$dueDate\n',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const TextSpan(
          text: 'You are ',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        TextSpan(
          text: week > 0 ? '$weeksLeft weeks away' : '—',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.brandPrimary,
          ),
        ),
        const TextSpan(
          text: ' from meeting your baby!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNextCheckup() {
    final nextCheckup = _dashboardData?['next_checkup'];
    final hasPregnancy = _dashboardData?['has_pregnancy'] ?? false;

    if (!hasPregnancy) {
      return const SizedBox.shrink();
    }

    return LongInfoBox(
      icon: Icons.notifications,
      borderColor: AppColors.borderPrimary,
      iconColor: AppColors.brandPrimary,
      text: [
        const TextSpan(
          text: 'Next Check-up\n',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        TextSpan(
          text: nextCheckup != null
              ? '${DateFormat('MMMM d, yyyy').format(nextCheckup)} – ${DateFormat('EEEE').format(nextCheckup)}'
              : 'No scheduled checkups',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showConcludePregnancyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Conclude Pregnancy'),
        content: const Text(
          'Are you sure you want to conclude this pregnancy?\n\n'
          'This will mark the current pregnancy as ended and '
          'allow you to register a new one if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conclude pregnancy coming soon'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conclude'),
          ),
        ],
      ),
    );
  }
}