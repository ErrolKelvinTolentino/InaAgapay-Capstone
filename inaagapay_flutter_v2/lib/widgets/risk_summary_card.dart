// lib/widgets/risk_summary_card.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/risk_engine.dart';

class RiskSummaryCard extends StatelessWidget {
  final RiskAssessment assessment;

  const RiskSummaryCard({
    super.key,
    required this.assessment,
  });

  String _getRiskSummary() {
    if (assessment.level == 'high') {
      return 'High-risk pregnancy detected. Close monitoring required.';
    } else if (assessment.level == 'medium') {
      return 'Moderate risk factors present. Regular monitoring recommended.';
    } else {
      return 'Low-risk pregnancy. Continue routine care.';
    }
  }

  Color _getRiskColor() {
    switch (assessment.level) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              assessment.level == 'high'
                  ? Icons.warning_amber_rounded
                  : assessment.level == 'medium'
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
              color: riskColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Risk: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      assessment.level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Score: ${assessment.score.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getRiskSummary(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (assessment.factors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: assessment.factors.take(2).map((factor) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          factor.length > 30 
                              ? '${factor.substring(0, 27)}...' 
                              : factor,
                          style: TextStyle(
                            fontSize: 10,
                            color: riskColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}