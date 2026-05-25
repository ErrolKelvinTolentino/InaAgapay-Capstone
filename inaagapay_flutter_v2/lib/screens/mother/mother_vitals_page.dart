// lib/screens/mother/mother_vitals_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/language_service.dart';
import '../../services/weight_gain_engine.dart';
import '../../models/weight_gain_models.dart';
import '../../widgets/app_input_field.dart';

class MotherVitalsPage extends StatefulWidget {
  final int motherId;
  final int pregnancyId;
  final String? lastMenstrualPeriod;

  const MotherVitalsPage({
    super.key,
    required this.motherId,
    required this.pregnancyId,
    this.lastMenstrualPeriod,
  });

  @override
  State<MotherVitalsPage> createState() => _MotherVitalsPageState();
}

class _MotherVitalsPageState extends State<MotherVitalsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allVitals = [];
  WeightGainResult? _weightGainResult;
  double? _prePregnancyWeight;
  double? _heightCm;
  int _fetalCount = 1;
  bool _isUnlinked = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch pregnancy info (fetal count, pre pregnancy weight)
      final pregRow = await SupabaseService.client
          .from('pregnancies')
          .select('pre_pregnancy_weight, fetal_count')
          .eq('pregnancy_id', widget.pregnancyId)
          .maybeSingle();

      if (pregRow != null) {
        _prePregnancyWeight = pregRow['pre_pregnancy_weight'] != null
            ? _toDouble(pregRow['pre_pregnancy_weight'])
            : null;
        _fetalCount = pregRow['fetal_count'] != null
            ? _toInt(pregRow['fetal_count']) ?? 1
            : 1;
      }

      // 2. Fetch mother height
      final motherRow = await SupabaseService.client
          .from('mothers')
          .select('height, assigned_bhc_id')
          .eq('mother_id', widget.motherId)
          .maybeSingle();

      if (motherRow != null) {
        if (motherRow['height'] != null) {
          _heightCm = _toDouble(motherRow['height']);
        }
        _isUnlinked = motherRow['assigned_bhc_id'] == null;
      }

      // 3. Fetch checkups
      final checkupsRaw = await SupabaseService.client
          .from('prenatal_checkups')
          .select('prenatal_checkup_id, checkup_datetime, age_of_gestation, checkup_weight, blood_pressure_systolic, blood_pressure_diastolic, remarks')
          .eq('pregnancy_id', widget.pregnancyId);

      // 4. Fetch maternal vitals
      final vitalsRaw = await SupabaseService.client
          .from('maternal_vitals')
          .select('vital_id, recorded_at, age_of_gestation, weight_kg, height_cm, notes')
          .eq('pregnancy_id', widget.pregnancyId);

      final checkups = (checkupsRaw as List).cast<Map<String, dynamic>>();
      final vitals = (vitalsRaw as List).cast<Map<String, dynamic>>();

      // 5. Merge records
      final List<Map<String, dynamic>> merged = [
        ...checkups.map((c) => {
              'id': c['prenatal_checkup_id'],
              'date': DateTime.tryParse(c['checkup_datetime']?.toString() ?? '') ?? DateTime.now(),
              'age_of_gestation': _toDouble(c['age_of_gestation']),
              'weight_kg': _toDouble(c['checkup_weight']),
              'bp_systolic': _toInt(c['blood_pressure_systolic']),
              'bp_diastolic': _toInt(c['blood_pressure_diastolic']),
              'height_cm': null,
              'notes': c['remarks'] ?? 'Official Prenatal Checkup',
              'source': 'prenatal_checkup',
            }),
        ...vitals.map((v) => {
              'id': v['vital_id'],
              'date': DateTime.tryParse(v['recorded_at']?.toString() ?? '') ?? DateTime.now(),
              'age_of_gestation': _toDouble(v['age_of_gestation']),
              'weight_kg': _toDouble(v['weight_kg']),
              'bp_systolic': null,
              'bp_diastolic': null,
              'height_cm': _toDouble(v['height_cm']),
              'notes': v['notes'],
              'source': 'mother_self',
            }),
      ];

      // Sort chronological descending for history list
      merged.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      _allVitals = merged;

      // Prefill height from the latest history record if local height is null
      double? latestHeight = _heightCm;
      for (final v in _allVitals) {
        if (v['height_cm'] != null) {
          latestHeight = v['height_cm'];
          break;
        }
      }
      _heightCm = latestHeight;

      // 6. Run Weight Gain Engine evaluation if we have at least one weight reading
      final weightReadingsAsc = _allVitals
          .where((v) => v['weight_kg'] != null)
          .map((v) => {
                'checkup_weight': v['weight_kg'],
                'age_of_gestation': v['age_of_gestation'],
                'checkup_datetime': (v['date'] as DateTime).toIso8601String(),
              })
          .toList()
          .reversed // Convert descending list back to chronological ascending order
          .toList();

      if (weightReadingsAsc.isNotEmpty) {
        final latest = weightReadingsAsc.last;
        final currentWeight = (latest['checkup_weight'] as num).toDouble();

        // Effective AOG calculation fallback
        double effectiveAog = (latest['age_of_gestation'] as num?)?.toDouble() ?? 0;
        if (effectiveAog == 0 && widget.lastMenstrualPeriod != null) {
          final lmp = DateTime.tryParse(widget.lastMenstrualPeriod!);
          if (lmp != null) {
            effectiveAog = DateTime.now().difference(lmp).inDays / 7.0;
          }
        }

        _weightGainResult = WeightGainEngine.evaluate(
          currentWeight: currentWeight,
          aogWeeks: effectiveAog,
          allCheckups: weightReadingsAsc,
          prePregnancyWeight: _prePregnancyWeight,
          heightCm: _heightCm,
          fetalCount: _fetalCount,
        );
      } else {
        _weightGainResult = null;
      }
    } catch (e) {
      debugPrint('Error loading vitals: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? get _computedAogWeeks {
    if (widget.lastMenstrualPeriod == null) return null;
    final lmp = DateTime.tryParse(widget.lastMenstrualPeriod!);
    if (lmp == null) return null;
    return DateTime.now().difference(lmp).inDays / 7.0;
  }

  void _showAddVitalsBottomSheet() {
    final weightController = TextEditingController();
    final heightController = TextEditingController(text: _heightCm != null ? _heightCm!.toStringAsFixed(1) : '');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? weightErrorText;
    String? heightErrorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            final weightStr = weightController.text.trim();
            final heightStr = heightController.text.trim();
            final weight = double.tryParse(weightStr);
            final height = double.tryParse(heightStr);

            setModalState(() {
              weightErrorText = null;
              heightErrorText = null;

              if (weightStr.isEmpty) {
                weightErrorText = _t('Weight is required', 'Kailangan ang timbang');
              } else if (weight == null || weight < 20 || weight > 200) {
                weightErrorText = _t('Enter a valid weight (20-200 kg)', 'Magpasok ng wastong timbang (20-200 kg)');
              }

              if (heightStr.isEmpty) {
                heightErrorText = _t('Height is required', 'Kailangan ang taas');
              } else if (height == null || height < 50 || height > 250) {
                heightErrorText = _t('Enter a valid height (50-250 cm)', 'Magpasok ng wastong taas (50-250 cm)');
              }
            });

            if (weightErrorText != null || heightErrorText != null) return;

            setModalState(() => isSaving = true);
            try {
              final notes = notesController.text.trim();

              final data = <String, dynamic>{
                'pregnancy_id': widget.pregnancyId,
                'mother_id': widget.motherId,
                'recorded_at': DateTime.now().toIso8601String(),
                'weight_kg': weight,
                'height_cm': height,
              };

              final aog = _computedAogWeeks;
              if (aog != null) {
                data['age_of_gestation'] = double.parse(aog.toStringAsFixed(1));
              }

              data['notes'] = notes.isNotEmpty ? notes : 'Self-logged vitals';

              await SupabaseService.client.from('maternal_vitals').insert(data);

              if (height != null) {
                await SupabaseService.client
                    .from('mothers')
                    .update({'height': height})
                    .eq('mother_id', widget.motherId);
                _heightCm = height;
              }

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(_t('Vitals logged successfully!', 'Matagumpay na naitala ang mga vital!')),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _loadData();
              }
            } catch (e) {
              setModalState(() => isSaving = false);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('Log My Vitals', 'Itala ang Aking Vitals'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        'Self-recorded entries will be visible on your history.',
                        'Ang mga sariling naitalang impormasyon ay makikita sa iyong kasaysayan.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                     // Height Input
                    Text(
                      _t('Height (cm)', 'Taas (cm)'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppInputField(
                      hintText: _t('e.g. 156.2', 'hal. 156.2'),
                      controller: heightController,
                      isRequired: true,
                      readOnly: !_isUnlinked,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                      ],
                      leadingIcon: Icons.height,
                      errorText: heightErrorText,
                    ),
                    if (!_isUnlinked) ...[
                      const SizedBox(height: 6),
                      Text(
                        _t('Height is managed by your Barangay Health Center. Contact your midwife to update it.',
                           'Ang taas ay pinamamahalaan ng iyong Barangay Health Center. Makipag-ugnayan sa midwife upang i-update ito.'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Weight Input
                    Text(
                      _t('Weight (kg)', 'Timbang (kg)'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppInputField(
                      hintText: _t('e.g. 58.5', 'hal. 58.5'),
                      controller: weightController,
                      isRequired: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                      ],
                      leadingIcon: Icons.monitor_weight_outlined,
                      errorText: weightErrorText,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    Text(
                      _t('Notes (optional)', 'Mga Tala (opsyonal)'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppInputField(
                      hintText: _t('How are you feeling today?', 'Ano ang iyong nararamdaman ngayon?'),
                      controller: notesController,
                      leadingIcon: Icons.notes,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _t('Save Vitals', 'I-save ang Vitals'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeightChart() {
    // Filter and prepare weights chronologically ascending
    final chartVitals = _allVitals
        .where((v) => v['weight_kg'] != null && v['age_of_gestation'] != null)
        .toList()
        .reversed
        .toList();

    if (chartVitals.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            const Icon(Icons.show_chart, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              _t('Log at least 2 entries to see the weight trend chart.', 'Itala ang hindi bababa sa 2 timbang upang makita ang tsart.'),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final spots = chartVitals.map((v) {
      final double aog = (v['age_of_gestation'] as num).toDouble();
      final double weight = (v['weight_kg'] as num).toDouble();
      return FlSpot(aog, weight);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;
    final minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    final maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Weight Progression (kg)', 'Progreso ng Timbang (kg)'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: minX - 0.5,
                maxX: maxX + 0.5,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (val, meta) => Text(
                        val.toStringAsFixed(1),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) => Text(
                        'W${val.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.brandPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeColor: AppColors.brandPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(WeightGainStatus status) {
    Color fg;
    String label;

    switch (status) {
      case WeightGainStatus.normal:
        fg = AppColors.success;
        label = _t('NORMAL', 'NORMAL');
        break;
      case WeightGainStatus.low:
        fg = Colors.amber;
        label = _t('LOW', 'MABABA');
        break;
      case WeightGainStatus.high:
        fg = const Color(0xFFEF5350);
        label = _t('HIGH', 'MATAAS');
        break;
      case WeightGainStatus.insufficient:
        fg = Colors.grey.shade600;
        label = _t('INSUFFICIENT', 'KULANG');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildSourceBadge(String source) {
    Color bg;
    Color fg;
    String text;

    switch (source) {
      case 'prenatal_checkup':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        text = _t('Official', 'Opisyal');
        break;
      case 'midwife_quick':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        text = _t('Midwife Log', 'Tala ng Midwife');
        break;
      case 'mother_self':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        text = _t('Self-logged', 'Sariling Tala');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEvaluationCard() {
    final result = _weightGainResult;
    if (result == null) return const SizedBox.shrink();


    Color bmiColor;
    switch (result.bmiCategory) {
      case 'Underweight':
        bmiColor = Colors.amber;
        break;
      case 'Normal':
        bmiColor = AppColors.success;
        break;
      case 'Overweight':
        bmiColor = Colors.orange;
        break;
      case 'Obese':
        bmiColor = const Color(0xFFEF5350);
        break;
      default:
        bmiColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Weight Gain Analysis', 'Pagsusuri sa Timbang'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Badges Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bmiColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _t(result.bmiCategory, result.bmiCategory),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: bmiColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(result.status),
            ],
          ),
          const SizedBox(height: 16),

          // Detail rows
          _weightInfoRow(_t('Current Weight', 'Kasalukuyang Timbang'), '${result.currentWeight.toStringAsFixed(1)} kg'),
          if (result.baselineWeight != null)
            _weightInfoRow(
              result.mode == WeightGainMode.full
                  ? _t('Pre-Pregnancy Weight', 'Timbang Bago Mabuntis')
                  : _t('Baseline Weight', 'Baseline na Timbang'),
              '${result.baselineWeight!.toStringAsFixed(1)} kg',
            ),
          if (result.actualGain != null)
            _weightInfoRow(
              _t('Actual Gain', 'Aktwal na Dagdag'),
              '${result.actualGain! >= 0 ? '+' : ''}${result.actualGain!.toStringAsFixed(1)} kg',
            ),
          if (result.expectedGainMin != null && result.expectedGainMax != null)
            _weightInfoRow(
              _t('Expected Gain', 'Inaasahang Dagdag'),
              '${result.expectedGainMin!.toStringAsFixed(1)} - ${result.expectedGainMax!.toStringAsFixed(1)} kg',
            )
          else if (result.expectedGain != null)
            _weightInfoRow(
              _t('Expected Gain', 'Inaasahang Dagdag'),
              '${result.expectedGain!.toStringAsFixed(1)} kg',
            ),
          if (result.weeklyGain != null)
            _weightInfoRow(
              _t('Weekly Gain Rate', 'Antas ng Lingguhang Dagdag'),
              '${result.weeklyGain!.toStringAsFixed(3)} kg/wk',
            ),

          const SizedBox(height: 14),

          // Advisory message box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              result.message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          if (result.hasFlags) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.flags.map((flag) {
                String label;
                Color flagColor;
                if (flag == 'weight_loss') {
                  label = _t('⚠️ Weight Loss Detected', '⚠️ May Bawas sa Timbang');
                  flagColor = AppColors.error;
                } else if (flag == 'plateau') {
                  label = _t('ℹ️ Weight Plateau', 'ℹ️ Patag na Timbang');
                  flagColor = AppColors.warning;
                } else if (flag == 'abnormal_spike') {
                  label = _t('⚠️ Rapid Weight Gain Spike', '⚠️ Mabilis na Pagtaas ng Timbang');
                  flagColor = AppColors.error;
                } else {
                  label = flag;
                  flagColor = AppColors.textSecondary;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: flagColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: flagColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: flagColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimaryOf(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          _t('My Vitals & Weight Gain', 'Aking Vitals & Timbang'),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.brandPrimary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  _buildEvaluationCard(),
                  const SizedBox(height: 16),
                  _buildWeightChart(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.history, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        _t('Vitals History Log', 'Kasaysayan ng mga Vital'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_allVitals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.favorite_border, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            _t('No vitals logged yet. Tap the button below to start tracking!', 
                               'Wala pang naitalang vitals. Tapikin ang button sa ibaba upang magsimula!'),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._allVitals.map((v) {
                      final double? weight = v['weight_kg'];
                      final double? height = v['height_cm'] ?? _heightCm;
                      final int? sys = v['bp_systolic'];
                      final int? dia = v['bp_diastolic'];
                      final double? aog = v['age_of_gestation'];
                      final String notes = v['notes'] ?? '';
                      final DateTime date = v['date'];
                      final String formattedDate = DateFormat('MMMM d, yyyy · h:mm a').format(date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                _buildSourceBadge(v['source']),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (weight != null) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.monitor_weight_outlined, size: 18, color: AppColors.brandPrimary),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _t('Weight', 'Timbang'),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              '${weight.toStringAsFixed(1)} kg',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (height != null) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.height, size: 18, color: AppColors.brandPrimary),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _t('Height', 'Taas'),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              '${height.toStringAsFixed(1)} cm',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                 ],
                                if (aog != null) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.baby_changing_station, size: 18, color: AppColors.brandPrimary),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _t('AOG', 'Edad ng Gest.'),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              '${aog.toStringAsFixed(1)} wks',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const Divider(height: 20, color: AppColors.borderPrimary),
                              Text(
                                notes,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inputText,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVitalsBottomSheet,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add),
        label: Text(_t('Log Vitals', 'Itala ang Vitals')),
      ),
    );
  }
}
