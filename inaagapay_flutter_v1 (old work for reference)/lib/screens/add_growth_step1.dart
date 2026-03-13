import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/secondary_header.dart';
import '../widgets/app_input_field.dart';
import '../widgets/status_indicator.dart';
import '../widgets/main_button.dart';
import '../widgets/page_title.dart';
import '../widgets/dialog_box.dart';
import '../widgets/confirmation_dialog_box.dart';
import '../widgets/validation_message.dart';

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

  /// --------------------------------------------------
  /// BMI CALCULATION
  /// --------------------------------------------------
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
    // Child BMI categories (simplified - you should use WHO charts for accuracy)
    if (bmi < 14) return StatusIndicatorType.underweight;
    if (bmi < 18) return StatusIndicatorType.normal;
    if (bmi < 22) return StatusIndicatorType.overweight;
    return StatusIndicatorType.obese;
  }

  /// --------------------------------------------------
  /// FORM VALIDATION
  /// --------------------------------------------------
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

  /// --------------------------------------------------
  /// SAVE GROWTH RECORD TO API
  /// --------------------------------------------------
  Future<bool> _saveGrowthRecord() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      _showErrorDialog('Authentication error. Please log in again.');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('https://inaagapay.alwaysdata.net/api/midwife/add_child_growth.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'child_id': widget.childId,
          'height': double.tryParse(_heightController.text) ?? 0.0,
          'weight': double.tryParse(_weightController.text) ?? 0.0,
          'bmi': double.tryParse(_bmiController.text) ?? 0.0,
          'remarks': _remarksController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return true;
        } else {
          _showErrorDialog(decoded['message'] ?? 'Failed to save growth record');
          return false;
        }
      } else {
        _showErrorDialog('Server error (${response.statusCode}). Please try again.');
        return false;
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
      return false;
    }
  }

  /// Helper method to show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return DialogBox(
          type: DialogType.error,
          title: 'Save Failed',
          subtitle: message,
          buttonText: 'OK',
          onPressed: () => Navigator.pop(context),
        );
      },
    );
  }

  /// --------------------------------------------------
  /// SUBMIT FLOW - SIMPLIFIED VERSION
  /// --------------------------------------------------
  void _submit() async {
    // First show confirmation dialog
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

    // If user didn't confirm, stop here
    if (confirm != true) return;

    // Start loading
    setState(() => _isLoading = true);

    try {
      // Save the record
      final success = await _saveGrowthRecord();
      
      setState(() => _isLoading = false);

      if (success) {
        // SUCCESS: Immediately pop back to profile page with true value
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
      // Error is already shown in _saveGrowthRecord
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      /// 🔝 SECONDARY HEADER
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
                    /// 🧬 SECTION TITLE
                    Center(
                      child: PageTitle(
                        title: 'Growth Details',
                        leadingIcon: Icons.edit_rounded,
                        trailingIcon: Icons.check_circle,
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// 📏 HEIGHT (NUMBERS ONLY)
                    TextFormField(
                      controller: _heightController,
                      style: const TextStyle(
                        color: AppColors.textPrimary, // Dark text color
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Height (cm)',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary, // Lighter hint text
                        ),
                        prefixIcon: const Icon(Icons.height, color: AppColors.brandPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _recalculateBMI(),
                    ),

                    const SizedBox(height: 16),

                    /// ⚖️ WEIGHT (NUMBERS ONLY)
                    TextFormField(
                      controller: _weightController,
                      style: const TextStyle(
                        color: AppColors.textPrimary, // Dark text color
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Weight (kg)',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary, // Lighter hint text
                        ),
                        prefixIcon: const Icon(Icons.monitor_weight, color: AppColors.brandPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _recalculateBMI(),
                    ),

                    const SizedBox(height: 16),

                    /// 🧮 BMI (AUTO-CALCULATED)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate,
                            color: AppColors.brandAccent,
                          ),
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

                    /// 📝 REMARKS (OPTIONAL)
                    TextFormField(
                      controller: _remarksController,
                      style: const TextStyle(
                        color: AppColors.textPrimary, // Dark text color
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Remarks (optional)',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary, // Lighter hint text
                        ),
                        prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.brandPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    /// ⚠️ VALIDATION MESSAGE
                    if (_validationMessage != null) ...[
                      const SizedBox(height: 12),
                      ValidationMessage(
                        message: _validationMessage!,
                        type: ValidationType.error,
                      ),
                    ],

                    const SizedBox(height: 28),

                    /// ➕ SUBMIT
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