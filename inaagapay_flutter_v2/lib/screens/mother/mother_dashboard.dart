// lib/screens/mother/mother_dashboard.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../widgets/main_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/headline.dart';
import '../../widgets/small_info_box.dart';
import '../../widgets/long_info_box.dart';
import '../../widgets/comparison_card.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../models/baby_growth_model.dart';

class MotherDashboard extends StatelessWidget {
  const MotherDashboard({super.key});

  String _getTrimester(int week) {
    if (week <= 13) return 'First Trimester';
    if (week <= 27) return 'Second Trimester';
    return 'Third Trimester';
  }

  @override
  Widget build(BuildContext context) {
    const int week = 27;
    final String trimester = _getTrimester(week);
    final babyGrowth = BabyGrowthData.getForWeek(week);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          MainHeader(
            title: 'HOME',
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
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome
                    Center(
                      child: Column(
                        children: [
                          const Headline(
                            text: 'Welcome, Nanay! 🌸',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Week $week • $trimester',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const HeroCard(
                      image: null,
                      week: 39,
                      showWeekBadge: true,
                      showHeartRow: true,
                    ),

                    const SizedBox(height: 20),

                    // Baby stats
                    Row(
                      children: [
                        SmallInfoBox(
                          icon: Icons.straighten,
                          title: 'Ideal Baby Size',
                          value: babyGrowth.size,
                        ),
                        const SizedBox(width: 12),
                        SmallInfoBox(
                          icon: Icons.monitor_weight,
                          title: 'Ideal Baby Weight',
                          value: babyGrowth.weight,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Due date
                    const LongInfoBox(
                      icon: Icons.calendar_month,
                      text: [
                        TextSpan(
                          text: 'Due Date: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'October 15, 2026\n',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: 'You are ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: '12 Weeks away',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' from meeting!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    ComparisonCard(week: week),

                    const SizedBox(height: 20),

                    // Next check-up
                    const LongInfoBox(
                      icon: Icons.notifications,
                      borderColor: AppColors.borderPrimary,
                      iconColor: AppColors.brandPrimary,
                      text: [
                        TextSpan(
                          text: 'Next Check-up\n',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'June 15, 2026 – Monday',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    MainButton(
                      label: 'More Info',
                      showIcons: true,
                      onPressed: () {
                        // TODO: Implement more info functionality
                      },
                    ),

                    const SizedBox(height: 12),

                    SecondaryButton(
                      label: 'Conclude Pregnancy',
                      showIcons: true,
                      onPressed: () {
                        // TODO: Implement conclude pregnancy functionality
                      },
                    ),

                    const SizedBox(height: 10),
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