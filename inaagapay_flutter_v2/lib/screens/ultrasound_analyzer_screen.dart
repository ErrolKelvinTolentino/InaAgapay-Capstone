import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gemini_service.dart';
import '../services/auth_storage.dart';
import '../models/gemini_response.dart';
import '../theme/app_colors.dart';
import '../widgets/dialog_box.dart';

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
    });
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _combinedResponse = null;
      _errorMessage = null;
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
    });

    try {
      final result = await _geminiService.analyzeUltrasoundImages(_selectedImages);
      
      setState(() {
        _combinedResponse = result;
        _isLoading = false;
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
    final summaryMatch = RegExp(r'HEALTH SUMMARY:([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
    if (summaryMatch != null) {
      return summaryMatch.group(1)?.trim() ?? description.split('\n').first;
    }
    return description.split('\n').first;
  }

  String _extractExplanation(String description) {
    final explanationMatch = RegExp(r'(?:BASIS|REASONING|EXPLANATION):([^\n]*(?:\n[^\n]*)*?)(?=\n\n|\Z)', caseSensitive: false).firstMatch(description);
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
                  color: Colors.purple.shade800,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.purple.shade700),
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
    if (status.contains('MONITORING')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getHealthStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;
    if (status.contains('HEALTHY') || status.contains('NORMAL')) return Icons.check_circle;
    if (status.contains('MONITORING')) return Icons.warning;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Ultrasound Analysis',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
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
                            border: Border.all(color: Colors.purple, width: 1.5),
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
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple.shade700,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.purple.shade200),
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
                      'Analyze',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.purple,
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
                        ),
                        child: const Column(
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Analyzing with Gemini 1.5 Flash...',
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        if (_combinedResponse!.healthStatus != null)
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
                                  _combinedResponse!.healthStatus!,
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

                        // Measurements
                        if (_combinedResponse!.measurements != null && _combinedResponse!.measurements!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Measurements',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._combinedResponse!.measurements!.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 16, color: Colors.purple),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(m)),
                                  ],
                                ),
                              )),
                            ],
                          ),

                        if (_combinedResponse!.measurements != null && _combinedResponse!.measurements!.isNotEmpty)
                          const SizedBox(height: 20),

                        // Normal Findings
                        if (_combinedResponse!.normalFindings != null && _combinedResponse!.normalFindings!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Normal Findings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._combinedResponse!.normalFindings!.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(f)),
                                  ],
                                ),
                              )),
                            ],
                          ),

                        if (_combinedResponse!.normalFindings != null && _combinedResponse!.normalFindings!.isNotEmpty)
                          const SizedBox(height: 20),

                        // Concerns
                        if (_combinedResponse!.concerns != null && _combinedResponse!.concerns!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Areas to Monitor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._combinedResponse!.concerns!.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c)),
                                  ],
                                ),
                              )),
                            ],
                          ),

                        if (_combinedResponse!.concerns != null && _combinedResponse!.concerns!.isNotEmpty)
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

                        const SizedBox(height: 20),

                        // Disclaimer
                        Container(
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