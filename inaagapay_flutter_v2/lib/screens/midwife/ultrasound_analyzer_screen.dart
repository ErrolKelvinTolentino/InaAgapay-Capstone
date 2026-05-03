// lib/screens/midwife/ultrasound_analyzer_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_service.dart';
import '../../services/auth_storage.dart';
import '../../models/gemini_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dialog_box.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';

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
  final GeminiService _geminiService = GeminiService();
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  final List<XFile> _selectedImages = [];
  GeminiResponse? _combinedResponse;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  late TextEditingController _healthSummaryController;
  late TextEditingController _explanationController;
  bool _isEditing = false;
  String? _lastAiPrompt;

  DateTime? _ultrasoundDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _healthWorkerNameController =
      TextEditingController();
  final TextEditingController _healthWorkerInstitutionController =
      TextEditingController();
  final TextEditingController _healthWorkerProfessionController =
      TextEditingController();

  late int _motherId;
  late int _pregnancyId;

  final List<String> _uploadedImageUrls = [];

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();
    _explanationController = TextEditingController();

    _ultrasoundDate = DateTime.now();
    _dateController.text = _dateFormat.format(_ultrasoundDate!);

    _motherId = widget.motherId;
    _pregnancyId = widget.pregnancyId;

    _loadUserContext();
  }

  @override
  void dispose() {
    _healthSummaryController.dispose();
    _explanationController.dispose();
    _dateController.dispose();
    _healthWorkerNameController.dispose();
    _healthWorkerInstitutionController.dispose();
    _healthWorkerProfessionController.dispose();
    super.dispose();
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
          _healthSummaryController.clear();
          _explanationController.clear();
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
          _healthSummaryController.clear();
          _explanationController.clear();
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
        _explanationController.clear();
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
      _explanationController.clear();
      _uploadedImageUrls.clear();
      _dateController.text = _dateFormat.format(DateTime.now());
      _ultrasoundDate = DateTime.now();
      _healthWorkerNameController.clear();
      _healthWorkerInstitutionController.clear();
      _healthWorkerProfessionController.clear();
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

  bool _validateForm() {
    if (_selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one ultrasound image';
      });
      return false;
    }

    if (_ultrasoundDate == null) {
      setState(() {
        _errorMessage = 'Please select the ultrasound date';
      });
      return false;
    }

    if (_healthWorkerNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the health worker\'s name';
      });
      return false;
    }

    if (_healthWorkerProfessionController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the health worker\'s profession';
      });
      return false;
    }

    return true;
  }

  Future<void> _analyzeImages() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _combinedResponse = null;
      _isEditing = false;
      _healthSummaryController.clear();
      _explanationController.clear();
    });

    try {
      _lastAiPrompt = [
        'Ultrasound AI analysis request',
        'Health worker name: ${_healthWorkerNameController.text.trim().isEmpty ? 'Not specified' : _healthWorkerNameController.text.trim()}',
        'Health worker institution: ${_healthWorkerInstitutionController.text.trim().isEmpty ? 'Not specified' : _healthWorkerInstitutionController.text.trim()}',
        'Health worker profession: ${_healthWorkerProfessionController.text.trim().isEmpty ? 'Not specified' : _healthWorkerProfessionController.text.trim()}',
        'Image count: ${_selectedImages.length}',
      ].join('\n');

      final result = await _geminiService.analyzeUltrasoundImages(
        _selectedImages,
        clinicalContext: _lastAiPrompt,
      );

      final isUnrelated = RegExp(
        r'RELEVANCE\s*CHECK\s*:\s*UNRELATED',
        caseSensitive: false,
      ).hasMatch(result.description);
      if (isUnrelated) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'AI flagged the upload as unrelated or unreadable. Please attach clearer ultrasound images.';
        });
        return;
      }

      setState(() {
        _combinedResponse = result;
        _isLoading = false;

        if (result.description.isNotEmpty) {
          _healthSummaryController.text = result.description;
          _explanationController.text = _extractExplanation(result.description);
        } else {
          _healthSummaryController.text = "No analysis available";
          _explanationController.text = "No recommendations available";
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToDatabase() async {
    if (_combinedResponse == null) return;

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

      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final bytes = await image.readAsBytes();
        final fileName =
            'ultrasound_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final filePath = 'ultrasounds/$_motherId/$fileName';

        await Supabase.instance.client.storage.from('files').uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
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
              'mime_type': 'image/jpeg',
              'file_size': bytes.length,
              'uploaded_by': userId,
              'reference_type': 'ultrasound',
              'processing_type': 'ultrasound_analysis',
              'ai_processed': true,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('file_id')
            .single();

        fileIds.add(fileResponse['file_id'] as int);
      }

      final ultrasoundResponse = await Supabase.instance.client
          .from('ultrasounds')
          .insert({
            'pregnancy_id': _pregnancyId,
            'ultrasound_date': _ultrasoundDate!.toIso8601String().split('T')[0],
            'ultrasound_location': 'Mobile Upload',
            'ultrasound_image': _uploadedImageUrls.isNotEmpty
                ? _uploadedImageUrls.join(',')
                : null,
            'remarks': _healthSummaryController.text,
            'health_worker_name': _healthWorkerNameController.text.trim(),
            'health_worker_institution':
                _healthWorkerInstitutionController.text.trim().isEmpty
                    ? null
                    : _healthWorkerInstitutionController.text.trim(),
            'health_worker_profession':
                _healthWorkerProfessionController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('ultrasound_id')
          .single();

      final ultrasoundId = ultrasoundResponse['ultrasound_id'] as int;

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

      for (int fileId in fileIds) {
        await Supabase.instance.client.from('files').update({
          'reference_id': ultrasoundId,
        }).eq('file_id', fileId);
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => DialogBox(
          title: 'Success',
          content: 'Ultrasound analysis saved successfully!',
          buttonText: 'OK',
          type: DialogType.success,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context, true);
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to database: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _extractHealthSummary(String description) {
    final summaryMatch = RegExp(
            r'HEALTH SUMMARY:([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)',
            caseSensitive: false)
        .firstMatch(description);
    if (summaryMatch != null) {
      return summaryMatch.group(1)?.trim() ?? description.split('\n').first;
    }
    return description.split('\n').first;
  }

  String _extractExplanation(String description) {
    final explanationMatch = RegExp(
            r'(?:BASIS|REASONING|EXPLANATION):([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)',
            caseSensitive: false)
        .firstMatch(description);
    if (explanationMatch != null) {
      return explanationMatch.group(1)?.trim() ?? '';
    }

    final lines = description.split('\n');
    final filteredLines = <String>[];

    bool skipSection = false;

    for (String line in lines) {
      if (line.contains('ANATOMICAL ASSESSMENT:')) {
        skipSection = true;
        continue;
      }

      if (line.contains('KEY OBSERVATIONS:')) {
        skipSection = true;
        continue;
      }

      if (line.contains('HEALTH SUMMARY:')) {
        skipSection = false;
        continue;
      }

      if (!skipSection) {
        if (line.trim().isNotEmpty ||
            (filteredLines.isNotEmpty && filteredLines.last.isNotEmpty)) {
          filteredLines.add(line);
        }
      }
    }

    if (filteredLines.isNotEmpty) {
      return filteredLines.join('\n').trim();
    }

    return '';
  }

  // Beautiful formatted text widget
  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    // Split by sections (marked by ALL CAPS lines)
    final lines = text.split('\n');
    final List<Widget> sections = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Check if this is a section header (all caps and longer than 2 chars)
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
                    AppColors.brandPrimary.withOpacity(0.1),
                    AppColors.brandSecondary.withOpacity(0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.brandPrimary.withOpacity(0.2),
                ),
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
      // Check if line starts with bullet point
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
      // Regular text
      else {
        // Check if line contains important keywords
        if (line.contains('✅') || line.contains('NORMAL')) {
          sections.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (line.contains('⚠️') ||
            line.contains('MONITORING') ||
            line.contains('CONCERN')) {
          sections.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (line.contains('🔍') || line.contains('FURTHER EVALUATION')) {
          sections.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
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

  String _getHealthStatus() {
    if (_combinedResponse == null) return 'Assessment Complete';

    if (_combinedResponse!.healthStatus != null) {
      if (_combinedResponse!.healthStatus!.contains('HEALTHY')) {
        return 'HEALTHY PREGNANCY';
      } else if (_combinedResponse!.healthStatus!.contains('MONITORING')) {
        return 'REQUIRES MONITORING';
      }
    }

    return 'ASSESSMENT COMPLETE';
  }

  Color _getHealthStatusColor() {
    if (_combinedResponse == null) return Colors.grey;

    if (_combinedResponse!.healthStatus != null) {
      if (_combinedResponse!.healthStatus!.contains('HEALTHY')) {
        return Colors.green;
      } else if (_combinedResponse!.healthStatus!.contains('MONITORING')) {
        return Colors.orange;
      }
    }

    return AppColors.brandPrimary;
  }

  IconData _getHealthStatusIcon() {
    if (_combinedResponse == null) return Icons.help_outline;

    if (_combinedResponse!.healthStatus != null) {
      if (_combinedResponse!.healthStatus!.contains('HEALTHY')) {
        return Icons.check_circle;
      } else if (_combinedResponse!.healthStatus!.contains('MONITORING')) {
        return Icons.warning;
      }
    }

    return Icons.info;
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
                        _healthSummaryController.text = _extractHealthSummary(
                            _combinedResponse!.description);
                        _explanationController.text =
                            _extractExplanation(_combinedResponse!.description);
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

        // Clinical Assessment Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getHealthStatusColor().withOpacity(0.1),
                _getHealthStatusColor().withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getHealthStatusColor().withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getHealthStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.health_and_safety,
                      color: _getHealthStatusColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinical Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getHealthStatusColor(),
                          ),
                        ),
                        Text(
                          'AI-Powered Analysis',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getHealthStatusColor().withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getHealthStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: _getHealthStatusColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getHealthStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (!_isEditing)
                _buildFormattedText(_healthSummaryController.text)
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

        const SizedBox(height: 16),

        // Recommendations Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (!_isEditing)
                _buildFormattedText(_explanationController.text)
              else
                TextField(
                  controller: _explanationController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText:
                        'Enter recommendations with bullet points...\n• Point 1\n• Point 2\n• Point 3',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isConcerningStatus(String status) {
    final s = status.toUpperCase();
    return s.contains('REVIEW') || s.contains('ABNORMAL') || s.contains('CONCERNING');
  }

  bool _isCautionStatus(String status) {
    final s = status.toUpperCase();
    return s == 'OBSERVE' || s == 'BORDERLINE' || s == 'POSITIVE' || s == 'MONITOR';
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

  String _safeText(Object? value) => value?.toString() ?? '';

  ({String testName, String value, String status, String remark}) _parseUltrasoundMetricLine(String line) {
    final cleaned = _safeText(line).replaceFirst(RegExp(r'^[-\*•]\s*'), '').trim();

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

        if (rest.startsWith('✓') || rest.toLowerCase() == 'normal' || rest.toLowerCase() == 'present') {
          value = 'Present / Normal';
          status = 'NORMAL';
          if (rest.startsWith('✓')) rest = rest.substring(1).trim();
        } else if (rest.startsWith('X') || rest.startsWith('✗') || rest.toLowerCase() == 'abnormal' || rest.toLowerCase() == 'absent') {
          value = 'Absent / Abnormal';
          status = 'ABNORMAL';
          if (rest.startsWith('X') || rest.startsWith('✗')) rest = rest.substring(1).trim();
        } else {
          final dashIndex = rest.lastIndexOf('-');
          if (dashIndex != -1) {
            final possibleStatus = rest.substring(dashIndex + 1).trim().toUpperCase();
            if (possibleStatus == 'NORMAL' || possibleStatus == 'ABNORMAL' || possibleStatus == 'REVIEW' || possibleStatus == 'MONITOR' || possibleStatus == 'BORDERLINE' || possibleStatus == 'CONCERNING') {
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
    
    if (status == 'UNKNOWN' || status.isEmpty) {
        if (RegExp(r'\bnormal\b', caseSensitive: false).hasMatch(value)) {
            status = 'NORMAL';
        } else if (RegExp(r'\babnormal\b|\bcritical\b|outside normal range|concerning', caseSensitive: false).hasMatch(value)) {
            status = 'ABNORMAL';
        } else {
            status = 'INFO';
        }
    }

    return (testName: testName, value: value, status: status, remark: remark);
  }

  Widget _buildMetricsList(List<String> lines) {
    final rows = lines.map(_parseUltrasoundMetricLine).where((r) => r.testName.isNotEmpty).toList();

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
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (row.status != 'UNKNOWN' && row.status != 'INFO')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  if (row.value.isNotEmpty && row.value != 'Present / Normal' && row.value != 'Absent / Abnormal')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildDetailedFindings() {
    if (_combinedResponse == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline,
                    color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Detailed Findings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Measurements
          if (_combinedResponse!.measurements != null &&
              _combinedResponse!.measurements!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.straighten,
                          color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Measurements',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  _buildMetricsList(_combinedResponse!.measurements!),
                ],
              ),
            ),
          ],

          // Key Findings
          if (_combinedResponse!.normalFindings != null &&
              _combinedResponse!.normalFindings!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Normal Findings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  _buildMetricsList(_combinedResponse!.normalFindings!),
                ],
              ),
            ),
          ],

          // Concerns
          if (_combinedResponse!.concerns != null &&
              _combinedResponse!.concerns!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Areas to Monitor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  _buildMetricsList(_combinedResponse!.concerns!),
                ],
              ),
            ),
          ],

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This analysis is AI-generated for reference only. Always consult with a qualified healthcare provider.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                      'Ultrasound Assessment',
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mother #$_motherId',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal,
                                  ),
                                ),
                                Text(
                                  'Pregnancy ID: $_pregnancyId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImages.isNotEmpty) ...[
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.teal, width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: kIsWeb
                                        ? Image.network(
                                            _selectedImages[index].path,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(_selectedImages[index].path),
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: _selectedImages.isEmpty
                                ? 'Add Images'
                                : 'Add More',
                            onPressed: _showImageSourceDialog,
                            leadingIcon: Icons.add_a_photo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MainButton(
                            label: 'Analyze',
                            onPressed: _analyzeImages,
                            leftIcon: Icons.auto_awesome,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment,
                                    color: Colors.teal),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Study Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 20, color: Colors.teal),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Study Date *',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          _dateController.text,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down,
                                      color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person,
                                    color: Colors.teal),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Health Worker Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _healthWorkerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _healthWorkerInstitutionController,
                              decoration: const InputDecoration(
                                labelText: 'Institution/Clinic',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _healthWorkerProfessionController,
                              decoration: const InputDecoration(
                                labelText: 'Profession *',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '* Required fields',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.teal),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing with AI...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage != null && !_isLoading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade400),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_combinedResponse != null && !_isLoading) ...[
                      const SizedBox(height: 16),

                      // Status Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getHealthStatusColor().withOpacity(0.2),
                              _getHealthStatusColor().withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getHealthStatusColor().withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getHealthStatusColor().withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getHealthStatusIcon(),
                                color: _getHealthStatusColor(),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Analysis Complete',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getHealthStatus(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _getHealthStatusColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Editable Sections
                      _buildEditableSection(),

                      const SizedBox(height: 16),

                      // Detailed Findings
                      _buildDetailedFindings(),

                      const SizedBox(height: 20),

                      // Save Button
                      if (!_isSaving)
                        MainButton(
                          label: 'Save to Records',
                          onPressed: _saveToDatabase,
                          leftIcon: Icons.save,
                        )
                      else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
