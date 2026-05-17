// lib/screens/midwife/add_growth_step1.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
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
  Map<String, dynamic>? _previousGrowth;
  bool _loading = true;
  int _ageInWeeks = 0;
  String _gender = '';

  double? _weightZScore;
  double? _heightZScore;
  double? _bmiZScore;

  String _bmiCategoryText = 'Normal';
  Color _bmiCategoryColor = AppColors.textPrimary;

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
      final childResponse =
          await Supabase.instance.client.from('children').select('''
            child_id,
            first_name,
            last_name,
            sex
          ''').eq('child_id', widget.childId).single();

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

      final previousGrowthResponse = await Supabase.instance.client
          .from('child_details')
          .select('*')
          .eq('child_id', widget.childId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      _previousGrowth = previousGrowthResponse;

      if (mounted) {
        setState(() {
          _childData = childResponse;
          _loading = false;
        });
      }

      // After loading, trigger an initial calculation if there are values
      _onMeasurementChanged();
    } catch (e) {
      debugPrint('Error loading child data: $e');
      if (mounted) {
        setState(() => _loading = false);
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

    if (heightCm == null ||
        weightKg == null ||
        heightCm == 0 ||
        weightKg == 0) {
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
      _bmiZScore =
          GrowthCalculator.calculateBMIZScore(bmi, _ageInWeeks, _gender);

      debugPrint('BMI Z-Score: $_bmiZScore');

      // Update status based on Z-score
      _updateBMICategory(_bmiZScore!);
    } else {
      debugPrint(
          'Cannot calculate Z-score: Age in weeks=$_ageInWeeks, Gender=$_gender');
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
        _bmiCategoryColor = AppColors.textPrimary;
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
      _heightZScore = GrowthCalculator.calculateHeightZScore(
          heightCm, _ageInWeeks, _gender);
    }

    if (weightKg != null && _ageInWeeks > 0 && _gender.isNotEmpty) {
      _weightZScore = GrowthCalculator.calculateWeightZScore(
          weightKg, _ageInWeeks, _gender);
    }

    if (bmi != null && _ageInWeeks > 0 && _gender.isNotEmpty) {
      _bmiZScore =
          GrowthCalculator.calculateBMIZScore(bmi, _ageInWeeks, _gender);
      _updateBMICategory(_bmiZScore!);
    }
  }

  void _validateForm() {
    if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
      setState(() {
        _isFormValid = false;
        _validationMessage = null;
      });
      return;
    }

    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height == null || weight == null) {
      setState(() {
        _isFormValid = false;
        _validationMessage =
            'Please enter valid numbers for height and weight.';
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

    final heightRange = _heightRangeForAge();
    final weightRange = _weightRangeForAge();
    final heightValid = height >= heightRange.min && height <= heightRange.max;
    final weightValid = weight >= weightRange.min && weight <= weightRange.max;

    if (!heightValid || !weightValid) {
      final heightText =
          'Height should be ${heightRange.min.toStringAsFixed(0)}–${heightRange.max.toStringAsFixed(0)} cm.';
      final weightText =
          'Weight should be ${weightRange.min.toStringAsFixed(1)}–${weightRange.max.toStringAsFixed(1)} kg.';
      setState(() {
        _isFormValid = false;
        _validationMessage =
            'This measurement is outside the typical range for the child\'s age. $heightText $weightText';
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

      await Supabase.instance.client.from('child_details').insert({
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
          subtitle:
              'Please make sure the details are correct. Growth records cannot be edited once added.',
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

  String _growthStatusDescription(String metric, double? zScore) {
    if (zScore == null) {
      return '$metric status unavailable';
    }
    if (zScore < -2) {
      return '$metric is below the expected range';
    }
    if (zScore < -1) {
      return '$metric is slightly below the expected range';
    }
    if (zScore <= 1) {
      return '$metric is within the expected range';
    }
    if (zScore <= 2) {
      return '$metric is slightly above the expected range';
    }
    return '$metric is above the expected range';
  }

  String? _calculatePreviousBMI() {
    if (_previousGrowth == null) return null;
    final prevHeight =
        (_previousGrowth!['child_height'] as num?)?.toDouble() ?? 0;
    final prevWeight =
        (_previousGrowth!['child_weight'] as num?)?.toDouble() ?? 0;
    if (prevHeight <= 0 || prevWeight <= 0) return null;
    final prevHeightM = prevHeight / 100.0;
    final prevBmi = prevWeight / (prevHeightM * prevHeightM);
    return prevBmi.toStringAsFixed(1);
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  _Range _heightRangeForAge() {
    if (_ageInWeeks < 13) return _Range(40, 70);
    if (_ageInWeeks < 26) return _Range(45, 80);
    if (_ageInWeeks < 52) return _Range(50, 90);
    return _Range(60, 140);
  }

  _Range _weightRangeForAge() {
    if (_ageInWeeks < 13) return _Range(2, 6);
    if (_ageInWeeks < 26) return _Range(2.5, 10);
    if (_ageInWeeks < 52) return _Range(3, 12);
    return _Range(4, 35);
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

    final childName =
        '${_childData?['first_name'] ?? ''} ${_childData?['last_name'] ?? ''}'
            .trim();
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            backgroundColor: _gender == 'female'
                                ? Colors.pink.shade100
                                : Colors.blue.shade100,
                            child: Text(
                              childName.isNotEmpty
                                  ? childName[0].toUpperCase()
                                  : 'C',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _gender == 'female'
                                    ? Colors.pink
                                    : Colors.blue,
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _onMeasurementChanged(),
                      isRequired: true,
                    ),

                    if (_previousGrowth != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Previous height: ${(_previousGrowth!['child_height'] as num?)?.toStringAsFixed(1) ?? 'n/a'} cm • ${_formatDate(_previousGrowth!['created_at']?.toString() ?? '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],

                    if (_heightZScore != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          _growthStatusDescription('Height', _heightZScore),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (_) => _onMeasurementChanged(),
                      isRequired: true,
                    ),

                    if (_previousGrowth != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Previous weight: ${(_previousGrowth!['child_weight'] as num?)?.toStringAsFixed(1) ?? 'n/a'} kg • ${_formatDate(_previousGrowth!['created_at']?.toString() ?? '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],

                    if (_weightZScore != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          _growthStatusDescription('Weight', _weightZScore),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.3),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calculate,
                                color: AppColors.brandPrimary,
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
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (_bmiController.text.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _bmiCategoryColor.withValues(
                                        alpha: 0.2),
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
                          if (_bmiZScore != null &&
                              _bmiController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _growthStatusDescription('BMI', _bmiZScore),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      _bmiCategoryColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_previousGrowth != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Previous BMI: ${_calculatePreviousBMI() ?? 'n/a'} • ${_formatDate(_previousGrowth!['created_at']?.toString() ?? '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.borderPrimary.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Measurement guide: enter height in cm and weight in kg. Use the child\'s age range to choose realistic values and double-check the measuring tool if numbers seem unusual.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.notes_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Remarks (optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _remarksController,
                            minLines: 4,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              hintText:
                                  'Add optional notes to describe the measurement context',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                            ),
                            style: TextStyle(
                              color:
                                  AppColors.textPrimary.withValues(alpha: 0.85),
                              fontSize: 15,
                            ),
                            cursorColor: AppColors.brandPrimary,
                          ),
                        ],
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

class _Range {
  final double min;
  final double max;
  const _Range(this.min, this.max);
}
