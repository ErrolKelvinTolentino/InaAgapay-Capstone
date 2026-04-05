import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/progressive_step_indicator.dart';

class AddLabTestPage extends StatefulWidget {
  const AddLabTestPage({
    super.key,
    required this.motherId,
  });

  final int motherId;

  @override
  State<AddLabTestPage> createState() => _AddLabTestPageState();
}

class _AddLabTestPageState extends State<AddLabTestPage> {
  final ImagePicker _picker = ImagePicker();

  final _locationCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _workerNameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();

  DateTime? _date;
  DateTime? _pregnancyLmp;
  DateTime? _pregnancyEdd;
  int? _pregnancyId;
  String? _profession;
  String? _selectedLabType;
  XFile? _imageFile;
  String? _locationError;
  String? _workerNameError;
  String? _institutionError;

  bool _loading = true;
  bool _submitting = false;
  int _step = 0;
  static const int _totalSteps = 3;

  static const List<String> _pregnancyLabTests = [
    'Complete Blood Count (CBC)',
    'Urinalysis',
    'OGTT (Oral Glucose Tolerance Test)',
    'Fasting Blood Sugar',
    'Hepatitis B (HBsAg)',
    'HIV Screening',
    'Syphilis (VDRL/RPR)',
    'Blood Typing',
    'Glucose Challenge Test',
    'Thyroid Function (TSH)',
    'Stool Examination',
    'Other (specify in remarks)',
  ];

  static const List<String> _labProfessions = [
    'Medical Technologist',
    'Pathologist',
    'Nurse',
    'Midwife',
  ];

  @override
  void initState() {
    super.initState();
    _locationCtrl.addListener(_validateLocationInline);
    _workerNameCtrl.addListener(_validateWorkerInline);
    _institutionCtrl.addListener(_validateWorkerInline);
    _loadPregnancy();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _remarksCtrl.dispose();
    _workerNameCtrl.dispose();
    _institutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPregnancy() async {
    try {
      final response = await Supabase.instance.client
          .from('pregnancies')
          .select(
              'pregnancy_id, last_menstrual_period, expected_date_of_delivery')
          .eq('mother_id', widget.motherId)
          .eq('status', 'ongoing')
          .maybeSingle();

      _pregnancyId = response?['pregnancy_id'] as int?;
      _pregnancyLmp = response?['last_menstrual_period'] != null
          ? DateTime.tryParse(response!['last_menstrual_period'].toString())
          : null;
      _pregnancyEdd = response?['expected_date_of_delivery'] != null
          ? DateTime.tryParse(response!['expected_date_of_delivery'].toString())
          : null;
    } catch (_) {
      _pregnancyId = null;
      _pregnancyLmp = null;
      _pregnancyEdd = null;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() => _imageFile = image);
    } catch (e) {
      _showMessage('Unable to pick image: $e', type: AppSnackType.error);
    }
  }

  void _showMessage(String message,
      {AppSnackType type = AppSnackType.warning}) {
    AppSnackbar.show(context, message, type: type);
  }

  void _validateLocationInline() {
    final location = _locationCtrl.text.trim();
    setState(() {
      if (location.isEmpty) {
        _locationError = null;
      } else if (location.length < 3 || location.length > 150) {
        _locationError = 'Must be 3 to 150 characters';
      } else {
        _locationError = null;
      }
    });
  }

  void _validateWorkerInline() {
    final worker = _workerNameCtrl.text.trim();
    final institution = _institutionCtrl.text.trim();
    setState(() {
      _workerNameError =
          (worker.isNotEmpty && (worker.length < 3 || worker.length > 80))
              ? 'Must be 3 to 80 characters'
              : null;
      _institutionError = (institution.isNotEmpty &&
              (institution.length < 3 || institution.length > 120))
          ? 'Must be 3 to 120 characters'
          : null;
    });
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentStep() {
    final now = DateTime.now();

    if (_step == 0) {
      if (_selectedLabType == null || _selectedLabType!.isEmpty) {
        _showMessage('Please select lab test type.');
        return false;
      }
      if (_date == null) {
        _showMessage('Please select lab test date.');
        return false;
      }
      if (_date!.isAfter(now)) {
        _showMessage('Future lab test dates are not allowed.');
        return false;
      }
      if (_pregnancyLmp != null && _date!.isBefore(_pregnancyLmp!)) {
        _showMessage(
            'Lab test date cannot be before the current pregnancy LMP.');
        return false;
      }
      if (_pregnancyEdd != null &&
          _date!.isAfter(_pregnancyEdd!.add(const Duration(days: 45)))) {
        _showMessage('Lab test date is too far beyond expected due date.');
        return false;
      }

      final location = _locationCtrl.text.trim();
      setState(() {
        _locationError = location.isEmpty
            ? 'Location is required'
            : (location.length < 3 || location.length > 150)
                ? 'Must be 3 to 150 characters'
                : null;
      });
      if (location.length < 3 || location.length > 150) {
        _showMessage('Lab test location must be 3 to 150 characters.');
        return false;
      }

      if (_imageFile != null) {
        final lower = _imageFile!.name.toLowerCase();
        final validImage = lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp');
        if (!validImage) {
          _showMessage('Only JPG, PNG, or WEBP images are allowed.');
          return false;
        }
      }
    }

    if (_step == 1) {
      final worker = _workerNameCtrl.text.trim();
      final institution = _institutionCtrl.text.trim();
      final anyWorkerField =
          worker.isNotEmpty || institution.isNotEmpty || _profession != null;
      setState(() {
        _workerNameError =
            (worker.isNotEmpty && (worker.length < 3 || worker.length > 80))
                ? 'Must be 3 to 80 characters'
                : null;
        _institutionError = (institution.isNotEmpty &&
                (institution.length < 3 || institution.length > 120))
            ? 'Must be 3 to 120 characters'
            : null;
      });
      if (anyWorkerField) {
        if (worker.isEmpty || institution.isEmpty || _profession == null) {
          _showMessage(
              'Complete health worker name, institution, and profession.');
          return false;
        }
        if (worker.length < 3 || worker.length > 80) {
          _showMessage('Health worker name must be 3 to 80 characters.');
          return false;
        }
        if (institution.length < 3 || institution.length > 120) {
          _showMessage('Institution must be 3 to 120 characters.');
          return false;
        }
      }
    }

    if (_step == 2 && _remarksCtrl.text.trim().length > 500) {
      _showMessage('Remarks must be 500 characters or less.');
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (_pregnancyId == null || _date == null || _selectedLabType == null) {
      _showMessage('Please complete required fields.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final userId = await AuthStorage.getUserId();
      String? publicUrl;
      String? filePath;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final upload = await _uploadImage(bytes);
        filePath = upload['filePath'];
        publicUrl = upload['publicUrl'];
      }

      final inserted = await Supabase.instance.client
          .from('lab_tests')
          .insert({
            'pregnancy_id': _pregnancyId,
            'lab_test_type': _selectedLabType,
            'lab_test_date': DateFormat('yyyy-MM-dd').format(_date!),
            'lab_test_location': _locationCtrl.text.trim(),
            'lab_test_image': publicUrl,
            'remarks': _remarksCtrl.text.trim().isEmpty
                ? null
                : _remarksCtrl.text.trim(),
            'health_worker_name': _workerNameCtrl.text.trim().isEmpty
                ? null
                : _workerNameCtrl.text.trim(),
            'health_worker_institution': _institutionCtrl.text.trim().isEmpty
                ? null
                : _institutionCtrl.text.trim(),
            'health_worker_profession': _profession,
          })
          .select('lab_test_id')
          .single();

      final labTestId = inserted['lab_test_id'];
      if (filePath != null && userId != null) {
        await Supabase.instance.client.from('files').insert({
          'bucket_name': 'medical-images',
          'file_path': filePath,
          'file_name': filePath.split('/').last,
          'file_category': 'lab_test_image',
          'mime_type': 'image/jpeg',
          'uploaded_by': userId,
          'reference_type': 'lab_test',
          'reference_id': labTestId,
          'processing_type': 'manual_upload',
          'ai_processed': false,
        });
      }

      if (!mounted) return;
      _showMessage('Lab test record saved.', type: AppSnackType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to save lab test: $e', type: AppSnackType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<Map<String, String>> _uploadImage(Uint8List bytes) async {
    final fileName = 'lab_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'lab-tests/${widget.motherId}/$fileName';

    await Supabase.instance.client.storage.from('medical-images').uploadBinary(
          filePath,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    final publicUrl = Supabase.instance.client.storage
        .from('medical-images')
        .getPublicUrl(filePath);

    return {
      'filePath': filePath,
      'publicUrl': publicUrl,
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = _pregnancyLmp != null
        ? DateTime(
            _pregnancyLmp!.year, _pregnancyLmp!.month, _pregnancyLmp!.day)
        : DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: first,
      lastDate: now,
      helpText: _pregnancyLmp == null
          ? 'Select Lab Test Date'
          : 'Select date after LMP (${DateFormat('MMM d, yyyy').format(_pregnancyLmp!)})',
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  Widget _buildStep() {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Lab Test Type',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedLabType,
              decoration: const InputDecoration(labelText: 'Select test type'),
              items: _pregnancyLabTests
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedLabType = value),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Lab Test Date',
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.brandPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _date == null
                          ? 'Tap to choose date'
                          : DateFormat('MMMM d, yyyy').format(_date!),
                      style: TextStyle(
                        color: _date == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight:
                            _date == null ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Location',
            child: AppInputField(
              hintText: 'Lab test location',
              controller: _locationCtrl,
              isRequired: true,
              errorText: _locationError,
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Image (Optional)',
            child: Column(
              children: [
                if (_imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(_imageFile!.path),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: AppColors.bgSecondary,
                            alignment: Alignment.center,
                            child: const Text('Unable to preview image'),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            onPressed: () => setState(() => _imageFile = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    alignment: Alignment.center,
                    child: const Text('No image selected'),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_step == 1) {
      return Column(
        children: [
          _sectionCard(
            title: 'Health Worker',
            child: Column(
              children: [
                AppInputField(
                  hintText: 'Health worker name',
                  controller: _workerNameCtrl,
                  errorText: _workerNameError,
                ),
                const SizedBox(height: 12),
                AppInputField(
                  hintText: 'Institution / Clinic',
                  controller: _institutionCtrl,
                  errorText: _institutionError,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _profession,
                  decoration: const InputDecoration(
                    labelText: 'Health worker profession',
                  ),
                  items: _labProfessions
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) => setState(() => _profession = value),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fill all health worker fields or leave all empty.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Remarks',
          child: TextField(
            controller: _remarksCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Summary',
          child: Column(
            children: [
              _summaryRow('Type', _selectedLabType ?? 'Not set'),
              _summaryRow(
                'Date',
                _date == null
                    ? 'Not set'
                    : DateFormat('yyyy-MM-dd').format(_date!),
              ),
              _summaryRow(
                'Location',
                _locationCtrl.text.trim().isEmpty
                    ? 'Not set'
                    : _locationCtrl.text.trim(),
              ),
              _summaryRow(
                'Image',
                _imageFile == null
                    ? 'No image attached'
                    : 'Image ready to upload',
                valueColor: _imageFile == null
                    ? AppColors.textSecondary
                    : AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Add Lab Test'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pregnancyId == null
              ? const Center(
                  child: Text(
                    'No ongoing pregnancy found for this mother.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ProgressiveStepIndicator(
                          currentStep: _step,
                          totalSteps: _totalSteps,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  'Lab Details',
                                  'Health Worker',
                                  'Remarks & Summary',
                                ][_step],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  'Type, date, location, and image',
                                  'Optional worker identity',
                                  'Final review before saving',
                                ][_step],
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildStep(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (_step > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _submitting ? null : _back,
                                  child: const Text('Back'),
                                ),
                              ),
                            if (_step > 0) const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _submitting
                                    ? null
                                    : (_step == _totalSteps - 1
                                        ? _submit
                                        : _next),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                  foregroundColor: Colors.white,
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_step == _totalSteps - 1
                                        ? 'Save Lab Test'
                                        : 'Next'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
