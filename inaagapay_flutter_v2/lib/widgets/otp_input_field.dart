import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OtpInputField extends StatefulWidget {
  final Function(String) onChanged;
  final bool showError;

  const OtpInputField({
    super.key,
    required this.onChanged,
    this.showError = false,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> controllers;
  late List<FocusNode> focusNodes;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(6, (_) => TextEditingController());
    focusNodes = List.generate(6, (_) => FocusNode());

    for (int i = 0; i < 6; i++) {
      controllers[i].addListener(() => _onTextChanged(i));
    }
  }

  void _onTextChanged(int index) {
    if (controllers[index].text.length == 1) {
      if (index < 5) {
        focusNodes[index + 1].requestFocus();
      } else {
        focusNodes[index].unfocus();
      }
    } else if (controllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Combine all digits
    String otp = '';
    for (var controller in controllers) {
      otp += controller.text;
    }
    widget.onChanged(otp);
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.showError
                  ? AppColors.error
                  : AppColors.textSecondary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            onChanged: (_) => _onTextChanged(index),
          ),
        );
      }),
    );
  }
}