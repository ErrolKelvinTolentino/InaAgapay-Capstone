import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';

class MotherCheckupDetailsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Map<String, dynamic> checkupData;

  const MotherCheckupDetailsPage({
    super.key,
    required this.onBack,
    required this.checkupData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data
    final date = checkupData['checkup_date'] ?? 'Not specified';
    final gestation = checkupData['age_of_gestation'] != null
        ? '${checkupData['age_of_gestation']} weeks'
        : 'Not specified';
    final weight = checkupData['checkup_weight'] != null
        ? '${checkupData['checkup_weight']} kg'
        : 'Not recorded';
    final systolic = checkupData['blood_pressure_systolic'];
    final diastolic = checkupData['blood_pressure_diastolic'];
    final bp = systolic != null && diastolic != null
        ? '$systolic/$diastolic'
        : 'Not recorded';
    final fetalPosition = checkupData['fetal_position'] ?? 'Not specified';
    final fetalHeartBeat = checkupData['fetal_heart_beat'] != null
        ? '${checkupData['fetal_heart_beat']} bpm'
        : 'Not recorded';
    final fetalHeartTone = checkupData['fetal_heart_tone'] ?? 'Not specified';
    final tdVaccine = checkupData['td_vaccine_dose'] ?? 'Not administered';
    final givenMeds = (checkupData['given_medications'] as List?) ?? [];
    int? ferrousQty;
    int? calciumQty;
    for (final med in givenMeds) {
      if (med is! Map) continue;
      final name =
          (med['given_medication_name'] ??
                  med['medicine_name'] ??
                  med['medication_name'] ??
                  med['name'])
              ?.toString()
              .toLowerCase();
      final qty = int.tryParse(
        (med['quantity'] ?? med['qty'] ?? '').toString(),
      );
      if (name == null || qty == null) continue;
      if (name.contains('ferrous')) {
        ferrousQty = qty;
      } else if (name.contains('calcium')) {
        calciumQty = qty;
      }
    }
    final edema = checkupData['edema'] ?? 'Not specified';
    final remarks = checkupData['remarks'] ?? 'No remarks available';
    final nextSchedule = checkupData['next_schedule'];

    // Get midwife name
    final midwifeName = _getMidwifeName(checkupData);

    // Format dates
    final formattedDate = _formatDate(date);
    final formattedNextSchedule = nextSchedule != null
        ? _formatDate(nextSchedule)
        : 'Not scheduled';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(title: 'Checkup Details', onBack: onBack),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 📋 CHECKUP BASIC INFO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services_rounded,
                        color: AppColors.brandText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checkup Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandText,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _detailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: formattedDate,
                  ),
                  const SizedBox(height: 12),

                  _detailRow(
                    icon: Icons.timeline_rounded,
                    label: 'Gestation Age',
                    value: gestation,
                  ),
                  const SizedBox(height: 12),

                  _detailRow(
                    icon: Icons.person_rounded,
                    label: 'Midwife',
                    value: midwifeName,
                  ),
                  const SizedBox(height: 12),

                  _detailRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Next Schedule',
                    value: formattedNextSchedule,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🩺 VITAL SIGNS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.monitor_heart_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vital Signs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _detailRow(
                    icon: Icons.monitor_weight_rounded,
                    label: 'Weight',
                    value: weight,
                  ),
                  const SizedBox(height: 12),

                  if (systolic != null && diastolic != null)
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Blood Pressure',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        bp,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getBPStatusColor(
                                            _getBPStatus(systolic, diastolic),
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _getBPStatus(systolic, diastolic),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _getBPStatusColor(
                                              _getBPStatus(systolic, diastolic),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),

                  _detailRow(
                    icon: Icons.water_drop_rounded,
                    label: 'Edema',
                    value: _formatEdema(edema),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 👶 FETAL ASSESSMENT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.child_care_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetal Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _detailRow(
                    icon: Icons.navigation_rounded,
                    label: 'Fetal Position',
                    value: fetalPosition,
                  ),
                  const SizedBox(height: 12),

                  _detailRow(
                    icon: Icons.favorite_rounded,
                    label: 'Fetal Heart Beat',
                    value: fetalHeartBeat,
                  ),
                  const SizedBox(height: 12),

                  _detailRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Fetal Heart Tone',
                    value: fetalHeartTone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 💉 IMMUNIZATION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.medical_information_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Immunization',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _detailRow(
                    icon: Icons.vaccines_rounded,
                    label: 'Tetanus-Diphtheria Vaccine',
                    value: tdVaccine,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 💊 GIVEN MEDICATIONS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: const [
                      Icon(
                        Icons.medication_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Given Medications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow(
                    icon: Icons.medication_outlined,
                    label: 'Ferrous + FA',
                    value: ferrousQty != null
                        ? '$ferrousQty given'
                        : 'Not given',
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.local_pharmacy_rounded,
                    label: 'Calcium',
                    value: calciumQty != null
                        ? '$calciumQty given'
                        : 'Not given',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 📝 REMARKS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remarks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      remarks,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🤖 AI ANALYSIS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: Color(0xFF7E57C2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Insights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF3E5F5), Color(0xFFE8EAF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
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
                            Text(
                              'Checkup Analysis',
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
                          _generateAIAnalysis(checkupData),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getMidwifeName(Map<String, dynamic> checkup) {
    final firstName = checkup['midwife_first_name'] ?? '';
    final lastName = checkup['midwife_last_name'] ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return 'Not specified';
    }

    return '$firstName $lastName'.trim();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonth(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatEdema(String edema) {
    switch (edema.toLowerCase()) {
      case 'none':
        return 'None';
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'severe':
        return 'Severe';
      default:
        return edema;
    }
  }

  String _getBPStatus(int systolic, int diastolic) {
    if (systolic >= 140 || diastolic >= 90) return 'High';
    if (systolic <= 90 || diastolic <= 60) return 'Low';
    return 'Normal';
  }

  Color _getBPStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _generateAIAnalysis(Map<String, dynamic> checkup) {
    final analysis = StringBuffer();
    final gestation = checkup['age_of_gestation'];
    final weight = checkup['checkup_weight'];
    final systolic = checkup['blood_pressure_systolic'];
    final diastolic = checkup['blood_pressure_diastolic'];
    final fetalHeartBeat = checkup['fetal_heart_beat'];
    final edema = checkup['edema'];
    final remarks = checkup['remarks']?.toString().toLowerCase() ?? '';

    analysis.write('Based on the prenatal checkup:\n\n');

    if (gestation != null) {
      if (gestation < 12) {
        analysis.write(
          '📅 **First Trimester** (${gestation} weeks): Focus on early pregnancy care, '
          'nutrition, and managing common symptoms like nausea.\n\n',
        );
      } else if (gestation < 28) {
        analysis.write(
          '📅 **Second Trimester** (${gestation} weeks): Period of rapid fetal growth. '
          'Monitor weight gain and blood pressure regularly.\n\n',
        );
      } else {
        analysis.write(
          '📅 **Third Trimester** (${gestation} weeks): Preparing for delivery. '
          'Focus on fetal position, regular monitoring, and birth planning.\n\n',
        );
      }
    }

    if (weight != null) {
      analysis.write('⚖️ **Weight**: ${weight}kg. ');
      if (gestation != null) {
        final expectedGain = gestation * 0.5; // Approximate 0.5kg per week
        if (weight > expectedGain + 3) {
          analysis.write(
            'Consider discussing weight management with your healthcare provider.\n\n',
          );
        } else if (weight < expectedGain - 2) {
          analysis.write(
            'Ensure adequate nutrition and discuss any concerns with your provider.\n\n',
          );
        } else {
          analysis.write(
            'Weight gain appears appropriate for this stage of pregnancy.\n\n',
          );
        }
      }
    }

    if (systolic != null && diastolic != null) {
      analysis.write('🩸 **Blood Pressure**: ${systolic}/${diastolic} mmHg - ');
      final bpStatus = _getBPStatus(systolic, diastolic);
      if (bpStatus == 'High') {
        analysis.write(
          'Elevated readings detected. Monitor closely and discuss with your provider '
          'to rule out pregnancy-induced hypertension.\n\n',
        );
      } else if (bpStatus == 'Low') {
        analysis.write(
          'Lower than average readings. Stay hydrated and rise slowly from sitting/lying positions.\n\n',
        );
      } else {
        analysis.write('Within normal range for pregnancy.\n\n');
      }
    }

    if (fetalHeartBeat != null) {
      analysis.write('💓 **Fetal Heart Rate**: ${fetalHeartBeat} bpm - ');
      if (fetalHeartBeat >= 110 && fetalHeartBeat <= 160) {
        analysis.write('Normal fetal heart rate range.\n\n');
      } else {
        analysis.write(
          'Discuss this reading with your healthcare provider for proper evaluation.\n\n',
        );
      }
    }

    if (edema != null && edema.toLowerCase() != 'none') {
      analysis.write(
        '🦶 **Edema (${_formatEdema(edema)})**: Common in pregnancy. '
        'Elevate legs when resting, stay hydrated, and monitor for sudden swelling.\n\n',
      );
    }

    if (checkup['td_vaccine_dose'] != null &&
        checkup['td_vaccine_dose'].toString().isNotEmpty) {
      analysis.write(
        '💉 **TD Vaccine Administered**: Important for protecting both mother and baby '
        'from tetanus and diphtheria.\n\n',
      );
    }

    // Analyze remarks
    if (remarks.contains('normal') || remarks.contains('unremarkable')) {
      analysis.write(
        '✅ Overall assessment appears normal. Continue regular prenatal care.\n\n',
      );
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      analysis.write(
        '📊 Follow-up monitoring recommended. Attend scheduled appointments.\n\n',
      );
    }

    analysis.write('💡 **Recommendations**:\n');
    analysis.write('• Continue regular prenatal visits\n');
    analysis.write('• Maintain balanced nutrition and hydration\n');
    analysis.write('• Monitor any new symptoms or changes\n');
    analysis.write('• Follow provider instructions for next appointment\n');

    return analysis.toString();
  }
}
