import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/language_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the language for pregnancy guidance and information.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<AppLanguage>(
              valueListenable: LanguageService.selectedLanguage,
              builder: (context, language, child) {
                return Column(
                  children: AppLanguage.values.map((option) {
                    return RadioListTile<AppLanguage>(
                      activeColor: AppColors.brandPrimary,
                      value: option,
                      groupValue: language,
                      onChanged: (value) {
                        if (value != null) {
                          LanguageService.selectedLanguage.value = value;
                        }
                      },
                      title: Text(
                        LanguageService.displayName(option),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        option == AppLanguage.filipino
                            ? 'Gagamitin ang Filipino sa pregnancy information.'
                            : 'Use English for pregnancy information.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: const Text(
                'The selected language will update pregnancy guidance on the home and detail screens.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
