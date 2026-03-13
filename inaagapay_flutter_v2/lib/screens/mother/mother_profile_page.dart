import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/mother_profile_service.dart';
import '../midwife/ultrasound_analyzer_screen.dart';
import '../midwife/lab_test_analyzer_screen.dart';

class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({super.key, required this.motherId});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _profileFuture;
  late TabController _tabController;
  bool _riskExpanded = false;

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

  // Show record details modal
  void _showRecordDetails({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    String? imageUrl,
    String? aiAnalysis,
  }) {
    showModalBottomSheet(
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
              const SizedBox(height: 12),

              // Image if available
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.bgSecondary,
                        child: const Center(child: Text('Image not available')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Column(
                  children: rows.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.key,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(entry.value),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),

              // AI Analysis if available
              if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF3E5F5), Color(0xFFE8EAF6)],
                    ),
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
                      const SizedBox(height: 8),
                      Text(
                        aiAnalysis,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: This is AI-generated analysis for informational purposes only.',
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
            ],
          ),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
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
                      const Icon(Icons.flag, color: AppColors.brandPrimary),
                      const SizedBox(width: 8),
                      const Text(
                        'Conclude Pregnancy',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Outcome dropdown
                  DropdownButtonFormField<String>(
                    value: outcome,
                    decoration: const InputDecoration(labelText: 'Outcome'),
                    items: const [
                      DropdownMenuItem(value: 'live_birth', child: Text('Live Birth')),
                      DropdownMenuItem(value: 'stillbirth', child: Text('Stillbirth')),
                      DropdownMenuItem(value: 'miscarriage', child: Text('Miscarriage')),
                      DropdownMenuItem(value: 'abortion', child: Text('Abortion')),
                      DropdownMenuItem(value: 'ectopic', child: Text('Ectopic')),
                    ],
                    onChanged: (v) => setModal(() => outcome = v ?? outcome),
                  ),
                  const SizedBox(height: 8),

                  // Outcome date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Outcome Date'),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(outcomeDate!)),
                    trailing: const Icon(Icons.calendar_today),
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
                  ),

                  // Delivery details for live birth/stillbirth
                  if (outcome == 'live_birth' || outcome == 'stillbirth') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(labelText: 'Place of Delivery'),
                      onChanged: (v) => placeOfDelivery = v,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: deliveryMethod,
                      decoration: const InputDecoration(labelText: 'Delivery Method'),
                      items: const [
                        DropdownMenuItem(value: 'NSD', child: Text('Normal Spontaneous Delivery')),
                        DropdownMenuItem(value: 'CS', child: Text('Cesarean Section')),
                        DropdownMenuItem(value: 'Instrumental', child: Text('Instrumental')),
                      ],
                      onChanged: (v) => setModal(() => deliveryMethod = v),
                    ),
                  ],

                  const SizedBox(height: 8),
                  TextField(
                    controller: gestAgeController,
                    decoration: const InputDecoration(labelText: 'Gestational Age at End (weeks)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => gestationalAge = double.tryParse(v),
                  ),
                  const SizedBox(height: 16),

                  // Submit button
                  ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Conclude Pregnancy'),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Pregnancy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Last Menstrual Period'),
              subtitle: Text(lmp == null ? 'Select date' : DateFormat('MMM d, yyyy').format(lmp!)),
              trailing: const Icon(Icons.calendar_today),
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
            ),
            if (lmp != null) ...[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Estimated Due Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(edd!)),
                trailing: const Icon(Icons.event_available),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  // Navigate to ultrasound analyzer
  void _goToUltrasoundAnalyzer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UltrasoundAnalyzerScreen(),
      ),
    ).then((_) => _refresh());
  }

  // Navigate to lab test analyzer
  void _goToLabTestAnalyzer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LabTestAnalyzerScreen(),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mother Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Current'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No profile data found'));
          }

          final profile = snapshot.data!;
          final currentPregnancy = profile['current_pregnancy'] as Map<String, dynamic>?;
          final pastPregnancies = profile['past_pregnancies'] as List? ?? [];
          final medicalConditions = profile['medical_conditions'] as List? ?? [];
          final allergies = profile['allergies'] as List? ?? [];
          final emergencyContacts = profile['emergency_contacts'] as List? ?? [];
          final children = profile['children'] as List? ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              // OVERVIEW TAB
              _buildOverviewTab(profile, medicalConditions, allergies, emergencyContacts, children),
              
              // CURRENT PREGNANCY TAB
              _buildCurrentPregnancyTab(profile, currentPregnancy),
              
              // HISTORY TAB
              _buildHistoryTab(pastPregnancies),
            ],
          );
        },
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
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'M',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
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
                        Text(
                          profile['email_address'] ?? '—',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          profile['phone_number'] ?? '—',
                          style: const TextStyle(color: AppColors.textSecondary),
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
                  child: _buildStatCard(
                    'Age',
                    profile['birthdate'] != null
                        ? '${DateTime.now().difference(DateTime.parse(profile['birthdate'])).inDays ~/ 365} yrs'
                        : '—',
                    Icons.cake,
                    Colors.pink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Children',
                    '${profile['children_count'] ?? 0}',
                    Icons.child_care,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Pregnancies',
                    '${profile['pregnancies_count'] ?? 0}',
                    Icons.pregnant_woman,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Analysis Tools
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandPrimary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          'Ultrasound',
                          Icons.photo,
                          Colors.purple,
                          _goToUltrasoundAnalyzer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          'Lab Test',
                          Icons.science,
                          Colors.orange,
                          _goToLabTestAnalyzer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Personal Information
            _buildSection('Personal Information', [
              _buildInfoRow('Birthdate', _formatDate(profile['birthdate'])),
              _buildInfoRow('Blood Type', profile['blood_type'] ?? '—'),
              _buildInfoRow('Height', profile['height'] != null ? '${profile['height']} cm' : '—'),
              _buildInfoRow('Weight', profile['weight'] != null ? '${profile['weight']} kg' : '—'),
            ]),

            // Address
            _buildSection('Address', [
              _buildInfoRow('House No.', profile['house_number'] ?? '—'),
              _buildInfoRow('Street', profile['street'] ?? '—'),
              _buildInfoRow('Barangay', profile['barangay'] ?? '—'),
              _buildInfoRow('City', profile['city_municipality'] ?? '—'),
              _buildInfoRow('Province', profile['province'] ?? '—'),
            ]),

            // Medical Conditions
            _buildExpandableSection(
              'Medical Conditions (${medicalConditions.length})',
              medicalConditions.isEmpty
                  ? [const Text('No medical conditions recorded')]
                  : medicalConditions.map<Widget>((c) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c['condition_name'] ?? '—'),
                      subtitle: Text(
                        '${c['status'] ?? 'active'} • ${_formatDate(c['diagnosis_date'])}',
                      ),
                    )).toList(),
            ),

            // Allergies
            _buildExpandableSection(
              'Allergies (${allergies.length})',
              allergies.isEmpty
                  ? [const Text('No allergies recorded')]
                  : allergies.map<Widget>((a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a['allergen'] ?? '—'),
                      subtitle: Text(
                        '${a['status'] ?? 'active'} • ${_formatDate(a['diagnosis_date'])}',
                      ),
                    )).toList(),
            ),

            // Emergency Contacts
            _buildSection('Emergency Contacts', [
              if (emergencyContacts.isEmpty)
                const Text('No emergency contacts')
              else
                ...emergencyContacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                      Text('📞 ${c['phone_number'] ?? '—'}'),
                      if (c['affiliation'] != null) Text('🏥 ${c['affiliation']}'),
                    ],
                  ),
                )),
            ]),

            // Children
            _buildSection('Children', [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search children...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _childQuery = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _childSort,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Most recent')),
                  DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                ],
                onChanged: (v) => setState(() => _childSort = v ?? 'recent'),
              ),
              const SizedBox(height: 8),
              ..._filterAndSortChildren(children).map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.bgSecondary,
                    child: Text(
                      c['first_name']?.toString().substring(0, 1).toUpperCase() ?? 'C',
                    ),
                  ),
                  title: Text([
                    c['first_name'],
                    c['middle_name'],
                    c['last_name'],
                  ].where((e) => e != null).join(' ')),
                  subtitle: Text('Added: ${_formatDate(c['added_at'])}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to child profile (to be implemented)
                  },
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // CURRENT PREGNANCY TAB
  Widget _buildCurrentPregnancyTab(Map<String, dynamic> profile, Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pregnant_woman, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'No ongoing pregnancy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _startNewPregnancy,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start New Pregnancy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions
            _buildSection('Quick Actions', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to add prenatal checkup (to be implemented)
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Checkup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _goToUltrasoundAnalyzer,
                    icon: const Icon(Icons.photo),
                    label: const Text('Add Ultrasound'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _goToLabTestAnalyzer,
                    icon: const Icon(Icons.science),
                    label: const Text('Add Lab Test'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showConcludePregnancyDialog(pregnancy),
                    icon: const Icon(Icons.flag),
                    label: const Text('Conclude'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 16),

            // Pregnancy Stats
            _buildSection('Pregnancy Stats', [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Gestation',
                      gestWeeks != null ? '$gestWeeks weeks' : '—',
                      Icons.timeline,
                      AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Days to EDD',
                      daysToEdd != null ? daysToEdd.toString() : '—',
                      Icons.event_available,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Checkups',
                      sortedCheckups.length.toString(),
                      Icons.fact_check,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Risk Level',
                      pregnancy['pregnancy_risk_level']?.toString().toUpperCase() ?? '—',
                      Icons.warning,
                      pregnancy['pregnancy_risk_level'] == 'high'
                          ? Colors.red
                          : pregnancy['pregnancy_risk_level'] == 'medium'
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 16),

            // Pregnancy Details
            _buildSection('Pregnancy Details', [
              _buildInfoRow('LMP', _formatDate(pregnancy['last_menstrual_period'])),
              _buildInfoRow('EDD', _formatDate(pregnancy['expected_date_of_delivery'])),
              _buildInfoRow('Status', pregnancy['status']?.toString().toUpperCase() ?? '—'),
            ]),

            const SizedBox(height: 16),

            // Checkups
            _buildSection('Prenatal Checkups', [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                  DropdownButton<String>(
                    value: _checkupSort,
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Newest first')),
                      DropdownMenuItem(value: 'asc', child: Text('Oldest first')),
                    ],
                    onChanged: (v) => setState(() => _checkupSort = v ?? 'desc'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sortedCheckups.isEmpty)
                const Text('No checkups recorded')
              else
                ...sortedCheckups.map((c) => _buildCheckupCard(c)),
            ]),

            const SizedBox(height: 16),

            // Ultrasounds
            _buildSection('Ultrasounds', [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                  DropdownButton<String>(
                    value: _ultrasoundSort,
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Newest first')),
                      DropdownMenuItem(value: 'asc', child: Text('Oldest first')),
                    ],
                    onChanged: (v) => setState(() => _ultrasoundSort = v ?? 'desc'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (ultrasounds.isEmpty)
                const Text('No ultrasounds recorded')
              else
                ..._sortByDate(ultrasounds, 'ultrasound_date', _ultrasoundSort).map(
                  (u) => _buildUltrasoundCard(u),
                ),
            ]),

            const SizedBox(height: 16),

            // Lab Tests
            _buildSection('Lab Tests', [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                  DropdownButton<String>(
                    value: _labSort,
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Newest first')),
                      DropdownMenuItem(value: 'asc', child: Text('Oldest first')),
                    ],
                    onChanged: (v) => setState(() => _labSort = v ?? 'desc'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (labTests.isEmpty)
                const Text('No lab tests recorded')
              else
                ..._sortByDate(labTests, 'lab_test_date', _labSort).map(
                  (l) => _buildLabTestCard(l),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // HISTORY TAB
  Widget _buildHistoryTab(List pastPregnancies) {
    if (pastPregnancies.isEmpty) {
      return const Center(
        child: Text('No past pregnancies recorded'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
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
                backgroundColor: AppColors.bgSecondary,
                child: const Icon(Icons.pregnant_woman, color: AppColors.brandPrimary),
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
                        const SizedBox(height: 8),
                        const Text('Delivery Details',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildExpandableSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupCard(Map<String, dynamic> checkup) {
    final date = _formatDateTime(checkup['checkup_datetime']);
    final bpSys = _formatValue(checkup['blood_pressure_systolic']);
    final bpDia = _formatValue(checkup['blood_pressure_diastolic']);
    final aog = _formatValue(checkup['age_of_gestation']);
    final weight = _formatValue(checkup['checkup_weight']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medical_services, color: AppColors.brandPrimary),
        title: Text('Checkup • $date'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bpSys != '—' && bpDia != '—')
              Text('BP: $bpSys/$bpDia'),
            if (aog != '—')
              Text('AOG: $aog weeks'),
            if (weight != '—')
              Text('Weight: $weight kg'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
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
        leading: const Icon(Icons.monitor_heart, color: Colors.purple),
        title: Text('Ultrasound • $date'),
        subtitle: Text(ultrasound['ultrasound_location'] ?? '—'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showRecordDetails(
            title: 'Ultrasound',
            subtitle: date,
            icon: Icons.monitor_heart,
            imageUrl: ultrasound['ultrasound_image'],
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
        leading: const Icon(Icons.science, color: Colors.orange),
        title: Text('$type • $date'),
        subtitle: Text(labTest['lab_test_location'] ?? '—'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showRecordDetails(
            title: type,
            subtitle: date,
            icon: Icons.science,
            imageUrl: labTest['lab_test_image'],
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