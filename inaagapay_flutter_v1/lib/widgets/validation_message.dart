import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ValidationType {
  error,
  success,
  info,
}

class ValidationMessage extends StatelessWidget {
  final String message;
  final ValidationType type;
  final IconData? icon;

  const ValidationMessage({
    super.key,
    required this.message,
    this.type = ValidationType.error,
    this.icon,
  });

  Color get _color {
    switch (type) {
      case ValidationType.success:
        return AppColors.success;
      case ValidationType.info:
        return AppColors.textSecondary;
      default:
        return AppColors.error;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case ValidationType.success:
        return Icons.check_circle;
      case ValidationType.info:
        return Icons.info_outline;
      default:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon ?? _defaultIcon,
          color: _color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: _color,
            ),
          ),
        ),
      ],
    );
  }
}
