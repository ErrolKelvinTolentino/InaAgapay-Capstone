import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ValidationType { error, success, info }

class ValidationMessage extends StatelessWidget {
  final String message;
  final ValidationType type;

  const ValidationMessage({
    super.key,
    required this.message,
    this.type = ValidationType.error,
  });

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      switch (type) {
        case ValidationType.error:
          return AppColors.error;
        case ValidationType.success:
          return AppColors.success;
        case ValidationType.info:
          return AppColors.info;
      }
    }

    IconData getIcon() {
      switch (type) {
        case ValidationType.error:
          return Icons.error_outline;
        case ValidationType.success:
          return Icons.check_circle_outline;
        case ValidationType.info:
          return Icons.info_outline;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            getIcon(),
            size: 16,
            color: getColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: getColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}