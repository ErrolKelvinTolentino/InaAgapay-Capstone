import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProgressiveStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const ProgressiveStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isActive = index <= currentStep;

            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.brandPrimary
                    : AppColors.borderPrimary,
              ),
            );
          }),
        ),

        const SizedBox(height: 8),

        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
