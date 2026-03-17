import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ImportantButton extends StatefulWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback onPressed;

  const ImportantButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
  });

  @override
  State<ImportantButton> createState() => _ImportantButtonState();
}

class _ImportantButtonState extends State<ImportantButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: _isPressed ? Alignment.centerRight : Alignment.centerLeft,
          end: _isPressed ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            AppColors.brandPrimary,
            AppColors.brandPrimary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withOpacity(
              _isPressed ? 0.25 : 0.4,
            ),
            blurRadius: _isPressed ? 10 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white.withOpacity(0.25),
          highlightColor: Colors.transparent,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(
                    widget.leadingIcon,
                    size: 20,
                    color: AppColors.textOnColor,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: AppColors.textOnColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
