import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ClickableText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;

  const ClickableText({
    super.key,
    required this.text,
    required this.onTap,
    this.color,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.brandAccent,
          fontSize: fontSize,
          fontWeight: fontWeight,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}