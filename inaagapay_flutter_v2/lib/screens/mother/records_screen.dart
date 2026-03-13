// lib/screens/mother/records_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import 'mother_prenatal_stack.dart';
import 'mother_ultrasound_stack.dart';
import 'mother_lab_stack.dart';
import 'pregnancy_details.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, int> _recordCounts = {
    'prenatal': 0,
    'ultrasound': 0,
    'lab': 0,
    'pregnancies': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadRecordSummary();
  }

  Future<void> _loadRecordSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final motherId = await AuthStorage.getMotherId();
      if (motherId == null) throw Exception('Mother ID not found');

      // Ensure session is active
      await SupabaseService.ensureSession();

      // Get all pregnancies for this mother
      final pregnanciesResponse = await SupabaseService.client
          .from('pregnancies')
          .select('pregnancy_id')
          .eq('mother_id', motherId);

      final pregnancies = List<Map<String, dynamic>>.from(pregnanciesResponse);
      final pregnancyCount = pregnancies.length;

      int prenatalCount = 0;
      int ultrasoundCount = 0;
      int labCount = 0;

      // For each pregnancy, get counts of records
      for (var pregnancy in pregnancies) {
        final pregnancyId = pregnancy['pregnancy_id'];

        // Get prenatal checkups count
        final prenatalResponse = await SupabaseService.client
            .from('prenatal_checkups')
            .select('prenatal_checkup_id')
            .eq('pregnancy_id', pregnancyId);
        prenatalCount += prenatalResponse.length;

        // Get ultrasounds count
        final ultrasoundResponse = await SupabaseService.client
            .from('ultrasounds')
            .select('ultrasound_id')
            .eq('pregnancy_id', pregnancyId);
        ultrasoundCount += ultrasoundResponse.length;

        // Get lab tests count
        final labResponse = await SupabaseService.client
            .from('lab_tests')
            .select('lab_test_id')
            .eq('pregnancy_id', pregnancyId);
        labCount += labResponse.length;
      }

      setState(() {
        _recordCounts = {
          'prenatal': prenatalCount,
          'ultrasound': ultrasoundCount,
          'lab': labCount,
          'pregnancies': pregnancyCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalRecords {
    return _recordCounts['prenatal']! +
        _recordCounts['ultrasound']! +
        _recordCounts['lab']! +
        _recordCounts['pregnancies']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brandPrimary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error Loading Records',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRecordSummary,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🎀 HERO / SUMMARY
          Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: const DecorationImage(
                image: AssetImage('assets/images/pinkbg.png'),
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'You have\n',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          TextSpan(
                            text: '$_totalRecords Stored Records!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/records.png',
                    height: 72,
                    width: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Icon(
                        Icons.folder,
                        color: AppColors.brandPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'All your pregnancy records in one place',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          _RecordCategoryCard(
            title: 'Prenatal Check-ups',
            countText: '${_recordCounts['prenatal']} file(s)',
            icon: Icons.medical_services_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MotherPrenatalStack(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _RecordCategoryCard(
            title: 'Ultrasound Records',
            countText: '${_recordCounts['ultrasound']} file(s)',
            icon: Icons.monitor_heart_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MotherUltrasoundStack(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _RecordCategoryCard(
            title: 'Laboratory Test Results',
            countText: '${_recordCounts['lab']} file(s)',
            icon: Icons.science_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MotherLabStack(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _RecordCategoryCard(
            title: 'Pregnancy History',
            countText: '${_recordCounts['pregnancies']} record(s)',
            icon: Icons.history_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PregnancyDetailsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecordCategoryCard extends StatefulWidget {
  final String title;
  final String countText;
  final IconData icon;
  final VoidCallback onTap;

  const _RecordCategoryCard({
    required this.title,
    required this.countText,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_RecordCategoryCard> createState() => _RecordCategoryCardState();
}

class _RecordCategoryCardState extends State<_RecordCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          onHighlightChanged: (isPressed) {
            setState(() => _pressed = isPressed);
          },
          splashColor: AppColors.brandPrimary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: AppColors.brandPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.countText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}