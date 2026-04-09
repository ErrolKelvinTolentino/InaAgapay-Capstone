import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_storage.dart';
import '../../services/gemini_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
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
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _notesCtrl = TextEditingController();

  DateTime? _date;
  DateTime? _pregnancyLmp;
  DateTime? _pregnancyEdd;
  int? _pregnancyId;
  String? _selectedLabType;

  final List<XFile> _images = [];

  bool _loading = true;
  bool _submitting = false;
  int _step = 0;
  static const int _totalSteps = 2;

  int _analysisRequestId = 0;
  final Set<int> _cancelledRequests = <int>{};
  bool _loadingModalVisible = false;

  String? _aiDraftInsight;
  String? _aiApprovedInsight;
  bool _showAllAi = false;

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
    'Other (specify in notes)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPregnancy();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
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

  void _showMessage(String message,
      {AppSnackType type = AppSnackType.warning}) {
    AppSnackbar.show(context, message, type: type);
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

  Future<void> _pickSingleImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() {
        _images.add(image);
        _aiDraftInsight = null;
        _aiApprovedInsight = null;
      });
    } catch (e) {
      _showMessage('Unable to pick image: $e', type: AppSnackType.error);
    }
  }

  Future<void> _pickMultiFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (images.isEmpty || !mounted) return;
      setState(() {
        _images.addAll(images);
        _aiDraftInsight = null;
        _aiApprovedInsight = null;
      });
    } catch (e) {
      _showMessage('Unable to pick images: $e', type: AppSnackType.error);
    }
  }

  void _openImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Add one or more images'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultiFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Capture one image'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickSingleImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _validateStep1() {
    final now = DateTime.now();
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
      _showMessage('Lab test date cannot be before the current pregnancy LMP.');
      return false;
    }
    if (_pregnancyEdd != null &&
        _date!.isAfter(_pregnancyEdd!.add(const Duration(days: 45)))) {
      _showMessage('Lab test date is too far beyond expected due date.');
      return false;
    }
    return true;
  }

  void _next() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  void _showAiLoadingModal(int requestId) {
    _loadingModalVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Analyzing lab test images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusLine(
                          icon: Icons.image_outlined,
                          text: 'Processing attached images',
                        ),
                        SizedBox(height: 8),
                        _StatusLine(
                          icon: Icons.science_outlined,
                          text: 'Extracting laboratory values',
                        ),
                        SizedBox(height: 8),
                        _StatusLine(
                          icon: Icons.auto_awesome_outlined,
                          text: 'Generating AI insights',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _cancelledRequests.add(requestId);
                        Navigator.of(context).pop();
                        _loadingModalVisible = false;
                        _showMessage('AI analysis canceled.',
                            type: AppSnackType.info);
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _loadingModalVisible = false;
    });
  }

  void _closeAiLoadingModalIfNeeded() {
    if (!_loadingModalVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _loadingModalVisible = false;
  }

  Future<void> _runAiAnalysis() async {
    if (_images.isEmpty) {
      _showMessage('Please add at least one image before AI analysis.');
      return;
    }

    final requestId = ++_analysisRequestId;
    _showAiLoadingModal(requestId);

    try {
      final result = await _geminiService.analyzeLabTestImages(_images);
      if (!mounted || _cancelledRequests.contains(requestId)) return;

      _closeAiLoadingModalIfNeeded();

      final insight = result.description.trim().isEmpty
          ? 'No AI insights generated.'
          : result.description.trim();

      setState(() {
        _aiDraftInsight = insight;
        _showAllAi = false;
      });

      await _showAiInsightsModal();
    } catch (e) {
      if (!mounted || _cancelledRequests.contains(requestId)) return;
      _closeAiLoadingModalIfNeeded();
      _showMessage('AI analysis failed: $e', type: AppSnackType.error);
    } finally {
      _cancelledRequests.remove(requestId);
      _closeAiLoadingModalIfNeeded();
    }
  }

  Future<void> _showAiInsightsModal() async {
    if (_aiDraftInsight == null) return;

    final editCtrl = TextEditingController(text: _aiDraftInsight!);
    final original = _aiDraftInsight!;
    bool isEditing = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxHeight = MediaQuery.of(context).size.height * 0.85;
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  height: maxHeight,
                  child: Column(
                    children: [
                      const LinearProgressIndicator(
                        minHeight: 4,
                        value: 1,
                        color: AppColors.brandPrimary,
                        backgroundColor: AppColors.borderPrimary,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'AI Analysis',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _showAllAi = !_showAllAi;
                                });
                              },
                              child:
                                  Text(_showAllAi ? 'Show Less' : 'Show All'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  isEditing = !isEditing;
                                });
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            if (!isEditing)
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _aiDraftInsight = editCtrl.text.trim();
                                  });
                                  _showMessage('Draft saved.',
                                      type: AppSnackType.success);
                                },
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: isEditing
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: editCtrl,
                                      minLines: 12,
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        hintText: 'Edit AI analysis...',
                                        filled: true,
                                        fillColor: AppColors.bgSecondary,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              setModalState(() {
                                                editCtrl.text = original;
                                                isEditing = false;
                                              });
                                              _showMessage(
                                                'Edit changes discarded.',
                                                type: AppSnackType.info,
                                              );
                                            },
                                            child:
                                                const Text('Discard Changes'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () {
                                              final updated =
                                                  editCtrl.text.trim();
                                              if (updated.isEmpty) {
                                                _showMessage(
                                                  'AI analysis cannot be empty.',
                                                );
                                                return;
                                              }
                                              setState(() {
                                                _aiDraftInsight = updated;
                                              });
                                              setModalState(() {
                                                isEditing = false;
                                              });
                                              _showMessage(
                                                'Changes saved.',
                                                type: AppSnackType.success,
                                              );
                                            },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.brandPrimary,
                                            ),
                                            child: const Text('Save Changes'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Text(
                                  _aiDraftInsight!,
                                  maxLines: _showAllAi ? null : 14,
                                  overflow: _showAllAi
                                      ? TextOverflow.visible
                                      : TextOverflow.fade,
                                  style: const TextStyle(
                                    height: 1.45,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _aiDraftInsight = null;
                                    _aiApprovedInsight = null;
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Discard'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final approvedText = editCtrl.text.trim();
                                  if (approvedText.isEmpty) {
                                    _showMessage(
                                        'AI analysis cannot be empty.');
                                    return;
                                  }
                                  setState(() {
                                    _aiDraftInsight = approvedText;
                                    _aiApprovedInsight = approvedText;
                                  });
                                  Navigator.of(context).pop();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                ),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    editCtrl.dispose();
  }

  Future<Map<String, List<String>>> _uploadImages(List<XFile> images) async {
    final urls = <String>[];
    final paths = <String>[];

    for (final image in images) {
      final bytes = await image.readAsBytes();
      final fileName =
          'lab_${DateTime.now().millisecondsSinceEpoch}_${paths.length}.jpg';
      final filePath = 'lab-tests/${widget.motherId}/$fileName';

      await Supabase.instance.client.storage
          .from('medical-images')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final publicUrl =
          Supabase.instance.client.storage.from('medical-images').getPublicUrl(
                filePath,
              );

      urls.add(publicUrl);
      paths.add(filePath);
    }

    return {
      'urls': urls,
      'paths': paths,
    };
  }

  Future<void> _submit() async {
    if (!_validateStep1()) return;
    if (_pregnancyId == null) {
      _showMessage('No ongoing pregnancy found for this mother.');
      return;
    }

    if (_aiDraftInsight != null && _aiApprovedInsight == null) {
      _showMessage('Approve or discard the AI analysis before saving.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final userId = await AuthStorage.getUserId();
      final upload = _images.isEmpty
          ? {
              'urls': <String>[],
              'paths': <String>[],
            }
          : await _uploadImages(_images);

      final urls = upload['urls'] ?? <String>[];
      final paths = upload['paths'] ?? <String>[];

      final notes = _notesCtrl.text.trim();
      final remarks = _aiApprovedInsight != null
          ? (notes.isEmpty
              ? _aiApprovedInsight!
              : '$notes\n\nAI Analysis:\n${_aiApprovedInsight!}')
          : (notes.isEmpty ? null : notes);

      final inserted = await Supabase.instance.client
          .from('lab_tests')
          .insert({
            'pregnancy_id': _pregnancyId,
            'lab_test_type': _selectedLabType,
            'lab_test_date': DateFormat('yyyy-MM-dd').format(_date!),
            'lab_test_location': 'Not specified',
            'lab_test_image': urls.isEmpty ? null : urls.join(','),
            'remarks': remarks,
          })
          .select('lab_test_id')
          .single();

      final labTestId = inserted['lab_test_id'] as int;

      if (userId != null) {
        for (final path in paths) {
          await Supabase.instance.client.from('files').insert({
            'bucket_name': 'medical-images',
            'file_path': path,
            'file_name': path.split('/').last,
            'file_category': 'lab_test_image',
            'mime_type': 'image/jpeg',
            'uploaded_by': userId,
            'reference_type': 'lab_test',
            'reference_id': labTestId,
            'processing_type': 'manual_upload',
            'ai_processed': _aiApprovedInsight != null,
          });
        }
      }

      if (_aiApprovedInsight != null) {
        await Supabase.instance.client.from('ai_responses').insert({
          'response_type': 'lab_test_analysis',
          'reference_table': 'lab_tests',
          'reference_id': labTestId,
          'ai_model': 'Gemini 1.5 Flash',
          'confidence_score': 0.92,
          'response': _aiApprovedInsight,
          'response_category': 'analysis',
          'status': 'approved',
          'generated_by_ai': true,
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

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Step 1: Test Details'),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lab Test Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppColors.brandPrimary),
                      const SizedBox(width: 10),
                      Text(
                        _date == null
                            ? 'Select date'
                            : DateFormat('MMMM d, yyyy').format(_date!),
                        style: TextStyle(
                          color: _date == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Lab Test Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLabType,
                decoration: const InputDecoration(
                  hintText: 'Select pregnancy-related lab test',
                  border: OutlineInputBorder(),
                ),
                items: _pregnancyLabTests
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedLabType = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(XFile image, int index) {
    return Stack(
      children: [
        Container(
          width: 98,
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              File(image.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.bgSecondary,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            onPressed: () {
              setState(() {
                _images.removeAt(index);
                _aiDraftInsight = null;
                _aiApprovedInsight = null;
              });
            },
            iconSize: 18,
            splashRadius: 18,
            color: AppColors.error,
            icon: const Icon(Icons.cancel),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageTile() {
    return InkWell(
      onTap: _openImagePickerSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 98,
        height: 98,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.55),
          ),
          color: AppColors.bgSecondary,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.brandPrimary),
            SizedBox(height: 6),
            Text(
              'Add Image +',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brandText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Step 2: Attach Images and Notes'),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Image Layout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderPrimary),
                  color: AppColors.bgSecondary.withValues(alpha: 0.35),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      _buildImageTile(_images[i], i),
                    _buildAddImageTile(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Type your notes here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _runAiAnalysis,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI Analyze'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_aiApprovedInsight != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI analysis approved and ready to save.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.brandText,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
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
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _step == 0 ? _buildStep1() : _buildStep2(),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
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
                                    : Text(
                                        _step == _totalSteps - 1
                                            ? 'Save Lab Test'
                                            : 'Next',
                                      ),
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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
