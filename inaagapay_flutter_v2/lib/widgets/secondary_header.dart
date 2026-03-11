// lib/widgets/secondary_header.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SecondaryHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const SecondaryHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: onBack,
              color: AppColors.textPrimary,
            ),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}