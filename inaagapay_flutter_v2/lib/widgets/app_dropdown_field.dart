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

    return RawAutocomplete<T>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return widget.options;
        }
        return _filterOptions(textEditingValue.text);
      },
      displayStringForOption: widget.displayStringForOption,
      onSelected: (T selected) {
        widget.onSelected(selected);
        _controller.text = widget.displayStringForOption(selected);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldTextEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        if (fieldTextEditingController.text != _controller.text) {
          fieldTextEditingController.text = _controller.text;
          fieldTextEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: fieldTextEditingController.text.length),
          );
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: Column(
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
                      child: TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: widget.hintText,
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 16,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
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
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<T> onSelected,
        Iterable<T> options,
      ) {
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 64),
          child: Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 200),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options.map((T option) {
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(
                        widget.displayStringForOption(option),
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
