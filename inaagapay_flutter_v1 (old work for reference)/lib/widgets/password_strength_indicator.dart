import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PasswordStrength { weak, medium, strong }

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthIndicator({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    late final IconData icon;

    switch (strength) {
      case PasswordStrength.strong:
        label = 'Strong';
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case PasswordStrength.medium:
        label = 'Medium';
        color = AppColors.warning;
        icon = Icons.radio_button_unchecked;
        break;
      default:
        label = 'Weak';
        color = AppColors.error;
        icon = Icons.cancel;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }
}
