import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'vaccine_schedule_status.dart';

class ChildCard extends StatefulWidget {
  final String fullName;
  final String ageText; // e.g. "0 years 5 months old"
  final ImageProvider? image;
  final VaccineScheduleStatus vaccineStatus;
  final VoidCallback? onTap;

  const ChildCard({
    super.key,
    required this.fullName,
    required this.ageText,
    required this.vaccineStatus,
    this.image,
    this.onTap,
  });

  @override
  State<ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<ChildCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHighlightChanged: (isPressed) {
            setState(() => _pressed = isPressed);
          },
          splashColor: AppColors.brandPrimary.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // 👶 Child Image
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                    image: widget.image != null
                        ? DecorationImage(
                            image: widget.image!,
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: AssetImage(
                              'assets/images/baby.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // 🧾 Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        widget.ageText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 💉 Vaccine Status Badge
                      VaccineScheduleStatusBadge(
                        status: widget.vaccineStatus,
                      ),
                    ],
                  ),
                ),

                // ➡️ Arrow
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
