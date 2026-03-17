// lib/screens/mother/mother_dashboard.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/headline.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/small_info_box.dart';
import '../../widgets/long_info_box.dart';
import '../../widgets/comparison_card.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/small_description.dart';
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

    return Container(
      color: AppColors.bgPrimary,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Headline(
                      text: 'Welcome, Nanay! 🌸',
                    ),
                    const SizedBox(height: 8),
                    SmallDescription(
                      icon: Icons.calendar_today,
                      text: 'Week $week • $trimester',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              HeroCard(
                image: const AssetImage('assets/images/pregnant1.png'),
                week: 39,
                showWeekBadge: true,
                showHeartRow: true,
              ),

              const SizedBox(height: 20),

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
                leftIcon: Icons.info_outline,
                onPressed: () {},
              ),

              const SizedBox(height: 12),

              SecondaryButton(
                label: 'Conclude Pregnancy',
                showIcons: true,
                leadingIcon: Icons.check,
                onPressed: () {},
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}