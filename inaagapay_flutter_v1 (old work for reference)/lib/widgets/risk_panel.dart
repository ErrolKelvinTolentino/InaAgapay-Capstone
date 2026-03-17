import 'package:flutter/material.dart';

import '../services/risk_engine.dart';
import '../theme/app_colors.dart';

class RiskPanel extends StatefulWidget {
  const RiskPanel({
    super.key,
    required this.assessment,
    this.collapsible = false,
    this.initiallyExpanded = false,
  });

  final RiskAssessment assessment;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  State<RiskPanel> createState() => _RiskPanelState();
}

class _RiskPanelState extends State<RiskPanel> {
  late bool _expanded = widget.collapsible ? widget.initiallyExpanded : true;

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(widget.assessment.level);
    final showDetails = widget.collapsible ? _expanded : true;

    return InkWell(
      onTap: widget.collapsible
          ? () => setState(() => _expanded = !_expanded)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.faintWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield,
                  color: AppColors.brandAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pregnancy Risk',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandText,
                  ),
                ),
                const Spacer(),
                Chip(
                  backgroundColor: color.withOpacity(0.15),
                  label: Text(
                    widget.assessment.level.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.collapsible) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                widget.assessment.note,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...widget.assessment.factors.map(
                (f) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }
}
