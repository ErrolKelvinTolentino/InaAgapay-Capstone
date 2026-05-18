import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';
import '../../widgets/ai_analytics_card.dart';
import '../../services/groq_service.dart';
import '../../services/growth_calculator.dart';
import '../../services/language_service.dart';

class MotherViewChildPage extends StatefulWidget {
  final VoidCallback onBackToChildren;
  final VoidCallback onViewGrowth;
  final VoidCallback onViewVaccines;
  final int childId;
  final String childName;
  final String childAge;
  final String childGender;

  const MotherViewChildPage({
    super.key,
    required this.onBackToChildren,
    required this.onViewGrowth,
    required this.onViewVaccines,
    required this.childId,
    required this.childName,
    required this.childAge,
    required this.childGender,
  });

  @override
  State<MotherViewChildPage> createState() => _MotherViewChildPageState();
}

class _MotherViewChildPageState extends State<MotherViewChildPage> {
  bool loading = true;
  Map<String, dynamic>? childData;
  Map<String, dynamic>? birthData;
  Map<String, dynamic>? latestGrowth;
  List<Map<String, dynamic>> growthRecords = [];
  String? aiAnalysis;
  bool aiLoading = false;
  String? aiError;
  List<Map<String, dynamic>> immunizations = [];
  Map<String, dynamic>? guardianData;
  bool hasGuardian = false;

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    setState(() => loading = true);

    try {
      final childResponse =
          await Supabase.instance.client.from('children').select('''
            *,
            mother:mother_id (
              mother_id,
              account:account_id (
                first_name,
                last_name,
                middle_name
              )
            ),
            guardian:guardian_id (
              guardian_id,
              first_name,
              last_name,
              middle_name,
              extension_name,
              phone_number,
              address,
              relationship
            )
          ''').eq('child_id', widget.childId).single();

      childData = childResponse;

      final guardian = childResponse['guardian'] as Map<String, dynamic>?;
      hasGuardian = guardian != null && childResponse['mother_id'] == null;

      if (hasGuardian && guardian != null) {
        guardianData = guardian;
      }

      final birthResponse = await Supabase.instance.client
          .from('birth_details')
          .select('*')
          .eq('child_id', widget.childId)
          .maybeSingle();

      birthData = birthResponse;

      final growthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: true);

      growthRecords = List<Map<String, dynamic>>.from(growthResponse);
      latestGrowth = growthRecords.isNotEmpty ? growthRecords.last : null;

      if (latestGrowth != null && latestGrowth!['child_details_id'] != null) {
        await _loadProfileAiInsight(latestGrowth!['child_details_id'] as int);
      }

      final immunizationResponse = await Supabase.instance.client
          .from('immunization_record')
          .select('''
            *,
            vaccine:vaccine_id (*)
          ''')
          .eq('child_id', widget.childId)
          .order('vaccination_date', ascending: false)
          .limit(5);

      immunizations = List<Map<String, dynamic>>.from(immunizationResponse);

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String calculateAge() {
    if (birthData == null) return 'Unknown age';
    final birthdate = birthData!['birthdate']?.toString();
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
        return '$years year${years != 1 ? 's' : ''} ${months > 0 ? '$months month${months != 1 ? 's' : ''}' : ''} old'
            .trim();
      }
    } catch (e) {
      return 'Unknown age';
    }
  }

  int _ageInWeeks(DateTime recordDate) {
    if (birthData == null) return 0;
    final birthdate = birthData!['birthdate']?.toString();
    if (birthdate == null || birthdate.isEmpty) return 0;

    try {
      final birth = DateTime.parse(birthdate);
      final difference = recordDate.difference(birth);
      return (difference.inDays / 7).round();
    } catch (_) {
      return 0;
    }
  }

  double _calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return _t('Not recorded', 'Hindi naitala');
    }
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMMM d, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  String getParentName() {
    if (hasGuardian && guardianData != null) {
      final firstName = guardianData!['first_name']?.toString() ?? '';
      final lastName = guardianData!['last_name']?.toString() ?? '';
      return '$firstName $lastName';
    }

    final mother = childData?['mother'] as Map<String, dynamic>?;
    if (mother != null) {
      final account = mother['account'] as Map<String, dynamic>?;
      if (account != null) {
        final firstName = account['first_name']?.toString() ?? '';
        final lastName = account['last_name']?.toString() ?? '';
        return '$firstName $lastName';
      }
    }

    final firstName = childData?['first_name']?.toString() ?? '';
    final lastName = childData?['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : 'Child';
  }

  String getChildName() {
    final firstName = childData?['first_name']?.toString() ?? '';
    final lastName = childData?['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : 'Child';
  }

  String getParentRelationship() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['relationship']?.toString() ??
          _t('Guardian', 'Tagapag-alaga');
    }
    return _t('Mother', 'Ina');
  }

  String getGuardianPhone() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['phone_number']?.toString() ??
          _t('Not recorded', 'Hindi naitala');
    }
    return _t('Not recorded', 'Hindi naitala');
  }

  String getGuardianAddress() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['address']?.toString() ??
          _t('Not recorded', 'Hindi naitala');
    }
    return _t('Not recorded', 'Hindi naitala');
  }

  String getBirthPlace() {
    final city = birthData?['birthplace_city_municipality']?.toString() ?? '';
    final province = birthData?['birthplace_province']?.toString() ?? '';
    final facility = birthData?['birthplace_facility']?.toString() ?? '';

    final parts = [facility, city, province].where((p) => p.isNotEmpty);
    return parts.isNotEmpty
        ? parts.join(', ')
        : _t('Not recorded', 'Hindi naitala');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
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

    if (childData == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SecondaryHeader(
            title: _t('Child Information', 'Impormasyon ng Anak'),
            onBack: widget.onBackToChildren,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load child profile',
                style: TextStyle(color: AppColors.error, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final fullName =
        '${childData!['first_name']} ${childData!['last_name']}'.trim();
    final age = calculateAge();
    final sex = (childData!['sex'] ?? '').toString().toUpperCase();
    final birthPlace = getBirthPlace();
    final parentName = getParentName();
    final parentRelationship = getParentRelationship();

    final displayHeight = latestGrowth != null
        ? '${(latestGrowth!['child_height'] as num?)?.toStringAsFixed(1) ?? '0'} cm'
        : _t('Not recorded', 'Hindi naitala');

    final displayWeight = latestGrowth != null
        ? '${(latestGrowth!['child_weight'] as num?)?.toStringAsFixed(1) ?? '0'} kg'
        : _t('Not recorded', 'Hindi naitala');

    final latestBMI = _getLatestBMI();
    final bmiStatus = latestBMI != null ? _bmiStatus(latestBMI) : null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: _t('Child Information', 'Impormasyon ng Anak'),
          onBack: widget.onBackToChildren,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ── Hero Card ──────────────────────────────────────
              HeroCard(
                image: null,
                title: fullName.isNotEmpty ? fullName : 'Unnamed Child',
                subtitle: '$age • $sex',
                showWeekBadge: false,
                showHeartRow: false,
              ),

              const SizedBox(height: 20),

              // ── Quick Stats ────────────────────────────────────
              _buildQuickStatsRow(displayHeight, displayWeight),

              const SizedBox(height: 24),

              // ── Parent / Guardian ──────────────────────────────
              _buildGuardianCard(parentName, parentRelationship),

              const SizedBox(height: 16),

              // ── Birth Details ──────────────────────────────────
              RecordsDisplayCard(
                title: _t('Birth Details', 'Detalye ng Kapanganakan'),
                headerIcon: Icons.cake_outlined,
                items: [
                  RecordItem(
                    leadingIcon: Icons.calendar_month_rounded,
                    label: _t('Birth Date', 'Petsa ng Kapanganakan'),
                    value: formatDate(birthData?['birthdate']),
                  ),
                  RecordItem(
                    leadingIcon: Icons.place_outlined,
                    label: _t('Birthplace', 'Lugar ng Kapanganakan'),
                    value: birthPlace,
                  ),
                  RecordItem(
                    leadingIcon: Icons.straighten_outlined,
                    label: _t('Birth Length', 'Haba sa Kapanganakan'),
                    value: birthData?['birth_length'] != null
                        ? '${birthData!['birth_length']} cm'
                        : _t('Not recorded', 'Hindi naitala'),
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight_outlined,
                    label: _t('Birth Weight', 'Timbang sa Kapanganakan'),
                    value: birthData?['birth_weight'] != null
                        ? '${birthData!['birth_weight']} kg'
                        : _t('Not recorded', 'Hindi naitala'),
                  ),
                  RecordItem(
                    leadingIcon: Icons.circle_outlined,
                    label: _t('Head Circumference', 'Sukat ng Ulo'),
                    value: birthData?['head_circumference'] != null
                        ? '${birthData!['head_circumference']} cm'
                        : _t('Not recorded', 'Hindi naitala'),
                  ),
                ],
              ),

              _buildSectionDivider(),

              // ── Growth & Development ──────────────────────────
              _buildSectionHeader(
                title: _t('Growth & Development', 'Paglaki at Pag-unlad'),
                icon: Icons.trending_up,
                onViewAll: () {
                  widget.onViewGrowth();
                },
              ),
              const SizedBox(height: 12),

              _buildGrowthCards(displayHeight, displayWeight),
              const SizedBox(height: 12),
              _buildBMICard(latestBMI, bmiStatus),
              const SizedBox(height: 12),
              _buildProfileAiCard(),

              _buildSectionDivider(),

              // ── Immunization ───────────────────────────────────
              _buildSectionHeader(
                title: _t('Immunization', 'Bakuna'),
                icon: Icons.vaccines_outlined,
                onViewAll: () {
                  widget.onViewVaccines();
                },
              ),
              const SizedBox(height: 12),

              RecordsDisplayCard(
                title: _t('Recent Immunizations', 'Mga Kamakailang Bakuna'),
                headerIcon: Icons.vaccines_outlined,
                items: immunizations.isEmpty
                    ? [
                        RecordItem(
                          leadingIcon: Icons.info_outline,
                          label: _t('Status', 'Status'),
                          value: _t('No immunization records yet',
                              'Wala pang naitalang bakuna'),
                        ),
                      ]
                    : immunizations.map((imm) {
                        final vaccine = imm['vaccine'] as Map<String, dynamic>?;
                        return RecordItem(
                          leadingIcon: Icons.vaccines,
                          label: vaccine?['vaccine_name'] ??
                              _t('Unknown Vaccine', 'Hindi Kilalang Bakuna'),
                          value: formatDate(imm['vaccination_date']),
                          trailingWidget: StatusIndicator(
                            status: StatusIndicatorType.onTime,
                          ),
                          onTap: () {
                            widget.onViewVaccines();
                          },
                        );
                      }).toList(),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow(String height, String weight) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.height,
            label: _t('Height', 'Taas'),
            value: height,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.monitor_weight,
            label: _t('Weight', 'Timbang'),
            value: weight,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.vaccines,
            label: _t('Vaccines', 'Bakuna'),
            value: '${immunizations.length}',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  double? _getLatestBMI() {
    if (latestGrowth == null) return null;
    final heightCm = (latestGrowth!['child_height'] as num?)?.toDouble() ?? 0;
    final weightKg = (latestGrowth!['child_weight'] as num?)?.toDouble() ?? 0;
    if (heightCm <= 0 || weightKg <= 0) return null;
    final heightM = heightCm / 100;
    if (heightM <= 0) return null;
    return weightKg / (heightM * heightM);
  }

  String _bmiStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiStatusColor(String status) {
    switch (status) {
      case 'Underweight':
        return AppColors.warning;
      case 'Normal':
        return AppColors.success;
      case 'Overweight':
        return AppColors.warning;
      case 'Obese':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildBMICard(double? bmi, String? status) {
    final isAvailable = bmi != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_weight,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Body Mass Index', 'Body Mass Index'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable ? bmi.toStringAsFixed(1) : 'No data',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAvailable ? 'kg/m²' : 'Height or weight missing',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // Classification label removed to avoid redundancy. Only badge chip remains.
                  ],
                ),
              ),
              if (isAvailable && status != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _bmiStatusColor(status).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _bmiStatusColor(status),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'This BMI value is calculated using the latest recorded height and weight.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAiCard() {
    return AiAnalyticsCard(
      isLoading: aiLoading,
      text: aiAnalysis ??
          aiError ??
          'AI growth insight will appear here once the latest height and weight records are available.',
    );
  }

  Future<void> _loadProfileAiInsight(int latestRecordId) async {
    if (!mounted) return;
    setState(() {
      aiLoading = true;
      aiError = null;
    });

    try {
      final saved = await Supabase.instance.client
          .from('ai_responses')
          .select('response')
          .eq('reference_table', 'child_details')
          .eq('reference_id', latestRecordId)
          .eq('response_type', 'growth_analysis')
          .maybeSingle();

      if (saved != null &&
          saved['response'] != null &&
          saved['response'].toString().trim().isNotEmpty) {
        aiAnalysis = saved['response'].toString().trim();
      } else {
        await _generateAndSaveProfileAiInsight(latestRecordId);
      }
    } catch (e) {
      aiError = 'Unable to load AI insight.';
      aiAnalysis = null;
    } finally {
      if (mounted) {
        setState(() => aiLoading = false);
      }
    }
  }

  Future<void> _generateAndSaveProfileAiInsight(int latestRecordId) async {
    if (growthRecords.isEmpty || childData == null || latestGrowth == null) {
      aiAnalysis = 'Not enough data for AI insight.';
      return;
    }

    try {
      final latestHeight =
          (latestGrowth!['child_height'] as num?)?.toDouble() ?? 0;
      final latestWeight =
          (latestGrowth!['child_weight'] as num?)?.toDouble() ?? 0;
      final latestBMI = _calculateBMI(latestHeight, latestWeight);
      final latestAgeWeeks =
          _ageInWeeks(DateTime.parse(latestGrowth!['created_at']));
      final sex = (childData!['sex'] as String?) ?? 'female';

      final prompt = _buildGrowthAiPrompt(
        childName: getChildName(),
        sex: sex,
        ageWeeks: latestAgeWeeks,
        height: latestHeight,
        weight: latestWeight,
        bmi: latestBMI,
        heightZ: GrowthCalculator.calculateHeightZScore(
            latestHeight, latestAgeWeeks, sex),
        weightZ: GrowthCalculator.calculateWeightZScore(
            latestWeight, latestAgeWeeks, sex),
        bmiZ:
            GrowthCalculator.calculateBMIZScore(latestBMI, latestAgeWeeks, sex),
      );

      final generated = await GroqService().generateTextInsight(
        prompt: prompt,
        temperature: 0.2,
        maxOutputTokens: 512,
      );

      aiAnalysis = generated.trim();
      await _saveProfileAiResponse(aiAnalysis!, latestRecordId);
    } catch (e) {
      aiError = 'AI insight could not be generated right now.';
      aiAnalysis = null;
    }
  }

  Future<void> _saveProfileAiResponse(
      String responseText, int latestRecordId) async {
    try {
      final existing = await Supabase.instance.client
          .from('ai_responses')
          .select('ai_response_id')
          .eq('reference_table', 'child_details')
          .eq('reference_id', latestRecordId)
          .eq('response_type', 'growth_analysis')
          .maybeSingle();

      final values = {
        'reference_table': 'child_details',
        'reference_id': latestRecordId,
        'response_type': 'growth_analysis',
        'response_category': 'growth',
        'generated_by_ai': true,
        'ai_model': 'groq',
        'status': 'generated',
        'response': responseText,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['ai_response_id'] != null) {
        await Supabase.instance.client
            .from('ai_responses')
            .update(values)
            .eq('ai_response_id', existing['ai_response_id']);
      } else {
        values['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('ai_responses').insert(values);
      }
    } catch (e) {
      debugPrint('Error saving profile AI response: $e');
    }
  }

  String _buildGrowthAiPrompt({
    required String childName,
    required String sex,
    required int ageWeeks,
    required double height,
    required double weight,
    required double bmi,
    required double? heightZ,
    required double? weightZ,
    required double? bmiZ,
  }) {
    final recordsSummary = growthRecords.map((record) {
      final heightVal = (record['child_height'] as num?)?.toDouble() ?? 0;
      final weightVal = (record['child_weight'] as num?)?.toDouble() ?? 0;
      final bmiVal = _calculateBMI(heightVal, weightVal);
      final weeks = _ageInWeeks(DateTime.parse(record['created_at']));
      return '- Week $weeks: ${heightVal.toStringAsFixed(1)} cm, ${weightVal.toStringAsFixed(1)} kg, BMI ${bmiVal.toStringAsFixed(1)}';
    }).join('\n');

    return '''
You are a warm, caring assistant writing a short growth update for a parent and midwife.
Do not use the phrase "your baby". Use "the child" or "the baby" instead.
Provide the response in both English and Filipino. Only one language will be shown at a time.
Use the exact output format below with markdown headings and bullet points only. Do not add extra sections or tables.

Child: $childName
Sex: ${sex.toLowerCase()}
Current age: $ageWeeks weeks

Latest measurements:
Height: ${height.toStringAsFixed(1)} cm
Weight: ${weight.toStringAsFixed(1)} kg

Recent growth:
$recordsSummary

Output format:

## English
## Baby Growth Summary
- A short, gentle explanation of how the child is growing.

### Current Measurements
- Length: ${height.toStringAsFixed(1)} cm
- Weight: ${weight.toStringAsFixed(1)} kg

### What This Means
- ...
- ...

### Helpful Note
- ...

## Filipino
## Buod ng Paglaki ng Bata
- Maikling, banayad na paliwanag kung paano lumalago ang bata.

### Kasalukuyang Sukat
- Haba: ${height.toStringAsFixed(1)} cm
- Timbang: ${weight.toStringAsFixed(1)} kg

### Ano ang Kahulugan Nito
- ...
- ...

### Paalala
- ...

Use calm, supportive wording. Keep it simple and easy to understand. Do not use technical terms such as z-scores, percentiles, or clinical indicators. Avoid alarm and focus on what the measurements mean for everyday care and follow-up.
''';
  }

  Widget _buildGuardianCard(String parentName, String parentRelationship) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasGuardian
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.brandPrimary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasGuardian
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasGuardian ? Icons.person_outline : Icons.pregnant_woman,
                  color:
                      hasGuardian ? AppColors.success : AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasGuardian
                        ? _t('Guardian', 'Tagapag-alaga')
                        : _t('Mother', 'Ina'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasGuardian
                          ? AppColors.success
                          : AppColors.brandPrimary,
                    ),
                  ),
                  Text(
                    parentRelationship,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parentName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (hasGuardian) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  getGuardianPhone(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (getGuardianAddress() !=
                _t('Not recorded', 'Hindi naitala')) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      getGuardianAddress(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required VoidCallback onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            _t('View All', 'Tingnan Lahat'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.borderPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCards(String height, String weight) {
    return Row(
      children: [
        Expanded(
          child: _buildGrowthDetailCard(
            icon: Icons.height,
            title: _t('Height', 'Taas'),
            value: height,
            color: AppColors.brandPrimary,
            onTap: () {
              widget.onViewGrowth();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGrowthDetailCard(
            icon: Icons.monitor_weight,
            title: _t('Weight', 'Timbang'),
            value: weight,
            color: AppColors.success,
            onTap: () {
              widget.onViewGrowth();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
