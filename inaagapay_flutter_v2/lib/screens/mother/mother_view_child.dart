// lib/screens/mother/mother_view_child.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/records_display_card.dart';
import '../../widgets/status_indicator.dart';
import '../../widgets/important_button.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';

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
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchChildDetails();
  }

  Future<void> _fetchChildDetails() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await ChildService.fetchChildDetails(widget.childId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _getBirthplace(ChildModel child) {
    final parts = [
      child.birthplaceCity,
      child.birthplaceProvince,
    ].where((p) => p != null && p.isNotEmpty);
    return parts.isNotEmpty ? parts.join(', ') : '--';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Child Information',
          onBack: widget.onBackToChildren,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchChildDetails,
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
                          onPressed: _fetchChildDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        HeroCard(
                          image: null,
                          title: widget.childName,
                          subtitle: '${widget.childAge} • ${widget.childGender == 'female' ? 'Girl' : 'Boy'}',
                          showWeekBadge: false,
                          showHeartRow: false,
                        ),
                        const SizedBox(height: 24),

                        RecordsDisplayCard(
                          title: 'Birth Details',
                          headerIcon: Icons.cake_outlined,
                          items: [
                            RecordItem(
                              leadingIcon: Icons.calendar_month_rounded,
                              label: 'Birth Date',
                              value: _formatDate(_data?['child']?.birthdate),
                            ),
                            RecordItem(
                              leadingIcon: Icons.location_on_outlined,
                              label: 'Birthplace',
                              value: _getBirthplace(_data?['child']),
                            ),
                            if (_data?['child']?.birthWeight != null)
                              RecordItem(
                                leadingIcon: Icons.monitor_weight,
                                label: 'Birth Weight',
                                value: '${_data?['child']?.birthWeight} kg',
                              ),
                            if (_data?['child']?.birthLength != null)
                              RecordItem(
                                leadingIcon: Icons.height,
                                label: 'Birth Length',
                                value: '${_data?['child']?.birthLength} cm',
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        RecordsDisplayCard(
                          title: 'Latest Growth Records',
                          headerIcon: Icons.bar_chart_rounded,
                          items: [
                            RecordItem(
                              leadingIcon: Icons.height,
                              label: 'Height',
                              value: _data?['latest_growth'] != null
                                  ? '${(_data?['latest_growth'] as GrowthRecord).height.toStringAsFixed(1)} cm'
                                  : '-- cm',
                            ),
                            RecordItem(
                              leadingIcon: Icons.monitor_weight,
                              label: 'Weight',
                              value: _data?['latest_growth'] != null
                                  ? '${(_data?['latest_growth'] as GrowthRecord).weight.toStringAsFixed(1)} kg'
                                  : '-- kg',
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        ImportantButton(
                          label: 'View Growth Statistics',
                          leadingIcon: Icons.bar_chart_rounded,
                          onPressed: widget.onViewGrowth,
                        ),

                        const SizedBox(height: 20),

                        RecordsDisplayCard(
                          title: 'Latest Immunization',
                          headerIcon: Icons.vaccines_outlined,
                          items: (_data?['immunizations'] as List?)?.isNotEmpty == true
                              ? [
                                  RecordItem(
                                    leadingIcon: Icons.vaccines,
                                    label: 'Name',
                                    value: (_data?['immunizations'] as List).first.vaccineName,
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.calendar_month_rounded,
                                    label: 'Taken',
                                    value: DateFormat('MMM d, yyyy').format(
                                      (_data?['immunizations'] as List).first.vaccinationDate
                                    ),
                                    trailingWidget: const StatusIndicator(
                                      status: StatusIndicatorType.onTime,
                                    ),
                                  ),
                                ]
                              : [
                                  const RecordItem(
                                    leadingIcon: Icons.info_outline,
                                    label: 'Status',
                                    value: 'No immunizations recorded yet',
                                  ),
                                ],
                        ),

                        const SizedBox(height: 20),

                        ImportantButton(
                          label: 'View Vaccination Details',
                          leadingIcon: Icons.vaccines_outlined,
                          onPressed: widget.onViewVaccines,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}