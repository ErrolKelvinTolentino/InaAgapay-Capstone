import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/hero_card.dart';
import '../widgets/records_display_card.dart';
import '../widgets/status_indicator.dart';
import '../widgets/important_button.dart';

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
  Map<String, dynamic>? response;
  Map<String, dynamic>? latestGrowthRecord;

  String v(Map<String, dynamic> map, String key) =>
      (map[key] ?? '').toString().trim();

  Future<void> fetchProfile() async {
    setState(() => loading = true);
    
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Fetch child profile
      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_profile.php?child_id=${widget.childId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final decoded = jsonDecode(res.body);
      
      // Also fetch growth records to get the actual latest one
      final growthRes = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_growth_list.php?child_id=${widget.childId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final growthDecoded = jsonDecode(growthRes.body);
      List allGrowthRecords = growthDecoded['records'] ?? [];
      
      // Find latest record by child_details_id (highest ID = latest)
      if (allGrowthRecords.isNotEmpty) {
        allGrowthRecords.sort((a, b) {
          final idA = int.tryParse(a['child_details_id'].toString()) ?? 0;
          final idB = int.tryParse(b['child_details_id'].toString()) ?? 0;
          return idB.compareTo(idA); // Descending - highest first
        });
        latestGrowthRecord = allGrowthRecords.first;
      }

      setState(() {
        response = decoded;
        loading = false;
      });
    } catch (e) {
      setState(() {
        response = {'success': false, 'message': e.toString()};
        loading = false;
      });
    }
  }

  String calculateAge(String? birthdate) {
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
        return '$months months old';
      } else {
        return '$years years ${months > 0 ? '$months months' : ''} old'.trim();
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

  StatusIndicatorType _getBMIIndicator(double? bmi) {
    if (bmi == null) return StatusIndicatorType.onTime;
    
    // Simple BMI categories for children (simplified)
    if (bmi < 16) return StatusIndicatorType.overdue;
    if (bmi >= 16 && bmi <= 24) return StatusIndicatorType.onTime;
    if (bmi > 24 && bmi <= 30) return StatusIndicatorType.overdue;
    return StatusIndicatorType.overdue;
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

    if (response == null || response!['success'] != true) {
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
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load child profile',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic> child =
        response!['child'] is Map ? response!['child'] : {};

    final Map<String, dynamic> birth =
        response!['birth'] is Map ? response!['birth'] : {};

    final Map<String, dynamic> growth =
        response!['growth'] is Map ? response!['growth'] : {};

    final Map<String, dynamic> immunization =
        response!['immunization'] is Map ? response!['immunization'] : {};

    final String fullName = '${v(child, 'first_name')} ${v(child, 'last_name')}';
    final String age = calculateAge(v(birth, 'birthdate'));
    final String sex = v(child, 'sex').toUpperCase();
    final String birthPlace = '${v(birth, 'birthplace_city_municipality')}, ${v(birth, 'birthplace_province')}';

    // Use latestGrowthRecord if available, otherwise fall back to API growth data
    final String displayHeight = latestGrowthRecord != null 
        ? '${(double.tryParse(latestGrowthRecord!['child_height'].toString()) ?? 0).toStringAsFixed(1)} cm'
        : v(growth, 'child_height').isNotEmpty
            ? '${v(growth, 'child_height')} cm'
            : 'Not recorded';
            
    final String displayWeight = latestGrowthRecord != null
        ? '${(double.tryParse(latestGrowthRecord!['child_weight'].toString()) ?? 0).toStringAsFixed(1)} kg'
        : v(growth, 'child_weight').isNotEmpty
            ? '${v(growth, 'child_weight')} kg'
            : 'Not recorded';
            
    final String displayBMI = latestGrowthRecord != null
        ? '${(double.tryParse(latestGrowthRecord!['bmi'].toString()) ?? 0).toStringAsFixed(1)} kg/m²'
        : v(growth, 'bmi').isNotEmpty
            ? '${v(growth, 'bmi')} kg/m²'
            : 'Not recorded';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      /// 🔝 Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Child Information',
          onBack: () => Navigator.pop(context),
        ),
      ),

      /// 🔽 Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              /// 👶 Child Hero
              HeroCard(
                image: const AssetImage('assets/images/baby.png'),
                title: fullName.isNotEmpty ? fullName : 'Unnamed Child',
                subtitle: '$age • $sex',
                showWeekBadge: false,
                showHeartRow: false,
              ),

              const SizedBox(height: 24),

              /// 🎂 Birth Details
              RecordsDisplayCard(
                title: 'Birth Details',
                headerIcon: Icons.cake_outlined,
                items: [
                  RecordItem(
                    leadingIcon: Icons.calendar_month_rounded,
                    label: 'Birth Date',
                    value: formatDate(v(birth, 'birthdate')),
                  ),
                  RecordItem(
                    leadingIcon: Icons.place_outlined,
                    label: 'Birthplace',
                    value: birthPlace,
                  ),
                  RecordItem(
                    leadingIcon: Icons.straighten_outlined,
                    label: 'Birth Length',
                    value: v(birth, 'birth_length').isNotEmpty 
                        ? '${v(birth, 'birth_length')} cm'
                        : 'Not recorded',
                  ),
                  RecordItem(
                    leadingIcon: Icons.circle_outlined,
                    label: 'Head Circumference',
                    value: v(birth, 'head_circumference').isNotEmpty
                        ? '${v(birth, 'head_circumference')} cm'
                        : 'Not recorded',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// 📈 Latest Growth Records
              RecordsDisplayCard(
                title: 'Latest Growth Records',
                headerIcon: Icons.bar_chart_rounded,
                items: [
                  RecordItem(
                    leadingIcon: Icons.height,
                    label: 'Height',
                    value: displayHeight,
                    trailingWidget: displayHeight != 'Not recorded'
                        ? const Icon(
                            Icons.trending_up,
                            size: 14,
                            color: AppColors.success,
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildGrowthListPage(
                            childId: widget.childId,
                          ),
                        ),
                      );
                    },
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight,
                    label: 'Weight',
                    value: displayWeight,
                    trailingWidget: displayWeight != 'Not recorded'
                        ? const Icon(
                            Icons.trending_up,
                            size: 14,
                            color: AppColors.success,
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildGrowthListPage(
                            childId: widget.childId,
                          ),
                        ),
                      );
                    },
                  ),
                  RecordItem(
                    leadingIcon: Icons.calculate,
                    label: 'BMI',
                    value: displayBMI,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// 📊 View Growth Statistics Button
              ImportantButton(
                label: 'View Growth Statistics',
                leadingIcon: Icons.bar_chart_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildGrowthListPage(
                        childId: widget.childId,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              /// 💉 Latest Immunization
              RecordsDisplayCard(
                title: 'Latest Immunization',
                headerIcon: Icons.vaccines_outlined,
                items: immunization.isNotEmpty
                    ? [
                        RecordItem(
                          leadingIcon: Icons.vaccines,
                          label: 'Vaccine',
                          value: v(immunization, 'vaccine_name'),
                        ),
                        RecordItem(
                          leadingIcon: Icons.format_list_numbered,
                          label: 'Dose',
                          value: v(immunization, 'dose_number').isNotEmpty
                              ? 'Dose ${v(immunization, 'dose_number')}'
                              : 'Not specified',
                        ),
                        RecordItem(
                          leadingIcon: Icons.calendar_month_rounded,
                          label: 'Date Given',
                          value: formatDate(v(immunization, 'vaccination_date')),
                          trailingWidget: StatusIndicator(
                            status: StatusIndicatorType.onTime,
                          ),
                        ),
                      ]
                    : [
                        RecordItem(
                          leadingIcon: Icons.info_outline,
                          label: 'Status',
                          value: 'No immunization recorded yet',
                        ),
                      ],
              ),

              const SizedBox(height: 20),

              /// 💉 View Vaccination Details Button
              ImportantButton(
                label: 'View Vaccination Details',
                leadingIcon: Icons.vaccines_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildImmunizationListPage(
                        childId: widget.childId,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              /// ➕ Add Growth Record Button
              ImportantButton(
                label: 'Add Growth Record',
                leadingIcon: Icons.add_chart,
                onPressed: () async {
                  // Wait for the result from AddGrowthStep1
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddGrowthStep1(childId: widget.childId),
                    ),
                  );

                  // If result is true, refresh the profile data
                  if (result == true && mounted) {
                    await fetchProfile();
                  }
                },
              ),

              const SizedBox(height: 20),

              /// 💉 Add Immunization Button
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

                  // Refresh profile when immunization is added
                  if (result == true && mounted) {
                    await fetchProfile();
                  }
                },
              ),

              const SizedBox(height: 20),

              /// 🤖 AI Growth Analysis Button
              ImportantButton(
                label: 'AI Growth Analysis',
                leadingIcon: Icons.psychology_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildGrowthAIPage(
                        childId: widget.childId,
                      ),
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