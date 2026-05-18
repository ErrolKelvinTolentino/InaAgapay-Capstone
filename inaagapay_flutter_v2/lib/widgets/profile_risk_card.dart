// lib/widgets/profile_risk_card.dart
// Risk assessment card, extracted from _buildSimpleRiskCard.

import 'package:flutter/material.dart';
import '../models/smart_risk_models.dart';
import '../theme/app_colors.dart';
import '../services/risk_engine.dart';
import '../services/smart_risk_engine.dart';

class ProfileRiskCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> pregnancy;

  const ProfileRiskCard({
    super.key,
    required this.profile,
    required this.pregnancy,
  });

  @override
  Widget build(BuildContext context) {
    final checkups =
        (pregnancy['checkups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pastPregnancies =
        (profile['past_pregnancies'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    final latestCheckup = checkups.isNotEmpty
        ? (List<Map<String, dynamic>>.from(checkups)
              ..sort((a, b) {
                final da =
                    DateTime.tryParse(a['checkup_datetime']?.toString() ?? '');
                final db =
                    DateTime.tryParse(b['checkup_datetime']?.toString() ?? '');
                if (da == null || db == null) return 0;
                return db.compareTo(da);
              }))
            .first
        : null;

    if (latestCheckup == null) return _buildNoDataCard();

    final risk = RiskEngine.evaluate(latestCheckup: latestCheckup);
    final history = SmartRiskEngine.buildHistory(
        allCheckups: checkups, pastPregnancies: pastPregnancies);
    final watchList = SmartRiskEngine.buildWatchList(
      allCheckups: checkups,
      pastPregnancies: pastPregnancies,
      latestCheckup: latestCheckup,
    );

    final isHigh = risk.level == 'high';
    final riskColor = isHigh ? AppColors.error : AppColors.success;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRiskDetailsModal(
          context,
          risk: risk,
          history: history,
          watchList: watchList,
          isHigh: isHigh,
          riskColor: riskColor,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isHigh
                  ? [AppColors.error, const Color(0xFFD32F2F)]
                  : [AppColors.success, const Color(0xFF4CAF93)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: riskColor.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isHigh ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHigh ? 'HIGH RISK' : 'LOW RISK',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        risk.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRiskDetailsModal(
    BuildContext context, {
    required RiskAssessment risk,
    required List<PregnancyEvent> history,
    required List<String> watchList,
    required bool isHigh,
    required Color riskColor,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Risk Assessment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusBanner(
                    isHigh: isHigh,
                    risk: risk,
                    riskColor: riskColor,
                  ),
                  const SizedBox(height: 16),
                  _buildRiskSection(
                    title: 'Current Risk Factors',
                    icon: isHigh
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    iconColor: riskColor,
                    children: risk.findings.isEmpty
                        ? [
                            _buildDetailRow(
                              'All readings within normal range',
                              AppColors.success,
                            ),
                          ]
                        : risk.findings
                            .map((finding) =>
                                _buildDetailRow(finding, AppColors.error))
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildRiskSection(
                    title: 'Earlier Risk Factors',
                    icon: Icons.history_rounded,
                    iconColor: AppColors.warning,
                    children: history.isEmpty
                        ? [
                            _buildDetailRow(
                              'No earlier risk factors recorded',
                              AppColors.textSecondary,
                            ),
                          ]
                        : history.map(_buildHistoryRow).toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildRiskSection(
                    title: 'What to Observe',
                    icon: Icons.remove_red_eye_outlined,
                    iconColor: AppColors.info,
                    children: watchList
                        .map((item) => _buildDetailRow(item, AppColors.info))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBanner({
    required bool isHigh,
    required RiskAssessment risk,
    required Color riskColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isHigh ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: riskColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHigh ? 'HIGH RISK' : 'LOW RISK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: riskColor,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  risk.note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(PregnancyEvent event) {
    final isElevated = event.type == 'elevated';
    final iconColor = isElevated ? AppColors.warning : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isElevated ? Icons.arrow_upward_rounded : Icons.circle,
            size: isElevated ? 14 : 8,
            color: iconColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.what,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
                if (event.week != null)
                  Text(
                    'Week ${event.week!.toInt()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary),
          SizedBox(width: 12),
          Text('No checkup data available yet',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
