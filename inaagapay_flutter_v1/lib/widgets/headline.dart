import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Headline extends StatelessWidget {
  final String text;
  final TextAlign textAlign; // 👈 ADD

  const Headline({
    super.key,
    required this.text,
    this.textAlign = TextAlign.center, // 👈 DEFAULT
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.brandPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}
