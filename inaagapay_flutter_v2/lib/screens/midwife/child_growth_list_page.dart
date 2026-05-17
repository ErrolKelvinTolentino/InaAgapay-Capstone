// lib/screens/midwife/child_growth_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/growth_calculator.dart';
import '../../services/groq_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_analytics_card.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';
import 'growth_history_screen.dart';
import '../../widgets/growth_record_card.dart';

class ChildGrowthListPage extends StatefulWidget {
  final int childId;

  const ChildGrowthListPage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildGrowthListPage> createState() => _ChildGrowthListPageState();
}

class _ChildGrowthListPageState extends State<ChildGrowthListPage> {
  bool loading = true;
  bool aiLoading = false;
  String? aiAnalysis;
  String? aiError;
  int activeTab = 0;
  List<Map<String, dynamic>> records = [];
  Map<String, dynamic>? childData;
  DateTime? birthdate;

  final GroqService _groqService = GroqService();

  // Computed properties for latest measurements
  Map<String, dynamic>? get latestRecord =>
      records.isNotEmpty ? records.last : null;

  double get latestHeight =>
      (latestRecord?['child_height'] as num?)?.toDouble() ?? 0;

  double get latestWeight =>
      (latestRecord?['child_weight'] as num?)?.toDouble() ?? 0;

  double get latestBMI => _calculateBMI(latestHeight, latestWeight);

  int get latestAgeWeeks => latestRecord != null
      ? _ageInWeeks(DateTime.parse(latestRecord!['created_at']))
      : 0;

  String get childSex => (childData?['sex'] as String?) ?? 'female';

  @override
  void initState() {
    super.initState();
    fetchGrowthRecords();
  }

  Future<void> fetchGrowthRecords() async {
    setState(() {
      loading = true;
      aiError = null;
    });

    try {
      await Future.wait([
        _fetchChildData(),
        _fetchBirthDetails(),
        _fetchGrowthRecords(),
      ]);

      if (records.isNotEmpty && birthdate != null) {
        final latest = latestRecord;
        final latestId = (latest?['child_details_id'] as int?) ?? 0;

        if (latestId > 0) {
          final saved = await _fetchSavedGrowthAnalysis(latestId);
          if (saved != null &&
              saved['response'] != null &&
              saved['response'].toString().isNotEmpty) {
            aiAnalysis = saved['response'].toString();
          } else {
            await _generateAndSaveAIAnalysis(latestId);
          }
        } else {
          aiAnalysis =
              'Cannot generate AI growth summary because the latest record ID is unavailable.';
        }
      } else {
        aiAnalysis = 'Not enough growth data yet to generate an AI summary.';
      }
    } catch (e) {
      debugPrint('Error loading growth records: $e');
      if (mounted) {
        setState(() {
          aiError = e.toString();
          aiAnalysis = 'Unable to load growth data. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading growth records: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _fetchChildData() async {
    final response = await Supabase.instance.client
        .from('children')
        .select('child_id, first_name, last_name, sex')
        .eq('child_id', widget.childId)
        .single();
    childData = response;
  }

  Future<void> _fetchBirthDetails() async {
    final response = await Supabase.instance.client
        .from('birth_details')
        .select('birthdate')
        .eq('child_id', widget.childId)
        .maybeSingle();

    if (response != null && response['birthdate'] != null) {
      birthdate = DateTime.parse(response['birthdate']);
    }
  }

  Future<void> _fetchGrowthRecords() async {
    final response = await Supabase.instance.client
        .from('child_details')
        .select('*')
        .eq('child_id', widget.childId)
        .order('created_at', ascending: true);

    records = List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> _fetchSavedGrowthAnalysis(
      int childDetailsId) async {
    return await Supabase.instance.client
        .from('ai_responses')
        .select('*')
        .eq('reference_table', 'child_details')
        .eq('reference_id', childDetailsId)
        .eq('response_type', 'growth_analysis')
        .maybeSingle();
  }

  Future<void> _generateAndSaveAIAnalysis(int latestRecordId) async {
    if (records.isEmpty || birthdate == null || childData == null) return;
    if (latestRecordId <= 0) return;

    setState(() => aiLoading = true);

    try {
      final heightZ = GrowthCalculator.calculateHeightZScore(
          latestHeight, latestAgeWeeks, childSex);
      final weightZ = GrowthCalculator.calculateWeightZScore(
          latestWeight, latestAgeWeeks, childSex);
      final bmiZ = GrowthCalculator.calculateBMIZScore(
          latestBMI, latestAgeWeeks, childSex);

      final prompt = _buildGrowthAiPrompt(
        childName: getChildName(),
        sex: childSex,
        ageWeeks: latestAgeWeeks,
        height: latestHeight,
        weight: latestWeight,
        bmi: latestBMI,
        heightZ: heightZ,
        weightZ: weightZ,
        bmiZ: bmiZ,
      );

      final generated = await _groqService.generateTextInsight(
        prompt: prompt,
        temperature: 0.2,
        maxOutputTokens: 512,
      );

      final analysis = generated.trim();
      if (mounted) {
        setState(() => aiAnalysis = analysis);
      }
      await _saveAIResponse(analysis, latestRecordId);
    } catch (e) {
      debugPrint('Error generating AI analysis: $e');
      if (mounted) {
        setState(() {
          aiError = 'AI analysis unavailable';
          aiAnalysis = 'AI analysis could not be generated right now.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => aiLoading = false);
      }
    }
  }

  String _buildGrowthAiPrompt({
    required String childName,
    required String sex,
    required int ageWeeks,
    required double height,
    required double weight,
    required double bmi,
    required double? heightZ,
    required double? weightZ,
    required double? bmiZ,
  }) {
    final recordsSummary = records.map((record) {
      final weightVal = (record['child_weight'] as num?)?.toDouble() ?? 0;
      final heightVal = (record['child_height'] as num?)?.toDouble() ?? 0;
      final bmiVal = _calculateBMI(heightVal, weightVal);
      final weeks = _ageInWeeks(DateTime.parse(record['created_at']));
      return '- Week $weeks: ${heightVal.toStringAsFixed(1)} cm, ${weightVal.toStringAsFixed(1)} kg, BMI ${bmiVal.toStringAsFixed(1)}';
    }).join('\n');

    return '''
You are a warm, caring assistant writing a short growth update for a parent.
Use the exact output format below with markdown headings and bullet points only. Do not add extra sections or tables.

Child: $childName
Sex: ${sex.toLowerCase()}
Current age: $ageWeeks weeks

Latest measurements:
Height: ${height.toStringAsFixed(1)} cm
Weight: ${weight.toStringAsFixed(1)} kg

Recent growth:
$recordsSummary

Output format:

## Baby Growth Summary
- A short, gentle explanation of how the child is growing.

### Current Measurements
- Length: ${height.toStringAsFixed(1)} cm
- Weight: ${weight.toStringAsFixed(1)} kg

### What This Means
- ...
- ...

### Helpful Note
- ...

Use calm, supportive wording. Keep it simple and easy to understand. Do not use technical terms such as z-scores, percentiles, or clinical indicators. Avoid alarm and focus on what the measurements mean for daily care and follow-up.
''';
  }

  Future<void> _saveAIResponse(String responseText, int childDetailsId) async {
    try {
      final existing = await Supabase.instance.client
          .from('ai_responses')
          .select('ai_response_id')
          .eq('reference_table', 'child_details')
          .eq('reference_id', childDetailsId)
          .eq('response_type', 'growth_analysis')
          .maybeSingle();

      final values = {
        'reference_table': 'child_details',
        'reference_id': childDetailsId,
        'response_type': 'growth_analysis',
        'response_category': 'growth',
        'generated_by_ai': true,
        'ai_model': 'groq',
        'status': 'generated',
        'response': responseText,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['ai_response_id'] != null) {
        await Supabase.instance.client
            .from('ai_responses')
            .update(values)
            .eq('ai_response_id', existing['ai_response_id']);
      } else {
        values['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('ai_responses').insert(values);
      }
    } catch (e) {
      debugPrint('Error saving AI response: $e');
    }
  }

  String getChildName() {
    if (childData == null) return 'Child';
    final firstName = childData!['first_name'] ?? '';
    final lastName = childData!['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String calculateAge() {
    if (birthdate == null) return 'Age unknown';

    final now = DateTime.now();
    int years = now.year - birthdate!.year;
    int months = now.month - birthdate!.month;
    int days = now.day - birthdate!.day;

    if (days < 0) {
      months -= 1;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    if (years > 0) {
      return '$years year${years != 1 ? 's' : ''}${months > 0 ? ', $months month${months != 1 ? 's' : ''}' : ''} old';
    } else if (months > 0) {
      final weekText = days > 0
          ? ', ${(days / 7).floor()} week${(days / 7).floor() != 1 ? 's' : ''}'
          : '';
      return '$months month${months != 1 ? 's' : ''}$weekText old';
    } else {
      return '$days day${days != 1 ? 's' : ''} old';
    }
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return 'No date';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  int _ageInWeeks(DateTime recordDate) {
    if (birthdate == null) return 0;
    final difference = recordDate.difference(birthdate!);
    return (difference.inDays / 7).round();
  }

  double _calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiCategoryColor(String category) {
    switch (category) {
      case 'Underweight':
        return AppColors.warning;
      case 'Normal':
        return AppColors.success;
      case 'Overweight':
        return AppColors.warning;
      case 'Obese':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _describeZScore(double? zscore) {
    if (zscore == null || zscore.isNaN || zscore.isInfinite) {
      return 'Status unavailable';
    }
    if (zscore < -2) return 'A little below the expected range for age and sex';
    if (zscore < -1) return 'A little below the expected range for age and sex';
    if (zscore <= 1) return 'Within the expected range for age and sex';
    if (zscore <= 2) return 'A little above the expected range for age and sex';
    return 'A little above the expected range for age and sex';
  }

  // FIXED: Properly filter and validate chart values
  List<double> _getChartValues(String metric) {
    final List<double> values = [];

    for (final record in records) {
      double value;
      switch (metric) {
        case 'height':
          value = (record['child_height'] as num?)?.toDouble() ?? 0;
          break;
        case 'weight':
          value = (record['child_weight'] as num?)?.toDouble() ?? 0;
          break;
        case 'bmi':
          final h = (record['child_height'] as num?)?.toDouble() ?? 0;
          final w = (record['child_weight'] as num?)?.toDouble() ?? 0;
          if (h <= 0 || w <= 0) {
            continue; // Skip invalid measurements
          }
          value = _calculateBMI(h, w);
          if (value <= 0 || value.isNaN || value.isInfinite) {
            continue; // Skip invalid BMI
          }
          break;
        default:
          continue;
      }

      if (value > 0) {
        values.add(value);
      }
    }

    return values;
  }

  // FIXED: Properly filter and validate chart labels to match values
  List<String> _getChartLabels(String metric) {
    final labels = <String>[];
    final weekCount = <String, int>{};

    for (final record in records) {
      double value;
      switch (metric) {
        case 'height':
          value = (record['child_height'] as num?)?.toDouble() ?? 0;
          break;
        case 'weight':
          value = (record['child_weight'] as num?)?.toDouble() ?? 0;
          break;
        case 'bmi':
          final h = (record['child_height'] as num?)?.toDouble() ?? 0;
          final w = (record['child_weight'] as num?)?.toDouble() ?? 0;
          if (h <= 0 || w <= 0) {
            continue; // Skip invalid measurements
          }
          value = _calculateBMI(h, w);
          if (value <= 0 || value.isNaN || value.isInfinite) {
            continue; // Skip invalid BMI
          }
          break;
        default:
          continue;
      }

      if (value <= 0) continue;

      final recordDate = DateTime.parse(record['created_at']);
      final weeks = _ageInWeeks(recordDate);
      final baseLabel = 'W$weeks';
      final count = (weekCount[baseLabel] ?? 0) + 1;
      weekCount[baseLabel] = count;

      if (count == 1) {
        labels.add(baseLabel);
      } else {
        labels.add('$baseLabel ${DateFormat('MMM d').format(recordDate)}');
      }
    }

    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final heightZ = GrowthCalculator.calculateHeightZScore(
        latestHeight, latestAgeWeeks, childSex);
    final weightZ = GrowthCalculator.calculateWeightZScore(
        latestWeight, latestAgeWeeks, childSex);
    final bmiZ = GrowthCalculator.calculateBMIZScore(
        latestBMI, latestAgeWeeks, childSex);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Growth Records',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchGrowthRecords,
          color: AppColors.brandPrimary,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: records.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(
                          heightZ: heightZ,
                          weightZ: weightZ,
                          bmiZ: bmiZ,
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.child_care,
                size: 64,
                color: AppColors.brandPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Growth Records Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Growth measurements for ${getChildName()} will appear here once recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required double? heightZ,
    required double? weightZ,
    required double? bmiZ,
  }) {
    final heightValues = _getChartValues('height');
    final heightLabels = _getChartLabels('height');
    final weightValues = _getChartValues('weight');
    final weightLabels = _getChartLabels('weight');
    final bmiValues = _getChartValues('bmi');
    final bmiLabels = _getChartLabels('bmi');

    // Debug output to verify data
    debugPrint('BMI Values: $bmiValues');
    debugPrint('BMI Labels: $bmiLabels');
    debugPrint('Height Values: $heightValues');
    debugPrint('Weight Values: $weightValues');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        HeroCard(
          image: null,
          title: getChildName(),
          subtitle: calculateAge(),
          showWeekBadge: false,
          showHeartRow: false,
        ),
        const SizedBox(height: 20),
        _buildTabBar(),
        const SizedBox(height: 20),
        _buildMetricCard(
          label: 'BMI',
          value: latestBMI > 0 ? latestBMI.toStringAsFixed(1) : 'n/a',
          zScore: bmiZ,
          bmiValue: latestBMI > 0 ? latestBMI : null,
          icon: Icons.straighten,
          color: AppColors.brandSecondary,
          show: activeTab == 0,
        ),
        _buildMetricCard(
          label: 'Weight',
          value: latestWeight > 0
              ? '${latestWeight.toStringAsFixed(1)} kg'
              : 'n/a',
          zScore: weightZ,
          icon: Icons.monitor_weight,
          color: AppColors.brandAccent,
          show: activeTab == 1,
        ),
        _buildMetricCard(
          label: 'Height',
          value: latestHeight > 0
              ? '${latestHeight.toStringAsFixed(1)} cm'
              : 'n/a',
          zScore: heightZ,
          icon: Icons.height,
          color: AppColors.brandPrimary,
          show: activeTab == 2,
        ),
        // FIXED: BMI Chart - Added check for both values and labels length match
        if (activeTab == 0 &&
            bmiValues.isNotEmpty &&
            bmiLabels.isNotEmpty &&
            bmiValues.length == bmiLabels.length)
          ChartCard(
            title: 'BMI History',
            lineColor: AppColors.brandPrimary,
            values: bmiValues,
            labels: bmiLabels,
            unit: 'kg/m²',
            startingLabel: 'First',
            startingValue: bmiValues.first.toStringAsFixed(1),
            latestLabel: 'Latest',
            latestValue: latestBMI > 0 ? latestBMI.toStringAsFixed(1) : 'n/a',
            insightText: 'BMI trend indicates body composition changes.',
          ),
        if (activeTab == 1 &&
            weightValues.isNotEmpty &&
            weightLabels.isNotEmpty &&
            weightValues.length == weightLabels.length)
          ChartCard(
            title: 'Weight History',
            lineColor: AppColors.brandAccent,
            values: weightValues,
            labels: weightLabels,
            unit: 'kg',
            startingLabel: 'First',
            startingValue: '${weightValues.first.toStringAsFixed(1)} kg',
            latestLabel: 'Latest',
            latestValue: '${latestWeight.toStringAsFixed(1)} kg',
            insightText:
                'Weight tracking provides insight into nutritional status.',
          ),
        if (activeTab == 2 &&
            heightValues.isNotEmpty &&
            heightLabels.isNotEmpty &&
            heightValues.length == heightLabels.length)
          ChartCard(
            title: 'Height History',
            lineColor: AppColors.brandPrimary,
            values: heightValues,
            labels: heightLabels,
            unit: 'cm',
            startingLabel: 'First',
            startingValue: '${heightValues.first.toStringAsFixed(1)} cm',
            latestLabel: 'Latest',
            latestValue: '${latestHeight.toStringAsFixed(1)} cm',
            insightText:
                'Weekly height measurements showing growth pattern over time.',
          ),
        const SizedBox(height: 20),
        AiAnalyticsCard(
          isLoading: aiLoading,
          text: aiAnalysis ?? 'Generating AI growth analysis...',
        ),
        const SizedBox(height: 24),
        _buildHistorySection(),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = ['BMI', 'Weight', 'Height'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = activeTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => activeTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required double? zScore,
    double? bmiValue,
    required IconData icon,
    required Color color,
    required bool show,
  }) {
    if (!show) return const SizedBox.shrink();

    final zScoreDesc = _describeZScore(zScore);
    final bmiCategory =
        label == 'BMI' && bmiValue != null ? _bmiCategory(bmiValue) : null;
    final bmiCategoryColor =
        bmiCategory != null ? _bmiCategoryColor(bmiCategory) : null;

    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  '$label Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (bmiCategory != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bmiCategoryColor!.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    bmiCategory,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: bmiCategoryColor,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      zScoreDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This is a guide, not a diagnosis. Mild differences may be normal.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final previewRecords = records.reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.history,
                color: AppColors.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Growth History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${records.length} record${records.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (previewRecords.isEmpty)
          Center(
            child: Text(
              'No growth measurements available yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...previewRecords.map((record) {
            final height = (record['child_height'] as num?)?.toDouble() ?? 0;
            final weight = (record['child_weight'] as num?)?.toDouble() ?? 0;
            final date = record['created_at']?.toString() ?? '';
            final weeks = _ageInWeeks(DateTime.parse(date));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GrowthRecordCard(
                height: height,
                weight: weight,
                date: formatDate(date),
                weekNumber: weeks,
                isLatest: record == records.last,
              ),
            );
          }),
        if (records.length > 3) ...[
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GrowthHistoryScreen(
                      records: records,
                      birthdate: birthdate,
                    ),
                  ),
                );
              },
              child: const Text(
                'View Growth Records',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
