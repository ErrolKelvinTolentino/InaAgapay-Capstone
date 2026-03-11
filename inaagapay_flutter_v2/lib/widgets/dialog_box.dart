// lib/widgets/dialog_box.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DialogType { success, error, warning, info }

class DialogBox extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final DialogType type;
  final VoidCallback onPressed;

  const DialogBox({
    super.key,
    required this.title,
    required this.content,
    required this.buttonText,
    required this.type,
    required this.onPressed,
  });

  Color get _getColor {
    switch (type) {
      case DialogType.success:
        return AppColors.success;
      case DialogType.error:
        return AppColors.error;
      case DialogType.warning:
        return AppColors.warning;
      case DialogType.info:
        return AppColors.info;
    }
  }

  IconData get _getIcon {
    switch (type) {
      case DialogType.success:
        return Icons.check_circle;
      case DialogType.error:
        return Icons.error;
      case DialogType.warning:
        return Icons.warning;
      case DialogType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(_getIcon, color: _getColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: _getColor,
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }
}