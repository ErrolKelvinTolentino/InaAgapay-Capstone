import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';
import '../../widgets/main_button.dart';
import '../../widgets/important_button.dart';
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
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
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
          ''')
          .eq('child_id', widget.childId)
          .single();

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

      setState(() => loading = false);
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
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
        return '$years year${years != 1 ? 's' : ''} ${months > 0 ? '$months month${months != 1 ? 's' : ''}' : ''} old'.trim();
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
      final relationship = guardianData!['relationship']?.toString() ?? 'Guardian';
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
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final fullName = '${childData!['first_name']} ${childData!['last_name']}'.trim();
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

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Child Information',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Child Hero Card
              HeroCard(
                image: null,
                title: fullName.isNotEmpty ? fullName : 'Unnamed Child',
                subtitle: '$age • $sex',
                showWeekBadge: false,
                showHeartRow: false,
              ),

              const SizedBox(height: 24),

              // Parent/Guardian Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasGuardian 
                      ? AppColors.success.withValues(alpha: 0.08)
                      : AppColors.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasGuardian
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.brandPrimary.withValues(alpha: 0.3),
                  ),
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
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.brandPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            hasGuardian ? Icons.person_outline : Icons.pregnant_woman,
                            color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          hasGuardian ? 'Guardian Information' : 'Mother Information',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Name Row
                    _buildParentInfoCard(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: parentName,
                      color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Relationship Row
                    _buildParentInfoCard(
                      icon: Icons.family_restroom,
                      label: 'Relationship',
                      value: parentRelationship,
                      color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                    ),
                    
                    if (hasGuardian) ...[
                      const SizedBox(height: 12),
                      
                      // Phone Row
                      _buildParentInfoCard(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: getGuardianPhone(),
                        color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                      ),
                      
                      if (getGuardianAddress() != 'Not recorded') ...[
                        const SizedBox(height: 12),
                        
                        // Address Row
                        _buildParentInfoCard(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: getGuardianAddress(),
                          color: hasGuardian ? AppColors.success : AppColors.brandPrimary,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Birth Details Card
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
                    leadingIcon: Icons.circle_outlined,
                    label: 'Head Circumference',
                    value: birthData?['head_circumference'] != null
                        ? '${birthData!['head_circumference']} cm'
                        : 'Not recorded',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Latest Growth Records Card
              RecordsDisplayCard(
                title: 'Latest Growth Records',
                headerIcon: Icons.bar_chart_rounded,
                items: [
                  RecordItem(
                    leadingIcon: Icons.height,
                    label: 'Height',
                    value: displayHeight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildGrowthListPage(childId: widget.childId),
                        ),
                      ).then((_) => fetchProfile());
                    },
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight,
                    label: 'Weight',
                    value: displayWeight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildGrowthListPage(childId: widget.childId),
                        ),
                      ).then((_) => fetchProfile());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // View Growth Statistics Button
              ImportantButton(
                label: 'View Growth Statistics',
                leadingIcon: Icons.bar_chart_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildGrowthListPage(childId: widget.childId),
                    ),
                  ).then((_) => fetchProfile());
                },
              ),

              const SizedBox(height: 20),

              // Add Growth Record Button
              MainButton(
                label: 'Add Growth Record',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddGrowthStep1(childId: widget.childId),
                    ),
                  );
                  if (result == true && mounted) {
                    fetchProfile();
                  }
                },
                leftIcon: Icons.add_chart,
              ),

              const SizedBox(height: 20),

              // Latest Immunization Card
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
                                builder: (_) => ChildImmunizationListPage(childId: widget.childId),
                              ),
                            ).then((_) => fetchProfile());
                          },
                        );
                      }).toList(),
              ),

              const SizedBox(height: 20),

              // View Vaccination Details Button
              ImportantButton(
                label: 'View Vaccination Details',
                leadingIcon: Icons.vaccines_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildImmunizationListPage(childId: widget.childId),
                    ),
                  ).then((_) => fetchProfile());
                },
              ),

              const SizedBox(height: 20),

              // Add Immunization Button
              ImportantButton(
                label: 'Add Immunization',
                leadingIcon: Icons.vaccines_outlined,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddImmunizationPage(childId: widget.childId),
                    ),
                  );
                  if (result == true && mounted) {
                    fetchProfile();
                  }
                },
              ),

              const SizedBox(height: 20),

              // AI Growth Analysis Button
              ImportantButton(
                label: 'AI Growth Analysis',
                leadingIcon: Icons.psychology_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildGrowthAIPage(childId: widget.childId),
                    ),
                  ).then((_) => fetchProfile());
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}