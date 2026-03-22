// lib/screens/mother/mother_profile_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/mother_profile_service.dart';
import '../../services/auth_storage.dart';
import '../midwife/ultrasound_analyzer_screen.dart';
import '../midwife/lab_test_analyzer_screen.dart';
import '../midwife/add_prenatal_checkup_screen.dart';
import '../../widgets/headline.dart';
import '../../widgets/page_title.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/overview_info.dart';
import '../../widgets/risk_panel.dart';
import '../../services/risk_engine.dart';
import '../../models/add_mother_form_data.dart';
import '../../widgets/full_screen_image_viewer.dart';

class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({super.key, required this.motherId});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _profileFuture;
  late TabController _tabController;

  // Sort states
  String _checkupSort = 'desc';
  String _ultrasoundSort = 'desc';
  String _labSort = 'desc';
  String _childQuery = '';
  String _childSort = 'recent';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
    });
  }

  Future<void> _logout() async {
    await AuthStorage.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // Navigate to ultrasound analyzer
  void _goToUltrasoundAnalyzer(Map<String, dynamic> pregnancy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UltrasoundAnalyzerScreen(
          motherId: widget.motherId,
          pregnancyId: pregnancy['pregnancy_id'],
        ),
      ),
    ).then((_) => _refresh());
  }

  // Navigate to lab test analyzer
  void _goToLabTestAnalyzer(Map<String, dynamic> pregnancy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabTestAnalyzerScreen(
          motherId: widget.motherId,
          pregnancyId: pregnancy['pregnancy_id'],
        ),
      ),
    ).then((_) => _refresh());
  }

  // Helper methods for formatting
  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return date.toString();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '—';
    try {
      final parsed = DateTime.tryParse(dateTime.toString());
      if (parsed == null) return dateTime.toString();
      return DateFormat('MMM d, yyyy h:mm a').format(parsed);
    } catch (e) {
      return dateTime.toString();
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    final str = value.toString().trim();
    return str.isEmpty ? '—' : str;
  }

  String _formatOutcome(String? outcome) {
    if (outcome == null) return '—';
    switch (outcome.toLowerCase()) {
      case 'live_birth':
        return 'Live Birth';
      case 'stillbirth':
        return 'Stillbirth';
      case 'miscarriage':
        return 'Miscarriage';
      case 'abortion':
        return 'Abortion';
      case 'ectopic':
        return 'Ectopic';
      default:
        return outcome;
    }
  }

  // Build risk assessment from DB-stored values (preferred) with local engine fallback.
  // Reads `pregnancy_risk_level` from the pregnancies row and risk factors from
  // the most recent checkup that has stored risk_factors.
  RiskAssessment _buildRiskAssessmentFromDb(
      Map<String, dynamic> profile,
      Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return RiskAssessment(
        level: 'low',
        score: 0,
        factors: ['No ongoing pregnancy'],
        note: 'No ongoing pregnancy to assess.',
      );
    }

    // ── 1. Try to use the stored DB risk level ──────────────────────────────
    final dbLevel = (pregnancy['pregnancy_risk_level'] as String?)?.toLowerCase();

    // ── 2. Collect risk factors from stored checkup risk assessments ────────
    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final List<String> dbFactors = [];
    String? dbAiNote;

    // Walk checkups newest-first to find the most recent one with risk data
    final sortedCheckups = List<Map<String, dynamic>>.from(
        checkups.whereType<Map<String, dynamic>>())
      ..sort((a, b) {
        final da = DateTime.tryParse(a['checkup_datetime'] ?? '');
        final db = DateTime.tryParse(b['checkup_datetime'] ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da); // newest first
      });

    for (final checkup in sortedCheckups) {
      final factors = checkup['risk_factors'] as List?;
      if (factors != null && factors.isNotEmpty) {
        for (final f in factors) {
          final fMap = f as Map<String, dynamic>;
          final factor = fMap['factor']?.toString() ?? '';
          if (factor.isNotEmpty) dbFactors.add(factor);
        }
        // Also grab the AI response text if available
        final aiResp = checkup['risk_ai_response'] as Map<String, dynamic>?;
        if (aiResp != null) {
          final resp = aiResp['response']?.toString();
          if (resp != null && resp.isNotEmpty) dbAiNote = resp;
        }
        break; // Only use the most recent checkup's risk data
      }
    }

    // ── 3. If we have DB data, return that ──────────────────────────────────
    if (dbLevel != null && dbLevel.isNotEmpty) {
      final level = (dbLevel == 'high' || dbLevel == 'medium' || dbLevel == 'low')
          ? dbLevel
          : 'low';

      String note;
      switch (level) {
        case 'high':
          note = dbAiNote ??
              'High-risk pregnancy. Close monitoring required. Consult with specialist.';
          break;
        case 'medium':
          note = dbAiNote ?? 'Moderate risk factors present. Regular monitoring recommended.';
          break;
        default:
          note = dbAiNote ?? 'No significant risk factors identified.';
      }

      return RiskAssessment(
        level: level,
        score: level == 'high'
            ? 60
            : level == 'medium'
                ? 30
                : 5,
        factors: dbFactors.isNotEmpty
            ? dbFactors
            : ['No risk factors recorded yet'],
        note: note,
      );
    }

    // ── 4. Fallback to local rule-based engine if no DB risk data yet ───────
    final formData = AddMotherFormData();
    if (profile['birthdate'] != null) {
      try {
        formData.birthdate = DateTime.parse(profile['birthdate']);
      } catch (_) {}
    }
    if (profile['height'] != null && profile['weight'] != null) {
      formData.heightCm = (profile['height'] as num?)?.toDouble();
      formData.weightKg = (profile['weight'] as num?)?.toDouble();
    }
    final conditions = profile['medical_conditions'] as List? ?? [];
    for (final condition in conditions) {
      formData.medicalConditions.add(
        MedicalConditionEntry(
          conditionName: condition['condition_name'] ?? '',
          status: condition['status'] ?? 'active',
        )..diagnosisDate = DateTime.tryParse(condition['diagnosis_date'] ?? ''),
      );
    }
    final pastPregnancies = profile['past_pregnancies'] as List? ?? [];
    for (final pg in pastPregnancies) {
      final date = DateTime.tryParse(pg['outcome_date'] ?? '');
      if (date != null) {
        formData.pregnancyHistory.add(
          PregnancyHistoryEntry(
            outcome: pg['outcome'] ?? 'live_birth',
            outcomeDate: date,
          ),
        );
      }
    }
    return RiskEngine.evaluate(formData);
  }

  // AI Analysis Generators
  String _generatePrenatalAIInsights(Map<String, dynamic> checkup) {
    final buffer = StringBuffer();
    buffer.write('🤖 AI Analysis:\n\n');

    // Blood Pressure Analysis
    final bpSys = _toDouble(checkup['blood_pressure_systolic']);
    final bpDia = _toDouble(checkup['blood_pressure_diastolic']);
    if (bpSys != null && bpDia != null) {
      if (bpSys >= 140 || bpDia >= 90) {
        buffer.write('⚠️ **Elevated Blood Pressure** detected. '
            'Consider monitoring for preeclampsia symptoms.\n\n');
      } else if (bpSys < 90 || bpDia < 60) {
        buffer.write('📉 **Low Blood Pressure** noted. '
            'Ensure adequate hydration and gradual position changes.\n\n');
      } else {
        buffer.write('✅ **Blood Pressure** is within normal pregnancy range.\n\n');
      }
    }

    // Weight Analysis
    final weight = _toDouble(checkup['checkup_weight']);
    if (weight != null) {
      buffer.write('⚖️ **Weight**: $weight kg\n\n');
    }

    // Fetal Heart Rate
    final fhr = checkup['fetal_heart_beat'];
    if (fhr != null) {
      final rate = int.tryParse(fhr.toString());
      if (rate != null) {
        if (rate >= 120 && rate <= 160) {
          buffer.write('💓 **Fetal Heart Rate**: $rate bpm (Normal range)\n\n');
        } else if (rate < 120) {
          buffer.write('⚠️ **Fetal Heart Rate**: $rate bpm (Below normal range)\n\n');
        } else {
          buffer.write('⚠️ **Fetal Heart Rate**: $rate bpm (Above normal range)\n\n');
        }
      }
    }

    // Edema
    final edema = checkup['edema']?.toString().toLowerCase();
    if (edema != null && edema != 'none') {
      buffer.write('💧 **Edema**: ${edema.toUpperCase()} - Monitor for worsening symptoms.\n\n');
    }

    // TD Vaccine
    final tdDose = checkup['td_vaccine_dose']?.toString();
    if (tdDose != null && tdDose.isNotEmpty) {
      buffer.write('💉 **TD Vaccine**: $tdDose administered\n\n');
    }

    // Recommendations
    buffer.write('📋 **Recommendations**:\n');
    buffer.write('• Continue regular prenatal visits\n');
    buffer.write('• Monitor fetal movements daily\n');
    buffer.write('• Report any unusual symptoms immediately\n');

    return buffer.toString();
  }

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final buffer = StringBuffer();
    buffer.write('🤖 Ultrasound AI Insights:\n\n');

    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final date = _formatDate(ultrasound['ultrasound_date']);

    buffer.write('Ultrasound conducted on $date');

    final location = ultrasound['ultrasound_location'];
    if (location != null && location.toString().isNotEmpty) {
      buffer.write(' at $location');
    }

    final worker = ultrasound['health_worker_name'];
    if (worker != null && worker.toString().isNotEmpty) {
      buffer.write(' by $worker');
    }
    buffer.write(':\n\n');

    // Analyze remarks
    if (remarks.contains('normal') || remarks.contains('healthy')) {
      buffer.write('✅ **Normal Findings**: Ultrasound appears normal with healthy fetal development.\n\n');
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      buffer.write('📊 **Follow-up Recommended**: Some findings require additional observation.\n\n');
    } else if (remarks.contains('concern') || remarks.contains('abnormal')) {
      buffer.write('🔍 **Further Evaluation Needed**: Discuss findings with healthcare provider.\n\n');
    } else {
      buffer.write('📋 **Diagnostic Information**: The ultrasound provides important diagnostic information.\n\n');
    }

    buffer.write('💡 **Key Recommendations**:\n');
    buffer.write('• Discuss findings with your healthcare provider\n');
    buffer.write('• Continue all scheduled prenatal appointments\n');

    return buffer.toString();
  }

  String _generateLabTestAIInsights(Map<String, dynamic> labTest) {
    final buffer = StringBuffer();
    buffer.write('🤖 Lab Test AI Analysis:\n\n');

    final testType = labTest['lab_test_type']?.toString().toLowerCase() ?? '';
    final remarks = labTest['remarks']?.toString().toLowerCase() ?? '';
    final date = _formatDate(labTest['lab_test_date']);

    buffer.write('**${testType.toUpperCase()} Results** from $date:\n\n');

    // Analyze based on test type
    if (testType.contains('blood') || testType.contains('cbc')) {
      buffer.write('🩸 **Blood Test Analysis**:\n');
      if (remarks.contains('normal')) {
        buffer.write('• Blood parameters are within normal pregnancy ranges\n');
      } else if (remarks.contains('low')) {
        buffer.write('• Some values below optimal range\n');
        buffer.write('• Consider dietary adjustments or supplements\n');
      } else if (remarks.contains('high')) {
        buffer.write('• Elevated values noted\n');
        buffer.write('• May require follow-up testing\n');
      }
    } else if (testType.contains('urine')) {
      buffer.write('🧪 **Urine Test Analysis**:\n');
      if (remarks.contains('normal')) {
        buffer.write('• Urine analysis shows no concerning findings\n');
      } else if (remarks.contains('protein')) {
        buffer.write('• Protein detected - monitor for preeclampsia\n');
      } else if (remarks.contains('infection')) {
        buffer.write('• Possible urinary tract infection\n');
        buffer.write('• Consult healthcare provider\n');
      }
    } else if (testType.contains('glucose')) {
      buffer.write('📊 **Glucose Test Analysis**:\n');
      if (remarks.contains('normal')) {
        buffer.write('• Glucose levels are within normal range\n');
      } else if (remarks.contains('high')) {
        buffer.write('• Elevated glucose levels detected\n');
        buffer.write('• May indicate need for gestational diabetes screening\n');
      }
    }

    buffer.write('\n🏥 **Health Recommendations**:\n');
    buffer.write('• Review results with your healthcare provider\n');
    buffer.write('• Follow any prescribed treatment plans\n');

    return buffer.toString();
  }

// Show full screen image
void _showFullScreenImage(List<String> imageUrls, int initialIndex) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FullScreenImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    ),
  );
}

  // Show record details modal
  void _showRecordDetails({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    List<String>? imageUrls,
    String? aiAnalysis,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: AppColors.brandPrimary),
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
                                  style: const TextStyle(color: AppColors.textSecondary),
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
                    const SizedBox(height: 16),

                    // Image Gallery if available
                    if (imageUrls != null && imageUrls.isNotEmpty) ...[
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(imageUrls, index),
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.bgSecondary,
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Image not available',
                                                  style: TextStyle(fontSize: 10),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: AppColors.bgSecondary,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Image counter overlay
                                      if (imageUrls.length > 1 && index == 0)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '+${imageUrls.length - 1} more',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Details
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Column(
                        children: rows.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),

                    // AI Analysis if available
                    if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF7E57C2).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology_rounded, color: const Color(0xFF7E57C2), size: 20),
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
                            const SizedBox(height: 12),
                            Text(
                              aiAnalysis,
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Note: This is AI-generated analysis for informational purposes only.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show conclude pregnancy dialog
  Future<void> _showConcludePregnancyDialog(Map<String, dynamic> pregnancy) async {
    String outcome = 'live_birth';
    DateTime? outcomeDate = DateTime.now();
    DateTime? deliveryDate;
    String? placeOfDelivery;
    String? deliveryMethod;
    double? gestationalAge;

    final lmpDate = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
    final gestAgeController = TextEditingController();
    final placeController = TextEditingController();

    if (lmpDate != null) {
      final weeks = DateTime.now().difference(lmpDate).inDays / 7;
      gestationalAge = double.parse(weeks.toStringAsFixed(1));
      gestAgeController.text = gestationalAge.toString();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.flag, color: Colors.red),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Conclude Pregnancy',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Outcome dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: outcome,
                              decoration: const InputDecoration(
                                labelText: 'Outcome',
                                border: InputBorder.none,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'live_birth', child: Text('Live Birth')),
                                DropdownMenuItem(value: 'stillbirth', child: Text('Stillbirth')),
                                DropdownMenuItem(value: 'miscarriage', child: Text('Miscarriage')),
                                DropdownMenuItem(value: 'abortion', child: Text('Abortion')),
                                DropdownMenuItem(value: 'ectopic', child: Text('Ectopic')),
                              ],
                              onChanged: (v) => setModal(() => outcome = v ?? outcome),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Outcome date
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: outcomeDate!,
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModal(() {
                                  outcomeDate = picked;
                                  if (outcome == 'live_birth' || outcome == 'stillbirth') {
                                    deliveryDate = picked;
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Outcome Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMMM d, yyyy').format(outcomeDate!),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),

                          // Delivery details for live birth/stillbirth
                          if (outcome == 'live_birth' || outcome == 'stillbirth') ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: placeController,
                              decoration: InputDecoration(
                                labelText: 'Place of Delivery',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.bgSecondary,
                              ),
                              onChanged: (v) => placeOfDelivery = v,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: deliveryMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Method',
                                  border: InputBorder.none,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'NSD', child: Text('Normal Spontaneous Delivery')),
                                  DropdownMenuItem(value: 'CS', child: Text('Cesarean Section')),
                                  DropdownMenuItem(value: 'Instrumental', child: Text('Instrumental')),
                                ],
                                onChanged: (v) => setModal(() => deliveryMethod = v),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          TextField(
                            controller: gestAgeController,
                            decoration: InputDecoration(
                              labelText: 'Gestational Age at End (weeks)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.bgSecondary,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => gestationalAge = double.tryParse(v),
                          ),
                          const SizedBox(height: 24),

                          // Submit button
                          MainButton(
                            label: 'Conclude Pregnancy',
                            onPressed: () async {
                              if (outcome == 'live_birth' || outcome == 'stillbirth') {
                                if (deliveryMethod == null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select delivery method')),
                                  );
                                  return;
                                }
                              }

                              final success = await MotherProfileService.concludePregnancy(
                                pregnancy['pregnancy_id'],
                                {
                                  'outcome': outcome,
                                  'outcome_date': outcomeDate?.toIso8601String().split('T')[0],
                                  'delivery_date': deliveryDate?.toIso8601String().split('T')[0],
                                  'place_of_delivery': placeOfDelivery ?? placeController.text,
                                  'delivery_method': deliveryMethod,
                                  'gestational_age_at_end': gestationalAge,
                                },
                              );

                              if (success && mounted) {
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pregnancy concluded successfully')),
                                );
                                _refresh();
                              }
                            },
                          ),
                        ],
                      ),
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
    placeController.dispose();
  }

  // Start new pregnancy
  Future<void> _startNewPregnancy() async {
    DateTime? lmp;
    DateTime? edd;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PageTitle(
                title: 'Start New Pregnancy',
                leadingIcon: Icons.pregnant_woman,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    lmp = picked;
                    edd = picked.add(const Duration(days: 280));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Menstrual Period',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lmp == null ? 'Select date' : DateFormat('MMMM d, yyyy').format(lmp!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (lmp != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, color: AppColors.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated Due Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMMM d, yyyy').format(edd!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                      showIcons: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MainButton(
                      label: 'Start',
                      onPressed: lmp == null ? null : () async {
                        final success = await MotherProfileService.startNewPregnancy(
                          widget.motherId,
                          lmp!,
                          edd!,
                        );
                        if (success && mounted) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New pregnancy started')),
                          );
                          _refresh();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                    ),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Headline(text: 'Error Loading Profile'),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          MainButton(
                            label: 'Retry',
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(child: Text('No profile data found')),
                ),
              ],
            );
          }

          final profile = snapshot.data!;
          final currentPregnancy = profile['current_pregnancy'] as Map<String, dynamic>?;
          final pastPregnancies = profile['past_pregnancies'] as List? ?? [];
          final medicalConditions = profile['medical_conditions'] as List? ?? [];
          final allergies = profile['allergies'] as List? ?? [];
          final emergencyContacts = profile['emergency_contacts'] as List? ?? [];
          final children = profile['children'] as List? ?? [];

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.brandPrimary,
                          labelColor: AppColors.brandPrimary,
                          unselectedLabelColor: AppColors.textSecondary,
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Current'),
                            Tab(text: 'History'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // OVERVIEW TAB
                            _buildOverviewTab(profile, medicalConditions, allergies, emergencyContacts, children, currentPregnancy),
                            
                            // CURRENT PREGNANCY TAB
                            _buildCurrentPregnancyTab(profile, currentPregnancy),
                            
                            // HISTORY TAB
                            _buildHistoryTab(pastPregnancies),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              
              // Logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.favorite, color: AppColors.brandPrimary, size: 30),
                ),
              ),

              // Title
              const Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandText,
                  letterSpacing: 0.4,
                ),
              ),

              const Spacer(),

              // Notifications
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  // Handle notifications
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(width: 14),

              // Avatar with profile menu
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          /// FULLSCREEN OVERLAY
          GestureDetector(
            onTap: () => entry.remove(),
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          /// PROFILE MENU
          Positioned(
            top: 90,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'View Profile',
                      onTap: () {
                        entry.remove();
                        // Already on profile
                      },
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _MenuItem(
                      icon: Icons.help_outline,
                      label: 'Help',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/help');
                      },
                    ),
                    const Divider(height: 8),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      isDanger: true,
                      onTap: () {
                        entry.remove();
                        _confirmLogout(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      showIcons: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MainButton(
                      label: 'Log out',
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // OVERVIEW TAB
  Widget _buildOverviewTab(
    Map<String, dynamic> profile,
    List medicalConditions,
    List allergies,
    List emergencyContacts,
    List children,
    Map<String, dynamic>? currentPregnancy,
  ) {
    final riskAssessment = _buildRiskAssessmentFromDb(profile, currentPregnancy);
    
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'M',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['full_name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                profile['email_address'] ?? '—',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              profile['phone_number'] ?? '—',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: OverviewInfo(
                    value: profile['birthdate'] != null
                        ? DateTime.now().difference(DateTime.parse(profile['birthdate'])).inDays ~/ 365
                        : 0,
                    label: 'Age',
                    icon: Icons.cake,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OverviewInfo(
                    value: profile['children_count'] ?? 0,
                    label: 'Children',
                    icon: Icons.child_care,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OverviewInfo(
                    value: profile['pregnancies_count'] ?? 0,
                    label: 'Pregnancies',
                    icon: Icons.pregnant_woman,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Risk Panel
            if (currentPregnancy != null)
              RiskPanel(assessment: riskAssessment),

            const SizedBox(height: 16),

            // AI Analysis Tools
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'AI Analysis Tools',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload medical images for AI-powered analysis',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          'Ultrasound',
                          Icons.photo,
                          Colors.purple,
                          () {
                            if (currentPregnancy != null) {
                              _goToUltrasoundAnalyzer(currentPregnancy);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No ongoing pregnancy found'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          'Lab Test',
                          Icons.science,
                          Colors.orange,
                          () {
                            if (currentPregnancy != null) {
                              _goToLabTestAnalyzer(currentPregnancy);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No ongoing pregnancy found'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Personal Information
            _buildExpandableSection(
              'Personal Information',
              Icons.person_outline,
              [
                _buildInfoRow('Birthdate', _formatDate(profile['birthdate'])),
                _buildInfoRow('Blood Type', profile['blood_type'] ?? '—'),
                _buildInfoRow('Height', profile['height'] != null ? '${profile['height']} cm' : '—'),
                _buildInfoRow('Weight', profile['weight'] != null ? '${profile['weight']} kg' : '—'),
              ],
            ),

            const SizedBox(height: 12),

            // Address
            _buildExpandableSection(
              'Address',
              Icons.home_outlined,
              [
                _buildInfoRow('House No.', profile['house_number'] ?? '—'),
                _buildInfoRow('Street', profile['street'] ?? '—'),
                _buildInfoRow('Barangay', profile['barangay'] ?? '—'),
                _buildInfoRow('City', profile['city_municipality'] ?? '—'),
                _buildInfoRow('Province', profile['province'] ?? '—'),
              ],
            ),

            const SizedBox(height: 12),

            // Medical Conditions
            _buildExpandableSection(
              'Medical Conditions',
              Icons.medical_services_outlined,
              medicalConditions.isEmpty
                  ? [const Text('No medical conditions recorded')]
                  : medicalConditions.map<Widget>((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c['status'] == 'active' ? Colors.orange : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['condition_name'] ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${c['status'] ?? 'active'} • ${_formatDate(c['diagnosis_date'])}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
            ),

            const SizedBox(height: 12),

            // Allergies
            _buildExpandableSection(
              'Allergies',
              Icons.warning_amber_outlined,
              allergies.isEmpty
                  ? [const Text('No allergies recorded')]
                  : allergies.map<Widget>((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: a['status'] == 'active' ? Colors.orange : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['allergen'] ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${a['status'] ?? 'active'} • ${_formatDate(a['diagnosis_date'])}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
            ),

            const SizedBox(height: 12),

            // Emergency Contacts
            _buildExpandableSection(
              'Emergency Contacts',
              Icons.contacts_outlined,
              emergencyContacts.isEmpty
                  ? [const Text('No emergency contacts')]
                  : emergencyContacts.map<Widget>((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              c['first_name'],
                              c['middle_name'],
                              c['last_name'],
                              c['extension_name'],
                            ].where((e) => e != null).join(' '),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(c['phone_number'] ?? '—'),
                            ],
                          ),
                          if (c['affiliation'] != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.business, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(c['affiliation']),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )).toList(),
            ),

            const SizedBox(height: 12),

            // Children
            _buildExpandableSection(
              'Children',
              Icons.child_care_outlined,
              [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search children...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.bgSecondary,
                  ),
                  onChanged: (v) => setState(() => _childQuery = v),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _childSort,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('Most recent')),
                      DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                    ],
                    onChanged: (v) => setState(() => _childSort = v ?? 'recent'),
                  ),
                ),
                const SizedBox(height: 12),
                ..._filterAndSortChildren(children).map((c) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                      child: Text(
                        c['first_name']?.toString().substring(0, 1).toUpperCase() ?? 'C',
                        style: TextStyle(color: AppColors.brandPrimary),
                      ),
                    ),
                    title: Text([
                      c['first_name'],
                      c['middle_name'],
                      c['last_name'],
                    ].where((e) => e != null).join(' ')),
                    subtitle: Text('Added: ${_formatDate(c['added_at'])}'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      // Navigate to child profile (to be implemented)
                    },
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CURRENT PREGNANCY TAB
  Widget _buildCurrentPregnancyTab(Map<String, dynamic> profile, Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pregnant_woman,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Ongoing Pregnancy'),
              const SizedBox(height: 8),
              const Text(
                'Start a new pregnancy to begin tracking',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MainButton(
                label: 'Start New Pregnancy',
                onPressed: _startNewPregnancy,
              ),
            ],
          ),
        ),
      );
    }

    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final ultrasounds = (pregnancy['ultrasounds'] as List?) ?? [];
    final labTests = (pregnancy['lab_tests'] as List?) ?? [];

    // Sort checkups
    final sortedCheckups = List<Map<String, dynamic>>.from(checkups);
    sortedCheckups.sort((a, b) {
      final dateA = DateTime.tryParse(a['checkup_datetime'] ?? '');
      final dateB = DateTime.tryParse(b['checkup_datetime'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return _checkupSort == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    // Calculate gestation
    final lmp = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
    final edd = DateTime.tryParse(pregnancy['expected_date_of_delivery'] ?? '');
    final now = DateTime.now();
    final gestWeeks = lmp != null ? (now.difference(lmp).inDays / 7).floor() : null;
    final daysToEdd = edd != null ? edd.difference(now).inDays : null;

    // Generate risk assessment
    final riskAssessment = _buildRiskAssessmentFromDb(profile, pregnancy);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk Panel
            RiskPanel(assessment: riskAssessment),

            const SizedBox(height: 16),

            // Quick Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              gestWeeks != null ? '$gestWeeks' : '—',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const Text(
                              'Weeks',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: AppColors.borderPrimary,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              daysToEdd != null ? daysToEdd.toString() : '—',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const Text(
                              'Days to EDD',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Checkups', sortedCheckups.length.toString(), Icons.fact_check),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Risk Level',
                          pregnancy['pregnancy_risk_level']?.toString().toUpperCase() ?? '—',
                          Icons.warning,
                          color: pregnancy['pregnancy_risk_level'] == 'high'
                              ? Colors.red
                              : pregnancy['pregnancy_risk_level'] == 'medium'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Add Checkup',
                          Icons.add,
                          AppColors.brandPrimary,
                          () async {
                            final pregnancyId = pregnancy['pregnancy_id'];
                            if (pregnancyId == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPrenatalCheckupScreen(
                                  motherId: widget.motherId,
                                  pregnancyId: pregnancyId as int,
                                  lmp: DateTime.tryParse(
                                      pregnancy['last_menstrual_period'] ?? ''),
                                  motherWeight: _toDouble(profile['weight']),
                                ),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Ultrasound',
                          Icons.photo,
                          Colors.purple,
                          () => _goToUltrasoundAnalyzer(pregnancy),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Lab Test',
                          Icons.science,
                          Colors.orange,
                          () => _goToLabTestAnalyzer(pregnancy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Conclude',
                          Icons.flag,
                          Colors.red,
                          () => _showConcludePregnancyDialog(pregnancy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pregnancy Details
            _buildExpandableSection(
              'Pregnancy Details',
              Icons.info_outline,
              [
                _buildInfoRow('LMP', _formatDate(pregnancy['last_menstrual_period'])),
                _buildInfoRow('EDD', _formatDate(pregnancy['expected_date_of_delivery'])),
                _buildInfoRow('Status', pregnancy['status']?.toString().toUpperCase() ?? '—'),
              ],
            ),

            const SizedBox(height: 12),

            // Checkups
            _buildExpandableSection(
              'Prenatal Checkups',
              Icons.medical_services_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _checkupSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) => setState(() => _checkupSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sortedCheckups.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No checkups recorded'),
                    ),
                  )
                else
                  ...sortedCheckups.map((c) => _buildCheckupCard(c)),
              ],
            ),

            const SizedBox(height: 12),

            // Ultrasounds
            _buildExpandableSection(
              'Ultrasounds',
              Icons.photo_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _ultrasoundSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) => setState(() => _ultrasoundSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (ultrasounds.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No ultrasounds recorded'),
                    ),
                  )
                else
                  ..._sortByDate(ultrasounds, 'ultrasound_date', _ultrasoundSort).map(
                    (u) => _buildUltrasoundCard(u),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Lab Tests
            _buildExpandableSection(
              'Lab Tests',
              Icons.science_outlined,
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _labSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'asc', child: Text('Oldest')),
                        ],
                        onChanged: (v) => setState(() => _labSort = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (labTests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No lab tests recorded'),
                    ),
                  )
                else
                  ..._sortByDate(labTests, 'lab_test_date', _labSort).map(
                    (l) => _buildLabTestCard(l),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // HISTORY TAB
  Widget _buildHistoryTab(List pastPregnancies) {
    if (pastPregnancies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Past Pregnancies'),
              const SizedBox(height: 8),
              const Text(
                'Past pregnancies will appear here',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pastPregnancies.length,
        itemBuilder: (context, index) {
          final p = pastPregnancies[index] as Map<String, dynamic>;
          final delivery = p['delivery'] as Map<String, dynamic>?;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                child: Icon(Icons.pregnant_woman, color: AppColors.brandPrimary),
              ),
              title: Text(_formatOutcome(p['outcome'])),
              subtitle: Text('Ended: ${_formatDate(p['outcome_date'])}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Outcome', _formatOutcome(p['outcome'])),
                      _buildInfoRow('Date', _formatDate(p['outcome_date'])),
                      _buildInfoRow('Gestational Age', p['gestational_age_at_end'] != null
                          ? '${p['gestational_age_at_end']} weeks'
                          : '—'),
                      if (delivery != null) ...[
                        const Divider(height: 24),
                        const Text('Delivery Details',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildInfoRow('Place', delivery['place_of_delivery'] ?? '—'),
                        _buildInfoRow('Method', delivery['delivery_method'] ?? '—'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper Widgets
  Widget _buildToolCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.brandPrimary, size: 18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupCard(Map<String, dynamic> checkup) {
    final date = _formatDateTime(checkup['checkup_datetime']);
    final bpSys = _formatValue(checkup['blood_pressure_systolic']);
    final bpDia = _formatValue(checkup['blood_pressure_diastolic']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.medical_services, color: AppColors.brandPrimary, size: 20),
        ),
        title: Text('Checkup', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            if (bpSys != '—' && bpDia != '—')
              Text('BP: $bpSys/$bpDia', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () {
          final aog = _formatValue(checkup['age_of_gestation']);
          final weight = _formatValue(checkup['checkup_weight']);
          
          _showRecordDetails(
            title: 'Prenatal Checkup',
            subtitle: date,
            icon: Icons.medical_services,
            rows: [
              MapEntry('Date', _formatDateTime(checkup['checkup_datetime'])),
              MapEntry('Age of Gestation', aog),
              MapEntry('Weight (kg)', weight),
              MapEntry('Blood Pressure', '$bpSys/$bpDia'),
              MapEntry('Fetal Position', _formatValue(checkup['fetal_position'])),
              MapEntry('Fetal Heart Beat', _formatValue(checkup['fetal_heart_beat'])),
              MapEntry('TD Vaccine', _formatValue(checkup['td_vaccine_dose'])),
              MapEntry('Edema', _formatValue(checkup['edema'])),
              MapEntry('Remarks', _formatValue(checkup['remarks'])),
              MapEntry('Next Schedule', _formatDate(checkup['next_schedule'])),
            ],
            aiAnalysis: _generatePrenatalAIInsights(checkup),
          );
        },
      ),
    );
  }

Widget _buildUltrasoundCard(Map<String, dynamic> ultrasound) {
  final date = _formatDate(ultrasound['ultrasound_date']);
  
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.photo, color: Colors.purple, size: 20),
      ),
      title: Text('Ultrasound', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(date),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        // Get all image URLs
        List<String> imageUrls = [];
        
        if (ultrasound['ultrasound_image'] != null) {
          final imageField = ultrasound['ultrasound_image'].toString();
          if (imageField.contains(',')) {
            // Multiple URLs separated by commas
            imageUrls = imageField.split(',').map((url) => url.trim()).toList();
          } else if (imageField.isNotEmpty) {
            // Single URL
            imageUrls = [imageField];
          }
        }
        
        _showRecordDetails(
          title: 'Ultrasound',
          subtitle: date,
          icon: Icons.monitor_heart,
          imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
          rows: [
            MapEntry('Date', _formatDate(ultrasound['ultrasound_date'])),
            MapEntry('Location', _formatValue(ultrasound['ultrasound_location'])),
            MapEntry('Health Worker', _formatValue(ultrasound['health_worker_name'])),
            MapEntry('Institution', _formatValue(ultrasound['health_worker_institution'])),
            MapEntry('Remarks', _formatValue(ultrasound['remarks'])),
          ],
          aiAnalysis: _generateUltrasoundAIInsights(ultrasound),
        );
      },
    ),
  );
}

Widget _buildLabTestCard(Map<String, dynamic> labTest) {
  final date = _formatDate(labTest['lab_test_date']);
  final type = labTest['lab_test_type'] ?? 'Lab Test';
  
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science, color: Colors.orange, size: 20),
      ),
      title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(date),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        // Get all image URLs
        List<String> imageUrls = [];
        
        if (labTest['lab_test_image'] != null) {
          final imageField = labTest['lab_test_image'].toString();
          if (imageField.contains(',')) {
            // Multiple URLs separated by commas
            imageUrls = imageField.split(',').map((url) => url.trim()).toList();
          } else if (imageField.isNotEmpty) {
            // Single URL
            imageUrls = [imageField];
          }
        }
        
        _showRecordDetails(
          title: type,
          subtitle: date,
          icon: Icons.science,
          imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
          rows: [
            MapEntry('Type', type),
            MapEntry('Date', _formatDate(labTest['lab_test_date'])),
            MapEntry('Location', _formatValue(labTest['lab_test_location'])),
            MapEntry('Health Worker', _formatValue(labTest['health_worker_name'])),
            MapEntry('Remarks', _formatValue(labTest['remarks'])),
          ],
          aiAnalysis: _generateLabTestAIInsights(labTest),
        );
      },
    ),
  );
}

  // Helper methods
  List<Map<String, dynamic>> _sortByDate(List list, String field, String order) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final dateA = DateTime.tryParse(a[field] ?? '');
      final dateB = DateTime.tryParse(b[field] ?? '');
      if (dateA == null || dateB == null) return 0;
      return order == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });
    return sorted;
  }

  List<Map<String, dynamic>> _filterAndSortChildren(List children) {
    var filtered = List<Map<String, dynamic>>.from(children)
        .where((c) {
          final name = [
            c['first_name'],
            c['middle_name'],
            c['last_name'],
          ].where((e) => e != null).join(' ').toLowerCase();
          return name.contains(_childQuery.toLowerCase());
        })
        .toList();

    if (_childSort == 'name') {
      filtered.sort((a, b) {
        final nameA = (a['last_name'] ?? '') + (a['first_name'] ?? '');
        final nameB = (b['last_name'] ?? '') + (b['first_name'] ?? '');
        return nameA.compareTo(nameB);
      });
    }

    return filtered;
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}