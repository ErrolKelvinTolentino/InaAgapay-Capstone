import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/ocr_result.dart';
import '../services/auth_storage.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/progressive_step_indicator.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Enums & Data Models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _GestationMethod { lmp, edd, aog }

enum _OcrDialogState { loading, results, error }

class _EmergencyContact {
  String firstName = '';
  String? middleName;
  String lastName = '';
  String? extensionName;
  String phoneNumber = '';
  String? affiliation;

  bool get isValid =>
      firstName.isNotEmpty && lastName.isNotEmpty && phoneNumber.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'extension_name': extensionName,
        'phone_number': phoneNumber,
        'affiliation': affiliation,
      };
}

class _MedicalCondition {
  final String conditionName;
  DateTime? diagnosisDate;
  String status = 'active';
  String? remarks;

  _MedicalCondition(this.conditionName);

  Map<String, dynamic> toMap() => {
        'condition_name': conditionName,
        'diagnosis_date': diagnosisDate?.toIso8601String().split('T')[0],
        'status': status,
        'remarks': remarks,
      };
}

class _Allergy {
  final String allergen;
  DateTime? diagnosisDate;
  String status = 'active';
  String? treatment;
  String? remarks;

  _Allergy(this.allergen);

  Map<String, dynamic> toMap() => {
        'allergen': allergen,
        'diagnosis_date': diagnosisDate?.toIso8601String().split('T')[0],
        'status': status,
        'treatment': treatment,
        'remarks': remarks,
      };
}

class _PastPregnancy {
  String outcome;
  DateTime outcomeDate;
  bool isEstimated = false;
  double? gestationalAgeAtEnd;
  String? placeOfDelivery;
  String? deliveryMethod;

  _PastPregnancy({required this.outcome, required this.outcomeDate});

  Map<String, dynamic> toMap() => {
        'outcome': outcome,
        'outcome_date': outcomeDate.toIso8601String().split('T')[0],
        'is_outcome_date_estimated': isEstimated,
        'gestational_age_at_end': gestationalAgeAtEnd,
        'place_of_delivery': placeOfDelivery,
        'delivery_method': deliveryMethod,
      };
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class MidwifeAddMotherScreen extends StatefulWidget {
  const MidwifeAddMotherScreen({super.key});

  @override
  State<MidwifeAddMotherScreen> createState() => _MidwifeAddMotherScreenState();
}

class _MidwifeAddMotherScreenState extends State<MidwifeAddMotherScreen> {
  // â”€â”€ Context â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int? _midwifeId;
  int? _assignedBhcId;
  String _bhcName = '';
  bool _loadingContext = true;

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int _step = 0;
  static const int _totalSteps = 9;
  bool _submitting = false;
  final _pageController = PageController();

  // â”€â”€ Formatters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _dateFmt = DateFormat('MMMM d, yyyy');

  // â”€â”€ Step 0 : Personal & Account â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  final _passwordFocus = FocusNode();
  String? _phoneError, _emailError;
  bool _emailChecking = false, _emailExists = false;
  Timer? _emailTimer;
  String? _lastEmailChecked;

  // â”€â”€ Step 1 : Address â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _addressSameAsBhc = true;
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  String? _selectedBarangay;
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();

  static const _bhcBarangays = [
    'San Jose',
    'Tarcan',
    'Sta. Barbara',
    'Tiaong',
    'Pinagbarilan',
  ];

  // â”€â”€ Step 2 : Emergency Contacts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<_EmergencyContact> _emergencyContacts = [];

  // â”€â”€ Step 3 : Vital Statistics â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  DateTime? _birthdate;
  final _birthdateCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodType;

  // â”€â”€ Step 4 : Medical Conditions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<_MedicalCondition> _medicalConditions = [];

  // â”€â”€ Step 5 : Allergies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<_Allergy> _allergies = [];

  // â”€â”€ Step 6 : Pregnancy History â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _hasPastPregnancy = false;
  final List<_PastPregnancy> _pastPregnancies = [];

  // â”€â”€ Step 7 : Gestational Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  _GestationMethod _gestationMethod = _GestationMethod.lmp;
  final _lmpCtrl = TextEditingController();
  final _eddCtrl = TextEditingController();
  final _aogWeeksCtrl = TextEditingController();
  final _aogDaysCtrl = TextEditingController();
  DateTime? _lmp;
  DateTime? _edd;
  // -- OCR -----------------------------------------------------------------------
  final _geminiService = GeminiService();

  // â”€â”€ Lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() => setState(() {}));
    _loadContext();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailTimer?.cancel();
    _passwordFocus.dispose();
    for (final c in [
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _extNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passwordCtrl,
      _houseCtrl,
      _streetCtrl,
      _barangayCtrl,
      _cityCtrl,
      _provinceCtrl,
      _birthdateCtrl,
      _heightCtrl,
      _weightCtrl,
      _lmpCtrl,
      _eddCtrl,
      _aogWeeksCtrl,
      _aogDaysCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // â”€â”€ Context â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // ── OCR methods ──────────────────────────────────────────────────────────────

  // ── OCR flow ──────────────────────────────────────────────────────────────────

  /// Entry point – shown when the user taps the OCR button in the AppBar.
  Future<void> _startOcrFlow() async {
    // Step 1: choose camera vs gallery
    final source = await _showOcrSourcePicker();
    if (source == null || !mounted) return;

    // Step 2: pick the image
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    // Step 3: upload + review dialog
    await _showOcrProcessDialog(file);
  }

  /// Bottom sheet that returns the chosen [ImageSource] (or null if dismissed).
  Future<ImageSource?> _showOcrSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan Document',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose an image source to extract patient data',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AFF68A5),
                child: Icon(Icons.camera_alt_outlined,
                    color: AppColors.brandPrimary),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo of the document'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AFF68A5),
                child: Icon(Icons.photo_library_outlined,
                    color: AppColors.brandPrimary),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Choose an existing photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Full upload→review dialog.
  /// Starts OCR immediately while the dialog is visible.
  Future<void> _showOcrProcessDialog(XFile imageFile) async {
    var dialogState = _OcrDialogState.loading;
    OcrResult? ocrResult;
    String? ocrError;
    StateSetter? dialogSetState;

    void startOcr() {
      _geminiService.extractMotherRegistrationData(imageFile).then((r) {
        dialogSetState?.call(() {
          if (!r.hasAnyValue) {
            ocrError = 'No recognisable patient data found in the image.\n'
                'Try a clearer or higher-quality photo.';
            dialogState = _OcrDialogState.error;
          } else {
            ocrResult = r;
            dialogState = _OcrDialogState.results;
          }
        });
      }).catchError((dynamic e) {
        dialogSetState?.call(() {
          ocrError = e.toString().replaceFirst('Exception: ', '');
          dialogState = _OcrDialogState.error;
        });
      });
    }

    startOcr();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          dialogSetState = setS;
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brandPrimary, Color(0xFFE91E8C)],
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (dialogState) {
                          _OcrDialogState.loading =>
                            Icons.cloud_upload_outlined,
                          _OcrDialogState.results =>
                            Icons.check_circle_outline_rounded,
                          _OcrDialogState.error => Icons.error_outline_rounded,
                        },
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              switch (dialogState) {
                                _OcrDialogState.loading =>
                                  'Scanning Document...',
                                _OcrDialogState.results => 'Data Extracted',
                                _OcrDialogState.error => 'Scan Failed',
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              switch (dialogState) {
                                _OcrDialogState.loading =>
                                  'Uploading and analysing with Gemini...',
                                _OcrDialogState.results =>
                                  'Review the extracted fields below',
                                _OcrDialogState.error =>
                                  'An error occurred during scanning',
                              },
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (dialogState != _OcrDialogState.loading)
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                    ],
                  ),
                ),
                // ── Body ───────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: switch (dialogState) {
                      _OcrDialogState.loading => _ocrLoadingBody(imageFile),
                      _OcrDialogState.results => _buildOcrFieldList(ocrResult!),
                      _OcrDialogState.error => _ocrErrorBody(ocrError!),
                    },
                  ),
                ),
                // ── Footer ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: AppColors.borderPrimary)),
                  ),
                  child: switch (dialogState) {
                    _OcrDialogState.loading => const SizedBox.shrink(),
                    _OcrDialogState.results => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                    color: AppColors.borderPrimary),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Apply to Form'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    _OcrDialogState.error => Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                    color: AppColors.borderPrimary),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setS(() {
                                  dialogState = _OcrDialogState.loading;
                                  ocrError = null;
                                });
                                startOcr();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true && mounted && ocrResult != null) {
      _applyOcrResult(ocrResult!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Form autofilled from OCR scan. Please review & edit as needed.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  Widget _ocrLoadingBody(XFile imageFile) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: imageFile.readAsBytes(),
              builder: (ctx, snap) {
                if (snap.hasData) {
                  return Image.memory(
                    snap.data!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  height: 180,
                  color: AppColors.bgSecondary,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandPrimary),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: AppColors.brandPrimary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Analysing with Gemini AI...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Extracting patient data from the image',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _ocrStep(number: 1, label: 'Image uploaded', done: true),
          _ocrStep(
              number: 2, label: 'Gemini reading document...', loading: true),
          _ocrStep(number: 3, label: 'Populating form fields'),
        ],
      );

  Widget _ocrStep({
    required int number,
    required String label,
    bool done = false,
    bool loading = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: done
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 20)
                  : loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brandPrimary),
                        )
                      : CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.borderPrimary,
                          child: Text(
                            '$number',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: (done || loading)
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: loading ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  Widget _ocrErrorBody(String message) => Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 52),
          const SizedBox(height: 12),
          const Text(
            'Scan Failed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tips for better results:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          _ocrTip('Ensure the document is well lit'),
          _ocrTip('Keep the camera steady and in focus'),
          _ocrTip('Make sure all text is visible and unobstructed'),
        ],
      );

  Widget _ocrTip(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 14, color: AppColors.brandAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _buildOcrFieldList(OcrResult r) {
    final rows = <Widget>[];

    void section(String title) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(_ocrSectionHeader(title));
    }

    void field(String label, String? value) {
      if (value == null) return;
      rows.add(_ocrFieldRow(label, value));
    }

    section('Personal Information');
    field('First Name', r.firstName);
    field('Middle Name', r.middleName);
    field('Last Name', r.lastName);
    field('Extension', r.extensionName);
    field('Phone', r.phone);
    field('Email', r.email);

    section('Address');
    field('House No.', r.houseNumber);
    field('Street', r.street);
    field('Barangay', r.barangay);
    field('City', r.city);
    field('Province', r.province);

    section('Vital Statistics');
    field('Birthdate', r.birthdate);
    field('Height', r.heightCm != null ? '${r.heightCm} cm' : null);
    field('Weight', r.weightKg != null ? '${r.weightKg} kg' : null);
    field('Blood Type', r.bloodType);

    section('Gestational Info');
    field('LMP', r.lmpDate);
    field('EDD', r.eddDate);

    if (r.emergencyContacts.isNotEmpty) {
      section('Emergency Contacts (${r.emergencyContacts.length})');
      for (final c in r.emergencyContacts) {
        rows.add(_ocrFieldRow(
          '${c.firstName} ${c.lastName}',
          '${c.phoneNumber}${c.affiliation != null ? ' · ${c.affiliation}' : ''}',
        ));
      }
    }

    if (r.medicalConditions.isNotEmpty) {
      section('Medical Conditions (${r.medicalConditions.length})');
      for (final m in r.medicalConditions) {
        rows.add(_ocrFieldRow(
          m.conditionName,
          '${m.status}${m.diagnosisDate != null ? ' · ${m.diagnosisDate}' : ''}',
        ));
      }
    }

    if (r.allergies.isNotEmpty) {
      section('Allergies (${r.allergies.length})');
      for (final a in r.allergies) {
        rows.add(_ocrFieldRow(
          a.allergen,
          '${a.status}${a.treatment != null ? ' · ${a.treatment}' : ''}',
        ));
      }
    }

    if (r.pastPregnancies.isNotEmpty) {
      section('Past Pregnancies (${r.pastPregnancies.length})');
      for (final p in r.pastPregnancies) {
        rows.add(_ocrFieldRow(
          _outcomeLabel(p.outcome),
          '${p.outcomeDate}${p.placeOfDelivery != null ? ' · ${p.placeOfDelivery}' : ''}',
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _ocrSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );

  Widget _ocrFieldRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 15, color: Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  void _applyOcrResult(OcrResult r) {
    setState(() {
      // Step 0 — Personal
      if (r.firstName != null) _firstNameCtrl.text = r.firstName!;
      if (r.middleName != null) _middleNameCtrl.text = r.middleName!;
      if (r.lastName != null) _lastNameCtrl.text = r.lastName!;
      if (r.extensionName != null) _extNameCtrl.text = r.extensionName!;
      if (r.phone != null) {
        _phoneCtrl.text = r.phone!;
        _onPhoneChanged(r.phone!);
      }
      if (r.email != null) {
        _emailCtrl.text = r.email!;
        _onEmailChanged(r.email!);
      }

      // Step 1 — Address
      if (r.houseNumber != null) _houseCtrl.text = r.houseNumber!;
      if (r.street != null) _streetCtrl.text = r.street!;
      if (r.barangay != null) {
        final match = _bhcBarangays
            .where((b) =>
                b.toLowerCase().contains(r.barangay!.toLowerCase()) ||
                r.barangay!.toLowerCase().contains(b.toLowerCase()))
            .firstOrNull;
        if (match != null) {
          _selectedBarangay = match;
          _barangayCtrl.text = match;
          _addressSameAsBhc = false;
        } else {
          _addressSameAsBhc = false;
          _selectedBarangay = null;
          _barangayCtrl.text = r.barangay!;
        }
      }
      if (r.city != null) {
        _cityCtrl.text = r.city!;
        _addressSameAsBhc = false;
      }
      if (r.province != null) {
        _provinceCtrl.text = r.province!;
        _addressSameAsBhc = false;
      }

      // Step 3 — Vitals
      if (r.birthdate != null) {
        final parsed = DateTime.tryParse(r.birthdate!);
        if (parsed != null) {
          _birthdate = parsed;
          _birthdateCtrl.text = _dateFmt.format(parsed);
        }
      }
      if (r.heightCm != null) {
        _heightCtrl.text = r.heightCm!.toStringAsFixed(1);
      }
      if (r.weightKg != null) {
        _weightCtrl.text = r.weightKg!.toStringAsFixed(1);
      }
      if (r.bloodType != null) _bloodType = r.bloodType;

      // Step 4 — Medical Conditions
      for (final m in r.medicalConditions) {
        if (m.conditionName.isEmpty) continue;
        final mc = _MedicalCondition(m.conditionName)
          ..status = m.status
          ..remarks = m.remarks;
        if (m.diagnosisDate != null) {
          mc.diagnosisDate = DateTime.tryParse(m.diagnosisDate!);
        }
        _medicalConditions.add(mc);
      }

      // Step 5 — Allergies
      for (final a in r.allergies) {
        if (a.allergen.isEmpty) continue;
        final al = _Allergy(a.allergen)
          ..status = a.status
          ..treatment = a.treatment
          ..remarks = a.remarks;
        if (a.diagnosisDate != null) {
          al.diagnosisDate = DateTime.tryParse(a.diagnosisDate!);
        }
        _allergies.add(al);
      }

      // Step 2 — Emergency Contacts
      for (final ec in r.emergencyContacts) {
        if (ec.firstName.isEmpty ||
            ec.lastName.isEmpty ||
            ec.phoneNumber.isEmpty) {
          continue;
        }
        _emergencyContacts.add(
          _EmergencyContact()
            ..firstName = ec.firstName
            ..middleName = ec.middleName
            ..lastName = ec.lastName
            ..extensionName = ec.extensionName
            ..phoneNumber = ec.phoneNumber
            ..affiliation = ec.affiliation,
        );
      }

      // Step 6 — Pregnancy History
      for (final p in r.pastPregnancies) {
        if (p.outcomeDate.isEmpty) continue;
        final date = DateTime.tryParse(p.outcomeDate);
        if (date == null) continue;
        _pastPregnancies.add(
          _PastPregnancy(outcome: p.outcome, outcomeDate: date)
            ..isEstimated = p.isEstimated
            ..gestationalAgeAtEnd = p.gestationalAgeAtEnd
            ..placeOfDelivery = p.placeOfDelivery
            ..deliveryMethod = p.deliveryMethod,
        );
      }
      if (_pastPregnancies.isNotEmpty) _hasPastPregnancy = true;

      // Step 7 — Gestational Info
      if (r.lmpDate != null) {
        final lmp = DateTime.tryParse(r.lmpDate!);
        if (lmp != null) _updateFromLmp(lmp);
      } else if (r.eddDate != null) {
        final edd = DateTime.tryParse(r.eddDate!);
        if (edd != null) _updateFromEdd(edd);
      }
    });
  }

  Future<void> _loadContext() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null) throw Exception('Not authenticated');
      final result = await SupabaseService.getMidwifeContext(accountId);
      if (result['success'] == true) {
        _midwifeId = result['midwife_id'] as int;
        _assignedBhcId = result['assigned_bhc_id'] as int;
        _bhcName = result['bhc_name'] as String;
        _applyBhcAddress();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load context: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
  }

  // â”€â”€ Email â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onEmailChanged(String v) {
    final value = v.trim();
    if (value.isEmpty) {
      _emailTimer?.cancel();
      setState(() {
        _emailChecking = false;
        _emailExists = false;
        _emailError = null;
      });
      return;
    }
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    setState(() => _emailError = valid ? null : 'Enter a valid email');
    if (!valid) {
      _emailTimer?.cancel();
      _emailChecking = false;
      _emailExists = false;
      return;
    }
    _emailTimer?.cancel();
    setState(() => _emailChecking = true);
    _emailTimer = Timer(
      const Duration(milliseconds: 600),
      () => _checkEmail(value),
    );
  }

  Future<void> _checkEmail(String email) async {
    _lastEmailChecked = email;
    final available = await SupabaseService.isEmailAvailable(email);
    if (_lastEmailChecked != email || !mounted) return;
    setState(() {
      _emailChecking = false;
      _emailExists = !available;
      _emailError = available ? null : 'Email already in use';
    });
  }

  // â”€â”€ Phone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onPhoneChanged(String v) {
    final normalized = v.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final valid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(
      () => _phoneError =
          v.trim().isEmpty ? null : (valid ? null : 'Enter a valid PH number'),
    );
  }

  // â”€â”€ Password â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final rng = Random.secure();
    final pw =
        List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
    setState(() {
      _passwordCtrl.text = pw;
      _obscurePassword = false;
    });
  }

  // â”€â”€ Address â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _applyBhcAddress() {
    _selectedBarangay = _bhcName;
    _barangayCtrl.text = _bhcName;
    _cityCtrl.text = 'Baliwag';
    _provinceCtrl.text = 'Bulacan';
  }

  // â”€â”€ Gestation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _updateFromLmp(DateTime lmp) {
    _lmp = lmp;
    _edd = lmp.add(const Duration(days: 280));
    _lmpCtrl.text = _dateFmt.format(lmp);
    _eddCtrl.text = _dateFmt.format(_edd!);
  }

  void _updateFromEdd(DateTime edd) {
    _edd = edd;
    _lmp = edd.subtract(const Duration(days: 280));
    _eddCtrl.text = _dateFmt.format(edd);
    _lmpCtrl.text = _dateFmt.format(_lmp!);
  }

  void _updateFromAog() {
    final w = int.tryParse(_aogWeeksCtrl.text.trim()) ?? 0;
    final d = int.tryParse(_aogDaysCtrl.text.trim()) ?? 0;
    if (w <= 0 && d <= 0) return;
    final lmp = DateTime.now().subtract(Duration(days: w * 7 + d));
    _updateFromLmp(lmp);
  }

  String _formatAog() {
    if (_lmp == null) return '-';
    final days = DateTime.now().difference(_lmp!).inDays;
    if (days < 0) return '-';
    return '${days ~/ 7}w ${days % 7}d';
  }

  // ── Pregnancy‐history helpers ──────────────────────────────────────────────

  /// Returns GA constraint (min weeks, max weeks, hint) for [outcome].
  ({int min, int max, String hint})? _outcomeGaConstraint(String outcome) =>
      switch (outcome) {
        'live_birth' => (
            min: 22,
            max: 45,
            hint: 'Valid: 22–45 weeks (typically 37–42 weeks)',
          ),
        'stillbirth' => (
            min: 20,
            max: 45,
            hint: 'Fetal death at 20+ weeks gestation',
          ),
        'miscarriage' => (
            min: 4,
            max: 19,
            hint: 'Pregnancy loss before 20 weeks',
          ),
        'abortion' => (
            min: 4,
            max: 23,
            hint: 'Typically performed before 24 weeks',
          ),
        'ectopic' => (
            min: 4,
            max: 15,
            hint: 'Ectopic pregnancies typically resolve before 16 weeks',
          ),
        _ => null,
      };

  /// Returns an error message if [weeks] is outside the valid range for
  /// [outcome], or null if valid.
  String? _gaConstraintErrorFor(String outcome, int weeks) {
    final c = _outcomeGaConstraint(outcome);
    if (c == null) return null;
    if (weeks < c.min) {
      return switch (outcome) {
        'live_birth' =>
          'A live birth at $weeks weeks is not viable (minimum: ${c.min} weeks)',
        'stillbirth' =>
          'Stillbirth is defined at 20+ weeks. Use Miscarriage for earlier loss.',
        _ =>
          'Gestational age cannot be less than ${c.min} weeks for this outcome',
      };
    }
    if (weeks > c.max) {
      return switch (outcome) {
        'miscarriage' =>
          'At $weeks weeks this is classified as Stillbirth, not Miscarriage',
        'abortion' =>
          'Gestational age ($weeks w) exceeds expected max for abortion (23 weeks)',
        'ectopic' => 'Ectopic pregnancies cannot survive beyond 16 weeks',
        _ =>
          'Gestational age ($weeks w) exceeds expected maximum for this outcome',
      };
    }
    return null;
  }

  /// Returns an error message if [date] is within 42 days of any existing
  /// past pregnancy outcome date. [excludeIndex] skips that entry (edit mode).
  String? _computeIntervalError(DateTime date, {int? excludeIndex}) {
    const minGapDays = 42;
    for (int i = 0; i < _pastPregnancies.length; i++) {
      if (i == excludeIndex) continue;
      final gap = date.difference(_pastPregnancies[i].outcomeDate).inDays.abs();
      if (gap < minGapDays) {
        return 'Only ${gap}d from another record (min: $minGapDays days / ~6 weeks)';
      }
    }
    return null;
  }

  // â”€â”€ Validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  bool _validateStep(int step) {
    String? msg;
    switch (step) {
      case 0:
        final issues = <String>[];
        if (_firstNameCtrl.text.trim().isEmpty) issues.add('First Name');
        if (_lastNameCtrl.text.trim().isEmpty) issues.add('Last Name');
        if (_phoneCtrl.text.trim().isEmpty) {
          issues.add('Phone Number');
        } else if (_phoneError != null) {
          issues.add('Phone (invalid)');
        }
        if (_emailCtrl.text.trim().isEmpty) {
          issues.add('Email Address');
        } else if (_emailChecking) {
          issues.add('Email (still checking)');
        } else if (_emailExists) {
          issues.add('Email (already in use)');
        } else if (_emailError != null) {
          issues.add('Email (invalid)');
        }
        if (_passwordCtrl.text.isEmpty) {
          issues.add('Password');
        } else if (_passwordCtrl.text.length < 8) {
          issues.add('Password (min 8 chars)');
        }
        if (issues.isNotEmpty) msg = 'Please fix: ${issues.join(', ')}.';
        break;

      case 1:
        if (!_addressSameAsBhc) {
          if ((_selectedBarangay ?? '').isEmpty ||
              _cityCtrl.text.trim().isEmpty ||
              _provinceCtrl.text.trim().isEmpty) {
            msg = 'Barangay, city, and province are required.';
          }
        }
        break;

      case 3:
        final issues = <String>[];
        if (_birthdate == null) {
          issues.add('Birthdate');
        } else {
          final age =
              (DateTime.now().difference(_birthdate!).inDays / 365.25).floor();
          if (age < 10 || age > 50) {
            issues.add(
                'Maternal age ($age yrs) is outside the possible range for pregnancy (10–50 yrs)');
          }
        }
        if (double.tryParse(_heightCtrl.text.trim()) == null) {
          issues.add('Height (cm)');
        } else {
          final h = double.parse(_heightCtrl.text.trim());
          if (h < 100 || h > 220) {
            issues.add(
                'Height must be between 100–220 cm (entered: ${h.toStringAsFixed(0)} cm)');
          }
        }
        if (double.tryParse(_weightCtrl.text.trim()) == null) {
          issues.add('Weight (kg)');
        } else {
          final w = double.parse(_weightCtrl.text.trim());
          if (w < 30 || w > 200) {
            issues.add(
                'Weight must be between 30–200 kg (entered: ${w.toStringAsFixed(0)} kg)');
          }
        }
        if (issues.isNotEmpty) msg = 'Please fix: ${issues.join('; ')}.';
        break;

      case 6:
        if (_hasPastPregnancy && _pastPregnancies.isEmpty) {
          msg = 'Add at least one past pregnancy or disable the toggle.';
        } else {
          // Check delivery info for live births & stillbirths
          for (final p in _pastPregnancies) {
            if ((p.outcome == 'live_birth' || p.outcome == 'stillbirth') &&
                (p.placeOfDelivery == null || p.deliveryMethod == null)) {
              msg =
                  'Provide delivery place & method for live birth / stillbirth records.';
              break;
            }
          }
          // Check GA constraints per outcome type
          if (msg == null) {
            for (final p in _pastPregnancies) {
              if (p.gestationalAgeAtEnd != null) {
                final gaErr = _gaConstraintErrorFor(
                    p.outcome, p.gestationalAgeAtEnd!.toInt());
                if (gaErr != null) {
                  msg = '${_outcomeLabel(p.outcome)}: $gaErr';
                  break;
                }
              }
            }
          }
          // Check minimum interval between consecutive past pregnancies
          if (msg == null && _pastPregnancies.length > 1) {
            final sorted = [..._pastPregnancies]
              ..sort((a, b) => a.outcomeDate.compareTo(b.outcomeDate));
            for (int i = 0; i < sorted.length - 1; i++) {
              final gap = sorted[i + 1]
                  .outcomeDate
                  .difference(sorted[i].outcomeDate)
                  .inDays;
              if (gap < 42) {
                msg =
                    'Two records are only ${gap}d apart (${_outcomeLabel(sorted[i].outcome)} → ${_outcomeLabel(sorted[i + 1].outcome)}). Minimum interval is 42 days. Please verify the dates.';
                break;
              }
            }
          }
        }
        break;

      case 7:
        if (_gestationMethod == _GestationMethod.lmp && _lmp == null) {
          msg = 'Select an LMP date.';
        } else if (_gestationMethod == _GestationMethod.edd && _edd == null) {
          msg = 'Select an EDD date.';
        } else if (_gestationMethod == _GestationMethod.aog &&
            _aogWeeksCtrl.text.trim().isEmpty &&
            _aogDaysCtrl.text.trim().isEmpty) {
          msg = 'Enter gestation in weeks or days.';
        } else if (_lmp == null || _edd == null) {
          msg = 'Unable to compute LMP and EDD. Please re-enter.';
        } else {
          // GA > 42 weeks is biologically impossible
          final gaWeeks = DateTime.now().difference(_lmp!).inDays ~/ 7;
          if (gaWeeks > 42) {
            msg =
                'Gestational age ($gaWeeks weeks) exceeds 42 weeks — biologically impossible. Please verify the LMP date.';
          }
          // Pregnancy interval check against the most recent past pregnancy
          if (msg == null && _pastPregnancies.isNotEmpty) {
            final sorted = [..._pastPregnancies]
              ..sort((a, b) => b.outcomeDate.compareTo(a.outcomeDate));
            final last = sorted.first;
            final interval = _lmp!.difference(last.outcomeDate).inDays;
            // Impossible thresholds per outcome (anything below = biologically impossible)
            const impossibleThresholds = {
              'live_birth': 1,
              'stillbirth': 30,
              'miscarriage': 30,
              'abortion': 20,
              'ectopic': 20,
            };
            final threshold = impossibleThresholds[last.outcome] ?? 30;
            if (interval < 0) {
              msg =
                  'LMP date is before the last recorded past pregnancy end date. Please verify your dates.';
            } else if (interval < threshold) {
              msg =
                  'Pregnancy interval of $interval days after the last ${_outcomeLabel(last.outcome)} is biologically impossible (minimum: $threshold days).';
            }
          }
        }
        break;

      case 8:
        if (_midwifeId == null || _assignedBhcId == null) {
          msg = 'Midwife context is missing. Please go back and retry.';
        }
        break;
    }

    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _goNext() {
    if (!_validateStep(_step)) return;
    if (_step < _totalSteps - 1) {
      _pageController.animateToPage(
        _step + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    }
  }

  void _goBack() {
    if (_step > 0) {
      _pageController.animateToPage(
        _step - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  // â”€â”€ Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _submit() async {
    if (!_validateStep(8)) return;
    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.addMotherFullByMidwife(
        midwifeId: _midwifeId!,
        assignedBhcId: _assignedBhcId!,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        extensionName:
            _extNameCtrl.text.trim().isEmpty ? null : _extNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        houseNumber:
            _houseCtrl.text.trim().isEmpty ? null : _houseCtrl.text.trim(),
        street:
            _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
        barangay: _selectedBarangay,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        province: _provinceCtrl.text.trim().isEmpty
            ? null
            : _provinceCtrl.text.trim(),
        birthdate: _birthdate,
        heightCm: double.tryParse(_heightCtrl.text.trim()),
        weightKg: double.tryParse(_weightCtrl.text.trim()),
        bloodType: _bloodType,
        lmp: _lmp,
        edd: _edd,
        emergencyContacts: _emergencyContacts.map((e) => e.toMap()).toList(),
        medicalConditions: _medicalConditions.map((m) => m.toMap()).toList(),
        allergies: _allergies.map((a) => a.toMap()).toList(),
        pastPregnancies: _pastPregnancies.map((p) => p.toMap()).toList(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccessDialog(
          name: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'
              .trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String password,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Mother Added'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name has been registered successfully.'),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Email', value: email),
            const SizedBox(height: 6),
            _CredentialRow(label: 'Password', value: password),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Share these credentials securely with the mother.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dismiss dialog
              Navigator.pop(context, true); // return to mothers list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Step titles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const _stepTitles = [
    'Personal Information',
    'Address Information',
    'Emergency Contacts',
    'Vital Statistics',
    'Medical Conditions',
    'Allergies',
    'Pregnancy History',
    'Gestational Information',
    'Summary & Submit',
  ];

  static const _stepSubtitles = [
    'Name, phone, email and login credentials',
    'Current place of residence',
    'Who to contact in an emergency',
    'Age, height, weight and blood type',
    'Known diagnoses and health conditions',
    'Known allergens and reactions',
    'Previous pregnancy outcomes',
    'Current pregnancy dating',
    'Review before saving',
  ];

  // â”€â”€ Step content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _pageFor(int index) {
    final content = switch (index) {
      0 => _stepPersonal(),
      1 => _stepAddress(),
      2 => _stepEmergencyContacts(),
      3 => _stepVitals(),
      4 => _stepMedicalConditions(),
      5 => _stepAllergies(),
      6 => _stepPregnancyHistory(),
      7 => _stepGestational(),
      _ => _stepSummary(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: content,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 0 : Personal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Full Name'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'First Name',
                controller: _firstNameCtrl,
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Middle',
                controller: _middleNameCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppInputField(
                hintText: 'Last Name',
                controller: _lastNameCtrl,
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Ext. (Jr., III)',
                controller: _extNameCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z\s\-\.\,]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel('Contact'),
        AppInputField(
          hintText: 'Phone Number',
          controller: _phoneCtrl,
          isRequired: true,
          leadingIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          errorText: _phoneError,
        ),
        const SizedBox(height: 24),
        _sectionLabel('Account Credentials'),
        AppInputField(
          hintText: 'Email Address',
          controller: _emailCtrl,
          isRequired: true,
          leadingIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
          errorText: _emailError,
        ),
        if (_emailChecking) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.brandAccent,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Checking availability...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Password field
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _passwordFocus.hasFocus
                  ? AppColors.brandPrimary
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: AppColors.brandAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Temporary Password *',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: AppColors.brandAccent,
                  size: 20,
                ),
                tooltip: 'Auto-generate password',
                onPressed: _generatePassword,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (_passwordCtrl.text.isNotEmpty)
          _passwordStrengthBar()
        else
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              'Tap the wand icon to auto-generate a secure password.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 1 : Address â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BHC info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_outlined,
                color: AppColors.brandAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assigned BHC: ${_bhcName.isEmpty ? '-' : _bhcName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Address Type'),
        _addressOption(
          title: 'Same as BHC address',
          subtitle:
              'Bulacan - Baliwag - ${_bhcName.isEmpty ? 'Assigned barangay' : _bhcName}',
          selected: _addressSameAsBhc,
          onTap: () => setState(() {
            _addressSameAsBhc = true;
            _applyBhcAddress();
          }),
        ),
        const SizedBox(height: 8),
        _addressOption(
          title: 'Custom address',
          subtitle: 'Enter a different barangay, city or province',
          selected: !_addressSameAsBhc,
          onTap: () => setState(() {
            _addressSameAsBhc = false;
            _selectedBarangay = null;
            _barangayCtrl.clear();
          }),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Address Details'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInputField(
                hintText: 'House No.',
                controller: _houseCtrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppInputField(
                hintText: 'Street',
                controller: _streetCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Barangay: read-only pill when BHC, dropdown when custom
        if (_addressSameAsBhc)
          AppInputField(
            hintText: 'Barangay',
            controller: _barangayCtrl,
            leadingIcon: Icons.location_on_outlined,
            readOnly: true,
            onChanged: (_) {},
          )
        else
          _styledDropdown(
            hint: 'Barangay *',
            value: _selectedBarangay,
            items: _bhcBarangays,
            icon: Icons.location_on_outlined,
            onChanged: (v) => setState(() => _selectedBarangay = v),
          ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'City / Municipality',
          controller: _cityCtrl,
          readOnly: _addressSameAsBhc,
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Province',
          controller: _provinceCtrl,
          readOnly: _addressSameAsBhc,
          onChanged: (_) {},
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 2 : Emergency Contacts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Emergency Contacts',
          subtitle: 'Optional - skip if not available',
          actionLabel: 'Add Contact',
          onAction: _showAddEmergencyContact,
        ),
        const SizedBox(height: 12),
        if (_emergencyContacts.isEmpty)
          _emptyState(
            Icons.contacts_outlined,
            'No emergency contacts added.\nYou can skip this step.',
          )
        else
          ..._emergencyContacts.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.person_outline),
                  title: '${e.value.firstName} ${e.value.lastName}',
                  subtitle: [
                    e.value.phoneNumber,
                    if (e.value.affiliation != null) e.value.affiliation!,
                  ].join(' - '),
                  onDelete: () =>
                      setState(() => _emergencyContacts.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 3 : Vitals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepVitals() {
    final age = _birthdate != null
        ? (DateTime.now().difference(_birthdate!).inDays / 365.25).floor()
        : null;
    final h = double.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);
    final bmi =
        (h != null && w != null && h > 0) ? w / ((h / 100) * (h / 100)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Birthdate'),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthdate ?? DateTime(1990),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _birthdate = picked;
                _birthdateCtrl.text = _dateFmt.format(picked);
              });
            }
          },
          child: IgnorePointer(
            child: AppInputField(
              hintText: 'Birthdate',
              controller: _birthdateCtrl,
              isRequired: true,
              leadingIcon: Icons.cake_outlined,
              readOnly: true,
              onChanged: (_) {},
            ),
          ),
        ),
        if (age != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Age: $age years old',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (age < 10 || age > 50)
            _riskHint(
              'Maternal age ($age yrs) is outside the possible range (10–50).',
              isError: true,
            )
          else if (age < 18)
            _riskHint('High-risk: adolescent pregnancy (under 18).')
          else if (age > 35)
            _riskHint('Advanced maternal age (>35) — high-risk pregnancy.'),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Body Measurements'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInputField(
                hintText: 'Height (cm)',
                controller: _heightCtrl,
                isRequired: true,
                leadingIcon: Icons.straighten_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInputField(
                hintText: 'Weight (kg)',
                controller: _weightCtrl,
                isRequired: true,
                leadingIcon: Icons.monitor_weight_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (bmi != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Text(
                  'BMI: ${bmi.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _bmiTag(bmi),
              ],
            ),
          ),
          // Height risk hint
          if (h != null && (h < 100 || h > 220))
            _riskHint(
              'Height (${h.toStringAsFixed(0)} cm) is outside the possible range (100–220 cm).',
              isError: true,
            )
          else if (h != null && h < 140)
            _riskHint('Unusually short height (<140 cm) — verify entry.'),
          // Weight risk hint
          if (w != null && (w < 30 || w > 200))
            _riskHint(
              'Weight (${w.toStringAsFixed(0)} kg) is outside the possible range (30–200 kg).',
              isError: true,
            )
          else if (w != null && w < 46)
            _riskHint('Low weight (<46 kg) — high-risk nutrition concern.')
          else if (w != null && w > 90)
            _riskHint('High weight (>90 kg) — high-risk for complications.'),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Blood Type (optional)'),
        _styledDropdown(
          hint: 'Select Blood Type',
          value: _bloodType,
          items: const [
            'A+',
            'A-',
            'B+',
            'B-',
            'AB+',
            'AB-',
            'O+',
            'O-',
            'Unknown'
          ],
          icon: Icons.bloodtype_outlined,
          onChanged: (v) => setState(() => _bloodType = v),
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 4 : Medical Conditions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepMedicalConditions() {
    const common = [
      'Anemia',
      'Diabetes',
      'Hypertension',
      'Smoking',
      'Alcohol Use',
      'Domestic Violence',
      'Bleeding Postpartum',
      'Prolonged Labor',
      'Other',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Medical Conditions',
          subtitle: 'Tap a chip to quick-add or use the button',
          actionLabel: 'Add',
          onAction: () => _showAddMedicalCondition(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: common
              .map(
                (c) => GestureDetector(
                  onTap: () => _showAddMedicalCondition(prefill: c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderPrimary),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          size: 13,
                          color: AppColors.brandAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          c,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        if (_medicalConditions.isEmpty)
          _emptyState(
            Icons.medical_services_outlined,
            'No conditions added.\nSkip if not applicable.',
          )
        else
          ..._medicalConditions.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.medical_services_outlined),
                  title: e.value.conditionName,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.diagnosisDate != null)
                      _dateFmt.format(e.value.diagnosisDate!),
                    if (e.value.remarks != null) e.value.remarks!,
                  ].join(' - '),
                  onDelete: () =>
                      setState(() => _medicalConditions.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 5 : Allergies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepAllergies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Allergies',
          subtitle: 'Optional - skip if none',
          actionLabel: 'Add Allergy',
          onAction: _showAddAllergy,
        ),
        const SizedBox(height: 12),
        if (_allergies.isEmpty)
          _emptyState(
            Icons.no_food_outlined,
            'No allergies recorded.\nSkip if not applicable.',
          )
        else
          ..._allergies.asMap().entries.map(
                (e) => _itemCard(
                  leading: _iconAvatar(Icons.warning_amber_outlined,
                      color: AppColors.warning),
                  title: e.value.allergen,
                  subtitle: [
                    e.value.status == 'active' ? 'Active' : 'Resolved',
                    if (e.value.treatment != null) e.value.treatment!,
                  ].join(' - '),
                  onDelete: () => setState(() => _allergies.removeAt(e.key)),
                ),
              ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 6 : Pregnancy History â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepPregnancyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SwitchListTile(
            title: const Text(
              'Had previous pregnancies?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Toggle on to log past pregnancy records'),
            value: _hasPastPregnancy,
            activeThumbColor: AppColors.brandPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onChanged: (v) => setState(() {
              _hasPastPregnancy = v;
              if (!v) _pastPregnancies.clear();
            }),
          ),
        ),
        if (_hasPastPregnancy) ...[
          const SizedBox(height: 16),
          _listHeader(
            title: 'Past Pregnancies',
            subtitle: 'Add each previous pregnancy record',
            actionLabel: 'Add',
            onAction: _showAddPastPregnancy,
          ),
          const SizedBox(height: 8),
          if (_pastPregnancies.isEmpty)
            _emptyState(
              Icons.history_outlined,
              'No records yet. Add at least one.',
            )
          else
            ...(() {
              final sorted = _pastPregnancies.asMap().entries.toList()
                ..sort((a, b) =>
                    a.value.outcomeDate.compareTo(b.value.outcomeDate));
              return sorted.map((e) {
                final p = e.value;
                return _itemCard(
                  leading: _iconAvatar(Icons.pregnant_woman_outlined),
                  title:
                      'G${sorted.indexOf(e) + 1} · ${_outcomeLabel(p.outcome)}',
                  subtitle: [
                    _dateFmt.format(p.outcomeDate),
                    if (p.gestationalAgeAtEnd != null)
                      '${p.gestationalAgeAtEnd!.toStringAsFixed(0)} wks AOG',
                    if (p.placeOfDelivery != null) p.placeOfDelivery!,
                    if (p.deliveryMethod != null) p.deliveryMethod!,
                  ].join(' · '),
                  onDelete: () =>
                      setState(() => _pastPregnancies.removeAt(e.key)),
                  onEdit: () => _showEditPastPregnancy(e.key),
                );
              });
            })(),
        ],
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 7 : Gestational â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepGestational() {
    final methodItems = const ['lmp', 'edd', 'aog'];
    final methodLabels = const [
      'Last Menstrual Period (LMP)',
      'Estimated Delivery Date (EDD)',
      'Age of Gestation (AOG)',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Calculation Method'),
        _styledDropdown(
          hint: 'Select method',
          value: _gestationMethod.name,
          items: methodItems,
          itemLabels: methodLabels,
          icon: Icons.calculate_outlined,
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _gestationMethod =
                  _GestationMethod.values.firstWhere((e) => e.name == v);
              _lmp = null;
              _edd = null;
              _lmpCtrl.clear();
              _eddCtrl.clear();
              _aogWeeksCtrl.clear();
              _aogDaysCtrl.clear();
            });
          },
        ),
        const SizedBox(height: 20),
        _sectionLabel('Date Entry'),
        if (_gestationMethod == _GestationMethod.lmp)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _lmp ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _updateFromLmp(picked));
            },
            child: IgnorePointer(
              child: AppInputField(
                hintText: 'Last Menstrual Period',
                controller: _lmpCtrl,
                isRequired: true,
                leadingIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onChanged: (_) {},
              ),
            ),
          )
        else if (_gestationMethod == _GestationMethod.edd)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _edd ?? DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 300)),
              );
              if (picked != null) setState(() => _updateFromEdd(picked));
            },
            child: IgnorePointer(
              child: AppInputField(
                hintText: 'Estimated Delivery Date',
                controller: _eddCtrl,
                isRequired: true,
                leadingIcon: Icons.event_available_outlined,
                readOnly: true,
                onChanged: (_) {},
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  hintText: 'Weeks',
                  controller: _aogWeeksCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(_updateFromAog),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  hintText: 'Days',
                  controller: _aogDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(_updateFromAog),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        _sectionLabel('Computed Values'),
        _derivedRow(
          Icons.calendar_today_outlined,
          'LMP',
          _lmpCtrl.text.isEmpty ? '-' : _lmpCtrl.text,
        ),
        const SizedBox(height: 8),
        _derivedRow(
          Icons.event_available_outlined,
          'EDD',
          _eddCtrl.text.isEmpty ? '-' : _eddCtrl.text,
        ),
        const SizedBox(height: 8),
        _derivedRow(Icons.timer_outlined, 'AOG', _formatAog()),
        if (_lmp != null)
          Builder(builder: (_) {
            final weeks = DateTime.now().difference(_lmp!).inDays ~/ 7;
            if (weeks > 42) {
              return _riskHint(
                'Gestational age ($weeks weeks) exceeds 42 weeks — biologically impossible. Please verify LMP.',
                isError: true,
              );
            }
            if (weeks == 42) {
              return _riskHint(
                  'Post-term pregnancy (42 weeks) — high-risk, monitor closely.');
            }
            return const SizedBox.shrink();
          }),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Step 8 : Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _stepSummary() {
    final fullName = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty)
        '${_middleNameCtrl.text.trim()[0]}.',
      _lastNameCtrl.text.trim(),
      if (_extNameCtrl.text.trim().isNotEmpty) _extNameCtrl.text.trim(),
    ].join(' ');

    final address = [
      if (_houseCtrl.text.trim().isNotEmpty) _houseCtrl.text.trim(),
      if (_streetCtrl.text.trim().isNotEmpty) _streetCtrl.text.trim(),
      if (_selectedBarangay != null) _selectedBarangay!,
      if (_cityCtrl.text.trim().isNotEmpty) _cityCtrl.text.trim(),
      if (_provinceCtrl.text.trim().isNotEmpty) _provinceCtrl.text.trim(),
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.brandAccent,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review all details. Navigate back to make changes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _summarySection('Personal', [
          _summaryRow('Name', fullName.isEmpty ? '-' : fullName),
          _summaryRow('Phone',
              _phoneCtrl.text.trim().isEmpty ? '-' : _phoneCtrl.text.trim()),
          _summaryRow('Email',
              _emailCtrl.text.trim().isEmpty ? '-' : _emailCtrl.text.trim()),
        ]),
        const SizedBox(height: 12),
        _summarySection('Address', [
          _summaryRow('Address', address.isEmpty ? '-' : address),
        ]),
        const SizedBox(height: 12),
        _summarySection('Vitals', [
          _summaryRow(
            'Birthdate',
            _birthdate != null ? _dateFmt.format(_birthdate!) : '-',
          ),
          _summaryRow(
            'Height / Weight',
            '${_heightCtrl.text.trim().isEmpty ? '-' : _heightCtrl.text.trim()} cm / ${_weightCtrl.text.trim().isEmpty ? '-' : _weightCtrl.text.trim()} kg',
          ),
          _summaryRow('Blood Type', _bloodType ?? '-'),
        ]),
        const SizedBox(height: 12),
        _summarySection('Gestation', [
          _summaryRow('LMP', _lmp != null ? _dateFmt.format(_lmp!) : '-'),
          _summaryRow('EDD', _edd != null ? _dateFmt.format(_edd!) : '-'),
          _summaryRow('AOG', _formatAog()),
        ]),
        const SizedBox(height: 12),
        _summarySection('Records', [
          _summaryRow(
            'Emergency Contacts',
            '${_emergencyContacts.length} added',
          ),
          _summaryRow(
            'Medical Conditions',
            '${_medicalConditions.length} added',
          ),
          _summaryRow('Allergies', '${_allergies.length} added'),
          _summaryRow(
            'Past Pregnancies',
            _hasPastPregnancy ? '${_pastPregnancies.length} added' : 'None',
          ),
        ]),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Modals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showAddEmergencyContact() async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? affiliationValue;

    bool isPhoneValid(String v) {
      final n = v.trim().replaceAll(RegExp(r'[^0-9+]'), '');
      return RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(n);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final phoneEntered = phoneCtrl.text.trim().isNotEmpty;
          final phoneValid = !phoneEntered || isPhoneValid(phoneCtrl.text);
          final canAdd = firstCtrl.text.trim().isNotEmpty &&
              lastCtrl.text.trim().isNotEmpty &&
              phoneEntered &&
              phoneValid;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Emergency Contact'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modalField(
                    'First Name *',
                    firstCtrl,
                    onChanged: (_) => setS(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s\-\']")),
                      LengthLimitingTextInputFormatter(100),
                    ],
                  ),
                  _modalField(
                    'Last Name *',
                    lastCtrl,
                    onChanged: (_) => setS(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s\-\']")),
                      LengthLimitingTextInputFormatter(100),
                    ],
                  ),
                  _modalField(
                    'Phone Number *',
                    phoneCtrl,
                    onChanged: (_) => setS(() {}),
                    keyboard: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                      LengthLimitingTextInputFormatter(15),
                    ],
                    errorText: phoneEntered && !phoneValid
                        ? 'Enter a valid PH number (e.g. 09XXXXXXXXX)'
                        : null,
                  ),
                  _modalDropdown(
                    ctx,
                    label: 'Relationship / Affiliation',
                    value: affiliationValue,
                    items: const {
                      'Spouse / Partner': 'Spouse / Partner',
                      'Parent': 'Parent',
                      'Child': 'Child',
                      'Sibling': 'Sibling',
                      'Relative': 'Relative',
                      'Friend': 'Friend',
                      'Neighbor': 'Neighbor',
                      'Coworker': 'Coworker',
                      'Other': 'Other',
                    },
                    onChanged: (v) => setS(() => affiliationValue = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canAdd ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final ec = _EmergencyContact()
        ..firstName = firstCtrl.text.trim()
        ..lastName = lastCtrl.text.trim()
        ..phoneNumber = phoneCtrl.text.trim()
        ..affiliation = affiliationValue;
      setState(() => _emergencyContacts.add(ec));
    }
  }

  Future<void> _showAddMedicalCondition({String? prefill}) async {
    final nameCtrl = TextEditingController(text: prefill ?? '');
    DateTime? diagDate;
    String status = 'active';
    final remarksCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Medical Condition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modalField('Condition Name *', nameCtrl,
                    onChanged: (_) => setS(() {}), maxLength: 255),
                _modalDateTile(
                  ctx,
                  label: diagDate == null
                      ? 'Diagnosis Date (optional)'
                      : _dateFmt.format(diagDate!),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => diagDate = d);
                  },
                ),
                _modalDropdown(
                  ctx,
                  label: 'Status',
                  value: status,
                  items: const {'active': 'Active', 'resolved': 'Resolved'},
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                _modalField('Remarks (optional)', remarksCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final mc = _MedicalCondition(nameCtrl.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..remarks =
            remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim();
      setState(() => _medicalConditions.add(mc));
    }
  }

  Future<void> _showAddAllergy() async {
    final allergenCtrl = TextEditingController();
    DateTime? diagDate;
    String status = 'active';
    final treatmentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Allergy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modalField('Allergen *', allergenCtrl,
                    onChanged: (_) => setS(() {}), maxLength: 255),
                _modalDateTile(
                  ctx,
                  label: diagDate == null
                      ? 'Diagnosis Date (optional)'
                      : _dateFmt.format(diagDate!),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: diagDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => diagDate = d);
                  },
                ),
                _modalDropdown(
                  ctx,
                  label: 'Status',
                  value: status,
                  items: const {'active': 'Active', 'resolved': 'Resolved'},
                  onChanged: (v) => setS(() => status = v ?? 'active'),
                ),
                _modalField('Treatment (optional)', treatmentCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: allergenCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && allergenCtrl.text.trim().isNotEmpty) {
      final al = _Allergy(allergenCtrl.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..treatment = treatmentCtrl.text.trim().isEmpty
            ? null
            : treatmentCtrl.text.trim();
      setState(() => _allergies.add(al));
    }
  }

  Future<void> _showAddPastPregnancy() async {
    final result = await _showPastPregnancyDialog();
    if (result != null) setState(() => _pastPregnancies.add(result));
  }

  Future<void> _showEditPastPregnancy(int index) async {
    final result = await _showPastPregnancyDialog(
      prefill: _pastPregnancies[index],
      editIndex: index,
    );
    if (result != null) setState(() => _pastPregnancies[index] = result);
  }

  /// Shared add / edit dialog for a [_PastPregnancy] entry.
  /// Pass [prefill] + [editIndex] when editing an existing record.
  Future<_PastPregnancy?> _showPastPregnancyDialog({
    _PastPregnancy? prefill,
    int? editIndex,
  }) async {
    String outcome = prefill?.outcome ?? 'live_birth';
    DateTime? outcomeDate = prefill?.outcomeDate;
    bool isEstimated = prefill?.isEstimated ?? false;
    final gaCtrl = TextEditingController(
        text: prefill?.gestationalAgeAtEnd != null
            ? prefill!.gestationalAgeAtEnd!.toStringAsFixed(0)
            : '');
    final placeCtrl =
        TextEditingController(text: prefill?.placeOfDelivery ?? '');
    String? deliveryMethod = prefill?.deliveryMethod;
    String? intervalError = prefill?.outcomeDate != null
        ? _computeIntervalError(prefill!.outcomeDate, excludeIndex: editIndex)
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final needsDelivery =
              outcome == 'live_birth' || outcome == 'stillbirth';
          final gaWeeksParsed = int.tryParse(gaCtrl.text.trim());
          final gaEntered = gaCtrl.text.trim().isNotEmpty;
          final gaError = gaEntered
              ? (gaWeeksParsed != null
                  ? _gaConstraintErrorFor(outcome, gaWeeksParsed)
                  : 'Enter a whole number of weeks')
              : null;
          final constraint = _outcomeGaConstraint(outcome);
          final isValid = outcomeDate != null &&
              intervalError == null &&
              gaError == null &&
              (!needsDelivery ||
                  (placeCtrl.text.trim().isNotEmpty && deliveryMethod != null));

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
                editIndex != null ? 'Edit Pregnancy Record' : 'Past Pregnancy'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modalDropdown(
                    ctx,
                    label: 'Outcome',
                    value: outcome,
                    items: const {
                      'live_birth': 'Live Birth',
                      'stillbirth': 'Stillbirth',
                      'miscarriage': 'Miscarriage',
                      'abortion': 'Abortion',
                      'ectopic': 'Ectopic',
                    },
                    onChanged: (v) => setS(() => outcome = v ?? 'live_birth'),
                  ),
                  _modalDateTileWithError(
                    ctx,
                    label: outcomeDate == null
                        ? 'Outcome / Delivery Date *'
                        : _dateFmt.format(outcomeDate!),
                    errorText: intervalError,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: outcomeDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setS(() {
                          outcomeDate = d;
                          intervalError =
                              _computeIntervalError(d, excludeIndex: editIndex);
                        });
                      }
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isEstimated,
                    onChanged: (v) => setS(() => isEstimated = v ?? false),
                    title: const Text(
                      'Date is estimated',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.brandPrimary,
                  ),
                  _modalField(
                    'Gestational age at outcome (weeks)',
                    gaCtrl,
                    keyboard: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (_) => setS(() {}),
                    errorText: gaError,
                  ),
                  // Outcome-specific GA hint
                  if (constraint != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, bottom: 8, top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 13, color: AppColors.brandAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              constraint.hint,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (needsDelivery) ...[
                    _modalField(
                      'Place of delivery *',
                      placeCtrl,
                      onChanged: (_) => setS(() {}),
                    ),
                    _modalDropdown(
                      ctx,
                      label: 'Delivery method *',
                      value: deliveryMethod,
                      items: const {
                        'Normal Spontaneous Vaginal Delivery':
                            'Normal Spontaneous Vaginal Delivery',
                        'Cesarean Section': 'Cesarean Section',
                        'Assisted Vaginal Delivery':
                            'Assisted Vaginal Delivery',
                        'Other': 'Other',
                      },
                      onChanged: (v) => setS(() => deliveryMethod = v),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(editIndex != null ? 'Save Changes' : 'Add'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && outcomeDate != null) {
      return _PastPregnancy(outcome: outcome, outcomeDate: outcomeDate!)
        ..isEstimated = isEstimated
        ..gestationalAgeAtEnd = double.tryParse(gaCtrl.text.trim())
        ..placeOfDelivery =
            placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim()
        ..deliveryMethod = deliveryMethod;
    }
    return null;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ UI Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _outcomeLabel(String outcome) => switch (outcome) {
        'live_birth' => 'Live Birth',
        'stillbirth' => 'Stillbirth',
        'miscarriage' => 'Miscarriage',
        'abortion' => 'Abortion',
        'ectopic' => 'Ectopic',
        _ => outcome,
      };

  /// Inline risk/warning chip displayed under input fields.
  /// [isError] = red (impossible), false = amber (high-risk warning).
  Widget _riskHint(String text, {bool isError = false}) => Padding(
        padding: const EdgeInsets.only(left: 16, top: 3),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.warning_amber_rounded,
              size: 13,
              color: isError ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  color: isError ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      );

  int _passwordStrengthLevel() {
    final pw = _passwordCtrl.text;
    if (pw.isEmpty) return 0;
    if (pw.length < 8) return 1;
    int score = 1;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)) score++;
    return score.clamp(1, 3);
  }

  Widget _passwordStrengthBar() {
    final level = _passwordStrengthLevel();
    const labels = ['', 'Weak', 'Fair', 'Strong'];
    final colors = [
      Colors.transparent,
      AppColors.error,
      AppColors.warning,
      const Color(0xFF4CAF50),
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          ...List.generate(
            3,
            (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < level ? colors[level] : AppColors.borderPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            labels[level],
            style: TextStyle(
              fontSize: 11,
              color: colors[level],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bmiTag(double bmi) {
    final String label;
    final Color color;
    if (bmi < 18.5) {
      label = 'Underweight';
      color = AppColors.warning;
    } else if (bmi < 25) {
      label = 'Normal';
      color = const Color(0xFF4CAF50);
    } else if (bmi < 30) {
      label = 'Overweight';
      color = AppColors.warning;
    } else {
      label = 'Obese';
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      );

  Widget _addressOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? AppColors.brandPrimary : AppColors.borderPrimary,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.brandPrimary : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _styledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final labels = itemLabels ?? items;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: List.generate(
                  items.length,
                  (i) => DropdownMenuItem<String>(
                    value: items[i],
                    child: Text(
                      labels[i],
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader({
    required String title,
    String? subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) =>
      Row(
        children: [
          Expanded(
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
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandAccent,
            ),
          ),
        ],
      );

  Widget _emptyState(IconData icon, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _iconAvatar(IconData icon, {Color? color}) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? AppColors.brandPrimary,
        ),
      );

  Widget _itemCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
    VoidCallback? onEdit,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: leading,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: onEdit != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.brandAccent,
                        size: 20,
                      ),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
        ),
      );

  Widget _derivedRow(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandAccent, size: 17),
            const SizedBox(width: 10),
            Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _summarySection(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: rows
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        e.value,
                        if (e.key < rows.length - 1)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.borderPrimary,
                          ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  // â”€â”€ Modal helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _modalField(
    String label,
    TextEditingController ctrl, {
    ValueChanged<String>? onChanged,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            filled: true,
            fillColor: AppColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderPrimary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderPrimary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.brandPrimary,
                width: 1.5,
              ),
            ),
          ),
        ),
      );

  Widget _modalDateTile(
    BuildContext ctx, {
    required String label,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: AppColors.brandAccent,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _modalDateTileWithError(
    BuildContext ctx, {
    required String label,
    required VoidCallback onTap,
    String? errorText,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: errorText != null
                        ? AppColors.error
                        : AppColors.borderPrimary,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: AppColors.brandAccent,
                    ),
                  ],
                ),
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _modalDropdown(
    BuildContext ctx, {
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderPrimary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderPrimary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.brandPrimary,
                width: 1.5,
              ),
            ),
          ),
          isExpanded: true,
          items: items.entries
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Add Mother',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _startOcrFlow,
              icon: const Icon(
                Icons.document_scanner_outlined,
                size: 18,
              ),
              label: const Text('OCR'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderPrimary),
        ),
      ),
      body: Column(
        children: [
          // Linear progress bar
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: AppColors.borderPrimary,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.brandPrimary,
            ),
            minHeight: 3,
          ),
          // Step header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                ProgressiveStepIndicator(
                  currentStep: _step,
                  totalSteps: _totalSteps,
                ),
                const SizedBox(height: 10),
                Text(
                  _stepTitles[_step],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stepSubtitles[_step],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${_step + 1} of $_totalSteps',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Step pages
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalSteps,
              itemBuilder: (_, i) => _pageFor(i),
            ),
          ),
        ],
      ),
      // Fixed bottom navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                if (_step > 0) ...[
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _goBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 13,
                    ),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      side: const BorderSide(color: AppColors.brandAccent),
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _step < _totalSteps - 1
                        ? ElevatedButton(
                            onPressed: _submitting ? null : _goNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Next'),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 17),
                            label: Text(
                              _submitting ? 'Saving...' : 'Finalize & Save',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Helper Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
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
