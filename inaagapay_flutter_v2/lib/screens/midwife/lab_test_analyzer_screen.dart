// lib/screens/midwife/lab_test_analyzer_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_service.dart';
import '../../services/auth_storage.dart';
import '../../models/gemini_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dialog_box.dart';

class LabTestAnalyzerScreen extends StatefulWidget {
  const LabTestAnalyzerScreen({super.key});

  @override
  State<LabTestAnalyzerScreen> createState() => _LabTestAnalyzerScreenState();
}

class _LabTestAnalyzerScreenState extends State<LabTestAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();

  final List<XFile> _selectedImages = [];
  GeminiResponse? _combinedResponse;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _rawResponse = '';

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
          _rawResponse = '';
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
          _rawResponse = '';
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
      _rawResponse = '';
    });
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _combinedResponse = null;
      _errorMessage = null;
      _rawResponse = '';
    });
  }

  Future<void> _analyzeImages() async {
    if (_selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one lab test image';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _combinedResponse = null;
      _rawResponse = '';
    });

    try {
      final result = await _geminiService.analyzeLabTestImages(_selectedImages);
      
      // Store raw response for debugging
      _rawResponse = result.description;
      
      // Log the response for debugging
      if (kDebugMode) {
        print('=== GEMINI RESPONSE ===');
        print('Description length: ${result.description.length}');
        print('First 500 chars: ${result.description.substring(0, min(500, result.description.length))}');
        print('Has labResults: ${result.labResults != null}');
        print('LabResults count: ${result.labResults?.length ?? 0}');
        print('Has overallAssessment: ${result.overallAssessment != null}');
      }
      
      setState(() {
        _combinedResponse = result;
        _isLoading = false;
      });
      
      // If no lab results were parsed, show a warning
      if (result.labResults == null || result.labResults!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI analyzed the image but could not extract structured lab results. Check the full response below.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      final List<int> uploadedFileIds = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final bytes = await image.readAsBytes();
        final fileName = 'lab_test_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final filePath = 'lab-tests/$motherId/$fileName';
        
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
        final fileResponse = await Supabase.instance.client.from('files').insert({
          'bucket_name': 'medical-images',
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
        }).select('file_id').single();
        
        uploadedFileIds.add(fileResponse['file_id']);
      }

      // 3. Create lab test record
      final labTestResponse = await Supabase.instance.client
          .from('lab_tests')
          .insert({
            'pregnancy_id': pregnancyId,
            'lab_test_type': 'Multiple Tests',
            'lab_test_date': DateTime.now().toIso8601String().split('T')[0],
            'lab_test_location': 'Mobile Upload',
            'remarks': _combinedResponse!.overallAssessment ?? 
                      (_combinedResponse!.description.length > 500 
                          ? _combinedResponse!.description.substring(0, 500) + '...' 
                          : _combinedResponse!.description),
            'health_worker_name': 'Self (AI Assisted)',
            'health_worker_institution': 'Inaagapay App',
            'health_worker_profession': 'Patient',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('lab_test_id')
          .single();

      final labTestId = labTestResponse['lab_test_id'];

      // 4. Create AI response record
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

      // 5. Link files to lab test record
      for (int i = 0; i < uploadedFilePaths.length; i++) {
        await Supabase.instance.client
            .from('files')
            .update({
              'reference_id': labTestId,
            })
            .eq('file_id', uploadedFileIds[i]);
      }

      // Show success dialog
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (_) => DialogBox(
          title: 'Success',
          content: 'Lab test analysis saved successfully!',
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
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.orange.shade700),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Lab Test Analysis',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.orange,
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
                            border: Border.all(color: Colors.orange, width: 1.5),
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
                      foregroundColor: Colors.orange.shade700,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analyzeImages,
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text(
                      'Analyze',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.orange,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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

            // Lab Test Results Response
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
                        // Lab Results
                        if (_combinedResponse!.labResults != null && _combinedResponse!.labResults!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Laboratory Results',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._combinedResponse!.labResults!.map((result) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: result.isNormal ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: result.isNormal ? Colors.green.shade200 : Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      result.isNormal ? Icons.check_circle : Icons.warning,
                                      color: result.isNormal ? Colors.green : Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            result.testName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            result.value,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: result.isNormal ? Colors.green.shade700 : Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Raw Analysis Result:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _combinedResponse!.description,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Overall Assessment
                        if (_combinedResponse!.overallAssessment != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Assessment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _combinedResponse!.overallAssessment!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),

                        if (_combinedResponse!.overallAssessment != null)
                          const SizedBox(height: 20),

                        // Abnormal Findings
                        if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Abnormal Findings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._combinedResponse!.abnormalFindings!.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(f)),
                                  ],
                                ),
                              )),
                            ],
                          ),

                        if (_combinedResponse!.abnormalFindings != null && _combinedResponse!.abnormalFindings!.isNotEmpty)
                          const SizedBox(height: 20),

                        // Normal Ranges
                        if (_combinedResponse!.normalRanges != null && _combinedResponse!.normalRanges!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reference Ranges',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._combinedResponse!.normalRanges!.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info, size: 14, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              )),
                            ],
                          ),

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
                                  'For reference only. Always consult your healthcare provider for proper interpretation.',
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

int min(int a, int b) => a < b ? a : b;