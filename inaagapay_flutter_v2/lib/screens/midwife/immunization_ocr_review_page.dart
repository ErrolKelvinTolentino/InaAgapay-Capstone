// lib/screens/midwife/immunization_ocr_review_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_button.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/confirmation_dialog_box.dart';

class ReviewItem {
  final String vaccineNameRaw;
  final int doseNumberRaw;
  final String dateRaw;
  final String? remarksRaw;
  
  int? matchedVaccineId;
  DateTime? vaccinationDate;
  String remarks;
  bool isSelected;
  bool alreadyTaken;

  ReviewItem({
    required this.vaccineNameRaw,
    required this.doseNumberRaw,
    required this.dateRaw,
    this.remarksRaw,
    this.matchedVaccineId,
    this.vaccinationDate,
    required this.remarks,
    this.isSelected = true,
    this.alreadyTaken = false,
  });
}

class ImmunizationOcrReviewPage extends StatefulWidget {
  final int childId;
  final List<Map<String, dynamic>> extractedVaccines;
  final List<Map<String, dynamic>> allVaccines;
  final Set<int> takenVaccineIds;

  const ImmunizationOcrReviewPage({
    super.key,
    required this.childId,
    required this.extractedVaccines,
    required this.allVaccines,
    required this.takenVaccineIds,
  });

  @override
  State<ImmunizationOcrReviewPage> createState() => _ImmunizationOcrReviewPageState();
}

class _ImmunizationOcrReviewPageState extends State<ImmunizationOcrReviewPage> {
  final List<ReviewItem> _reviewItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeReviewItems();
  }

  void _initializeReviewItems() {
    for (final extracted in widget.extractedVaccines) {
      final nameRaw = extracted['vaccine_name_raw']?.toString() ?? '';
      final doseRaw = (extracted['dose_number'] as num?)?.toInt() ?? 1;
      final dateRaw = extracted['date_raw']?.toString() ?? '';
      final parsedDateStr = extracted['parsed_date']?.toString();
      final remarksRaw = extracted['remarks']?.toString();

      // Attempt parsing date
      DateTime? initialDate;
      if (parsedDateStr != null && parsedDateStr.isNotEmpty) {
        try {
          initialDate = DateTime.parse(parsedDateStr);
        } catch (_) {}
      }

      // Try to find the best matching vaccine in database
      final matchedId = _findBestMatch(nameRaw, doseRaw);
      final alreadyTaken = matchedId != null && widget.takenVaccineIds.contains(matchedId);

      _reviewItems.add(
        ReviewItem(
          vaccineNameRaw: nameRaw,
          doseNumberRaw: doseRaw,
          dateRaw: dateRaw,
          remarksRaw: remarksRaw,
          matchedVaccineId: matchedId,
          vaccinationDate: initialDate,
          remarks: remarksRaw ?? '',
          isSelected: !alreadyTaken && matchedId != null, // Auto-uncheck if already taken
          alreadyTaken: alreadyTaken,
        ),
      );
    }
  }

  int? _findBestMatch(String rawName, int dose) {
    final lower = rawName.toLowerCase();
    
    // Determine the type of vaccine
    String? searchKeyword;
    if (lower.contains('bcg')) {
      searchKeyword = 'bcg';
    } else if (lower.contains('hepa') || lower.contains('hepatitis')) {
      searchKeyword = 'hepatitis';
    } else if (lower.contains('penta') || lower.contains('dpt')) {
      searchKeyword = 'pentavalent';
    } else if (lower.contains('opv') || (lower.contains('polio') && lower.contains('oral'))) {
      searchKeyword = 'oral polio';
    } else if (lower.contains('ipv') || (lower.contains('polio') && lower.contains('inactivated'))) {
      searchKeyword = 'inactivated polio';
    } else if (lower.contains('pcv') || lower.contains('pneumo')) {
      searchKeyword = 'pneumococcal';
    } else if (lower.contains('mmr') || lower.contains('measles')) {
      searchKeyword = 'measles';
    } else if (lower.contains('rota')) {
      searchKeyword = 'rotavirus';
    }

    if (searchKeyword == null) return null;

    // Search in the master database vaccines list
    for (final v in widget.allVaccines) {
      final dbName = (v['vaccine_name']?.toString() ?? '').toLowerCase();
      final dbDose = (v['dose_number'] as num?)?.toInt() ?? 1;

      if (dbName.contains(searchKeyword) && dbDose == dose) {
        return v['vaccine_id'] as int;
      }
    }
    
    return null;
  }

  Future<void> _selectDate(ReviewItem item) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.vaccinationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        item.vaccinationDate = picked;
      });
    }
  }

  bool get _isFormValid {
    final selectedItems = _reviewItems.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) return false;

    for (final item in selectedItems) {
      if (item.matchedVaccineId == null || item.vaccinationDate == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveRecords() async {
    final selectedItems = _reviewItems.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      final List<Map<String, dynamic>> recordsToInsert = [];

      for (final item in selectedItems) {
        // Double check duplicate insertion
        final existing = await client
            .from('immunization_record')
            .select('immunization_record_id')
            .eq('child_id', widget.childId)
            .eq('vaccine_id', item.matchedVaccineId!)
            .maybeSingle();

        if (existing != null) {
          throw Exception(
            'One or more selected vaccines (ID: ${item.matchedVaccineId}) have already been recorded for this child.',
          );
        }

        recordsToInsert.add({
          'child_id': widget.childId,
          'vaccine_id': item.matchedVaccineId!,
          'vaccination_date': DateFormat('yyyy-MM-dd').format(item.vaccinationDate!),
          'remarks': item.remarks.trim().isEmpty ? null : item.remarks.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Perform bulk insert
      await client.from('immunization_record').insert(recordsToInsert);

      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogBox(
            type: DialogType.success,
            title: 'Records Saved',
            content: '${recordsToInsert.length} immunization records have been successfully saved.',
            buttonText: 'OK',
            onPressed: () {
              Navigator.pop(context); // Pop dialog
              Navigator.pop(context, true); // Return success to previous screen
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving bulk immunizations: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          builder: (_) => DialogBox(
            type: DialogType.error,
            title: 'Save Failed',
            content: e.toString().replaceAll('Exception: ', ''),
            buttonText: 'OK',
            onPressed: () => Navigator.pop(context),
          ),
        );
      }
    }
  }

  void _confirmSave() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmationDialogBox(
        title: 'Confirm Bulk Record',
        subtitle: 'Please review all vaccine matches and dates. Growth and immunization records cannot be modified once added.',
        confirmText: 'Save Records',
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          _saveRecords();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _reviewItems.where((item) => item.isSelected).toList().length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Review Extracted Vaccines',
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
                    SizedBox(height: 16),
                    Text(
                      'Recording immunizations...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Instruction Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppColors.brandPrimary.withValues(alpha: 0.08),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: AppColors.brandPrimary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Below are the vaccines detected from the card photo. Please review the vaccine matches, dates, and select which ones to record.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inputText,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviewItems.length,
                      itemBuilder: (context, index) {
                        final item = _reviewItems[index];
                        return _buildReviewCard(item);
                      },
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        top: BorderSide(color: AppColors.borderPrimary, width: 1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isFormValid && selectedCount > 0)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: Text(
                                'Make sure all selected vaccines have a valid match and date.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        MainButton(
                          label: selectedCount == 0
                              ? 'Select records to save'
                              : 'Record $selectedCount Immunization${selectedCount != 1 ? 's' : ''}',
                          onPressed: _isFormValid ? _confirmSave : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewItem item) {
    // Check if the system vaccines contains appropriate dropdown options
    // Filter to only include untaken vaccines OR the currently matched vaccine
    final dropdownOptions = widget.allVaccines.where((v) {
      final vaccineId = v['vaccine_id'] as int;
      final isAlreadyTaken = widget.takenVaccineIds.contains(vaccineId);
      return !isAlreadyTaken || vaccineId == item.matchedVaccineId;
    }).toList();

    // Map system dropdown values
    final optionList = dropdownOptions.map((v) {
      final id = v['vaccine_id'] as int;
      final name = v['vaccine_name']?.toString() ?? '';
      final dose = v['dose_number']?.toString() ?? '';
      final notes = v['notes']?.toString() ?? '';
      final parts = <String>['$name (Dose $dose)'];
      if (notes.isNotEmpty) parts.add(notes);
      return MapEntry(id, parts.join(' - '));
    }).toList();

    final dateText = item.vaccinationDate != null
        ? DateFormat('yyyy-MM-dd').format(item.vaccinationDate!)
        : 'Select Date';

    return Opacity(
      opacity: item.isSelected ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: item.isSelected
                ? AppColors.brandPrimary.withValues(alpha: 0.3)
                : AppColors.borderPrimary,
            width: item.isSelected ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Toggle Selection and Raw Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  activeColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  value: item.isSelected,
                  onChanged: item.alreadyTaken
                      ? null
                      : (val) {
                          setState(() {
                            item.isSelected = val ?? false;
                          });
                        },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_alt_rounded,
                              color: AppColors.brandPrimary, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'Extracted Raw Info:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (item.alreadyTaken)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppColors.success, size: 10),
                                  SizedBox(width: 4),
                                  Text(
                                    'Already recorded',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"${item.vaccineNameRaw}" (Dose ${item.doseNumberRaw}) • Date: ${item.dateRaw}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inputText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (item.isSelected) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Match Dropdown
              const Text(
                'Map to System Vaccine *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: const Text('Select vaccine match'),
                    value: item.matchedVaccineId,
                    onChanged: (id) {
                      setState(() {
                        item.matchedVaccineId = id;
                        // check already taken
                        if (id != null && widget.takenVaccineIds.contains(id)) {
                          item.alreadyTaken = true;
                          item.isSelected = false;
                        } else {
                          item.alreadyTaken = false;
                        }
                      });
                    },
                    items: optionList.map((opt) {
                      return DropdownMenuItem<int>(
                        value: opt.key,
                        child: Text(
                          opt.value,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Date Picker and Remarks in Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vaccination Date *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _selectDate(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderPrimary),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    color: AppColors.brandPrimary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dateText,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: item.vaccinationDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Remarks
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remarks (optional)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: TextField(
                            onChanged: (val) {
                              item.remarks = val;
                            },
                            controller: TextEditingController.fromValue(
                              TextEditingValue(
                                text: item.remarks,
                                selection: TextSelection.collapsed(offset: item.remarks.length),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              hintText: 'Add remarks',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
