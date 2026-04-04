// lib/widgets/calculation_dropdown.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/due_date_basis.dart';

class CalculationDropdown extends StatelessWidget {
  final DueDateBasis value;
  final ValueChanged<DueDateBasis> onChanged;

  const CalculationDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          const Icon(Icons.calculate, color: AppColors.brandAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DueDateBasis>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: DueDateBasis.values.map((basis) {
                  return DropdownMenuItem(
                    value: basis,
                    child: Text(basis.label),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) onChanged(newValue);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}