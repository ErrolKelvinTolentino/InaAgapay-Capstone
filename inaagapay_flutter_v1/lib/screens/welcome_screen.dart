import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/main_button.dart';
import '../widgets/headline.dart';
import 'due_date_setter.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== LOGO =====
              Image.asset('assets/images/logo.png', height: 120),

              const SizedBox(height: 24),

              // ===== HEADLINE =====
              const Headline(text: 'Welcome, [First Name]!'),

              const SizedBox(height: 6),

              const Text(
                'What brings you here today?',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),

              const SizedBox(height: 32),

              // ===== I’M PREGNANT =====
              MainButton(
                label: "I'm Pregnant",
                showIcons: true,
                leadingIcon: Icons.pregnant_woman,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DueDateSetterScreen(mode: DueDateMode.pregnant),
                    ),
                  );
                },
              ),

              const SizedBox(height: 6),

              const Text(
                "First-time or experienced, we’re here for you!",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 20),

              // ===== SUPPORTING SOMEONE =====
              MainButton(
                label: "I'm Supporting Someone",
                showIcons: true, // ✅ REQUIRED
                leadingIcon: Icons.favorite,
                backgroundColor: Colors.white,
                textColor: AppColors.textSecondary,
                iconColor: AppColors.textSecondary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DueDateSetterScreen(mode: DueDateMode.supporting),
                    ),
                  );
                },
              ),

              const SizedBox(height: 6),

              const Text(
                "Partner, family member, or friend",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 20),

              // ===== LEARN & EXPLORE =====
              MainButton(
                label: 'Learn and Explore',
                showIcons: true, // ✅ REQUIRED
                leadingIcon: Icons.menu_book,
                backgroundColor: Colors.white,
                textColor: AppColors.textSecondary,
                iconColor: AppColors.textSecondary,
                onPressed: () {
                  // TODO: navigate to explore flow
                },
              ),

              const SizedBox(height: 6),

              const Text(
                "For educational purposes",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              const Text(
                "You can change this anytime in your settings",
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
