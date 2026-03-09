import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/headline.dart';
import '../widgets/main_button.dart';
import '../widgets/info_row.dart';
import '../screens/due_date_setter.dart';

class CongratsPage extends StatelessWidget {
  final DueDateMode mode;

  // 🔧 Static placeholders (backend later)
  final int weeksPregnant = 12;
  final int monthsLeft = 6;
  final String dueDate = 'October 15, 2026';

  const CongratsPage({super.key, required this.mode});

  bool get isPregnant => mode == DueDateMode.pregnant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // 🔽 Scrollable content (prevents overflow)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),

                      // 🖼 Illustration
                      Image.asset(
                        'assets/images/pregnant1.png',
                        height: MediaQuery.of(context).size.height * 0.30,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 28),

                      // 🎉 Headline
                      Center(
                        child: Headline(
                          text: isPregnant
                              ? 'Congratulations, Nanay!'
                              : 'Congratulations!',
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 🧠 Supporting subtitle
                      if (!isPregnant)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "You're now supporting someone through their pregnancy journey!",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // 🧾 Section label (centered correctly)
                      const Center(
                        child: Text(
                          'This means...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 📋 Info rows
                      InfoRow(
                        icon: Icons.calendar_today,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: isPregnant ? 'You are ' : 'They are ',
                            ),
                            TextSpan(
                              text: '$weeksPregnant weeks',
                              style: const TextStyle(
                                color: AppColors.brandAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' pregnant!'),
                          ],
                        ),
                      ),

                      InfoRow(
                        icon: Icons.child_care,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: isPregnant
                                  ? 'Your baby is expected on '
                                  : 'Their baby is expected on ',
                            ),
                            TextSpan(
                              text: dueDate,
                              style: const TextStyle(
                                color: AppColors.brandAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: '!'),
                          ],
                        ),
                      ),

                      InfoRow(
                        icon: Icons.hourglass_bottom,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: isPregnant
                                  ? "You're just "
                                  : "They're just ",
                            ),
                            TextSpan(
                              text: '$monthsLeft months',
                              style: const TextStyle(
                                color: AppColors.brandAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' away from meeting!'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 🚀 CTA (role-aware + routed)
              MainButton(
                label: isPregnant
                    ? "Let's begin your journey!"
                    : "Let's begin the journey!",
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/mother-dashboard',
                    (route) => false,
                  );
                },
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
