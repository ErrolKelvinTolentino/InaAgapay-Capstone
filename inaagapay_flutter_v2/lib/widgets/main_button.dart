// lib/widgets/main_button.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool showIcons;
  final IconData? leftIcon;
  final IconData? rightIcon;

  const MainButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showIcons = true,
    this.leftIcon,
    this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcons && leftIcon != null) ...[
              Icon(leftIcon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showIcons && rightIcon != null) ...[
              const SizedBox(width: 8),
              Icon(rightIcon, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}