// lib/screens/midwife/ultrasound_analyzer_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/groq_service.dart';
import '../../services/auth_storage.dart';
import '../../models/groq_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/progressive_step_indicator.dart';

class UltrasoundAnalyzerScreen extends StatefulWidget {
  final int motherId;
  final int pregnancyId;

  const UltrasoundAnalyzerScreen({
    super.key,
    required this.motherId,
    required this.pregnancyId,
  });

  @override
  State<UltrasoundAnalyzerScreen> createState() =>
      _UltrasoundAnalyzerScreenState();
}

class _UltrasoundAnalyzerScreenState extends State<UltrasoundAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GroqService _groqService = GroqService();
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  final List<XFile> _selectedImages = [];
  GroqResponse? _combinedResponse;
  bool _isSaving = false;
  String? _errorMessage;

  int _step = 0;
  static const int _totalSteps = 3;
  bool _analysisApproved = false;
  bool _showAdvancedAiDetails = false;
  bool _loadingOverlayVisible = false;
  String _loadingTitle = 'Preparing AI analysis';
  String _loadingDetail = 'Validating images and input context';
  int _analysisRunId = 0;
  final Set<int> _cancelledRunIds = <int>{};
  final Set<String> _expandedAspects = <String>{};
  String? _lastAiPrompt;

  final TextEditingController _notesController = TextEditingController();

  late TextEditingController _healthSummaryController;
  bool _isEditing = false;
  String _healthSummaryBeforeEdit = '';

  DateTime? _ultrasoundDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _healthWorkerNameController =
      TextEditingController();
  final TextEditingController _healthWorkerInstitutionController =
      TextEditingController();
  final TextEditingController _healthWorkerProfessionController =
      TextEditingController();
  String? _selectedHealthWorkerProfession;

  late int _motherId;
  late int _pregnancyId;

  final List<String> _uploadedImageUrls = [];

  static const List<String> _ultrasoundProfessions = [
    'Radiologist',
    'Sonographer',
    'OB-GYN',
    'Midwife',
    'Other (specify)',
  ];
  static const String _otherProfessionOption = 'Other (specify)';

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();

    _ultrasoundDate = DateTime.now();
    _dateController.text = _dateFormat.format(_ultrasoundDate!);

    _motherId = widget.motherId;
    _pregnancyId = widget.pregnancyId;

    _loadUserContext();
  }

  @override
  void dispose() {
    _healthSummaryController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _healthWorkerNameController.dispose();
    _healthWorkerInstitutionController.dispose();
    _healthWorkerProfessionController.dispose();
    super.dispose();
  }

  void _showMessage(String message,
      {AppSnackType type = AppSnackType.warning}) {
    AppSnackbar.show(context, message, type: type);
  }

  Future<void> _loadUserContext() async {
    try {
      await AuthStorage.getUserRole();
    } catch (e) {
      if (kDebugMode) print('Error loading user context: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          _combinedResponse = null;
          _errorMessage = null;
          _isEditing = false;
          _analysisApproved = false;
          _showAdvancedAiDetails = false;
          _healthSummaryController.clear();
          _uploadedImageUrls.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
          _combinedResponse = null;
          _errorMessage = null;
          _isEditing = false;
          _analysisApproved = false;
          _showAdvancedAiDetails = false;
          _healthSummaryController.clear();
          _uploadedImageUrls.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking photo: $e';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _combinedResponse = null;
        _healthSummaryController.clear();
        _uploadedImageUrls.clear();
      }
      _isEditing = false;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _combinedResponse = null;
      _errorMessage = null;
      _isEditing = false;
      _healthSummaryController.clear();
      _uploadedImageUrls.clear();
      _dateController.text = _dateFormat.format(DateTime.now());
      _ultrasoundDate = DateTime.now();
      _healthWorkerNameController.clear();
      _healthWorkerInstitutionController.clear();
      _healthWorkerProfessionController.clear();
      _selectedHealthWorkerProfession = null;
      _analysisApproved = false;
      _showAdvancedAiDetails = false;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ultrasoundDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _ultrasoundDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }

  bool _validateStep1() {
    if (_ultrasoundDate == null) {
      _showMessage('Please select ultrasound date.',
          type: AppSnackType.warning);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_healthWorkerNameController.text.trim().isEmpty) {
      _showMessage('Please enter the health worker\'s full name.',
          type: AppSnackType.warning);
      return false;
    }
    final selected = _effectiveSelectedProfession();
    if (selected == null || selected.trim().isEmpty) {
      _showMessage('Please select the health worker\'s profession.',
          type: AppSnackType.warning);
      return false;
    }
    if (selected == _otherProfessionOption &&
        _healthWorkerProfessionController.text.trim().isEmpty) {
      _showMessage('Please specify the profession.',
          type: AppSnackType.warning);
      return false;
    }
    return true;
  }

  String? _effectiveSelectedProfession() {
    final selected = _selectedHealthWorkerProfession?.trim();
    final text = _healthWorkerProfessionController.text.trim();

    if (selected != null && selected.isNotEmpty) {
      if (selected == _otherProfessionOption) return selected;
      if (_ultrasoundProfessions.contains(selected)) return selected;
    }

    if (text.isEmpty) return null;
    if (_ultrasoundProfessions.contains(text)) return text;
    return _otherProfessionOption;
  }

  bool _validateStep3() {
    if (_selectedImages.isEmpty) {
      _showMessage('Please attach at least one ultrasound image.',
          type: AppSnackType.warning);
      return false;
    }
    return true;
  }

  bool _isAiResultUnrelated(String text) {
    return RegExp(r'RELEVANCE\s*CHECK\s*:\s*UNRELATED', caseSensitive: false)
            .hasMatch(text) ||
        RegExp(r'not\s+ultrasound|unrelated\s+image|unreadable',
                caseSensitive: false)
            .hasMatch(text);
  }

  String _extractRelevanceReason(String text) {
    final match =
        RegExp(r'RELEVANCE\s*REASON\s*:\s*([^\n]+)', caseSensitive: false)
            .firstMatch(text);
    if (match == null) {
      return 'Uploaded content appears unrelated to ultrasound.';
    }
    return match.group(1)?.trim() ??
        'Uploaded content appears unrelated to ultrasound.';
  }

  void _setLoadingState(String title, String detail) {
    if (!mounted) return;
    setState(() {
      _loadingTitle = title;
      _loadingDetail = detail;
    });
  }

  Future<String?> _runImageQualityChecks() async {
    if (_selectedImages.isEmpty) return 'Please attach at least one image.';

    if (_selectedImages.length > 10) {
      return 'Too many images attached. Please keep it to 10 or fewer per record.';
    }

    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final size = await image.length();

      if (size < 25 * 1024) {
        return 'Image ${i + 1} looks too small/low quality. Please upload a clearer photo.';
      }

      if (size > 8 * 1024 * 1024) {
        return 'Image ${i + 1} is too large. Please keep each image below 8MB.';
      }

      try {
        final bytes = await image.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          return 'Image ${i + 1} could not be decoded. Please upload JPG, PNG, WEBP, or another convertible image.';
        }
        final shortestSide =
            decoded.width < decoded.height ? decoded.width : decoded.height;
        if (shortestSide < 400) {
          return 'Image ${i + 1} resolution is too low (minimum 400px on the shortest side). Retake in better lighting and closer framing.';
        }
      } catch (_) {
        return 'Image ${i + 1} could not be read. Please re-upload a clear image.';
      }
    }

    return null;
  }

  Future<
      ({
        Uint8List bytes,
        String contentType,
        String extension,
        bool converted,
      })> _prepareImageForUpload(XFile image) async {
    final rawBytes = await image.readAsBytes();
    final ext = image.path.split('.').last.toLowerCase();

    if (ext == 'jpg' || ext == 'jpeg') {
      return (
        bytes: Uint8List.fromList(rawBytes),
        contentType: 'image/jpeg',
        extension: 'jpg',
        converted: false,
      );
    }

    if (ext == 'png') {
      return (
        bytes: Uint8List.fromList(rawBytes),
        contentType: 'image/png',
        extension: 'png',
        converted: false,
      );
    }

    if (ext == 'webp') {
      return (
        bytes: Uint8List.fromList(rawBytes),
        contentType: 'image/webp',
        extension: 'webp',
        converted: false,
      );
    }

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception(
          'Unsupported image format detected. Please upload convertible image files.');
    }

    final convertedBytes =
        Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
    return (
      bytes: convertedBytes,
      contentType: 'image/jpeg',
      extension: 'jpg',
      converted: true,
    );
  }

  void _nextStep() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step == 1 && !_validateStep2()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  Future<void> _analyzeImages() async {
    if (!_validateStep1() || !_validateStep2() || !_validateStep3()) return;

    _setLoadingState(
      'Checking image quality',
      'Validating image format, size, and readability',
    );
    final imageQualityIssue = await _runImageQualityChecks();
    if (imageQualityIssue != null) {
      _showMessage(imageQualityIssue, type: AppSnackType.warning);
      return;
    }

    final runId = ++_analysisRunId;
    _setLoadingState(
      'Preparing AI analysis',
      'Checking images and clinical context',
    );
    _showLoadingOverlay(runId);

    setState(() {
      _errorMessage = null;
      _combinedResponse = null;
      _isEditing = false;
      _analysisApproved = false;
      _healthSummaryController.clear();
    });

    try {
      _lastAiPrompt = [
        'Ultrasound AI analysis request',
        'Health worker name: ${_healthWorkerNameController.text.trim().isEmpty ? 'Not specified' : _healthWorkerNameController.text.trim()}',
        'Health worker institution: ${_healthWorkerInstitutionController.text.trim().isEmpty ? 'Not specified' : _healthWorkerInstitutionController.text.trim()}',
        'Health worker profession: ${_effectiveSelectedProfession() ?? 'Not specified'}',
        'Notes: ${_notesController.text.trim().isEmpty ? 'None provided' : _notesController.text.trim()}',
        'Image count: ${_selectedImages.length}',
      ].join('\n');

      _setLoadingState(
        'Reading ultrasound images',
        'Extracting ultrasound observations and measurements',
      );

      final result = await _groqService.analyzeUltrasoundImages(
        _selectedImages,
        clinicalContext: _lastAiPrompt,
      );
      if (!mounted || _cancelledRunIds.contains(runId)) return;

      _setLoadingState(
        'Finalizing insights',
        'Checking relevance and preparing summary',
      );

      if (_isAiResultUnrelated(result.description)) {
        _closeLoadingOverlayIfNeeded();
        _showMessage(
          'AI flagged unrelated upload: ${_extractRelevanceReason(result.description)}',
          type: AppSnackType.warning,
        );
        return;
      }

      _closeLoadingOverlayIfNeeded();

      setState(() {
        _combinedResponse = result;

        if (result.description.isNotEmpty) {
          _healthSummaryController.text = result.description;
        } else {
          _healthSummaryController.text = "No analysis available";
        }
      });

      await _showInsightsModal();
    } catch (e) {
      if (!mounted || _cancelledRunIds.contains(runId)) return;
      _closeLoadingOverlayIfNeeded();
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      _showMessage(_errorMessage!, type: AppSnackType.error);
    } finally {
      _cancelledRunIds.remove(runId);
      _closeLoadingOverlayIfNeeded();
    }
  }

  Future<void> _saveToDatabase() async {
    if (!_validateStep1() || !_validateStep2() || !_validateStep3()) return;
    final aiGenerated = _combinedResponse != null;
    if (aiGenerated && !_analysisApproved) {
      _showMessage('Please approve the AI analysis before saving.',
          type: AppSnackType.warning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = await AuthStorage.getUserId();

      if (userId == null) {
        throw Exception('User not logged in');
      }

      _uploadedImageUrls.clear();

      final List<String> uploadedFilePaths = [];
      final List<int> fileIds = [];
      int convertedCount = 0;
      int storageFailureCount = 0;

      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          final image = _selectedImages[i];
          final preparedUpload = await _prepareImageForUpload(image);
          final bytes = preparedUpload.bytes;
          if (preparedUpload.converted) {
            convertedCount += 1;
          }
          final fileName =
              'ultrasound_${DateTime.now().millisecondsSinceEpoch}_$i.${preparedUpload.extension}';
          final filePath = 'ultrasounds/$_motherId/$fileName';

          await Supabase.instance.client.storage.from('files').uploadBinary(
                filePath,
                bytes,
                fileOptions:
                    FileOptions(contentType: preparedUpload.contentType),
              );

          final publicUrl = Supabase.instance.client.storage
              .from('files')
              .getPublicUrl(filePath);

          uploadedFilePaths.add(filePath);
          _uploadedImageUrls.add(publicUrl);

          final fileResponse = await Supabase.instance.client
              .from('files')
              .insert({
                'bucket_name': 'files',
                'file_path': filePath,
                'file_name': fileName,
                'file_category': 'ultrasound_image',
                'mime_type': preparedUpload.contentType,
                'file_size': bytes.length,
                'uploaded_by': userId,
                'reference_type': 'ultrasound',
                'processing_type': 'ultrasound_analysis',
                'ai_processed': aiGenerated,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select('file_id')
              .single();

          fileIds.add(fileResponse['file_id'] as int);
        } catch (uploadError) {
          storageFailureCount += 1;
          if (kDebugMode) {
            print('Storage upload skipped for image $i: $uploadError');
          }
        }
      }

      final profession = _effectiveSelectedProfession();
      final finalProfession = profession == _otherProfessionOption
          ? _healthWorkerProfessionController.text.trim()
          : profession ?? '';

      final ultrasoundResponse = await Supabase.instance.client
          .from('ultrasounds')
          .insert({
            'pregnancy_id': _pregnancyId,
            'ultrasound_date': _ultrasoundDate!.toIso8601String().split('T')[0],
            'ultrasound_location': 'Mobile Upload',
            'ultrasound_image': _uploadedImageUrls.isNotEmpty
                ? _uploadedImageUrls.join(',')
                : null,
            'remarks': _healthSummaryController.text.trim().isEmpty
                ? null
                : _healthSummaryController.text.trim(),
            'health_worker_name': _healthWorkerNameController.text.trim(),
            'health_worker_institution':
                _healthWorkerInstitutionController.text.trim().isEmpty
                    ? null
                    : _healthWorkerInstitutionController.text.trim(),
            'health_worker_profession': finalProfession,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('ultrasound_id')
          .single();

      final ultrasoundId = ultrasoundResponse['ultrasound_id'] as int;

      if (aiGenerated) {
        final finalAiText = _healthSummaryController.text.trim();
        final originalAiText = (_combinedResponse?.description ?? '').trim();
        final aiWasEdited =
            originalAiText.isNotEmpty && finalAiText != originalAiText;

        final insertedAi = await Supabase.instance.client
            .from('ai_responses')
            .insert({
              'response_type': 'ultrasound_analysis',
              'reference_table': 'ultrasounds',
              'reference_id': ultrasoundId,
              'ai_model': 'Gemini 1.5 Flash',
              'confidence_score': null,
              'response': finalAiText,
              'response_category': 'analysis',
              'status': 'approved',
              'generated_by_ai': true,
              'approved_by': userId,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('ai_response_id')
            .single();

        final aiResponseId = insertedAi['ai_response_id'] as int;

        if ((_lastAiPrompt ?? '').trim().isNotEmpty) {
          await Supabase.instance.client.from('ai_prompt_logs').insert({
            'ai_response_id': aiResponseId,
            'prompt': _lastAiPrompt,
            'model_used': 'Gemini 1.5 Flash',
          });
        }

        if (aiWasEdited) {
          await Supabase.instance.client.from('ai_edit_history').insert({
            'ai_response_id': aiResponseId,
            'old_content': originalAiText,
            'new_content': finalAiText,
            'edited_by': userId,
            'edit_reason':
                'Midwife edited AI ultrasound analysis before final save.',
          });
        }

        await Supabase.instance.client.from('audit_trail').insert({
          'action': 'AI_APPROVAL',
          'table_name': 'ai_responses',
          'account_id': userId,
          'old_data': {
            'status': aiWasEdited ? 'edited' : 'generated',
            'approved_by': null,
          },
          'new_data': {
            'ai_response_id': aiResponseId,
            'status': 'approved',
            'approved_by': userId,
            'reference_table': 'ultrasounds',
            'reference_id': ultrasoundId,
          },
          'description':
              'Midwife approved AI ultrasound analysis for ultrasound_id=$ultrasoundId.',
        });
      }

      for (int fileId in fileIds) {
        await Supabase.instance.client.from('files').update({
          'reference_id': ultrasoundId,
        }).eq('file_id', fileId);
      }

      if (!mounted) return;
      if (convertedCount > 0) {
        _showMessage(
          '$convertedCount image(s) were automatically converted to an acceptable format.',
          type: AppSnackType.info,
        );
      }
      if (storageFailureCount > 0) {
        _showMessage(
          'Record saved, but $storageFailureCount image upload(s) were blocked by storage permissions.',
          type: AppSnackType.warning,
        );
      }
      _showMessage('Ultrasound analysis saved successfully!',
          type: AppSnackType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to database: $e');
      }

      if (!mounted) return;
      _showMessage('Error saving: ${e.toString()}', type: AppSnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // UI BUILDERS
  // ============================================================

  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final List<Widget> sections = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Section headers (ALL CAPS)
      if (line.length > 2 &&
          line == line.toUpperCase() &&
          !line.contains(RegExp(r'[0-9]'))) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.1),
                    AppColors.brandSecondary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.2)),
              ),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      }
      // Bullet points
      else if (line.startsWith('•') ||
          line.startsWith('-') ||
          line.startsWith('*')) {
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary,
                        AppColors.brandSecondary
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Status messages
      else if (line.contains('✅') || line.contains('NORMAL')) {
        sections.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Warning messages
      else if (line.contains('⚠️') ||
          line.contains('MONITORING') ||
          line.contains('CONCERN')) {
        sections.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Regular text
      else {
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Map<String, List<String>> _extractInsightSections(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).toList();

    final Map<String, List<String>> sections = {};
    String currentSection = 'Summary';
    sections[currentSection] = [];

    final headingPattern = RegExp(
      r'^(?:\d+\.\s*)?(RELEVANCE CHECK|RELEVANCE REASON|OVERALL HEALTH STATUS|OVERALL ASSESSMENT|GESTATIONAL AGE ASSESSMENT|DETAILED MEASUREMENTS ASSESSMENT|ANATOMICAL ASSESSMENT|ABNORMAL FINDINGS|RECOMMENDED NEXT ACTIONS|KEY OBSERVATIONS)\s*:?\s*(.*)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (RegExp(r'^[-_=]{2,}$').hasMatch(line.replaceAll(' ', ''))) continue;

      final heading = headingPattern.firstMatch(line);
      if (heading != null) {
        currentSection = heading.group(1)!.toUpperCase();
        sections.putIfAbsent(currentSection, () => []);
        final inlineContent = heading.group(2)?.trim() ?? '';
        if (inlineContent.isNotEmpty && inlineContent != ':') {
          sections[currentSection]!.add(inlineContent);
        }
        continue;
      }

      sections.putIfAbsent(currentSection, () => []);
      sections[currentSection]!.add(line);
    }

    sections.removeWhere((_, value) => value.isEmpty);
    return sections;
  }

  String _safeText(Object? value) => value?.toString() ?? '';

  bool _isConcerningStatus(String status) {
    final s = status.toUpperCase();
    return s.contains('REVIEW') ||
        s.contains('ABNORMAL') ||
        s.contains('CONCERNING');
  }

  bool _isCautionStatus(String status) {
    final s = status.toUpperCase();
    return s == 'OBSERVE' || s == 'BORDERLINE' || s == 'MONITOR';
  }

  Color _statusChipBackground(String status) {
    if (_isConcerningStatus(status)) return AppColors.error.withValues(alpha: 0.08);
    if (_isCautionStatus(status)) return AppColors.warning.withValues(alpha: 0.08);
    return AppColors.success.withValues(alpha: 0.08);
  }

  Color _statusChipBorder(String status) {
    if (_isConcerningStatus(status)) return AppColors.error.withValues(alpha: 0.25);
    if (_isCautionStatus(status)) return AppColors.warning.withValues(alpha: 0.25);
    return AppColors.success.withValues(alpha: 0.25);
  }

  Color _statusChipTextColor(String status) {
    if (_isConcerningStatus(status)) return AppColors.error;
    if (_isCautionStatus(status)) return AppColors.warning;
    return AppColors.success;
  }

  ({String testName, String value, String status, String remark})
      _parseUltrasoundMetricLine(String line) {
    final cleaned =
        _safeText(line).replaceFirst(RegExp(r'^[-\*•]\s*'), '').trim();

    String testName = '';
    String value = '';
    String status = 'UNKNOWN';
    String remark = '';

    final bracketMatch = RegExp(r'\[(.*?)\]').firstMatch(cleaned);

    if (bracketMatch != null) {
      status = bracketMatch.group(1)!.trim().toUpperCase();
      testName = cleaned.substring(0, bracketMatch.start).trim();

      final colonIdx = testName.indexOf(':');
      if (colonIdx != -1) {
        value = testName.substring(colonIdx + 1).trim();
        testName = testName.substring(0, colonIdx).trim();
      }

      remark = cleaned.substring(bracketMatch.end).trim();
      remark = remark.replaceFirst(RegExp(r'^[-:]\s*'), '').trim();
    } else {
      final colonIndex = cleaned.indexOf(':');
      if (colonIndex != -1) {
        testName = cleaned.substring(0, colonIndex).trim();
        String rest = cleaned.substring(colonIndex + 1).trim();

        final parenMatch = RegExp(r'\(([^)]+)\)$').firstMatch(rest);
        if (parenMatch != null) {
          remark = parenMatch.group(1)!.trim();
          rest = rest.substring(0, parenMatch.start).trim();
        }

        if (rest.startsWith('✓') ||
            rest.toLowerCase() == 'normal' ||
            rest.toLowerCase() == 'present') {
          value = 'Present / Normal';
          status = 'NORMAL';
        } else if (rest.startsWith('X') ||
            rest.startsWith('✗') ||
            rest.toLowerCase() == 'abnormal' ||
            rest.toLowerCase() == 'absent') {
          value = 'Absent / Abnormal';
          status = 'ABNORMAL';
        } else {
          final dashIndex = rest.lastIndexOf('-');
          if (dashIndex != -1) {
            final possibleStatus =
                rest.substring(dashIndex + 1).trim().toUpperCase();
            if (possibleStatus == 'NORMAL' ||
                possibleStatus == 'ABNORMAL' ||
                possibleStatus == 'REVIEW' ||
                possibleStatus == 'MONITOR' ||
                possibleStatus == 'BORDERLINE' ||
                possibleStatus == 'CONCERNING') {
              status = possibleStatus;
              value = rest.substring(0, dashIndex).trim();
            } else {
              value = rest;
            }
          } else {
            value = rest;
          }
        }
      } else {
        return (testName: cleaned, value: '', status: 'UNKNOWN', remark: '');
      }
    }

    if (status == 'CONCERNING') status = 'ABNORMAL';

    return (testName: testName, value: value, status: status, remark: remark);
  }

  Widget _buildMetricsList(List<String> lines) {
    final rows = lines
        .map(_parseUltrasoundMetricLine)
        .where((r) => r.testName.isNotEmpty)
        .toList();

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.replaceFirst(RegExp(r'^[-\-*]\s*'), '').trim(),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((row) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderPrimary),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.testName,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (row.status != 'UNKNOWN' && row.status != 'INFO')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusChipBackground(row.status),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: _statusChipBorder(row.status)),
                      ),
                      child: Text(
                        row.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusChipTextColor(row.status),
                        ),
                      ),
                    ),
                  if (row.value.isNotEmpty &&
                      row.value != 'Present / Normal' &&
                      row.value != 'Absent / Abnormal')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (row.remark.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  row.remark,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStructuredInsights(String text, {VoidCallback? onInteraction}) {
    final sections = _extractInsightSections(text);
    if (sections.isEmpty) return _buildFormattedText(text);

    final sectionOrder = [
      'OVERALL HEALTH STATUS',
      'OVERALL ASSESSMENT',
      'GESTATIONAL AGE ASSESSMENT',
      'DETAILED MEASUREMENTS ASSESSMENT',
      'ANATOMICAL ASSESSMENT',
      'ABNORMAL FINDINGS',
      'RECOMMENDED NEXT ACTIONS',
      'KEY OBSERVATIONS',
      'SUMMARY',
    ];

    final orderedEntries = <MapEntry<String, List<String>>>[];
    for (final key in sectionOrder) {
      if (sections.containsKey(key)) {
        orderedEntries.add(MapEntry(key, sections[key]!));
      }
    }
    for (final entry in sections.entries) {
      if (!sectionOrder.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    final widgets = <Widget>[];
    for (final entry in orderedEntries) {
      if (entry.key == 'RELEVANCE CHECK' || entry.key == 'RELEVANCE REASON') {
        continue;
      }

      final isMeasurements = entry.key == 'DETAILED MEASUREMENTS ASSESSMENT';
      final isAnatomical = entry.key == 'ANATOMICAL ASSESSMENT';
      final isAbnormal = entry.key == 'ABNORMAL FINDINGS';

      Color accentColor;
      IconData icon;
      if (entry.key.contains('HEALTH STATUS')) {
        final hasHealthy =
            entry.value.any((v) => v.toLowerCase().contains('healthy'));
        accentColor = hasHealthy ? AppColors.success : AppColors.warning;
        icon = Icons.monitor_heart_outlined;
      } else if (isMeasurements) {
        accentColor = Colors.teal;
        icon = Icons.straighten;
      } else if (isAnatomical) {
        accentColor = AppColors.success;
        icon = Icons.child_care_outlined;
      } else if (isAbnormal) {
        accentColor = AppColors.error;
        icon = Icons.warning_amber_rounded;
      } else if (entry.key.contains('RECOMMENDED')) {
        accentColor = Colors.blue;
        icon = Icons.lightbulb_outline;
      } else {
        accentColor = AppColors.brandPrimary;
        icon = Icons.article_outlined;
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _friendlySectionTitle(entry.key),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isMeasurements || isAnatomical || isAbnormal)
                _buildMetricsList(entry.value)
              else
                ...entry.value.map((line) {
                  final cleaned =
                      line.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: _buildFormattedText(cleaned)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  String _friendlySectionTitle(String title) {
    switch (title) {
      case 'OVERALL HEALTH STATUS':
        return 'Health Status';
      case 'OVERALL ASSESSMENT':
        return 'Overall Assessment';
      case 'GESTATIONAL AGE ASSESSMENT':
        return 'Gestational Age';
      case 'DETAILED MEASUREMENTS ASSESSMENT':
        return 'Measurements';
      case 'ANATOMICAL ASSESSMENT':
        return 'Anatomical Findings';
      case 'ABNORMAL FINDINGS':
        return 'Abnormal Findings / Concerns';
      case 'RECOMMENDED NEXT ACTIONS':
        return 'Recommended Actions';
      default:
        return title
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0]}${w.substring(1).toLowerCase()}' : w)
            .join(' ');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add Ultrasound Images',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.teal.shade700),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple images'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue.shade700),
              ),
              title: const Text('Take a Photo'),
              subtitle: const Text('Capture new image'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLoadingOverlay(int runId) {
    _loadingOverlayVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loadingTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _StatusLine(
                    icon: Icons.auto_awesome_outlined,
                    text: _loadingDetail,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _cancelledRunIds.add(runId);
                      Navigator.of(context).pop();
                      _loadingOverlayVisible = false;
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
      ),
    ).then((_) {
      _loadingOverlayVisible = false;
    });
  }

  void _closeLoadingOverlayIfNeeded() {
    if (!_loadingOverlayVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _loadingOverlayVisible = false;
  }

  Future<void> _showInsightsModal() async {
    if (_combinedResponse == null) return;
    final summaryDraft =
        TextEditingController(text: _healthSummaryController.text);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.84,
                  child: Column(
                    children: [
                      const LinearProgressIndicator(
                        minHeight: 4,
                        value: 1,
                        color: AppColors.brandPrimary,
                        backgroundColor: AppColors.borderPrimary,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'AI Analysis',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final updated =
                                    await Navigator.of(context).push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => _AiInsightsEditorPage(
                                      initialText: summaryDraft.text,
                                    ),
                                  ),
                                );
                                if (updated == null) return;
                                setModalState(() {
                                  summaryDraft.text = updated;
                                });
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Open Editor'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () {
                                final txt = summaryDraft.text.trim();
                                if (txt.isEmpty) {
                                  _showMessage('AI analysis cannot be empty.');
                                  return;
                                }
                                setState(() {
                                  _healthSummaryController.text = txt;
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
                          child: _buildStructuredInsights(
                            summaryDraft.text,
                            onInteraction: () => setModalState(() {}),
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
                                  Navigator.pop(context);
                                },
                                child: const Text('Close'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final txt = summaryDraft.text.trim();
                                  if (txt.isEmpty) {
                                    _showMessage(
                                        'AI analysis cannot be empty.');
                                    return;
                                  }
                                  setState(() {
                                    _healthSummaryController.text = txt;
                                    _analysisApproved = true;
                                  });
                                  Navigator.pop(context);
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

    summaryDraft.dispose();
  }

  String _getHealthStatus() {
    if (_combinedResponse == null) return 'Assessment Complete';

    final sections = _extractInsightSections(_healthSummaryController.text);
    final healthStatus = sections['OVERALL HEALTH STATUS'] ?? const <String>[];

    if (healthStatus.isNotEmpty) {
      final statusText = healthStatus.join(' ').toLowerCase();
      if (statusText.contains('healthy')) return 'HEALTHY PREGNANCY';
      if (statusText.contains('monitoring') ||
          statusText.contains('follow-up')) {
        return 'REQUIRES MONITORING';
      }
    }

    final abnormal = sections['ABNORMAL FINDINGS'] ?? const <String>[];
    if (abnormal.isNotEmpty) return 'REVIEW FLAGGED FINDINGS';

    return 'ASSESSMENT COMPLETE';
  }

  Color _getHealthStatusColor() {
    final status = _getHealthStatus();
    if (status.contains('HEALTHY')) return AppColors.success;
    if (status.contains('MONITORING')) return AppColors.warning;
    if (status.contains('REVIEW')) return AppColors.error;
    return AppColors.brandPrimary;
  }

  IconData _getHealthStatusIcon() {
    final status = _getHealthStatus();
    if (status.contains('HEALTHY')) return Icons.check_circle;
    if (status.contains('MONITORING')) return Icons.warning;
    if (status.contains('REVIEW')) return Icons.warning_amber_rounded;
    return Icons.info;
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Step 1: Ultrasound Details',
          subtitle: 'Set the date and enter study details.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Study Date',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 20, color: AppColors.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ultrasound Date',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              _dateController.text,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBox() {
    return Container(
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
          for (int i = 0; i < _selectedImages.length; i++)
            Stack(
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
                    child: kIsWeb
                        ? Image.network(_selectedImages[i].path,
                            fit: BoxFit.cover)
                        : Image.file(File(_selectedImages[i].path),
                            fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: IconButton(
                    onPressed: () => _removeImage(i),
                    iconSize: 18,
                    splashRadius: 18,
                    color: AppColors.error,
                    icon: const Icon(Icons.cancel),
                  ),
                ),
              ],
            ),
          InkWell(
            onTap: _showImageSourceDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.55)),
                color: AppColors.bgSecondary,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: AppColors.brandPrimary),
                  SizedBox(height: 6),
                  Text(
                    'Add Image +',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.brandText,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Step 2: Health Worker Information',
          subtitle:
              'Enter the responsible health worker details before analysis.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health Worker Information',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Required: Full name and profession',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _healthWorkerNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _healthWorkerInstitutionController,
                decoration: const InputDecoration(
                  labelText: 'Institution/Clinic',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final effectiveSelected = _effectiveSelectedProfession();
                  final dropdownValue =
                      (_ultrasoundProfessions.contains(effectiveSelected) ||
                              effectiveSelected == _otherProfessionOption)
                          ? effectiveSelected
                          : null;

                  final dropdownItems = [
                    ..._ultrasoundProfessions,
                  ];

                  return DropdownButtonFormField<String>(
                    initialValue: dropdownValue,
                    decoration: const InputDecoration(
                      labelText: 'Profession *',
                      border: OutlineInputBorder(),
                    ),
                    items: dropdownItems
                        .map((profession) => DropdownMenuItem<String>(
                              value: profession,
                              child: Text(profession),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedHealthWorkerProfession = value;
                        if (value != null && value != _otherProfessionOption) {
                          _healthWorkerProfessionController.text = value;
                        }
                      });
                    },
                  );
                },
              ),
              if (_effectiveSelectedProfession() == _otherProfessionOption) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _healthWorkerProfessionController,
                  decoration: const InputDecoration(
                    labelText: 'Specify Profession *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Step 3: Attach Images and Notes',
          subtitle:
              'Attach ultrasound images, add notes, then run and review AI analysis.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Image Layout',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Required: Add at least one ultrasound image',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _buildImageBox(),
              const SizedBox(height: 16),
              const Text('Notes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Optional context. AI uses this during analysis if provided.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _analyzeImages,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Run AI Analysis'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_combinedResponse != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showInsightsModal,
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('Open AI Insights'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_analysisApproved)
                          const Chip(
                            label: Text('Approved'),
                            avatar: Icon(Icons.check_circle,
                                color: AppColors.success, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getHealthStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                _getHealthStatusColor().withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(_getHealthStatusIcon(),
                              color: _getHealthStatusColor()),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getHealthStatus(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _getHealthStatusColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => setState(() =>
                          _showAdvancedAiDetails = !_showAdvancedAiDetails),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderPrimary),
                          color: AppColors.bgSecondary,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvancedAiDetails
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showAdvancedAiDetails
                                  ? 'Hide Advanced AI Details'
                                  : 'Show Advanced AI Details',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAdvancedAiDetails) ...[
                      const SizedBox(height: 10),
                      _buildEditableSection(),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableSection() {
    if (_combinedResponse == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!_isEditing)
              IconButton(
                onPressed: () {
                  setState(() {
                    _healthSummaryBeforeEdit = _healthSummaryController.text;
                    _isEditing = true;
                  });
                },
                icon: Icon(Icons.edit, color: AppColors.brandPrimary),
                tooltip: 'Edit notes',
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    icon: Icon(Icons.save, color: AppColors.success),
                    tooltip: 'Save changes',
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _healthSummaryController.text =
                            _healthSummaryBeforeEdit;
                        _isEditing = false;
                      });
                    },
                    icon: Icon(Icons.close, color: AppColors.error),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderPrimary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.health_and_safety,
                        color: AppColors.brandPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Clinical Assessment',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                _buildStructuredInsights(_healthSummaryController.text)
              else
                TextField(
                  controller: _healthSummaryController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: 'Enter clinical assessment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.5),
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
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ultrasound Assessment',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandText),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete_sweep, color: AppColors.error),
                      onPressed: _clearAll,
                      tooltip: 'Clear all images',
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.person,
                                      size: 20, color: Colors.teal.shade700),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mother #$_motherId',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal),
                                      ),
                                      Text(
                                        'Pregnancy ID: $_pregnancyId',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.teal.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ProgressiveStepIndicator(
                            currentStep: _step,
                            totalSteps: _totalSteps,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.borderPrimary),
                            ),
                            child: Text(
                              _step == 0
                                  ? 'Complete ultrasound details first, then continue.'
                                  : _step == 1
                                      ? 'Enter health worker details before proceeding.'
                                      : 'Attach images, optionally run AI analysis, and approve AI only if you generated one before saving.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _step == 0
                              ? _buildStep1()
                              : _step == 1
                                  ? _buildStep2()
                                  : _buildStep3(),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _prevStep,
                              child: const Text('Back'),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _step == _totalSteps - 1
                              ? (_isSaving
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppColors.success),
                                        ),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _saveToDatabase,
                                      icon: const Icon(Icons.save_outlined),
                                      label: const Text('Save to Records'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.brandPrimary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ))
                              : FilledButton(
                                  onPressed: _nextStep,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Next'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.brandText),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
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
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _AiInsightsEditorPage extends StatefulWidget {
  const _AiInsightsEditorPage({required this.initialText});

  final String initialText;

  @override
  State<_AiInsightsEditorPage> createState() => _AiInsightsEditorPageState();
}

class _AiInsightsEditorPageState extends State<_AiInsightsEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit AI Insights'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 20,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Type or edit AI insights here...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(context, text);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
