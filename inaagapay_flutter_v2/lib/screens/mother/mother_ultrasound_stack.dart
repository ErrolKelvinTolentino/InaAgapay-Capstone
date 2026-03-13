// lib/screens/mother/mother_ultrasound_stack.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MotherUltrasoundStack extends StatelessWidget {
  const MotherUltrasoundStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Ultrasound Records',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 64,
              color: AppColors.brandPrimary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ultrasound Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This feature is coming soon',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}