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
import '../../services/language_service.dart';
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

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  String _genderLabel() {
    if (widget.childGender == 'female') {
      return _t('Girl', 'Babae');
    }
    return _t('Boy', 'Lalaki');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: _t('Child Information', 'Impormasyon ng Anak'),
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
                          child: Text(_t('Retry', 'Subukan Muli')),
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
                          subtitle: '${widget.childAge} • ${_genderLabel()}',
                          showWeekBadge: false,
                          showHeartRow: false,
                        ),
                        const SizedBox(height: 24),

                        RecordsDisplayCard(
                          title: _t('Birth Details', 'Detalye ng Kapanganakan'),
                          headerIcon: Icons.cake_outlined,
                          items: [
                            RecordItem(
                              leadingIcon: Icons.calendar_month_rounded,
                              label: _t('Birth Date', 'Petsa ng Kapanganakan'),
                              value: _formatDate(_data?['child']?.birthdate),
                            ),
                            RecordItem(
                              leadingIcon: Icons.location_on_outlined,
                              label: _t('Birthplace', 'Lugar ng Kapanganakan'),
                              value: _getBirthplace(_data?['child']),
                            ),
                            if (_data?['child']?.birthWeight != null)
                              RecordItem(
                                leadingIcon: Icons.monitor_weight,
                                label: _t('Birth Weight', 'Timbang sa Kapanganakan'),
                                value: '${_data?['child']?.birthWeight} kg',
                              ),
                            if (_data?['child']?.birthLength != null)
                              RecordItem(
                                leadingIcon: Icons.height,
                                label: _t('Birth Length', 'Haba sa Kapanganakan'),
                                value: '${_data?['child']?.birthLength} cm',
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        RecordsDisplayCard(
                          title: _t('Latest Growth Records',
                              'Pinakabagong Growth Records'),
                          headerIcon: Icons.bar_chart_rounded,
                          items: [
                            RecordItem(
                              leadingIcon: Icons.height,
                              label: _t('Height', 'Taas'),
                              value: _data?['latest_growth'] != null
                                  ? '${(_data?['latest_growth'] as GrowthRecord).height.toStringAsFixed(1)} cm'
                                  : '-- cm',
                            ),
                            RecordItem(
                              leadingIcon: Icons.monitor_weight,
                              label: _t('Weight', 'Timbang'),
                              value: _data?['latest_growth'] != null
                                  ? '${(_data?['latest_growth'] as GrowthRecord).weight.toStringAsFixed(1)} kg'
                                  : '-- kg',
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        ImportantButton(
                          label: _t('View Growth Statistics',
                              'Tingnan ang Growth Statistics'),
                          leadingIcon: Icons.bar_chart_rounded,
                          onPressed: widget.onViewGrowth,
                        ),

                        const SizedBox(height: 20),

                        RecordsDisplayCard(
                          title: _t('Latest Immunization',
                              'Pinakabagong Bakuna'),
                          headerIcon: Icons.vaccines_outlined,
                          items: (_data?['immunizations'] as List?)?.isNotEmpty == true
                              ? [
                                  RecordItem(
                                    leadingIcon: Icons.vaccines,
                                    label: _t('Name', 'Pangalan'),
                                    value: (_data?['immunizations'] as List).first.vaccineName,
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.calendar_month_rounded,
                                    label: _t('Taken', 'Nakuha'),
                                    value: DateFormat('MMM d, yyyy').format(
                                      (_data?['immunizations'] as List).first.vaccinationDate
                                    ),
                                    trailingWidget: const StatusIndicator(
                                      status: StatusIndicatorType.onTime,
                                    ),
                                  ),
                                ]
                              : [
                                  RecordItem(
                                    leadingIcon: Icons.info_outline,
                                    label: _t('Status', 'Status'),
                                    value: _t(
                                        'No immunizations recorded yet',
                                        'Wala pang naitalang bakuna'),
                                  ),
                                ],
                        ),

                        const SizedBox(height: 20),

                        ImportantButton(
                          label: _t('View Vaccination Details',
                              'Tingnan ang Detalye ng Bakuna'),
                          leadingIcon: Icons.vaccines_outlined,
                          onPressed: widget.onViewVaccines,
                        ),
                      ],
                    ),
                  ),
      ),
        );
      },
    );
  }
}
