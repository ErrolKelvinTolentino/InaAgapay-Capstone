// lib/widgets/password_constraints.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PasswordConstraints extends StatelessWidget {
  final String password;

  const PasswordConstraints({super.key, required this.password});

  bool get hasMinLength => password.length >= 8;
  bool get hasNumber => RegExp(r'\d').hasMatch(password);
  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(password);
  bool get hasLowercase => RegExp(r'[a-z]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConstraint('At least 8 characters', hasMinLength),
          const SizedBox(height: 8),
          _buildConstraint('Contains a number', hasNumber),
          const SizedBox(height: 8),
          _buildConstraint('Contains uppercase letter', hasUppercase),
          const SizedBox(height: 8),
          _buildConstraint('Contains lowercase letter', hasLowercase),
        ],
      ),
    );
  }

  Widget _buildConstraint(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isMet ? AppColors.success : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isMet ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}