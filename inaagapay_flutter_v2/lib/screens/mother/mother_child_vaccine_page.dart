// lib/screens/mother/mother_child_vaccine_page.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/small_description.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';

class MotherChildVaccinePage extends StatefulWidget {
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildVaccinePage({
    super.key,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildVaccinePage> createState() => _MotherChildVaccinePageState();
}

class _MotherChildVaccinePageState extends State<MotherChildVaccinePage> {
  List<Map<String, dynamic>> _vaccines = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVaccines();
  }

  Future<void> _loadVaccines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SupabaseService.ensureSession();

      // Get all vaccines with their immunization records for this child
      final response = await SupabaseService.client
          .from('vaccines')
          .select('''
            vaccine_id,
            vaccine_name,
            dose_number,
            recommended_age_months,
            target_recipients,
            immunization_record!left (
              immunization_record_id,
              vaccination_date,
              remarks,
              created_at
            )
          ''')
          .eq('target_recipients', 'child')
          .order('recommended_age_months', ascending: true);

      final vaccines = List<Map<String, dynamic>>.from(response);

      // For each vaccine, check if this child has taken it
      for (var vaccine in vaccines) {
        final records = vaccine['immunization_record'] as List? ?? [];
        final childRecord = records.firstWhere(
          (r) => r['child_id'] == widget.childId,
          orElse: () => null,
        );

        if (childRecord != null) {
          vaccine['status'] = 'done';
          vaccine['vaccination_date'] = childRecord['vaccination_date'];
        } else {
          vaccine['status'] = 'pending';
        }
      }

      setState(() {
        _vaccines = vaccines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  StatusIndicatorType _getStatusType(String status) {
    switch (status) {
      case 'done':
        return StatusIndicatorType.onTime;
      case 'pending':
        return StatusIndicatorType.ongoing;
      default:
        return StatusIndicatorType.ongoing;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SecondaryHeader(
          title: 'Vaccination Details',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          : _error != null
              ? Center(
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
                        Text(
                          'Error Loading Vaccines',
                          style: const TextStyle(
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
                          onPressed: _loadVaccines,
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
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeroCard(
                          image: const AssetImage('assets/images/baby.png'),
                          title: widget.childName,
                          subtitle: widget.childAge,
                          showWeekBadge: false,
                          showHeartRow: false,
                        ),
                        const SizedBox(height: 16),
                        const SmallDescription(
                          text: 'Vaccines based on official immunization schedule',
                        ),
                        const SizedBox(height: 16),
                        if (_vaccines.isEmpty)
                          const Center(
                            child: Text(
                              'No vaccines found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ..._vaccines.map((v) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecordsDisplayCard(
                                title: '${v['vaccine_name']} (Dose ${v['dose_number']})',
                                headerIcon: Icons.vaccines_outlined,
                                items: [
                                  RecordItem(
                                    leadingIcon: Icons.schedule,
                                    label: 'Recommended',
                                    value: '${v['recommended_age_months']} months',
                                  ),
                                  if (v['status'] == 'done')
                                    RecordItem(
                                      leadingIcon: Icons.calendar_today,
                                      label: 'Date Taken',
                                      value: _formatDate(v['vaccination_date']),
                                    ),
                                  RecordItem(
                                    leadingIcon: Icons.verified,
                                    label: 'Status',
                                    value: v['status'].toUpperCase(),
                                    trailingWidget: StatusIndicator(
                                      status: _getStatusType(v['status']),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}