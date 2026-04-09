// lib/screens/midwife/add_growth_step1.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/app_input_field.dart';
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

  String _bmiCategoryText = 'Normal';
  Color _bmiCategoryColor = AppColors.success;
  
  bool _isFormValid = false;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadChildData();
    _heightController.addListener(_onMeasurementChanged);
    _weightController.addListener(_onMeasurementChanged);
  }

  Future<void> _loadChildData() async {
    try {
      // First fetch child details
      final childResponse = await Supabase.instance.client
          .from('children')
          .select('''
            child_id,
            first_name,
            last_name,
            sex
          ''')
          .eq('child_id', widget.childId)
          .single();

      // Then fetch birth details separately
      final birthDetailsResponse = await Supabase.instance.client
          .from('birth_details')
          .select('birthdate')
          .eq('child_id', widget.childId)
          .maybeSingle();

      final birthdate = birthDetailsResponse?['birthdate']?.toString();
      
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
      
      // After loading, trigger an initial calculation if there are values
      _onMeasurementChanged();
    } catch (e) {
      debugPrint('Error loading child data: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading child data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onMeasurementChanged() {
    _updateBMIAndStatus();
    _validateForm();
  }

  void _updateBMIAndStatus() {
    final double? heightCm = double.tryParse(_heightController.text);
    final double? weightKg = double.tryParse(_weightController.text);

    debugPrint('=== REAL-TIME BMI CALCULATION ===');
    debugPrint('Height: ${_heightController.text} cm');
    debugPrint('Weight: ${_weightController.text} kg');
    debugPrint('Age in weeks: $_ageInWeeks');
    debugPrint('Gender: $_gender');

    if (heightCm == null || weightKg == null || heightCm == 0 || weightKg == 0) {
      debugPrint('Invalid height or weight, resetting BMI');
      setState(() {
        _bmiController.text = '';
        _bmiZScore = null;
        _bmiCategoryText = 'Normal';
        _bmiCategoryColor = AppColors.success;
      });
      return;
    }

    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);
    
    debugPrint('Calculated BMI: $bmi');
    
    setState(() {
      _bmiController.text = bmi.toStringAsFixed(1);
    });
    
    if (_ageInWeeks > 0 && _gender.isNotEmpty) {
      // Calculate BMI Z-score
      _bmiZScore = GrowthCalculator.calculateBMIZScore(bmi, _ageInWeeks, _gender);
      
      debugPrint('BMI Z-Score: $_bmiZScore');
      
      // Update status based on Z-score
      _updateBMICategory(_bmiZScore!);
    } else {
      debugPrint('Cannot calculate Z-score: Age in weeks=$_ageInWeeks, Gender=$_gender');
    }
  }

  void _updateBMICategory(double zScore) {
    debugPrint('Updating BMI category for Z-Score: $zScore');
    
    setState(() {
      if (zScore < -2) {
        _bmiCategoryText = 'Underweight';
        _bmiCategoryColor = AppColors.warning;
        debugPrint('Category: Underweight (zScore < -2)');
      } else if (zScore < -1) {
        _bmiCategoryText = 'Mildly Underweight';
        _bmiCategoryColor = Colors.orange;
        debugPrint('Category: Mildly Underweight (-2 < zScore < -1)');
      } else if (zScore <= 1) {
        _bmiCategoryText = 'Normal';
        _bmiCategoryColor = AppColors.success;
        debugPrint('Category: Normal (-1 <= zScore <= 1)');
      } else if (zScore <= 2) {
        _bmiCategoryText = 'Overweight';
        _bmiCategoryColor = Colors.orange;
        debugPrint('Category: Overweight (1 < zScore <= 2)');
      } else if (zScore <= 3) {
        _bmiCategoryText = 'Obese';
        _bmiCategoryColor = AppColors.error;
        debugPrint('Category: Obese (2 < zScore <= 3)');
      } else {
        _bmiCategoryText = 'Severely Obese';
        _bmiCategoryColor = AppColors.error;
        debugPrint('Category: Severely Obese (zScore > 3)');
      }
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
      _updateBMICategory(_bmiZScore!);
    }
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
      // BMI and remarks are NOT saved to database

      await Supabase.instance.client
          .from('child_details')
          .insert({
            'child_id': widget.childId,
            'child_height': height,
            'child_weight': weight,
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
  void dispose() {
    _heightController.removeListener(_onMeasurementChanged);
    _weightController.removeListener(_onMeasurementChanged);
    _heightController.dispose();
    _weightController.dispose();
    _bmiController.dispose();
    _remarksController.dispose();
    super.dispose();
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
                      onChanged: (_) => _onMeasurementChanged(),
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
                      onChanged: (_) => _onMeasurementChanged(),
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

                    // BMI Display with Real-time Status (calculated in app, NOT saved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _bmiCategoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _bmiCategoryColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calculate, 
                                color: _bmiCategoryColor,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _bmiController.text.isEmpty
                                      ? 'BMI: ---'
                                      : 'BMI: ${_bmiController.text}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _bmiController.text.isEmpty 
                                        ? AppColors.textSecondary
                                        : _bmiCategoryColor,
                                  ),
                                ),
                              ),
                              if (_bmiController.text.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _bmiCategoryColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _bmiCategoryText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _bmiCategoryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_bmiZScore != null && _bmiController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Z-Score: ${_formatZScore(_bmiZScore)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _bmiCategoryColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remarks Field (UI only, NOT saved to DB)
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
                          hintText: 'Remarks (optional - not saved)',
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