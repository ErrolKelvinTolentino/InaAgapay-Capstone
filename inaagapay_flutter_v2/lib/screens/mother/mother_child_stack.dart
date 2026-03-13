// lib/screens/mother/mother_child_stack.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_bottom_navigation.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/important_button.dart';
import '../../widgets/status_indicator.dart';
import 'mother_child_growth_page.dart';
import 'mother_child_vaccine_page.dart';

class MotherChildStack extends StatefulWidget {
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildStack({
    super.key,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildStack> createState() => _MotherChildStackState();
}

class _MotherChildStackState extends State<MotherChildStack> {
  Map<String, dynamic>? _childData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ensure session is active
      await SupabaseService.ensureSession();

      // Get child with birth details and latest growth record
      final response = await SupabaseService.client
          .from('children')
          .select('''
            *,
            birth_details (*),
            child_details (
              child_height,
              child_weight,
              created_at
            )
          ''')
          .eq('child_id', widget.childId)
          .single();

      // Get latest vaccine record
      final vaccineResponse = await SupabaseService.client
          .from('immunization_record')
          .select('''
            *,
            vaccine: vaccine_id (*)
          ''')
          .eq('child_id', widget.childId)
          .order('vaccination_date', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        _childData = {
          ...response,
          'latest_vaccine': vaccineResponse,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '--';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _getBirthplace() {
    final birthDetails = _childData?['birth_details'] as Map<String, dynamic>?;
    if (birthDetails == null) return '--';
    
    final parts = [
      birthDetails['birthplace_city_municipality'],
      birthDetails['birthplace_province'],
    ].where((e) => e != null && e.toString().isNotEmpty).toList();
    
    return parts.isNotEmpty ? parts.join(', ') : '--';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SecondaryHeader(
            title: 'Child Information',
            onBack: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_error != null) {
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error Loading Child Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadChildData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final birthDetails = _childData?['birth_details'] as Map<String, dynamic>?;
    final childDetails = _childData?['child_details'] as List?;
    final latestGrowth = childDetails != null && childDetails.isNotEmpty
        ? childDetails.first as Map<String, dynamic>
        : null;
    final latestVaccine = _childData?['latest_vaccine'] as Map<String, dynamic>?;

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
              HeroCard(
                image: const AssetImage('assets/images/baby.png'),
                title: widget.childName,
                subtitle: widget.childAge,
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
                    value: _formatDate(birthDetails?['birthdate']),
                  ),
                  RecordItem(
                    leadingIcon: Icons.location_on_outlined,
                    label: 'Birthplace',
                    value: _getBirthplace(),
                  ),
                  if (birthDetails?['birth_weight'] != null)
                    RecordItem(
                      leadingIcon: Icons.monitor_weight,
                      label: 'Birth Weight',
                      value: '${birthDetails!['birth_weight']} kg',
                    ),
                  if (birthDetails?['birth_length'] != null)
                    RecordItem(
                      leadingIcon: Icons.height,
                      label: 'Birth Length',
                      value: '${birthDetails!['birth_length']} cm',
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
                    value: latestGrowth != null
                        ? '${latestGrowth['child_height']} cm'
                        : '-- cm',
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight,
                    label: 'Weight',
                    value: latestGrowth != null
                        ? '${latestGrowth['child_weight']} kg'
                        : '-- kg',
                  ),
                  if (latestGrowth != null)
                    RecordItem(
                      leadingIcon: Icons.update,
                      label: 'Last Updated',
                      value: _formatDate(latestGrowth['created_at']),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // View Growth Button
              ImportantButton(
                label: 'View Growth Statistics',
                leadingIcon: Icons.bar_chart_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MotherChildGrowthPage(
                        childId: widget.childId,
                        childName: widget.childName,
                        childAge: widget.childAge,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Latest Immunization Card
              RecordsDisplayCard(
                title: 'Latest Immunization',
                headerIcon: Icons.vaccines_outlined,
                items: [
                  RecordItem(
                    leadingIcon: Icons.vaccines,
                    label: 'Vaccine',
                    value: latestVaccine?['vaccine']?['vaccine_name'] ?? '--',
                  ),
                  RecordItem(
                    leadingIcon: Icons.calendar_month_rounded,
                    label: 'Date Taken',
                    value: _formatDate(latestVaccine?['vaccination_date']),
                    trailingWidget: latestVaccine != null
                        ? const StatusIndicator(
                            status: StatusIndicatorType.onTime,
                          )
                        : null,
                  ),
                ],
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
                      builder: (_) => MotherChildVaccinePage(
                        childId: widget.childId,
                        childName: widget.childName,
                        childAge: widget.childAge,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      // Remove the bottomNavigationBar since it's handled by the parent shell
    );
  }
}