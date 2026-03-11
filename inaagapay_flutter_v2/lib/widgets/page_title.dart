// lib/widgets/page_title.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PageTitle extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const PageTitle({
    super.key,
    required this.title,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              leadingIcon,
              color: AppColors.brandAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailingIcon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              trailingIcon,
              color: AppColors.success,
              size: 18,
            ),
          ),
      ],
    );
  }
}