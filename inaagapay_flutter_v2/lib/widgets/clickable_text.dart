// lib/widgets/clickable_text.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ClickableText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;

  const ClickableText({
    super.key,
    required this.text,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.brandAccent,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color ?? AppColors.brandAccent,
        ),
      ),
    );
  }
}