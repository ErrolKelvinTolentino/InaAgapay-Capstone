// lib/screens/mother/mother_child_growth.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/tab_button.dart';
import '../../widgets/hero_card.dart';
import '../../services/language_service.dart';
import '../../services/growth_calculator.dart';

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
  int _currentIndex = 0; // 0: BMI, 1: Height, 2: Weight
  bool _loading = true;
  String? _errorMessage;
  
  Map<String, dynamic>? _childProfile;
  DateTime? _birthdate;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchGrowthHistory();
  }

  Future<void> _fetchGrowthHistory() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch child profile
      final childRes = await Supabase.instance.client
          .from('children')
          .select('*')
          .eq('child_id', widget.childId)
          .single();

      _childProfile = childRes;

      // 2. Fetch birth details
      final birthRes = await Supabase.instance.client
          .from('birth_details')
          .select('birthdate')
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (birthRes?['birthdate'] != null) {
        _birthdate = DateTime.parse(birthRes!['birthdate'].toString());
      }

      // 3. Fetch detailed measurements
      final recordsRes = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: true);

      _records = List<Map<String, dynamic>>.from(recordsRes);

      if (mounted) {
        setState(() => _loading = false);
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

  int _ageInWeeksForDate(DateTime date) {
    if (_birthdate == null) return 0;
    final difference = date.difference(_birthdate!);
    return (difference.inDays / 7).round();
  }

  double _calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  @override
  Widget build(BuildContext context) {
    final sex = _childProfile?['sex']?.toString().toLowerCase() ?? 'female';

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: SecondaryHeader(
              title: _t('Growth Analytics', 'Pagsusuri sa Paglaki'),
              onBack: widget.onBack,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _fetchGrowthHistory,
            color: AppColors.brandPrimary,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
                : _errorMessage != null
                    ? _buildErrorView()
                    : _records.isEmpty
                        ? _buildEmptyView()
                        : Column(
                            children: [
                              const SizedBox(height: 12),
                              // 3 Tabs
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TabButton(
                                      label: _t('BMI-for-Age', 'BMI sa Edad'),
                                      isActive: _currentIndex == 0,
                                      onTap: () => setState(() => _currentIndex = 0),
                                    ),
                                    const SizedBox(width: 8),
                                    TabButton(
                                      label: _t('Height-for-Age', 'Haba sa Edad'),
                                      isActive: _currentIndex == 1,
                                      onTap: () => setState(() => _currentIndex = 1),
                                    ),
                                    const SizedBox(width: 8),
                                    TabButton(
                                      label: _t('Weight-for-Age', 'Timbang sa Edad'),
                                      isActive: _currentIndex == 2,
                                      onTap: () => setState(() => _currentIndex = 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: IndexedStack(
                                  index: _currentIndex,
                                  children: [
                                    _buildTabContent(metric: 'bmi', sex: sex),
                                    _buildTabContent(metric: 'height', sex: sex),
                                    _buildTabContent(metric: 'weight', sex: sex),
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchGrowthHistory,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
              child: Text(_t('Retry', 'Subukan Muli')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(_t('No Records Found', 'Walang Datos na Nahanap'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t('Growth history will appear here once registered.', 'Ang kasaysayan ng paglaki ay lalabas dito kapag may naitala na.')),
        ],
      ),
    );
  }

  Widget _buildTabContent({required String metric, required String sex}) {
    // 1. Prepare actual spots
    final List<FlSpot> actualSpots = [];
    final Map<int, double> recordMap = {};

    for (final record in _records) {
      final date = DateTime.parse(record['created_at'].toString());
      final ageWeeks = _ageInWeeksForDate(date);
      
      double val = 0.0;
      if (metric == 'height') {
        val = (record['child_height'] as num?)?.toDouble() ?? 0.0;
      } else if (metric == 'weight') {
        val = (record['child_weight'] as num?)?.toDouble() ?? 0.0;
      } else {
        // BMI
        final h = (record['child_height'] as num?)?.toDouble() ?? 0.0;
        final w = (record['child_weight'] as num?)?.toDouble() ?? 0.0;
        val = _calculateBMI(h, w);
      }

      if (val > 0) {
        actualSpots.add(FlSpot(ageWeeks.toDouble(), val));
        recordMap[ageWeeks] = val;
      }
    }

    actualSpots.sort((a, b) => a.x.compareTo(b.x));

    // 2. Fetch WHO standard curves
    final List<FlSpot> medianSpots = [];
    final List<FlSpot> minSpots = []; // -1 SD
    final List<FlSpot> maxSpots = []; // +1 SD

    // Plot WHO standards for weeks 0 to 13 dynamically
    for (int w = 0; w <= 13; w++) {
      Map<String, dynamic>? ref;
      if (metric == 'height') {
        ref = GrowthCalculator.getHeightData(w, sex);
      } else if (metric == 'weight') {
        ref = GrowthCalculator.getWeightData(w, sex);
      } else {
        ref = GrowthCalculator.getBMIData(w, sex);
      }

      if (ref != null) {
        final x = w.toDouble();
        medianSpots.add(FlSpot(x, (ref['sd0'] as num).toDouble()));
        minSpots.add(FlSpot(x, (ref['sd1neg'] as num).toDouble()));
        maxSpots.add(FlSpot(x, (ref['sd1'] as num).toDouble()));
      }
    }

    final double startWeek = actualSpots.isNotEmpty ? actualSpots.first.x : 0.0;
    final double endWeek = actualSpots.isNotEmpty ? actualSpots.last.x.clamp(8, 13) : 13.0;

    final allSpots = [...actualSpots, ...medianSpots, ...minSpots, ...maxSpots];
    final double minY = allSpots.isEmpty ? 0 : allSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9;
    final double maxY = allSpots.isEmpty ? 50 : allSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1;

    final String unit = metric == 'height' ? 'cm' : (metric == 'weight' ? 'kg' : 'kg/m²');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroCard(
            image: null,
            title: widget.childName,
            subtitle: widget.childAge,
            sex: widget.childGender,
            showWeekBadge: false,
            showHeartRow: false,
          ),
          const SizedBox(height: 16),

          // Growth Chart Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('${metric.toUpperCase()} Growth Trend', 'Progreso ng ${metric.toUpperCase()}'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(_t('Actual', 'Sukat'), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Container(
                          width: 10,
                          height: 10,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 4),
                        Text(_t('Normal Range', 'Normal'), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minX: startWeek,
                      maxX: endWeek,
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.shade100,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (val, meta) => Text(
                              '${val.toStringAsFixed(0)} $unit',
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (val, meta) => Text(
                              'W${val.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Shaded Range (-1 to +1 SD) dynamically represented by boundary lines
                        LineChartBarData(
                          spots: minSpots,
                          isCurved: true,
                          color: Colors.grey.shade300,
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: maxSpots,
                          isCurved: true,
                          color: Colors.grey.shade300,
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                        ),
                        // Median standard
                        LineChartBarData(
                          spots: medianSpots,
                          isCurved: true,
                          color: Colors.grey.shade400,
                          barWidth: 1,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                        // Child actual trajectory
                        if (actualSpots.isNotEmpty)
                          LineChartBarData(
                            spots: actualSpots,
                            isCurved: true,
                            color: AppColors.brandPrimary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interpretation Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.brandPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _t('Clinical Interpretation', 'Interpretasyon sa Sukat'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getLocalInterpretation(metric, sex),
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Measurement History Table Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Measurement History', 'Kasaysayan ng mga Sukat'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _records.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final record = _records[_records.length - 1 - idx]; // Show latest first
                    final date = DateTime.parse(record['created_at'].toString());
                    final ageWeeks = _ageInWeeksForDate(date);
                    
                    double val = 0.0;
                    if (metric == 'height') {
                      val = (record['child_height'] as num?)?.toDouble() ?? 0.0;
                    } else if (metric == 'weight') {
                      val = (record['child_weight'] as num?)?.toDouble() ?? 0.0;
                    } else {
                      final h = (record['child_height'] as num?)?.toDouble() ?? 0.0;
                      final w = (record['child_weight'] as num?)?.toDouble() ?? 0.0;
                      val = _calculateBMI(h, w);
                    }

                    // Compute classification
                    String badgeLabel = 'Expected';
                    Color badgeColor = AppColors.success;
                    
                    if (metric == 'height') {
                      final z = GrowthCalculator.calculateHeightZScore(val, ageWeeks, sex);
                      if (z != null) {
                        if (z < -1) {
                          badgeLabel = 'Below Standard';
                          badgeColor = Colors.orange;
                        } else if (z > 1) {
                          badgeLabel = 'Above Standard';
                          badgeColor = Colors.orange;
                        }
                      }
                    } else if (metric == 'weight') {
                      final z = GrowthCalculator.calculateWeightZScore(val, ageWeeks, sex);
                      if (z != null) {
                        if (z < -1) {
                          badgeLabel = 'Below Standard';
                          badgeColor = Colors.orange;
                        } else if (z > 1) {
                          badgeLabel = 'Above Standard';
                          badgeColor = Colors.orange;
                        }
                      }
                    } else {
                      final z = GrowthCalculator.calculateBMIZScore(val, ageWeeks, sex);
                      if (z != null) {
                        if (z < -1) {
                          badgeLabel = 'Below Standard';
                          badgeColor = Colors.orange;
                        } else if (z > 1) {
                          badgeLabel = 'Above Standard';
                          badgeColor = Colors.orange;
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMMM d, yyyy').format(date),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _t('Week $ageWeeks old', 'Ika-$ageWeeks linggo gulang'),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${val.toStringAsFixed(1)} $unit',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _t(badgeLabel, badgeLabel),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalInterpretation(String metric, String sex) {
    if (_records.isEmpty) return 'No growth records found.';
    
    final latestRecord = _records.last;
    final date = DateTime.parse(latestRecord['created_at'].toString());
    final ageWeeks = _ageInWeeksForDate(date);
    
    final double height = (latestRecord['child_height'] as num?)?.toDouble() ?? 0.0;
    final double weight = (latestRecord['child_weight'] as num?)?.toDouble() ?? 0.0;
    final double bmi = _calculateBMI(height, weight);

    if (metric == 'height') {
      final z = GrowthCalculator.calculateHeightZScore(height, ageWeeks, sex);
      if (z == null) return 'Height interpretation unavailable.';
      if (z < -1) {
        return 'The child\'s length is slightly below the standard range for their age. Ensure adequate breastfeeding or formula intake and track height again next week.';
      } else if (z <= 1) {
        return 'The child\'s length is within the expected WHO standard range for their age. They are growing steadily!';
      } else {
        return 'The child\'s length is slightly above the standard range for their age, indicating a tall healthy stature.';
      }
    } else if (metric == 'weight') {
      final z = GrowthCalculator.calculateWeightZScore(weight, ageWeeks, sex);
      if (z == null) return 'Weight interpretation unavailable.';
      if (z < -1) {
        return 'The child\'s weight is slightly below the expected WHO standards. Check their feeding frequency and confirm they are feeding properly.';
      } else if (z <= 1) {
        return 'The child\'s weight is perfectly within the expected WHO standard range for their age. Great job caring for them!';
      } else {
        return 'The child\'s weight is slightly above the expected standard range. Normal variations exist, continue healthy active play and monitoring.';
      }
    } else {
      // BMI
      final z = GrowthCalculator.calculateBMIZScore(bmi, ageWeeks, sex);
      if (z == null) return 'BMI interpretation unavailable.';
      if (z < -1) {
        final wZ = GrowthCalculator.calculateWeightZScore(weight, ageWeeks, sex);
        final hZ = GrowthCalculator.calculateHeightZScore(height, ageWeeks, sex);
        if (wZ != null && wZ >= -1 && hZ != null && hZ <= 1) {
          return 'Although weight and length are individually normal, the weight is on the lower side relative to height, resulting in a slightly below standard BMI.';
        }
        return 'The child\'s BMI-for-Age is slightly below standard expected WHO ranges, which indicates they are lean. Continue nourishing and monitoring.';
      } else if (z <= 1) {
        return 'The child\'s weight is perfectly proportioned to their height, resulting in a completely healthy expected standard BMI.';
      } else {
        return 'The child\'s BMI is slightly above standard limits. This means they are slightly heavier relative to their length. Track their active minutes and balanced diet.';
      }
    }
  }
}
