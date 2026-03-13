// lib/screens/mother/mother_child_growth_page.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/tab_button.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/ai_analytics_card.dart';

class MotherChildGrowthPage extends StatefulWidget {
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildGrowthPage({
    super.key,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildGrowthPage> createState() => _MotherChildGrowthPageState();
}

class _MotherChildGrowthPageState extends State<MotherChildGrowthPage> {
  int _currentIndex = 0;
  Map<String, dynamic>? _growthData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGrowthData();
  }

  Future<void> _loadGrowthData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SupabaseService.ensureSession();

      // Get all growth records for this child
      final response = await SupabaseService.client
          .from('child_details')
          .select('child_height, child_weight, created_at')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: true);

      final records = List<Map<String, dynamic>>.from(response);

      if (records.isEmpty) {
        setState(() {
          _growthData = {
            'height': {'values': [], 'start': null, 'latest': null, 'gain': 0},
            'weight': {'values': [], 'start': null, 'latest': null, 'gain': 0},
            'ai': {
              'height': 'No height data available yet. Start tracking your child\'s growth regularly.',
              'weight': 'No weight data available yet. Regular measurements help track healthy development.',
            }
          };
          _isLoading = false;
        });
        return;
      }

      // Extract height and weight values
      final heightValues = records.map((r) => (r['child_height'] as num?)?.toDouble() ?? 0).where((h) => h > 0).toList();
      final weightValues = records.map((r) => (r['child_weight'] as num?)?.toDouble() ?? 0).where((w) => w > 0).toList();

      // Calculate stats
      final double? firstHeight = heightValues.isNotEmpty ? heightValues.first : null;
      final double? lastHeight = heightValues.isNotEmpty ? heightValues.last : null;
      final double? firstWeight = weightValues.isNotEmpty ? weightValues.first : null;
      final double? lastWeight = weightValues.isNotEmpty ? weightValues.last : null;

      final heightGain = firstHeight != null && lastHeight != null 
          ? (lastHeight - firstHeight).toStringAsFixed(1) 
          : '0';
      final weightGain = firstWeight != null && lastWeight != null 
          ? (lastWeight - firstWeight).toStringAsFixed(1) 
          : '0';

      // Generate AI insights
      final heightInsight = _generateHeightInsight(heightValues, heightGain);
      final weightInsight = _generateWeightInsight(weightValues, weightGain);

      setState(() {
        _growthData = {
          'height': {
            'values': heightValues,
            'start': firstHeight,
            'latest': lastHeight,
            'gain': heightGain,
          },
          'weight': {
            'values': weightValues,
            'start': firstWeight,
            'latest': lastWeight,
            'gain': weightGain,
          },
          'ai': {
            'height': heightInsight,
            'weight': weightInsight,
          }
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _generateHeightInsight(List<double> values, String gain) {
    if (values.isEmpty) return 'No height data available yet.';
    
    final avgGrowth = values.length > 1 
        ? (values.last - values.first) / (values.length - 1) 
        : 0;
    
    if (avgGrowth < 0.5) {
      return '${widget.childName}\'s height growth has been slower than average. Consider consulting with your pediatrician.';
    } else if (avgGrowth > 2) {
      return '${widget.childName} is showing excellent height growth! Keep up the good nutrition.';
    } else {
      return '${widget.childName}\'s height is growing at a healthy rate. Total growth of $gain cm recorded.';
    }
  }

  String _generateWeightInsight(List<double> values, String gain) {
    if (values.isEmpty) return 'No weight data available yet.';
    
    final avgGain = values.length > 1 
        ? (values.last - values.first) / (values.length - 1) 
        : 0;
    
    if (avgGain < 0.3) {
      return 'Weight gain has been minimal. Ensure ${widget.childName} is getting adequate nutrition.';
    } else if (avgGain > 1) {
      return 'Healthy weight gain detected! ${widget.childName} gained $gain kg overall.';
    } else {
      return 'Weight is progressing within normal ranges. Total gain of $gain kg recorded.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SecondaryHeader(
            title: 'Growth Statistics',
            onBack: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_error != null || _growthData == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SecondaryHeader(
            title: 'Growth Statistics',
            onBack: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_error ?? 'Failed to load growth data'),
        ),
      );
    }

    final heightData = _growthData!['height'];
    final weightData = _growthData!['weight'];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: 'Growth Statistics',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: Column(
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
                  image: 'height.png',
                  title: 'Height Chart',
                  icon: Icons.height,
                  values: heightData['values'],
                  unit: 'cm',
                  start: heightData['start'],
                  latest: heightData['latest'],
                  insight: '${widget.childName} grew by ${heightData['gain']} cm!',
                  ai: _growthData!['ai']['height'],
                ),
                _buildChartContent(
                  image: 'weight.png',
                  title: 'Weight Chart',
                  icon: Icons.monitor_weight,
                  values: weightData['values'],
                  unit: 'kg',
                  start: weightData['start'],
                  latest: weightData['latest'],
                  insight: '${widget.childName} gained ${weightData['gain']} kg!',
                  ai: _growthData!['ai']['weight'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent({
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
            image: const AssetImage('assets/images/baby.png'),
            title: widget.childName,
            subtitle: widget.childAge,
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No $title data available',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ChartCard(
              title: title,
              headerIcon: icon,
              values: values,
              labels: List.generate(values.length, (i) => 'M${i + 1}'),
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