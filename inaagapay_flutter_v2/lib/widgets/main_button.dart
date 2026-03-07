import 'package:flutter/material.dart';
import '../theme/app_colors.dart';


class MainButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;


  /// Icon control
  final bool showIcons;
  final IconData? leadingIcon;


  /// Optional color overrides
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;


  const MainButton({
    super.key,
    required this.label,
    this.onPressed,
    this.showIcons = false,
    this.leadingIcon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });


  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        backgroundColor ?? AppColors.brandPrimary;
    final Color fgColor =
        textColor ?? AppColors.textOnColor;
    final Color iconFgColor =
        iconColor ?? fgColor;


    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor:
              MaterialStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(MaterialState.disabled)) {
                return bgColor.withOpacity(0.6);
              }
              return bgColor;
            },
          ),
          elevation:
              MaterialStateProperty.resolveWith<double>(
            (states) {
              if (states.contains(MaterialState.disabled)) {
                return 0;
              }
              return 4;
            },
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcons && leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 20,
                color: iconFgColor,
              ),
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
          ],
        ),
      ),
    );
  }
}



