// lib/screens/mother/mother_child_growth.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/tab_button.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/ai_analytics_card.dart';
import '../../services/child_service.dart';
import '../../services/language_service.dart';

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

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  String _genderLabel() {
    return widget.childGender == 'female' ? _t('Girl', 'Babae') : _t('Boy', 'Lalaki');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: _t('Growth Statistics', 'Growth Statistics'),
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
                          child: Text(_t('Retry', 'Subukan Muli')),
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
                            Text(
                              _t('Not Enough Data', 'Kulang ang Datos'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t(
                                'Need at least 2 growth records to display charts.\nCurrent records: ${_growthData?['records_count'] ?? 0}',
                                'Kailangan ng hindi bababa sa 2 growth records para maipakita ang charts.\nKasalukuyang records: ${_growthData?['records_count'] ?? 0}',
                              ),
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
                                label: _t('Height Chart', 'Chart ng Taas'),
                                isActive: _currentIndex == 0,
                                onTap: () => setState(() => _currentIndex = 0),
                              ),
                              const SizedBox(width: 12),
                              TabButton(
                                label: _t('Weight Chart', 'Chart ng Timbang'),
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
      },
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
            subtitle: '${widget.childAge} • ${_genderLabel()}',
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: title == 'Height Chart'
                ? _t('Height Chart', 'Chart ng Taas')
                : _t('Weight Chart', 'Chart ng Timbang'),
            headerIcon: icon,
            values: values,
            labels: labels,
            unit: unit,
            lineColor: AppColors.brandPrimary,
            startingLabel: _t('Starting', 'Simula'),
            startingValue: start != null ? '$start $unit' : '--',
            latestLabel: _t('Latest', 'Pinakabago'),
            latestValue: latest != null ? '$latest $unit' : '--',
            insightText: gain != null
                ? '${widget.childName} ${title.contains('Height') ? _t('grew', 'tumaas ng') : _t('gained', 'nadagdagan ng')} $gain $unit!'
                : _t('Add more records for trend analysis',
                    'Magdagdag pa ng records para sa trend analysis'),
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
      return _t(
          'No growth data available yet. Add growth records to see AI analysis.',
          'Wala pang growth data. Magdagdag ng growth records para makita ang AI analysis.');
    }
    
    if (values.length < 2) {
      return _t(
          'Need at least 2 measurements for trend analysis. Current: ${values.length} record(s).',
          'Kailangan ng hindi bababa sa 2 sukat para sa trend analysis. Kasalukuyan: ${values.length} record(s).');
    }
    
    final first = values.first;
    final last = values.last;
    final change = last - first;
    final percentChange = (change / first * 100).abs();
    
    if (unit == 'cm') {
      if (change > 5) {
        return _t(
            '$childName has shown excellent height growth of ${change.toStringAsFixed(1)} cm (${percentChange.toStringAsFixed(0)}% increase). This indicates healthy physical development.',
            'Nagpakita si $childName ng mahusay na paglaki sa taas na ${change.toStringAsFixed(1)} cm (${percentChange.toStringAsFixed(0)}% pagtaas). Ipinapakita nito ang malusog na pisikal na pag-unlad.');
      } else if (change > 2) {
        return _t(
            '$childName is showing steady height growth of ${change.toStringAsFixed(1)} cm. Growth is progressing within expected ranges.',
            'Patuloy ang paglaki ng taas ni $childName ng ${change.toStringAsFixed(1)} cm. Nasa inaasahang saklaw ang paglaki.');
      } else {
        return _t(
            '$childName\'s height growth has been minimal (${change.toStringAsFixed(1)} cm). Continue monitoring and ensure proper nutrition.',
            'Kaunti lang ang paglaki ng taas ni $childName (${change.toStringAsFixed(1)} cm). Ipagpatuloy ang pagsubaybay at siguraduhin ang tamang nutrisyon.');
      }
    } else {
      if (change > 2) {
        return _t(
            '$childName has gained ${change.toStringAsFixed(1)} kg (${percentChange.toStringAsFixed(0)}% increase). Weight gain is appropriate for age.',
            'Nadagdagan ang timbang ni $childName ng ${change.toStringAsFixed(1)} kg (${percentChange.toStringAsFixed(0)}% pagtaas). Ang pagdagdag ng timbang ay angkop sa edad.');
      } else if (change > 0.5) {
        return _t(
            '$childName is maintaining steady weight gain of ${change.toStringAsFixed(1)} kg. Continue regular monitoring.',
            'Patuloy ang pagdagdag ng timbang ni $childName ng ${change.toStringAsFixed(1)} kg. Ipagpatuloy ang regular na pagsubaybay.');
      } else {
        return _t(
            '$childName\'s weight gain has been minimal (${change.toStringAsFixed(1)} kg). Consult healthcare provider if concerned.',
            'Kaunti lang ang pagdagdag ng timbang ni $childName (${change.toStringAsFixed(1)} kg). Kumonsulta sa healthcare provider kung may alalahanin.');
      }
    }
  }
}
