// lib/screens/midwife/add_immunization_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/page_title.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/main_button.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/confirmation_dialog_box.dart';
import '../../widgets/validation_message.dart';

class AddImmunizationPage extends StatefulWidget {
  final int childId;

  const AddImmunizationPage({
    super.key,
    required this.childId,
  });

  @override
  State<AddImmunizationPage> createState() => _AddImmunizationPageState();
}

class _AddImmunizationPageState extends State<AddImmunizationPage> {
  final TextEditingController _vaccineController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  int? _selectedVaccineId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _vaccines = [];
  bool _vaccinesLoading = true;
  Set<int> _takenVaccineIds = {};
  String? _errorMessage;
  DateTime? _childBirthdate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _vaccinesLoading = true;
      _errorMessage = null;
    });

    await Future.wait([
      _loadVaccines(),
      _loadTakenVaccines(),
      _loadChildBirthdate(),
    ]);

    setState(() => _vaccinesLoading = false);

    debugPrint('Vaccines loaded: ${_vaccines.length}');
    debugPrint('Taken vaccines: ${_takenVaccineIds.length}');
    debugPrint('Available vaccines: ${_getAvailableVaccines().length}');
    debugPrint('Child birthdate: $_childBirthdate');
  }

  Future<void> _loadChildBirthdate() async {
    try {
      final response = await Supabase.instance.client
          .from('birth_details')
          .select('birthdate')
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (response != null && response['birthdate'] != null) {
        _childBirthdate = DateTime.parse(response['birthdate']);
      }
    } catch (e) {
      debugPrint('Error loading child birthdate: $e');
    }
  }

  /// Returns the child's age in months (fractional).
  double _getChildAgeMonths() {
    if (_childBirthdate == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(_childBirthdate!);
    return diff.inDays / 30.44; // average days per month
  }

  Future<void> _loadVaccines() async {
    try {
      final response = await Supabase.instance.client
          .from('vaccines')
          .select('*')
          .eq('target_recipients', 'child')
          .order('recommended_age_months')
          .order('vaccine_name');

      _vaccines = List<Map<String, dynamic>>.from(response);

      if (_vaccines.isEmpty) {
        setState(() {
          _errorMessage = 'No vaccines found in the database. Please add vaccines first.';
        });
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading vaccines: $e');
      setState(() {
        _errorMessage = 'Failed to load vaccines: $e';
      });
    }
  }

  Future<void> _loadTakenVaccines() async {
    try {
      final response = await Supabase.instance.client
          .from('immunization_record')
          .select('vaccine_id')
          .eq('child_id', widget.childId);

      final taken = List<Map<String, dynamic>>.from(response);
      setState(() {
        _takenVaccineIds = taken.map((t) => t['vaccine_id'] as int).toSet();
      });
    } catch (e) {
      debugPrint('Error loading taken vaccines: $e');
    }
  }

  /// Checks whether the prerequisite dose for a given vaccine has been taken.
  /// For multi-dose vaccines (e.g. Pentavalent 1->2->3), dose N requires dose N-1.
  bool _isPrerequisiteMet(Map<String, dynamic> vaccine) {
    final doseNumber = (vaccine['dose_number'] as num?)?.toInt() ?? 1;
    if (doseNumber <= 1) return true; // first dose has no prerequisite

    final vaccineName = vaccine['vaccine_name']?.toString() ?? '';

    // Find the previous dose for the same vaccine_name
    final previousDose = _vaccines.where((v) {
      final vName = v['vaccine_name']?.toString() ?? '';
      final vDose = (v['dose_number'] as num?)?.toInt() ?? 1;
      return vName == vaccineName && vDose == doseNumber - 1;
    }).toList();

    if (previousDose.isEmpty) return true; // no previous dose found in DB, allow

    // Check if the previous dose vaccine_id is in takenVaccineIds
    final prevId = previousDose.first['vaccine_id'] as int;
    return _takenVaccineIds.contains(prevId);
  }

  /// Returns vaccines available for selection:
  /// - Not already taken
  /// - Age-appropriate (child age >= recommended_age_months)
  /// - Prerequisite doses met
  List<Map<String, dynamic>> _getAvailableVaccines() {
    final childAgeMonths = _getChildAgeMonths();
    return _vaccines.where((v) {
      final vaccineId = v['vaccine_id'] as int;
      final recommendedAge = (v['recommended_age_months'] as num?)?.toDouble() ?? 0;

      // Must not already be taken
      if (_takenVaccineIds.contains(vaccineId)) return false;

      // Must be age-appropriate
      if (childAgeMonths < recommendedAge) return false;

      // Must have prerequisite dose taken
      if (!_isPrerequisiteMet(v)) return false;

      return true;
    }).toList();
  }

  /// Determines the status of a vaccine for the roadmap display.
  /// Returns 'given', 'recommended', or 'not_due'.
  String _getVaccineStatus(Map<String, dynamic> vaccine) {
    final vaccineId = vaccine['vaccine_id'] as int;
    if (_takenVaccineIds.contains(vaccineId)) return 'given';

    final recommendedAge = (vaccine['recommended_age_months'] as num?)?.toDouble() ?? 0;
    final childAgeMonths = _getChildAgeMonths();
    if (childAgeMonths >= recommendedAge) return 'recommended';

    return 'not_due';
  }

  bool get _isFormValid =>
      _selectedVaccineId != null && _selectedDate != null;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _formatRecommendedAge(double? months) {
    if (months == null) return '';
    if (months == 0) return 'At birth';
    if (months < 1) {
      final weeks = (months * 4).round();
      return '$weeks weeks';
    }
    return '${months.toStringAsFixed(0)} months';
  }

  /// Returns a milestone label for grouping vaccines by recommended age.
  String _getMilestoneLabel(double months) {
    if (months == 0) return 'At Birth';
    if (months < 1) {
      final weeks = (months * 4).round();
      return '$weeks Weeks';
    }
    if (months < 12) {
      return '${months.toStringAsFixed(0)} Months';
    }
    final years = months / 12;
    if (years == years.roundToDouble()) {
      return '${years.toStringAsFixed(0)} Year${years > 1 ? 's' : ''}';
    }
    return '${months.toStringAsFixed(0)} Months';
  }

  void _openVaccineDropdown() {
    if (_vaccinesLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading vaccines, please wait...')),
      );
      return;
    }

    if (_vaccines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vaccines available in the system.')),
      );
      return;
    }

    final availableVaccines = _getAvailableVaccines();

    if (availableVaccines.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => DialogBox(
          type: DialogType.info,
          title: 'No Vaccines Available',
          content: 'All age-appropriate vaccines have already been administered, '
              'or the child has not yet reached the recommended age for remaining vaccines.',
          buttonText: 'OK',
          onPressed: () => Navigator.pop(context),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Vaccine',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Showing ${availableVaccines.length} age-appropriate, untaken vaccines',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: availableVaccines.length,
                  itemBuilder: (context, index) {
                    final vaccine = availableVaccines[index];
                    final vaccineName = vaccine['vaccine_name']?.toString() ?? '';
                    final doseNumber = vaccine['dose_number']?.toString() ?? '';
                    final notes = vaccine['notes']?.toString() ?? '';
                    final recommendedAge = (vaccine['recommended_age_months'] as num?)?.toDouble() ?? 0;
                    final ageText = _formatRecommendedAge(recommendedAge);
                    // Build display name, avoiding duplicate info when notes
                    // already matches the age label (e.g. "At birth" / "At birth").
                    final parts = <String>['$vaccineName (Dose $doseNumber)'];
                    if (ageText.isNotEmpty) {
                      parts.add(ageText);
                    }
                    if (notes.isNotEmpty &&
                        notes.toLowerCase() != ageText.toLowerCase()) {
                      parts.add(notes);
                    }
                    final displayName = parts.join(' - ');

                    return ListTile(
                      leading: const Icon(Icons.vaccines, color: AppColors.brandPrimary),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedVaccineId = vaccine['vaccine_id'] as int;
                          _vaccineController.text = displayName;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _submitImmunization() async {
    if (_selectedVaccineId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vaccine.')),
        );
      }
      return false;
    }

    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vaccination date.')),
        );
      }
      return false;
    }

    try {
      // Check if vaccine already given to this child
      final existing = await Supabase.instance.client
          .from('immunization_record')
          .select('immunization_record_id')
          .eq('child_id', widget.childId)
          .eq('vaccine_id', _selectedVaccineId!)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This vaccine has already been administered to this child.');
      }

      // Enforce prerequisite check at submission time as well
      final selectedVaccine = _vaccines.firstWhere(
        (v) => v['vaccine_id'] == _selectedVaccineId,
        orElse: () => <String, dynamic>{},
      );
      if (selectedVaccine.isNotEmpty && !_isPrerequisiteMet(selectedVaccine)) {
        throw Exception(
          'The previous dose has not been administered yet. '
          'Please administer doses in sequential order.',
        );
      }

      await Supabase.instance.client
          .from('immunization_record')
          .insert({
            'child_id': widget.childId,
            'vaccine_id': _selectedVaccineId!,
            'vaccination_date': _selectedDate!.toIso8601String().split('T')[0],
            'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('Error saving immunization: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => DialogBox(
            type: DialogType.error,
            title: 'Cannot Save',
            content: e.toString().replaceAll('Exception: ', ''),
            buttonText: 'OK',
            onPressed: () => Navigator.pop(context),
          ),
        );
      }
      return false;
    }
  }

  void _submit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmationDialogBox(
        title: 'Confirm Immunization',
        subtitle: 'Please review the details carefully. Immunization records cannot be edited once added.',
        confirmText: 'Confirm',
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          Navigator.pop(context);

          setState(() => _isLoading = true);

          final success = await _submitImmunization();

          setState(() => _isLoading = false);

          if (success && mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogBox(
                type: DialogType.success,
                title: 'Immunization Added',
                content: 'The immunization record has been successfully saved.',
                buttonText: 'OK',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
              ),
            );
          }
        },
      ),
    );
  }

  /// Groups vaccines by recommended_age_months for the roadmap display.
  /// Returns a list of (milestoneLabel, vaccines) pairs sorted by age.
  List<MapEntry<String, List<Map<String, dynamic>>>> _getGroupedVaccines() {
    final Map<double, List<Map<String, dynamic>>> grouped = {};

    for (final v in _vaccines) {
      final age = (v['recommended_age_months'] as num?)?.toDouble() ?? 0;
      grouped.putIfAbsent(age, () => []);
      grouped[age]!.add(v);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys.map((age) {
      return MapEntry(_getMilestoneLabel(age), grouped[age]!);
    }).toList();
  }

  /// Builds the immunization roadmap widget.
  Widget _buildRoadmap() {
    final groups = _getGroupedVaccines();
    if (groups.isEmpty) return const SizedBox.shrink();

    final givenCount = _vaccines.where((v) =>
        _takenVaccineIds.contains(v['vaccine_id'] as int)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.map_outlined, color: AppColors.brandPrimary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Immunization Roadmap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$givenCount / ${_vaccines.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _vaccines.isEmpty ? 0 : givenCount / _vaccines.length,
            backgroundColor: AppColors.borderPrimary,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        // Legend
        Row(
          children: [
            _legendDot(AppColors.success, 'Given'),
            const SizedBox(width: 12),
            _legendDot(AppColors.warning, 'Recommended'),
            const SizedBox(width: 12),
            _legendDot(AppColors.textSecondary, 'Not due yet'),
          ],
        ),
        const SizedBox(height: 12),
        // Milestone groups
        ...groups.map((entry) => _buildMilestoneGroup(entry.key, entry.value)),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMilestoneGroup(String label, List<Map<String, dynamic>> vaccines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandAccent,
              ),
            ),
            const SizedBox(height: 6),
            ...vaccines.map((v) => _buildVaccineStatusRow(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineStatusRow(Map<String, dynamic> vaccine) {
    final status = _getVaccineStatus(vaccine);
    final vaccineName = vaccine['vaccine_name']?.toString() ?? '';
    final doseNumber = vaccine['dose_number']?.toString() ?? '';
    final notes = vaccine['notes']?.toString() ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'given':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusLabel = 'Already given';
        break;
      case 'recommended':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        statusLabel = 'Recommended';
        break;
      default: // not_due
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.lock_outline;
        statusLabel = 'Not due yet';
    }

    final displayText = notes.isNotEmpty
        ? '$vaccineName (Dose $doseNumber) - $notes'
        : '$vaccineName (Dose $doseNumber)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: status == 'not_due'
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration: status == 'given'
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasEnteredData =>
      _selectedVaccineId != null ||
      _selectedDate != null ||
      _remarksController.text.trim().isNotEmpty;

  Future<void> _confirmDiscardAndPop() async {
    if (!_hasEnteredData) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved immunization data. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVaccines = _getAvailableVaccines();
    final hasAvailableVaccines = availableVaccines.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'Add Immunization',
          onBack: _confirmDiscardAndPop,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: PageTitle(
                  title: 'Vaccine Details',
                  leadingIcon: Icons.vaccines_rounded,
                  trailingIcon: Icons.check_circle,
                ),
              ),
              const SizedBox(height: 16),

              // Show error if any
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (_vaccinesLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),

              // Roadmap has been moved to child_immunization_list_page.dart

              // Select Vaccine
              GestureDetector(
                onTap: _vaccinesLoading ? null : _openVaccineDropdown,
                child: AbsorbPointer(
                  child: AppInputField(
                    hintText: 'Select Vaccine',
                    controller: _vaccineController,
                    leadingIcon: Icons.vaccines_outlined,
                    trailingIcon: Icons.keyboard_arrow_down_rounded,
                    isRequired: true,
                  ),
                ),
              ),

              if (!_vaccinesLoading && !hasAvailableVaccines && _vaccines.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Text(
                    'All age-appropriate vaccines have been administered, '
                    'or the child has not reached the recommended age for remaining vaccines.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Select Date
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: AppInputField(
                    hintText: 'Vaccination Date',
                    controller: _dateController,
                    leadingIcon: Icons.calendar_month_rounded,
                    isRequired: true,
                  ),
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

              const SizedBox(height: 12),

              if (!_isFormValid)
                const ValidationMessage(
                  message: 'Please complete all required fields before submitting.',
                  type: ValidationType.info,
                ),

              const SizedBox(height: 28),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : MainButton(
                      label: 'Add Immunization Record',
                      onPressed: (_isFormValid && hasAvailableVaccines && !_vaccinesLoading) ? _submit : null,
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
