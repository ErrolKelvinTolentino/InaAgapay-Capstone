import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onNotificationTap;
  final ImageProvider? avatarImage;
  final VoidCallback? onAvatarTap;
  final Key? avatarKey;

  const MainHeader({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.avatarImage,
    this.onAvatarTap,
    this.avatarKey,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60, // 👈 shorter like prototype
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
            // 🔹 Logo
            Image.asset(
              'assets/images/logo.png',
              height: 40, // 👈 matches avatar
            ),

            const SizedBox(width: 12),

            // 🔹 Page title
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 18, // 👈 slightly tighter
                fontWeight: FontWeight.w700,
                color: AppColors.brandText,
                letterSpacing: 0.4,
              ),
            ),

            const Spacer(),

            // 🔔 Notification bell
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

            // 👤 Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                key: avatarKey,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPrimary,
                  image: avatarImage != null
                      ? DecorationImage(image: avatarImage!, fit: BoxFit.cover)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
