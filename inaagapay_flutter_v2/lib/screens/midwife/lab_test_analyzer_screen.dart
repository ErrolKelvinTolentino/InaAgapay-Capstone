// lib/screens/midwife/lab_test_analyzer_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/groq_service.dart';
import '../../services/auth_storage.dart';
import '../../services/lab_cbc_interpretation_engine.dart';
import '../../services/ultrasound_interpretation_engine.dart'
    show MonitoringClassification, Trimester;
import '../../models/groq_response.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_button.dart';
import '../../widgets/app_dropdown_field.dart';

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
  final GroqService _groqService = GroqService();
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  final List<XFile> _selectedImages = [];
  String _selectedLanguage = 'filipino';
  GroqResponse? _combinedResponse;
  bool _isSaving = false;
  String? _errorMessage;

  int _step = 0;
  static const int _totalSteps = 3;
  static const List<String> _stepTitles = [
    'Lab Test Details',
    'Attach Images and Notes',
    'Assessment & Clinical Review',
  ];
  static const List<String> _stepSubtitles = [
    'Set the date and enter optional health worker details.',
    'Attach lab test images and add optional clinical notes.',
    'Review AI-assisted analysis and save to records.',
  ];
  bool _analysisApproved = false;
  bool _aiAnalysisSkipped = false;
  // ignore: unused_field
  bool _showAdvancedAiDetails = false;
  String _activeLabTab = 'risk';
  String _pregnancyRiskLevel = 'low';
  // ignore: unused_field
  DateTime? _pregnancyLmp;
  Trimester _currentTrimester = Trimester.second;
  MonitoringClassification _monitoringClassification =
      MonitoringClassification.withinExpectedRange;
  List<CbcComponentResult> _cbcResults = [];
  bool _showSecondaryDetails = false;
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
  String _motherName = '';

  final List<String> _uploadedImageUrls = [];
  DateTime? _motherBirthdate;
  List<String> _maternalActiveConditions = [];
  List<String> _maternalAllergies = [];
  double? _maternalHeight;
  double? _maternalPrePregWeight;
  int? _pregnancyFetalCount;

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
    _motherName = 'Mother #$_motherId';

    _loadUserContext();
    _loadMotherName();
    _loadPregnancyData();
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

  Future<void> _loadMotherName() async {
    try {
      final response = await Supabase.instance.client
          .from('mothers')
          .select('account:account_id (first_name, last_name)')
          .eq('mother_id', _motherId)
          .maybeSingle();

      if (response != null && response['account'] != null) {
        final account = response['account'] as Map<String, dynamic>;
        final first = account['first_name']?.toString() ?? '';
        final last = account['last_name']?.toString() ?? '';
        final full = '$first $last'.trim();
        if (mounted && full.isNotEmpty) {
          setState(() {
            _motherName = full;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading mother name: $e');
    }
  }

  Future<void> _loadPregnancyData() async {
    try {
      final response = await Supabase.instance.client
          .from('pregnancies')
          .select('last_menstrual_period, pregnancy_risk_level, fetal_count, pre_pregnancy_weight')
          .eq('pregnancy_id', _pregnancyId)
          .maybeSingle();

      if (response != null) {
        if (mounted) {
          setState(() {
            if (response['last_menstrual_period'] != null) {
              _pregnancyLmp = DateTime.parse(response['last_menstrual_period'].toString());
            }
            if (response['pregnancy_risk_level'] != null) {
              _pregnancyRiskLevel = response['pregnancy_risk_level'].toString().toLowerCase();
            }
            if (response['fetal_count'] != null) {
              _pregnancyFetalCount = int.tryParse(response['fetal_count'].toString());
            }
            if (response['pre_pregnancy_weight'] != null) {
              _maternalPrePregWeight = double.tryParse(response['pre_pregnancy_weight'].toString());
            }

            if (_pregnancyLmp != null) {
              final referenceDate = _labTestDate ?? DateTime.now();
              final aogWeeks =
                  LabCbcInterpretationEngine.calculateAogWeeks(_pregnancyLmp!, referenceDate);
              _currentTrimester =
                  LabCbcInterpretationEngine.getTrimester(aogWeeks);
            }
          });
        }
      }

      // Load mother profile details (height, birthdate)
      final motherRes = await Supabase.instance.client
          .from('mothers')
          .select('height, birthdate')
          .eq('mother_id', _motherId)
          .maybeSingle();
      if (motherRes != null) {
        if (mounted) {
          setState(() {
            if (motherRes['height'] != null) {
              _maternalHeight = double.tryParse(motherRes['height'].toString());
            }
            if (motherRes['birthdate'] != null) {
              _motherBirthdate = DateTime.parse(motherRes['birthdate'].toString());
            }
          });
        }
      }

      // Load active medical conditions
      final List conditionsRes = await Supabase.instance.client
          .from('medical_conditions')
          .select('condition_name')
          .eq('mother_id', _motherId)
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          _maternalActiveConditions = conditionsRes
              .map((c) => c['condition_name'].toString())
              .toList();
        });
      }

      // Load allergies
      final List allergiesRes = await Supabase.instance.client
          .from('allergies')
          .select('allergen')
          .eq('mother_id', _motherId)
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          _maternalAllergies = allergiesRes
              .map((a) => a['allergen'].toString())
              .toList();
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading pregnancy details: $e');
    }
  }

  double? _calculatePrePregnancyBmi() {
    if (_maternalPrePregWeight == null || _maternalHeight == null || _maternalHeight! <= 0) return null;
    final heightInMeters = _maternalHeight! / 100.0;
    return _maternalPrePregWeight! / (heightInMeters * heightInMeters);
  }

  int? _calculateMaternalAge() {
    if (_motherBirthdate == null) return null;
    final today = DateTime.now();
    var age = today.year - _motherBirthdate!.year;
    if (today.month < _motherBirthdate!.month ||
        (today.month == _motherBirthdate!.month && today.day < _motherBirthdate!.day)) {
      age--;
    }
    return age;
  }

  String _buildRuleBasedLabSummary({String? lang}) {
    final language = lang ?? _selectedLanguage;
    final trimesterLabel = _currentTrimester == Trimester.first ? 'First Trimester' : (_currentTrimester == Trimester.second ? 'Second Trimester' : 'Third Trimester');
    final trimesterFil = _currentTrimester == Trimester.first ? 'Unang Trimester' : (_currentTrimester == Trimester.second ? 'Ikalawang Trimester' : 'Ikatlong Trimester');
    
    final riskLabelEn = _pregnancyRiskLevel == 'low' ? 'Low Risk' : 'High Risk';
    final riskLabelFil = _pregnancyRiskLevel == 'low' ? 'Mababa (Low Risk)' : 'Mataas (High Risk)';
    
    if (language == 'filipino') {
      return '''Kamusta, mommy! Ang iyong laboratory record para sa $trimesterFil ay naitala na. Ang iyong pangkalahatang pregnancy risk level ay kasalukuyang $riskLabelFil. Upang masubaybayan ang kalagayan ng iyong dugo at maiwasan ang mga karaniwang isyu tulad ng anemia habang nagbubuntis, iminumungkahi namin ang regular na pagsubaybay sa iyong Hemoglobin, Hematocrit, at Platelet levels mula sa iyong CBC report. Ang patuloy na prenatal monitoring ay lubhang makakatulong sa inyong kalusugan.''';
    } else {
      return '''Hello, Mommy! Your laboratory record for the $trimesterLabel has been logged. Your overall pregnancy risk level is evaluated as $riskLabelEn. To support your health and prevent issues like anemia during pregnancy, it is recommended to keep track of your Hemoglobin, Hematocrit, and Platelet levels from your printed CBC report. Continued prenatal checkups and healthcare consultations are highly recommended to support your health.''';
    }
  }

  List<Widget> _buildRiskFactorsPills() {
    final List<Widget> pills = [];

    // BMI Warning Pill
    final bmi = _calculatePrePregnancyBmi();
    if (bmi != null) {
      if (bmi < 18.5) {
        pills.add(_buildRiskPill('Underweight BMI (${bmi.toStringAsFixed(1)})', isSevere: false));
      } else if (bmi >= 25.0 && bmi < 30.0) {
        pills.add(_buildRiskPill('Overweight BMI (${bmi.toStringAsFixed(1)})', isSevere: false));
      } else if (bmi >= 30.0) {
        pills.add(_buildRiskPill('Obese BMI (${bmi.toStringAsFixed(1)})', isSevere: true));
      }
    }

    // Maternal Age Warning Pill
    final age = _calculateMaternalAge();
    if (age != null) {
      if (age < 18) {
        pills.add(_buildRiskPill('Early Maternal Age ($age years)', isSevere: true));
      } else if (age >= 35) {
        pills.add(_buildRiskPill('Advanced Maternal Age ($age years)', isSevere: true));
      }
    }

    // Multiple pregnancy pill
    if (_pregnancyFetalCount != null && _pregnancyFetalCount! > 1) {
      pills.add(_buildRiskPill('Multiple Pregnancy ($_pregnancyFetalCount babies)', isSevere: true));
    }

    // Medical conditions
    for (final cond in _maternalActiveConditions) {
      pills.add(_buildRiskPill('Medical: $cond', isSevere: true));
    }

    // Allergies
    for (final allerg in _maternalAllergies) {
      pills.add(_buildRiskPill('Allergy: $allerg', isSevere: false));
    }

    if (pills.isEmpty) {
      pills.add(_buildRiskPill('No high-risk complications detected', isSevere: false, isSuccess: true));
    }

    return pills;
  }

  Widget _buildRiskPill(String label, {required bool isSevere, bool isSuccess = false}) {
    final Color bgColor = isSuccess
        ? AppColors.success.withValues(alpha: 0.08)
        : (isSevere ? AppColors.error.withValues(alpha: 0.08) : AppColors.warning.withValues(alpha: 0.08));
    final Color borderColor = isSuccess
        ? AppColors.success.withValues(alpha: 0.3)
        : (isSevere ? AppColors.error.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3));
    final Color textColor = isSuccess
        ? AppColors.success
        : (isSevere ? AppColors.error : AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error_outline,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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
      _aiAnalysisSkipped = false;
      _showAdvancedAiDetails = false;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _labTestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              onSurface: AppColors.brandText,
              secondary: AppColors.brandPrimary,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: Colors.white,
              elevation: 4,
              surfaceTintColor: Colors.transparent,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: Colors.white,
              headerForegroundColor: AppColors.brandText,
              headerHeadlineStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.brandText,
              ),
              headerHelpStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _labTestDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }


  bool _validateStep1() {
    if (_labTestDate == null) {
      _showMessage('Please select lab test date.', type: AppSnackType.warning);
      return false;
    }
    // Health worker metadata is optional.
    final selected = _effectiveSelectedProfession();
    if (selected == _otherProfessionOption &&
        _healthWorkerProfessionController.text.trim().isEmpty) {
      _showMessage('You selected "Other" — please specify the profession or clear the selection.',
          type: AppSnackType.warning);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
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

  String? _validateNotesInput() {
    final notes = _notesController.text.trim();

    if (notes.length > 2000) {
      return 'Notes are too long. Please keep notes within 2000 characters.';
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
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final decoded = frame.image;
        final shortestSide =
            decoded.width < decoded.height ? decoded.width : decoded.height;
        if (shortestSide < 400) {
          return 'Image ${i + 1} resolution is too low (minimum 400px on the shortest side). Retake in better lighting and closer framing.';
        }
      } catch (_) {
        return 'Image ${i + 1} could not be decoded. Please upload JPG, PNG, WEBP, or another convertible image.';
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

  bool get _hasEnteredData =>
      _selectedImages.isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _healthWorkerNameController.text.trim().isNotEmpty ||
      _healthWorkerInstitutionController.text.trim().isNotEmpty;

  Future<void> _confirmDiscardAndPop() async {
    if (!_hasEnteredData) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved lab test data. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.pop(context);
    }
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
    if (!_validateStep2()) return;

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
      _aiAnalysisSkipped = false;
      _healthSummaryController.clear();
    });

    try {
      _lastAiPrompt = [
        'Lab test AI analysis request',
        'Notes: ${_notesController.text.trim().isEmpty ? 'None provided' : _notesController.text.trim()}',
        'Image count: ${_selectedImages.length}',
      ].join('\n');

      _setLoadingState(
        'Reading laboratory record',
        'Extracting laboratory values from uploaded images',
      );

      final result = await _groqService.analyzeLabTestImages(
        _selectedImages,
        selectedLabType: null,
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

        // Populate extracted admin fields if available
        if (result.extractedProfessional != null && result.extractedProfessional!.isNotEmpty && _healthWorkerNameController.text.trim().isEmpty) {
          _healthWorkerNameController.text = result.extractedProfessional!;
        }
        if (result.extractedClinicLocation != null && result.extractedClinicLocation!.isNotEmpty && _healthWorkerInstitutionController.text.trim().isEmpty) {
          _healthWorkerInstitutionController.text = result.extractedClinicLocation!;
        }

        // Compute CBC interpretation results from AI-extracted lab data
        if (result.labResults != null && result.labResults!.isNotEmpty) {
          final valueMap = <String, double>{};
          final valueStrs = <String, String>{};
          for (final lr in result.labResults!) {
            final numVal = double.tryParse(
                lr.value.replaceAll(RegExp(r'[^\d.]'), ''));
            if (numVal != null) {
              valueMap[lr.testName] = numVal;
              valueStrs[lr.testName] = lr.value;
            }
          }
          _cbcResults = LabCbcInterpretationEngine.interpretAll(
            values: valueMap,
            valueStrs: valueStrs,
            trimester: _currentTrimester,
          );
          _monitoringClassification =
              LabCbcInterpretationEngine.classifyOverall(_cbcResults);
          _showSecondaryDetails = false;
        }

        _step = 2; // Navigate to Step 3 (0-indexed)
      });
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
    // Only images + AI analysis result are strictly required.
    if (!_validateStep2()) return;
    final aiGenerated = _combinedResponse != null;
    if (!aiGenerated && !_aiAnalysisSkipped) {
      _showMessage('Please run AI analysis or skip it before saving.',
          type: AppSnackType.warning);
      return;
    }
    if (aiGenerated && !_analysisApproved && !_aiAnalysisSkipped) {
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

      // Prefer AI-extracted lab test type. Fall back to first result name.
      String labTestType = 'Multiple Tests';
      if (aiGenerated && _combinedResponse!.extractedLabTestType != null &&
          _combinedResponse!.extractedLabTestType!.trim().isNotEmpty) {
        labTestType = _combinedResponse!.extractedLabTestType!;
      } else if (aiGenerated &&
          _combinedResponse!.labResults != null &&
          _combinedResponse!.labResults!.isNotEmpty) {
        final firstTest = _combinedResponse!.labResults!.first;
        if (firstTest.testName.isNotEmpty) {
          labTestType = firstTest.testName;
        }
      }

      final String remarks = aiGenerated ? _notesController.text.trim() : _healthSummaryController.text.trim();

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

      // Update pregnancy risk level if overridden by midwife
      await Supabase.instance.client
          .from('pregnancies')
          .update({
            'pregnancy_risk_level': _pregnancyRiskLevel,
          })
          .eq('pregnancy_id', _pregnancyId);

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

  // ignore: unused_element
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

  // ignore: unused_element
  Widget _buildCombinedLabResultsCard(
    Map<String, List<String>> sections, {
    VoidCallback? onInteraction,
  }) {
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
                      if (hasDetails)
                        IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          constraints: const BoxConstraints.tightFor(
                              width: 24, height: 24),
                          onPressed: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedAspects.remove(aspectKey);
                              } else {
                                _expandedAspects.add(aspectKey);
                              }
                            });
                            onInteraction?.call();
                          },
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
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
                ? AppColors.error.withValues(alpha: 0.08)
                : caution
                    ? AppColors.warning.withValues(alpha: 0.08)
                    : AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: concerning
                  ? AppColors.error.withValues(alpha: 0.25)
                  : caution
                      ? AppColors.warning.withValues(alpha: 0.25)
                      : AppColors.success.withValues(alpha: 0.25),
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
                      ? AppColors.error
                      : caution
                          ? AppColors.warning
                          : AppColors.success,
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
        ? AppColors.error
        : isRecommendation
            ? Colors.blue
            : isAssessment
                ? AppColors.brandAccent
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
        color: isRecommendation
            ? accent.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecommendation
              ? accent.withValues(alpha: 0.35)
              : AppColors.borderPrimary,
          width: isRecommendation ? 1.5 : 1.0,
        ),
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
                    fontSize: isRecommendation ? 14 : 13,
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

  String _cleanBilingualText(String text, String language) {
    final filipinoIndex = text.indexOf('=== FILIPINO ===');
    final englishIndex = text.indexOf('=== ENGLISH ===');

    if (filipinoIndex != -1 && englishIndex != -1) {
      if (filipinoIndex < englishIndex) {
        final filipino = text.substring(filipinoIndex + '=== FILIPINO ==='.length, englishIndex).trim();
        final english = text.substring(englishIndex + '=== ENGLISH ==='.length).trim();
        return language == 'filipino' ? filipino : english;
      } else {
        final english = text.substring(englishIndex + '=== ENGLISH ==='.length, filipinoIndex).trim();
        final filipino = text.substring(filipinoIndex + '=== FILIPINO ==='.length).trim();
        return language == 'filipino' ? filipino : english;
      }
    } else if (filipinoIndex != -1) {
      return text.substring(filipinoIndex + '=== FILIPINO ==='.length).trim();
    } else if (englishIndex != -1) {
      return text.substring(englishIndex + '=== ENGLISH ==='.length).trim();
    }
    return text.trim();
  }

  Widget _buildStructuredInsights(
    String text, {
    VoidCallback? onInteraction,
  }) {
    final cleanedText = _cleanBilingualText(text, _selectedLanguage);
    final sections = _extractInsightSections(cleanedText);
    if (sections.isEmpty) return _buildFormattedText(cleanedText);

    const sectionOrder = [
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
      // Hide relevance check/reason from display (validation logic still runs)
      if (entry.key == 'RELEVANCE CHECK' || entry.key == 'RELEVANCE REASON') {
        continue;
      }

      // Laboratory Results is now handled by the engine-based
      // _buildMonitoringResults() card — skip the AI-parsed text version.
      if (entry.key == 'LABORATORY RESULTS') {
        continue;
      }

      // These details are now merged into expandable rows per aspect.
      if (entry.key == 'ABNORMAL FINDINGS' || entry.key == 'NORMAL RANGES') {
        continue;
      }

      // Hide recommendations from the tab list because we display them
      // prominently directly above the approval checkbox!
      if (entry.key == 'RECOMMENDATIONS') {
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
                  color: AppColors.brandAccent,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library,
                    color: AppColors.brandAccent),
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
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.faintWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandPrimary, width: 3),
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _loadingTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingDetail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      _cancelledRunIds.add(runId);
                      Navigator.of(context).pop();
                      _loadingOverlayVisible = false;
                      _showMessage('AI analysis canceled.',
                          type: AppSnackType.info);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: const BorderSide(
                        color: AppColors.borderPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
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

  // ignore: unused_element
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
            return PopScope(
              canPop: false,
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


  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Lab Test Date'),
        AppInputField(
          hintText: 'Select Lab Test Date',
          controller: _dateController,
          isRequired: true,
          leadingIcon: Icons.calendar_today_outlined,
          readOnly: true,
          onTap: _selectDate,
        ),
        const SizedBox(height: 24),

        // Optional Health Worker details card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderPrimary),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.brandPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI will automatically extract health worker details from your uploaded lab test. You can also optionally specify them below.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.borderPrimary, height: 1),
              const SizedBox(height: 18),

              _sectionLabel('Health Worker Name (Optional)'),
              AppInputField(
                hintText: 'e.g. Dr. Jane Doe',
                controller: _healthWorkerNameController,
                isRequired: false,
                leadingIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              _sectionLabel('Institution / Clinic (Optional)'),
              AppInputField(
                hintText: 'e.g. Health Center or Clinic Name',
                controller: _healthWorkerInstitutionController,
                isRequired: false,
                leadingIcon: Icons.local_hospital_outlined,
              ),
              const SizedBox(height: 16),

              _sectionLabel('Profession (Optional)'),
              AppDropdownField<String>(
                value: _selectedHealthWorkerProfession,
                options: [..._acceptedLabProfessions, _otherProfessionOption],
                displayStringForOption: (val) => val,
                onSelected: (val) {
                  setState(() {
                    _selectedHealthWorkerProfession = val;
                  });
                },
                hintText: 'Select Profession',
                leadingIcon: Icons.work_outline,
              ),
              if (_selectedHealthWorkerProfession == _otherProfessionOption) ...[
                const SizedBox(height: 16),
                _sectionLabel('Specify Profession'),
                AppInputField(
                  hintText: 'e.g. Medical Technologist, Pathologist',
                  controller: _healthWorkerProfessionController,
                  isRequired: true,
                  leadingIcon: Icons.work_outline,
                ),
              ],
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
        _sectionLabel('Attached Images'),
        const SizedBox(height: 8),
        _buildImageBox(),
        const SizedBox(height: 24),
        _sectionLabel('Notes'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Optional context. AI uses this during analysis if provided.',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  String _buildReportText() {
    final buffer = StringBuffer();
    buffer.writeln('=== LAB TEST ANALYSIS REPORT ===');
    buffer.writeln('Date: ${_dateController.text}');
    final aiLabType = _combinedResponse?.extractedLabTestType;
    if (aiLabType != null && aiLabType.isNotEmpty) {
      buffer.writeln('Lab Test Type: $aiLabType');
    }
    buffer.writeln();
    if (_healthWorkerNameController.text.trim().isNotEmpty) {
      buffer.writeln('Health Worker: ${_healthWorkerNameController.text.trim()}');
    }
    if (_healthWorkerInstitutionController.text.trim().isNotEmpty) {
      buffer.writeln('Institution: ${_healthWorkerInstitutionController.text.trim()}');
    }
    final profession = _effectiveSelectedProfession();
    if (profession != null && profession.isNotEmpty && profession != _otherProfessionOption) {
      buffer.writeln('Profession: $profession');
    } else if (_healthWorkerProfessionController.text.trim().isNotEmpty) {
      buffer.writeln('Profession: ${_healthWorkerProfessionController.text.trim()}');
    }
    buffer.writeln();
    buffer.writeln('--- AI ANALYSIS ---');
    buffer.writeln(_healthSummaryController.text.trim());
    buffer.writeln();
    if (_combinedResponse?.recommendations != null &&
        _combinedResponse!.recommendations!.isNotEmpty) {
      buffer.writeln('--- RECOMMENDATIONS ---');
      for (final rec in _combinedResponse!.recommendations!) {
        buffer.writeln('- $rec');
      }
      buffer.writeln();
    }
    buffer.writeln('Generated by InaAgapay AI Analyzer');
    return buffer.toString();
  }

  // ignore: unused_element
  void _copyReportToClipboard() {
    final report = _buildReportText();
    Clipboard.setData(ClipboardData(text: report));
    _showMessage('Report copied to clipboard!', type: AppSnackType.success);
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabTabSwitcher(),
        _buildLabAssessmentCard(),
      ],
    );
  }

  // ── Tab Switcher (matches ultrasound's _buildAssessmentTabSwitcher) ──────

  Widget _buildLabTabSwitcher() {
    if (_combinedResponse == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderPrimary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeLabTab = 'risk';
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _activeLabTab == 'risk'
                      ? AppColors.brandPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: 14,
                      color: _activeLabTab == 'risk'
                          ? Colors.white
                          : AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pregnancy Risk',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _activeLabTab == 'risk'
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _activeLabTab == 'risk'
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeLabTab = 'insight';
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _activeLabTab == 'insight'
                      ? AppColors.brandPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 14,
                      color: _activeLabTab == 'insight'
                          ? Colors.white
                          : AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lab Monitoring Insight',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _activeLabTab == 'insight'
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _activeLabTab == 'insight'
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Assessment Card (matches ultrasound's _buildUltrasoundAssessmentCard) ─

  Color _monitoringChipColor(MonitoringClassification c) {
    switch (c) {
      case MonitoringClassification.withinExpectedRange:
        return AppColors.success;
      case MonitoringClassification.requiresCloserMonitoring:
        return AppColors.warning;
      case MonitoringClassification.followUpRecommended:
        return AppColors.error;
    }
  }

  IconData _monitoringChipIcon(MonitoringClassification c) {
    switch (c) {
      case MonitoringClassification.withinExpectedRange:
        return Icons.check_circle_rounded;
      case MonitoringClassification.requiresCloserMonitoring:
        return Icons.remove_circle_outline_rounded;
      case MonitoringClassification.followUpRecommended:
        return Icons.warning_rounded;
    }
  }

  Widget _buildLabAssessmentCard() {
    // No AI and not skipped → prompt user
    if (_combinedResponse == null && !_aiAnalysisSkipped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: const Column(
          children: [
            Icon(Icons.info_outline,
                color: AppColors.textSecondary, size: 32),
            SizedBox(height: 8),
            Text(
              'No AI analysis available yet.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Go back to Step 2 to run or skip AI analysis.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // AI Skipped → simplified card with risk override only
    if (_combinedResponse == null && _aiAnalysisSkipped) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderPrimary),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.08),
                border: const Border(
                    bottom: BorderSide(color: AppColors.borderPrimary)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.brandPrimary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lab Test Assessment (AI Skipped)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI analysis was skipped. This record will be saved with a plain rule-based monitoring summary.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Pregnancy Risk Override',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppDropdownField<String>(
                          value: _pregnancyRiskLevel,
                          options: const ['low', 'high'],
                          displayStringForOption: (val) =>
                              val == 'low' ? 'Low Risk' : 'High Risk',
                          onSelected: (val) {
                            setState(() {
                              _pregnancyRiskLevel = val;
                              _healthSummaryController.text = _buildRuleBasedLabSummary(); // Re-populate based on selected risk
                            });
                          },
                          hintText: 'Select Pregnancy Risk',
                          leadingIcon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderPrimary, height: 1),
                  const SizedBox(height: 16),

                  // Overall Pregnancy Risk Factors
                  const Text(
                    'Overall Pregnancy Risk Factors',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildRiskFactorsPills(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderPrimary, height: 1),
                  const SizedBox(height: 16),

                  // Clinical Findings (Rule-Based Summary)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Clinical Findings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.borderPrimary.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguage = 'filipino';
                                      _healthSummaryController.text = _buildRuleBasedLabSummary();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedLanguage == 'filipino' ? AppColors.brandPrimary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Tagalog',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: _selectedLanguage == 'filipino' ? FontWeight.w600 : FontWeight.w500,
                                        color: _selectedLanguage == 'filipino' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguage = 'english';
                                      _healthSummaryController.text = _buildRuleBasedLabSummary();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedLanguage == 'english' ? AppColors.brandPrimary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'English',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: _selectedLanguage == 'english' ? FontWeight.w600 : FontWeight.w500,
                                        color: _selectedLanguage == 'english' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_isEditing)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _healthSummaryBeforeEdit =
                                      _healthSummaryController.text;
                                  _isEditing = true;
                                });
                              },
                              icon: const Icon(Icons.edit_outlined,
                                  size: 14, color: AppColors.brandPrimary),
                              label: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_isEditing) ...[
                    _buildStructuredInsights(
                        _healthSummaryController.text),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextField(
                      controller: _healthSummaryController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Edit clinical findings...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.borderPrimary),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(
                          fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _healthSummaryController.text =
                                    _healthSummaryBeforeEdit;
                                _isEditing = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: AppColors.borderPrimary),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            child: const Text('Save Draft'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // AI analysis exists → full assessment card
    final classificationLabel =
        LabCbcInterpretationEngine.classificationLabel(
            _monitoringClassification, language: 'english');
    final chipColor = _monitoringChipColor(_monitoringClassification);
    final chipIcon = _monitoringChipIcon(_monitoringClassification);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              border: const Border(
                  bottom: BorderSide(color: AppColors.borderPrimary)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.brandPrimary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lab Test AI-Assisted Assessment',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(chipIcon, size: 14, color: chipColor),
                      const SizedBox(width: 4),
                      Text(
                        classificationLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sufficiency Warning Callout
                if (_combinedResponse != null) ...[
                  () {
                    final warning = LabCbcInterpretationEngine.getSufficiencyWarning(
                      results: _cbcResults,
                      trimester: _currentTrimester,
                      confidenceScore: _combinedResponse!.confidence,
                    );
                    if (warning == null) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
                ],
                if (_activeLabTab == 'risk') ...[
                  // Pregnancy Risk Override
                  Row(
                    children: [
                      const Text(
                        'Pregnancy Risk Override',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppDropdownField<String>(
                          value: _pregnancyRiskLevel,
                          options: const ['low', 'high'],
                          displayStringForOption: (val) =>
                              val == 'low' ? 'Low Risk' : 'High Risk',
                          onSelected: (val) {
                            setState(() {
                              _pregnancyRiskLevel = val;
                            });
                          },
                          hintText: 'Select Pregnancy Risk',
                          leadingIcon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                      color: AppColors.borderPrimary, height: 1),
                  const SizedBox(height: 16),

                  // Overall Pregnancy Risk Factors
                  const Text(
                    'Overall Pregnancy Risk Factors',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildRiskFactorsPills(),
                  ),
                ] else ...[
                  // Lab Monitoring Insight tab

                  // Clinical Reference Tile
                  _buildLabClinicalReferenceTile(),
                  const SizedBox(height: 16),

                  // Clinical Findings header with Edit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Clinical Findings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.borderPrimary.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguage = 'filipino';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedLanguage == 'filipino' ? AppColors.brandPrimary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Tagalog',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: _selectedLanguage == 'filipino' ? FontWeight.w600 : FontWeight.w500,
                                        color: _selectedLanguage == 'filipino' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguage = 'english';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedLanguage == 'english' ? AppColors.brandPrimary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'English',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: _selectedLanguage == 'english' ? FontWeight.w600 : FontWeight.w500,
                                        color: _selectedLanguage == 'english' ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_isEditing)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _healthSummaryBeforeEdit =
                                      _healthSummaryController.text;
                                  _isEditing = true;
                                });
                              },
                              icon: const Icon(Icons.edit_outlined,
                                  size: 14, color: AppColors.brandPrimary),
                              label: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_isEditing) ...[
                    _buildStructuredInsights(
                        _healthSummaryController.text),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextField(
                      controller: _healthSummaryController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Edit clinical findings...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.borderPrimary),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(
                          fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _healthSummaryController.text =
                                    _healthSummaryBeforeEdit;
                                _isEditing = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: AppColors.borderPrimary),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            child: const Text('Save Draft'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Detailed Lab Monitoring Findings
                  if (_hasDetailedLabData()) ...[
                    _buildMonitoringResults(),
                  ],
                ],

                // AI-Assisted Recommendations (placed prominently above approval checkbox)
                if (_combinedResponse != null && !_aiAnalysisSkipped && _activeLabTab == 'insight') ...[
                  () {
                    final sections = _extractInsightSections(_healthSummaryController.text);
                    final recLines = sections['RECOMMENDATIONS'] ?? _combinedResponse?.recommendations;
                    if (recLines == null || recLines.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildInsightSectionCard('RECOMMENDATIONS', recLines),
                    );
                  }(),
                ],

                // Approval checkbox (outside tabs)
                const SizedBox(height: 16),
                const Divider(
                    color: AppColors.borderPrimary, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _analysisApproved,
                      activeColor: AppColors.brandPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        setState(() {
                          _analysisApproved = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _analysisApproved = !_analysisApproved;
                          });
                        },
                        child: const Text(
                          'I have reviewed and approved this clinical assessment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
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
      ),
    );
  }

  // ── Monitoring Results (replaces _buildDetailedResults with interpretive language) ─

  Widget _buildMotherFriendlyCard({
    required String title,
    required IconData icon,
    required CbcComponentStatus status,
    required String description,
  }) {
    final statusColor = status == CbcComponentStatus.expected
        ? AppColors.success
        : (status == CbcComponentStatus.monitor
            ? AppColors.warning
            : AppColors.error);

    final statusText = _selectedLanguage == 'filipino'
        ? (status == CbcComponentStatus.expected
            ? '✅ Maayos (Normal na Antas)'
            : (status == CbcComponentStatus.monitor
                ? '⚠️ Iminumungkahi ang Pagsubaybay'
                : '🚨 Nangangailangan ng Pagsusuri'))
        : (status == CbcComponentStatus.expected
            ? '✅ Within Expected Monitoring Range'
            : (status == CbcComponentStatus.monitor
                ? '⚠️ Monitoring Recommended'
                : '🚨 Clinical Follow-Up Recommended'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringResults() {
    if (_combinedResponse == null || !_hasDetailedLabData()) {
      return const SizedBox.shrink();
    }

    CbcComponentResult? findResult(String name) {
      for (final res in _cbcResults) {
        if (res.componentName.toLowerCase() == name.toLowerCase()) {
          return res;
        }
      }
      return null;
    }

    CbcComponentStatus getGroupStatus(List<String> names) {
      var finalStatus = CbcComponentStatus.expected;
      for (final name in names) {
        final res = findResult(name);
        if (res != null) {
          if (res.status == CbcComponentStatus.review) {
            return CbcComponentStatus.review;
          } else if (res.status == CbcComponentStatus.monitor) {
            finalStatus = CbcComponentStatus.monitor;
          }
        }
      }
      return finalStatus;
    }

    final oxygenStatus = getGroupStatus(['Hemoglobin', 'Hematocrit', 'MCV']);
    final immuneStatus = getGroupStatus(['WBC']);
    final clottingStatus = getGroupStatus(['Platelets']);

    final overallColor = _monitoringClassification == MonitoringClassification.withinExpectedRange
        ? AppColors.success
        : (_monitoringClassification == MonitoringClassification.requiresCloserMonitoring
            ? AppColors.warning
            : AppColors.error);

    final overallTitle = _selectedLanguage == 'filipino'
        ? 'Pangkalahatang Buod ng Pagsusuri sa Dugo'
        : 'Blood Monitoring Summary';

    final overallBadge = _selectedLanguage == 'filipino'
        ? (_monitoringClassification == MonitoringClassification.withinExpectedRange
            ? '✅ Maayos at Normal na Antas'
            : (_monitoringClassification == MonitoringClassification.requiresCloserMonitoring
                ? '⚠️ Iminumungkahi ang Masusing Pagsubaybay'
                : '🚨 Konsultasyon sa Doktor ay Iminumungkahi'))
        : (_monitoringClassification == MonitoringClassification.withinExpectedRange
            ? '✅ Within Expected Monitoring Range'
            : (_monitoringClassification == MonitoringClassification.requiresCloserMonitoring
                ? '⚠️ Monitoring Recommended'
                : '🚨 Clinical Follow-Up Recommended'));

    final overallDesc = _selectedLanguage == 'filipino'
        ? (_monitoringClassification == MonitoringClassification.withinExpectedRange
            ? 'Ang iyong kabuuang resulta ng pagsusuri sa dugo ay maayos at angkop para sa iyong yugto ng pagbubuntis.'
            : (_monitoringClassification == MonitoringClassification.requiresCloserMonitoring
                ? 'Iminumungkahi ang masusing pagsubaybay sa ilang antas ng iyong dugo kasama ang iyong midwife o doktor.'
                : 'Lubhang iminumungkahi ang agarang konsultasyon sa iyong doktor o midwife upang masuri ang mga antas ng iyong dugo.'))
        : (_monitoringClassification == MonitoringClassification.withinExpectedRange
            ? 'Your overall blood monitoring results generally appear consistent with the expected range for this stage of pregnancy.'
            : (_monitoringClassification == MonitoringClassification.requiresCloserMonitoring
                ? 'A closer monitoring of certain blood levels is recommended in coordination with your midwife or doctor.'
                : 'A prompt follow-up consultation with your doctor or midwife is highly recommended to evaluate your blood levels.'));

    final oxygenDesc = _selectedLanguage == 'filipino'
        ? (oxygenStatus == CbcComponentStatus.expected
            ? 'Ang iyong mga antas na may kinalaman sa pagdadala ng oxygen sa dugo (tulad ng Hemoglobin at Hematocrit) ay maayos at nasa normal na antas para sa iyong yugto ng pagbubuntis.'
            : (oxygenStatus == CbcComponentStatus.monitor
                ? 'May kaunting pagbabago sa iyong mga resulta para sa oxygen support. Ipagpatuloy ang pag-inom ng prenatal vitamins at kumonsulta sa iyong midwife.'
                : 'May mga antas sa oxygen support na nangangailangan ng masusing pagsusuri ng midwife o doktor upang maiwasan ang anemia o matinding pagkapagod.'))
        : (oxygenStatus == CbcComponentStatus.expected
            ? 'Your blood monitoring results related to oxygen support (such as Hemoglobin and Hematocrit) appear generally consistent and within the expected range for this stage of pregnancy.'
            : (oxygenStatus == CbcComponentStatus.monitor
                ? 'Your blood monitoring results related to oxygen support show some slight variations. It is recommended to observe these and correlate them with your midwife.'
                : 'Your oxygen support levels indicate variations that require clinical review by your midwife or doctor to prevent anemia.'));

    final immuneDesc = _selectedLanguage == 'filipino'
        ? (immuneStatus == CbcComponentStatus.expected
            ? 'Ang mga naitalang antas na may kinalaman sa immune response o paglaban sa impeksyon (WBC o White Blood Cells) ay maayos at nagpapakita ng malusog na proteksyon.'
            : (immuneStatus == CbcComponentStatus.monitor
                ? 'May katamtamang pagbabago sa immune monitoring. Ito ay karaniwang reaksyon ng katawan habang nagbubuntis, ngunit iminumungkahi ang patuloy na pagsubaybay.'
                : 'Nangangailangan ng karagdagang pagsusuri ang iyong immune response levels upang masigurong ligtas ka at si baby sa anumang impeksyon.'))
        : (immuneStatus == CbcComponentStatus.expected
            ? 'The recorded blood monitoring values related to immune response and infection monitoring (WBC) appear generally reassuring and expected.'
            : (immuneStatus == CbcComponentStatus.monitor
                ? 'The immune monitoring results show moderate variations. While often normal during pregnancy, continued monitoring is recommended.'
                : 'Your immune response levels indicate a need for further clinical review to ensure safety from any infection.'));

    final clottingDesc = _selectedLanguage == 'filipino'
        ? (clottingStatus == CbcComponentStatus.expected
            ? 'Ang mga naitalang antas na may kinalaman sa pagpigil sa pagdurugo (Platelets) ay maayos, ligtas, at handa para sa iyong panganganak.'
            : (clottingStatus == CbcComponentStatus.monitor
                ? 'May kaunting pagbabago sa platelet count. Subaybayan ito sa tulong ng iyong midwife upang manatiling ligtas at malusog.'
                : 'Ang mga antas para sa pagpigil sa pagdurugo ay nangangailangan ng pagsusuri ng doktor upang masigurong ligtas ang iyong panganganak at maiwasan ang komplikasyon.'))
        : (clottingStatus == CbcComponentStatus.expected
            ? 'The recorded blood monitoring values related to platelet activity and blood clotting support (Platelets) appear stable and within expected ranges.'
            : (clottingStatus == CbcComponentStatus.monitor
                ? 'There are minor variations in your platelet levels. Continued observation with your midwife is recommended.'
                : 'Your blood clotting support levels indicate variations that require professional medical review for a safe delivery.'));

    final highPriorityComponents = {'Hemoglobin', 'Hematocrit', 'WBC', 'Platelets', 'MCV'};
    final highPriorityWidgets = <Widget>[];
    final secondaryWidgets = <Widget>[];

    if (_combinedResponse!.labResults != null &&
        _combinedResponse!.labResults!.isNotEmpty) {
      final interpreted = _combinedResponse!.labResults!
          .map((result) {
            final interpretation =
                LabCbcInterpretationEngine.interpretComponent(
              componentName: result.testName,
              value: double.tryParse(
                      result.value.replaceAll(RegExp(r'[^\d.]'), '')) ??
                  0,
              trimester: _currentTrimester,
              valueStr: result.value,
            );
            if (interpretation == null) return null;
            return MapEntry(result, interpretation);
          })
          .where((e) => e != null)
          .toList();

      for (final e in interpreted) {
        final result = e!.key;
        final interpretation = e.value;

        final statusColor =
            interpretation.status == CbcComponentStatus.expected
                ? AppColors.success
                : (interpretation.status == CbcComponentStatus.monitor
                    ? AppColors.warning
                    : AppColors.error);

        final statusLabel = LabCbcInterpretationEngine.statusLabel(
            interpretation.status);

        final widget = Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.testName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                interpretation.contextPhrase,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );

        if (highPriorityComponents.contains(interpretation.componentName)) {
          highPriorityWidgets.add(widget);
        } else {
          secondaryWidgets.add(widget);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: overallColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: overallColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overallTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: overallColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                overallBadge,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: overallColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                overallDesc,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: AppColors.brandAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              _selectedLanguage == 'filipino' ? 'Gabay sa Pagsusuri' : 'Simple Monitoring Notes',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMotherFriendlyCard(
          title: _selectedLanguage == 'filipino' ? 'Suporta sa Oxygen ng Dugo (Blood Oxygen Support)' : 'Blood Oxygen Support',
          icon: Icons.air_rounded,
          status: oxygenStatus,
          description: oxygenDesc,
        ),
        _buildMotherFriendlyCard(
          title: _selectedLanguage == 'filipino' ? 'Pagsubaybay sa Impeksyon at Imunidad' : 'Infection & Immune Monitoring',
          icon: Icons.shield_outlined,
          status: immuneStatus,
          description: immuneDesc,
        ),
        _buildMotherFriendlyCard(
          title: _selectedLanguage == 'filipino' ? 'Suporta sa Pag-ampat ng Dugo (Blood Clotting Support)' : 'Blood Clotting Support',
          icon: Icons.water_drop_outlined,
          status: clottingStatus,
          description: clottingDesc,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            setState(() {
              _showSecondaryDetails = !_showSecondaryDetails;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderPrimary),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _showSecondaryDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLanguage == 'filipino'
                          ? (_showSecondaryDetails ? 'Itago ang Detalyadong Resulta' : 'Ipakita ang Detalyadong Resulta (Personnel View)')
                          : (_showSecondaryDetails ? 'Hide Detailed Laboratory Values' : 'Detailed Laboratory Values (Healthcare Personnel View)'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandText,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${highPriorityWidgets.length + secondaryWidgets.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSecondaryDetails) ...[
          const SizedBox(height: 16),
          Text(
            _selectedLanguage == 'filipino'
                ? 'Gabay sa Status: REVIEW = kailangan ng masusing pagsusuri, MONITOR = subaybayan, EXPECTED = normal na antas.'
                : 'Status guide: REVIEW = needs clinical review, MONITOR = observe and correlate, EXPECTED = within commonly expected range.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          ...highPriorityWidgets,
          if (secondaryWidgets.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderPrimary, height: 1),
            const SizedBox(height: 16),
            const Text(
              'Secondary CBC Indices',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...secondaryWidgets,
          ],
        const SizedBox(height: 16),
        () {
          final cleanAbnormalFindings = (_combinedResponse!.abnormalFindings ?? []).where((finding) {
            final lower = finding.toLowerCase();
            for (final res in _cbcResults) {
              final name = res.componentName.toLowerCase();
              if (lower.contains(name) || (name == 'hemoglobin' && (lower.contains('hb') || lower.contains('hgb')))) {
                if (res.status == CbcComponentStatus.expected) {
                  return false;
                }
              }
            }
            return true;
          }).toList();

          if (cleanAbnormalFindings.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FLAGGED FINDINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...cleanAbnormalFindings.map((finding) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.warning, size: 16),
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
              const SizedBox(height: 8),
            ],
          );
        }(),
        // AI disclaimer banner
        Container(
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
                  'This monitoring context is generated for reference purposes only using WHO and pregnancy-adjusted laboratory standards. It does not constitute a medical diagnosis. Always consult with a qualified healthcare provider.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ],
    );
  }

  // ── Clinical Reference Tile (matches ultrasound's _buildClinicalReferenceTile) ─

  Widget _buildLabClinicalReferenceTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderPrimary.withValues(alpha: 0.4),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(
            Icons.menu_book_outlined,
            size: 15,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          title: Text(
            'Clinical Reference Basis',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          iconColor: AppColors.textSecondary.withValues(alpha: 0.5),
          collapsedIconColor:
              AppColors.textSecondary.withValues(alpha: 0.4),
          children: [
            _buildLabCitationRow(
              authors: LabCbcInterpretationEngine.citation1Authors,
              full: LabCbcInterpretationEngine.citation1Full,
              url: LabCbcInterpretationEngine.citation1Url,
            ),
            const SizedBox(height: 8),
            _buildLabCitationRow(
              authors: LabCbcInterpretationEngine.citation2Authors,
              full: LabCbcInterpretationEngine.citation2Full,
              url: LabCbcInterpretationEngine.citation2Url,
            ),
            const SizedBox(height: 8),
            Text(
              'For health monitoring support only. Does not replace professional medical consultation.',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabCitationRow({
    required String authors,
    required String full,
    required String url,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$authors $full',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          url,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.brandPrimary.withValues(alpha: 0.6),
            decoration: TextDecoration.underline,
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
        bottom: false,
        child: Column(
          children: [
            SecondaryHeader(
              title: 'Lab Test Analysis',
              onBack: _confirmDiscardAndPop,
              trailing: _selectedImages.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.delete_sweep, color: AppColors.error),
                      onPressed: _clearAll,
                      tooltip: 'Clear all images',
                    )
                  : null,
            ),
            LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              backgroundColor: AppColors.borderPrimary,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
              minHeight: 3,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Text(
                    _stepTitles[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepSubtitles[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
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
                            child: Text(
                              _motherName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            ? 'Complete lab test details first, then continue.'
                            : (_step == 1
                                ? 'Attach images and notes, then run AI analysis.'
                                : 'Review the AI-assisted assessment findings.'),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _step == 0
                        ? _buildStep1()
                        : (_step == 1 ? _buildStep2() : _buildStep3()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Builder(
              builder: (context) {
                if (_step == 1) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: MainButton(
                          label: 'Back',
                          leftIcon: Icons.arrow_back_ios_new_rounded,
                          isWhiteVariant: true,
                          fontSize: 13,
                          onPressed: _isSaving ? null : _prevStep,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: MainButton(
                          label: 'Skip AI Analysis',
                          isWhiteVariant: true,
                          fontSize: 13,
                          onPressed: _isSaving ? null : () {
                            setState(() {
                              _aiAnalysisSkipped = true;
                              _combinedResponse = null; // Clear old AI results!
                              _cbcResults.clear();      // Clear cbc component list!
                              _healthSummaryController.text = _buildRuleBasedLabSummary(); // Plain rule-based summary!
                              _analysisApproved = false; // Reset approval!
                              _step = 2; // Move to Step 3: Assessment & Clinical Review
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: MainButton(
                          label: 'Run AI Analysis',
                          rightIcon: Icons.auto_awesome,
                          fontSize: 13,
                          onPressed: _isSaving ? null : _analyzeImages,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: MainButton(
                          label: 'Back',
                          leftIcon: Icons.arrow_back_ios_new_rounded,
                          isWhiteVariant: true,
                          onPressed: _isSaving ? null : _prevStep,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildRightButton(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightButton() {
    if (_step == 0) {
      return MainButton(
        label: 'Next',
        rightIcon: Icons.arrow_forward_ios_rounded,
        onPressed: _isSaving ? null : _nextStep,
      );
    } else {
      return MainButton(
        label: _isSaving ? 'Saving...' : 'Save to Records',
        rightIcon: _isSaving ? null : Icons.check_rounded,
        onPressed: _isSaving ? null : _saveToDatabase,
      );
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(2))),
            Text(text.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.3)),
          ],
        ),
      );

}

// ignore: unused_element
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
