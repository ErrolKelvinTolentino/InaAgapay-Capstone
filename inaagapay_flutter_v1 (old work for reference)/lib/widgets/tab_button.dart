import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const TabButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandPrimary
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.brandPrimary,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color:
                        AppColors.brandPrimary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive
                ? Colors.white
                : AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}
