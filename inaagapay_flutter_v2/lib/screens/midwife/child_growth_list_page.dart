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
    required double heightZ,
    required double weightZ,
    required double bmiZ,
  }) {
    final recordsSummary = records.map((record) {
      final weightVal = (record['child_weight'] as num?)?.toDouble() ?? 0;
      final heightVal = (record['child_height'] as num?)?.toDouble() ?? 0;
      final bmiVal = _calculateBMI(heightVal, weightVal);
      final weeks = _ageInWeeks(DateTime.parse(record['created_at']));
      return '- Week $weeks: ${heightVal.toStringAsFixed(1)} cm, ${weightVal.toStringAsFixed(1)} kg, BMI ${bmiVal.toStringAsFixed(1)}';
    }).join('\n');

    return '''
You are a pediatric growth analyst.
Provide output in the exact structured format below using markdown headings and bullet points only. Do not add extra sections or narrative.

Child: $childName
Sex: ${sex.toLowerCase()}
Current age: $ageWeeks weeks

Latest measurements:
Height: ${height.toStringAsFixed(1)} cm
Weight: ${weight.toStringAsFixed(1)} kg
BMI: ${bmi.toStringAsFixed(1)}

Z-scores:
Height z-score: ${heightZ.toStringAsFixed(2)}
Weight z-score: ${weightZ.toStringAsFixed(2)}
BMI z-score: ${bmiZ.toStringAsFixed(2)}

Growth history:
$recordsSummary

Output format:

## SUMMARY
- One clear sentence describing the overall growth status.

## KEY FINDINGS
- Height: ...
- Weight: ...
- BMI: ...

## Z-SCORE REVIEW
- Height z-score: ...
- Weight z-score: ...
- BMI z-score: ...

## TABLE
| Metric | Current | Status | Note |
|---|---|---|---|
| Height | ... | ... | ... |
| Weight | ... | ... | ... |
| BMI | ... | ... | ... |

## RECOMMENDATIONS
- Practical advice for the caregiver or midwife.

Keep language concise, professional, and supportive. Do not provide a medical diagnosis.
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

  String _formatZScore(double zscore) {
    if (zscore.isNaN || zscore.isInfinite) return 'n/a';
    return zscore.toStringAsFixed(2);
  }

  String _describeZScore(double zscore) {
    if (zscore.isNaN || zscore.isInfinite) return 'No z-score available';
    if (zscore < -2) return 'Below expected range';
    if (zscore < -1) return 'Slightly below expected';
    if (zscore <= 1) return 'Within expected range';
    if (zscore <= 2) return 'Slightly above expected';
    return 'Above expected range';
  }

  Color _getZScoreColor(double zscore) {
    if (zscore.isNaN || zscore.isInfinite) return AppColors.textSecondary;
    if (zscore < -2 || zscore > 2) return AppColors.error;
    if (zscore < -1 || zscore > 1) return AppColors.warning;
    return AppColors.success;
  }

  List<double> _getChartValues(String metric) {
    return records.map((record) {
      switch (metric) {
        case 'height':
          return (record['child_height'] as num?)?.toDouble() ?? 0;
        case 'weight':
          return (record['child_weight'] as num?)?.toDouble() ?? 0;
        case 'bmi':
          final h = (record['child_height'] as num?)?.toDouble() ?? 0;
          final w = (record['child_weight'] as num?)?.toDouble() ?? 0;
          return _calculateBMI(h, w);
        default:
          return 0.0;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final heightZ = GrowthCalculator.calculateHeightZScore(
        latestHeight, latestAgeWeeks, childSex);
    final weightZ = GrowthCalculator.calculateWeightZScore(
        latestWeight, latestAgeWeeks, childSex);
    final bmiZ = GrowthCalculator.calculateBMIZScore(
        latestBMI, latestAgeWeeks, childSex);

    final chartLabels = records.map((record) {
      final weeks = _ageInWeeks(DateTime.parse(record['created_at']));
      return 'W$weeks';
    }).toList();

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
                          chartLabels: chartLabels,
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
    required double heightZ,
    required double weightZ,
    required double bmiZ,
    required List<String> chartLabels,
  }) {
    final heightValues = _getChartValues('height');
    final weightValues = _getChartValues('weight');
    final bmiValues = _getChartValues('bmi');

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
        if (activeTab == 0 && bmiValues.isNotEmpty)
          ChartCard(
            title: 'BMI History',
            lineColor: AppColors.brandSecondary,
            values: bmiValues,
            labels: chartLabels,
            unit: 'kg/m²',
            startingLabel: 'First',
            startingValue: bmiValues.first.toStringAsFixed(1),
            latestLabel: 'Latest',
            latestValue: latestBMI > 0 ? latestBMI.toStringAsFixed(1) : 'n/a',
            insightText: 'BMI trend indicates body composition changes.',
          ),
        if (activeTab == 1 && weightValues.isNotEmpty)
          ChartCard(
            title: 'Weight History',
            lineColor: AppColors.brandAccent,
            values: weightValues,
            labels: chartLabels,
            unit: 'kg',
            startingLabel: 'First',
            startingValue: '${weightValues.first.toStringAsFixed(1)} kg',
            latestLabel: 'Latest',
            latestValue: '${latestWeight.toStringAsFixed(1)} kg',
            insightText:
                'Weight tracking provides insight into nutritional status.',
          ),
        if (activeTab == 2 && heightValues.isNotEmpty)
          ChartCard(
            title: 'Height History',
            lineColor: AppColors.brandPrimary,
            values: heightValues,
            labels: chartLabels,
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
    required double zScore,
    required IconData icon,
    required Color color,
    required bool show,
  }) {
    if (!show) return const SizedBox.shrink();

    final zScoreColor = _getZScoreColor(zScore);
    final zScoreDesc = _describeZScore(zScore);

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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: zScoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Z-score',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: zScoreColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatZScore(zScore),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: zScoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
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
        ...records.reversed.map((record) {
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
      ],
    );
  }
}

class GrowthRecordCard extends StatelessWidget {
  final double height;
  final double weight;
  final String date;
  final int weekNumber;
  final bool isLatest;

  const GrowthRecordCard({
    super.key,
    required this.height,
    required this.weight,
    required this.date,
    required this.weekNumber,
    this.isLatest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLatest
            ? Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Week $weekNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Latest',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMeasurementItem(
                  'Height',
                  '${height.toStringAsFixed(1)} cm',
                  Icons.height,
                  AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMeasurementItem(
                  'Weight',
                  '${weight.toStringAsFixed(1)} kg',
                  Icons.monitor_weight,
                  AppColors.brandAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
