import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'trimester_card.dart';

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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        children: [
          /// MAIN NUMBER
          Text(
            totalPregnancies.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.brandText,
            ),
          ),

          const SizedBox(height: 8),

          /// HEADER (icon + title)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.circle,
                size: 12,
                color: AppColors.brandPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Active Pregnancies',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// TRIMESTER CARDS
          Row(
            children: [
              Expanded(
                child: TrimesterCard(
                  value: firstTrimester,
                  title: '1st\nTrimester',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TrimesterCard(
                  value: secondTrimester,
                  title: '2nd\nTrimester',
                  backgroundColor: AppColors.brandSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TrimesterCard(
                  value: thirdTrimester,
                  title: '3rd\nTrimester',
                  backgroundColor: AppColors.faintWhite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
