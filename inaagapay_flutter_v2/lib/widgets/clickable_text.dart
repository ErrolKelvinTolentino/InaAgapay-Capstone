import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ClickableText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool underline;

  const ClickableText({
    super.key,
    required this.text,
    required this.onTap,
    this.underline = false,
  });

  @override
  State<ClickableText> createState() => _ClickableTextState();
}

class _ClickableTextState extends State<ClickableText> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color textColor() {
      if (_pressed) return AppColors.brandAccent; // darker on press
      if (_hovered) return AppColors.brandPrimary.withOpacity(0.85);
      return AppColors.brandPrimary;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0, // subtle press feedback
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor(),
              decoration: widget.underline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}
