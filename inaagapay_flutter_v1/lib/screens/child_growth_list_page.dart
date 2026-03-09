import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/hero_card.dart';
import '../widgets/records_display_card.dart';

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
  List records = [];
  Map<String, dynamic>? childData;

  Future<void> fetchGrowthRecords() async {
    final token = await AuthStorage.getToken();

    try {
      // Fetch growth records
      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/child_growth_list.php?child_id=${widget.childId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final decoded = jsonDecode(res.body);

      // Fetch child profile for name
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
      setState(() => loading = false);
    }
  }

  String getChildName() {
    if (childData == null) return 'Child';
    return '${childData!['first_name'] ?? ''} ${childData!['last_name'] ?? ''}'.trim();
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

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return 'No date';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  String getBMICategory(double? bmi) {
    if (bmi == null) return 'Normal';
    if (bmi < 16) return 'Underweight';
    if (bmi < 18.5) return 'Normal';
    if (bmi < 25) return 'Overweight';
    if (bmi < 30) return 'Obese';
    return 'Severely Obese';
  }

  Color getBMIColor(double? bmi) {
    if (bmi == null) return AppColors.success;
    if (bmi < 16) return AppColors.warning;
    if (bmi < 18.5) return AppColors.success;
    if (bmi < 25) return AppColors.warning;
    return AppColors.error;
  }

  @override
  void initState() {
    super.initState();
    fetchGrowthRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      /// 🔝 HEADER
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Growth Records',
          onBack: () => Navigator.pop(context),
        ),
      ),

      /// 🔽 BODY
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
                    /// 👶 CHILD HERO
                    HeroCard(
                      image: const AssetImage('assets/images/baby.png'),
                      title: getChildName(),
                      subtitle: calculateAge(childData?['birthdate']?.toString()),
                      showWeekBadge: false,
                      showHeartRow: false,
                    ),

                    const SizedBox(height: 16),

                    /// 📊 SUMMARY CARD
                    if (records.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              '${records.length}',
                              'Records',
                              Icons.list_alt,
                            ),
                            _buildStatItem(
                              '${_calculateAverageHeight().toStringAsFixed(1)} cm',
                              'Avg Height',
                              Icons.height,
                            ),
                            _buildStatItem(
                              '${_calculateAverageWeight().toStringAsFixed(1)} kg',
                              'Avg Weight',
                              Icons.monitor_weight,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    /// 📋 GROWTH RECORDS LIST
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
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: fetchGrowthRecords,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                                final height = double.tryParse(record['child_height']?.toString() ?? '0') ?? 0;
                                final weight = double.tryParse(record['child_weight']?.toString() ?? '0') ?? 0;
                                final bmi = double.tryParse(record['bmi']?.toString() ?? '0');
                                final date = record['created_at']?.toString() ?? '';
                                final remarks = record['remarks']?.toString() ?? '';

                                return GrowthRecordCard(
                                  height: height,
                                  weight: weight,
                                  bmi: bmi,
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

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.brandPrimary,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  double _calculateAverageHeight() {
    if (records.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final record in records) {
      final height = double.tryParse(record['child_height']?.toString() ?? '0') ?? 0;
      if (height > 0) {
        total += height;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  double _calculateAverageWeight() {
    if (records.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final record in records) {
      final weight = double.tryParse(record['child_weight']?.toString() ?? '0') ?? 0;
      if (weight > 0) {
        total += weight;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }
}

/// 🧩 GROWTH RECORD CARD WIDGET
class GrowthRecordCard extends StatelessWidget {
  final double height;
  final double weight;
  final double? bmi;
  final String date;
  final String remarks;

  const GrowthRecordCard({
    super.key,
    required this.height,
    required this.weight,
    this.bmi,
    required this.date,
    required this.remarks,
  });

  String getBMICategory(double? bmi) {
    if (bmi == null) return 'Normal';
    if (bmi < 16) return 'Underweight';
    if (bmi < 18.5) return 'Normal';
    if (bmi < 25) return 'Overweight';
    if (bmi < 30) return 'Obese';
    return 'Severely Obese';
  }

  Color getBMIColor(double? bmi) {
    if (bmi == null) return AppColors.success;
    if (bmi < 16) return AppColors.warning;
    if (bmi < 18.5) return AppColors.success;
    if (bmi < 25) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final bmiColor = getBMIColor(bmi);
    final bmiCategory = getBMICategory(bmi);
    final bmiValue = bmi?.toStringAsFixed(1) ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 📅 DATE HEADER
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bmiColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'BMI: $bmiValue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bmiColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 📊 MEASUREMENTS
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

          /// 📝 BMI STATUS
          if (bmi != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: bmiColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BMI Status: $bmiCategory',
                      style: TextStyle(
                        color: bmiColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          /// 📝 REMARKS (IF ANY)
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

  Widget _buildMeasurementItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
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