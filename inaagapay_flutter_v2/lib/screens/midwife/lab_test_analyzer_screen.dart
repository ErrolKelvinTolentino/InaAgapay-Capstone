// lib/screens/midwife/lab_test_analyzer_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_service.dart';
import '../../services/auth_storage.dart';
import '../../models/gemini_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/progressive_step_indicator.dart';

class LabTestAnalyzerScreen extends StatefulWidget {
  final int motherId;
  final int pregnancyId;

  const LabTestAnalyzerScreen({
    super.key,
    required this.motherId,
    required this.pregnancyId,
  });

  @override
  State<LabTestAnalyzerScreen> createState() => _LabTestAnalyzerScreenState();
}

class _LabTestAnalyzerScreenState extends State<LabTestAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  final List<XFile> _selectedImages = [];
  GeminiResponse? _combinedResponse;
  bool _isSaving = false;
  String? _errorMessage;

  int _step = 0;
  static const int _totalSteps = 3;
  String? _selectedLabType;
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

  DateTime? _labTestDate;
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

  static const List<String> _acceptedLabProfessions = [
    'Medical Technologist',
    'Pathologist',
    'Physician',
    'Nurse',
    'Midwife',
    'Phlebotomist',
  ];
  static const String _otherProfessionOption = 'Other (specify)';

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();

    _labTestDate = DateTime.now();
    _dateController.text = _dateFormat.format(_labTestDate!);

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
      _labTestDate = DateTime.now();
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
      initialDate: _labTestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _labTestDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }

  bool _validateForm() {
    if (!_validateStep1()) return false;
    if (!_validateStep2()) return false;
    if (!_validateStep3()) return false;
    return true;
  }

  bool _validateStep1() {
    if (_labTestDate == null) {
      _showMessage('Please select lab test date.', type: AppSnackType.warning);
      return false;
    }
    if (_selectedLabType == null || _selectedLabType!.isEmpty) {
      _showMessage('Please select lab test type.', type: AppSnackType.warning);
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
      return selected;
    }

    if (text.isEmpty) return null;
    if (_acceptedLabProfessions.contains(text)) return text;
    return _otherProfessionOption;
  }

  bool _validateStep3() {
    if (_selectedImages.isEmpty) {
      _showMessage('Please attach at least one lab test image.',
          type: AppSnackType.warning);
      return false;
    }

    final noteError = _validateNotesInput();
    if (noteError != null) {
      _showMessage(noteError, type: AppSnackType.warning);
      return false;
    }

    return true;
  }

  String? _validateNotesInput() {
    final notes = _notesController.text.trim();

    if ((_selectedLabType ?? '').startsWith('Other') && notes.isEmpty) {
      return 'Please specify details in notes when lab test type is Other.';
    }

    if (notes.length > 1200) {
      return 'Notes are too long. Please keep notes within 1200 characters.';
    }

    if (notes.isNotEmpty) {
      if (notes.length < 4) {
        return 'Notes are too short. Please enter meaningful details.';
      }

      final compact = notes.replaceAll(RegExp(r'\s+'), '');
      if (RegExp(r'(.)\1{7,}').hasMatch(compact)) {
        return 'Notes appear repetitive or noisy. Please enter only relevant details.';
      }

      final unrelatedPattern = RegExp(
        r'lorem ipsum|asdf|qwerty|movie|lyrics|tiktok|facebook|instagram|shopping|gaming',
        caseSensitive: false,
      );
      if (unrelatedPattern.hasMatch(notes)) {
        return 'Notes appear unrelated to a lab record. Please remove unrelated text.';
      }
    }

    return null;
  }

  bool _isAiResultUnrelated(String text) {
    return RegExp(r'RELEVANCE\s*CHECK\s*:\s*UNRELATED', caseSensitive: false)
            .hasMatch(text) ||
        RegExp(r'not\s+laboratory\s+result|unrelated\s+image|unreadable',
                caseSensitive: false)
            .hasMatch(text);
  }

  String _extractRelevanceReason(String text) {
    final match =
        RegExp(r'RELEVANCE\s*REASON\s*:\s*([^\n]+)', caseSensitive: false)
            .firstMatch(text);
    if (match == null) {
      return 'Uploaded content appears unrelated to lab tests.';
    }
    return match.group(1)?.trim() ??
        'Uploaded content appears unrelated to lab tests.';
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
      'Checking selected test, notes, and attached images',
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
        'Lab test AI analysis request',
        'Selected lab type: ${_selectedLabType ?? 'Not specified'}',
        'Notes: ${_notesController.text.trim().isEmpty ? 'None provided' : _notesController.text.trim()}',
        'Image count: ${_selectedImages.length}',
      ].join('\n');

      _setLoadingState(
        'Reading laboratory record',
        'Extracting laboratory values from uploaded images',
      );

      final result = await _geminiService.analyzeLabTestImages(
        _selectedImages,
        selectedLabType: _selectedLabType,
        notes: _notesController.text.trim(),
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
    if (!_validateForm()) return;
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

      // Prefer explicit user-selected type. Use AI extraction only as fallback.
      String labTestType = _selectedLabType ?? 'Multiple Tests';
      if ((_selectedLabType == null || _selectedLabType!.trim().isEmpty) &&
          aiGenerated &&
          _combinedResponse!.labResults != null &&
          _combinedResponse!.labResults!.isNotEmpty) {
        final firstTest = _combinedResponse!.labResults!.first;
        if (firstTest.testName.isNotEmpty) {
          labTestType = firstTest.testName;
        }
      }

      final notesText = _notesController.text.trim();
      final String remarks = notesText;

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
              'lab_test_${DateTime.now().millisecondsSinceEpoch}_$i.${preparedUpload.extension}';
          final filePath = 'lab-tests/$_motherId/$fileName';

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
                'file_category': 'lab_result_image',
                'mime_type': preparedUpload.contentType,
                'file_size': bytes.length,
                'uploaded_by': userId,
                'reference_type': 'lab_test',
                'processing_type': 'lab_test_analysis',
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

      final labTestResponse = await Supabase.instance.client
          .from('lab_tests')
          .insert({
            'pregnancy_id': _pregnancyId,
            'lab_test_type': labTestType,
            'lab_test_date': _labTestDate!.toIso8601String().split('T')[0],
            'lab_test_location': 'Mobile Upload', // Default value
            'lab_test_image': _uploadedImageUrls.isNotEmpty
                ? _uploadedImageUrls.join(',')
                : null,
            'remarks': remarks.isEmpty ? null : remarks,
            'health_worker_name': _healthWorkerNameController.text.trim(),
            'health_worker_institution':
                _healthWorkerInstitutionController.text.trim().isEmpty
                    ? null
                    : _healthWorkerInstitutionController.text.trim(),
            'health_worker_profession':
                _healthWorkerProfessionController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('lab_test_id')
          .single();

      final labTestId = labTestResponse['lab_test_id'] as int;

      if (aiGenerated) {
        final finalAiText = _healthSummaryController.text.trim();
        final originalAiText = (_combinedResponse?.description ?? '').trim();
        final aiWasEdited =
            originalAiText.isNotEmpty && finalAiText != originalAiText;

        final insertedAi = await Supabase.instance.client
            .from('ai_responses')
            .insert({
              'response_type': 'lab_test_analysis',
              'reference_table': 'lab_tests',
              'reference_id': labTestId,
              'ai_model': 'Gemini 1.5 Flash',
              'confidence_score': 0.92,
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
            'edit_reason': 'Midwife edited AI lab analysis before final save.',
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
            'reference_table': 'lab_tests',
            'reference_id': labTestId,
          },
          'description':
              'Midwife approved AI lab analysis for lab_test_id=$labTestId.',
        });
      }

      for (int fileId in fileIds) {
        await Supabase.instance.client.from('files').update({
          'reference_id': labTestId,
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
      _showMessage('Lab test analysis saved successfully!',
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

  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final normalizedLine = _normalizeMarkdownLine(lines[i]);
      spans.addAll(_parseInlineMarkdown(normalizedLine));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style:
            const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
        children: spans,
      ),
    );
  }

  String _normalizeMarkdownLine(String input) {
    var line = input;
    line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*(?:[-*]|•)\s+'), '');
    return line;
  }

  String _cleanResidualMarkdown(String input) {
    var text = input;
    text = text.replaceAll('**', '');
    text = text.replaceAll('##', '');
    text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
    return text;
  }

  List<TextSpan> _parseInlineMarkdown(String input) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int current = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > current) {
        spans.add(TextSpan(
          text: _cleanResidualMarkdown(input.substring(current, match.start)),
        ));
      }

      final boldText = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      current = match.end;
    }

    if (current < input.length) {
      spans.add(TextSpan(
        text: _cleanResidualMarkdown(input.substring(current)),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: _cleanResidualMarkdown(input)));
    }

    return spans;
  }

  Map<String, List<String>> _extractInsightSections(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => _cleanResidualMarkdown(_normalizeMarkdownLine(l)).trim())
        .toList();

    final Map<String, List<String>> sections = {};
    String currentSection = 'Summary';
    sections[currentSection] = [];

    final headingPattern = RegExp(
      r'^(?:\d+\.\s*)?(RELEVANCE CHECK|RELEVANCE REASON|LABORATORY RESULTS|ABNORMAL FINDINGS|NORMAL RANGES|REFERENCE RANGES|OVERALL ASSESSMENT|RECOMMENDATIONS|KEY OBSERVATIONS)\s*:\s*(.*)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.toUpperCase() == 'COMPREHENSIVE LABORATORY ANALYSIS') continue;
      if (RegExp(r'^[-_=]{2,}$').hasMatch(line.replaceAll(' ', ''))) {
        continue;
      }

      final heading = headingPattern.firstMatch(line);
      if (heading != null) {
        currentSection = heading.group(1)!.toUpperCase();
        if (currentSection == 'REFERENCE RANGES') {
          currentSection = 'NORMAL RANGES';
        }
        sections.putIfAbsent(currentSection, () => []);
        final inlineContent = heading.group(2)?.trim() ?? '';
        if (inlineContent.isNotEmpty) {
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

  String _stripDecorativeDashes(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^[-_=]{2,}$').hasMatch(trimmed)) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'\s+--+\s+'), ' ').trim();
  }

  bool _isConcerningAnalyte(String text) {
    final t = text.toLowerCase();
    return RegExp(
      r'protein|glucose|ketone|nitrite|leukocyte|blood|pus|bacteria|bilirubin|hiv|hbsag|vdrl|rpr|syphilis|infection|pathogen',
      caseSensitive: false,
    ).hasMatch(t);
  }

  String _classifyLabStatus(String testName, String rawValue) {
    final test = testName.toLowerCase();
    final value = rawValue.toLowerCase();
    final merged = '$test $value';

    final hasWithinNormal = RegExp(
      r'within normal limits|within normal range|normal range|wnl',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasWithinNormal) return 'WITHIN NORMAL LIMITS';

    final isColorFinding = test.contains('color') || test.contains('colour');
    if (isColorFinding) {
      if (RegExp(r'\byellow\b|\bstraw\b|\bpale\b|\bclear\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'WITHIN NORMAL LIMITS';
      }
      if (RegExp(r'\bdark\b|\bamber\b|\bbrown\b|\bred\b|\bbloody\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'ABNORMAL (REVIEW)';
      }
      return 'OBSERVE';
    }

    if (RegExp(r'\bpositive\b', caseSensitive: false).hasMatch(value)) {
      if (_isConcerningAnalyte(merged)) return 'POSITIVE (REVIEW)';
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'POSITIVE (EXPECTED)';
      }
      return 'POSITIVE';
    }

    if (RegExp(r'\bnegative\b', caseSensitive: false).hasMatch(value)) {
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'NEGATIVE (REVIEW)';
      }
      if (_isConcerningAnalyte(merged)) return 'NEGATIVE (REASSURING)';
      return 'NEGATIVE';
    }

    if (RegExp(r'\btrace\b|\bfew\b|\bslight\b|\bmild\b|\bborderline\b',
            caseSensitive: false)
        .hasMatch(value)) {
      return 'BORDERLINE';
    }

    if (RegExp(
      r'\babnormal\b|\bcritical\b|outside normal range|higher than normal|lower than normal|\belevated\b|\bdecreased\b|\bincreased\b|⚠',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'ABNORMAL (REVIEW)';
    }

    if (RegExp(r'\bnormal\b', caseSensitive: false).hasMatch(value)) {
      return 'NORMAL';
    }

    return 'OBSERVE';
  }

  bool _isConcerningStatus(String status) {
    final s = status.toUpperCase();
    return s.contains('REVIEW') || s == 'ABNORMAL';
  }

  bool _isCautionStatus(String status) {
    final s = status.toUpperCase();
    return s == 'OBSERVE' || s == 'BORDERLINE' || s == 'POSITIVE';
  }

  Color _statusChipBackground(String status) {
    if (_isConcerningStatus(status)) return Colors.red.shade50;
    if (_isCautionStatus(status)) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _statusChipBorder(String status) {
    if (_isConcerningStatus(status)) return Colors.red.shade200;
    if (_isCautionStatus(status)) return Colors.orange.shade200;
    return Colors.green.shade200;
  }

  Color _statusChipTextColor(String status) {
    if (_isConcerningStatus(status)) return Colors.red;
    if (_isCautionStatus(status)) return Colors.orange.shade800;
    return Colors.green;
  }

  String _statusMeaning(String status) {
    switch (status.toUpperCase()) {
      case 'WITHIN NORMAL LIMITS':
        return 'Consistent with expected findings for this test.';
      case 'NORMAL':
        return 'Reported as normal for this parameter.';
      case 'ABNORMAL (REVIEW)':
      case 'ABNORMAL':
        return 'May need clinician review with symptoms and history.';
      case 'BORDERLINE':
        return 'Near threshold. Monitor trends and correlate clinically.';
      case 'OBSERVE':
        return 'Not clearly high-risk. Observe and compare with references.';
      case 'POSITIVE (REVIEW)':
        return 'Positive finding that may be clinically significant.';
      case 'POSITIVE (EXPECTED)':
        return 'Positive finding can be expected for this test context.';
      case 'NEGATIVE (REASSURING)':
        return 'No concerning marker detected for this parameter.';
      case 'NEGATIVE (REVIEW)':
        return 'Negative may be unexpected for this context; verify clinically.';
      case 'POSITIVE':
      case 'NEGATIVE':
        return 'Interpret this result based on the specific test context.';
      default:
        return 'Interpret this result together with reference ranges and overall assessment.';
    }
  }

  bool _hasWithinNormalOverallAssessment() {
    final text =
        (_combinedResponse?.description ?? _healthSummaryController.text)
            .toLowerCase();
    return RegExp(
      r'overall assessment[^\n]*within normal limits|overall assessment[^\n]*normal|within normal limits',
      caseSensitive: false,
    ).hasMatch(text);
  }

  bool _hasAbnormalSignals() {
    final text =
        (_combinedResponse?.description ?? _healthSummaryController.text)
            .toLowerCase();
    final hasWithinNormal = _hasWithinNormalOverallAssessment();

    final strongAbnormalPattern = RegExp(
      r'\bcritical\b|outside normal range|higher than normal|lower than normal|requires urgent|severe',
      caseSensitive: false,
    );

    if (strongAbnormalPattern.hasMatch(text)) return true;

    final sections = _extractInsightSections(_healthSummaryController.text);
    final labLines = sections['LABORATORY RESULTS'] ?? const <String>[];
    final hasConcerningRow = labLines.map(_parseLabResultLine).any(
        (row) => row.testName.isNotEmpty && _isConcerningStatus(row.status));

    if (hasConcerningRow && hasWithinNormal) {
      return false;
    }

    if (hasConcerningRow) return true;

    if (_combinedResponse?.labResults != null) {
      for (final result in _combinedResponse!.labResults!) {
        if (result.isAbnormal && !hasWithinNormal) return true;
      }
    }

    return false;
  }

  bool _hasDetailedLabData() {
    if (_combinedResponse == null) return false;

    if ((_combinedResponse!.labResults?.isNotEmpty ?? false) ||
        (_combinedResponse!.abnormalFindings?.isNotEmpty ?? false) ||
        (_combinedResponse!.normalRanges?.isNotEmpty ?? false)) {
      return true;
    }

    final sections = _extractInsightSections(_healthSummaryController.text);
    return (sections['LABORATORY RESULTS']?.isNotEmpty ?? false) ||
        (sections['ABNORMAL FINDINGS']?.isNotEmpty ?? false) ||
        (sections['NORMAL RANGES']?.isNotEmpty ?? false);
  }

  ({String testName, String value, String status}) _parseLabResultLine(
      String line) {
    final cleaned =
        _safeText(line).replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim();
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex == -1) {
      return (testName: cleaned, value: '', status: 'UNKNOWN');
    }

    final testName = cleaned.substring(0, colonIndex).trim();
    final rawValue = _safeText(cleaned.substring(colonIndex + 1)).trim();
    final status = _classifyLabStatus(testName, rawValue);

    final value = rawValue
        .replaceAll('⚠️', '')
        .replaceAll('⚠', '')
        .replaceAll(RegExp(r'\bABNORMAL\b', caseSensitive: false), '')
        .trim();

    return (
      testName: _stripDecorativeDashes(testName),
      value: _stripDecorativeDashes(value),
      status: status
    );
  }

  String _normalizeAspectKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _lineMatchesAspect(String line, String aspect) {
    final a = _normalizeAspectKey(_safeText(aspect));
    final l = _normalizeAspectKey(_safeText(line));
    return a.isNotEmpty && l.contains(a);
  }

  String _buildAspectDetails(
      String aspect, List<String> abnormalLines, List<String> rangeLines) {
    final matches = <String>[];
    for (final line in abnormalLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add(line);
      }
    }
    for (final line in rangeLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add('Reference: $line');
      }
    }
    return matches.join('\n\n').trim();
  }

  Widget _buildCombinedLabResultsCard(Map<String, List<String>> sections) {
    final labLines = sections['LABORATORY RESULTS'] ?? const <String>[];
    final abnormalLines = sections['ABNORMAL FINDINGS'] ?? const <String>[];
    final rangeLines = sections['NORMAL RANGES'] ?? const <String>[];

    final rows = labLines
        .map(_parseLabResultLine)
        .where((r) => r.testName.isNotEmpty && r.status != 'UNKNOWN')
        .toList();

    if (rows.isEmpty) {
      return _buildInsightSectionCard('LABORATORY RESULTS', labLines);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science_outlined,
                  size: 18, color: AppColors.brandPrimary),
              SizedBox(width: 8),
              Text(
                'Laboratory Results',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Status guide: REVIEW = needs clinician review, BORDERLINE/OBSERVE = monitor and correlate, WITHIN NORMAL LIMITS = reassuring in context.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final details = _buildAspectDetails(
              row.testName,
              abnormalLines,
              rangeLines,
            );
            final aspectKey = _normalizeAspectKey(row.testName);
            final isExpanded = _expandedAspects.contains(aspectKey);
            final hasDetails = details.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.testName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          onPressed: hasDetails
                              ? () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedAspects.remove(aspectKey);
                                    } else {
                                      _expandedAspects.add(aspectKey);
                                    }
                                  });
                                }
                              : null,
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusChipBackground(row.status),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _statusChipBorder(row.status),
                          ),
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
                      if (row.value.isNotEmpty)
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
                  const SizedBox(height: 6),
                  Text(
                    _statusMeaning(row.status),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (isExpanded && hasDetails)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildFormattedText(details),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLabResultRows(List<String> lines) {
    return Column(
      children: lines.map((line) {
        final parsed = _parseLabResultLine(line);
        final concerning = _isConcerningStatus(parsed.status);
        final caution = _isCautionStatus(parsed.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: concerning
                ? Colors.red.shade50
                : caution
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: concerning
                  ? Colors.red.shade200
                  : caution
                      ? Colors.orange.shade200
                      : Colors.green.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.testName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (parsed.value.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        parsed.value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _statusMeaning(parsed.status),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: concerning
                      ? Colors.red
                      : caution
                          ? Colors.orange.shade700
                          : Colors.green,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  parsed.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _friendlySectionTitle(String title) {
    switch (title) {
      case 'LABORATORY RESULTS':
        return 'Laboratory Results';
      case 'ABNORMAL FINDINGS':
        return 'Abnormal Findings';
      case 'NORMAL RANGES':
        return 'Reference Ranges';
      case 'OVERALL ASSESSMENT':
        return 'Overall Assessment';
      case 'RECOMMENDATIONS':
        return 'Recommendations';
      case 'RELEVANCE CHECK':
        return 'Relevance Check';
      case 'RELEVANCE REASON':
        return 'Relevance Reason';
      case 'KEY OBSERVATIONS':
        return 'Key Observations';
      default:
        return title
            .split(' ')
            .map(
                (w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  Widget _buildInsightSectionCard(String title, List<String> lines) {
    final safeTitle = _safeText(title).toUpperCase();
    final isAbnormal = safeTitle.contains('ABNORMAL');
    final isRecommendation = safeTitle.contains('RECOMMENDATION');
    final isAssessment = safeTitle.contains('ASSESSMENT');

    final Color accent = isAbnormal
        ? Colors.red
        : isRecommendation
            ? Colors.blue
            : isAssessment
                ? Colors.deepPurple
                : AppColors.brandPrimary;

    final IconData icon = isAbnormal
        ? Icons.warning_amber_rounded
        : isRecommendation
            ? Icons.lightbulb_outline
            : isAssessment
                ? Icons.health_and_safety_outlined
                : Icons.article_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _friendlySectionTitle(safeTitle),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (safeTitle == 'LABORATORY RESULTS')
            _buildLabResultRows(lines)
          else
            ...lines.map((line) {
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
                        color: accent,
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
    );
  }

  Widget _buildStructuredInsights(String text) {
    final sections = _extractInsightSections(text);
    if (sections.isEmpty) return _buildFormattedText(text);

    const sectionOrder = [
      'RELEVANCE CHECK',
      'RELEVANCE REASON',
      'OVERALL ASSESSMENT',
      'LABORATORY RESULTS',
      'ABNORMAL FINDINGS',
      'NORMAL RANGES',
      'KEY OBSERVATIONS',
      'RECOMMENDATIONS',
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
      if (entry.key == 'LABORATORY RESULTS') {
        widgets.add(_buildCombinedLabResultsCard(sections));
        continue;
      }

      // These details are now merged into expandable rows per aspect.
      if (entry.key == 'ABNORMAL FINDINGS' || entry.key == 'NORMAL RANGES') {
        continue;
      }

      widgets.add(_buildInsightSectionCard(entry.key, entry.value));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
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
                'Add Lab Test Images',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library,
                    color: Colors.deepPurple.shade700),
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
                    SizedBox(width: 12),
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
                  borderRadius: BorderRadius.circular(18),
                ),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
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
                          child: _buildStructuredInsights(summaryDraft.text),
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

    if (_hasWithinNormalOverallAssessment() && !_hasAbnormalSignals()) {
      return 'WITHIN NORMAL LIMITS';
    }

    if (_hasWithinNormalOverallAssessment() && _hasAbnormalSignals()) {
      return 'MIXED FINDINGS, CLINICAL REVIEW ADVISED';
    }

    if (_hasAbnormalSignals()) {
      return 'REVIEW FLAGGED FINDINGS';
    }

    return 'NO HIGH-RISK FINDINGS DETECTED';
  }

  Color _getHealthStatusColor() {
    if (_combinedResponse == null) return Colors.grey;

    if (_hasWithinNormalOverallAssessment() && !_hasAbnormalSignals()) {
      return Colors.green;
    }

    if (_hasWithinNormalOverallAssessment() && _hasAbnormalSignals()) {
      return Colors.orange.shade700;
    }

    if (_hasAbnormalSignals()) {
      return Colors.red;
    }

    return Colors.blueGrey;
  }

  IconData _getHealthStatusIcon() {
    if (_combinedResponse == null) return Icons.help_outline;

    if (_hasWithinNormalOverallAssessment() && !_hasAbnormalSignals()) {
      return Icons.verified_rounded;
    }

    if (_hasWithinNormalOverallAssessment() && _hasAbnormalSignals()) {
      return Icons.rule_folder_outlined;
    }

    if (_hasAbnormalSignals()) {
      return Icons.warning_amber_rounded;
    }

    return Icons.verified_outlined;
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
                    icon: const Icon(Icons.save, color: Colors.green),
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
                    icon: const Icon(Icons.close, color: Colors.red),
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
            border: Border.all(
              color: AppColors.borderPrimary,
              width: 1.5,
            ),
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
                    child: Icon(
                      Icons.medical_information,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Clinical Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                _buildStructuredInsights(_healthSummaryController.text)
              else
                TextField(
                  controller: _healthSummaryController,
                  maxLines: 4,
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
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedResults() {
    if (_combinedResponse == null || !_hasDetailedLabData()) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science,
                    color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Detailed Laboratory Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_combinedResponse!.labResults != null &&
              _combinedResponse!.labResults!.isNotEmpty) ...[
            const Text(
              'TEST RESULTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._combinedResponse!.labResults!.map((result) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: result.isNormal
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: result.isNormal
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        result.isNormal ? Icons.check_circle : Icons.warning,
                        color: result.isNormal ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.testName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: result.isNormal
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: result.isNormal ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        result.isNormal ? 'NORMAL' : 'ABNORMAL',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (_combinedResponse!.abnormalFindings != null &&
              _combinedResponse!.abnormalFindings!.isNotEmpty) ...[
            const Text(
              'ABNORMAL FINDINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._combinedResponse!.abnormalFindings!.map((finding) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        finding,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (_combinedResponse!.normalRanges != null &&
              _combinedResponse!.normalRanges!.isNotEmpty) ...[
            const Text(
              'REFERENCE RANGES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._combinedResponse!.normalRanges!.map((range) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        range,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This analysis is AI-generated for reference only. Always consult with a qualified healthcare provider for proper interpretation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Step 1: Test Details',
          subtitle: 'Set the date and choose the pregnancy-related lab test.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lab Test Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
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
                              'Lab Test Date',
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
              const SizedBox(height: 12),
              const Text(
                'Lab Test Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedLabType,
                decoration: const InputDecoration(
                  hintText: 'Select pregnancy-related lab test',
                  border: OutlineInputBorder(),
                ),
                items: _pregnancyLabTests
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedLabType = value),
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
                      fontWeight: FontWeight.w600,
                    ),
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
                color: Colors.black.withOpacity(0.05),
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
                      (_acceptedLabProfessions.contains(effectiveSelected) ||
                              effectiveSelected == _otherProfessionOption)
                          ? effectiveSelected
                          : null;

                  final dropdownItems = [
                    ..._acceptedLabProfessions,
                    _otherProfessionOption,
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
              'Attach lab result images, add notes, then run and review AI analysis.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                'Required: Add at least one lab test image',
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
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
                          color: _getHealthStatusColor().withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getHealthStatusIcon(),
                            color: _getHealthStatusColor(),
                          ),
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
                      onTap: () => setState(
                        () => _showAdvancedAiDetails = !_showAdvancedAiDetails,
                      ),
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAdvancedAiDetails) ...[
                      const SizedBox(height: 10),
                      _buildEditableSection(),
                      if (_hasDetailedLabData()) _buildDetailedResults(),
                    ],
                  ],
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
                    color: Colors.black.withOpacity(0.05),
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
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Lab Test Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandText,
                      ),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
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
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.deepPurple.shade200),
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
                                      size: 20,
                                      color: Colors.deepPurple.shade700),
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
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      Text(
                                        'Pregnancy ID: $_pregnancyId',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.deepPurple.shade700,
                                        ),
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
                                  ? 'Complete test details first, then continue.'
                                  : _step == 1
                                      ? 'Enter health worker details before proceeding.'
                                      : 'Attach images, optionally run AI analysis, and approve AI only if you generated one before saving.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
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
                                                  Colors.green),
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
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
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
              fontWeight: FontWeight.w500,
            ),
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
