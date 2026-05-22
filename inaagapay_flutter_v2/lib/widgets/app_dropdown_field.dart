// lib/widgets/app_dropdown_field.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppDropdownField<T extends Object> extends StatefulWidget {
  final String hintText;
  final IconData? leadingIcon;
  final T? value;
  final List<T> options;
  final String Function(T) displayStringForOption;
  final ValueChanged<T> onSelected;
  final String? errorText;

  const AppDropdownField({
    super.key,
    required this.hintText,
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
    this.leadingIcon,
    this.value,
    this.errorText,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T extends Object> extends State<AppDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == null ? '' : widget.displayStringForOption(widget.value!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value == null ? '' : widget.displayStringForOption(widget.value!);
    }
  }

  Iterable<T> _filterOptions(String query) {
    final lower = query.toLowerCase();
    return widget.options.where((option) {
      return widget.displayStringForOption(option).toLowerCase().contains(lower);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.borderPrimary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, color: AppColors.brandAccent),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: widget.value,
                    hint: Text(
                      widget.hintText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    focusColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 16,
                    ),
                    onChanged: (T? newValue) {
                      if (newValue != null) {
                        widget.onSelected(newValue);
                      }
                    },
                    items: widget.options.map((T option) {
                      return DropdownMenuItem<T>(
                        value: option,
                        child: Text(widget.displayStringForOption(option)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}
