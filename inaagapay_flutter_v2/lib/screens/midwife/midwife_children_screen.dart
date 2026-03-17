// lib/screens/midwife/midwife_children_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MidwifeChildrenScreen extends StatelessWidget {
  const MidwifeChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      child: const SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.child_care_outlined,
                size: 72,
                color: AppColors.brandPrimary,
              ),
              SizedBox(height: 16),
              Text(
                'Children List',
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