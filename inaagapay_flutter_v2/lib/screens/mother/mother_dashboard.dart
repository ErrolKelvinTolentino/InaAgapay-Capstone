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
  List<String>? _riskFactors;
  List<String>? _suggestedActions;

  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is num) return value.toInt();
    return fallback;
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

  @override
  Widget build(BuildContext context) {
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
                                    'Welcome, ${_firstName.isNotEmpty ? _firstName.split(' ').first : 'Nanay'}! 🌸',
                              ),
                              const SizedBox(height: 8),
                              SmallDescription(
                                icon: Icons.calendar_today,
                                text: _hasPregnancy && _week > 0
                                    ? 'Week $_week • $_trimester'
                                    : 'No active pregnancy',
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
                                  title: 'Ideal Baby Size',
                                  value: _babySize,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SmallInfoBox(
                                  icon: Icons.monitor_weight,
                                  title: 'Ideal Baby Weight',
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
                            const TextSpan(
                              text: 'Due Date: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: _hasPregnancy && _dueDate != '—'
                                  ? '$_dueDate\n'
                                  : 'Not set\n',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            if (_hasPregnancy && _week > 0) ...[
                              const TextSpan(
                                text: 'You are ',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                              TextSpan(
                                text: '$_weeksLeft weeks away',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              const TextSpan(
                                text: ' from meeting!',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                            ] else if (!_hasPregnancy) ...[
                              const TextSpan(
                                text: 'No active pregnancy',
                                style: TextStyle(
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
                          label: 'More Info',
                          showIcons: true,
                          leftIcon: Icons.info_outline,
                          onPressed: () {
                            if (!_hasPregnancy ||
                                _week == 0 ||
                                _pregnancyId == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'No active pregnancy to show details for.'),
                                ),
                              );
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
                          label: 'Conclude Pregnancy',
                          showIcons: true,
                          leadingIcon: Icons.check,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Conclude pregnancy coming soon!')),
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
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
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
