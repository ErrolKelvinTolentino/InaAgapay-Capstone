import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FloatingAddChildButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingAddChildButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }
}