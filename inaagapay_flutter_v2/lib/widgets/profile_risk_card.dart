// lib/widgets/profile_risk_card.dart
// Risk assessment card, extracted from _buildSimpleRiskCard.

import 'package:flutter/material.dart';
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
    final riskColor = isHigh ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Risk header strip ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHigh
                    ? [Colors.red.shade400, Colors.red.shade600]
                    : [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  isHigh
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Column(
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
                      isHigh ? 'Needs closer monitoring' : 'Readings within normal range',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHigh) ...[
                  Text(
                    risk.note,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...risk.findings.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                // ── Expandable: What happened before ──
                if (history.isNotEmpty) ...[
                  const Divider(height: 20),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text('What happened before',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      children: history.map((event) {
                        final isElevated = event.type == 'elevated';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isElevated
                                    ? Icons.arrow_upward
                                    : Icons.circle,
                                size: 12,
                                color: isElevated
                                    ? Colors.orange
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event.what,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800)),
                                    if (event.week != null)
                                      Text('Week ${event.week!.toInt()}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // ── Expandable: What to watch ──
                if (watchList.isNotEmpty) ...[
                  const Divider(height: 8),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined,
                              size: 16, color: AppColors.info),
                          SizedBox(width: 6),
                          Text('What to watch',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      children: watchList
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.fiber_manual_record,
                                        size: 8, color: AppColors.info),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(item,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade800)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
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
