import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RiskPreviewCard extends StatelessWidget {
  const RiskPreviewCard({
    super.key,
    required this.level,
    required this.score,
    required this.factors,
    required this.note,
  });

  final String level; // low | medium | high
  final int score;
  final List<String> factors;
  final String note;

  Color _pillColor() {
    switch (level) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _label() {
    switch (level) {
      case 'high':
        return 'High Risk';
      case 'medium':
        return 'Medium Risk';
      default:
        return 'Low Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _pillColor().withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: _pillColor(), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _label(),
                          style: TextStyle(
                            color: _pillColor(),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Score: $score',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (factors.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: factors
                  .take(4)
                  .map(
                    (f) => Chip(
                      backgroundColor: AppColors.brandSecondary,
                      label: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.brandText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  )
                  .toList(),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
