// lib/screens/midwife/child_growth_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/hero_card.dart';

class ChildGrowthListPage extends StatefulWidget {
  final int childId;

  const ChildGrowthListPage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildGrowthListPage> createState() => _ChildGrowthListPageState();
}

class _ChildGrowthListPageState extends State<ChildGrowthListPage> {
  bool loading = true;
  List<Map<String, dynamic>> records = [];
  Map<String, dynamic>? childData;
  DateTime? birthdate;

  @override
  void initState() {
    super.initState();
    fetchGrowthRecords();
  }

  Future<void> fetchGrowthRecords() async {
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

      // Fetch growth records
      final growthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: false);

      records = List<Map<String, dynamic>>.from(growthResponse);

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error loading growth records: $e');
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading growth records: $e'),
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
          title: 'Growth Records',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchGrowthRecords,
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
                                    Icons.auto_graph_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Growth Records',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add growth records to track development',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
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
                                final height = (record['child_height'] as num?)?.toDouble() ?? 0;
                                final weight = (record['child_weight'] as num?)?.toDouble() ?? 0;
                                final date = record['created_at']?.toString() ?? '';

                                return GrowthRecordCard(
                                  height: height,
                                  weight: weight,
                                  date: formatDate(date),
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

class GrowthRecordCard extends StatelessWidget {
  final double height;
  final double weight;
  final String date;

  const GrowthRecordCard({
    super.key,
    required this.height,
    required this.weight,
    required this.date,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMeasurementItem(
                  'Height',
                  '${height.toStringAsFixed(1)} cm',
                  Icons.height,
                  AppColors.brandPrimary,
                ),
              ),
              Expanded(
                child: _buildMeasurementItem(
                  'Weight',
                  '${weight.toStringAsFixed(1)} kg',
                  Icons.monitor_weight,
                  AppColors.brandAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}