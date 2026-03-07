import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PasswordConstraints extends StatelessWidget {
  final String password;

  const PasswordConstraints({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConstraint(
          'At least 8 characters',
          password.length >= 8,
        ),
        const SizedBox(height: 4),
        _buildConstraint(
          'Contains a number',
          RegExp(r'\d').hasMatch(password),
        ),
        const SizedBox(height: 4),
        _buildConstraint(
          'Contains uppercase letter',
          RegExp(r'[A-Z]').hasMatch(password),
        ),
        const SizedBox(height: 4),
        _buildConstraint(
          'Contains lowercase letter',
          RegExp(r'[a-z]').hasMatch(password),
        ),
      ],
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
            fontSize: 12,
            color: isMet ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}