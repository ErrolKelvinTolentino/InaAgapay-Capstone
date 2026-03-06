import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

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

  String? get _geminiApiKey => dotenv.env['GEMINI_API_KEY'];
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

  static const List<String> _pageTitles = <String>[
    'AI Autofill',
    'Personal Information',
    'Vital Statistics',
  ];

  @override
  void dispose() {
    _pageController.dispose();
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

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
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
    final String? apiKey = _geminiApiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('Set GEMINI_API_KEY in your .env file.');
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
        'responseMimeType': 'application/json',
      },
    };

    final Uri uri = Uri.parse('$_geminiEndpoint?key=$apiKey');
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
    String cleaned = text.trim();

    if (cleaned.startsWith('```')) {
      final int firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      final int fenceEnd = cleaned.lastIndexOf('```');
      if (fenceEnd != -1) {
        cleaned = cleaned.substring(0, fenceEnd).trim();
      }
    }

    if ((cleaned.startsWith('{') && cleaned.endsWith('}')) ||
        (cleaned.startsWith('[') && cleaned.endsWith(']'))) {
      return cleaned;
    }

    final bool looksLikeFields =
        cleaned.contains('"first_name"') || cleaned.contains('\"first_name\"');
    if (looksLikeFields && !cleaned.contains('{')) {
      cleaned = _coerceToJsonObject(cleaned);
    }

    final int start = cleaned.indexOf('{');
    final int end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      final String preview = cleaned.length > 200
          ? '${cleaned.substring(0, 200)}...'
          : cleaned;
      throw Exception('Could not locate JSON in Gemini response: $preview');
    }

    return cleaned.substring(start, end + 1);
  }

  String _coerceToJsonObject(String text) {
    final Map<String, dynamic> map = <String, dynamic>{};
    final List<String> lines = text.split('\n');

    for (final String rawLine in lines) {
      String line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      line = line.replaceAll(RegExp(r'^[\-\*\,\s]+'), '');
      if (!line.contains(':')) {
        continue;
      }

      final int splitIndex = line.indexOf(':');
      String key = line.substring(0, splitIndex).trim();
      String value = line.substring(splitIndex + 1).trim();

      key = key.replaceAll(RegExp("^['\\\"]|['\\\"]\$"), '');
      value = value.replaceAll(RegExp(r",\s*$"), '').trim();

      if (value.toLowerCase() == 'null') {
        map[key] = null;
        continue;
      }

      final bool isNumber = RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value);
      if (isNumber) {
        map[key] = num.tryParse(value);
        continue;
      }

      value = value.replaceAll(RegExp("^['\\\"]|['\\\"]\$"), '');
      map[key] = value;
    }

    return jsonEncode(map);
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

  void _clearFields() {
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _extensionNameController.clear();
    _phoneNumberController.clear();
    _emailAddressController.clear();
    _birthdateController.clear();
    _heightController.clear();
    _weightController.clear();

    setState(() {
      _bloodType = null;
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Page builders
  // ---------------------------------------------------------------------------

  Widget _buildPage1() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: <Widget>[
        const Text(
          'Upload or capture an image to automatically fill the form fields.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
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
          height: 220,
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
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _selectedImage == null ? null : _removeImage,
          child: const Text('Remove Image'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _clearFields,
          child: const Text('Clear All Fields'),
        ),
      ],
    );
  }

  Widget _buildPage2() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: <Widget>[
        const Text(
          'Enter your personal details below.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'First Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _middleNameController,
          decoration: const InputDecoration(
            labelText: 'Middle Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Last Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _extensionNameController,
          decoration: const InputDecoration(
            labelText: 'Extension Name (e.g. Jr., Sr.)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneNumberController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailAddressController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPage3() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: <Widget>[
        const Text(
          'Provide your vital statistics below.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _birthdateController,
          readOnly: true,
          onTap: _pickBirthdate,
          decoration: const InputDecoration(
            labelText: 'Birthdate',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Height (cm)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String?>(_bloodType),
          value: _bloodType,
          decoration: const InputDecoration(
            labelText: 'Blood Type',
            border: OutlineInputBorder(),
          ),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Step indicator
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(_totalPages, (int index) {
        final bool isActive = index == _currentPage;
        final bool isCompleted = index < _currentPage;
        return Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 32 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            if (index < _totalPages - 1)
              Container(
                width: 24,
                height: 2,
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _pageTitles[_currentPage],
            key: ValueKey<int>(_currentPage),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              _buildStepIndicator(),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Step ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: <Widget>[
                    _buildPage1(),
                    _buildPage2(),
                    _buildPage3(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previousPage,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              if (_currentPage < _totalPages - 1)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    iconAlignment: IconAlignment.end,
                  ),
                ),
              if (_currentPage == _totalPages - 1)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showMessage('Form submitted!');
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Submit'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
