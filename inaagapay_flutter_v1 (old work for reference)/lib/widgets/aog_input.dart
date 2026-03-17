import 'package:flutter/material.dart';
import '../widgets/app_input_field.dart';

class AogInput extends StatelessWidget {
  final TextEditingController weeksController;
  final TextEditingController daysController;

  const AogInput({
    super.key,
    required this.weeksController,
    required this.daysController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppInputField(
          hintText: 'Weeks',
          controller: weeksController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Days',
          controller: daysController,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
