import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InfoRow extends StatelessWidget {
  final IconData icon;
  final InlineSpan text;

  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon (optically aligned)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 22,
              color: AppColors.brandAccent,
            ),
          ),

          const SizedBox(width: 14),

          // Text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
                children: [text],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
