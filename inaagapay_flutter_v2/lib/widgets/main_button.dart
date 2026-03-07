import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool showIcons;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;

  const MainButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showIcons = true,
    this.leftIcon,
    this.rightIcon,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    print('MainButton: "$label" - enabled: ${onPressed != null}');
    
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppColors.brandAccent,
          side: BorderSide(color: textColor ?? AppColors.brandAccent),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _buildChild(),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null 
            ? Colors.grey.shade300 
            : (backgroundColor ?? AppColors.brandAccent),
        foregroundColor: onPressed == null
            ? Colors.grey.shade600
            : (textColor ?? Colors.white),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: onPressed == null ? 0 : 2,
      ),
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (!showIcons) {
      return Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leftIcon != null) ...[
          Icon(leftIcon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (rightIcon != null) ...[
          const SizedBox(width: 8),
          Icon(rightIcon, size: 20),
        ],
      ],
    );
  }
}