import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/tab_button.dart';
import '../widgets/hero_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/ai_analytics_card.dart';

import '../services/api_service.dart';
import '../utils/session.dart';

class MotherChildGrowthPage extends StatefulWidget {
  final VoidCallback onBack;
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildGrowthPage({
    super.key,
    required this.onBack,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildGrowthPage> createState() =>
      _MotherChildGrowthPageState();
}

class _MotherChildGrowthPageState extends State<MotherChildGrowthPage> {
  int _currentIndex = 0;

  Future<Map<String, dynamic>> _fetchGrowth() async {
    return await ApiService.get(
      'mother/child_growth.php?child_id=${widget.childId}',
      token: Session.token,
    );
  }

  List<double> _toDoubleList(List<dynamic> raw) {
    return raw.map((e) => (e as num).toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: 'Growth Statistics',
          onBack: widget.onBack,
        ),
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchGrowth(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          if (!data['success']) {
            return const Center(child: Text('Failed to load data'));
          }

          final height = data['height'];
          final weight = data['weight'];

          final heightValues = _toDoubleList(height['values']);
          final weightValues = _toDoubleList(weight['values']);

          return Column(
            children: [
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TabButton(
                    label: 'Height Chart',
                    isActive: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  const SizedBox(width: 12),
                  TabButton(
                    label: 'Weight Chart',
                    isActive: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _chartContent(
                      image: 'height.png',
                      title: 'Height Chart',
                      icon: Icons.height,
                      values: heightValues,
                      unit: 'cm',
                      start: height['start'],
                      latest: height['latest'],
                      insight:
                          '${widget.childName} grew by ${height['gain']} cm!',
                      ai: data['ai']['height'],
                    ),
                    _chartContent(
                      image: 'weight.png',
                      title: 'Weight Chart',
                      icon: Icons.monitor_weight,
                      values: weightValues,
                      unit: 'kg',
                      start: weight['start'],
                      latest: weight['latest'],
                      insight:
                          '${widget.childName} gained ${weight['gain']} kg!',
                      ai: data['ai']['weight'],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chartContent({
    required String image,
    required String title,
    required IconData icon,
    required List<double> values,
    required String unit,
    required dynamic start,
    required dynamic latest,
    required String insight,
    required String ai,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          HeroCard(
            image: AssetImage('assets/images/$image'),
            title: widget.childName,
            subtitle: widget.childAge,
            showWeekBadge: false,
            showHeartRow: false,
          ),

          const SizedBox(height: 16),

          ChartCard(
            title: title,
            headerIcon: icon,
            values: values,
            labels:
                List.generate(values.length, (i) => 'R${i + 1}'),
            unit: unit,
            lineColor: AppColors.brandPrimary,
            startingLabel: 'Starting',
            startingValue: start != null ? '$start $unit' : '--',
            latestLabel: 'Latest',
            latestValue: latest != null ? '$latest $unit' : '--',
            insightText: insight,
          ),

          const SizedBox(height: 16),

          AiAnalyticsCard(text: ai),
        ],
      ),
    );
  }
}
