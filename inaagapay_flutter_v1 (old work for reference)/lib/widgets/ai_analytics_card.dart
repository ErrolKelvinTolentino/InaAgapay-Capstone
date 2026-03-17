import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AiAnalyticsCard extends StatelessWidget {
  final String text;

  const AiAnalyticsCard({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brandPrimary.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🤖 HEADER
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 🧠 ANALYSIS TEXT
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
