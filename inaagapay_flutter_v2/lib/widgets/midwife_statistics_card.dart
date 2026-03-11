// lib/widgets/midwife_statistics_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MidwifeStatisticsCard extends StatelessWidget {
  final int totalPregnancies;
  final int firstTrimester;
  final int secondTrimester;
  final int thirdTrimester;

  const MidwifeStatisticsCard({
    super.key,
    required this.totalPregnancies,
    required this.firstTrimester,
    required this.secondTrimester,
    required this.thirdTrimester,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Pregnancies',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $totalPregnancies',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTrimesterRow(
            'First Trimester',
            firstTrimester,
            totalPregnancies,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildTrimesterRow(
            'Second Trimester',
            secondTrimester,
            totalPregnancies,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTrimesterRow(
            'Third Trimester',
            thirdTrimester,
            totalPregnancies,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTrimesterRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}