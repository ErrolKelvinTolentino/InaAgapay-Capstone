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
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                color: AppColors.brandPrimary,
                onPressed: onBack,
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
