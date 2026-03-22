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
import '../../widgets/app_input_field.dart';

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
  late TextEditingController _remarksController;
  bool _isEditing = false;

  DateTime? _labTestDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _healthWorkerNameController = TextEditingController();
  final TextEditingController _healthWorkerInstitutionController = TextEditingController();
  final TextEditingController _healthWorkerProfessionController = TextEditingController();

  final List<String> _uploadedImageUrls = [];

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();
    _explanationController = TextEditingController();
    _remarksController = TextEditingController();
    
    _labTestDate = DateTime.now();
    _dateController.text = _dateFormat.format(_labTestDate!);
  }

  @override
  void dispose() {
    _healthSummaryController.dispose();
    _explanationController.dispose();
    _remarksController.dispose();
    _dateController.dispose();
    _healthWorkerNameController.dispose();
    _healthWorkerInstitutionController.dispose();
    _healthWorkerProfessionController.dispose();
    super.dispose();
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
      _remarksController.clear();
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
      
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
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
        final fileName = 'labtest_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final filePath = 'lab-tests/${widget.motherId}/$fileName';
        
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

      String labTestType = 'Laboratory Test';
      if (_combinedResponse!.labResults != null && _combinedResponse!.labResults!.isNotEmpty) {
        final firstTest = _combinedResponse!.labResults!.first;
        if (firstTest.testName.isNotEmpty) {
          labTestType = firstTest.testName;
        }
      }

      final labTestResponse = await Supabase.instance.client
          .from('lab_tests')
          .insert({
            'pregnancy_id': widget.pregnancyId,
            'lab_test_type': labTestType,
            'lab_test_date': _labTestDate!.toIso8601String().split('T')[0],
            'lab_test_location': 'Mobile Upload',
            'lab_test_image': _uploadedImageUrls.isNotEmpty 
                ? _uploadedImageUrls.join(',')
                : null,
            'remarks': _remarksController.text.trim().isEmpty 
                ? _healthSummaryController.text 
                : _remarksController.text.trim(),
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
            'response': _healthSummaryController.text,
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
        debugPrint('Error saving to database: $e');
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
    
    final lines = description.split('\n');
    final filteredLines = <String>[];
    
    bool skipSection = false;
    
    for (String line in lines) {
      if (line.contains('LABORATORY RESULTS:')) {
        skipSection = true;
        continue;
      }
      
      if (line.contains('ABNORMAL FINDINGS:')) {
        skipSection = true;
        continue;
      }
      
      if (line.contains('OVERALL ASSESSMENT:')) {
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
      return const Color(0xFFF44336);
    }
    
    if (_combinedResponse!.labResults != null) {
      for (var result in _combinedResponse!.labResults!) {
        if (result.isAbnormal) {
          return const Color(0xFFFF9800);
        }
      }
    }
    
    return const Color(0xFF4CAF50);
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

  List<_AISection> _parseAISections(String text) {
    final sections = <_AISection>[];
    
    final patterns = {
      'OVERALL ASSESSMENT': {
        'icon': Icons.health_and_safety,
        'color': _getHealthStatusColor(),
        'collapsible': false,
      },
      'LABORATORY RESULTS': {
        'icon': Icons.science,
        'color': const Color(0xFF2196F3),
        'collapsible': true,
      },
      'ABNORMAL FINDINGS': {
        'icon': Icons.warning,
        'color': const Color(0xFFF44336),
        'collapsible': true,
      },
      'NORMAL RANGES': {
        'icon': Icons.info_outline,
        'color': const Color(0xFF4CAF50),
        'collapsible': true,
      },
      'RECOMMENDATIONS': {
        'icon': Icons.lightbulb_outline,
        'color': const Color(0xFF00BCD4),
        'collapsible': false,
      },
    };
    
    String currentSection = '';
    StringBuffer currentContent = StringBuffer();
    
    final lines = text.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      String? foundSection;
      for (var pattern in patterns.keys) {
        if (line.contains(pattern) || line.toUpperCase().contains(pattern)) {
          foundSection = pattern;
          break;
        }
      }
      
      if (foundSection != null) {
        if (currentSection.isNotEmpty && currentContent.isNotEmpty) {
          sections.add(_AISection(
            title: currentSection,
            icon: patterns[currentSection]!['icon'] as IconData,
            color: patterns[currentSection]!['color'] as Color,
            content: currentContent.toString().trim(),
            isCollapsible: patterns[currentSection]!['collapsible'] as bool,
          ));
        }
        currentSection = foundSection;
        currentContent.clear();
      } else if (currentSection.isNotEmpty) {
        currentContent.writeln(line);
      }
    }
    
    if (currentSection.isNotEmpty && currentContent.isNotEmpty) {
      sections.add(_AISection(
        title: currentSection,
        icon: patterns[currentSection]!['icon'] as IconData,
        color: patterns[currentSection]!['color'] as Color,
        content: currentContent.toString().trim(),
        isCollapsible: patterns[currentSection]!['collapsible'] as bool,
      ));
    }
    
    return sections;
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
              _buildActionChip(
                icon: Icons.edit_outlined,
                label: 'Edit Notes',
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                color: AppColors.brandPrimary,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionChip(
                    icon: Icons.save_outlined,
                    label: 'Save',
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildActionChip(
                    icon: Icons.close_outlined,
                    label: 'Cancel',
                    onPressed: () {
                      setState(() {
                        _healthSummaryController.text = _extractHealthSummary(_combinedResponse!.description);
                        _explanationController.text = _extractExplanation(_combinedResponse!.description);
                        _isEditing = false;
                      });
                    },
                    color: AppColors.error,
                  ),
                ],
              ),
          ],
        ),

        const SizedBox(height: 16),

        _buildHealthStatusBanner(),

        const SizedBox(height: 20),

        if (!_isEditing)
          _buildStructuredAnalysis(_healthSummaryController.text)
        else
          _buildEditSectionContent(),

        const SizedBox(height: 20),

        _buildDetailedResults(),

        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildHealthStatusBanner() {
    final status = _getHealthStatus();
    final statusColor = _getHealthStatusColor();
    final statusIcon = _getHealthStatusIcon();
    
    String statusDescription;
    Color statusBgColor;
    IconData statusBgIcon;
    
    if (status.contains('NORMAL')) {
      statusDescription = 'All laboratory values are within normal ranges';
      statusBgColor = const Color(0xFF4CAF50);
      statusBgIcon = Icons.health_and_safety;
    } else if (status.contains('ABNORMAL')) {
      statusDescription = 'Some values are outside normal ranges - requires attention';
      statusBgColor = const Color(0xFFF44336);
      statusBgIcon = Icons.warning_amber_rounded;
    } else {
      statusDescription = 'Please review findings with healthcare provider';
      statusBgColor = const Color(0xFFFF9800);
      statusBgIcon = Icons.medical_information;
    }
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusBgColor.withValues(alpha: 0.12),
            statusBgColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusBgColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              statusBgIcon,
              size: 80,
              color: statusBgColor.withValues(alpha: 0.08),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusBgColor.withValues(alpha: 0.2),
                        statusBgColor.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusBgColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusBgColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
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
    );
  }

  Widget _buildStructuredAnalysis(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    
    final sections = _parseAISections(text);
    
    if (sections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: _buildFormattedContent(text),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        return _buildSectionCard(
          title: section.title,
          icon: section.icon,
          color: section.color,
          content: section.content,
          isCollapsible: section.isCollapsible,
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
    bool isCollapsible = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderPrimary, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (isCollapsible)
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: color,
                      size: 20,
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFormattedContent(content),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    if (content.isEmpty) {
      return const Text(
        'No content available',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    final lines = content.split('\n');
    final List<Widget> widgets = [];
    bool inBulletList = false;
    bool inNumberedList = false;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        if (inBulletList || inNumberedList) {
          widgets.add(const SizedBox(height: 8));
          inBulletList = false;
          inNumberedList = false;
        } else {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }
      
      if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
        if (!inBulletList && widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 4));
        }
        inBulletList = true;
        inNumberedList = false;
        
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brandPrimary, AppColors.brandAccent],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      else if (RegExp(r'^\d+\.').hasMatch(line)) {
        if (!inNumberedList && widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 4));
        }
        inNumberedList = true;
        inBulletList = false;
        
        final parts = line.split('.');
        final number = parts[0];
        final rest = parts.sublist(1).join('.').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$number.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rest,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      else if (line == line.toUpperCase() && line.length > 3 && !line.contains(RegExp(r'[a-z]'))) {
        inBulletList = false;
        inNumberedList = false;
        
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.1),
                    AppColors.brandSecondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.brandPrimary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        );
      }
      else if (line.contains('**')) {
        inBulletList = false;
        inNumberedList = false;
        
        final parts = line.split('**');
        final List<TextSpan> spans = [];
        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 1) {
            spans.add(TextSpan(
              text: parts[i],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ));
          } else {
            spans.add(TextSpan(
              text: parts[i],
              style: const TextStyle(color: AppColors.textPrimary),
            ));
          }
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(children: spans, style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ),
        );
      }
      else if (line.contains('✅') || line.contains('NORMAL')) {
        inBulletList = false;
        inNumberedList = false;
        
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      else if (line.contains('⚠️') || line.contains('ABNORMAL') || line.contains('HIGH') || line.contains('LOW')) {
        inBulletList = false;
        inNumberedList = false;
        
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF44336).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF44336).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: const Color(0xFFF44336), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFF44336),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      else {
        inBulletList = false;
        inNumberedList = false;
        
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildEditSectionContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderPrimary),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Clinical Notes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          Text(
                            'You can edit the AI analysis. Formatting tips:',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildFormatTip('•', 'Bullet points'),
                              _buildFormatTip('1.', 'Numbered lists'),
                              _buildFormatTip('**bold**', 'Bold text'),
                              _buildFormatTip('CAPS', 'Section headers'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: TextField(
                  controller: _healthSummaryController,
                  maxLines: 20,
                  minLines: 12,
                  decoration: InputDecoration(
                    hintText: 'Edit the clinical assessment here...\n\n'
                        'Tips:\n'
                        '• Use "•" for bullet points\n'
                        '• Use "1.", "2." for numbered lists\n'
                        '• Use ALL CAPS for section headers\n'
                        '• Press Enter for new lines',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showPreviewDialog();
                      },
                      icon: const Icon(Icons.preview, size: 18),
                      label: const Text('Preview Changes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        side: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildFormatTip(String symbol, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.preview,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Preview - Clinical Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildFormattedContent(_healthSummaryController.text),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderPrimary),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Changes saved. Click Save to Records to finalize.'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                        ),
                        child: const Text('Keep Changes'),
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
  }

  Widget _buildDetailedResults() {
    if (_combinedResponse == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.12),
                    AppColors.brandPrimary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.science, color: AppColors.brandPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'DETAILED LABORATORY RESULTS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          color: result.isNormal ? const Color(0xFF4CAF50).withValues(alpha: 0.08) : const Color(0xFFF44336).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: result.isNormal ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : const Color(0xFFF44336).withValues(alpha: 0.2),
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
                                color: result.isNormal ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
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
                                      color: result.isNormal ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
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
                                color: result.isNormal ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
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
                          color: const Color(0xFFF44336).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF44336).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Color(0xFFF44336), size: 16),
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
                            Icon(Icons.info, color: AppColors.brandPrimary, size: 16),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This analysis is AI-generated for reference only. Always consult with a qualified healthcare provider for proper interpretation and clinical decisions.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ),
        ],
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
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: AppColors.brandPrimary),
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
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt, color: AppColors.brandPrimary),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          Column(
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
                        icon: const Icon(Icons.delete_sweep, color: AppColors.error),
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
                          color: AppColors.brandPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.person, size: 20, color: AppColors.brandPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mother #${widget.motherId}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Pregnancy ID: ${widget.pregnancyId}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.brandPrimary.withValues(alpha: 0.7),
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
                                      border: Border.all(color: AppColors.brandPrimary, width: 2),
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
                                          color: AppColors.error,
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.assignment, color: AppColors.brandPrimary),
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
                                    const Icon(Icons.calendar_today, size: 20, color: AppColors.brandPrimary),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person, color: AppColors.brandPrimary),
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
                            
                            AppInputField(
                              hintText: 'Full Name *',
                              controller: _healthWorkerNameController,
                              isRequired: true,
                              leadingIcon: Icons.person_outline,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            AppInputField(
                              hintText: 'Institution / Clinic',
                              controller: _healthWorkerInstitutionController,
                              leadingIcon: Icons.business_outlined,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            AppInputField(
                              hintText: 'Profession *',
                              controller: _healthWorkerProfessionController,
                              isRequired: true,
                              leadingIcon: Icons.work_outline,
                            ),
                            
                            const SizedBox(height: 12),
                            
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
                                  hintText: 'Remarks (Optional)',
                                  border: InputBorder.none,
                                  icon: Icon(Icons.note_outlined, color: AppColors.brandPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_combinedResponse != null && !_isLoading) ...[
                        const SizedBox(height: 16),
                        _buildEditableSection(),
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
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
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
          
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing with AI...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This may take a few moments',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AISection {
  final String title;
  final IconData icon;
  final Color color;
  final String content;
  final bool isCollapsible;
  
  _AISection({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    required this.isCollapsible,
  });
}