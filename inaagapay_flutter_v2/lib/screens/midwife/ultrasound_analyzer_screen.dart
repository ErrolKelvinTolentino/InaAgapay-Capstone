// Update imports at the top of the file
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Change these:
import '../../services/gemini_service.dart';
import '../../services/auth_storage.dart';
import '../../models/gemini_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dialog_box.dart';
class UltrasoundAnalyzerScreen extends StatefulWidget {
  const UltrasoundAnalyzerScreen({super.key});

  @override
  State<UltrasoundAnalyzerScreen> createState() => _UltrasoundAnalyzerScreenState();
}

class _UltrasoundAnalyzerScreenState extends State<UltrasoundAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();

  final List<XFile> _selectedImages = [];
  GeminiResponse? _combinedResponse;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  // Controllers for editable fields
  late TextEditingController _healthSummaryController;
  late TextEditingController _explanationController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _healthSummaryController = TextEditingController();
    _explanationController = TextEditingController();
  }

  @override
  void dispose() {
    _healthSummaryController.dispose();
    _explanationController.dispose();
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
      _combinedResponse = null;
      _isEditing = false;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _combinedResponse = null;
      _errorMessage = null;
      _isEditing = false;
    });
  }

  Future<void> _analyzeImages() async {
    if (_selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one ultrasound image';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _combinedResponse = null;
      _isEditing = false;
    });

    try {
      final result = await _geminiService.analyzeUltrasoundImages(_selectedImages);
      
      setState(() {
        _combinedResponse = result;
        _isLoading = false;
        // Initialize text controllers with the response
        _healthSummaryController.text = _extractHealthSummary(result.description);
        _explanationController.text = _extractExplanation(result.description);
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
      final motherId = await AuthStorage.getMotherId();
      
      if (userId == null) {
        throw Exception('User not logged in');
      }

      if (motherId == null) {
        throw Exception('Mother ID not found');
      }

      // Get the current pregnancy ID for this mother
      final pregnancyResponse = await Supabase.instance.client
          .from('pregnancies')
          .select('pregnancy_id')
          .eq('mother_id', motherId)
          .eq('status', 'ongoing')
          .maybeSingle();

      if (pregnancyResponse == null) {
        throw Exception('No ongoing pregnancy found');
      }

      final pregnancyId = pregnancyResponse['pregnancy_id'];

      // 1. Upload images to Supabase Storage
      final List<String> uploadedFilePaths = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final bytes = await image.readAsBytes();
        final fileName = 'ultrasound_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final filePath = 'ultrasounds/$motherId/$fileName';
        
        // Upload to Supabase Storage
        await Supabase.instance.client.storage
            .from('medical-images')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        
        uploadedFilePaths.add(filePath);
        
        // 2. Create file record in files table
        await Supabase.instance.client.from('files').insert({
          'bucket_name': 'medical-images',
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
        });
      }

      // 3. Create ultrasound record
      final ultrasoundResponse = await Supabase.instance.client
          .from('ultrasounds')
          .insert({
            'pregnancy_id': pregnancyId,
            'ultrasound_date': DateTime.now().toIso8601String().split('T')[0],
            'ultrasound_location': 'Mobile Upload',
            'remarks': _healthSummaryController.text,
            'health_worker_name': 'Self (AI Assisted)',
            'health_worker_institution': 'Inaagapay App',
            'health_worker_profession': 'Patient',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('ultrasound_id')
          .single();

      final ultrasoundId = ultrasoundResponse['ultrasound_id'];

      // 4. Create AI response record
      await Supabase.instance.client
          .from('ai_responses')
          .insert({
            'response_type': 'ultrasound_analysis',
            'reference_table': 'ultrasounds',
            'reference_id': ultrasoundId,
            'ai_model': 'Gemini 1.5 Flash',
            'confidence_score': 0.92,
            'response': _combinedResponse!.description,
            'response_category': 'analysis',
            'status': 'generated',
            'generated_by_ai': true,
            'created_at': DateTime.now().toIso8601String(),
          });

      // 5. Link files to ultrasound record
      for (String filePath in uploadedFilePaths) {
        await Supabase.instance.client
            .from('files')
            .update({
              'reference_id': ultrasoundId,
            })
            .eq('file_path', filePath);
      }

      // Show success dialog
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (_) => DialogBox(
          title: 'Success',
          content: 'Ultrasound analysis saved successfully!',
          buttonText: 'OK',
          type: DialogType.success,
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Go back to records screen
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
    // Extract health summary from description
    final summaryMatch = RegExp(r'HEALTH SUMMARY:([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
    if (summaryMatch != null) {
      return summaryMatch.group(1)?.trim() ?? description.split('\n').first;
    }
    return description.split('\n').first;
  }

  String _extractExplanation(String description) {
    // First, try to extract BASIS/REASONING/EXPLANATION section
    final explanationMatch = RegExp(r'(?:BASIS|REASONING|EXPLANATION):([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
    if (explanationMatch != null) {
      return explanationMatch.group(1)?.trim() ?? '';
    }
    
    // If no specific section, filter out the unwanted sections
    final lines = description.split('\n');
    final filteredLines = <String>[];
    
    bool skipSection = false;
    
    for (String line in lines) {
      // Skip Anatomical Assessment section
      if (line.contains('ANATOMICAL ASSESSMENT:')) {
        skipSection = true;
        continue;
      }
      
      // Skip KEY OBSERVATIONS section
      if (line.contains('KEY OBSERVATIONS:')) {
        skipSection = true;
        continue;
      }
      
      // Stop skipping when we hit HEALTH SUMMARY or end of sections
      if (line.contains('HEALTH SUMMARY:')) {
        skipSection = false;
        continue;
      }
      
      // Only add lines when not in skipped sections
      if (!skipSection) {
        // Skip empty lines at boundaries
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

  // Helper function to format text with bold for capitalized words
  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    
    final words = text.split(' ');
    final List<TextSpan> spans = [];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      // Check if word is all caps and longer than 1 character
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
      
      // Add space between words (except last)
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

  Color _getHealthStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('HEALTHY') || status.contains('NORMAL')) return Colors.green;
    if (status.contains('MONITORING')) return Colors.amber;
    return Colors.grey;
  }

  IconData _getHealthStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;
    if (status.contains('HEALTHY') || status.contains('NORMAL')) return Icons.check_circle;
    if (status.contains('MONITORING')) return Icons.warning;
    return Icons.help_outline;
  }

  Widget _buildEditableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit/Save buttons
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
                icon: Icon(Icons.edit, color: Colors.teal.shade700),
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

        // Health Summary (Editable)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getHealthStatusColor(_combinedResponse!.healthStatus).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getHealthStatusColor(_combinedResponse!.healthStatus).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety, color: _getHealthStatusColor(_combinedResponse!.healthStatus), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Health Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_isEditing)
                _buildFormattedText(_healthSummaryController.text)
              else
                TextField(
                  controller: _healthSummaryController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter health summary...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Explanation with Bullet Points (Editable)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Why?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isEditing)
                _buildBulletPoints(_explanationController.text)
              else
                TextField(
                  controller: _explanationController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter explanation with bullet points...\n• Point 1\n• Point 2\n• Point 3',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoints(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 4);
        
        // Check if line starts with bullet point
        if (line.trim().startsWith('•') || line.trim().startsWith('-') || line.trim().startsWith('*')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildExtraDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: Colors.teal.shade700, size: 18),
          ),
          title: Text(
            'Detailed Findings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Measurements
                  if (_combinedResponse!.measurements != null && _combinedResponse!.measurements!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.straighten, color: Colors.teal.shade600, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Measurements',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._combinedResponse!.measurements!.map((measurement) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 24),
                            child: Text(
                              '• $measurement',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          );
                        }).toList(),
                      ],
                    ),

                  if (_combinedResponse!.measurements != null && _combinedResponse!.measurements!.isNotEmpty)
                    const SizedBox(height: 16),

                  // Key Findings
                  if (_combinedResponse!.normalFindings != null && _combinedResponse!.normalFindings!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key, color: Colors.amber.shade600, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Key Findings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._combinedResponse!.normalFindings!.map((finding) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 24),
                            child: Text(
                              '• $finding',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          );
                        }).toList(),
                      ],
                    ),

                  // Concerns (if any)
                  if (_combinedResponse!.concerns != null && _combinedResponse!.concerns!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.amber.shade700, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Areas to Monitor',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._combinedResponse!.concerns!.map((concern) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4, left: 24),
                              child: Text(
                                '• $concern',
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                  // Disclaimer
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'For reference only. Always consult your healthcare provider.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                                fontStyle: FontStyle.italic,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Ultrasound Assessment',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 22),
              onPressed: _clearAll,
              tooltip: 'Clear all images',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Selected Images Grid
            if (_selectedImages.isNotEmpty)
              Container(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                              padding: const EdgeInsets.all(2),
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: Text(
                      _selectedImages.isEmpty ? 'Add Images' : 'Add More',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade700,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.teal.shade200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analyzeImages,
                    icon: const Icon(Icons.health_and_safety, size: 18),
                    label: const Text(
                      'Assess',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Loading Indicator
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Analyzing...',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error Message
            if (_errorMessage != null && !_isLoading)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Health Assessment Response
            if (_combinedResponse != null && !_isLoading)
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getHealthStatusColor(_combinedResponse!.healthStatus).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getHealthStatusColor(_combinedResponse!.healthStatus).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getHealthStatusIcon(_combinedResponse!.healthStatus),
                                color: _getHealthStatusColor(_combinedResponse!.healthStatus),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _combinedResponse!.healthStatus ?? 'Assessment Complete',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _getHealthStatusColor(_combinedResponse!.healthStatus),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Editable Sections (Health Summary + Why?)
                        _buildEditableSection(),

                        // Extra Details Dropdown (contains Key Findings)
                        _buildExtraDetails(),

                        const SizedBox(height: 20),

                        // Save Button
                        if (!_isSaving)
                          ElevatedButton.icon(
                            onPressed: _saveToDatabase,
                            icon: const Icon(Icons.save),
                            label: const Text('Save to Records'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}