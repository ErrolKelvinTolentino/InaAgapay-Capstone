// lib/screens/midwife/child_profile_page.dart

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

  Future<void> fetchProfile() async {
    setState(() => loading = true);

    try {
      // Fetch child details with mother info
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
            )
          ''')
          .eq('child_id', widget.childId)
          .single();

      childData = childResponse;

      // Fetch birth details
      final birthResponse = await Supabase.instance.client
          .from('birth_details')
          .select('*')
          .eq('child_id', widget.childId)
          .maybeSingle();

      birthData = birthResponse;

      // Fetch latest growth record
      final growthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      latestGrowth = growthResponse;

      // Fetch recent immunizations (last 5)
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

  String getMotherName() {
    final mother = childData?['mother'] as Map<String, dynamic>?;
    if (mother == null) return 'Unknown';
    final account = mother['account'] as Map<String, dynamic>?;
    if (account == null) return 'Unknown';
    final firstName = account['first_name']?.toString() ?? '';
    final lastName = account['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim();
  }

  String getBirthPlace() {
    final city = birthData?['birthplace_city_municipality']?.toString() ?? '';
    final province = birthData?['birthplace_province']?.toString() ?? '';
    
    if (city.isNotEmpty && province.isNotEmpty) {
      return '$city, $province';
    } else if (city.isNotEmpty) {
      return city;
    } else if (province.isNotEmpty) {
      return province;
    }
    return 'Not recorded';
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
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
                  RecordItem(
                    leadingIcon: Icons.person_outline,
                    label: 'Mother',
                    value: getMotherName(),
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
                      );
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
                      );
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
                  );
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
                            );
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
                  );
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
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}