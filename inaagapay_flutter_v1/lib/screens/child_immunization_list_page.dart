import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/small_description.dart';
import '../widgets/hero_card.dart';
import '../widgets/records_display_card.dart';
import '../widgets/status_indicator.dart';
import '../widgets/main_button.dart';

import 'add_immunization_page.dart';

// Simple enum for vaccine status
enum VaccineStatus {
  done,
  pending,
  locked,
}

class ChildImmunizationListPage extends StatefulWidget {
  final int childId;

  const ChildImmunizationListPage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildImmunizationListPage> createState() =>
      _ChildImmunizationListPageState();
}

class _ChildImmunizationListPageState
    extends State<ChildImmunizationListPage> {
  bool loading = true;
  List records = [];
  Map<String, dynamic>? childData;

  Future<void> fetchImmunizations() async {
    final token = await AuthStorage.getToken();

    try {
      // Fetch immunizations
      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_immunization_list.php?child_id=${widget.childId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final decoded = jsonDecode(res.body);
      
      // Fetch child profile for name and age
      final childRes = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_profile.php?child_id=${widget.childId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final childDecoded = jsonDecode(childRes.body);

      setState(() {
        records = decoded['records'] ?? [];
        if (childDecoded['success'] == true) {
          childData = childDecoded['child'] is Map ? childDecoded['child'] : {};
        }
        loading = false;
      });
    } catch (e) {
      setState(() {
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

  String getNextDueVaccine() {
    if (records.isEmpty) return 'Start vaccination schedule';
    
    // Simple logic - you should replace with actual vaccine schedule logic
    final administeredCount = records.length;
    if (administeredCount < 3) return 'Next primary vaccines';
    if (administeredCount < 6) return 'Follow-up vaccines';
    return 'All primary vaccines completed';
  }

  StatusIndicatorType getProtectionStatus() {
    if (records.isEmpty) return StatusIndicatorType.overdue;
    
    if (records.length >= 6) return StatusIndicatorType.onTime;
    if (records.length >= 3) return StatusIndicatorType.ongoing;
    return StatusIndicatorType.overdue;
  }

  @override
  void initState() {
    super.initState();
    fetchImmunizations();
  }

  @override
  Widget build(BuildContext context) {
    final childName = childData != null 
        ? '${childData!['first_name'] ?? ''} ${childData!['last_name'] ?? ''}'.trim()
        : 'Child';
    
    final childAge = childData != null
        ? calculateAge(childData!['birthdate']?.toString())
        : 'Unknown age';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      /// 🔝 Header (Back = pop)
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SecondaryHeader(
          title: 'Vaccination Details',
          onBack: () => Navigator.pop(context),
        ),
      ),

      /// 🔽 Body
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchImmunizations,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 👶 Child Hero
                      HeroCard(
                        image: const AssetImage('assets/images/vaccine.png'),
                        title: childName.isNotEmpty ? childName : 'Unnamed Child',
                        subtitle: childAge,
                        showWeekBadge: false,
                        showHeartRow: false,
                      ),

                      const SizedBox(height: 16),

                      /// 📝 Description
                      const SmallDescription(
                        text: 'View immunization details for this child.',
                      ),

                      const SizedBox(height: 16),

                      /// 📋 Overview
                      RecordsDisplayCard(
                        title: 'Overview',
                        headerIcon: Icons.info_outline,
                        items: [
                          RecordItem(
                            leadingIcon: Icons.verified,
                            label: 'Protection Status',
                            value: '',
                            trailingWidget: StatusIndicator(
                              status: getProtectionStatus(),
                            ),
                          ),
                          RecordItem(
                            leadingIcon: Icons.schedule,
                            label: 'Next Due',
                            value: getNextDueVaccine(),
                          ),
                          RecordItem(
                            leadingIcon: Icons.vaccines,
                            label: 'Total Vaccines',
                            value: '${records.length} administered',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// 📋 ADMINISTERED VACCINES LIST
                      if (records.isNotEmpty) ...[
                        RecordsDisplayCard(
                          title: 'Administered Vaccines',
                          headerIcon: Icons.check_circle_outline,
                          items: records.map<RecordItem>((record) {
                            final vaccineName = record['vaccine_name']?.toString() ?? 'Unknown Vaccine';
                            final doseNumber = record['dose_number']?.toString() ?? '';
                            final date = record['vaccination_date']?.toString() ?? '';
                            final remarks = record['remarks']?.toString() ?? '';
                            
                            String formattedDate = 'Not recorded';
                            if (date.isNotEmpty) {
                              try {
                                final parsed = DateTime.parse(date);
                                formattedDate = DateFormat('MMM d, yyyy').format(parsed);
                              } catch (e) {
                                formattedDate = date;
                              }
                            }

                            return RecordItem(
                              leadingIcon: Icons.vaccines,
                              label: doseNumber.isNotEmpty 
                                  ? '$vaccineName (Dose $doseNumber)'
                                  : vaccineName,
                              value: formattedDate,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Empty state
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.vaccines_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No vaccines administered yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Start the vaccination schedule to protect this child',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      /// 💉 SIMPLE VACCINE SCHEDULE
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Vaccine Schedule',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Simple vaccine schedule - you can replace with your actual data
                            _buildScheduleItem('BCG', 'Birth', records.any((r) => 
                              r['vaccine_name']?.toString().toLowerCase().contains('bcg') ?? false)),
                            _buildScheduleItem('Hepatitis B', 'Birth', records.any((r) => 
                              r['vaccine_name']?.toString().toLowerCase().contains('hepatitis') ?? false)),
                            _buildScheduleItem('Pentavalent 1', '6 weeks', records.any((r) => 
                              r['vaccine_name']?.toString().toLowerCase().contains('penta') ?? false)),
                            _buildScheduleItem('OPV 1', '6 weeks', records.any((r) => 
                              r['vaccine_name']?.toString().toLowerCase().contains('opv') ?? false)),
                            _buildScheduleItem('PCV 1', '6 weeks', records.any((r) => 
                              r['vaccine_name']?.toString().toLowerCase().contains('pcv') ?? false)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ➕ Add Immunization
                      MainButton(
                        label: 'Add Immunization',
                        showIcons: true,
                        leadingIcon: Icons.add,
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddImmunizationPage(childId: widget.childId),
                            ),
                          );
                          
                          // Refresh if immunization was added
                          if (result == true) {
                            await fetchImmunizations();
                          }
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String vaccine, String schedule, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaccine,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Text(
                  schedule,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDone 
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isDone ? 'Done' : 'Pending',
              style: TextStyle(
                fontSize: 12,
                color: isDone ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}