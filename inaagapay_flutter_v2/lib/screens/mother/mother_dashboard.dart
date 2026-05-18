// lib/screens/mother/mother_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/headline.dart';
import '../../widgets/small_description.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/small_info_box.dart';
import '../../widgets/long_info_box.dart';
import '../../widgets/comparison_card.dart';
import '../../widgets/main_button.dart';
import '../../widgets/secondary_button.dart';
import '../../models/baby_growth_model.dart';
import '../../services/auth_storage.dart';
import '../../services/language_service.dart';
import '../../services/mother_profile_service.dart';
import '../../services/supabase_service.dart';
import 'mother_pregnancy_detail_page.dart';

class MotherDashboard extends StatefulWidget {
  const MotherDashboard({super.key});

  @override
  State<MotherDashboard> createState() => _MotherDashboardState();
}

class _MotherDashboardState extends State<MotherDashboard> {
  bool _isLoading = true;
  String? _errorMessage;

  // Dashboard data
  int _week = 0;
  int _weeksLeft = 0;
  String _trimester = '—';
  String _dueDate = '—';
  String _firstName = '';
  bool _hasPregnancy = false;
  int _pregnancyId = 0;
  String _babySize = '—';
  String _babyWeight = '—';
  String _riskLevel = 'low';
  int _fetalCount = 1;
  DateTime? _lmpDate;
  List<String>? _riskFactors;
  List<String>? _suggestedActions;

  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is num) return value.toInt();
    return fallback;
  }

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  String _localizedTrimester() {
    switch (_trimester) {
      case 'First Trimester':
        return _t('First Trimester', 'Unang Trimester');
      case 'Second Trimester':
        return _t('Second Trimester', 'Ikalawang Trimester');
      case 'Third Trimester':
        return _t('Third Trimester', 'Ikatlong Trimester');
      default:
        return _trimester;
    }
  }

  void _resetPregnancyData() {
    _week = 0;
    _weeksLeft = 0;
    _trimester = '—';
    _dueDate = '—';
    _hasPregnancy = false;
    _pregnancyId = 0;
    _babySize = '—';
    _babyWeight = '—';
    _riskLevel = 'low';
    _fetalCount = 1;
    _lmpDate = null;
    _riskFactors = null;
    _suggestedActions = null;
  }

  bool _requiresDeliveryDetails(String outcome) {
    return outcome == 'live_birth' || outcome == 'stillbirth';
  }

  String _dateIso(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resetPregnancyData();
    });

    try {
      final motherId = await AuthStorage.getMotherId();
      debugPrint('=== DASHBOARD DEBUG ===');
      debugPrint('Mother ID: $motherId');

      if (motherId == null) {
        throw Exception(
            'Mother ID not found. Please log out and log in again.');
      }

      // Get account info for name
      final accountId = await AuthStorage.getUserId();
      debugPrint('Account ID: $accountId');

      if (accountId != null) {
        final accountResponse = await SupabaseService.client
            .from('accounts')
            .select('first_name, last_name')
            .eq('account_id', accountId)
            .maybeSingle();

        debugPrint('Account response: $accountResponse');

        if (accountResponse != null) {
          final firstName = accountResponse['first_name']?.toString() ?? '';
          final lastName = accountResponse['last_name']?.toString() ?? '';
          _firstName = '$firstName $lastName'.trim();
          if (_firstName.isEmpty) _firstName = firstName;
        }
      }

      // Get current pregnancy data
      final List<dynamic> pregnancyResponse = await SupabaseService.client
          .from('pregnancies')
          .select('*')
          .eq('mother_id', motherId)
          .eq('status', 'ongoing');

      debugPrint('Pregnancy response: $pregnancyResponse');

      if (pregnancyResponse.isNotEmpty) {
        final Map<String, dynamic> pregnancy =
            pregnancyResponse.first as Map<String, dynamic>;
        _hasPregnancy = true;
        _pregnancyId = _parseInt(pregnancy['pregnancy_id']);

        final String? lmpStr = pregnancy['last_menstrual_period'] as String?;
        final String? eddStr =
            pregnancy['expected_date_of_delivery'] as String?;

        if (lmpStr != null && lmpStr.isNotEmpty) {
          final DateTime lmp = DateTime.parse(lmpStr);
          _lmpDate = lmp;
          final DateTime now = DateTime.now();
          _week = now.difference(lmp).inDays ~/ 7;
          if (_week < 1) _week = 1;
          if (_week > 40) _week = 40;

          final babyGrowth = BabyGrowthData.getForWeek(_week);
          _babySize = babyGrowth.size;
          _babyWeight = babyGrowth.weight;

          _riskLevel = (pregnancy['pregnancy_risk_level'] as String? ?? 'Low')
              .toLowerCase();
          _fetalCount = _parseInt(pregnancy['fetal_count'], 1);

          DateTime edd;
          if (eddStr != null && eddStr.isNotEmpty) {
            edd = DateTime.parse(eddStr);
          } else {
            edd = lmp.add(const Duration(days: 280));
          }

          _dueDate = DateFormat('MMMM d, yyyy').format(edd);

          final int daysLeft = edd.difference(now).inDays;
          _weeksLeft = daysLeft > 0 ? daysLeft ~/ 7 : 0;

          if (_week <= 13) {
            _trimester = 'First Trimester';
          } else if (_week <= 27) {
            _trimester = 'Second Trimester';
          } else {
            _trimester = 'Third Trimester';
          }

          // Fetch risk factors and suggested actions for the detail page
          await _loadRiskData();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadRiskData() async {
    try {
      // Fetch latest risk assessment
      final riskData = await SupabaseService.client
          .from('pregnancy_risk_assessments')
          .select('pregnancy_risk_id')
          .eq('pregnancy_id', _pregnancyId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (riskData != null) {
        final riskId = riskData['pregnancy_risk_id'];

        // Fetch risk factors
        final List<dynamic> factorsData = await SupabaseService.client
            .from('pregnancy_risk_factors')
            .select('factor')
            .eq('pregnancy_risk_id', riskId);

        if (factorsData.isNotEmpty) {
          _riskFactors = factorsData.map((f) => f['factor'] as String).toList();
        }

        // Fetch AI recommendations
        final aiData = await SupabaseService.client
            .from('ai_responses')
            .select('response')
            .eq('reference_table', 'pregnancies')
            .eq('reference_id', _pregnancyId)
            .eq('response_type', 'recommendation')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (aiData != null && aiData['response'] is String) {
          final response = aiData['response'] as String;
          _suggestedActions = response
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) =>
                  line.replaceAll(RegExp(r'^[\d\-\.\*]+\s*'), '').trim())
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading risk data: $e');
      // Non-critical - don't fail the whole dashboard
    }
  }

  Future<void> _showConcludePregnancyDialog() async {
    if (!_hasPregnancy || _pregnancyId == 0) {
      _showSnackBar(_t('No active pregnancy to conclude.',
          'Walang aktibong pagbubuntis na tatapusin.'));
      return;
    }

    final lmpDate = _lmpDate;
    if (lmpDate == null) {
      _showSnackBar(_t(
          'Cannot conclude pregnancy because the LMP is missing.',
          'Hindi matatapos ang pagbubuntis dahil nawawala ang LMP.'));
      return;
    }

    final today = DateTime.now();
    if (DateUtils.dateOnly(lmpDate).isAfter(DateUtils.dateOnly(today))) {
      _showSnackBar(_t(
          'Cannot conclude pregnancy because the LMP is in the future.',
          'Hindi matatapos ang pagbubuntis dahil nasa hinaharap ang LMP.'));
      return;
    }

    final fetalCount = _fetalCount < 1 ? 1 : _fetalCount;
    final outcomes = List<String>.filled(fetalCount, 'live_birth');
    final outcomeDates = List<DateTime>.filled(fetalCount, DateUtils.dateOnly(today));
    final deliveryDates =
        List<DateTime?>.filled(fetalCount, DateUtils.dateOnly(today));
    final deliveryMethods = List<String?>.filled(fetalCount, null);
    final placeControllers =
        List.generate(fetalCount, (_) => TextEditingController());
    var isSubmitting = false;

    double? computeGestAge() {
      final earliest = outcomeDates.reduce((a, b) => a.isBefore(b) ? a : b);
      final weeks = earliest.difference(lmpDate).inDays / 7;
      return weeks < 0 ? null : double.parse(weeks.toStringAsFixed(1));
    }

    String? validateForm() {
      final dateOnlyLmp = DateUtils.dateOnly(lmpDate);
      final dateOnlyToday = DateUtils.dateOnly(DateTime.now());

      for (int i = 0; i < fetalCount; i++) {
        final fetusLabel =
            fetalCount > 1 ? _t('Fetus ${i + 1}', 'Sanggol ${i + 1}') : _t('the pregnancy', 'ang pagbubuntis');
        final outcomeDate = DateUtils.dateOnly(outcomeDates[i]);

        if (outcomeDate.isBefore(dateOnlyLmp)) {
          return _t(
              'Outcome date for $fetusLabel cannot be before the LMP.',
              'Ang petsa ng kinalabasan para sa $fetusLabel ay hindi maaaring mauna sa LMP.');
        }

        if (outcomeDate.isAfter(dateOnlyToday)) {
          return _t(
              'Outcome date for $fetusLabel cannot be in the future.',
              'Ang petsa ng kinalabasan para sa $fetusLabel ay hindi maaaring nasa hinaharap.');
        }

        if (_requiresDeliveryDetails(outcomes[i])) {
          final place = placeControllers[i].text.trim();
          if (place.isEmpty) {
            return _t(
                'Please enter the place of delivery for $fetusLabel.',
                'Pakilagay ang lugar ng panganganak para sa $fetusLabel.');
          }

          if (deliveryMethods[i] == null) {
            return _t(
                'Please select the delivery method for $fetusLabel.',
                'Pakipili ang paraan ng panganganak para sa $fetusLabel.');
          }

          final deliveryDate = deliveryDates[i] ?? outcomeDates[i];
          final dateOnlyDelivery = DateUtils.dateOnly(deliveryDate);
          if (dateOnlyDelivery.isBefore(dateOnlyLmp)) {
            return _t(
                'Delivery date for $fetusLabel cannot be before the LMP.',
                'Ang petsa ng panganganak para sa $fetusLabel ay hindi maaaring mauna sa LMP.');
          }

          if (dateOnlyDelivery.isAfter(dateOnlyToday)) {
            return _t(
                'Delivery date for $fetusLabel cannot be in the future.',
                'Ang petsa ng panganganak para sa $fetusLabel ay hindi maaaring nasa hinaharap.');
          }
        }
      }

      if (computeGestAge() == null) {
        return _t(
            'Gestational age cannot be computed from the selected dates.',
            'Hindi makuwenta ang edad ng pagbubuntis mula sa napiling mga petsa.');
      }

      return null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final gestAge = computeGestAge();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                        top: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.flag,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _t('Conclude Pregnancy',
                                      'Tapusin ang Pagbubuntis'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed:
                                    isSubmitting ? null : () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          if (fetalCount > 1) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _t(
                                        'This pregnancy has $fetalCount fetuses. Please fill out the outcome for each.',
                                        'May $fetalCount sanggol ang pagbubuntis na ito. Pakilagay ang kinalabasan para sa bawat isa.',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          for (int i = 0; i < fetalCount; i++) ...[
                            if (fetalCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _t('Fetus ${i + 1} of $fetalCount',
                                        'Sanggol ${i + 1} sa $fetalCount'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: outcomes[i],
                                decoration: InputDecoration(
                                  labelText: _t('Outcome', 'Kinalabasan'),
                                  border: InputBorder.none,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'live_birth',
                                    child:
                                        Text(_t('Live Birth', 'Buhay na Sanggol')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'stillbirth',
                                    child: Text(_t('Stillbirth', 'Patay na Sanggol')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'miscarriage',
                                    child: Text(_t('Miscarriage', 'Pagkalaglag')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'abortion',
                                    child: Text(_t('Abortion', 'Aborsyon')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ectopic',
                                    child: Text(_t('Ectopic', 'Ectopic')),
                                  ),
                                ],
                                onChanged: isSubmitting
                                    ? null
                                    : (value) {
                                        setModal(() {
                                          outcomes[i] = value ?? outcomes[i];
                                          if (_requiresDeliveryDetails(
                                              outcomes[i])) {
                                            deliveryDates[i] = outcomeDates[i];
                                          } else {
                                            deliveryDates[i] = null;
                                            deliveryMethods[i] = null;
                                          }
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: outcomeDates[i],
                                        firstDate: DateUtils.dateOnly(lmpDate),
                                        lastDate: DateUtils.dateOnly(today),
                                      );
                                      if (picked != null) {
                                        setModal(() {
                                          outcomeDates[i] = picked;
                                          if (_requiresDeliveryDetails(
                                              outcomes[i])) {
                                            deliveryDates[i] = picked;
                                          }
                                        });
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _t('Outcome Date',
                                                'Petsa ng Kinalabasan'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMMM d, yyyy')
                                                .format(outcomeDates[i]),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_requiresDeliveryDetails(outcomes[i])) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: placeControllers[i],
                                enabled: !isSubmitting,
                                decoration: InputDecoration(
                                  labelText:
                                      _t('Place of Delivery', 'Lugar ng Panganganak'),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.bgSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: deliveryMethods[i],
                                  decoration: InputDecoration(
                                    labelText: _t(
                                        'Delivery Method', 'Paraan ng Panganganak'),
                                    border: InputBorder.none,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'NSD',
                                      child:
                                          Text(_t('Normal Spontaneous Delivery',
                                              'Normal na Panganganak')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CS',
                                      child:
                                          Text(_t('Cesarean Section', 'Cesarean Section')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Instrumental',
                                      child: Text(_t('Instrumental',
                                          'Instrumental')),
                                    ),
                                  ],
                                  onChanged: isSubmitting
                                      ? null
                                      : (value) => setModal(
                                            () => deliveryMethods[i] = value,
                                          ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (i < fetalCount - 1)
                              const Divider(
                                height: 24,
                                color: AppColors.borderPrimary,
                              ),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.borderPrimary),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('Gestational Age at End',
                                            'Edad ng Pagbubuntis sa Pagtatapos'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        gestAge != null
                                            ? '${gestAge.toStringAsFixed(1)} ${_t('weeks', 'linggo')}'
                                            : _t('Unable to compute',
                                                'Hindi makuwenta'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: gestAge != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _t(
                                  'Auto-computed from LMP and outcome date',
                                  'Awtomatikong kinuha mula sa LMP at petsa ng kinalabasan'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MainButton(
                            label: isSubmitting
                                ? _t('Concluding...', 'Tinatapos...')
                                : _t('Conclude Pregnancy',
                                    'Tapusin ang Pagbubuntis'),
                            showIcons: false,
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final validationMessage = validateForm();
                                    if (validationMessage != null) {
                                      _showSnackBar(validationMessage);
                                      return;
                                    }

                                    final gestAgeAtEnd = computeGestAge();
                                    final fetalOutcomes =
                                        <Map<String, dynamic>>[];
                                    for (int i = 0; i < fetalCount; i++) {
                                      fetalOutcomes.add({
                                        'fetus_number': i + 1,
                                        'outcome': outcomes[i],
                                        'outcome_date':
                                            _dateIso(outcomeDates[i]),
                                        'delivery_date':
                                            deliveryDates[i] == null
                                                ? null
                                                : _dateIso(deliveryDates[i]!),
                                        'place_of_delivery':
                                            placeControllers[i].text.trim(),
                                        'delivery_method': deliveryMethods[i],
                                      });
                                    }

                                    setModal(() => isSubmitting = true);
                                    final success =
                                        await MotherProfileService
                                            .concludePregnancy(
                                      _pregnancyId,
                                      gestAgeAtEnd,
                                      fetalOutcomes,
                                    );

                                    if (!mounted) return;
                                    if (success) {
                                      Navigator.pop(ctx);
                                      _showSnackBar(
                                          _t('Pregnancy concluded successfully.',
                                              'Matagumpay na natapos ang pagbubuntis.'));
                                      await _loadDashboardData();
                                    } else {
                                      setModal(() => isSubmitting = false);
                                      _showSnackBar(
                                          _t('Failed to conclude pregnancy.',
                                              'Hindi natapos ang pagbubuntis.'));
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    for (final controller in placeControllers) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: AppColors.brandPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Welcome Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Headline(
                                text:
                                    '${_t('Welcome', 'Maligayang pagdating')}, ${_firstName.isNotEmpty ? _firstName.split(' ').first : 'Nanay'}! 🌸',
                              ),
                              const SizedBox(height: 8),
                              SmallDescription(
                                icon: Icons.calendar_today,
                                text: _hasPregnancy && _week > 0
                                    ? '${_t('Week', 'Linggo')} $_week • ${_localizedTrimester()}'
                                    : _t('No active pregnancy',
                                        'Walang aktibong pagbubuntis'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        HeroCard(
                          image:
                              const AssetImage('assets/images/pregnant1.png'),
                          week: _hasPregnancy && _week > 0 ? _week : null,
                          showWeekBadge: _hasPregnancy && _week > 0,
                          showHeartRow: _hasPregnancy && _week > 0,
                        ),

                        const SizedBox(height: 20),

                        // Baby Growth Info
                        if (_hasPregnancy && _week > 0) ...[
                          Row(
                            children: [
                              Expanded(
                                child: SmallInfoBox(
                                  icon: Icons.straighten,
                                  title: _t(
                                      'Ideal Baby Size', 'Inaasahang Sukat ng Sanggol'),
                                  value: _babySize,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SmallInfoBox(
                                  icon: Icons.monitor_weight,
                                  title: _t('Ideal Baby Weight',
                                      'Inaasahang Timbang ng Sanggol'),
                                  value: _babyWeight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Due Date Info
                        LongInfoBox(
                          icon: Icons.calendar_month,
                          text: [
                            TextSpan(
                              text: '${_t('Due Date', 'Takdang Araw')}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: _hasPregnancy && _dueDate != '—'
                                  ? '$_dueDate\n'
                                  : '${_t('Not set', 'Hindi nakatakda')}\n',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            if (_hasPregnancy && _week > 0) ...[
                              TextSpan(
                                text: '${_t('You are', 'Ikaw ay')} ',
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                              TextSpan(
                                text:
                                    '$_weeksLeft ${_t('weeks away', 'linggo na lang')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              TextSpan(
                                text: _t(' from meeting!', ' bago magkita!'),
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            ] else if (!_hasPregnancy) ...[
                              TextSpan(
                                text: _t('No active pregnancy',
                                    'Walang aktibong pagbubuntis'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Comparison Card
                        if (_hasPregnancy && _week > 0)
                          ComparisonCard(week: _week),

                        const SizedBox(height: 24),

                        // Action Buttons
                        MainButton(
                          label: _t('More Info', 'Karagdagang Impormasyon'),
                          showIcons: true,
                          leftIcon: Icons.info_outline,
                          onPressed: () {
                            if (!_hasPregnancy ||
                                _week == 0 ||
                                _pregnancyId == 0) {
                              _showSnackBar(_t(
                                  'No active pregnancy to show details for.',
                                  'Walang aktibong pagbubuntis na maaaring tingnan.'));
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PregnancyDetailPage(
                                  week: _week,
                                  trimester: _trimester,
                                  dueDate: _dueDate,
                                  weeksLeft: _weeksLeft,
                                  babySize: _babySize,
                                  babyWeight: _babyWeight,
                                  firstName: _firstName,
                                  riskLevel: _riskLevel,
                                  fetalCount: _fetalCount,
                                  pregnancyId: _pregnancyId,
                                  riskFactors: _riskFactors,
                                  suggestedActions: _suggestedActions,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        SecondaryButton(
                          label: _t('Conclude Pregnancy',
                              'Tapusin ang Pagbubuntis'),
                          showIcons: true,
                          leadingIcon: Icons.check,
                          onPressed: _showConcludePregnancyDialog,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
              ),
              child: Text(_t('Retry', 'Subukan Muli')),
            ),
          ],
        ),
      ),
    );
  }
}
