import 'package:flutter/material.dart';
import '../theme/app_colors.dart';


class MainBottomNavigation extends StatelessWidget {
  final int currentIndex;


  const MainBottomNavigation({
    super.key,
    required this.currentIndex,
  });


  void _handleNavigation(BuildContext context, int index) {
    // Prevent reloading the same page
    if (index == currentIndex) return;


    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(
          context,
          '/mother-dashboard',
        );
        break;


      case 2:
        Navigator.pushReplacementNamed(
          context,
          '/mother-children',
        );
        break;


      // 🚧 Journal & Records (routes later)
      case 1:
      break;
      case 3:
        Navigator.pushReplacementNamed(
          context,
          '/mother-records',
        );
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
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
              onTap: () => _handleNavigation(context, 0),
            ),
            _NavItem(
              icon: Icons.menu_book_outlined,
              label: 'Journal',
              isActive: currentIndex == 1,
              onTap: () => _handleNavigation(context, 1),
            ),
            _NavItem(
              icon: Icons.child_care_outlined,
              label: 'Children',
              isActive: currentIndex == 2,
              onTap: () => _handleNavigation(context, 2),
            ),
            _NavItem(
              icon: Icons.description_outlined,
              label: 'Records',
              isActive: currentIndex == 3,
              onTap: () => _handleNavigation(context, 3),
            ),
          ],
        ),
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
          const SizedBox(height: 6),


          if (isActive)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}



