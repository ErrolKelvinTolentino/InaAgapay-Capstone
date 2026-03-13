import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';

import 'add_prenatal_checkup.dart';
import 'add_ultrasound_page.dart';
import 'add_lab_test_page.dart';
import 'child_profile_page.dart';
import 'midwife/start_pregnancy_screen.dart';

class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({super.key, required this.motherId});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage>
    with SingleTickerProviderStateMixin {
  Future<Map<String, dynamic>>? _future;
  bool _riskExpanded = false;
  String _childQuery = '';
  String _childSort = 'recent';
  String _checkupSort = 'desc';
  String _labSort = 'desc';
  String _usSort = 'desc';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _future = fetchMotherProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchMotherProfile() async {
    final token = await AuthStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/mother_profile.php?mother_id=${widget.motherId}',
      ),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    final decoded = jsonDecode(res.body);
    if (decoded['success'] == true &&
        decoded['mother'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(decoded['mother'] as Map);
    }

    throw Exception(decoded['message'] ?? 'Failed to load profile');
  }

  Future<void> _refresh() async {
    final future = fetchMotherProfile();
    setState(() {
      _future = future;
    });
    await future;
  }

  // Helper methods
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String? _fmtDate(dynamic v) {
    if (v == null) return null;
    final parsed = DateTime.tryParse(v.toString());
    if (parsed == null) return v.toString();
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  String? _fmtDateTime(dynamic v) {
    final parsed = _parseDateTime(v);
    if (parsed == null) return v?.toString();
    return DateFormat('MMM d, yyyy h:mm a').format(parsed);
  }

  String _fmtValue(dynamic v) {
    if (v == null) return '—';
    final value = v.toString().trim();
    return value.isEmpty ? '—' : value;
  }

  String _shortDate(dynamic v) {
    final parsed = _parseDateTime(v) ?? _parseDate(v);
    if (parsed == null) return '—';
    return DateFormat('MMM d').format(parsed);
  }

  // AI Analysis Helper Functions
  String _generatePrenatalAIInsights(Map<String, dynamic> checkup) {
    final analysis = StringBuffer();
    analysis.write('🤖 AI Analysis:\n\n');

    // Blood Pressure Analysis
    final bpSys = _toDouble(checkup['blood_pressure_systolic']);
    final bpDia = _toDouble(checkup['blood_pressure_diastolic']);
    if (bpSys != null && bpDia != null) {
      if (bpSys >= 140 || bpDia >= 90) {
        analysis.write('⚠️ **Elevated Blood Pressure** detected. '
            'Consider monitoring for preeclampsia symptoms.\n\n');
      } else if (bpSys < 90 || bpDia < 60) {
        analysis.write('📉 **Low Blood Pressure** noted. '
            'Ensure adequate hydration and gradual position changes.\n\n');
      } else {
        analysis.write('✅ **Blood Pressure** is within normal pregnancy range.\n\n');
      }
    }

    // Weight Analysis
    final weight = _toDouble(checkup['checkup_weight']);
    if (weight != null) {
      analysis.write('⚖️ **Weight tracking**: ');
      final prevWeight = _toDouble(checkup['previous_weight']);
      if (prevWeight != null) {
        final diff = weight - prevWeight;
        if (diff > 2) {
          analysis.write('Rapid weight gain noted. Monitor for edema.\n\n');
        } else if (diff < -1) {
          analysis.write('Weight loss detected. Ensure adequate nutrition.\n\n');
        } else {
          analysis.write('Steady weight progression.\n\n');
        }
      } else {
        analysis.write('Baseline weight recorded.\n\n');
      }
    }

    // Edema Analysis
    final edema = checkup['edema']?.toString().toLowerCase();
    if (edema != null && edema != 'none') {
      analysis.write('💧 **Edema ${edema.toUpperCase()}**: '
          'Monitor for worsening symptoms. Elevate feet when resting.\n\n');
    }

    // TD Vaccine Analysis
    final tdDose = checkup['td_vaccine_dose']?.toString();
    if (tdDose != null && tdDose.isNotEmpty) {
      analysis.write('💉 **TD Vaccine ${tdDose.toUpperCase()}** administered. '
          'Provides protection against tetanus and diphtheria.\n\n');
    }

    // General Recommendations
    analysis.write('📋 **Recommendations**:\n');
    analysis.write('• Continue regular prenatal visits\n');
    analysis.write('• Monitor fetal movements daily\n');
    analysis.write('• Report any unusual symptoms immediately\n');
    analysis.write('• Maintain balanced nutrition and hydration\n');

    final aog = _toDouble(checkup['age_of_gestation']);
    if (aog != null && aog >= 28) {
      analysis.write('• Practice kick counts regularly\n');
    }

    return analysis.toString();
  }

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final analysis = StringBuffer();
    analysis.write('🤖 Ultrasound AI Insights:\n\n');

    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final date = _fmtDate(ultrasound['ultrasound_date']) ?? 'Unknown date';

    analysis.write('Based on ultrasound conducted on $date');

    final location = ultrasound['ultrasound_location'];
    if (location != null && location.toString().isNotEmpty) {
      analysis.write(' at $location');
    }

    final healthWorker = ultrasound['health_worker_name'];
    if (healthWorker != null && healthWorker.toString().isNotEmpty) {
      analysis.write(' by $healthWorker');
    }

    analysis.write(':\n\n');

    // Analyze remarks
    if (remarks.contains('normal') ||
        remarks.contains('healthy') ||
        remarks.contains('good') ||
        remarks.contains('appropriate') ||
        remarks.contains('within normal limits')) {
      analysis.write('✅ **Normal Findings**: Ultrasound appears normal with healthy fetal development. '
          'All measurements and observations are within expected ranges.\n\n');
    } else if (remarks.contains('follow') ||
        remarks.contains('monitor') ||
        remarks.contains('repeat') ||
        remarks.contains('re-evaluate')) {
      analysis.write('📊 **Follow-up Recommended**: Some findings require additional observation '
          'or repeat ultrasound. This is a common precautionary measure.\n\n');
    } else if (remarks.contains('concern') ||
        remarks.contains('abnormal') ||
        remarks.contains('further') ||
        remarks.contains('investigation')) {
      analysis.write('🔍 **Further Evaluation Needed**: Results indicate findings that may require '
          'additional evaluation. Discuss with healthcare provider for appropriate guidance.\n\n');
    } else if (remarks.contains('growth') ||
        remarks.contains('measurement') ||
        remarks.contains('size')) {
      analysis.write('📏 **Growth Assessment**: Fetal growth and measurements noted. '
          'Regular monitoring will help ensure continued healthy development.\n\n');
    } else if (remarks.contains('position') ||
        remarks.contains('presentation') ||
        remarks.contains('placenta')) {
      analysis.write('📍 **Position Assessment**: Fetal position and placental location noted. '
          'Important factors for pregnancy progression and delivery planning.\n\n');
    } else {
      analysis.write('📋 **Diagnostic Information**: The ultrasound provides important diagnostic '
          'information about your pregnancy progression.\n\n');
    }

    // Key Recommendations
    analysis.write('💡 **Key Recommendations**:\n');
    analysis.write('• Discuss findings with your healthcare provider\n');
    analysis.write('• Continue all scheduled prenatal appointments\n');
    analysis.write('• Report any unusual symptoms immediately\n');
    analysis.write('• Maintain ultrasound follow-up schedule\n');

    if (remarks.contains('exercise') || remarks.contains('activity')) {
      analysis.write('• Continue moderate exercise as approved\n');
    }

    return analysis.toString();
  }

  String _generateLabTestAIInsights(Map<String, dynamic> labTest) {
    final analysis = StringBuffer();
    analysis.write('🤖 Lab Test AI Analysis:\n\n');

    final testType = labTest['lab_test_type']?.toString().toLowerCase() ?? '';
    final remarks = labTest['remarks']?.toString().toLowerCase() ?? '';
    final date = _fmtDate(labTest['lab_test_date']) ?? 'Unknown date';

    analysis.write('**${testType.toUpperCase()} Results** from $date:\n\n');

    // Analyze based on test type
    if (testType.contains('blood') || testType.contains('cbc')) {
      analysis.write('🩸 **Blood Test Analysis**:\n');
      if (remarks.contains('normal') || remarks.contains('within range')) {
        analysis.write('• Blood parameters are within normal pregnancy ranges\n');
        analysis.write('• No significant abnormalities detected\n');
      } else if (remarks.contains('low') || remarks.contains('deficient')) {
        analysis.write('• Some values below optimal range\n');
        analysis.write('• Consider dietary adjustments or supplements\n');
      } else if (remarks.contains('high') || remarks.contains('elevated')) {
        analysis.write('• Elevated values noted\n');
        analysis.write('• May require follow-up testing\n');
      }
      analysis.write('\n');
    } else if (testType.contains('urine') || testType.contains('uti')) {
      analysis.write('🧪 **Urine Test Analysis**:\n');
      if (remarks.contains('normal') || remarks.contains('clear')) {
        analysis.write('• Urine analysis shows no concerning findings\n');
        analysis.write('• Good kidney function indicated\n');
      } else if (remarks.contains('protein') || remarks.contains('albumin')) {
        analysis.write('• Protein detected - monitor for preeclampsia\n');
        analysis.write('• Increase water intake and rest\n');
      } else if (remarks.contains('infection') || remarks.contains('bacteria')) {
        analysis.write('• Possible urinary tract infection\n');
        analysis.write('• Consult healthcare provider for treatment\n');
      }
      analysis.write('\n');
    } else if (testType.contains('glucose') || testType.contains('sugar')) {
      analysis.write('📊 **Glucose Test Analysis**:\n');
      if (remarks.contains('normal') || remarks.contains('passed')) {
        analysis.write('• Glucose levels are within normal range\n');
        analysis.write('• No indication of gestational diabetes\n');
      } else if (remarks.contains('high') || remarks.contains('elevated')) {
        analysis.write('• Elevated glucose levels detected\n');
        analysis.write('• May indicate need for gestational diabetes screening\n');
        analysis.write('• Monitor diet and consider follow-up testing\n');
      }
      analysis.write('\n');
    }

    // General interpretation
    if (remarks.contains('normal') ||
        remarks.contains('negative') ||
        remarks.contains('clear')) {
      analysis.write('✅ **Overall Assessment**: Test results are reassuring '
          'and show no significant abnormalities.\n\n');
    } else if (remarks.contains('borderline') ||
        remarks.contains('slightly')) {
      analysis.write('⚠️ **Borderline Results**: Some values are at the edge '
          'of normal range. Consider repeat testing if symptoms develop.\n\n');
    } else if (remarks.contains('abnormal') ||
        remarks.contains('positive') ||
        remarks.contains('detected')) {
      analysis.write('🔍 **Abnormal Findings**: Results indicate areas that '
          'require medical attention. Follow up with healthcare provider.\n\n');
    }

    // Health Recommendations
    analysis.write('🏥 **Health Recommendations**:\n');
    analysis.write('• Review results with your healthcare provider\n');
    analysis.write('• Follow any prescribed treatment plans\n');
    analysis.write('• Schedule follow-up tests as recommended\n');
    analysis.write('• Maintain healthy lifestyle habits\n');

    return analysis.toString();
  }

  Widget _buildAIAnalysisSection(String title, String analysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: Color(0xFF7E57C2),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Analysis content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E5F5),
                  Color(0xFFE8EAF6),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF7E57C2).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFF7E57C2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI-Powered Insights',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E35B1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  analysis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: This is an AI-generated analysis for informational purposes only. '
                  'Always consult with your healthcare provider for medical advice.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.bgPrimary, elevation: 0),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No profile data found.'));
          }

          final m = snapshot.data!;

          String fullName = [
            m['first_name'],
            m['middle_name'],
            m['last_name'],
            m['extension_name'],
          ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');

          Widget section(String title, List<Widget> children) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.faintWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...children,
                ],
              ),
            );
          }

          Widget infoCard(String title, List<Widget> children) {
            return section(title, children);
          }

          Widget field(String label, dynamic value) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(flex: 5, child: Text(value?.toString() ?? '—')),
                ],
              ),
            );
          }

          String formatOutcome(dynamic v) {
            final raw = v?.toString().trim().toLowerCase() ?? '';
            switch (raw) {
              case 'live_birth':
              case 'livebirth':
                return 'Livebirth';
              case 'stillbirth':
                return 'Stillbirth';
              case 'miscarriage':
                return 'Miscarriage';
              case 'abortion':
                return 'Abortion';
              case 'ectopic':
                return 'Ectopic';
              default:
                return raw.isEmpty ? '—' : raw;
            }
          }

          String formatDeliveryMethod(dynamic v) {
            final raw = v?.toString().trim() ?? '';
            if (raw.isEmpty) return '—';
            switch (raw.toUpperCase()) {
              case 'NSD':
                return 'Normal Spontaneous Delivery';
              case 'CS':
                return 'Cesarean Section';
              case 'INSTRUMENTAL':
                return 'Instrumental';
              default:
                return raw;
            }
          }

          List<dynamic> listOrEmpty(dynamic v) => v is List ? v : [];

          Map<String, dynamic>? riskData(dynamic v) {
            return v is Map<String, dynamic> ? v : null;
          }

          String? resolveImageUrl(dynamic v) {
            if (v == null) return null;
            final raw = v.toString().trim();
            if (raw.isEmpty) return null;
            if (raw.startsWith('http')) return raw;
            final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
            return 'https://inaagapay.alwaysdata.net/$cleaned';
          }

          List<Map<String, dynamic>> sortedCheckups(dynamic v) {
            final list = listOrEmpty(
              v,
            ).whereType<Map<String, dynamic>>().toList();
            list.sort((a, b) {
              final da = _parseDateTime(
                a['checkup_datetime'] ?? a['checkup_date'],
              );
              final db = _parseDateTime(
                b['checkup_datetime'] ?? b['checkup_date'],
              );
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              var cmp = da.compareTo(db);
              if (cmp == 0) {
                final ida =
                    int.tryParse(a['prenatal_checkup_id']?.toString() ?? '') ??
                    0;
                final idb =
                    int.tryParse(b['prenatal_checkup_id']?.toString() ?? '') ??
                    0;
                cmp = ida.compareTo(idb);
              }
              return _checkupSort == 'asc' ? cmp : -cmp;
            });
            return list;
          }

          List<Map<String, dynamic>> sortByDate(
            dynamic v,
            String field,
            String order,
          ) {
            final list = listOrEmpty(
              v,
            ).whereType<Map<String, dynamic>>().toList();
            list.sort((a, b) {
              final da = _parseDate(a[field]);
              final db = _parseDate(b[field]);
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              var cmp = da.compareTo(db);
              if (cmp == 0) {
                final ida = int.tryParse(
                  a['prenatal_checkup_id']?.toString() ?? '',
                );
                final idb = int.tryParse(
                  b['prenatal_checkup_id']?.toString() ?? '',
                );
                if (ida != null && idb != null) {
                  cmp = ida.compareTo(idb);
                }
              }
              return order == 'asc' ? cmp : -cmp;
            });
            return list;
          }

          Widget metricTile({
            required String title,
            required String value,
            required IconData icon,
            Color? color,
          }) {
            final accent = color ?? AppColors.brandPrimary;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderPrimary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          Widget chartCard({
            required String title,
            required Widget chart,
            String? subtitle,
          }) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderPrimary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandText,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 190, child: chart),
                ],
              ),
            );
          }

          Widget emptyChart(String label) {
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          LineChartData lineChartData({
            required List<LineChartBarData> lines,
            required List<String> labels,
            double? minY,
            double? maxY,
          }) {
            return LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[index],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: lines,
            );
          }

          Widget statChip(String label, String value) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Text('$label: $value'),
            );
          }

          Widget tagChip(String text) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Text(text, style: const TextStyle(fontSize: 12)),
            );
          }

          Widget recordCard({
            required IconData icon,
            required String title,
            String? subtitle,
            List<String> tags = const [],
            VoidCallback? onTap,
          }) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppColors.brandText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (subtitle != null && subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags.map(tagChip).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          }

                    Widget detailRow(String label, String value) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(flex: 5, child: Text(value)),
                ],
              ),
            );
          }

          void showRecordSheet({
            required String title,
            required List<MapEntry<String, String>> rows,
            IconData icon = Icons.receipt_long,
            String? subtitle,
            String? imageUrl,
            String? aiAnalysis,
          }) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: AppColors.brandText),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (subtitle != null && subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Container(
                                color: AppColors.bgSecondary,
                                child: const Center(
                                  child: Text('Image not available'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.faintWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: Column(
                          children: rows
                              .map((r) => detailRow(r.key, r.value))
                              .toList(),
                        ),
                      ),
                      if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildAIAnalysisSection(
                          title.contains('Checkup')
                              ? 'Prenatal Checkup Analysis'
                              : title.contains('Ultrasound')
                                  ? 'Ultrasound Analysis'
                                  : 'Lab Test Analysis',
                          aiAnalysis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          final currentPreg = m['current_pregnancy'];
          final pastPregs = listOrEmpty(m['past_pregnancies']);
          final medicalConditions = listOrEmpty(m['medical_conditions']);
          final allergies = listOrEmpty(m['allergies']);
          final emergencyContacts = listOrEmpty(m['emergency_contacts']);
          final motherMeds = listOrEmpty(m['mother_medications']);
          final givenMeds = listOrEmpty(m['given_medications']);
          final children = listOrEmpty(m['children']);

          List<String> takenTdDosesFromCheckups(List<dynamic> raw) {
            final taken = <String>{};
            for (final entry in raw.whereType<Map<String, dynamic>>()) {
              final doseRaw = entry['td_vaccine_dose']?.toString().trim();
              if (doseRaw == null || doseRaw.isEmpty) continue;
              final normalized = doseRaw
                  .replaceAll(RegExp(r'\s+'), '')
                  .toUpperCase();
              switch (normalized) {
                case 'TD1':
                  taken.add('TD 1');
                  break;
                case 'TD2':
                  taken.add('TD 2');
                  break;
                case 'TD3':
                  taken.add('TD 3');
                  break;
                case 'TD4':
                  taken.add('TD 4');
                  break;
                case 'TD5':
                  taken.add('TD 5');
                  break;
                default:
                  taken.add(doseRaw);
              }
            }
            final list = taken.toList();
            list.sort();
            return list;
          }

          Future<void> addPrenatalCheckup() async {
            final pregnancyId =
                currentPreg?['pregnancy_id'] ?? m['pregnancy_id'];
            if (pregnancyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No ongoing pregnancy found.')),
              );
              return;
            }

            DateTime? lmp;
            final lmpRaw =
                currentPreg?['last_menstrual_period'] ??
                m['last_menstrual_period'];
            if (lmpRaw != null) {
              lmp = DateTime.tryParse(lmpRaw.toString());
            }

            final added = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddPrenatalCheckupScreen(
                  motherId: widget.motherId,
                  pregnancyId: int.parse(pregnancyId.toString()),
                  lmp: lmp,
                  motherWeight: null,
                  takenTdDoses: takenTdDosesFromCheckups(
                    listOrEmpty(currentPreg?['checkups']),
                  ),
                ),
              ),
            );

            if (added == true) {
              await _refresh();
            }
          }

          Future<void> startNewPregnancy() async {
            final started = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StartPregnancyScreen(
                  motherId: widget.motherId,
                  motherName: fullName,
                ),
              ),
            );

            if (started == true) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pregnancy started.')),
              );
              await _refresh();
            }
          }

          Future<void> concludePregnancy() async {
            if (currentPreg == null) return;
            String outcome = 'live_birth';
            DateTime? outcomeDate;
            DateTime? deliveryDate;
            String? deliveryMethod;
            String? placeOfDelivery;
            double? gestAge;
            final gestAgeController = TextEditingController();
            final placeCtrl = TextEditingController();
            final lmpDate = _parseDate(
              currentPreg['last_menstrual_period'] ??
                  m['last_menstrual_period'],
            );

            void recomputeGestAge() {
              if (lmpDate == null) return;
              final reference =
                  (outcome == 'live_birth' || outcome == 'stillbirth')
                  ? (deliveryDate ?? outcomeDate ?? DateTime.now())
                  : (outcomeDate ?? DateTime.now());
              final weeks = reference.difference(lmpDate).inDays / 7;
              final rounded = double.parse(weeks.toStringAsFixed(1));
              gestAge = rounded;
              gestAgeController.text = rounded.toStringAsFixed(1);
            }

            recomputeGestAge();

            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (ctx, setModal) {
                    Future<void> pickDate(bool isDelivery) async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setModal(() {
                          if (isDelivery) {
                            deliveryDate = picked;
                            outcomeDate = picked;
                          } else {
                            outcomeDate = picked;
                          }
                          recomputeGestAge();
                        });
                      }
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                        top: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag),
                              const SizedBox(width: 8),
                              const Text(
                                'Conclude Pregnancy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: outcome,
                            decoration: const InputDecoration(
                              labelText: 'Outcome',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'live_birth',
                                child: Text('Live birth'),
                              ),
                              DropdownMenuItem(
                                value: 'stillbirth',
                                child: Text('Stillbirth'),
                              ),
                              DropdownMenuItem(
                                value: 'miscarriage',
                                child: Text('Miscarriage'),
                              ),
                              DropdownMenuItem(
                                value: 'abortion',
                                child: Text('Abortion'),
                              ),
                              DropdownMenuItem(
                                value: 'ectopic',
                                child: Text('Ectopic'),
                              ),
                            ],
                            onChanged: (v) => setModal(() {
                              outcome = v ?? outcome;
                              recomputeGestAge();
                            }),
                          ),
                          const SizedBox(height: 8),
                          if (outcome == 'live_birth' ||
                              outcome == 'stillbirth') ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Delivery date'),
                              subtitle: Text(
                                deliveryDate == null
                                    ? 'Pick date'
                                    : DateFormat(
                                        'MMM d, yyyy',
                                      ).format(deliveryDate!),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => pickDate(true),
                            ),
                            TextField(
                              controller: placeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Place of delivery',
                              ),
                              onChanged: (v) => placeOfDelivery = v.trim(),
                            ),
                            DropdownButtonFormField<String>(
                              value: deliveryMethod,
                              decoration: const InputDecoration(
                                labelText: 'Delivery method',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'NSD',
                                  child: Text('Normal Spontaneous Delivery'),
                                ),
                                DropdownMenuItem(
                                  value: 'CS',
                                  child: Text('Cesarean Section'),
                                ),
                                DropdownMenuItem(
                                  value: 'Instrumental',
                                  child: Text('Instrumental'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setModal(() => deliveryMethod = v),
                            ),
                          ] else ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Outcome date'),
                              subtitle: Text(
                                outcomeDate == null
                                    ? 'Pick date'
                                    : DateFormat(
                                        'MMM d, yyyy',
                                      ).format(outcomeDate!),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => pickDate(false),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: gestAgeController,
                            decoration: const InputDecoration(
                              labelText: 'AOG at end (weeks)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => gestAge = double.tryParse(v),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (outcome == 'live_birth' ||
                                  outcome == 'stillbirth') {
                                if (deliveryDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select the delivery date.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              } else {
                                if (outcomeDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select the outcome date.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }

                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Confirm conclude'),
                                  content: const Text(
                                    'This will end the current pregnancy. Proceed?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Yes, conclude'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              try {
                                final token = await AuthStorage.getToken();
                                if (token == null)
                                  throw Exception('Not authenticated');

                                final placeValue = placeCtrl.text.trim();
                                final normalizedPlace = placeValue.isEmpty
                                    ? (placeOfDelivery?.trim().isEmpty ?? true
                                          ? null
                                          : placeOfDelivery?.trim())
                                    : placeValue;
                                final normalizedMethod =
                                    deliveryMethod?.trim().isEmpty ?? true
                                    ? null
                                    : deliveryMethod?.trim();
                                final normalizedOutcomeDate =
                                    (outcome == 'live_birth' ||
                                        outcome == 'stillbirth')
                                    ? deliveryDate
                                    : outcomeDate;

                                final res = await http.post(
                                  Uri.parse(
                                    'https://inaagapay.alwaysdata.net/api/midwife/conclude_pregnancy.php',
                                  ),
                                  headers: {
                                    'Authorization': 'Bearer $token',
                                    'Accept': 'application/json',
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode({
                                    'pregnancy_id': currentPreg['pregnancy_id'],
                                    'outcome': outcome,
                                    'outcome_date': normalizedOutcomeDate
                                        ?.toIso8601String(),
                                    'delivery_date': deliveryDate
                                        ?.toIso8601String(),
                                    'delivery_method': normalizedMethod,
                                    'place_of_delivery': normalizedPlace,
                                    'gestational_age_at_end': gestAge,
                                  }),
                                );

                                final decoded = jsonDecode(res.body);
                                if (decoded['success'] != true) {
                                  throw Exception(
                                    decoded['message'] ?? 'Failed to conclude',
                                  );
                                }
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pregnancy concluded.'),
                                  ),
                                );
                                await _refresh();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Conclude pregnancy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
            gestAgeController.dispose();
            placeCtrl.dispose();
          }

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: NestedScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      headerSliverBuilder: (context, _) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFECF3),
                                        Color(0xFFFFF7FB),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: AppColors.borderPrimary,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.06,
                                              ),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 34,
                                          color: AppColors.brandText,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName.isNotEmpty
                                                  ? fullName
                                                  : 'Unnamed Mother',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              m['phone_number'] ?? '—',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                statChip(
                                                  'Status',
                                                  '${m['status'] ?? '—'}',
                                                ),
                                                statChip(
                                                  'Risk',
                                                  '${m['pregnancy_risk_level'] ?? '—'}',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    statChip(
                                      'Children',
                                      '${m['children_count'] ?? 0}',
                                    ),
                                    statChip(
                                      'Barangay',
                                      '${m['barangay'] ?? '—'}',
                                    ),
                                    statChip(
                                      'City',
                                      '${m['city_municipality'] ?? '—'}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (_) {
                                    final risk =
                                        riskData(m['pregnancy_risk']) ??
                                        riskData(
                                          m['current_pregnancy']?['risk'],
                                        );
                                    if (risk == null) return const SizedBox();
                                    final level = (risk['level'] ?? '—')
                                        .toString()
                                        .toLowerCase();
                                    Color cardColor;
                                    switch (level) {
                                      case 'high':
                                        cardColor = Colors.red.shade50;
                                        break;
                                      case 'medium':
                                        cardColor = Colors.orange.shade50;
                                        break;
                                      default:
                                        cardColor = Colors.green.shade50;
                                    }
                                    final reasons = listOrEmpty(
                                      risk['factors'],
                                    ).whereType<String>().toList();
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.warning),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Risk: ${level.toUpperCase()} (${risk['score'] ?? '—'})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  _riskExpanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                ),
                                                onPressed: () => setState(
                                                  () => _riskExpanded =
                                                      !_riskExpanded,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            risk['note'] ?? 'Risk summary',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (_riskExpanded &&
                                              reasons.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: reasons
                                                  .map((r) => tagChip(r))
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                TabBar(
                                  controller: _tabController,
                                  tabs: const [
                                    Tab(text: 'Overview'),
                                    Tab(text: 'Current'),
                                    Tab(text: 'History'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          // ================= OVERVIEW =================
                          SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                infoCard('Quick Actions', [
                                  if (currentPreg == null) ...[
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'No ongoing pregnancy.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: startNewPregnancy,
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text(
                                            'Start New Pregnancy',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Set LMP and EDD to begin tracking.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: addPrenatalCheckup,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Checkup'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.pink,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final added = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AddUltrasoundPage(
                                                      motherId: widget.motherId,
                                                    ),
                                              ),
                                            );
                                            if (added == true) await _refresh();
                                          },
                                          icon: const Icon(Icons.monitor_heart),
                                          label: const Text('Add Ultrasound'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final added = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddLabTestPage(
                                                  motherId: widget.motherId,
                                                ),
                                              ),
                                            );
                                            if (added == true) await _refresh();
                                          },
                                          icon: const Icon(Icons.science),
                                          label: const Text('Add Lab Test'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: concludePregnancy,
                                          icon: const Icon(Icons.flag),
                                          label: const Text('Conclude'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ]),
                                infoCard('Personal Information', [
                                  field('Phone', m['phone_number']),
                                  field('Email', m['email_address']),
                                  field('Birthdate', m['birthdate']),
                                ]),
                                infoCard('Address', [
                                  field('House No.', m['house_number']),
                                  field('Street', m['street']),
                                  field('Barangay', m['barangay']),
                                  field('City', m['city_municipality']),
                                  field('Province', m['province']),
                                ]),
                                infoCard('Medical Info', [
                                  field('Height (cm)', m['height']),
                                  field('Weight (kg)', m['weight']),
                                  field('Blood Type', m['blood_type']),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      'Medical Conditions (${medicalConditions.length})',
                                    ),
                                    children: medicalConditions.isEmpty
                                        ? [
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Text('No records.'),
                                            ),
                                          ]
                                        : medicalConditions.map((c) {
                                            return ListTile(
                                              dense: true,
                                              title: Text(
                                                c['condition_name'] ?? '—',
                                              ),
                                              subtitle: Text(
                                                '${c['status'] ?? 'active'} • ${_fmtDate(c['diagnosis_date']) ?? '—'}',
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      'Allergies (${allergies.length})',
                                    ),
                                    children: allergies.isEmpty
                                        ? [
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Text('No records.'),
                                            ),
                                          ]
                                        : allergies.map((a) {
                                            return ListTile(
                                              dense: true,
                                              title: Text(a['allergen'] ?? '—'),
                                              subtitle: Text(
                                                '${a['status'] ?? 'active'} • ${_fmtDate(a['diagnosis_date']) ?? '—'}',
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                ]),
                                infoCard(
                                  'Emergency Contacts (${emergencyContacts.length})',
                                  [
                                    if (emergencyContacts.isEmpty)
                                      const Text('No emergency contacts yet.'),
                                    ...emergencyContacts.map((c) {
                                      final name =
                                          [
                                                c['first_name'],
                                                c['middle_name'],
                                                c['last_name'],
                                                c['extension_name'],
                                              ]
                                              .where(
                                                (e) =>
                                                    e != null &&
                                                    e
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty,
                                              )
                                              .join(' ');
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          name.isEmpty ? 'Unnamed' : name,
                                        ),
                                        subtitle: Text(
                                          '${c['phone_number'] ?? '—'} • ${c['affiliation'] ?? '—'}',
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                infoCard(
                                  'Medication Plans (${motherMeds.length})',
                                  [
                                    if (motherMeds.isEmpty)
                                      const Text(
                                        'No medication plans recorded.',
                                      ),
                                    ...motherMeds.map((mPlan) {
                                      final dates = [
                                        _fmtDate(mPlan['start_date']),
                                        _fmtDate(mPlan['end_date']),
                                      ].whereType<String>().join(' to ');
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          mPlan['mother_medication_name'] ??
                                              '—',
                                        ),
                                        subtitle: Text(
                                          [
                                            if ((mPlan['frequency'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              'Freq: ${mPlan['frequency']}',
                                            if ((mPlan['quantity'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              'Qty: ${mPlan['quantity']}',
                                            if (dates.isNotEmpty) dates,
                                          ].join(' · '),
                                        ),
                                        trailing: Text(
                                          (mPlan['status'] ?? 'active')
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                infoCard(
                                  'Given Medications (${givenMeds.length})',
                                  [
                                    if (givenMeds.isEmpty)
                                      const Text('No given medications yet.'),
                                    ...givenMeds.map((g) {
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          g['given_medication_name'] ?? '—',
                                        ),
                                        subtitle: Text(
                                          [
                                            if (g['quantity'] != null)
                                              'Qty: ${g['quantity']}',
                                            if (_fmtDate(g['date_given']) !=
                                                null)
                                              _fmtDate(g['date_given'])!,
                                          ].join(' · '),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                infoCard('Children (${children.length})', [
                                  TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Search children...',
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _childQuery = v),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _childSort,
                                    decoration: const InputDecoration(
                                      labelText: 'Sort by',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'recent',
                                        child: Text('Most recent'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'name',
                                        child: Text('Name A–Z'),
                                      ),
                                    ],
                                    onChanged: (v) => setState(
                                      () => _childSort = v ?? 'recent',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (_) {
                                      var filtered = children
                                          .whereType<Map<String, dynamic>>()
                                          .where((c) {
                                            final name =
                                                [
                                                      c['first_name'],
                                                      c['middle_name'],
                                                      c['last_name'],
                                                      c['extension_name'],
                                                    ]
                                                    .where(
                                                      (e) =>
                                                          e != null &&
                                                          e
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty,
                                                    )
                                                    .join(' ')
                                                    .toLowerCase();
                                            return name.contains(
                                              _childQuery.toLowerCase(),
                                            );
                                          })
                                          .toList();

                                      final totalCount = children.length;
                                      final showingCount = filtered.length;

                                      if (_childSort == 'name') {
                                        filtered.sort((a, b) {
                                          final na =
                                              ((a['last_name'] ?? '') +
                                                      (a['first_name'] ?? ''))
                                                  .toString()
                                                  .toLowerCase();
                                          final nb =
                                              ((b['last_name'] ?? '') +
                                                      (b['first_name'] ?? ''))
                                                  .toString()
                                                  .toLowerCase();
                                          return na.compareTo(nb);
                                        });
                                      }

                                      if (filtered.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text('No children found.'),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Showing $showingCount of $totalCount',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...filtered.map((c) {
                                            final name =
                                                [
                                                      c['first_name'],
                                                      c['middle_name'],
                                                      c['last_name'],
                                                      c['extension_name'],
                                                    ]
                                                    .where(
                                                      (e) =>
                                                          e != null &&
                                                          e
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty,
                                                    )
                                                    .join(' ');

                                            final subtitle = [
                                              if (_fmtDate(c['added_at']) !=
                                                  null)
                                                'Added: ${_fmtDate(c['added_at'])}',
                                              if ((c['sex'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                'Sex: ${c['sex']}',
                                            ].where((e) => e.isNotEmpty).join(' · ');

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      AppColors.borderPrimary,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.03),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: ListTile(
                                                leading: const CircleAvatar(
                                                  backgroundColor:
                                                      AppColors.bgSecondary,
                                                  child: Icon(
                                                    Icons.child_care,
                                                    color:
                                                        AppColors.brandPrimary,
                                                  ),
                                                ),
                                                title: Text(
                                                  name.isEmpty
                                                      ? 'Unnamed'
                                                      : name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  subtitle.isEmpty
                                                      ? '—'
                                                      : subtitle,
                                                ),
                                                trailing: const Icon(
                                                  Icons.chevron_right,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                onTap: () {
                                                  final id = int.tryParse(
                                                    c['child_id']?.toString() ??
                                                        '',
                                                  );
                                                  if (id != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ChildProfilePage(
                                                              childId: id,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                                ]),
                              ],
                            ),
                          ),

                          // ================= CURRENT PREGNANCY =================
                          SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: currentPreg == null
                                ? infoCard('Current Pregnancy', [
                                    const Text('No ongoing pregnancy found.'),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: startNewPregnancy,
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Start New Pregnancy'),
                                    ),
                                  ])
                                : Builder(
                                    builder: (_) {
                                      final checkups = sortedCheckups(
                                        currentPreg['checkups'],
                                      );
                                      final lastCheckup = checkups.isNotEmpty
                                          ? checkups.last
                                          : null;
                                      final lastCheckupDate = _fmtDateTime(
                                        lastCheckup?['checkup_datetime'] ??
                                            lastCheckup?['checkup_date'],
                                      );
                                      final nextSchedule = _fmtDate(
                                        lastCheckup?['next_schedule'],
                                      );

                                      final lmp = _parseDate(
                                        currentPreg['last_menstrual_period'],
                                      );
                                      final edd = _parseDate(
                                        currentPreg['expected_date_of_delivery'],
                                      );
                                      final now = DateTime.now();
                                      final gestWeeks = lmp == null
                                          ? null
                                          : (now.difference(lmp).inDays / 7)
                                                .floor();
                                      final daysToEdd = edd
                                          ?.difference(now)
                                          .inDays;

                                      Widget weightChart() {
                                        final points = <FlSpot>[];
                                        final labels = <String>[];
                                        for (final c in checkups) {
                                          final w = _toDouble(
                                            c['checkup_weight'],
                                          );
                                          if (w == null) continue;
                                          points.add(
                                            FlSpot(points.length.toDouble(), w),
                                          );
                                          labels.add(
                                            _shortDate(
                                              c['checkup_datetime'] ??
                                                  c['checkup_date'],
                                            ),
                                          );
                                        }
                                        if (points.length < 2) {
                                          return emptyChart('Not enough data');
                                        }
                                        final minY = points
                                            .map((e) => e.y)
                                            .reduce((a, b) => a < b ? a : b);
                                        final maxY = points
                                            .map((e) => e.y)
                                            .reduce((a, b) => a > b ? a : b);
                                        return LineChart(
                                          lineChartData(
                                            lines: [
                                              LineChartBarData(
                                                spots: points,
                                                isCurved: true,
                                                color: AppColors.brandPrimary,
                                                barWidth: 3,
                                                dotData: FlDotData(show: true),
                                              ),
                                            ],
                                            labels: labels,
                                            minY: (minY - 1),
                                            maxY: (maxY + 1),
                                          ),
                                        );
                                      }

                                      Widget bpChart() {
                                        final sys = <FlSpot>[];
                                        final dia = <FlSpot>[];
                                        final labels = <String>[];
                                        for (final c in checkups) {
                                          final s = _toDouble(
                                            c['blood_pressure_systolic'],
                                          );
                                          final d = _toDouble(
                                            c['blood_pressure_diastolic'],
                                          );
                                          if (s == null || d == null) continue;
                                          final x = sys.length.toDouble();
                                          sys.add(FlSpot(x, s));
                                          dia.add(FlSpot(x, d));
                                          labels.add(
                                            _shortDate(
                                              c['checkup_datetime'] ??
                                                  c['checkup_date'],
                                            ),
                                          );
                                        }
                                        if (sys.length < 2) {
                                          return emptyChart('Not enough data');
                                        }
                                        final values = [
                                          ...sys.map((e) => e.y),
                                          ...dia.map((e) => e.y),
                                        ];
                                        final minY = values.reduce(
                                          (a, b) => a < b ? a : b,
                                        );
                                        final maxY = values.reduce(
                                          (a, b) => a > b ? a : b,
                                        );
                                        return LineChart(
                                          lineChartData(
                                            lines: [
                                              LineChartBarData(
                                                spots: sys,
                                                isCurved: true,
                                                color: AppColors.brandPrimary,
                                                barWidth: 3,
                                                dotData: FlDotData(show: false),
                                              ),
                                              LineChartBarData(
                                                spots: dia,
                                                isCurved: true,
                                                color: AppColors.brandAccent,
                                                barWidth: 3,
                                                dotData: FlDotData(show: false),
                                              ),
                                            ],
                                            labels: labels,
                                            minY: (minY - 5),
                                            maxY: (maxY + 5),
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          infoCard('Pregnancy Insights', [
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                SizedBox(
                                                  width:
                                                      (MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          56) /
                                                      2,
                                                  child: metricTile(
                                                    title: 'Gestation',
                                                    value: gestWeeks == null
                                                        ? '—'
                                                        : '$gestWeeks wks',
                                                    icon: Icons.timeline,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width:
                                                      (MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          56) /
                                                      2,
                                                  child: metricTile(
                                                    title: 'Days to EDD',
                                                    value: daysToEdd == null
                                                        ? '—'
                                                        : daysToEdd.toString(),
                                                    icon: Icons.event_available,
                                                    color: AppColors.warning,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width:
                                                      (MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          56) /
                                                      2,
                                                  child: metricTile(
                                                    title: 'Checkups',
                                                    value: checkups.length
                                                        .toString(),
                                                    icon: Icons.fact_check,
                                                    color: AppColors.success,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width:
                                                      (MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          56) /
                                                      2,
                                                  child: metricTile(
                                                    title: 'Last Checkup',
                                                    value:
                                                        lastCheckupDate ?? '—',
                                                    icon: Icons.event,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (nextSchedule != null &&
                                                nextSchedule.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.brandPrimary
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppColors
                                                        .brandPrimary
                                                        .withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_today,
                                                      size: 18,
                                                      color:
                                                          AppColors.brandText,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Next checkup: $nextSchedule',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ]),
                                          chartCard(
                                            title: 'Weight Trend (kg)',
                                            subtitle:
                                                'From recorded prenatal checkups',
                                            chart: weightChart(),
                                          ),
                                          chartCard(
                                            title: 'Blood Pressure Trend',
                                            subtitle: 'Systolic vs Diastolic',
                                            chart: bpChart(),
                                          ),
                                          infoCard('Current Pregnancy', [
                                            field(
                                              'Risk Level',
                                              currentPreg['pregnancy_risk_level'],
                                            ),
                                            field(
                                              'Status',
                                              currentPreg['status'],
                                            ),
                                            field(
                                              'LMP',
                                              _fmtDate(
                                                currentPreg['last_menstrual_period'],
                                              ),
                                            ),
                                            field(
                                              'EDD',
                                              _fmtDate(
                                                currentPreg['expected_date_of_delivery'],
                                              ),
                                            ),
                                          ]),
                                          infoCard('Checkups', [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Sort',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                DropdownButton<String>(
                                                  value: _checkupSort,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'desc',
                                                      child: Text(
                                                        'Newest first',
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'asc',
                                                      child: Text(
                                                        'Oldest first',
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (v) => setState(
                                                    () => _checkupSort =
                                                        v ?? 'desc',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ...sortedCheckups(
                                              currentPreg['checkups'],
                                            ).map((c) {
                                              final date =
                                                  _fmtDateTime(
                                                    c['checkup_datetime'] ??
                                                        c['checkup_date'],
                                                  ) ??
                                                  '—';
                                              final bpSys = _fmtValue(
                                                c['blood_pressure_systolic'],
                                              );
                                              final bpDia = _fmtValue(
                                                c['blood_pressure_diastolic'],
                                              );
                                              final bp =
                                                  (bpSys == '—' && bpDia == '—')
                                                  ? null
                                                  : 'BP: $bpSys/$bpDia';
                                              final aog = _fmtValue(
                                                c['age_of_gestation'],
                                              );
                                              final wt = _fmtValue(
                                                c['checkup_weight'],
                                              );
                                              final tdDose = _fmtValue(
                                                c['td_vaccine_dose'],
                                              );
                                              final ferrousGiven =
                                                  int.tryParse(
                                                    c['ferrous_given']
                                                            ?.toString() ??
                                                        '0',
                                                  ) ??
                                                  0;
                                              final calciumGiven =
                                                  int.tryParse(
                                                    c['calcium_given']
                                                            ?.toString() ??
                                                        '0',
                                                  ) ??
                                                  0;
                                              final tags = <String>[];
                                              if (bp != null) tags.add(bp);
                                              if (aog != '—')
                                                tags.add('AOG: $aog');
                                              if (wt != '—')
                                                tags.add('Wt: $wt kg');
                                              if (tdDose != '—')
                                                tags.add('TD: $tdDose');
                                              if (ferrousGiven > 0)
                                                tags.add(
                                                  'Ferrous+FA: $ferrousGiven',
                                                );
                                              if (calciumGiven > 0)
                                                tags.add(
                                                  'Calcium: $calciumGiven',
                                                );

                                              final next = _fmtDate(
                                                c['next_schedule'],
                                              );
                                              return recordCard(
                                                icon: Icons.medical_services,
                                                title: 'Checkup • $date',
                                                subtitle:
                                                    (next == null ||
                                                        next.isEmpty)
                                                    ? null
                                                    : 'Next: $next',
                                                tags: tags,
                                                onTap: () => showRecordSheet(
                                                  title: 'Checkup Details',
                                                  subtitle: date,
                                                  icon: Icons.medical_services,
                                                  rows: [
                                                    MapEntry(
                                                      'Checkup Date',
                                                      _fmtValue(
                                                        _fmtDateTime(
                                                          c['checkup_datetime'] ??
                                                              c['checkup_date'],
                                                        ),
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Age of Gestation',
                                                      _fmtValue(
                                                        c['age_of_gestation'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Weight (kg)',
                                                      _fmtValue(
                                                        c['checkup_weight'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Blood Pressure',
                                                      '${_fmtValue(c['blood_pressure_systolic'])}/${_fmtValue(c['blood_pressure_diastolic'])}',
                                                    ),
                                                    MapEntry(
                                                      'TD Vaccine Dose',
                                                      _fmtValue(
                                                        c['td_vaccine_dose'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Ferrous + FA Given',
                                                      ferrousGiven > 0
                                                          ? '$ferrousGiven'
                                                          : '—',
                                                    ),
                                                    MapEntry(
                                                      'Calcium Given',
                                                      calciumGiven > 0
                                                          ? '$calciumGiven'
                                                          : '—',
                                                    ),
                                                    MapEntry(
                                                      'Fetal Position',
                                                      _fmtValue(
                                                        c['fetal_position'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Fetal Heart Beat',
                                                      _fmtValue(
                                                        c['fetal_heart_beat'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Fetal Heart Tone',
                                                      _fmtValue(
                                                        c['fetal_heart_tone'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Edema',
                                                      _fmtValue(c['edema']),
                                                    ),
                                                    MapEntry(
                                                      'Remarks',
                                                      _fmtValue(c['remarks']),
                                                    ),
                                                    MapEntry(
                                                      'Next Schedule',
                                                      _fmtValue(
                                                        _fmtDate(
                                                          c['next_schedule'],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  aiAnalysis: _generatePrenatalAIInsights(c),
                                                ),
                                              );
                                            }),
                                            if (listOrEmpty(
                                              currentPreg['checkups'],
                                            ).isEmpty)
                                              const Text('No checkups yet.'),
                                          ]),
                                          infoCard('Ultrasounds', [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Sort',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                DropdownButton<String>(
                                                  value: _usSort,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'desc',
                                                      child: Text(
                                                        'Newest first',
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'asc',
                                                      child: Text(
                                                        'Oldest first',
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (v) => setState(
                                                    () => _usSort = v ?? 'desc',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ...sortByDate(
                                              currentPreg['ultrasounds'],
                                              'ultrasound_date',
                                              _usSort,
                                            ).map((u) {
                                              final date =
                                                  _fmtDate(
                                                    u['ultrasound_date'],
                                                  ) ??
                                                  '—';
                                              final imageUrl = resolveImageUrl(
                                                u['ultrasound_image'],
                                              );
                                              final tags = <String>[];
                                              final worker = _fmtValue(
                                                u['health_worker_name'],
                                              );
                                              if (worker != '—') {
                                                tags.add(worker);
                                              }
                                              if (imageUrl != null) {
                                                tags.add('Image');
                                              }
                                              return recordCard(
                                                icon: Icons.monitor_heart,
                                                title: 'Ultrasound • $date',
                                                subtitle: _fmtValue(
                                                  u['ultrasound_location'],
                                                ),
                                                tags: tags,
                                                onTap: () => showRecordSheet(
                                                  title: 'Ultrasound Details',
                                                  subtitle: date,
                                                  icon: Icons.monitor_heart,
                                                  imageUrl: imageUrl,
                                                  rows: [
                                                    MapEntry(
                                                      'Date',
                                                      _fmtValue(
                                                        _fmtDate(
                                                          u['ultrasound_date'],
                                                        ),
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Location',
                                                      _fmtValue(
                                                        u['ultrasound_location'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Health Worker',
                                                      _fmtValue(
                                                        u['health_worker_name'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Institution',
                                                      _fmtValue(
                                                        u['health_worker_institution'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Profession',
                                                      _fmtValue(
                                                        u['health_worker_profession'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Remarks',
                                                      _fmtValue(u['remarks']),
                                                    ),
                                                  ],
                                                  aiAnalysis: _generateUltrasoundAIInsights(u),
                                                ),
                                              );
                                            }),
                                            if (listOrEmpty(
                                              currentPreg['ultrasounds'],
                                            ).isEmpty)
                                              const Text('No ultrasounds yet.'),
                                          ]),
                                          infoCard('Lab Tests', [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Sort',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                DropdownButton<String>(
                                                  value: _labSort,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'desc',
                                                      child: Text(
                                                        'Newest first',
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'asc',
                                                      child: Text(
                                                        'Oldest first',
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (v) => setState(
                                                    () =>
                                                        _labSort = v ?? 'desc',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ...sortByDate(
                                              currentPreg['lab_tests'],
                                              'lab_test_date',
                                              _labSort,
                                            ).map((l) {
                                              final date =
                                                  _fmtDate(l['lab_test_date']) ??
                                                  '—';
                                              final imageUrl = resolveImageUrl(
                                                l['lab_test_image'],
                                              );
                                              final tags = <String>[];
                                              final worker = _fmtValue(
                                                l['health_worker_name'],
                                              );
                                              if (worker != '—') {
                                                tags.add(worker);
                                              }
                                              if (imageUrl != null) {
                                                tags.add('Image');
                                              }
                                              return recordCard(
                                                icon: Icons.science,
                                                title:
                                                    '${l['lab_test_type'] ?? 'Lab Test'} • $date',
                                                subtitle: _fmtValue(
                                                  l['lab_test_location'],
                                                ),
                                                tags: tags,
                                                onTap: () => showRecordSheet(
                                                  title: 'Lab Test Details',
                                                  subtitle: date,
                                                  icon: Icons.science,
                                                  imageUrl: imageUrl,
                                                  rows: [
                                                    MapEntry(
                                                      'Type',
                                                      _fmtValue(
                                                        l['lab_test_type'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Date',
                                                      _fmtValue(
                                                        _fmtDate(
                                                          l['lab_test_date'],
                                                        ),
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Location',
                                                      _fmtValue(
                                                        l['lab_test_location'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Health Worker',
                                                      _fmtValue(
                                                        l['health_worker_name'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Institution',
                                                      _fmtValue(
                                                        l['health_worker_institution'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Profession',
                                                      _fmtValue(
                                                        l['health_worker_profession'],
                                                      ),
                                                    ),
                                                    MapEntry(
                                                      'Remarks',
                                                      _fmtValue(l['remarks']),
                                                    ),
                                                  ],
                                                  aiAnalysis: _generateLabTestAIInsights(l),
                                                ),
                                              );
                                            }),
                                            if (listOrEmpty(
                                              currentPreg['lab_tests'],
                                            ).isEmpty)
                                              const Text('No lab tests yet.'),
                                          ]),
                                        ],
                                      );
                                    },
                                  ),
                          ),

                          // ================= HISTORY =================
                          SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: pastPregs.isEmpty
                                ? infoCard('Past Pregnancies', const [
                                    Text('No past pregnancies recorded.'),
                                  ])
                                : Column(
                                    children: pastPregs.map((p) {
                                      final delivery = p['delivery'];
                                      final outcomeLabel = formatOutcome(
                                        p['outcome'],
                                      );
                                      final outcomeDate =
                                          _fmtDate(p['outcome_date']) ??
                                              _fmtDate(delivery?['delivery_date']);
                                      return infoCard('Pregnancy • $outcomeLabel', [
                                        field('Outcome Date', outcomeDate),
                                        field(
                                          'Gestational Age',
                                          p['gestational_age_at_end'],
                                        ),
                                        if (delivery != null) ...[
                                          field(
                                            'Delivery Place',
                                            delivery['place_of_delivery'],
                                          ),
                                          field(
                                            'Delivery Method',
                                            formatDeliveryMethod(
                                              delivery['delivery_method'],
                                            ),
                                          ),
                                        ],
                                        ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(
                                            'Checkups (${listOrEmpty(p['checkups']).length})',
                                          ),
                                          children:
                                              listOrEmpty(p['checkups']).isEmpty
                                              ? [
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: Text('No checkups.'),
                                                  ),
                                                ]
                                              : listOrEmpty(p['checkups']).map((
                                                  c,
                                                ) {
                                                  final date =
                                                      _fmtDateTime(
                                                        c['checkup_datetime'] ??
                                                            c['checkup_date'],
                                                      ) ??
                                                      '—';
                                                  final bpSys = _fmtValue(
                                                    c['blood_pressure_systolic'],
                                                  );
                                                  final bpDia = _fmtValue(
                                                    c['blood_pressure_diastolic'],
                                                  );
                                                  final bp =
                                                      (bpSys == '—' &&
                                                          bpDia == '—')
                                                      ? null
                                                      : 'BP: $bpSys/$bpDia';
                                                  final aog = _fmtValue(
                                                    c['age_of_gestation'],
                                                  );
                                                  final wt = _fmtValue(
                                                    c['checkup_weight'],
                                                  );
                                                  final tags = <String>[];
                                                  if (bp != null) tags.add(bp);
                                                  if (aog != '—') {
                                                    tags.add('AOG: $aog');
                                                  }
                                                  if (wt != '—')
                                                    tags.add('Wt: $wt kg');

                                                  return recordCard(
                                                    icon:
                                                        Icons.medical_services,
                                                    title: 'Checkup • $date',
                                                    tags: tags,
                                                    onTap: () => showRecordSheet(
                                                      title: 'Checkup Details',
                                                      subtitle: date,
                                                      icon: Icons
                                                          .medical_services,
                                                      rows: [
                                                        MapEntry(
                                                          'Checkup Date',
                                                          _fmtValue(
                                                            _fmtDate(
                                                              c['checkup_datetime'] ??
                                                                  c['checkup_date'],
                                                            ),
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Age of Gestation',
                                                          _fmtValue(
                                                            c['age_of_gestation'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Weight (kg)',
                                                          _fmtValue(
                                                            c['checkup_weight'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Blood Pressure',
                                                          '${_fmtValue(c['blood_pressure_systolic'])}/${_fmtValue(c['blood_pressure_diastolic'])}',
                                                        ),
                                                        MapEntry(
                                                          'Fetal Position',
                                                          _fmtValue(
                                                            c['fetal_position'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Fetal Heart Beat',
                                                          _fmtValue(
                                                            c['fetal_heart_beat'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Fetal Heart Tone',
                                                          _fmtValue(
                                                            c['fetal_heart_tone'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Edema',
                                                          _fmtValue(c['edema']),
                                                        ),
                                                        MapEntry(
                                                          'Remarks',
                                                          _fmtValue(
                                                            c['remarks'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Next Schedule',
                                                          _fmtValue(
                                                            _fmtDate(
                                                              c['next_schedule'],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      aiAnalysis: _generatePrenatalAIInsights(c),
                                                    ),
                                                  );
                                                }).toList(),
                                        ),
                                        ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(
                                            'Ultrasounds (${listOrEmpty(p['ultrasounds']).length})',
                                          ),
                                          children:
                                              listOrEmpty(
                                                p['ultrasounds'],
                                              ).isEmpty
                                              ? [
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: Text(
                                                      'No ultrasounds.',
                                                    ),
                                                  ),
                                                ]
                                              : listOrEmpty(
                                                  p['ultrasounds'],
                                                ).map((u) {
                                                  final date =
                                                      _fmtDate(
                                                        u['ultrasound_date'],
                                                      ) ??
                                                      '—';
                                                  final imageUrl =
                                                      resolveImageUrl(
                                                        u['ultrasound_image'],
                                                      );
                                                  final tags = <String>[];
                                                  final worker = _fmtValue(
                                                    u['health_worker_name'],
                                                  );
                                                  if (worker != '—')
                                                    tags.add(worker);
                                                  if (imageUrl != null) {
                                                    tags.add('Image');
                                                  }
                                                  return recordCard(
                                                    icon: Icons.monitor_heart,
                                                    title: 'Ultrasound • $date',
                                                    subtitle: _fmtValue(
                                                      u['ultrasound_location'],
                                                    ),
                                                    tags: tags,
                                                    onTap: () => showRecordSheet(
                                                      title:
                                                          'Ultrasound Details',
                                                      subtitle: date,
                                                      icon: Icons.monitor_heart,
                                                      imageUrl: imageUrl,
                                                      rows: [
                                                        MapEntry(
                                                          'Date',
                                                          _fmtValue(
                                                            _fmtDate(
                                                              u['ultrasound_date'],
                                                            ),
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Location',
                                                          _fmtValue(
                                                            u['ultrasound_location'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Health Worker',
                                                          _fmtValue(
                                                            u['health_worker_name'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Institution',
                                                          _fmtValue(
                                                            u['health_worker_institution'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Profession',
                                                          _fmtValue(
                                                            u['health_worker_profession'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Remarks',
                                                          _fmtValue(
                                                            u['remarks'],
                                                          ),
                                                        ),
                                                      ],
                                                      aiAnalysis: _generateUltrasoundAIInsights(u),
                                                    ),
                                                  );
                                                }).toList(),
                                        ),
                                        ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(
                                            'Lab Tests (${listOrEmpty(p['lab_tests']).length})',
                                          ),
                                          children:
                                              listOrEmpty(
                                                p['lab_tests'],
                                              ).isEmpty
                                              ? [
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: Text(
                                                      'No lab tests.',
                                                    ),
                                                  ),
                                                ]
                                              : listOrEmpty(
                                                  p['lab_tests'],
                                                ).map((l) {
                                                  final date =
                                                      _fmtDate(
                                                        l['lab_test_date'],
                                                      ) ??
                                                      '—';
                                                  final imageUrl =
                                                      resolveImageUrl(
                                                        l['lab_test_image'],
                                                      );
                                                  final tags = <String>[];
                                                  final worker = _fmtValue(
                                                    l['health_worker_name'],
                                                  );
                                                  if (worker != '—')
                                                    tags.add(worker);
                                                  if (imageUrl != null)
                                                    tags.add('Image');
                                                  return recordCard(
                                                    icon: Icons.science,
                                                    title:
                                                        '${l['lab_test_type'] ?? 'Lab Test'} • $date',
                                                    subtitle: _fmtValue(
                                                      l['lab_test_location'],
                                                    ),
                                                    tags: tags,
                                                    onTap: () => showRecordSheet(
                                                      title: 'Lab Test Details',
                                                      subtitle: date,
                                                      icon: Icons.science,
                                                      imageUrl: imageUrl,
                                                      rows: [
                                                        MapEntry(
                                                          'Type',
                                                          _fmtValue(
                                                            l['lab_test_type'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Date',
                                                          _fmtValue(
                                                            _fmtDate(
                                                              l['lab_test_date'],
                                                            ),
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Location',
                                                          _fmtValue(
                                                            l['lab_test_location'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Health Worker',
                                                          _fmtValue(
                                                            l['health_worker_name'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Institution',
                                                          _fmtValue(
                                                            l['health_worker_institution'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Profession',
                                                          _fmtValue(
                                                            l['health_worker_profession'],
                                                          ),
                                                        ),
                                                        MapEntry(
                                                          'Remarks',
                                                          _fmtValue(
                                                            l['remarks'],
                                                          ),
                                                        ),
                                                      ],
                                                      aiAnalysis: _generateLabTestAIInsights(l),
                                                    ),
                                                  );
                                                }).toList(),
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}