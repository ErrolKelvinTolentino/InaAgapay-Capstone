import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DialogType { success, error, info, warning }

class DialogBox extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback onPressed;
  final DialogType type;

  const DialogBox({
    super.key,
    required this.title,
    this.content = '',
    required this.buttonText,
    required this.onPressed,
    this.type = DialogType.info,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getButtonColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case DialogType.success:
        iconData = Icons.check_circle;
        iconColor = AppColors.success;
        break;
      case DialogType.error:
        iconData = Icons.error;
        iconColor = AppColors.error;
        break;
      case DialogType.warning:
        iconData = Icons.warning;
        iconColor = AppColors.warning;
        break;
      case DialogType.info:
        iconData = Icons.info;
        iconColor = AppColors.info;
        break;
    }

    return Icon(
      iconData,
      size: 48,
      color: iconColor,
    );
  }

  Color _getButtonColor() {
    switch (type) {
      case DialogType.success:
        return AppColors.success;
      case DialogType.error:
        return AppColors.error;
      case DialogType.warning:
        return AppColors.warning;
      case DialogType.info:
        return AppColors.brandAccent;
    }
  }
}