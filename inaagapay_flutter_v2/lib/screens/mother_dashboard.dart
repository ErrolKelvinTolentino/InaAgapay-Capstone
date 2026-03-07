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

// 🆕 MODEL IMPORT
import '../models/baby_growth_model.dart';

class MotherDashboard extends StatelessWidget {
  const MotherDashboard({super.key});

  // 🧠 Trimester logic
  String _getTrimester(int week) {
    if (week <= 13) return 'First Trimester';
    if (week <= 27) return 'Second Trimester';
    return 'Third Trimester';
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 TEMP HARD-CODED DATA (backend later)
    const int week = 27;
    final String trimester = _getTrimester(week);

    // 🧠 IDEAL BABY DATA (size + weight)
    final babyGrowth = BabyGrowthData.getForWeek(week);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      // 🔝 Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'HOME',
          onViewProfile: () => Navigator.pushNamed(context, '/profile'),
          onSettings: () => Navigator.pushNamed(context, '/settings'),
          onHelp: () => Navigator.pushNamed(context, '/help'),
          onLogout: () {
            // clear session, navigate to login
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),

      // 🔽 Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👋 Welcome
              Center(
                child: Column(
                  children: [
                    const Headline(
                      text: 'Welcome, [First Name]! 🌸',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    SmallDescription(
                      icon: Icons.calendar_today,
                      text: 'Week $week • $trimester',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🧸 HERO CARD
              HeroCard(
                image: const AssetImage('assets/images/pregnant1.png'),
                week: 39,
                showWeekBadge: true,
                showHeartRow: true,
              ),

              const SizedBox(height: 20),

              // 📦 Baby stats
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

              // 📅 Due date
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
                    text: 'Month Day, Year\n',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: 'You are ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: 'X Weeks away',
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

              // 🫐 Comparison
              ComparisonCard(week: week),

              const SizedBox(height: 20),

              // 🔔 Next check-up
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
                    text: 'Month Day, Year – Day',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🔘 Actions
              MainButton(
                label: 'More Info',
                showIcons: true,
                leadingIcon: Icons.info_outline,
                onPressed: () {
                  // TODO
                },
              ),

              const SizedBox(height: 12),

              SecondaryButton(
                label: 'Conclude Pregnancy',
                showIcons: true,
                leadingIcon: Icons.check,
                onPressed: () {
                  // TODO
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),

      // 🔻 Bottom Nav
      bottomNavigationBar: MainBottomNavigation(currentIndex: 0),
    );
  }
}
