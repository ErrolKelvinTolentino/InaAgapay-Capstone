import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/password_strength.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      switch (strength) {
        case PasswordStrength.weak:
          return AppColors.error;
        case PasswordStrength.medium:
          return AppColors.warning;
        case PasswordStrength.strong:
          return AppColors.success;
      }
    }

    String getText() {
      switch (strength) {
        case PasswordStrength.weak:
          return 'Weak';
        case PasswordStrength.medium:
          return 'Medium';
        case PasswordStrength.strong:
          return 'Strong';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        getText(),
        style: TextStyle(
          color: getColor(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}