import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/main_bottom_navigation.dart';
import '../widgets/headline.dart';
import '../widgets/small_description.dart';
import '../widgets/hero_card.dart';
import '../widgets/small_info_box.dart';
import '../widgets/long_info_box.dart';
import '../widgets/comparison_card.dart';
import '../widgets/main_button.dart';
import '../widgets/secondary_button.dart';

import '../models/baby_growth_model.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class MotherDashboard extends StatelessWidget {
  const MotherDashboard({super.key});

  Future<Map<String, dynamic>> _loadDashboard() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final res = await ApiService.get('mother/dashboard.php', token: token);

    if (res['success'] != true) {
      throw Exception('Failed to load dashboard');
    }

    return res;
  }

  Future<void> _logout(BuildContext context) async {
    final token = await AuthStorage.getToken();

    try {
      if (token != null && token.isNotEmpty) {
        await ApiService.post('auth/logout.php', const {}, token: token);
      }
    } catch (_) {
      // Ignore network errors and continue clearing local session.
    }

    await AuthStorage.clearToken();

    // Navigate back to login
    if (context.mounted) {
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
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile coming soon')),
                );
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
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadDashboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load dashboard',
                  style: TextStyle(color: AppColors.error),
                ),
              );
            }

            final data = snapshot.data!;

            final int week = (data['week'] ?? 0) as int;
            final int weeksLeft = (data['weeks_left'] ?? 0) as int;
            final String trimester = data['trimester'] ?? '—';
            final String dueDate = data['due_date'] ?? '—';
            final String firstName = data['first_name'] ?? '';

            // Get baby growth data from model
            final BabyGrowth babyGrowth = BabyGrowthData.getForWeek(week);

            return SingleChildScrollView(
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
                          text: 'Welcome, $firstName! 🌸',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SmallDescription(
                          icon: Icons.calendar_today,
                          text: week > 0
                              ? 'Week $week • $trimester'
                              : 'Pregnancy not yet set',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  HeroCard(
                    image: const AssetImage('assets/images/pregnant1.png'),
                    week: week,
                    showWeekBadge: week > 0,
                    showHeartRow: week > 0,
                  ),

                  const SizedBox(height: 20),

                  // Baby Growth Info
                  Row(
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
                  ),

                  const SizedBox(height: 16),

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
                        text: ' from meeting!',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Comparison Card (only show if pregnancy is set)
                  if (week > 0) ComparisonCard(week: week),

                  const SizedBox(height: 24),

                  // Action Buttons
                  MainButton(
                    label: 'More Info',
                    showIcons: true,
                    leadingIcon: Icons.info_outline,
                    onPressed: () {
  Navigator.pushNamed(context, '/mother-more-info');
},

                  ),

                  const SizedBox(height: 12),

                  SecondaryButton(
                    label: 'Conclude Pregnancy',
                    showIcons: true,
                    leadingIcon: Icons.check,
                    onPressed: () {
                      // TODO: Implement conclude pregnancy functionality
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: const MainBottomNavigation(currentIndex: 0),
    );
  }
}
