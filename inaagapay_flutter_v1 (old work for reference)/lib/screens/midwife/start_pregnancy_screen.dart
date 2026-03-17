import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../models/due_date_basis.dart';
import '../../services/auth_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';

class StartPregnancyScreen extends StatefulWidget {
  final int motherId;
  final String? motherName;

  const StartPregnancyScreen({
    super.key,
    required this.motherId,
    this.motherName,
  });

  @override
  State<StartPregnancyScreen> createState() => _StartPregnancyScreenState();
}

class _StartPregnancyScreenState extends State<StartPregnancyScreen> {
  final DateFormat _dateFmt = DateFormat('MMM d, yyyy');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _weeksController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  DueDateBasis _basis = DueDateBasis.lmp;
  DateTime? _lmp;
  DateTime? _edd;
  bool _submitting = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _resetInputs() {
    _lmp = null;
    _edd = null;
    _dateController.clear();
    _weeksController.clear();
    _daysController.clear();
  }

  void _setBasis(DueDateBasis basis) {
    setState(() {
      _basis = basis;
      _resetInputs();
    });
  }

  void _updateFromLmp(DateTime lmp) {
    final normalized = _normalize(lmp);
    setState(() {
      _lmp = normalized;
      _edd = normalized.add(const Duration(days: 280));
      _dateController.text = _dateFmt.format(normalized);
    });
  }

  void _updateFromEdd(DateTime edd) {
    final normalized = _normalize(edd);
    setState(() {
      _edd = normalized;
      _lmp = normalized.subtract(const Duration(days: 280));
      _dateController.text = _dateFmt.format(normalized);
    });
  }

  void _updateFromAog() {
    final weeks = int.tryParse(_weeksController.text.trim()) ?? 0;
    final days = int.tryParse(_daysController.text.trim()) ?? 0;
    final totalDays = (weeks * 7) + days;
    if (totalDays <= 0) {
      setState(() {
        _lmp = null;
        _edd = null;
      });
      return;
    }

    final lmp = _today.subtract(Duration(days: totalDays));
    setState(() {
      _lmp = lmp;
      _edd = lmp.add(const Duration(days: 280));
    });
  }

  String _formatAogFromLmp() {
    if (_lmp == null) return '—';
    final days = _today.difference(_lmp!).inDays;
    if (days < 0) return '—';
    final weeks = days ~/ 7;
    final remDays = days % 7;
    return '${weeks}w ${remDays}d';
  }

  String? _validate() {
    if (_lmp == null || _edd == null) {
      return 'Provide gestational info to compute LMP and EDD.';
    }
    if (_lmp!.isAfter(_today)) {
      return 'LMP cannot be in the future.';
    }
    if (_edd!.isBefore(_today)) {
      return 'EDD cannot be in the past.';
    }
    final spanDays = _edd!.difference(_lmp!).inDays;
    if (spanDays < 259 || spanDays > 294) {
      return 'EDD must be 37–42 weeks from LMP.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _basis == DueDateBasis.edd
          ? (_edd ?? now.add(const Duration(days: 1)))
          : (_lmp ?? now),
      firstDate: _basis == DueDateBasis.edd ? now : DateTime(1900),
      lastDate: _basis == DueDateBasis.edd ? DateTime(now.year + 2) : now,
    );

    if (picked != null) {
      if (_basis == DueDateBasis.lmp) {
        _updateFromLmp(picked);
      } else {
        _updateFromEdd(picked);
      }
    }
  }

  Future<void> _submit() async {
    final message = _validate();
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final res = await http.post(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/start_pregnancy.php',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mother_id': widget.motherId,
          'last_menstrual_period': _lmp!.toIso8601String(),
          'expected_date_of_delivery': _edd!.toIso8601String(),
        }),
      );

      final decoded = jsonDecode(res.body);
      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Failed to start pregnancy');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.brandText,
      ),
    ),
  );

  Widget _infoRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _dateController.dispose();
    _weeksController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Start Pregnancy'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.motherName != null &&
                          widget.motherName!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            widget.motherName!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Text(
                        'Select how you want to calculate the due date, then provide the value. We will compute LMP, AOG, and EDD for you.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('1) Calculation basis'),
                      DropdownButtonFormField<DueDateBasis>(
                        value: _basis,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        items: DueDateBasis.values
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _setBasis(v);
                        },
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('2) Provide value'),
                      if (_basis == DueDateBasis.lmp ||
                          _basis == DueDateBasis.edd)
                        AppInputField(
                          hintText: _basis == DueDateBasis.lmp
                              ? 'Last menstrual period'
                              : 'Estimated delivery date',
                          controller: _dateController,
                          readOnly: true,
                          leadingIcon: Icons.calendar_today,
                          onTap: _pickDate,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: AppInputField(
                                hintText: 'Weeks',
                                controller: _weeksController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _updateFromAog(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppInputField(
                                hintText: 'Days',
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _updateFromAog(),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.brandPrimary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 22,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _basis == DueDateBasis.edd
                                    ? 'EDD should be a future date. LMP and AOG are calculated automatically.'
                                    : 'Your closest estimate works. LMP, AOG, and EDD are computed right away.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('3) Computed results'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderPrimary),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _infoRow(
                              'LMP',
                              _lmp == null ? '—' : _dateFmt.format(_lmp!),
                              Icons.event,
                            ),
                            _infoRow(
                              'EDD',
                              _edd == null ? '—' : _dateFmt.format(_edd!),
                              Icons.child_care,
                            ),
                            _infoRow(
                              'AOG',
                              _formatAogFromLmp(),
                              Icons.hourglass_bottom,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              MainButton(
                label: _submitting ? 'Starting...' : 'Start Pregnancy',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
