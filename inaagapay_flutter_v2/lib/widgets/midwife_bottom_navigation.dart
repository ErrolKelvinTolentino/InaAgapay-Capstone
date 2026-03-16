// lib/widgets/midwife_bottom_navigation.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MidwifeBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const MidwifeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70, // Match mother's bottom navigation height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_filled,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          _NavItem(
            icon: Icons.pregnant_woman_rounded,
            label: 'Mothers',
            isActive: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          _NavItem(
            icon: Icons.child_care_outlined,
            label: 'Children',
            isActive: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          _NavItem(
            icon: Icons.calendar_today_rounded,
            label: 'Schedules',
            isActive: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        isActive ? AppColors.brandPrimary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}