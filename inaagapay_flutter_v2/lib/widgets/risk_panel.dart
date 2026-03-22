// lib/widgets/risk_panel.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/risk_engine.dart';

class RiskPanel extends StatelessWidget {
  final RiskAssessment assessment;
  final bool concise; // Add this parameter

  const RiskPanel({
    super.key,
    required this.assessment,
    this.concise = true, // Default to concise view
  });

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

  IconData _getRiskIcon() {
    switch (assessment.level) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _getConciseNote() {
    // Extract only the first sentence or a concise summary
    final note = assessment.note;
    if (note.isEmpty) return 'No significant risk factors identified.';
    
    // For AI-generated notes, extract just the risk level
    if (note.contains('RISK LEVEL:')) {
      // Try to extract just the risk level line
      final lines = note.split('\n');
      for (final line in lines) {
        if (line.contains('RISK LEVEL:')) {
          return line.trim();
        }
        if (line.contains('Risk level:')) {
          return line.trim();
        }
      }
    }
    
    // Otherwise, take first sentence only
    final firstPeriod = note.indexOf('.');
    if (firstPeriod > 0 && firstPeriod < 100) {
      return note.substring(0, firstPeriod + 1);
    }
    
    // Fallback: first line or first 80 characters
    final firstLine = note.split('\n').first;
    if (firstLine.length <= 80) return firstLine;
    return '${firstLine.substring(0, 80)}...';
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();
    final riskIcon = _getRiskIcon();
    final displayNote = concise ? _getConciseNote() : assessment.note;
    
    // For concise view, show fewer risk factors
    final displayFactors = concise && assessment.factors.length > 3
        ? assessment.factors.take(2).toList()
        : assessment.factors;
    
    final hasMoreFactors = concise && assessment.factors.length > 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  riskIcon,
                  color: riskColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Assessment',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assessment.level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: ${assessment.score.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Note - now concise in default view
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              displayNote,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Factors header
          const Text(
            'Risk Factors:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Risk factors list
          ...displayFactors.map(
            (factor) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 8,
                    color: riskColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      factor,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Show "See more" if there are additional factors
          if (hasMoreFactors)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () {
                  // Show a snackbar indicating there are more factors
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('View full risk assessment in details section below'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See ${assessment.factors.length - 2} more factors...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}