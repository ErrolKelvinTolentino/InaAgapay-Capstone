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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: AppColors.textPrimary,
              onPressed: onBack,
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onBack != null) const SizedBox(width: 48), // Balance the header
        ],
      ),
    );
  }
}