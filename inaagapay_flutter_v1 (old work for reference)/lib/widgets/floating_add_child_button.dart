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
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.add,
        size: 28,
        color: Colors.white,
      ),
    );
  }
}
