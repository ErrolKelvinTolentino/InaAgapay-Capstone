import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HeroCard extends StatelessWidget {
  final ImageProvider image;
  final String? title;
  final String? subtitle;
  final int? week;
  final bool showWeekBadge;
  final bool showHeartRow;

  const HeroCard({
    super.key,
    required this.image,
    this.title,
    this.subtitle,
    this.week,
    this.showWeekBadge = false,
    this.showHeartRow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bgSecondary,
                  ),
                  child: Image(
                    image: image,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              if (showWeekBadge && week != null)
                Positioned(
                  top: 6,
                  right: 24,
                  child: _WeekBadge(week: week!),
                ),
            ],
          ),

          if (title != null) ...[
            const SizedBox(height: 16),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPrimary,
              ),
            ),
          ],

          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],

          if (showHeartRow) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.favorite,
                    size: 16, color: AppColors.brandPrimary),
                SizedBox(width: 6),
                Text(
                  'Your baby is growing beautifully!',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekBadge extends StatelessWidget {
  final int week;

  const _WeekBadge({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Week $week',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnColor,
        ),
      ),
    );
  }
}
