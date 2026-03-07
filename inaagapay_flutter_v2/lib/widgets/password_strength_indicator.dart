import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PasswordStrength {
  weak,
  medium,
  strong,
}

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
  });

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
      case PasswordStrength.weak:
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
          Icon(
            icon,
            size: 16,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _StrengthRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final IconData icon;

  const _StrengthRow({
    required this.label,
    required this.isActive,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
