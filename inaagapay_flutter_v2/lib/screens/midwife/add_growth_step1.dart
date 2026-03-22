import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/status_indicator.dart';
import '../../widgets/main_button.dart';
import '../../widgets/page_title.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/confirmation_dialog_box.dart';
import '../../widgets/validation_message.dart';

class AddGrowthStep1 extends StatefulWidget {
  final int childId;

  const AddGrowthStep1({
    super.key,
    required this.childId,
  });

  @override
  State<AddGrowthStep1> createState() => _AddGrowthStep1State();
}

class _AddGrowthStep1State extends State<AddGrowthStep1> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  StatusIndicatorType _bmiStatus = StatusIndicatorType.normal;
  bool _isFormValid = false;
  String? _validationMessage;
  bool _isLoading = false;

  void _recalculateBMI() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);

    if (heightCm == null || weightKg == null || heightCm == 0) {
      setState(() {
        _bmiController.text = '';
        _isFormValid = false;
        _validationMessage = 'Please enter valid height and weight.';
        _bmiStatus = StatusIndicatorType.normal;
      });
      return;
    }

    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);

    setState(() {
      _bmiController.text = bmi.toStringAsFixed(1);
      _bmiStatus = _getBmiStatus(bmi);
      _validateForm();
    });
  }

  StatusIndicatorType _getBmiStatus(double bmi) {
    if (bmi < 14) return StatusIndicatorType.underweight;
    if (bmi < 18) return StatusIndicatorType.normal;
    if (bmi < 22) return StatusIndicatorType.overweight;
    return StatusIndicatorType.obese;
  }

  void _validateForm() {
    if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
      setState(() {
        _isFormValid = false;
        _validationMessage = 'Height and weight are required.';
      });
      return;
    }

    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height == null || weight == null) {
      setState(() {
        _isFormValid = false;
        _validationMessage = 'Please enter valid numbers for height and weight.';
      });
      return;
    }

    if (height <= 0 || weight <= 0) {
      setState(() {
        _isFormValid = false;
        _validationMessage = 'Height and weight must be greater than zero.';
      });
      return;
    }

    setState(() {
      _isFormValid = true;
      _validationMessage = null;
    });
  }

  Future<bool> _saveGrowthRecord() async {
    try {
      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);
      final bmi = double.parse(_bmiController.text);

      await Supabase.instance.client
          .from('child_details')
          .insert({
            'child_id': widget.childId,
            'child_height': height,
            'child_weight': weight,
            'bmi': bmi,
            'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return DialogBox(
          type: DialogType.error,
          title: 'Save Failed',
          content: message,
          buttonText: 'OK',
          onPressed: () => Navigator.pop(context),
        );
      },
    );
  }

  void _submit() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ConfirmationDialogBox(
          title: 'Confirm Growth Record',
          subtitle: 'Please make sure the details are correct. Growth records cannot be edited once added.',
          confirmText: 'Confirm',
          cancelText: 'Cancel',
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await _saveGrowthRecord();
      
      setState(() => _isLoading = false);

      if (success && mounted) {
        Navigator.pop(context, true);
      } else {
        _showErrorDialog('Failed to save growth record. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Add Growth Record',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: PageTitle(
                        title: 'Growth Details',
                        leadingIcon: Icons.edit_rounded,
                        trailingIcon: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppInputField(
                      hintText: 'Height (cm)',
                      controller: _heightController,
                      leadingIcon: Icons.height,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _recalculateBMI(),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    AppInputField(
                      hintText: 'Weight (kg)',
                      controller: _weightController,
                      leadingIcon: Icons.monitor_weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _recalculateBMI(),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate, color: AppColors.brandAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _bmiController.text.isEmpty
                                  ? 'BMI: ---'
                                  : 'BMI: ${_bmiController.text}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          StatusIndicator(status: _bmiStatus),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: TextField(
                        controller: _remarksController,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Remarks (optional)',
                          border: InputBorder.none,
                          icon: Icon(Icons.notes_rounded, color: AppColors.brandPrimary),
                        ),
                      ),
                    ),

                    if (_validationMessage != null) ...[
                      const SizedBox(height: 12),
                      ValidationMessage(
                        message: _validationMessage!,
                        type: ValidationType.error,
                      ),
                    ],

                    const SizedBox(height: 28),

                    MainButton(
                      label: 'Add Growth Record',
                      onPressed: _isFormValid ? _submit : null,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}