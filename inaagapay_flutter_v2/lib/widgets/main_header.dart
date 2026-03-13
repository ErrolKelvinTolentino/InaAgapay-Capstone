// lib/widgets/main_header.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onNotificationTap;
  final ImageProvider? avatarImage;
  final VoidCallback? onViewProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final VoidCallback? onLogout;

  const MainHeader({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.avatarImage,
    this.onViewProfile,
    this.onSettings,
    this.onHelp,
    this.onLogout,
  });

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.person_outline,
              label: 'View Profile',
              onTap: () {
                Navigator.pop(ctx);
                onViewProfile?.call();
              },
            ),
            _buildMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(ctx);
                onSettings?.call();
              },
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              label: 'Help',
              onTap: () {
                Navigator.pop(ctx);
                onHelp?.call();
              },
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout_rounded,
              label: 'Log out',
              isDanger: true,
              onTap: () {
                Navigator.pop(ctx);
                onLogout?.call();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppColors.error : AppColors.textPrimary;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            /// LOGO
            Image.asset(
              'assets/images/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.favorite, color: AppColors.brandPrimary, size: 30),
            ),

            const SizedBox(width: 12),

            /// TITLE
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.brandText,
                letterSpacing: 0.4,
              ),
            ),

            const Spacer(),

            /// NOTIFICATIONS
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onNotificationTap,
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(width: 14),

            /// AVATAR
            GestureDetector(
              onTap: () => _showProfileMenu(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPrimary,
                  image: avatarImage != null
                      ? DecorationImage(
                          image: avatarImage!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarImage == null
                    ? const Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}