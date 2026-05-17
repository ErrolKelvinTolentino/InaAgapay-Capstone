import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';
import 'add_growth_step1.dart';
import 'add_immunization_page.dart';
import 'child_growth_list_page.dart';
import 'child_immunization_list_page.dart';
import 'child_growth_ai_page.dart';

class ChildProfilePage extends StatefulWidget {
  final int childId;

  const ChildProfilePage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> {
  bool loading = true;
  Map<String, dynamic>? childData;
  Map<String, dynamic>? birthData;
  Map<String, dynamic>? latestGrowth;
  List<Map<String, dynamic>> immunizations = [];
  Map<String, dynamic>? guardianData;
  bool hasGuardian = false;

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
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      latestGrowth = growthResponse;

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

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Not recorded';
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

    return 'Unknown';
  }

  String getParentRelationship() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['relationship']?.toString() ?? 'Guardian';
    }
    return 'Mother';
  }

  String getGuardianPhone() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['phone_number']?.toString() ?? 'Not recorded';
    }
    return 'Not recorded';
  }

  String getGuardianAddress() {
    if (hasGuardian && guardianData != null) {
      return guardianData!['address']?.toString() ?? 'Not recorded';
    }
    return 'Not recorded';
  }

  String getBirthPlace() {
    final city = birthData?['birthplace_city_municipality']?.toString() ?? '';
    final province = birthData?['birthplace_province']?.toString() ?? '';
    final facility = birthData?['birthplace_facility']?.toString() ?? '';

    final parts = [facility, city, province].where((p) => p.isNotEmpty);
    return parts.isNotEmpty ? parts.join(', ') : 'Not recorded';
  }

  void _showAddOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Add Record',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the type of record to add',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Options
            Row(
              children: [
                Expanded(
                  child: _buildAddOptionCard(
                    icon: Icons.trending_up,
                    title: 'Growth',
                    subtitle: 'Height & Weight',
                    color: AppColors.brandPrimary,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAddGrowth();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAddOptionCard(
                    icon: Icons.vaccines,
                    title: 'Immunization',
                    subtitle: 'Vaccine Record',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAddImmunization();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAddGrowth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddGrowthStep1(childId: widget.childId),
      ),
    );
    if (result == true && mounted) {
      fetchProfile();
    }
  }

  Future<void> _navigateToAddImmunization() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddImmunizationPage(childId: widget.childId),
      ),
    );
    if (result == true && mounted) {
      fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            title: 'Child Information',
            onBack: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load child profile',
                style: TextStyle(color: Colors.red, fontSize: 16),
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
        : 'Not recorded';

    final displayWeight = latestGrowth != null
        ? '${(latestGrowth!['child_weight'] as num?)?.toStringAsFixed(1) ?? '0'} kg'
        : 'Not recorded';

    final latestBMI = _getLatestBMI();
    final bmiStatus = latestBMI != null ? _bmiStatus(latestBMI) : null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Child Information',
          onBack: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptionsModal,
        backgroundColor: AppColors.brandPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
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
                title: 'Birth Details',
                headerIcon: Icons.cake_outlined,
                items: [
                  RecordItem(
                    leadingIcon: Icons.calendar_month_rounded,
                    label: 'Birth Date',
                    value: formatDate(birthData?['birthdate']),
                  ),
                  RecordItem(
                    leadingIcon: Icons.place_outlined,
                    label: 'Birthplace',
                    value: birthPlace,
                  ),
                  RecordItem(
                    leadingIcon: Icons.straighten_outlined,
                    label: 'Birth Length',
                    value: birthData?['birth_length'] != null
                        ? '${birthData!['birth_length']} cm'
                        : 'Not recorded',
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight_outlined,
                    label: 'Birth Weight',
                    value: birthData?['birth_weight'] != null
                        ? '${birthData!['birth_weight']} kg'
                        : 'Not recorded',
                  ),
                  RecordItem(
                    leadingIcon: Icons.circle_outlined,
                    label: 'Head Circumference',
                    value: birthData?['head_circumference'] != null
                        ? '${birthData!['head_circumference']} cm'
                        : 'Not recorded',
                  ),
                ],
              ),

              _buildSectionDivider(),

              // ── Growth & Development ──────────────────────────
              _buildSectionHeader(
                title: 'Growth & Development',
                icon: Icons.trending_up,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChildGrowthListPage(childId: widget.childId),
                    ),
                  ).then((_) => fetchProfile());
                },
              ),
              const SizedBox(height: 12),

              _buildGrowthCards(displayHeight, displayWeight),
              const SizedBox(height: 12),
              _buildBMICard(latestBMI, bmiStatus),
              const SizedBox(height: 16),
              _buildAICard(),

              _buildSectionDivider(),

              // ── Immunization ───────────────────────────────────
              _buildSectionHeader(
                title: 'Immunization',
                icon: Icons.vaccines_outlined,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChildImmunizationListPage(childId: widget.childId),
                    ),
                  ).then((_) => fetchProfile());
                },
              ),
              const SizedBox(height: 12),

              RecordsDisplayCard(
                title: 'Recent Immunizations',
                headerIcon: Icons.vaccines_outlined,
                items: immunizations.isEmpty
                    ? [
                        RecordItem(
                          leadingIcon: Icons.info_outline,
                          label: 'Status',
                          value: 'No immunization records yet',
                        ),
                      ]
                    : immunizations.map((imm) {
                        final vaccine = imm['vaccine'] as Map<String, dynamic>?;
                        return RecordItem(
                          leadingIcon: Icons.vaccines,
                          label: vaccine?['vaccine_name'] ?? 'Unknown Vaccine',
                          value: formatDate(imm['vaccination_date']),
                          trailingWidget: StatusIndicator(
                            status: StatusIndicatorType.onTime,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildImmunizationListPage(
                                    childId: widget.childId),
                              ),
                            ).then((_) => fetchProfile());
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
            label: 'Height',
            value: height,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.monitor_weight,
            label: 'Weight',
            value: weight,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.vaccines,
            label: 'Vaccines',
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
              const Expanded(
                child: Text(
                  'Body Mass Index',
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
                    hasGuardian ? 'Guardian' : 'Mother',
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
            if (getGuardianAddress() != 'Not recorded') ...[
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
          child: const Text(
            'View All',
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
            title: 'Height',
            value: height,
            color: AppColors.brandPrimary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildGrowthListPage(childId: widget.childId),
                ),
              ).then((_) => fetchProfile());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGrowthDetailCard(
            icon: Icons.monitor_weight,
            title: 'Weight',
            value: weight,
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildGrowthListPage(childId: widget.childId),
                ),
              ).then((_) => fetchProfile());
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

  Widget _buildAICard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary.withValues(alpha: 0.05),
            AppColors.brandPrimary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: AppColors.brandPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Growth Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get personalized insights and predictions',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthAIPage(childId: widget.childId),
                  ),
                ).then((_) => fetchProfile());
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Analyze Growth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
