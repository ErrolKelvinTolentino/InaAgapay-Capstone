import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiFormScreen extends StatefulWidget {
  const AiFormScreen({super.key});

  @override
  State<AiFormScreen> createState() => _AiFormScreenState();
}

class _AiFormScreenState extends State<AiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _extensionNameController =
      TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailAddressController = TextEditingController();

  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String? _bloodType;
  File? _selectedImage;
  bool _isAnalyzing = false;

  static const String _geminiApiKey = 'AIzaSyDfKHISyob-5SjthK2KrJ7syr1CPJ5xAUw';
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const List<String> _bloodTypeOptions = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extensionNameController.dispose();
    _phoneNumberController.dispose();
    _emailAddressController.dispose();
    _birthdateController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image == null) {
      return;
    }

    setState(() {
      _selectedImage = File(image.path);
    });
  }

  Future<void> _captureImageFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (image == null) {
      return;
    }

    setState(() {
      _selectedImage = File(image.path);
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      _showMessage('Please select an image first.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final Map<String, dynamic> result = await _sendImageToGemini(
        _selectedImage!,
      );
      _populateFieldsFromJson(result);
      _showMessage('Form fields updated.');
    } catch (error) {
      _showMessage('Analysis failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _sendImageToGemini(File imageFile) async {
    if (_geminiApiKey == 'AIzaSyDfKHISyob-5SjthK2KrJ7syr1CPJ5xAUw') {
      throw Exception('Set your Gemini API key in ai_form_screen.dart.');
    }

    final List<int> bytes = await imageFile.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final String prompt =
        'Analyze the image and extract the following fields: '
        'first_name, middle_name, last_name, extension_name, phone_number, '
        'email_address, birthdate, height_cm, weight_kg, blood_type. '
        'If a field cannot be determined, return null. '
        'Return only valid JSON with exactly these keys.';

    final Map<String, dynamic> payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': prompt},
            <String, dynamic>{
              'inline_data': <String, dynamic>{
                'mime_type': 'image/jpeg',
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.2,
        'maxOutputTokens': 512,
      },
    };

    final Uri uri = Uri.parse('$_geminiEndpoint?key=$_geminiApiKey');
    final http.Response response = await http.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    final String? text = _extractTextFromResponse(responseBody);
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned no text content.');
    }

    final String jsonText = _extractJsonString(text);
    final Map<String, dynamic> jsonMap =
        jsonDecode(jsonText) as Map<String, dynamic>;
    return jsonMap;
  }

  String? _extractTextFromResponse(Map<String, dynamic> responseBody) {
    final List<dynamic>? candidates =
        responseBody['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? content =
        candidates.first['content'] as Map<String, dynamic>?;
    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? firstPart =
        parts.first as Map<String, dynamic>?;
    return firstPart?['text'] as String?;
  }

  String _extractJsonString(String text) {
    final String trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final int start = trimmed.indexOf('{');
    final int end = trimmed.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw Exception('Could not locate JSON in Gemini response.');
    }

    return trimmed.substring(start, end + 1);
  }

  void _populateFieldsFromJson(Map<String, dynamic> data) {
    _firstNameController.text = _stringValue(data['first_name']);
    _middleNameController.text = _stringValue(data['middle_name']);
    _lastNameController.text = _stringValue(data['last_name']);
    _extensionNameController.text = _stringValue(data['extension_name']);
    _phoneNumberController.text = _stringValue(data['phone_number']);
    _emailAddressController.text = _stringValue(data['email_address']);
    _birthdateController.text = _stringValue(data['birthdate']);

    final String heightValue = _stringValue(data['height_cm']);
    final String weightValue = _stringValue(data['weight_kg']);
    _heightController.text = heightValue;
    _weightController.text = weightValue;

    final String? bloodTypeValue = _nullableStringValue(data['blood_type']);
    setState(() {
      _bloodType = _bloodTypeOptions.contains(bloodTypeValue)
          ? bloodTypeValue
          : null;
    });
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String? _nullableStringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final String stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  Future<void> _pickBirthdate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    final String formatted =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      _birthdateController.text = formatted;
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Form Autofill')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectImageFromGallery,
                      icon: const Icon(Icons.image),
                      label: const Text('Upload Image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _captureImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Use Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage == null
                    ? const Center(child: Text('No image selected'))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeImage,
                child: _isAnalyzing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Analyze Image'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Personal Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(labelText: 'Middle Name'),
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextFormField(
                controller: _extensionNameController,
                decoration: const InputDecoration(labelText: 'Extension Name'),
              ),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              TextFormField(
                controller: _emailAddressController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vital Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthdateController,
                readOnly: true,
                onTap: _pickBirthdate,
                decoration: const InputDecoration(
                  labelText: 'Birthdate',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>(_bloodType),
                initialValue: _bloodType,
                decoration: const InputDecoration(labelText: 'Blood Type'),
                items: _bloodTypeOptions
                    .map(
                      (String type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _bloodType = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
