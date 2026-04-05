// lib/screens/mother/mother_child_vaccine.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/small_description.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';

class MotherChildVaccinePage extends StatefulWidget {
  final VoidCallback onBack;
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildVaccinePage({
    super.key,
    required this.onBack,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildVaccinePage> createState() => _MotherChildVaccinePageState();
}

class _MotherChildVaccinePageState extends State<MotherChildVaccinePage> {
  List<ImmunizationRecord> _immunizations = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVaccines();
  }

  Future<void> _fetchVaccines() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final immunizations = await ChildService.fetchImmunizations(widget.childId);
      setState(() {
        _immunizations = immunizations;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatRecommendedAge(double months) {
    if (months == 0) return 'At birth';
    if (months < 1) {
      final weeks = (months * 4).round();
      return '$weeks week${weeks != 1 ? 's' : ''}';
    }
    if (months == 1) return '1 month';
    if (months < 12) return '${months.toInt()} months';
    final years = (months / 12).floor();
    return '$years year${years != 1 ? 's' : ''}';
  }

  StatusIndicatorType _getStatusIcon(ImmunizationRecord record) {
    // All records in the list are already given (since they're from immunization_record table)
    return StatusIndicatorType.onTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SecondaryHeader(
          title: 'Vaccination Details',
          onBack: widget.onBack,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchVaccines,
        color: AppColors.brandPrimary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchVaccines,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeroCard(
                          image: null,
                          title: widget.childName,
                          subtitle: widget.childAge,
                          showWeekBadge: false,
                          showHeartRow: false,
                        ),
                        const SizedBox(height: 16),
                        const SmallDescription(
                          text: 'Vaccines administered based on immunization schedule',
                        ),
                        const SizedBox(height: 16),
                        if (_immunizations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.vaccines_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No immunizations recorded yet',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._immunizations.map((v) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecordsDisplayCard(
                                title: '${v.vaccineName} (Dose ${v.doseNumber})',
                                headerIcon: Icons.vaccines_outlined,
                                items: [
                                  RecordItem(
                                    leadingIcon: Icons.schedule,
                                    label: 'Recommended',
                                    value: _formatRecommendedAge(v.recommendedAgeMonths),
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.calendar_month_rounded,
                                    label: 'Date Given',
                                    value: _formatDate(v.vaccinationDate),
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.verified,
                                    label: 'Status',
                                    value: 'COMPLETED',
                                    trailingWidget: StatusIndicator(
                                      status: _getStatusIcon(v),
                                    ),
                                  ),
                                  if (v.remarks != null && v.remarks!.isNotEmpty)
                                    RecordItem(
                                      leadingIcon: Icons.notes_outlined,
                                      label: 'Remarks',
                                      value: v.remarks!,
                                    ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}