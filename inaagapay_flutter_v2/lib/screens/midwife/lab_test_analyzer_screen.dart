// lib/screens/midwife/lab_test_analyzer_screen.dart

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
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  late TextEditingController _healthSummaryController;
  late TextEditingController _explanationController;
  bool _isEditing = false;

  DateTime? _labTestDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _healthWorkerNameController = TextEditingController();
  final TextEditingController _healthWorkerInstitutionController = TextEditingController();
  final TextEditingController _healthWorkerProfessionController = TextEditingController();

  String? _userRole;
  late int _motherId;
  late int _pregnancyId;

  List<String> _uploadedImageUrls = [];

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();
    _explanationController = TextEditingController();
    
    _labTestDate = DateTime.now();
    _dateController.text = _dateFormat.format(_labTestDate!);
    
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
      final role = await AuthStorage.getUserRole();
      setState(() {
        _userRole = role;
      });
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
      _labTestDate = DateTime.now();
      _healthWorkerNameController.clear();
      _healthWorkerInstitutionController.clear();
      _healthWorkerProfessionController.clear();
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
    if (_selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one lab test image';
      });
      return false;
    }

    if (_labTestDate == null) {
      setState(() {
        _errorMessage = 'Please select the test date';
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
      final result = await _geminiService.analyzeLabTestImages(_selectedImages);
      
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

      // Determine lab test type from response or set default
      String labTestType = 'Multiple Tests';
      if (_combinedResponse!.labResults != null && _combinedResponse!.labResults!.isNotEmpty) {
        final firstTest = _combinedResponse!.labResults!.first;
        if (firstTest.testName.isNotEmpty) {
          labTestType = firstTest.testName;
        }
      }

      final List<String> uploadedFilePaths = [];
      final List<int> fileIds = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final bytes = await image.readAsBytes();
        final fileName = 'lab_test_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final filePath = 'lab-tests/$_motherId/$fileName';
        
        await Supabase.instance.client.storage
            .from('files')
            .uploadBinary(
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
              'file_category': 'lab_result_image',
              'mime_type': 'image/jpeg',
              'file_size': bytes.length,
              'uploaded_by': userId,
              'reference_type': 'lab_test',
              'processing_type': 'lab_test_analysis',
              'ai_processed': true,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('file_id')
            .single();

        fileIds.add(fileResponse['file_id'] as int);
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
            'remarks': _healthSummaryController.text,
            'health_worker_name': _healthWorkerNameController.text.trim(),
            'health_worker_institution': _healthWorkerInstitutionController.text.trim().isEmpty 
                ? null 
                : _healthWorkerInstitutionController.text.trim(),
            'health_worker_profession': _healthWorkerProfessionController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('lab_test_id')
          .single();

      final labTestId = labTestResponse['lab_test_id'] as int;

      await Supabase.instance.client
          .from('ai_responses')
          .insert({
            'response_type': 'lab_test_analysis',
            'reference_table': 'lab_tests',
            'reference_id': labTestId,
            'ai_model': 'Gemini 1.5 Flash',
            'confidence_score': 0.92,
            'response': _combinedResponse!.description,
            'response_category': 'analysis',
            'status': 'generated',
            'generated_by_ai': true,
            'created_at': DateTime.now().toIso8601String(),
          });

      for (int fileId in fileIds) {
        await Supabase.instance.client
            .from('files')
            .update({
              'reference_id': labTestId,
            })
            .eq('file_id', fileId);
      }

      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (_) => DialogBox(
          title: 'Success',
          content: 'Lab test analysis saved successfully!',
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
    final summaryMatch = RegExp(r'OVERALL ASSESSMENT:([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
    if (summaryMatch != null) {
      return summaryMatch.group(1)?.trim() ?? description.split('\n').first;
    }
    return description.split('\n').first;
  }

  String _extractExplanation(String description) {
    final recommendationMatch = RegExp(r'RECOMMENDATIONS:([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
    if (recommendationMatch != null) {
      return recommendationMatch.group(1)?.trim() ?? '';
    }
    
    final parts = description.split('OVERALL ASSESSMENT:');
    if (parts.length > 1) {
      final afterAssessment = parts[1];
      final paragraphs = afterAssessment.split('\n\n');
      if (paragraphs.length > 1) {
        return paragraphs[1].trim();
      }
    }
    
    final lines = description.split('\n');
    if (lines.length > 5) {
      return lines.sublist(5).join('\n').trim();
    }
    
    return description;
  }

  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    
    final words = text.split(' ');
    final List<TextSpan> spans = [];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      if (word.length > 1 && word == word.toUpperCase() && !word.contains(RegExp(r'[0-9]'))) {
        spans.add(TextSpan(
          text: word,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ));
      } else {
        spans.add(TextSpan(text: word));
      }
      
      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
        children: spans,
      ),
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
                child: Icon(Icons.photo_library, color: Colors.deepPurple.shade700),
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
    
    if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty) {
      return 'ABNORMAL FINDINGS DETECTED';
    }
    
    if (_combinedResponse!.labResults != null) {
      for (var result in _combinedResponse!.labResults!) {
        if (result.isAbnormal) {
          return 'ABNORMAL FINDINGS DETECTED';
        }
      }
    }
    
    return 'ALL RESULTS NORMAL';
  }

  Color _getHealthStatusColor() {
    if (_combinedResponse == null) return Colors.grey;
    
    if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty) {
      return Colors.red;
    }
    
    if (_combinedResponse!.labResults != null) {
      for (var result in _combinedResponse!.labResults!) {
        if (result.isAbnormal) {
          return Colors.orange;
        }
      }
    }
    
    return Colors.green;
  }

  IconData _getHealthStatusIcon() {
    if (_combinedResponse == null) return Icons.help_outline;
    
    if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty) {
      return Icons.warning_amber_rounded;
    }
    
    if (_combinedResponse!.labResults != null) {
      for (var result in _combinedResponse!.labResults!) {
        if (result.isAbnormal) {
          return Icons.warning;
        }
      }
    }
    
    return Icons.check_circle;
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
                        _healthSummaryController.text = _extractHealthSummary(_combinedResponse!.description);
                        _explanationController.text = _extractExplanation(_combinedResponse!.description);
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
            color: _getHealthStatusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getHealthStatusColor().withValues(alpha: 0.3),
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
                      color: _getHealthStatusColor().withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medical_information,
                      color: _getHealthStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Clinical Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getHealthStatusColor(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                _buildFormattedText(_healthSummaryController.text)
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

        const SizedBox(height: 16),

        Container(
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                _buildBulletPoints(_explanationController.text)
              else
                TextField(
                  controller: _explanationController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter recommendations with bullet points...\n• Point 1\n• Point 2\n• Point 3',
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

  Widget _buildBulletPoints(String text) {
    if (text.isEmpty) {
      return const Text(
        'No recommendations available',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
    
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 4);
        
        if (line.trim().startsWith('•') || line.trim().startsWith('-') || line.trim().startsWith('*')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildFormattedText(line.trim().substring(1).trim()),
                ),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildFormattedText(line),
          );
        }
      }).toList(),
    );
  }

  Widget _buildDetailedResults() {
    if (_combinedResponse == null) return const SizedBox.shrink();
    
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
                child: const Icon(Icons.science, color: Colors.deepPurple, size: 20),
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

          if (_combinedResponse!.labResults != null && _combinedResponse!.labResults!.isNotEmpty) ...[
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
                  color: result.isNormal ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: result.isNormal ? Colors.green.shade200 : Colors.red.shade200,
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
                              color: result.isNormal ? Colors.green.shade700 : Colors.red.shade700,
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

          if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty) ...[
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

          if (_combinedResponse!.normalRanges != null && _combinedResponse!.normalRanges!.isNotEmpty) ...[
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
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
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
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.person, size: 20, color: Colors.deepPurple.shade700),
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
                                    border: Border.all(color: Colors.deepPurple, width: 2),
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
                            label: _selectedImages.isEmpty ? 'Add Images' : 'Add More',
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
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Test Details',
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20, color: Colors.deepPurple),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Test Date *',
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
                                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
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
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person, color: Colors.deepPurple),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing with AI...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.deepPurple,
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
                            Icon(Icons.error_outline, color: Colors.red.shade400),
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
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getHealthStatusColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getHealthStatusColor().withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getHealthStatusColor().withValues(alpha: 0.2),
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

                      _buildEditableSection(),

                      const SizedBox(height: 16),

                      _buildDetailedResults(),

                      const SizedBox(height: 20),

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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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