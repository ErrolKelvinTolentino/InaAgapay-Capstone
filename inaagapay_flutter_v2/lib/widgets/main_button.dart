// lib/widgets/main_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool showIcons;
  final IconData? leadingIcon;
  final IconData? rightIcon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const MainButton({
    super.key,
    required this.label,
    this.onPressed,
    this.showIcons = false,
    this.leadingIcon,
    this.rightIcon,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = backgroundColor ?? AppColors.brandPrimary;
    final Color fgColor = textColor ?? AppColors.textOnColor;
    final Color iconFgColor = iconColor ?? fgColor;

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor ?? AppColors.brandAccent,
            side: BorderSide(color: textColor ?? AppColors.brandAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: _buildChild(fgColor, iconFgColor),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return bgColor.withValues(alpha: 0.6);
            }
            return bgColor;
          }),
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            return states.contains(WidgetState.disabled) ? 0 : 4;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        child: _buildChild(fgColor, iconFgColor),
      ),
    );
  }

  Widget _buildChild(Color fgColor, Color iconFgColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIcons && leadingIcon != null) ...[
          Icon(leadingIcon, size: 20, color: iconFgColor),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
        if (showIcons && rightIcon != null) ...[
          const SizedBox(width: 10),
          Icon(rightIcon, size: 20, color: iconFgColor),
        ],
      ],
    );
  }
}
