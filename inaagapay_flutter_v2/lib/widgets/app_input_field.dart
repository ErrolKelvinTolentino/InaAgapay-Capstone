// lib/widgets/app_input_field.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppInputField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final bool readOnly;
  final bool isRequired;
  final TextInputType keyboardType;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;
  final Function(String)? onChanged;

  const AppInputField({
    super.key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.readOnly = false,
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingTap,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            const SizedBox(width: 16),
            Icon(
              leadingIcon,
              color: AppColors.brandAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              readOnly: readOnly,
              keyboardType: keyboardType,
              onTap: onTap,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText + (isRequired ? ' *' : ''),
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            IconButton(
              icon: Icon(
                trailingIcon,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: onTrailingTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}