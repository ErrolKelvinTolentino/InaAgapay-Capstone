import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/mother_profile_service.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../midwife/ultrasound_analyzer_screen.dart';
import '../midwife/lab_test_analyzer_screen.dart';
import '../midwife/add_prenatal_checkup_screen.dart';
import '../../widgets/headline.dart';
import '../../widgets/main_button.dart';
import '../../widgets/overview_info.dart';
import '../../services/risk_engine.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/status_indicator.dart';

// Blood type options
const List<String> _bloodTypeOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
// Extension name options
const List<String> _extensionOptions = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({super.key, required this.motherId});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _profileFuture;
  late TabController _tabController;

  // Sort states
  String _checkupSort = 'desc';
  String _ultrasoundSort = 'desc';
  String _labSort = 'desc';
  final Set<String> _expandedLabInsightAspects = <String>{};
  StateSetter? _recordDetailsModalSetState;
  
  // Edit mode states
  bool _isEditingPersonal = false;
  bool _isEditingAddress = false;
  final Map<String, TextEditingController> _personalControllers = {};
  final Map<String, TextEditingController> _addressControllers = {};
  
  // Dropdown selections for editing
  String _editingBloodType = '';
  String _editingExtension = '';
  
  // Profile picture
  String? _profilePictureUrl;
  
  // Latest growth data
  Map<String, dynamic>? _latestGrowthData;
  bool _loadingGrowth = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
    _loadProfilePicture();
    _loadLatestGrowthData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _personalControllers.values) {
      controller.dispose();
    }
    for (var controller in _addressControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfilePicture() async {
    final url = await SupabaseService.getProfilePictureUrl(widget.motherId);
    if (mounted) {
      setState(() {
        _profilePictureUrl = url;
      });
    }
  }

  Future<void> _loadLatestGrowthData() async {
    setState(() => _loadingGrowth = true);
    
    try {
      final pregnanciesResponse = await SupabaseService.client
          .from('pregnancies')
          .select('pregnancy_id')
          .eq('mother_id', widget.motherId)
          .eq('status', 'ongoing')
          .maybeSingle();
      
      if (pregnanciesResponse == null) {
        setState(() {
          _latestGrowthData = null;
          _loadingGrowth = false;
        });
        return;
      }
      
      final pregnancyId = pregnanciesResponse['pregnancy_id'] as int;
      
      final checkupResponse = await SupabaseService.client
          .from('prenatal_checkups')
          .select('''
            prenatal_checkup_id,
            checkup_datetime,
            age_of_gestation,
            checkup_weight,
            blood_pressure_systolic,
            blood_pressure_diastolic,
            fetal_heart_beat,
            edema
          ''')
          .eq('pregnancy_id', pregnancyId)
          .order('checkup_datetime', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (checkupResponse != null) {
        final weight = checkupResponse['checkup_weight'] as num?;
        final height = await _getMotherHeight();
        
        double? bmi;
        String? bmiStatus;
        
        if (weight != null && height != null && height > 0) {
          final heightM = height / 100;
          bmi = weight / (heightM * heightM);
          bmiStatus = _getBMIStatus(bmi);
        }
        
        setState(() {
          _latestGrowthData = {
            'date': checkupResponse['checkup_datetime'],
            'aog': checkupResponse['age_of_gestation']?.toString() ?? 'N/A',
            'weight': weight?.toDouble() ?? 0,
            'height': height ?? 0,
            'bmi': bmi,
            'bmi_status': bmiStatus,
          };
          _loadingGrowth = false;
        });
      } else {
        setState(() {
          _latestGrowthData = null;
          _loadingGrowth = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading growth data: $e');
      setState(() {
        _latestGrowthData = null;
        _loadingGrowth = false;
      });
    }
  }
  
  Future<double?> _getMotherHeight() async {
    try {
      final response = await SupabaseService.client
          .from('mothers')
          .select('height')
          .eq('mother_id', widget.motherId)
          .maybeSingle();
      
      if (response != null && response['height'] != null) {
        return (response['height'] as num).toDouble();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  String _getBMIStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
  
  Color _getBMIStatusColor(String status) {
    switch (status) {
      case 'Underweight': return AppColors.warning;
      case 'Normal': return AppColors.success;
      case 'Overweight': return AppColors.warning;
      case 'Obese': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = MotherProfileService.fetchMotherProfile(widget.motherId);
    });
    await _loadProfilePicture();
    await _loadLatestGrowthData();
  }

  // Helper methods
  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return date.toString();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
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
    if (value == null) return '-';
    final str = value.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  String _formatOutcome(String? outcome) {
    if (outcome == null) return '-';
    switch (outcome.toLowerCase()) {
      case 'live_birth': return 'Live Birth';
      case 'stillbirth': return 'Stillbirth';
      case 'miscarriage': return 'Miscarriage';
      case 'abortion': return 'Abortion';
      case 'ectopic': return 'Ectopic';
      default: return outcome;
    }
  }

  // ============================================================
  // RISK ASSESSMENT
  // ============================================================

  RiskAssessment _buildRiskAssessmentFromDb(
      Map<String, dynamic> profile, Map<String, dynamic>? pregnancy) {
    if (pregnancy == null) {
      return RiskAssessment(
        level: 'low',
        score: 0,
        factors: ['No ongoing pregnancy'],
        note: 'No ongoing pregnancy to assess.',
      );
    }

    final dbLevel = (pregnancy['pregnancy_risk_level'] as String?)?.toLowerCase();
    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final List<String> dbFactors = [];
    String? dbAiNote;

    for (final checkup in checkups) {
      final factors = checkup['risk_factors'] as List?;
      if (factors != null && factors.isNotEmpty) {
        for (final f in factors) {
          final factor = f['factor']?.toString() ?? '';
          if (factor.isNotEmpty) dbFactors.add(factor);
        }
        final aiResp = checkup['risk_ai_response'] as Map<String, dynamic>?;
        if (aiResp != null) {
          final resp = aiResp['response']?.toString();
          if (resp != null && resp.isNotEmpty) dbAiNote = resp;
        }
        break;
      }
    }

    String baselineLevel = 'low';
    double baselineScore = 5;
    String baselineNote = 'No significant risk factors identified.';
    final baselineFactors = <String>[];

    if (dbLevel != null && dbLevel.isNotEmpty) {
      baselineLevel = ['high', 'medium', 'low'].contains(dbLevel) ? dbLevel : 'low';
      baselineScore = baselineLevel == 'high' ? 60 : baselineLevel == 'medium' ? 30 : 5;
      baselineFactors.addAll(dbFactors.isNotEmpty ? dbFactors : ['No risk factors recorded yet']);
      baselineNote = dbAiNote ?? (baselineLevel == 'high' 
          ? 'High-risk pregnancy. Close monitoring required. Consult with specialist.'
          : baselineLevel == 'medium'
              ? 'Moderate risk factors present. Regular monitoring recommended.'
              : 'No significant risk factors identified.');
    }

    return RiskAssessment(
      level: baselineLevel,
      score: baselineScore,
      factors: baselineFactors,
      note: baselineNote,
    );
  }

  Widget _buildStructuredRiskAssessment(RiskAssessment assessment) {
    final levelColor = assessment.level == 'high' ? AppColors.error 
        : assessment.level == 'medium' ? AppColors.warning : AppColors.success;
    final levelIcon = assessment.level == 'high' ? Icons.warning_amber_rounded
        : assessment.level == 'medium' ? Icons.info_outline : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: levelColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(levelIcon, color: levelColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Risk Assessment', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(assessment.level.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: levelColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('Score: ${assessment.score.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: levelColor)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📋 Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(assessment.note, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('⚠️ Risk Factors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...assessment.factors.map((factor) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6, decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(factor, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ============================================================
  // EDITABLE FUNCTIONS
  // ============================================================

  void _initializePersonalControllers(Map<String, dynamic> profile) {
    // Editable fields only
    _personalControllers['height'] = TextEditingController(text: profile['height']?.toString() ?? '');
    _personalControllers['weight'] = TextEditingController(text: profile['weight']?.toString() ?? '');
    _editingBloodType = profile['blood_type'] ?? '';
    
    // Get extension name from account
    final account = profile['account'] as Map<String, dynamic>? ?? {};
    _editingExtension = account['extension_name'] ?? '';
  }

  Future<void> _savePersonalInfo() async {
    final accountId = await AuthStorage.getUserId();
    if (accountId == null) return;

    try {
      // Only update editable fields
      await SupabaseService.client.from('accounts').update({
        'extension_name': _editingExtension.isEmpty ? null : _editingExtension,
      }).eq('account_id', accountId);

      await SupabaseService.client.from('mothers').update({
        'height': double.tryParse(_personalControllers['height']?.text.trim() ?? ''),
        'weight': double.tryParse(_personalControllers['weight']?.text.trim() ?? ''),
        'blood_type': _editingBloodType.isEmpty ? null : _editingBloodType,
      }).eq('mother_id', widget.motherId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical information updated'), backgroundColor: AppColors.success),
        );
        setState(() => _isEditingPersonal = false);
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _initializeAddressControllers(Map<String, dynamic> profile) {
    _addressControllers['house_number'] = TextEditingController(text: profile['house_number'] ?? '');
    _addressControllers['street'] = TextEditingController(text: profile['street'] ?? '');
    _addressControllers['barangay'] = TextEditingController(text: profile['barangay'] ?? '');
    _addressControllers['city'] = TextEditingController(text: profile['city_municipality'] ?? '');
    _addressControllers['province'] = TextEditingController(text: profile['province'] ?? '');
  }

  Future<void> _saveAddress() async {
    try {
      await SupabaseService.client.from('mothers').update({
        'house_number': _addressControllers['house_number']?.text.trim(),
        'street': _addressControllers['street']?.text.trim(),
        'barangay': _addressControllers['barangay']?.text.trim(),
        'city_municipality': _addressControllers['city']?.text.trim(),
        'province': _addressControllers['province']?.text.trim(),
      }).eq('mother_id', widget.motherId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address updated'), backgroundColor: AppColors.success),
        );
        setState(() => _isEditingAddress = false);
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ============================================================
  // LATEST GROWTH RECORDS CARD (Only Height, Weight, BMI)
  // ============================================================

  Widget _buildLatestGrowthCard() {
    if (_loadingGrowth) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      );
    }
    
    if (_latestGrowthData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: const Column(
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text(
              'No growth data yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Growth data will appear after first prenatal checkup',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    final data = _latestGrowthData!;
    final bmiStatusColor = _getBMIStatusColor(data['bmi_status'] ?? 'Normal');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Latest Growth Records',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 12),
          
          // Date and AOG
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppColors.brandPrimary),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(data['date']),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (data['aog'] != 'N/A')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data['aog']} weeks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Height, Weight, BMI (3 columns)
          Row(
            children: [
              Expanded(
                child: _buildGrowthMetric(
                  icon: Icons.height,
                  label: 'Height',
                  value: data['height'] > 0 ? '${data['height'].toStringAsFixed(1)} cm' : 'Not recorded',
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGrowthMetric(
                  icon: Icons.monitor_weight,
                  label: 'Weight',
                  value: data['weight'] > 0 ? '${data['weight'].toStringAsFixed(1)} kg' : 'Not recorded',
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGrowthMetric(
                  icon: Icons.calculate,
                  label: 'BMI',
                  value: data['bmi'] != null ? '${data['bmi']!.toStringAsFixed(1)} (${data['bmi_status']})' : 'Not calculated',
                  color: bmiStatusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGrowthMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CURRENT PREGNANCY TAB
  // ============================================================

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
                decoration: BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
                child: const Icon(Icons.pregnant_woman, size: 64, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Ongoing Pregnancy'),
              const SizedBox(height: 8),
              const Text('Start a new pregnancy to begin tracking', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              MainButton(label: 'Start New Pregnancy', onPressed: () => _startNewPregnancyDialog(profile)),
            ],
          ),
        ),
      );
    }

    final checkups = (pregnancy['checkups'] as List?) ?? [];
    final ultrasounds = (pregnancy['ultrasounds'] as List?) ?? [];
    final labTests = (pregnancy['lab_tests'] as List?) ?? [];

    final sortedCheckups = List<Map<String, dynamic>>.from(checkups);
    sortedCheckups.sort((a, b) {
      final dateA = DateTime.tryParse(a['checkup_datetime'] ?? '');
      final dateB = DateTime.tryParse(b['checkup_datetime'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return _checkupSort == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    final lmp = DateTime.tryParse(pregnancy['last_menstrual_period'] ?? '');
    final edd = DateTime.tryParse(pregnancy['expected_date_of_delivery'] ?? '');
    final now = DateTime.now();
    final gestWeeks = lmp != null ? (now.difference(lmp).inDays / 7).floor() : null;
    final daysToEdd = edd?.difference(now).inDays;
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
            _buildStructuredRiskAssessment(riskAssessment),
            const SizedBox(height: 16),
            
            // Quick Stats Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(gestWeeks != null ? '$gestWeeks' : '-', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
                            const Text('Weeks', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(height: 40, width: 1, color: AppColors.borderPrimary),
                      Expanded(
                        child: Column(
                          children: [
                            Text(daysToEdd != null ? daysToEdd.toString() : '-', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
                            const Text('Days to EDD', style: TextStyle(color: AppColors.textSecondary)),
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
                        child: Row(
                          children: [
                            Icon(Icons.fact_check, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(sortedCheckups.length.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Text('Checkups', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: pregnancy['pregnancy_risk_level'] == 'high' ? Colors.red : AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(pregnancy['pregnancy_risk_level']?.toString().toUpperCase() ?? '-', 
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pregnancy['pregnancy_risk_level'] == 'high' ? Colors.red : null)),
                          ],
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton('Add Checkup', Icons.add, AppColors.brandPrimary, () async {
                          final pregnancyId = pregnancy['pregnancy_id'];
                          if (pregnancyId == null) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddPrenatalCheckupScreen(
                                motherId: widget.motherId,
                                pregnancyId: pregnancyId as int,
                                lmp: DateTime.tryParse(pregnancy['last_menstrual_period'] ?? ''),
                                motherWeight: _toDouble(profile['weight']),
                              ),
                            ),
                          );
                          _refresh();
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton('Ultrasound', Icons.photo, Colors.purple, () => _goToUltrasoundAnalyzer(pregnancy)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton('Lab Test', Icons.science, Colors.orange, () => _goToLabTestAnalyzer(pregnancy)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton('Conclude', Icons.flag, Colors.red, () => _showConcludePregnancyDialog(pregnancy)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pregnancy Details
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline, color: AppColors.brandPrimary, size: 18),
                ),
                title: const Text('Pregnancy Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow('LMP', _formatDate(pregnancy['last_menstrual_period'])),
                        _buildInfoRow('EDD', _formatDate(pregnancy['expected_date_of_delivery'])),
                        _buildInfoRow('Status', pregnancy['status']?.toString().toUpperCase() ?? '-'),
                        _buildInfoRow('Fetal Count', pregnancy['fetal_count']?.toString() ?? '1'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Prenatal Checkups
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.medical_services, color: AppColors.brandPrimary, size: 18),
                ),
                title: const Text('Prenatal Checkups', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(8)),
                              child: DropdownButton<String>(
                                value: _checkupSort,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'desc', child: Text('Newest First')),
                                  DropdownMenuItem(value: 'asc', child: Text('Oldest First')),
                                ],
                                onChanged: (v) => setState(() => _checkupSort = v ?? 'desc'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sortedCheckups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No checkups recorded', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        else
                          ...sortedCheckups.map((c) => _buildCheckupCard(c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Ultrasounds
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo, color: Colors.purple, size: 18),
                ),
                title: const Text('Ultrasounds', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(8)),
                              child: DropdownButton<String>(
                                value: _ultrasoundSort,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'desc', child: Text('Newest First')),
                                  DropdownMenuItem(value: 'asc', child: Text('Oldest First')),
                                ],
                                onChanged: (v) => setState(() => _ultrasoundSort = v ?? 'desc'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (ultrasounds.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No ultrasounds recorded', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        else
                          ..._sortByDate(ultrasounds, 'ultrasound_date', _ultrasoundSort).map((u) => _buildUltrasoundCard(u)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lab Tests
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.science, color: Colors.orange, size: 18),
                ),
                title: const Text('Lab Tests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(8)),
                              child: DropdownButton<String>(
                                value: _labSort,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'desc', child: Text('Newest First')),
                                  DropdownMenuItem(value: 'asc', child: Text('Oldest First')),
                                ],
                                onChanged: (v) => setState(() => _labSort = v ?? 'desc'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (labTests.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No lab tests recorded', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        else
                          ..._sortByDate(labTests, 'lab_test_date', _labSort).map((l) => _buildLabTestCard(l)),
                      ],
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

  // ============================================================
  // HISTORY TAB
  // ============================================================

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
                decoration: BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
                child: const Icon(Icons.history, size: 64, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Headline(text: 'No Past Pregnancies'),
              const SizedBox(height: 8),
              const Text('Past pregnancies will appear here', style: TextStyle(color: AppColors.textSecondary)),
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
          final deliveries = (p['delivery'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final outcomesList = (p['outcomes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          final normalizedOutcomes = outcomesList.isNotEmpty
              ? outcomesList
              : (p['outcome'] != null || p['outcome_date'] != null)
                  ? [{'fetus_number': 1, 'outcome': p['outcome'], 'outcome_date': p['outcome_date']}]
                  : [];

          final primaryOutcomeStr = normalizedOutcomes.isNotEmpty
              ? outcomesList.map((o) => _formatOutcome(o['outcome'] as String?)).join(', ')
              : '-';
          final primaryOutcomeDate = normalizedOutcomes.isNotEmpty
              ? _formatDate(normalizedOutcomes.first['outcome_date'] as String?)
              : '-';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                child: Icon(Icons.pregnant_woman, color: AppColors.brandPrimary),
              ),
              title: Text(primaryOutcomeStr),
              subtitle: Text('Ended: $primaryOutcomeDate'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Gestational Age', p['gestational_age_at_end'] != null ? '${p['gestational_age_at_end']} weeks' : '-'),
                      const SizedBox(height: 8),
                      for (int i = 0; i < normalizedOutcomes.length; i++) ...[
                        if (normalizedOutcomes.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('Fetus ${normalizedOutcomes[i]['fetus_number'] ?? (i + 1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        _buildInfoRow('Outcome', _formatOutcome(normalizedOutcomes[i]['outcome'] as String?)),
                        _buildInfoRow('Date', _formatDate(normalizedOutcomes[i]['outcome_date'] as String?)),
                        ...() {
                          final deliveryList = deliveries.where((d) => d['fetus_number'] == normalizedOutcomes[i]['fetus_number']).toList();
                          if (deliveryList.isNotEmpty) {
                            final delivery = deliveryList.first;
                            return [
                              _buildInfoRow('Place', delivery['place_of_delivery']?.toString() ?? '-'),
                              _buildInfoRow('Method', delivery['delivery_method']?.toString() ?? '-'),
                            ];
                          }
                          return [];
                        }(),
                        const SizedBox(height: 8),
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

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
          decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.medical_services, color: AppColors.brandPrimary, size: 20),
        ),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: bpSys != '-' && bpDia != '-' ? Text('BP: $bpSys/$bpDia') : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () {
          _showRecordDetails(
            title: 'Prenatal Checkup',
            subtitle: date,
            icon: Icons.medical_services,
            rows: [
              MapEntry('Date', _formatDateTime(checkup['checkup_datetime'])),
              MapEntry('Age of Gestation', _formatValue(checkup['age_of_gestation'])),
              MapEntry('Weight', _formatValue(checkup['checkup_weight'])),
              MapEntry('Blood Pressure', '$bpSys/$bpDia'),
              MapEntry('Fetal Heart Rate', _formatValue(checkup['fetal_heart_beat'])),
              MapEntry('Edema', _formatValue(checkup['edema'])),
              MapEntry('TD Vaccine', _formatValue(checkup['td_vaccine_dose'])),
              MapEntry('Remarks', _formatValue(checkup['remarks'])),
              MapEntry('Next Schedule', _formatDate(checkup['next_schedule'])),
            ],
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
          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.photo, color: Colors.purple, size: 20),
        ),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () {
          List<String> imageUrls = [];
          if (ultrasound['ultrasound_image'] != null) {
            final imageField = ultrasound['ultrasound_image'].toString();
            if (imageField.contains(',')) {
              imageUrls = imageField.split(',').map((url) => url.trim()).toList();
            } else if (imageField.isNotEmpty) {
              imageUrls = [imageField];
            }
          }
          _showRecordDetails(
            title: 'Ultrasound',
            subtitle: date,
            icon: Icons.monitor_heart,
            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
            rows: [
              MapEntry('Date', date),
              MapEntry('Location', _formatValue(ultrasound['ultrasound_location'])),
              MapEntry('Health Worker', _formatValue(ultrasound['health_worker_name'])),
              MapEntry('Remarks', _formatValue(ultrasound['remarks'])),
            ],
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
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.science, color: Colors.orange, size: 20),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(date),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () {
          List<String> imageUrls = [];
          if (labTest['lab_test_image'] != null) {
            final imageField = labTest['lab_test_image'].toString();
            if (imageField.contains(',')) {
              imageUrls = imageField.split(',').map((url) => url.trim()).toList();
            } else if (imageField.isNotEmpty) {
              imageUrls = [imageField];
            }
          }
          _showRecordDetails(
            title: type,
            subtitle: date,
            icon: Icons.science,
            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
            rows: [
              MapEntry('Test Type', type),
              MapEntry('Date', date),
              MapEntry('Health Worker', _formatValue(labTest['health_worker_name'])),
              MapEntry('Remarks', _formatValue(labTest['remarks'])),
            ],
          );
        },
      ),
    );
  }

  void _showRecordDetails({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<MapEntry<String, String>> rows,
    List<String>? imageUrls,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
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
                          decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: AppColors.brandPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.bgSecondary,
                                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                    ),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: rows.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 120, child: Text(entry.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                              Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _showConcludePregnancyDialog(Map<String, dynamic> pregnancy) async {
    final int fetalCount = pregnancy['fetal_count'] as int? ?? 1;
    final List<String> outcomes = List.filled(fetalCount, 'live_birth');
    final List<DateTime> outcomeDates = List.filled(fetalCount, DateTime.now());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conclude Pregnancy'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: Column(
            children: [
              const Text('Are you sure you want to conclude this pregnancy?'),
              const SizedBox(height: 16),
              for (int i = 0; i < fetalCount; i++) ...[
                if (fetalCount > 1) Text('Fetus ${i + 1}:'),
                DropdownButtonFormField<String>(
                  value: outcomes[i],
                  items: const [
                    DropdownMenuItem(value: 'live_birth', child: Text('Live Birth')),
                    DropdownMenuItem(value: 'stillbirth', child: Text('Stillbirth')),
                    DropdownMenuItem(value: 'miscarriage', child: Text('Miscarriage')),
                    DropdownMenuItem(value: 'abortion', child: Text('Abortion')),
                    DropdownMenuItem(value: 'ectopic', child: Text('Ectopic')),
                  ],
                  onChanged: (v) => outcomes[i] = v ?? 'live_birth',
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Conclude')),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pregnancy concluded'), backgroundColor: AppColors.success),
      );
      _refresh();
    }
  }

  Future<void> _startNewPregnancyDialog(Map<String, dynamic> profile) async {
    final lmpCtrl = TextEditingController();
    DateTime? lmp;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start New Pregnancy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(lmp == null ? 'Select LMP Date' : _formatDate(lmp)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  lmp = picked;
                  lmpCtrl.text = _formatDate(picked);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: lmp != null ? () => Navigator.pop(context, true) : null, child: const Text('Start')),
        ],
      ),
    );

    if (confirmed == true && lmp != null) {
      final edd = lmp!.add(const Duration(days: 280));
      final success = await MotherProfileService.startNewPregnancy(widget.motherId, lmp!, edd);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New pregnancy started'), backgroundColor: AppColors.success),
        );
        _refresh();
      }
    }
  }

  // ============================================================
  // MEDICAL INFORMATION SECTION (WITHOUT NAME/PHONE/EMAIL)
  // ============================================================

  Widget _buildMedicalInfoSection(Map<String, dynamic> profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.medical_information, color: AppColors.brandPrimary, size: 18),
        ),
        title: const Text('Medical Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Birthdate (read-only)
                _buildInfoRow('Birthdate', _formatDate(profile['birthdate'])),
                
                const SizedBox(height: 8),
                
                // Height (editable - shown in edit mode)
                _buildInfoRow('Height', _personalControllers['height']?.text.isNotEmpty == true 
                    ? '${_personalControllers['height']?.text} cm' 
                    : 'Not set'),
                
                const SizedBox(height: 8),
                
                // Weight (editable - shown in edit mode)
                _buildInfoRow('Weight', _personalControllers['weight']?.text.isNotEmpty == true 
                    ? '${_personalControllers['weight']?.text} kg' 
                    : 'Not set'),
                
                const SizedBox(height: 8),
                
                // Blood Type (editable dropdown)
                _buildInfoRow('Blood Type', profile['blood_type'] ?? 'Not set'),
                
                const SizedBox(height: 8),
                
                // Extension Name (editable dropdown)
                _buildInfoRow('Extension Name', profile['extension_name'] ?? 'None'),
                
                const SizedBox(height: 16),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isEditingPersonal = true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Medical Info'),
                  ),
                ),
                
                if (_isEditingPersonal) ...[
                  const SizedBox(height: 12),
                  _buildEditableMedicalForm(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditingPersonal = false), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: _savePersonalInfo, style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary), child: const Text('Save Changes'))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlySection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.brandPrimary, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.brandPrimary, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableMedicalForm() {
    return Column(
      children: [
        TextField(
          controller: _personalControllers['height'],
          decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _personalControllers['weight'],
          decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        // Blood Type Dropdown
        DropdownButtonFormField<String>(
          value: _editingBloodType.isEmpty ? null : _editingBloodType,
          decoration: const InputDecoration(labelText: 'Blood Type', border: OutlineInputBorder()),
          items: _bloodTypeOptions.map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _editingBloodType = value ?? '';
            });
          },
        ),
        const SizedBox(height: 12),
        // Extension Name Dropdown
        DropdownButtonFormField<String>(
          value: _editingExtension.isEmpty ? null : _editingExtension,
          decoration: const InputDecoration(labelText: 'Extension Name', border: OutlineInputBorder()),
          items: _extensionOptions.map((ext) {
            return DropdownMenuItem(value: ext.isEmpty ? null : ext, child: Text(ext.isEmpty ? 'None' : ext));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _editingExtension = value ?? '';
            });
          },
        ),
      ],
    );
  }

  Widget _buildEditableAddressForm() {
    return Column(
      children: [
        TextField(
          controller: _addressControllers['house_number'],
          decoration: const InputDecoration(labelText: 'House Number', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressControllers['street'],
          decoration: const InputDecoration(labelText: 'Street', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressControllers['barangay'],
          decoration: const InputDecoration(labelText: 'Barangay', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressControllers['city'],
          decoration: const InputDecoration(labelText: 'City/Municipality', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressControllers['province'],
          decoration: const InputDecoration(labelText: 'Province', border: OutlineInputBorder()),
        ),
      ],
    );
  }

  // ============================================================
  // OVERVIEW TAB
  // ============================================================

  Widget _buildOverviewTab(
    Map<String, dynamic> profile,
    List medicalConditions,
    List allergies,
    List emergencyContacts,
    List children,
    Map<String, dynamic>? currentPregnancy,
  ) {
    final riskAssessment = _buildRiskAssessmentFromDb(profile, currentPregnancy);
    _initializePersonalControllers(profile);
    _initializeAddressControllers(profile);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card with Profile Picture
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // Profile Picture or Avatar
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                      image: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_profilePictureUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                        ? Center(
                            child: Text(
                              profile['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'M',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile['full_name'] ?? 'Unnamed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(child: Text(profile['email_address'] ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(profile['phone_number'] ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                Expanded(child: OverviewInfo(value: profile['birthdate'] != null ? DateTime.now().difference(DateTime.parse(profile['birthdate'])).inDays ~/ 365 : 0, label: 'Age', icon: Icons.cake)),
                const SizedBox(width: 8),
                Expanded(child: OverviewInfo(value: profile['children_count'] ?? 0, label: 'Children', icon: Icons.child_care)),
                const SizedBox(width: 8),
                Expanded(child: OverviewInfo(value: profile['pregnancies_count'] ?? 0, label: 'Pregnancies', icon: Icons.pregnant_woman)),
              ],
            ),
            const SizedBox(height: 16),

            // Risk Assessment
            _buildStructuredRiskAssessment(riskAssessment),
            const SizedBox(height: 16),

            // Latest Growth Records
            _buildLatestGrowthCard(),
            const SizedBox(height: 16),

            // Medical Information (without name/phone/email)
            _buildMedicalInfoSection(profile),
            const SizedBox(height: 12),

            // Address
            _buildReadOnlySection(
              'Address',
              Icons.home_outlined,
              [
                _buildInfoRow('House No.', profile['house_number'] ?? '-'),
                _buildInfoRow('Street', profile['street'] ?? '-'),
                _buildInfoRow('Barangay', profile['barangay'] ?? '-'),
                _buildInfoRow('City', profile['city_municipality'] ?? '-'),
                _buildInfoRow('Province', profile['province'] ?? '-'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isEditingAddress = true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Address'),
                  ),
                ),
                if (_isEditingAddress) ...[
                  const SizedBox(height: 12),
                  _buildEditableAddressForm(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditingAddress = false), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: _saveAddress, style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary), child: const Text('Save Address'))),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Medical Conditions
            _buildExpandableSection(
              'Medical Conditions',
              Icons.medical_services_outlined,
              medicalConditions.isEmpty
                  ? [const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No medical conditions recorded', style: TextStyle(color: AppColors.textSecondary)))]
                  : medicalConditions.map<Widget>((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: c['status'] == 'active' ? Colors.orange : Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['condition_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${c['status'] ?? 'active'} - ${_formatDate(c['diagnosis_date'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  ? [const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No allergies recorded', style: TextStyle(color: AppColors.textSecondary)))]
                  : allergies.map<Widget>((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: a['status'] == 'active' ? Colors.orange : Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['allergen'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${a['status'] ?? 'active'} - ${_formatDate(a['diagnosis_date'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  ? [const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No emergency contacts', style: TextStyle(color: AppColors.textSecondary)))]
                  : emergencyContacts.map<Widget>((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([c['first_name'], c['middle_name'], c['last_name'], c['extension_name']].where((e) => e != null).join(' '), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(children: [const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary), const SizedBox(width: 4), Text(c['phone_number'] ?? '-')]),
                          if (c['affiliation'] != null) ...[
                            const SizedBox(height: 2),
                            Row(children: [const Icon(Icons.business, size: 14, color: AppColors.textSecondary), const SizedBox(width: 4), Text(c['affiliation'])]),
                          ],
                        ],
                      ),
                    )).toList(),
            ),
            const SizedBox(height: 12),

            // Children
            _buildExpandableSection(
              'Children',
              Icons.child_care,
              children.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(Icons.child_care_outlined, size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 8),
                            Text('No Children Registered', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    ]
                  : children.map<Widget>((child) {
                      final name = '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim();
                      final birthDetails = child['birth_details'] as Map<String, dynamic>?;
                      final birthdate = birthDetails?['birthdate'] != null ? DateTime.tryParse(birthDetails!['birthdate']) : null;
                      
                      String ageText = 'Age unknown';
                      if (birthdate != null) {
                        final now = DateTime.now();
                        int years = now.year - birthdate.year;
                        int months = now.month - birthdate.month;
                        if (months < 0) { years--; months += 12; }
                        if (years <= 0) {
                          ageText = '$months month${months != 1 ? 's' : ''} old';
                        } else {
                          ageText = '$years year${years != 1 ? 's' : ''} ${months > 0 ? '$months month${months != 1 ? 's' : ''}' : ''} old'.trim();
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: TextStyle(color: AppColors.brandPrimary)),
                          ),
                          title: Text(name.isNotEmpty ? name : 'Unnamed Child'),
                          subtitle: Text(ageText),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () {},
                        ),
                      );
                    }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER WITH PROFILE PICTURE
  // ============================================================

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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.favorite,
                    color: AppColors.brandPrimary,
                    size: 30,
                  ),
                ),
              ),
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
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                    image: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_profilePictureUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        )
                      : null,
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
          GestureDetector(onTap: () => entry.remove(), child: Container(color: Colors.black.withOpacity(0.35))),
          Positioned(
            top: 90,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(
                  children: [
                    _MenuItem(icon: Icons.person_outline, label: 'View Profile', onTap: () { entry.remove(); }),
                    _MenuItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () { entry.remove(); Navigator.pushNamed(context, '/settings'); }),
                    _MenuItem(icon: Icons.help_outline, label: 'Help', onTap: () { entry.remove(); Navigator.pushNamed(context, '/help'); }),
                    const Divider(height: 8),
                    _MenuItem(icon: Icons.logout_rounded, label: 'Log out', isDanger: true, onTap: () { entry.remove(); _confirmLogout(context); }),
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
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _logout(); }, child: const Text('Log out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await AuthStorage.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                const Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary)))),
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
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          const Headline(text: 'Error Loading Profile'),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(), style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          MainButton(label: 'Retry', onPressed: _refresh),
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
                const Expanded(child: Center(child: Text('No profile data found'))),
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
                            _buildOverviewTab(profile, medicalConditions, allergies, emergencyContacts, children, currentPregnancy),
                            _buildCurrentPregnancyTab(profile, currentPregnancy),
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
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.isDanger = false});

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
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}