// lib/screens/mother/mother_child_growth.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/tab_button.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/ai_analytics_card.dart';
import '../../services/child_service.dart';

class MotherChildGrowthPage extends StatefulWidget {
  final VoidCallback onBack;
  final int childId;
  final String childName;
  final String childAge;
  final String childGender;

  const MotherChildGrowthPage({
    super.key,
    required this.onBack,
    required this.childId,
    required this.childName,
    required this.childAge,
    required this.childGender,
  });

  @override
  State<MotherChildGrowthPage> createState() => _MotherChildGrowthPageState();
}

class _MotherChildGrowthPageState extends State<MotherChildGrowthPage> {
  int _currentIndex = 0;
  Map<String, dynamic>? _growthData;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGrowthData();
  }

  Future<void> _fetchGrowthData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await ChildService.fetchGrowthHistory(widget.childId);
      if (mounted) {
        setState(() {
          _growthData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
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
      body: RefreshIndicator(
        onRefresh: _fetchGrowthData,
        color: AppColors.brandPrimary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              )
            : _errorMessage != null
                ? Center(
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchGrowthData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : (_growthData?['records_count'] ?? 0) < 2
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.bar_chart_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Not Enough Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Need at least 2 growth records to display charts.\nCurrent records: ${_growthData?['records_count'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
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
                                _buildChartContent(
                                  title: 'Height Chart',
                                  icon: Icons.height,
                                  values: (_growthData?['height']['values'] as List<dynamic>?)?.cast<double>() ?? [],
                                  unit: 'cm',
                                  start: _growthData?['height']['start'],
                                  latest: _growthData?['height']['latest'],
                                  gain: _growthData?['height']['gain'],
                                  labels: (_growthData?['labels'] as List<dynamic>?)?.cast<String>() ?? [],
                                ),
                                _buildChartContent(
                                  title: 'Weight Chart',
                                  icon: Icons.monitor_weight,
                                  values: (_growthData?['weight']['values'] as List<dynamic>?)?.cast<double>() ?? [],
                                  unit: 'kg',
                                  start: _growthData?['weight']['start'],
                                  latest: _growthData?['weight']['latest'],
                                  gain: _growthData?['weight']['gain'],
                                  labels: (_growthData?['labels'] as List<dynamic>?)?.cast<String>() ?? [],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildChartContent({
    required String title,
    required IconData icon,
    required List<double> values,
    required String unit,
    required dynamic start,
    required dynamic latest,
    required String? gain,
    required List<String> labels,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          HeroCard(
            image: null,
            title: widget.childName,
            subtitle: '${widget.childAge} • ${widget.childGender == 'female' ? 'Girl' : 'Boy'}',
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: title,
            headerIcon: icon,
            values: values,
            labels: labels,
            unit: unit,
            lineColor: AppColors.brandPrimary,
            startingLabel: 'Starting',
            startingValue: start != null ? '$start $unit' : '--',
            latestLabel: 'Latest',
            latestValue: latest != null ? '$latest $unit' : '--',
            insightText: gain != null
                ? '${widget.childName} ${title.contains('Height') ? 'grew' : 'gained'} $gain $unit!'
                : 'Add more records for trend analysis',
          ),
          const SizedBox(height: 16),
          AiAnalyticsCard(
            text: _generateAIAnalysis(values, unit, gain, widget.childName),
          ),
        ],
      ),
    );
  }

  String _generateAIAnalysis(List<double> values, String unit, String? gain, String childName) {
    if (values.isEmpty) {
      return 'No growth data available yet. Add growth records to see AI analysis.';
    }
    
    if (values.length < 2) {
      return 'Need at least 2 measurements for trend analysis. Current: ${values.length} record(s).';
    }
    
    final first = values.first;
    final last = values.last;
    final change = last - first;
    final percentChange = (change / first * 100).abs();
    
    if (unit == 'cm') {
      if (change > 5) {
        return '$childName has shown excellent height growth of ${change.toStringAsFixed(1)} cm (${percentChange.toStringAsFixed(0)}% increase). This indicates healthy physical development.';
      } else if (change > 2) {
        return '$childName is showing steady height growth of ${change.toStringAsFixed(1)} cm. Growth is progressing within expected ranges.';
      } else {
        return '$childName\'s height growth has been minimal (${change.toStringAsFixed(1)} cm). Continue monitoring and ensure proper nutrition.';
      }
    } else {
      if (change > 2) {
        return '$childName has gained ${change.toStringAsFixed(1)} kg (${percentChange.toStringAsFixed(0)}% increase). Weight gain is appropriate for age.';
      } else if (change > 0.5) {
        return '$childName is maintaining steady weight gain of ${change.toStringAsFixed(1)} kg. Continue regular monitoring.';
      } else {
        return '$childName\'s weight gain has been minimal (${change.toStringAsFixed(1)} kg). Consult healthcare provider if concerned.';
      }
    }
  }
}