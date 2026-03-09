import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/progressive_step_indicator.dart';

class AddUltrasoundPage extends StatefulWidget {
  final int motherId;
  const AddUltrasoundPage({super.key, required this.motherId});

  @override
  State<AddUltrasoundPage> createState() => _AddUltrasoundPageState();
}

class _AddUltrasoundPageState extends State<AddUltrasoundPage> {
  DateTime? _date;
  int? _pregnancyId;
  bool _loading = true;
  bool _submitting = false;
  int _step = 0;
  static const int _totalSteps = 3;
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  static const List<String> _ultrasoundProfessions = [
    'Radiologist',
    'Sonographer',
    'OB-GYN',
  ];

  final _locationCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _workerNameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  String? _profession;

  @override
  void initState() {
    super.initState();
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
    final token = await AuthStorage.getToken();
    final res = await http.get(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/get_active_pregnancy.php'
        '?mother_id=${widget.motherId}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    final decoded = jsonDecode(res.body);

    if (decoded['success'] == true) {
      _pregnancyId = decoded['pregnancy_id'];
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_pregnancyId == null || _date == null) return;
    setState(() => _submitting = true);

    try {
      final token = await AuthStorage.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/add_ultrasound.php',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll({
        'pregnancy_id': _pregnancyId.toString(),
        'ultrasound_date': DateFormat('yyyy-MM-dd').format(_date!),
        'ultrasound_location': _locationCtrl.text,
        'remarks': _remarksCtrl.text,
        'health_worker_name': _workerNameCtrl.text,
        'health_worker_institution': _institutionCtrl.text,
        'health_worker_profession': _profession ?? '',
      });

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'ultrasound_image',
            _imageFile!.path,
          ),
        );
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(res.body);

      if (!mounted) return;
      if (decoded['success'] == true) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decoded['message'] ?? 'Save failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _validateStep() {
    String? message;
    switch (_step) {
      case 0:
        if (_date == null) {
          message = 'Ultrasound date is required.';
        } else if (_date!.isAfter(DateTime.now())) {
          message = 'Future ultrasound dates are not allowed.';
        }
        break;
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final initial = _date != null && _date!.isBefore(today) ? _date! : today;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDate: initial,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  Widget _imagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ultrasound Image (optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: _imageFile == null
                ? Row(
                    children: const [
                      Icon(Icons.upload_file, color: AppColors.brandText),
                      SizedBox(width: 10),
                      Text('Tap to upload an image'),
                    ],
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imageFile!.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _imageFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _imageFile = null),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _controls({bool showSubmit = false}) {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(
            onPressed: _submitting ? null : _back,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandAccent,
            ),
            child: const Text('Back'),
          ),
        const Spacer(),
        if (showSubmit)
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_submitting ? 'Saving...' : 'Save & Finish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 48),
            ),
          )
        else
          ElevatedButton(
            onPressed: _submitting ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 48),
            ),
            child: const Text('Next'),
          ),
      ],
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _date == null
                    ? 'Select Ultrasound Date'
                    : DateFormat('MMMM d, yyyy').format(_date!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            AppInputField(hintText: 'Location', controller: _locationCtrl),
            const SizedBox(height: 12),
            _imagePicker(),
            const SizedBox(height: 20),
            _controls(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppInputField(
              hintText: 'Health Worker',
              controller: _workerNameCtrl,
            ),
            const SizedBox(height: 12),
            AppInputField(
              hintText: 'Institution',
              controller: _institutionCtrl,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _profession,
              decoration: const InputDecoration(
                labelText: 'Profession',
                border: OutlineInputBorder(),
              ),
              items: _ultrasoundProfessions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _profession = v),
            ),
            const SizedBox(height: 20),
            _controls(),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _remarksCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _infoChip(
              'Date',
              _date == null ? '—' : DateFormat('yyyy-MM-dd').format(_date!),
            ),
            const SizedBox(height: 20),
            _controls(showSubmit: true),
          ],
        );
    }
  }

  Widget _infoChip(String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Text('$label: $value'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_pregnancyId == null) {
      return const Scaffold(
        body: Center(child: Text('No active pregnancy found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Ultrasound (${_step + 1} of $_totalSteps)'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressiveStepIndicator(
              currentStep: _step,
              totalSteps: _totalSteps,
            ),
            const SizedBox(height: 12),
            Text(
              [
                'Ultrasound Details',
                'Health Worker',
                'Remarks & Summary',
              ][_step],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brandText,
              ),
            ),
            const SizedBox(height: 16),
            _stepContent(),
          ],
        ),
      ),
    );
  }
}
