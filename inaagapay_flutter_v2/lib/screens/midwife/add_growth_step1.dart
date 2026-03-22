// lib/screens/midwife/add_growth_step1.dart

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
import '../../services/growth_calculator.dart';

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

  Map<String, dynamic>? _childData;
  bool _loading = true;
  int _ageInWeeks = 0;
  String _gender = '';
  
  double? _weightZScore;
  double? _heightZScore;
  double? _bmiZScore;
  
  StatusIndicatorType _bmiStatus = StatusIndicatorType.normal;
  
  bool _isFormValid = false;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadChildData();
    _heightController.addListener(_updateBMI);
    _weightController.addListener(_updateBMI);
  }

  Future<void> _loadChildData() async {
    try {
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            sex,
            mother:mother_id (
              birth_details (
                birthdate
              )
            )
          ''')
          .eq('child_id', widget.childId)
          .single();

      final mother = childResponse['mother'] as Map<String, dynamic>?;
      final birthDetailsList = mother?['birth_details'] as List?;
      final birthDetails = birthDetailsList?.first as Map<String, dynamic>?;
      final birthdate = birthDetails?['birthdate']?.toString();
      
      if (birthdate != null) {
        final birth = DateTime.parse(birthdate);
        final now = DateTime.now();
        _ageInWeeks = (now.difference(birth).inDays / 7).floor();
      }
      
      _gender = childResponse['sex']?.toString().toLowerCase() ?? '';
      
      setState(() {
        _childData = childResponse;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error loading child data: $e');
    }
  }

  void _updateBMI() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);

    if (heightCm == null || weightKg == null || heightCm == 0) {
      setState(() {
        _bmiController.text = '';
        _bmiZScore = null;
        _bmiStatus = StatusIndicatorType.normal;
        _validateForm();
      });
      return;
    }

    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);
    
    if (_ageInWeeks > 0 && _gender.isNotEmpty) {
      _bmiZScore = GrowthCalculator.calculateBMIZScore(bmi, _ageInWeeks, _gender);
      _bmiStatus = _getBMICategoryFromZScore(_bmiZScore!);
    }

    setState(() {
      _bmiController.text = bmi.toStringAsFixed(1);
      _validateForm();
    });
  }

  void _calculateZScores() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);
    final double? bmi = double.tryParse(_bmiController.text);

    if (heightCm != null && _ageInWeeks > 0 && _gender.isNotEmpty) {
      _heightZScore = GrowthCalculator.calculateHeightZScore(heightCm, _ageInWeeks, _gender);
    }
    
    if (weightKg != null && _ageInWeeks > 0 && _gender.isNotEmpty) {
      _weightZScore = GrowthCalculator.calculateWeightZScore(weightKg, _ageInWeeks, _gender);
    }
    
    if (bmi != null && _ageInWeeks > 0 && _gender.isNotEmpty) {
      _bmiZScore = GrowthCalculator.calculateBMIZScore(bmi, _ageInWeeks, _gender);
      _bmiStatus = _getBMICategoryFromZScore(_bmiZScore!);
    }
  }

  StatusIndicatorType _getBMICategoryFromZScore(double zScore) {
    if (zScore < -1) return StatusIndicatorType.underweight;
    if (zScore <= 1) return StatusIndicatorType.normal;
    if (zScore <= 2) return StatusIndicatorType.overweight;
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
      _calculateZScores();
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
      debugPrint('Error saving growth record: $e');
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

    setState(() => _isSaving = true);

    try {
      final success = await _saveGrowthRecord();
      
      setState(() => _isSaving = false);

      if (success && mounted) {
        Navigator.pop(context, true);
      } else {
        _showErrorDialog('Failed to save growth record. Please try again.');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorDialog('Unexpected error: $e');
    }
  }

  String _formatZScore(double? zScore) {
    if (zScore == null) return 'N/A';
    if (zScore > 3) return '> +3';
    if (zScore < -3) return '< -3';
    return zScore.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.brandPrimary,
          ),
        ),
      );
    }

    final childName = '${_childData?['first_name'] ?? ''} ${_childData?['last_name'] ?? ''}'.trim();
    final ageText = '$_ageInWeeks weeks old';

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
        child: _isSaving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.brandPrimary),
                    SizedBox(height: 20),
                    Text(
                      'Saving growth record...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

                    // Child Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _gender == 'female' ? Colors.pink.shade100 : Colors.blue.shade100,
                            child: Text(
                              childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _gender == 'female' ? Colors.pink : Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  childName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  ageText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Height Input
                    AppInputField(
                      hintText: 'Height (cm)',
                      controller: _heightController,
                      leadingIcon: Icons.height,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _updateBMI(),
                      isRequired: true,
                    ),
                    
                    if (_heightZScore != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Z-Score: ${_formatZScore(_heightZScore)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),

                    // Weight Input
                    AppInputField(
                      hintText: 'Weight (kg)',
                      controller: _weightController,
                      leadingIcon: Icons.monitor_weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _updateBMI(),
                      isRequired: true,
                    ),
                    
                    if (_weightZScore != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Z-Score: ${_formatZScore(_weightZScore)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),

                    // BMI Display with Z-Score
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
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
                          if (_bmiZScore != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Z-Score: ${_formatZScore(_bmiZScore)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remarks
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