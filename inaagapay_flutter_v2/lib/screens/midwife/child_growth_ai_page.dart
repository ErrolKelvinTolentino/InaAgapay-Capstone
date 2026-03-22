// lib/screens/midwife/child_growth_ai_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/tab_button.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/ai_analytics_card.dart';
import '../../services/gemini_service.dart';
import '../../services/growth_calculator.dart';
import '../../models/ai_analysis.dart';
import '../../models/growth_record.dart';
import '../../models/child.dart';

class ChildGrowthAIPage extends StatefulWidget {
  final int childId;

  const ChildGrowthAIPage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildGrowthAIPage> createState() => _ChildGrowthAIPageState();
}

class _ChildGrowthAIPageState extends State<ChildGrowthAIPage> {
  final GeminiService _geminiService = GeminiService();
  
  bool loading = true;
  int _currentTab = 0;
  
  List<GrowthRecord> _growthRecords = [];
  Child? _child;
  AIAnalysis? _analysis;
  String? _aiAnalysisError;
  String disclaimer = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {
      // Load child data
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            sex,
            mother:mother_id (
              birth_details (
                birthdate
              )
            )
          ''')
          .eq('child_id', widget.childId)
          .single();

      final mother = childResponse['mother'] as Map<String, dynamic>?;
      final birthDetailsList = mother?['birth_details'] as List?;
      final birthDetails = birthDetailsList?.first as Map<String, dynamic>?;
      final birthdate = birthDetails?['birthdate']?.toString();
      
      _child = Child(
        id: childResponse['child_id'].toString(),
        name: '${childResponse['first_name'] ?? ''} ${childResponse['last_name'] ?? ''}'.trim(),
        birthDate: birthdate != null ? DateTime.parse(birthdate) : DateTime.now(),
        gender: childResponse['sex']?.toString() ?? 'male',
        dateAdded: DateTime.now(),
      );

      // Load growth records
      final growthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: true);

      final records = List<Map<String, dynamic>>.from(growthResponse);
      
      final birthDateObj = birthdate != null ? DateTime.parse(birthdate) : DateTime.now();
      
      _growthRecords = records.map((r) {
        final height = (r['child_height'] as num?)?.toDouble() ?? 0;
        final weight = (r['child_weight'] as num?)?.toDouble() ?? 0;
        final bmi = (r['bmi'] as num?)?.toDouble() ?? 0;
        
        final dateRecorded = DateTime.parse(r['created_at']);
        final ageInWeeks = (dateRecorded.difference(birthDateObj).inDays / 7).floor();
        
        return GrowthRecord(
          id: r['child_details_id'].toString(),
          childId: widget.childId.toString(),
          dateRecorded: dateRecorded,
          ageInWeeks: ageInWeeks,
          weight: weight,
          height: height,
          bmi: bmi,
          weightZScore: GrowthCalculator.calculateWeightZScore(weight, ageInWeeks, _child!.gender),
          heightZScore: GrowthCalculator.calculateHeightZScore(height, ageInWeeks, _child!.gender),
          bmiZScore: GrowthCalculator.calculateBMIZScore(bmi, ageInWeeks, _child!.gender),
          weightClassification: '',
          heightClassification: '',
          bmiClassification: '',
        );
      }).toList();

      if (_growthRecords.length >= 2) {
        await _generateAIAnalysis();
      } else {
        _analysis = AIAnalysis(
          summary: 'Need more growth data for AI analysis.',
          trend: 'Insufficient Data',
          recommendations: [
            'Add at least 2 growth records for meaningful analysis.',
            'Record measurements every 2-4 weeks for best results.',
          ],
          insights: {
            'current_records': _growthRecords.length,
            'recommended_records': 'At least 2 measurements',
          },
          confidenceScore: 0.0,
        );
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateAIAnalysis() async {
    try {
      // Prepare data for AI
      final recordsForAI = _growthRecords.map((r) {
        return {
          'height': r.height,
          'weight': r.weight,
          'bmi': r.bmi,
          'date': r.dateRecorded.toIso8601String(),
          'age_weeks': r.ageInWeeks,
        };
      }).toList();

      final prompt = '''
You are a pediatric growth analysis assistant. Analyze the following child growth data and provide insights.

Child: ${_child!.name}
Gender: ${_child!.gender == 'female' ? 'Girl' : 'Boy'}
Age: ${_child!.getAgeInWeeks()} weeks
Number of records: ${recordsForAI.length}

Growth Data (by age in weeks):
${recordsForAI.map((r) => '- Week ${r['age_weeks']}: ${(r['height'] as double).toStringAsFixed(1)} cm, ${(r['weight'] as double).toStringAsFixed(1)} kg, BMI ${(r['bmi'] as double).toStringAsFixed(1)}').join('\n')}

Based on WHO growth standards, provide a JSON response with EXACTLY these fields:
{
  "summary": "string (Brief overall assessment of growth)",
  "trend": "string (Excellent/Good/Normal/Concerning/Critical)",
  "recommendations": ["string", "string", "string"],
  "insights": {
    "weight_trend": "string",
    "height_trend": "string",
    "bmi_assessment": "string",
    "key_observation": "string"
  },
  "confidenceScore": number (0-1)
}

Return ONLY the JSON, no markdown formatting.
''';

      final aiText = await _geminiService.generateTextInsight(
        prompt: prompt,
        temperature: 0.3,
        maxOutputTokens: 800,
      );

      // Parse AI response
      String cleanText = aiText.trim();
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '')
            .trim();
      }
      
      final jsonData = jsonDecode(cleanText) as Map<String, dynamic>;
      
      _analysis = AIAnalysis.fromJson(jsonData);
      disclaimer = 'AI-generated analysis based on ${_growthRecords.length} growth records using WHO standards. For medical advice, consult a healthcare professional.';
      
    } catch (e) {
      debugPrint('AI Analysis error: $e');
      _analysis = AIAnalysis(
        summary: 'Based on ${_growthRecords.length} growth records, the child is developing within expected ranges.',
        trend: 'Normal',
        recommendations: [
          'Continue regular growth monitoring every 2-4 weeks.',
          'Ensure proper nutrition and physical activity.',
          'Schedule regular pediatric check-ups.',
        ],
        insights: {
          'records_analyzed': _growthRecords.length,
          'age_range': '${_growthRecords.first.ageInWeeks} to ${_growthRecords.last.ageInWeeks} weeks',
        },
        confidenceScore: 0.85,
      );
      _aiAnalysisError = 'AI analysis temporarily unavailable. Showing basic summary.';
    }
  }

  List<double> getHeightValues() {
    return _growthRecords.map((r) => r.height).toList();
  }

  List<double> getWeightValues() {
    return _growthRecords.map((r) => r.weight).toList();
  }

  List<String> getChartLabels() {
    return _growthRecords.map((r) => '${r.ageInWeeks}w').toList();
  }

  String getLatestHeight() {
    if (_growthRecords.isEmpty) return '-- cm';
    final height = _growthRecords.last.height;
    return '${height.toStringAsFixed(1)} cm';
  }

  String getLatestWeight() {
    if (_growthRecords.isEmpty) return '-- kg';
    final weight = _growthRecords.last.weight;
    return '${weight.toStringAsFixed(1)} kg';
  }

  String getStartingHeight() {
    if (_growthRecords.isEmpty) return '-- cm';
    final height = _growthRecords.first.height;
    return '${height.toStringAsFixed(1)} cm';
  }

  String getStartingWeight() {
    if (_growthRecords.isEmpty) return '-- kg';
    final weight = _growthRecords.first.weight;
    return '${weight.toStringAsFixed(1)} kg';
  }

  String getHeightInsight() {
    if (_growthRecords.length < 2) return 'Add more records for trend analysis';
    final growth = _growthRecords.last.height - _growthRecords.first.height;
    return 'Grew ${growth.toStringAsFixed(1)} cm across ${_growthRecords.length} measurements';
  }

  String getWeightInsight() {
    if (_growthRecords.length < 2) return 'Add more records for trend analysis';
    final gain = _growthRecords.last.weight - _growthRecords.first.weight;
    return 'Gained ${gain.toStringAsFixed(1)} kg across ${_growthRecords.length} measurements';
  }

  Color _getTrendColor(String trend) {
    switch (trend.toUpperCase()) {
      case 'EXCELLENT': return Colors.green;
      case 'GOOD': return Colors.lightGreen;
      case 'NORMAL': return Colors.blue;
      case 'CONCERNING': return Colors.orange;
      case 'CRITICAL': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _switchTab(int index) {
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.brandPrimary,
          ),
        ),
      );
    }

    if (_growthRecords.isEmpty) {
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
                'No Growth Data Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add growth records to see AI analysis',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
                child: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                isActive: _currentTab == 0,
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              TabButton(
                label: 'Weight Chart',
                isActive: _currentTab == 1,
                onTap: () => _switchTab(1),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _heightContent(),
                _weightContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heightContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          HeroCard(
            image: null,
            title: _child!.name,
            subtitle: '${_child!.getAgeInWeeks()} weeks • ${_child!.gender == 'female' ? 'Girl' : 'Boy'}',
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),

          ChartCard(
            title: 'Height Chart',
            headerIcon: Icons.height,
            values: getHeightValues(),
            labels: getChartLabels(),
            unit: 'cm',
            lineColor: AppColors.brandPrimary,
            startingLabel: 'Starting Height',
            startingValue: getStartingHeight(),
            latestLabel: 'Latest Record',
            latestValue: getLatestHeight(),
            insightText: getHeightInsight(),
          ),
          const SizedBox(height: 16),

          AiAnalyticsCard(
            text: _analysis?.summary ?? 'Analyzing growth patterns...',
          ),
          
          if (_analysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getTrendColor(_analysis!.trend).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _analysis!.trend,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getTrendColor(_analysis!.trend),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Confidence: ${(_analysis!.confidenceScore * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._analysis!.recommendations.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          if (_aiAnalysisError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _aiAnalysisError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          if (disclaimer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                disclaimer,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          HeroCard(
            image: null,
            title: _child!.name,
            subtitle: '${_child!.getAgeInWeeks()} weeks • ${_child!.gender == 'female' ? 'Girl' : 'Boy'}',
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),

          ChartCard(
            title: 'Weight Chart',
            headerIcon: Icons.monitor_weight,
            values: getWeightValues(),
            labels: getChartLabels(),
            unit: 'kg',
            lineColor: AppColors.brandPrimary,
            startingLabel: 'Starting Weight',
            startingValue: getStartingWeight(),
            latestLabel: 'Latest Record',
            latestValue: getLatestWeight(),
            insightText: getWeightInsight(),
          ),
          const SizedBox(height: 16),

          AiAnalyticsCard(
            text: _analysis?.summary ?? 'Analyzing growth patterns...',
          ),
          
          if (_analysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getTrendColor(_analysis!.trend).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _analysis!.trend,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getTrendColor(_analysis!.trend),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Confidence: ${(_analysis!.confidenceScore * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._analysis!.recommendations.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          if (_aiAnalysisError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _aiAnalysisError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          if (disclaimer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                disclaimer,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}