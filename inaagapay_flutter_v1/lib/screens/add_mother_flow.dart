import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/add_mother_form_data.dart';
import '../services/auth_storage.dart';
import '../services/risk_engine.dart';
import '../theme/app_colors.dart';
import '../widgets/app_input_field.dart';
import '../widgets/progressive_step_indicator.dart';
import '../widgets/risk_panel.dart';
import 'add_prenatal_checkup.dart';
import 'mother_profile_page.dart';

enum GestationMethod { lmp, edd, aog }

class AddMotherFlow extends StatefulWidget {
  const AddMotherFlow({super.key});

  @override
  State<AddMotherFlow> createState() => _AddMotherFlowState();
}

class _AddMotherFlowState extends State<AddMotherFlow> {
  final AddMotherFormData form = AddMotherFormData();
  final dateFmt = DateFormat('MMMM d, yyyy');

  // ===== CONTROLLERS =====
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _extName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  final TextEditingController _houseNumber = TextEditingController();
  final TextEditingController _street = TextEditingController();
  final TextEditingController _barangay = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _province = TextEditingController();

  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  final TextEditingController _birthDateCtrl = TextEditingController();

  final TextEditingController _gestationLmp = TextEditingController();
  final TextEditingController _gestationEdd = TextEditingController();
  final TextEditingController _aogWeeks = TextEditingController();
  final TextEditingController _aogDays = TextEditingController();

  GestationMethod _gestationMethod = GestationMethod.lmp;
  String? _emailError;
  String? _phoneError;
  Timer? _emailCheckTimer;
  String? _lastEmailChecked;
  bool _emailChecking = false;
  bool _emailExists = false;

  int step = 0;
  static const int totalSteps = 9; // mother-only steps
  bool loadingContext = true;
  bool submitting = false;

  RiskAssessment risk = const RiskAssessment(
    level: 'low',
    score: 0,
    factors: ['No significant risk factors identified so far.'],
    note: 'No significant risk factors identified so far.',
  );

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _extName.dispose();
    _email.dispose();
    _phone.dispose();
    _houseNumber.dispose();
    _street.dispose();
    _barangay.dispose();
    _city.dispose();
    _province.dispose();
    _height.dispose();
    _weight.dispose();
    _birthDateCtrl.dispose();
    _gestationLmp.dispose();
    _gestationEdd.dispose();
    _aogWeeks.dispose();
    _aogDays.dispose();
    _emailCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) throw Exception('Not authenticated');

      final res = await http.get(
        Uri.parse('https://inaagapay.alwaysdata.net/api/midwife/context.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final decoded = jsonDecode(res.body);
      if (decoded['success'] == true) {
        form.context.midwifeId = decoded['midwife_id'];
        form.context.assignedBhcId = decoded['assigned_bhc_id'];
        form.context.assignedBhcName = decoded['bhc_name'];

        // Prefill address when same as BHC
        if (form.addressSameAsBhc) {
          _province.text = 'Bulacan';
          _city.text = 'Baliwag';
          _barangay.text = form.context.assignedBhcName ?? '';
          form.province = _province.text;
          form.city = _city.text;
          form.barangay = _barangay.text;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Context load failed: $e')));
      }
    } finally {
      _recomputeRisk();
      if (mounted) {
        setState(() => loadingContext = false);
      }
    }
  }

  void _recomputeRisk() {
    if (!mounted) return;
    setState(() {
      risk = RiskEngine.evaluate(form);
    });
  }

  void _updateEddFromLmp() {
    if (form.lmp == null) return;
    final edd = form.lmp!.add(const Duration(days: 280));
    form.edd = edd;
    _gestationEdd.text = dateFmt.format(edd);
    _gestationLmp.text = dateFmt.format(form.lmp!);
  }

  void _updateDerivedFromLmp(DateTime lmp) {
    form.lmp = lmp;
    _updateEddFromLmp();
  }

  void _updateDerivedFromEdd(DateTime edd) {
    form.edd = edd;
    final lmp = edd.subtract(const Duration(days: 280));
    form.lmp = lmp;
    _gestationLmp.text = dateFmt.format(lmp);
    _gestationEdd.text = dateFmt.format(edd);
  }

  void _updateDerivedFromAog() {
    final weeks = int.tryParse(_aogWeeks.text.trim()) ?? 0;
    final days = int.tryParse(_aogDays.text.trim()) ?? 0;
    if (weeks <= 0 && days <= 0) return;

    final totalDays = (weeks * 7) + days;
    final lmp = DateTime.now().subtract(Duration(days: totalDays));
    form.lmp = lmp;
    form.edd = lmp.add(const Duration(days: 280));
    _gestationLmp.text = dateFmt.format(lmp);
    _gestationEdd.text = dateFmt.format(form.edd!);
  }

  String _formatAogFromLmp() {
    if (form.lmp == null) return '—';
    final days = DateTime.now().difference(form.lmp!).inDays;
    if (days < 0) return '—';
    final weeks = days ~/ 7;
    final remDays = days % 7;
    return '${weeks}w ${remDays}d';
  }

  void _onEmailChanged(String v) {
    final value = v.trim();
    form.email = value.isEmpty ? null : value;
    if (value.isEmpty) {
      _emailCheckTimer?.cancel();
      _lastEmailChecked = null;
      _emailChecking = false;
      _emailExists = false;
      setState(() => _emailError = null);
      return;
    }
    final isValid = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+").hasMatch(value);
    setState(() => _emailError = isValid ? null : 'Enter a valid email');
    if (!isValid) {
      _emailCheckTimer?.cancel();
      _lastEmailChecked = null;
      _emailChecking = false;
      _emailExists = false;
      return;
    }

    _emailCheckTimer?.cancel();
    _emailChecking = true;
    _emailExists = false;
    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () {
      _checkEmailExists(value);
    });
  }

  Future<void> _checkEmailExists(String email) async {
    try {
      _lastEmailChecked = email;
      final token = await AuthStorage.getToken();
      if (token == null) return;

      final encodedEmail = Uri.encodeComponent(email);
      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/check_email.php?email=$encodedEmail',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final decoded = jsonDecode(res.body);
      if (_lastEmailChecked != email) return;

      if (decoded['success'] == true) {
        final available = decoded['available'] == true;
        setState(() {
          _emailChecking = false;
          _emailExists = !available;
          _emailError = available ? null : 'Email already exists';
        });
      }
    } catch (_) {
      if (_lastEmailChecked != email) return;
      setState(() {
        _emailChecking = false;
        _emailError = 'Unable to verify email';
      });
    }
  }

  void _onPhoneChanged(String v) {
    final value = v.trim();
    form.phone = value;
    final normalized = value.replaceAll(RegExp(r'[^0-9+]'), '');
    final isValid = RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(normalized);
    setState(() => _phoneError = isValid ? null : 'Enter a valid PH number');
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
      _recomputeRisk();
    }
  }

  bool _validateStep() {
    String? message;
    switch (step) {
      case 0:
        final issues = <String>[];
        if (_firstName.text.trim().isEmpty) issues.add('First Name');
        if (_lastName.text.trim().isEmpty) issues.add('Last Name');
        if (_phone.text.trim().isEmpty) {
          issues.add('Phone Number');
        } else if (_phoneError != null) {
          issues.add('Phone Number (invalid)');
        }
        if (_email.text.trim().isNotEmpty) {
          if (_emailChecking) {
            issues.add('Email (checking)');
          } else if (_emailExists) {
            issues.add('Email (already exists)');
          } else if (_emailError != null) {
            issues.add('Email (invalid)');
          }
        }
        if (issues.isNotEmpty) {
          message = 'Please fix: ${issues.join(', ')}.';
        }
        break;
      case 1:
        if (!form.addressSameAsBhc) {
          if (_province.text.trim().isEmpty ||
              _city.text.trim().isEmpty ||
              _barangay.text.trim().isEmpty) {
            message = 'Province, city/municipality, and barangay are required.';
          }
        }
        break;
      case 3:
        final issues = <String>[];
        if (form.birthdate == null) issues.add('Birthdate');
        final heightVal = double.tryParse(_height.text.trim());
        final weightVal = double.tryParse(_weight.text.trim());

        if (heightVal == null || heightVal <= 0) {
          issues.add('Height (cm)');
        }
        if (weightVal == null || weightVal <= 0) {
          issues.add('Weight (kg)');
        }

        if (issues.isNotEmpty) {
          message = 'Please provide: ${issues.join(', ')}.';
        } else {
          form.heightCm = heightVal;
          form.weightKg = weightVal;
        }
        break;
      case 6:
        if (form.hasPastPregnancy && form.pregnancyHistory.isEmpty) {
          message = 'Add at least one past pregnancy or toggle off the switch.';
        }
        for (final hist in form.pregnancyHistory) {
          if ((hist.outcome == 'live_birth' || hist.outcome == 'stillbirth') &&
              (hist.placeOfDelivery == null || hist.deliveryMethod == null)) {
            message =
                'Provide delivery place and method for live birth or stillbirth records.';
            break;
          }
        }
        break;
      case 7:
        if (_gestationMethod == GestationMethod.lmp && form.lmp == null) {
          message = 'Select LMP date.';
        } else if (_gestationMethod == GestationMethod.edd &&
            form.edd == null) {
          message = 'Select EDD date.';
        } else if (_gestationMethod == GestationMethod.aog &&
            (_aogWeeks.text.trim().isEmpty && _aogDays.text.trim().isEmpty)) {
          message = 'Enter age of gestation in weeks or days.';
        }

        if (message == null) {
          if (form.lmp == null || form.edd == null) {
            message = 'Provide gestational info to compute LMP and EDD.';
          } else {
            final days = form.edd!.difference(form.lmp!).inDays;
            if (days < 259 || days > 294) {
              message = 'EDD must be 37–42 weeks from LMP.';
            }
          }
        }
        break;
      case 8:
        if (form.context.midwifeId == null ||
            form.context.assignedBhcId == null) {
          message = 'Midwife context is missing. Please retry.';
        }
        break;
    }

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (step < totalSteps - 1) {
      setState(() => step++);
    }
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    setState(() => submitting = true);
    try {
      final token = await AuthStorage.getToken();
      if (token == null) throw Exception('Not authenticated');

      final payload = form.toPayload(
        pregnancyRiskLevel: risk.level,
        includeFirstPrenatal: false,
      );
      final res = await http.post(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/add_mother_full.php',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(res.body);
      if (decoded['success'] == true) {
        if (!mounted) return;
        final motherId = decoded['mother_id'];
        final pregnancyId = decoded['pregnancy_id'];

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Mother Added Successfully'),
            content: const Text(
              'Would you like to add a prenatal checkup now or go to the mother’s profile?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MotherProfilePage(motherId: motherId),
                    ),
                  );
                },
                child: const Text('Go to Profile'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPrenatalCheckupScreen(
                        motherId: motherId,
                        pregnancyId: pregnancyId,
                        lmp: form.lmp,
                        motherWeight: form.weightKg,
                      ),
                    ),
                  );
                },
                child: const Text('Add Prenatal Checkup'),
              ),
            ],
          ),
        );
      } else {
        throw Exception(decoded['message'] ?? 'Save failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ProgressiveStepIndicator(currentStep: step, totalSteps: totalSteps),
        const SizedBox(height: 12),
        Text(
          _stepTitle(step),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.brandText,
          ),
        ),
      ],
    );
  }

  String _stepTitle(int s) {
    const titles = [
      'Personal Information',
      'Address Information',
      'Emergency Contacts',
      'Vital Statistics',
      'Medical Conditions',
      'Allergies',
      'Pregnancy History',
      'Current Gestational Info',
      'Summary',
    ];
    return titles[s];
  }

  Widget _scaffoldControls({bool showSubmit = false}) {
    return Row(
      children: [
        if (step > 0)
          OutlinedButton(
            onPressed: submitting ? null : _back,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandAccent,
            ),
            child: const Text('Back'),
          ),
        const Spacer(),
        if (showSubmit)
          ElevatedButton.icon(
            onPressed: submitting ? null : _submit,
            icon: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(submitting ? 'Saving...' : 'Finalize & Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 48),
            ),
          )
        else
          ElevatedButton(
            onPressed: submitting ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 48),
            ),
            child: const Text('Next'),
          ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (step) {
      case 0:
        return _personalInfo();
      case 1:
        return _addressInfo();
      case 2:
        return _emergencyContacts();
      case 3:
        return _vitalStats();
      case 4:
        return _medicalConditions();
      case 5:
        return _allergies();
      case 6:
        return _pregnancyHistory();
      case 7:
        return _gestationalInfo();
      default:
        return _summary();
    }
  }

  Widget _personalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInputField(
          hintText: 'First Name',
          controller: _firstName,
          isRequired: true,
          onChanged: (v) => form.firstName = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Middle Name',
          controller: _middleName,
          onChanged: (v) => form.middleName = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Last Name',
          controller: _lastName,
          isRequired: true,
          onChanged: (v) => form.lastName = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Extension (Jr., III, etc.)',
          controller: _extName,
          onChanged: (v) => form.extensionName = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Phone Number',
          controller: _phone,
          isRequired: true,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          errorText: _phoneError,
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Email Address (optional)',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
          errorText: _emailError,
        ),
        if (_emailChecking)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Checking email...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _addressInfo() {
    const bhcBarangays = [
      'San Jose',
      'Tarcan',
      'Sta. Barbara',
      'Tiaong',
      'Pinagbarilan',
    ];
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
          child: Row(
            children: [
              const Icon(
                Icons.home_work_outlined,
                color: AppColors.brandAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assigned BHC: ${form.context.assignedBhcName ?? 'Loading...'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RadioListTile<bool>(
          title: const Text('Use assigned BHC address'),
          subtitle: const Text('Bulacan · Baliwag · Assigned barangay'),
          value: true,
          groupValue: form.addressSameAsBhc,
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              form.addressSameAsBhc = v;
              _province.text = 'Bulacan';
              _city.text = 'Baliwag';
              _barangay.text = form.context.assignedBhcName ?? '';
              form.province = _province.text;
              form.city = _city.text;
              form.barangay = _barangay.text;
            });
          },
        ),
        RadioListTile<bool>(
          title: const Text('Use custom address'),
          subtitle: const Text('Enter a different barangay/city/province'),
          value: false,
          groupValue: form.addressSameAsBhc,
          onChanged: (v) => setState(() => form.addressSameAsBhc = v ?? false),
        ),
        const SizedBox(height: 8),
        AppInputField(
          hintText: 'House Number',
          controller: _houseNumber,
          onChanged: (v) => form.houseNumber = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Street',
          controller: _street,
          onChanged: (v) => form.street = v.trim(),
        ),
        const SizedBox(height: 12),
        if (form.addressSameAsBhc)
          AppInputField(
            hintText: 'Barangay',
            controller: _barangay,
            readOnly: true,
            onChanged: (_) {},
          )
        else
          DropdownButtonFormField<String>(
            value: _barangay.text.isEmpty ? null : _barangay.text,
            decoration: const InputDecoration(labelText: 'Barangay'),
            items: bhcBarangays
                .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              _barangay.text = v ?? '';
              form.barangay = v;
            },
          ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'City / Municipality',
          controller: _city,
          readOnly: form.addressSameAsBhc,
          onChanged: (v) => form.city = v.trim(),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Province',
          controller: _province,
          readOnly: form.addressSameAsBhc,
          onChanged: (v) => form.province = v.trim(),
        ),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _emergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Emergency Contacts (optional)',
          actionLabel: 'Add Contact',
          onAction: _addEmergencyContact,
        ),
        const SizedBox(height: 8),
        if (form.emergencyContacts.isEmpty)
          const Text('No emergency contacts added. You can skip this.'),
        ...form.emergencyContacts.asMap().entries.map((entry) {
          final idx = entry.key;
          final ec = entry.value;
          return Card(
            child: ListTile(
              title: Text('${ec.firstName ?? ''} ${ec.lastName ?? ''}'.trim()),
              subtitle: Text(ec.phoneNumber ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => form.emergencyContacts.removeAt(idx));
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _vitalStats() {
    const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInputField(
          hintText: 'Birthdate',
          controller: _birthDateCtrl,
          isRequired: true,
          leadingIcon: Icons.calendar_today,
          readOnly: true,
          onTap: () => _pickDate(
            initialDate: form.birthdate ?? DateTime(1990, 1, 1),
            onSelected: (d) {
              setState(() {
                form.birthdate = d;
                _birthDateCtrl.text = dateFmt.format(d);
              });
            },
            lastDate: DateTime.now(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Age: ${form.ageYears != null ? '${form.ageYears} years old' : '—'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Height (cm)',
          controller: _height,
          isRequired: true,
          keyboardType: TextInputType.number,
          onChanged: (v) {
            form.heightCm = double.tryParse(v);
            _recomputeRisk();
          },
        ),
        const SizedBox(height: 12),
        AppInputField(
          hintText: 'Weight (kg)',
          controller: _weight,
          isRequired: true,
          keyboardType: TextInputType.number,
          onChanged: (v) {
            form.weightKg = double.tryParse(v);
            _recomputeRisk();
          },
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Blood Type',
          value: form.bloodType,
          items: bloodTypes,
          onChanged: (v) => setState(() => form.bloodType = v),
        ),
        const SizedBox(height: 12),
        Text(
          'Derived BMI: ${form.bmi?.toStringAsFixed(1) ?? '—'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _medicalConditions() {
    const options = [
      'Anemia',
      'Diabetes',
      'Domestic Violence',
      'Bleeding Postpartum',
      'Smoking',
      'Prolonged Labor',
      'Alcohol',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipSelector(
          label: 'Select / add conditions',
          options: options,
          onTap: (label) => _addMedicalCondition(prefill: label),
        ),
        const SizedBox(height: 12),
        if (form.medicalConditions.isEmpty)
          const Text('No medical conditions added.'),
        ...form.medicalConditions.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          return Card(
            child: ListTile(
              title: Text('${m.conditionName} (${m.status})'),
              subtitle: Text(
                [
                  m.diagnosisDate != null
                      ? 'Diagnosed: ${dateFmt.format(m.diagnosisDate!)}'
                      : null,
                  m.remarks,
                ].whereType<String>().join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    form.medicalConditions.removeAt(idx);
                    _recomputeRisk();
                  });
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _allergies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _listHeader(
          title: 'Allergies',
          actionLabel: 'Add Allergy',
          onAction: _addAllergy,
        ),
        const SizedBox(height: 8),
        if (form.allergies.isEmpty) const Text('No allergies recorded.'),
        ...form.allergies.asMap().entries.map((entry) {
          final idx = entry.key;
          final a = entry.value;
          return Card(
            child: ListTile(
              title: Text('${a.allergen} (${a.status})'),
              subtitle: Text(
                [
                  a.diagnosisDate != null
                      ? 'Diagnosed: ${dateFmt.format(a.diagnosisDate!)}'
                      : null,
                  a.treatment,
                ].whereType<String>().join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    form.allergies.removeAt(idx);
                    _recomputeRisk();
                  });
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _pregnancyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Any past pregnancies?'),
          value: form.hasPastPregnancy,
          onChanged: (v) => setState(() {
            form.hasPastPregnancy = v;
            if (!v) form.pregnancyHistory.clear();
            _recomputeRisk();
          }),
        ),
        if (form.hasPastPregnancy) ...[
          _listHeader(
            title: 'Past Pregnancies',
            actionLabel: 'Add Pregnancy',
            onAction: _addPregnancyHistory,
          ),
          const SizedBox(height: 8),
          if (form.pregnancyHistory.isEmpty)
            const Text('Add at least one record or toggle off if none.'),
          ...form.pregnancyHistory.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Card(
              child: ListTile(
                title: Text(
                  '${_outcomeLabel(p.outcome)} on ${dateFmt.format(p.outcomeDate)}',
                ),
                subtitle: Text(
                  [
                    p.placeOfDelivery,
                    p.deliveryMethod,
                    p.gestationalAgeAtEnd != null
                        ? 'GA: ${p.gestationalAgeAtEnd} wks'
                        : null,
                  ].whereType<String>().join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      form.pregnancyHistory.removeAt(idx);
                      _recomputeRisk();
                    });
                  },
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 20),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  String _outcomeLabel(String outcome) {
    switch (outcome) {
      case 'live_birth':
        return 'Live Birth';
      case 'stillbirth':
        return 'Stillbirth';
      case 'miscarriage':
        return 'Miscarriage';
      case 'abortion':
        return 'Abortion';
      case 'ectopic':
        return 'Ectopic';
      default:
        return outcome;
    }
  }

  Widget _gestationalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<GestationMethod>(
          value: _gestationMethod,
          decoration: const InputDecoration(labelText: 'Calculation method'),
          items: const [
            DropdownMenuItem(
              value: GestationMethod.lmp,
              child: Text('Last Menstrual Period (LMP)'),
            ),
            DropdownMenuItem(
              value: GestationMethod.edd,
              child: Text('Estimated Delivery Date (EDD)'),
            ),
            DropdownMenuItem(
              value: GestationMethod.aog,
              child: Text('Age of Gestation (AOG)'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _gestationMethod = v;
              form.lmp = null;
              form.edd = null;
              _gestationLmp.clear();
              _gestationEdd.clear();
              _aogWeeks.clear();
              _aogDays.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        if (_gestationMethod == GestationMethod.lmp)
          AppInputField(
            hintText: 'Select LMP',
            controller: _gestationLmp,
            readOnly: true,
            leadingIcon: Icons.calendar_today,
            onTap: () => _pickDate(
              initialDate: form.lmp ?? DateTime.now(),
              lastDate: DateTime.now(),
              onSelected: (d) {
                setState(() {
                  _updateDerivedFromLmp(d);
                });
              },
            ),
          )
        else if (_gestationMethod == GestationMethod.edd)
          AppInputField(
            hintText: 'Select EDD',
            controller: _gestationEdd,
            readOnly: true,
            leadingIcon: Icons.calendar_today,
            onTap: () => _pickDate(
              initialDate:
                  form.edd ?? DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              onSelected: (d) {
                setState(() {
                  _updateDerivedFromEdd(d);
                });
              },
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  hintText: 'Weeks',
                  controller: _aogWeeks,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_updateDerivedFromAog),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  hintText: 'Days',
                  controller: _aogDays,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_updateDerivedFromAog),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _infoRow('LMP', _gestationLmp.text.isEmpty ? '—' : _gestationLmp.text),
        _infoRow('EDD', _gestationEdd.text.isEmpty ? '—' : _gestationEdd.text),
        _infoRow('AOG', _formatAogFromLmp()),
        const SizedBox(height: 20),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(),
      ],
    );
  }

  Widget _summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review all details below. Saving will create the mother record, then you can proceed to a prenatal checkup or view the profile.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _summaryTile(
          'Name',
          '${form.firstName ?? ''} ${form.lastName ?? ''}'.trim(),
        ),
        _summaryTile('Phone', form.phone ?? '—'),
        _summaryTile(
          'Address',
          [
                form.houseNumber,
                form.street,
                form.barangay ?? form.context.assignedBhcName,
                form.city ?? 'Baliwag',
                form.province ?? 'Bulacan',
              ]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .join(', '),
        ),
        _summaryTile(
          'Birthdate',
          form.birthdate != null ? dateFmt.format(form.birthdate!) : '—',
        ),
        _summaryTile(
          'Height/Weight',
          '${form.heightCm?.toStringAsFixed(1) ?? '—'} cm / ${form.weightKg?.toStringAsFixed(1) ?? '—'} kg',
        ),
        _summaryTile('Blood Type', form.bloodType ?? '—'),
        _summaryTile('LMP', form.lmp != null ? dateFmt.format(form.lmp!) : '—'),
        _summaryTile('EDD', form.edd != null ? dateFmt.format(form.edd!) : '—'),
        _summaryTile('AOG', _formatAogFromLmp()),
        const SizedBox(height: 12),
        _riskPanel(),
        const SizedBox(height: 20),
        _scaffoldControls(showSubmit: true),
      ],
    );
  }

  Widget _riskPanel() {
    return RiskPanel(assessment: risk, collapsible: true);
  }

  Widget _summaryTile(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(flex: 3, child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  Widget _listHeader({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandText,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
          style: TextButton.styleFrom(foregroundColor: AppColors.brandAccent),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.transparent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: items
                  .map(
                    (b) => DropdownMenuItem<String>(value: b, child: Text(b)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Text('$label: $value'),
          ),
        ],
      ),
    );
  }

  Widget _chipSelector({
    required String label,
    required List<String> options,
    required ValueChanged<String> onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (o) => ChoiceChip(
                  label: Text(o),
                  selected: false,
                  onSelected: (_) => onTap(o),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ===== MODALS =====
  Future<void> _addEmergencyContact() async {
    final ec = EmergencyContact();
    final first = TextEditingController();
    final middle = TextEditingController();
    final last = TextEditingController();
    final ext = TextEditingController();
    final phone = TextEditingController();
    final affiliation = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final isValid =
              first.text.trim().isNotEmpty &&
              last.text.trim().isNotEmpty &&
              phone.text.trim().isNotEmpty;
          return AlertDialog(
            title: Row(
              children: [
                const Text('Add Emergency Contact'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: first,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  TextField(
                    controller: middle,
                    decoration: const InputDecoration(labelText: 'Middle Name'),
                  ),
                  TextField(
                    controller: last,
                    decoration: const InputDecoration(labelText: 'Last Name *'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  TextField(
                    controller: ext,
                    decoration: const InputDecoration(
                      labelText: 'Extension (Jr., III, etc.)',
                    ),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  TextField(
                    controller: affiliation,
                    decoration: const InputDecoration(
                      labelText: 'Affiliation / Relationship',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(context, true) : null,
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      ec.firstName = first.text.trim();
      ec.middleName = middle.text.trim().isEmpty ? null : middle.text.trim();
      ec.lastName = last.text.trim();
      ec.extensionName = ext.text.trim().isEmpty ? null : ext.text.trim();
      ec.phoneNumber = phone.text.trim();
      ec.affiliation = affiliation.text.trim().isEmpty
          ? null
          : affiliation.text.trim();

      if (ec.isValid) {
        setState(() => form.emergencyContacts.add(ec));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('First name, last name, and phone are required.'),
          ),
        );
      }
    }
  }

  Future<void> _addMedicalCondition({String? prefill}) async {
    final name = TextEditingController(text: prefill ?? '');
    DateTime? diagDate;
    String status = 'active';
    final remarks = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final isValid = name.text.trim().isNotEmpty && diagDate != null;
          return AlertDialog(
            title: Row(
              children: [
                const Text('Medical Condition'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Condition *'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      diagDate == null
                          ? 'Diagnosis Date *'
                          : 'Diagnosis: ${dateFmt.format(diagDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: diagDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => diagDate = picked);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => status = v ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  TextField(
                    controller: remarks,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(context, true) : null,
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && name.text.trim().isNotEmpty) {
      final entry = MedicalConditionEntry(conditionName: name.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..remarks = remarks.text.trim().isEmpty ? null : remarks.text.trim();
      setState(() {
        form.medicalConditions.add(entry);
        _recomputeRisk();
      });
    }
  }

  Future<void> _addAllergy() async {
    final allergen = TextEditingController();
    DateTime? diagDate;
    String status = 'active';
    final treatment = TextEditingController();
    final remarks = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final isValid = allergen.text.trim().isNotEmpty;
          return AlertDialog(
            title: Row(
              children: [
                const Text('Add Allergy'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: allergen,
                    decoration: const InputDecoration(labelText: 'Allergen *'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      diagDate == null
                          ? 'Diagnosis Date'
                          : 'Diagnosis: ${dateFmt.format(diagDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: diagDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null)
                        setModalState(() => diagDate = picked);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => status = v ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  TextField(
                    controller: treatment,
                    decoration: const InputDecoration(labelText: 'Treatment'),
                  ),
                  TextField(
                    controller: remarks,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(context, true) : null,
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && allergen.text.trim().isNotEmpty) {
      final entry = AllergyEntry(allergen: allergen.text.trim())
        ..diagnosisDate = diagDate
        ..status = status
        ..treatment = treatment.text.trim().isEmpty
            ? null
            : treatment.text.trim()
        ..remarks = remarks.text.trim().isEmpty ? null : remarks.text.trim();
      setState(() {
        form.allergies.add(entry);
        _recomputeRisk();
      });
    }
  }

  Future<void> _addPregnancyHistory() async {
    String outcome = 'live_birth';
    DateTime? outcomeDate;
    bool isEstimated = false;
    final gaController = TextEditingController();
    final placeCtrl = TextEditingController();
    String? deliveryMethod;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final needsDeliveryDetails =
              outcome == 'live_birth' || outcome == 'stillbirth';
          final isValid =
              outcomeDate != null &&
              (!needsDeliveryDetails ||
                  (placeCtrl.text.trim().isNotEmpty &&
                      (deliveryMethod ?? '').trim().isNotEmpty));

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Past Pregnancy',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: outcome,
                    items: const [
                      DropdownMenuItem(
                        value: 'live_birth',
                        child: Text('Live Birth'),
                      ),
                      DropdownMenuItem(
                        value: 'stillbirth',
                        child: Text('Stillbirth'),
                      ),
                      DropdownMenuItem(
                        value: 'miscarriage',
                        child: Text('Miscarriage'),
                      ),
                      DropdownMenuItem(
                        value: 'abortion',
                        child: Text('Abortion'),
                      ),
                      DropdownMenuItem(
                        value: 'ectopic',
                        child: Text('Ectopic'),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => outcome = v ?? 'live_birth'),
                    decoration: const InputDecoration(labelText: 'Outcome'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      outcomeDate == null
                          ? 'Outcome Date *'
                          : 'Outcome: ${dateFmt.format(outcomeDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: outcomeDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => outcomeDate = picked);
                      }
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isEstimated,
                    onChanged: (v) =>
                        setModalState(() => isEstimated = v ?? false),
                    title: const Text('Outcome date is estimated'),
                  ),
                  TextField(
                    controller: gaController,
                    decoration: const InputDecoration(
                      labelText: 'Gestational age at end (weeks, optional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (needsDeliveryDetails) ...[
                    TextField(
                      controller: placeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Place of delivery *',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    DropdownButtonFormField<String>(
                      value: deliveryMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Delivery method *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Normal Spontaneous Vaginal Delivery',
                          child: Text(
                            'Normal Spontaneous Vaginal Delivery',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Cesarean Section',
                          child: Text(
                            'Cesarean Section',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Assisted Vaginal Delivery',
                          child: Text(
                            'Assisted Vaginal Delivery',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setModalState(() {
                        deliveryMethod = v;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(context, true) : null,
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && outcomeDate != null) {
      final entry =
          PregnancyHistoryEntry(outcome: outcome, outcomeDate: outcomeDate!)
            ..isOutcomeDateEstimated = isEstimated
            ..gestationalAgeAtEnd = double.tryParse(gaController.text.trim())
            ..placeOfDelivery = placeCtrl.text.trim().isEmpty
                ? null
                : placeCtrl.text.trim()
            ..deliveryMethod = deliveryMethod?.trim().isEmpty ?? true
                ? null
                : deliveryMethod?.trim();
      setState(() {
        form.pregnancyHistory.add(entry);
        _recomputeRisk();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingContext) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Add Mother – Step ${step + 1} of $totalSteps'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStepContent(),
          ],
        ),
      ),
    );
  }
}
