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
import '../../services/language_service.dart';
import '../../models/child_model.dart';

class MotherChildVaccinePage extends StatefulWidget {
  final VoidCallback onBack;
  final int childId;
  final String childName;
  final String childAge;
  final String childGender;

  const MotherChildVaccinePage({
    super.key,
    required this.onBack,
    required this.childId,
    required this.childName,
    required this.childAge,
    required this.childGender,
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
      if (mounted) {
        setState(() {
          _immunizations = immunizations;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  String _formatRecommendedAge(double months) {
    if (months == 0) return _t('At birth', 'Sa kapanganakan');
    if (months < 1) {
      final weeks = (months * 4).round();
      if (LanguageService.isFilipino) return '$weeks linggo';
      return '$weeks week${weeks != 1 ? 's' : ''}';
    }
    if (months == 1) return _t('1 month', '1 buwan');
    if (LanguageService.isFilipino && months < 12) {
      return '${months.toInt()} buwan';
    }
    if (months < 12) return '${months.toInt()} months';
    final years = (months / 12).floor();
    if (LanguageService.isFilipino) return '$years taon';
    return '$years year${years != 1 ? 's' : ''}';
  }

  StatusIndicatorType _getStatusIcon(ImmunizationRecord record) {
    // All records in the list are already given (since they're from immunization_record table)
    return StatusIndicatorType.onTime;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SecondaryHeader(
          title: _t('Vaccination Details', 'Detalye ng Bakuna'),
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
                          child: Text(_t('Retry', 'Subukan Muli')),
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
                          sex: widget.childGender,
                          showWeekBadge: false,
                          showHeartRow: false,
                        ),
                        const SizedBox(height: 16),
                        SmallDescription(
                          text: _t(
                              'Vaccines administered based on immunization schedule',
                              'Mga bakunang ibinigay batay sa immunization schedule'),
                        ),
                        const SizedBox(height: 16),
                        if (_immunizations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.vaccines_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _t('No immunizations recorded yet',
                                      'Wala pang naitalang bakuna'),
                                  style: const TextStyle(
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
                                title:
                                    '${v.vaccineName} (${_t('Dose', 'Dose')} ${v.doseNumber})',
                                headerIcon: Icons.vaccines_outlined,
                                items: [
                                  RecordItem(
                                    leadingIcon: Icons.schedule,
                                    label: _t('Recommended', 'Inirerekomenda'),
                                    value: _formatRecommendedAge(v.recommendedAgeMonths),
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.calendar_month_rounded,
                                    label: _t('Date Given', 'Petsa ng Pagbigay'),
                                    value: _formatDate(v.vaccinationDate),
                                  ),
                                  RecordItem(
                                    leadingIcon: Icons.verified,
                                    label: _t('Status', 'Status'),
                                    value: _t('COMPLETED', 'KUMPLETO'),
                                    trailingWidget: StatusIndicator(
                                      status: _getStatusIcon(v),
                                    ),
                                  ),
                                  if (v.remarks != null && v.remarks!.isNotEmpty)
                                    RecordItem(
                                      leadingIcon: Icons.notes_outlined,
                                      label: _t('Remarks', 'Mga Tala'),
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
      },
    );
  }
}
