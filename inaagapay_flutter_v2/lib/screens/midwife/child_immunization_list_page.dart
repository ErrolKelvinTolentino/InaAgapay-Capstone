// lib/screens/midwife/child_immunization_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';

class ChildImmunizationListPage extends StatefulWidget {
  final int childId;

  const ChildImmunizationListPage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildImmunizationListPage> createState() => _ChildImmunizationListPageState();
}

class _ChildImmunizationListPageState extends State<ChildImmunizationListPage> {
  bool loading = true;
  List<Map<String, dynamic>> records = [];
  Map<String, dynamic>? childData;
  DateTime? birthdate;

  @override
  void initState() {
    super.initState();
    fetchImmunizations();
  }

  Future<void> fetchImmunizations() async {
    setState(() => loading = true);

    try {
      // Fetch child details
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            sex
          ''')
          .eq('child_id', widget.childId)
          .single();

      // Fetch birth details separately (directly from birth_details table)
      final birthDetailsResponse = await Supabase.instance.client
          .from('birth_details')
          .select('birthdate')
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (birthDetailsResponse != null && birthDetailsResponse['birthdate'] != null) {
        birthdate = DateTime.parse(birthDetailsResponse['birthdate']);
      }

      childData = childResponse;

      // Fetch immunization records with vaccine details
      final immunizationResponse = await Supabase.instance.client
          .from('immunization_record')
          .select('''
            *,
            vaccine:vaccine_id (
              vaccine_id,
              vaccine_name,
              dose_number,
              recommended_age_months,
              notes
            )
          ''')
          .eq('child_id', widget.childId)
          .order('vaccination_date', ascending: false);

      records = List<Map<String, dynamic>>.from(immunizationResponse);
      
      debugPrint('Loaded ${records.length} immunization records');

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint('Error loading immunizations: $e');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading immunizations: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String getChildName() {
    if (childData == null) return 'Child';
    return '${childData!['first_name'] ?? ''} ${childData!['last_name'] ?? ''}'.trim();
  }

  String calculateAge() {
    if (birthdate == null) return 'Unknown age';

    try {
      final now = DateTime.now();

      int years = now.year - birthdate!.year;
      int months = now.month - birthdate!.month;

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
    if (date == null || date.isEmpty) return 'No date';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Immunization Records',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchImmunizations,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : Column(
                  children: [
                    HeroCard(
                      image: null,
                      title: getChildName(),
                      subtitle: calculateAge(),
                      showWeekBadge: false,
                      showHeartRow: false,
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: records.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.vaccines_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Immunization Records',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add immunization records to track vaccinations',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: fetchImmunizations,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandPrimary,
                                    ),
                                    child: const Text(
                                      'Refresh',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              itemCount: records.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final vaccine = record['vaccine'] as Map<String, dynamic>?;
                                final vaccineName = vaccine?['vaccine_name']?.toString() ?? 'Unknown Vaccine';
                                final doseNumber = vaccine?['dose_number']?.toString() ?? '';
                                final notes = vaccine?['notes']?.toString() ?? '';
                                final date = record['vaccination_date']?.toString() ?? '';
                                final remarks = record['remarks']?.toString() ?? '';

                                return ImmunizationRecordCard(
                                  vaccineName: vaccineName,
                                  doseNumber: doseNumber,
                                  notes: notes,
                                  date: formatDate(date),
                                  remarks: remarks,
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ImmunizationRecordCard extends StatelessWidget {
  final String vaccineName;
  final String doseNumber;
  final String notes;
  final String date;
  final String remarks;

  const ImmunizationRecordCard({
    super.key,
    required this.vaccineName,
    required this.doseNumber,
    required this.notes,
    required this.date,
    required this.remarks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.vaccines,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vaccineName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (doseNumber.isNotEmpty)
                      Text(
                        'Dose $doseNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (notes.isNotEmpty)
                      Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Given',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remarks,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}