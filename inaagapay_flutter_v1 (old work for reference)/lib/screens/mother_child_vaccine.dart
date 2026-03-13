import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/small_description.dart';
import '../widgets/hero_card.dart';
import '../widgets/records_display_card.dart';
import '../widgets/status_indicator.dart';

import '../services/api_service.dart';
import '../utils/session.dart';

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
  State<MotherChildVaccinePage> createState() =>
      _MotherChildVaccinePageState();
}

class _MotherChildVaccinePageState extends State<MotherChildVaccinePage> {

  Future<Map<String, dynamic>> _fetchVaccines() async {
    return await ApiService.get(
      'mother/child_vaccines.php?child_id=${widget.childId}',
      token: Session.token,
    );
  }

  StatusIndicatorType _statusIcon(String status) {
    switch (status) {
      case 'done':
        return StatusIndicatorType.onTime;
      case 'pending':
        return StatusIndicatorType.ongoing;
      default:
        return StatusIndicatorType.ongoing;
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
          onBack: widget.onBack,
        ),
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchVaccines(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!['success'] != true) {
            return const Center(
              child: Text(
                'Failed to load vaccines',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final vaccines = snapshot.data!['vaccines'] as List;

          return SafeArea(
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

                  ...vaccines.map((v) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RecordsDisplayCard(
                        title: '${v['name']} (Dose ${v['dose']})',
                        headerIcon: Icons.vaccines_outlined,
                        items: [
                          RecordItem(
                            leadingIcon: Icons.schedule,
                            label: 'Recommended',
                            value: '${v['recommended_months']} months',
                          ),
                          RecordItem(
                            leadingIcon: Icons.verified,
                            label: 'Status',
                            value: v['status'].toUpperCase(),
                            trailingWidget: StatusIndicator(
                              status: _statusIcon(v['status']),
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
          );
        },
      ),
    );
  }
}
