// lib/screens/mother/mother_journal_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MotherJournalScreen extends StatelessWidget {
  const MotherJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Journal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.brandAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 72,
                color: AppColors.brandAccent,
              ),
              SizedBox(height: 16),
              Text(
                'Pregnancy Journal',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}