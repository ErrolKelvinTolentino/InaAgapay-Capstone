// lib/widgets/risk_panel.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/risk_engine.dart';

class RiskPanel extends StatelessWidget {
  final RiskAssessment assessment;
  final bool collapsible;

  const RiskPanel({
    super.key,
    required this.assessment,
    this.collapsible = false,
  });

  Color get _riskColor {
    switch (assessment.level) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData get _riskIcon {
    switch (assessment.level) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.error_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _riskColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_riskIcon, color: _riskColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Risk Assessment: ${assessment.level.toUpperCase()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _riskColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Score: ${assessment.score.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: _riskColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Factors:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ...assessment.factors.take(3).map((factor) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  factor,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
        if (assessment.factors.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '+${assessment.factors.length - 3} more',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _riskColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            assessment.note,
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );

    if (collapsible) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _riskColor.withOpacity(0.3)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(_riskIcon, color: _riskColor, size: 18),
            title: Text(
              'Risk: ${assessment.level.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _riskColor,
              ),
            ),
            children: [Padding(padding: const EdgeInsets.all(12), child: content)],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _riskColor.withOpacity(0.3)),
      ),
      child: content,
    );
  }
}