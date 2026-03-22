// lib/widgets/ai_analytics_card.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AiAnalyticsCard extends StatelessWidget {
  final String text;
  final bool isLoading;

  const AiAnalyticsCard({
    super.key,
    required this.text,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPrimary.withValues(alpha: 0.08),
            AppColors.brandAccent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI GROWTH ANALYSIS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              ),
            )
          else
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}