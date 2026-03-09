import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/main_bottom_navigation.dart';
import '../widgets/hero_card.dart';
import '../widgets/records_display_card.dart';
import '../widgets/status_indicator.dart';
import '../widgets/important_button.dart';

import '../services/api_service.dart';
import '../utils/session.dart';

class MotherViewChildPage extends StatefulWidget {
  final VoidCallback onBackToChildren;
  final VoidCallback onViewGrowth;
  final VoidCallback onViewVaccines;
  final int childId;

  const MotherViewChildPage({
    super.key,
    required this.onBackToChildren,
    required this.onViewGrowth,
    required this.onViewVaccines,
    required this.childId,
  });

  @override
  State<MotherViewChildPage> createState() => _MotherViewChildPageState();
}

class _MotherViewChildPageState extends State<MotherViewChildPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchChild();
  }

  Future<void> _fetchChild() async {
    final res = await ApiService.get(
      'mother/view_child.php?child_id=${widget.childId}',
      token: Session.token,
    );

    if (!res['success']) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _data = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final child = _data!['child'];
    final growth = _data!['growth'];
    final vaccine = _data!['latest_vaccine'];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Child Information',
          onBack: widget.onBackToChildren,
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              HeroCard(
                image: const AssetImage('assets/images/baby.png'),
                title: child['full_name'],
                subtitle: 'Born ${child['birthdate'] ?? '--'}',
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
                    value: child['birthdate'] ?? '--',
                  ),
                  RecordItem(
                    leadingIcon: Icons.location_on_outlined,
                    label: 'Birthplace',
                    value: child['birthplace'].isNotEmpty
                        ? child['birthplace']
                        : '--',
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
                    value: growth?['child_height'] != null
                        ? '${growth['child_height']} cm'
                        : '-- cm',
                  ),
                  RecordItem(
                    leadingIcon: Icons.monitor_weight,
                    label: 'Weight',
                    value: growth?['child_weight'] != null
                        ? '${growth['child_weight']} kg'
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
                items: [
                  RecordItem(
                    leadingIcon: Icons.vaccines,
                    label: 'Name',
                    value: vaccine?['vaccine_name'] ?? '--',
                  ),
                  RecordItem(
                    leadingIcon: Icons.calendar_month_rounded,
                    label: 'Taken',
                    value: vaccine?['vaccination_date'] ?? '--',
                    trailingWidget: const StatusIndicator(
                      status: StatusIndicatorType.onTime,
                    ),
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

      bottomNavigationBar: const MainBottomNavigation(
        currentIndex: 2,
      ),
    );
  }
}
