// lib/widgets/hero_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HeroCard extends StatelessWidget {
  final String? image;
  final String title;
  final String subtitle;
  final bool showWeekBadge;
  final bool showHeartRow;

  const HeroCard({
    super.key,
    this.image,
    required this.title,
    required this.subtitle,
    required this.showWeekBadge,
    required this.showHeartRow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandSecondary, AppColors.brandSecondary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}