import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/chart_card.dart';
import '../widgets/hero_card.dart';
import '../widgets/ai_analytics_card.dart';

class MotherGrowthPage extends StatelessWidget {
  final VoidCallback onBack;

  const MotherGrowthPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(title: 'Growth Statistics', onBack: onBack),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            HeroCard(
              image: const AssetImage('assets/images/mother_weight.png'),
              title: 'First Name MI. Last Name',
              showWeekBadge: false,
              showHeartRow: false,
            ),

            const SizedBox(height: 16),

            ChartCard(
              title: 'Weight Chart',
              headerIcon: Icons.monitor_weight,
              values: const [43.5, 45.8, 48.2, 49.1],
              labels: const ['4w', '12w', '16w', '18w'],
              unit: 'kg',
              lineColor: AppColors.brandPrimary,
              startingLabel: 'Starting Weight',
              startingValue: '-- kg',
              latestLabel: 'Latest Record',
              latestValue: '-- kg',
              insightText: 'You gained __ kg in two weeks!',
            ),
            SizedBox(height: 16),
            AiAnalyticsCard(
              text:
                  'Weight gain is steady and appropriate for the current gestational age.',
            ),
          ],
        ),
      ),
    );
  }
}
