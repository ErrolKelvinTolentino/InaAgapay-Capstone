// lib/screens/midwife/quick_vitals_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/app_input_field.dart';

/// Lightweight dialog-style screen that lets a midwife record basic vitals
/// (weight, blood pressure) without going through the full prenatal checkup
/// flow. Inserts a minimal `prenatal_checkups` row.
class QuickVitalsScreen extends StatefulWidget {
  const QuickVitalsScreen({
    super.key,
    required this.motherId,
    required this.pregnancyId,
    required this.motherName,
    this.lastMenstrualPeriod,
  });

  final int motherId;
  final int pregnancyId;
  final String motherName;
  final String? lastMenstrualPeriod;

  @override
  State<QuickVitalsScreen> createState() => _QuickVitalsScreenState();
}

class _QuickVitalsScreenState extends State<QuickVitalsScreen> {
  final _weightController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  int? _midwifeId;

  @override
  void initState() {
    super.initState();
    _fetchMidwifeId();
  }

  Future<void> _fetchMidwifeId() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) return;
      final result = await SupabaseService.client
          .from('midwives')
          .select('midwife_id')
          .eq('account_id', accountId)
          .maybeSingle();
      if (result != null && mounted) {
        setState(() => _midwifeId = result['midwife_id'] as int);
      }
    } catch (_) {}
  }

  int? get _computedAogWeeks {
    if (widget.lastMenstrualPeriod == null) return null;
    final lmp = DateTime.tryParse(widget.lastMenstrualPeriod!);
    if (lmp == null) return null;
    return DateTime.now().difference(lmp).inDays ~/ 7;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final weight = double.tryParse(_weightController.text.trim());
      final systolic = int.tryParse(_systolicController.text.trim());
      final diastolic = int.tryParse(_diastolicController.text.trim());
      final remarks = _remarksController.text.trim();

      // Validate ranges
      if (weight != null && (weight < 30 || weight > 200)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Weight must be between 30 and 200 kg.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
      if (systolic != null && (systolic < 70 || systolic > 250)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Systolic BP must be between 70 and 250 mmHg.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
      if (diastolic != null && (diastolic < 40 || diastolic > 150)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Diastolic BP must be between 40 and 150 mmHg.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final data = <String, dynamic>{
        'pregnancy_id': widget.pregnancyId,
        'checkup_datetime': DateTime.now().toIso8601String(),
      };

      if (_midwifeId != null) data['midwife_id'] = _midwifeId;
      if (weight != null) data['checkup_weight'] = weight;
      if (systolic != null) data['blood_pressure_systolic'] = systolic;
      if (diastolic != null) data['blood_pressure_diastolic'] = diastolic;
      if (_computedAogWeeks != null) {
        data['age_of_gestation'] = _computedAogWeeks;
      }
      if (remarks.isNotEmpty) {
        data['remarks'] = remarks;
      } else {
        data['remarks'] = 'Quick vitals entry by midwife';
      }

      await SupabaseService.client.from('prenatal_checkups').insert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vitals saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save vitals: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aog = _computedAogWeeks;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: const Text('Quick Vitals'),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mother info header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pregnant_woman,
                            color: AppColors.brandPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.motherName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              aog != null
                                  ? 'Pregnancy #${widget.pregnancyId} · AOG: $aog weeks'
                                  : 'Pregnancy #${widget.pregnancyId}',
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

                // Weight field
                const Text(
                  'Weight (kg)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AppInputField(
                  hintText: 'e.g. 58.5',
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  leadingIcon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 16),

                // Blood Pressure
                const Text(
                  'Blood Pressure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppInputField(
                        hintText: 'Systolic',
                        controller: _systolicController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        leadingIcon: Icons.favorite_border,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AppInputField(
                        hintText: 'Diastolic',
                        controller: _diastolicController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        leadingIcon: Icons.favorite_border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Remarks
                const Text(
                  'Remarks (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AppInputField(
                  hintText: 'Additional notes...',
                  controller: _remarksController,
                  leadingIcon: Icons.notes,
                ),
                const SizedBox(height: 12),

                // Auto-computed AOG info
                if (aog != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.brandPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Age of Gestation will be auto-set to $aog weeks (computed from LMP).',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveVitals,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Vitals',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
