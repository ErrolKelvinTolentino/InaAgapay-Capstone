// lib/widgets/headline.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Headline extends StatelessWidget {
  final String text;

  const Headline({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }
}