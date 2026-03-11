// lib/screens/midwife/midwife_dashboard.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../widgets/main_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/overview_info.dart';
import '../../widgets/midwife_statistics_card.dart';
import '../../widgets/midwife_history_card.dart';
import '../../widgets/chart_card.dart';

class MidwifeDashboard extends StatelessWidget {
  const MidwifeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data
    const int ferrousGiven = 90;
    const int calciumGiven = 65;
    const int tdDosesGiven = 12;

    const int totalPregnancies = 13;
    const int firstTrimester = 4;
    const int secondTrimester = 5;
    const int thirdTrimester = 4;

    final List<double> bhcVisitValues = [5, 7, 6, 8, 9, 4, 3];
    final List<String> bhcVisitDays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Hero Card
                  HeroCard(
                    image: null,
                    title: 'Welcome, Midwife! 🌸',
                    subtitle: 'Barangay Sta. Barbara',
                    showWeekBadge: false,
                    showHeartRow: false,
                  ),

                  const SizedBox(height: 20),

                  // Quick Overview
                  Row(
                    children: const [
                      Expanded(
                        child: OverviewInfo(
                          value: 12,
                          label: 'Registered\nChildren',
                          icon: Icons.child_care_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OverviewInfo(
                          value: 24,
                          label: 'Registered\nMothers',
                          icon: Icons.pregnant_woman,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OverviewInfo(
                          value: ferrousGiven,
                          label: 'Ferrous FA\ngiven',
                          icon: Icons.medication,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OverviewInfo(
                          value: calciumGiven,
                          label: 'Calcium\ngiven',
                          icon: Icons.local_pharmacy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OverviewInfo(
                          value: tdDosesGiven,
                          label: 'TD Vaccine\ndoses given',
                          icon: Icons.vaccines,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Active Pregnancies Card
                  MidwifeStatisticsCard(
                    totalPregnancies: totalPregnancies,
                    firstTrimester: firstTrimester,
                    secondTrimester: secondTrimester,
                    thirdTrimester: thirdTrimester,
                  ),

                  const SizedBox(height: 20),

                  // Recent Visits
                  MidwifeHistoryCard(
                    visits: const [
                      MidwifeVisitItem(
                        fullName: 'Maria Santos',
                        visitType: 'Prenatal Check-up',
                        timeLabel: 'Today',
                      ),
                      MidwifeVisitItem(
                        fullName: 'Juana Dela Cruz',
                        visitType: 'Prenatal Check-up',
                        timeLabel: 'Yesterday',
                      ),
                      MidwifeVisitItem(
                        fullName: 'Ana Lopez',
                        visitType: 'Prenatal Check-up',
                        timeLabel: '2 days ago',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BHC Visits Chart
                  ChartCard(
                    title: 'BHC Daily Visits Chart',
                    headerIcon: Icons.show_chart_rounded,
                    values: bhcVisitValues,
                    labels: bhcVisitDays,
                    unit: 'visits',
                    lineColor: AppColors.brandPrimary,
                    startingLabel: 'Lowest',
                    startingValue: '3 visits',
                    latestLabel: 'Highest',
                    latestValue: '9 visits',
                    insightText:
                        'Tuesday had the most prenatal visits this week!',
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}