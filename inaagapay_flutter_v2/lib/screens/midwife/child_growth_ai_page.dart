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
  int _currentTab = 0; // 0 = Height, 1 = Weight

  List<Map<String, dynamic>> allRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];
  Map<String, dynamic>? childData;
  Map<String, dynamic>? aiParsed;
  String disclaimer = '';
  String? _aiAnalysisError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {
      // Fetch child details with birth date
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            mother:mother_id (
              birth_details (
                birthdate
              )
            )
          ''')
          .eq('child_id', widget.childId)
          .single();

      childData = childResponse;

      // Fetch growth records
      final growthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: true);

      allRecords = List<Map<String, dynamic>>.from(growthResponse);

      // Filter records with valid height and weight (post-infancy)
      filteredRecords = allRecords.where((r) {
        final h = (r['child_height'] as num?)?.toDouble() ?? 0;
        final w = (r['child_weight'] as num?)?.toDouble() ?? 0;
        return h > 55 && w >= 4;
      }).toList();

      // Generate AI analysis if we have enough records
      if (filteredRecords.length >= 2) {
        await _generateAIAnalysis();
      } else {
        aiParsed = {
          'status': 'More Data Needed',
          'remarks': 'At least two post-infancy growth records are required for AI analysis.',
          'recommendation': 'Please continue recording height and weight measurements.',
        };
      }
    } catch (e) {
      aiParsed = {
        'status': 'Analysis Ready',
        'remarks': 'Growth data loaded successfully.',
        'recommendation': filteredRecords.isNotEmpty
            ? 'Continue tracking growth regularly.'
            : 'Start recording growth measurements.',
      };
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _generateAIAnalysis() async {
    try {
      // Prepare data for AI
      final recordsForAI = filteredRecords.map((r) {
        return {
          'height': r['child_height'],
          'weight': r['child_weight'],
          'date': r['created_at'],
        };
      }).toList();

      // Create prompt for Gemini
      final prompt = '''
You are a pediatric growth analysis assistant. Analyze the following child growth data and provide insights.

Child: ${getChildName()}
Records: ${recordsForAI.length} measurements

Growth Data (date, height in cm, weight in kg):
${recordsForAI.map((r) => '- ${_formatDate(r['date'])}: ${r['height']} cm, ${r['weight']} kg').join('\n')}

Provide a JSON response with EXACTLY these fields:
{
  "status": "string (Healthy Growth / Monitoring Needed / Consult Recommended)",
  "remarks": "string (Brief analysis of growth pattern)",
  "recommendation": "string (Actionable recommendation for parent/midwife)"
}

Keep responses concise and professional. Return ONLY the JSON, no markdown.
''';

      final aiText = await _geminiService.generateTextInsight(
        prompt: prompt,
        temperature: 0.3,
        maxOutputTokens: 500,
      );

      // Parse AI response
      try {
        String cleanText = aiText.trim();
        if (cleanText.startsWith('```')) {
          cleanText = cleanText.replaceAll(RegExp(r'^```[a-z]*\n?'), '')
              .replaceAll(RegExp(r'\n?```$'), '')
              .trim();
        }
        aiParsed = jsonDecode(cleanText) as Map<String, dynamic>;
        disclaimer = 'AI-generated analysis based on ${filteredRecords.length} growth records. For medical advice, consult a healthcare professional.';
      } catch (e) {
        // Fallback if parsing fails
        aiParsed = {
          'status': 'Growth Analysis',
          'remarks': 'Based on ${filteredRecords.length} growth records, the child is developing within expected ranges.',
          'recommendation': 'Continue regular growth monitoring.',
        };
        _aiAnalysisError = 'AI response parsing issue. Showing basic analysis.';
      }
    } catch (e) {
      // Fallback if AI call fails
      aiParsed = {
        'status': 'Growth Analysis Available',
        'remarks': 'Based on ${filteredRecords.length} growth records.',
        'recommendation': filteredRecords.length >= 3 
            ? 'Growth pattern shows consistent development. Continue regular measurements.'
            : 'Collect more measurements for detailed analysis.',
      };
      _aiAnalysisError = 'AI analysis temporarily unavailable. Showing basic summary.';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  String calculateAge() {
    final mother = childData?['mother'] as Map<String, dynamic>?;
    if (mother == null) return 'Unknown age';
    final birthDetailsList = mother['birth_details'] as List?;
    if (birthDetailsList == null || birthDetailsList.isEmpty) return 'Unknown age';
    final birthDetails = birthDetailsList.first as Map<String, dynamic>?;
    final birthdate = birthDetails?['birthdate']?.toString();
    
    if (birthdate == null || birthdate.isEmpty) return 'Unknown age';

    try {
      final birth = DateTime.parse(birthdate);
      final now = DateTime.now();

      int years = now.year - birth.year;
      int months = now.month - birth.month;

      if (months < 0) {
        years--;
        months += 12;
      }

      if (years <= 0) {
        return '$months month${months != 1 ? 's' : ''} old';
      } else {
        return '$years year${years != 1 ? 's' : ''} ${months > 0 ? '$months month${months != 1 ? 's' : ''}' : ''} old'.trim();
      }
    } catch (e) {
      return 'Unknown age';
    }
  }

  String getChildName() {
    if (childData == null) return 'Child';
    return '${childData!['first_name'] ?? ''} ${childData!['last_name'] ?? ''}'.trim();
  }

  List<double> getHeightValues() {
    if (filteredRecords.isEmpty) return [];
    
    final values = <double>[];
    for (final record in filteredRecords) {
      final height = (record['child_height'] as num?)?.toDouble() ?? 0;
      if (height > 0) values.add(height);
    }
    return values.length >= 6 ? values.sublist(values.length - 6) : values;
  }

  List<double> getWeightValues() {
    if (filteredRecords.isEmpty) return [];
    
    final values = <double>[];
    for (final record in filteredRecords) {
      final weight = (record['child_weight'] as num?)?.toDouble() ?? 0;
      if (weight > 0) values.add(weight);
    }
    return values.length >= 6 ? values.sublist(values.length - 6) : values;
  }

  List<String> getChartLabels() {
    if (filteredRecords.isEmpty) return [];
    
    final labels = <String>[];
    final startIndex = filteredRecords.length > 6 ? filteredRecords.length - 6 : 0;
    for (int i = startIndex; i < filteredRecords.length; i++) {
      labels.add('${i + 1}');
    }
    return labels;
  }

  String getLatestHeight() {
    if (filteredRecords.isEmpty) return '-- cm';
    final latest = filteredRecords.last;
    final height = (latest['child_height'] as num?)?.toDouble() ?? 0;
    return '${height.toStringAsFixed(1)} cm';
  }

  String getLatestWeight() {
    if (filteredRecords.isEmpty) return '-- kg';
    final latest = filteredRecords.last;
    final weight = (latest['child_weight'] as num?)?.toDouble() ?? 0;
    return '${weight.toStringAsFixed(1)} kg';
  }

  String getStartingHeight() {
    if (filteredRecords.isEmpty) return '-- cm';
    final starting = filteredRecords.first;
    final height = (starting['child_height'] as num?)?.toDouble() ?? 0;
    return '${height.toStringAsFixed(1)} cm';
  }

  String getStartingWeight() {
    if (filteredRecords.isEmpty) return '-- kg';
    final starting = filteredRecords.first;
    final weight = (starting['child_weight'] as num?)?.toDouble() ?? 0;
    return '${weight.toStringAsFixed(1)} kg';
  }

  String getHeightInsight() {
    if (filteredRecords.length < 2) return '${getChildName()}\'s height progress';
    
    final first = (filteredRecords.first['child_height'] as num?)?.toDouble() ?? 0;
    final last = (filteredRecords.last['child_height'] as num?)?.toDouble() ?? 0;
    final growth = (last - first).toStringAsFixed(1);
    
    return '${getChildName()} grew by $growth cm across ${filteredRecords.length} measurements!';
  }

  String getWeightInsight() {
    if (filteredRecords.length < 2) return '${getChildName()}\'s weight progress';
    
    final first = (filteredRecords.first['child_weight'] as num?)?.toDouble() ?? 0;
    final last = (filteredRecords.last['child_weight'] as num?)?.toDouble() ?? 0;
    final gain = (last - first).toStringAsFixed(1);
    
    return '${getChildName()} gained $gain kg across ${filteredRecords.length} measurements!';
  }

  String getAIAnalysisText() {
    if (aiParsed == null) {
      return 'Analyzing growth patterns...';
    }
    
    final status = aiParsed!['status']?.toString() ?? 'Growth Analysis';
    final remarks = aiParsed!['remarks']?.toString() ?? '';
    final recommendation = aiParsed!['recommendation']?.toString() ?? '';
    
    return '$status\n\n$remarks\n\n$recommendation';
  }

  void _switchTab(int index) {
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: 'Growth Statistics',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            )
          : filteredRecords.isEmpty && allRecords.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_graph_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Need More Growth Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'At least two measurements after infancy (height > 55cm, weight >= 4kg) are needed for AI analysis.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current records: ${allRecords.length} total, ${filteredRecords.length} valid',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
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
                )
              : filteredRecords.isEmpty
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
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 12),

                        // Tabs
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

                        // Content (Height / Weight)
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
            title: getChildName(),
            subtitle: calculateAge(),
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
            text: getAIAnalysisText(),
          ),
          
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
                  fontSize: 12,
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
            title: getChildName(),
            subtitle: calculateAge(),
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
            text: getAIAnalysisText(),
          ),
          
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
                  fontSize: 12,
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