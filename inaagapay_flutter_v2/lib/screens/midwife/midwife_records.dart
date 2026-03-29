// lib/screens/midwife/midwife_records.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import 'ultrasound_analyzer_screen.dart';
import 'lab_test_analyzer_screen.dart';
import '../../services/supabase_service.dart';

class MidwifeRecords extends StatefulWidget {
  const MidwifeRecords({super.key});

  @override
  State<MidwifeRecords> createState() => _MidwifeRecordsState();
}

class _MidwifeRecordsState extends State<MidwifeRecords> {
  List<Map<String, dynamic>> _mothers = [];
  bool _loadingMothers = true;

  @override
  void initState() {
    super.initState();
    _loadMothers();
  }

  Future<void> _loadMothers() async {
    setState(() {
      _loadingMothers = true;
    });

    try {
      final response = await SupabaseService.client
          .from('mothers')
          .select('''
            mother_id,
            account:account_id (
              first_name,
              last_name
            ),
            pregnancies!inner (
              pregnancy_id,
              status
            )
          ''')
          .eq('pregnancies.status', 'ongoing');

      final mothers = List<Map<String, dynamic>>.from(response);
      
      setState(() {
        _mothers = mothers;
        _loadingMothers = false;
      });
    } catch (e) {
      setState(() {
        _loadingMothers = false;
      });
      if (kDebugMode) {
        print('Error loading mothers: $e');
      }
    }
  }

  Future<void> _showMotherSelectionDialog({
    required Function(int motherId, int pregnancyId) onSelected,
  }) async {
    if (_mothers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No mothers with ongoing pregnancies found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Mother',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingMothers)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_mothers.isEmpty)
              const Center(
                child: Text('No mothers available'),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mothers.length,
                  itemBuilder: (context, index) {
                    final mother = _mothers[index];
                    final account = mother['account'] as Map<String, dynamic>?;
                    final firstName = account?['first_name'] as String? ?? '';
                    final lastName = account?['last_name'] as String? ?? '';
                    final name = '$firstName $lastName'.trim();
                    final displayName = name.isNotEmpty ? name : 'Mother ${mother['mother_id']}';
                    
                    final pregnancies = mother['pregnancies'] as List? ?? [];
                    final pregnancyId = pregnancies.isNotEmpty
                        ? pregnancies.first['pregnancy_id'] as int
                        : null;

                    if (pregnancyId == null) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text('Pregnancy ID: $pregnancyId'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(mother['mother_id'], pregnancyId);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Records',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage patient medical records',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandSecondary, AppColors.brandSecondary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Analysis Tools',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload patient images for AI-powered analysis',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAIToolCard(
                          context,
                          'Ultrasound Analysis',
                          Icons.photo,
                          Colors.purple,
                          () {
                            _showMotherSelectionDialog(
                              onSelected: (motherId, pregnancyId) {
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UltrasoundAnalyzerScreen(
                                      motherId: motherId,
                                      pregnancyId: pregnancyId,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAIToolCard(
                          context,
                          'Lab Test Analysis',
                          Icons.science,
                          Colors.orange,
                          () {
                            _showMotherSelectionDialog(
                              onSelected: (motherId, pregnancyId) {
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LabTestAnalyzerScreen(
                                      motherId: motherId,
                                      pregnancyId: pregnancyId,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('Recent Ultrasound Records', Icons.photo),
            const SizedBox(height: 15),
            _buildUltrasoundRecord(
              'Maria Santos',
              'May 15, 2026',
              '24 weeks',
              'Normal',
              Colors.green,
            ),
            const SizedBox(height: 10),
            _buildUltrasoundRecord(
              'Juana Dela Cruz',
              'May 10, 2026',
              '32 weeks',
              'Requires Monitoring',
              Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildUltrasoundRecord(
              'Ana Lopez',
              'May 5, 2026',
              '16 weeks',
              'Normal',
              Colors.green,
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('Recent Lab Test Records', Icons.science),
            const SizedBox(height: 15),
            _buildLabTestRecord(
              'Maria Santos',
              'CBC',
              'May 14, 2026',
              'All Normal',
              Colors.green,
            ),
            const SizedBox(height: 10),
            _buildLabTestRecord(
              'Juana Dela Cruz',
              'Blood Glucose',
              'May 12, 2026',
              'Borderline',
              Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildLabTestRecord(
              'Ana Lopez',
              'Urinalysis',
              'May 8, 2026',
              'Normal',
              Colors.green,
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('Pending Reviews', Icons.pending_actions),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '3 Records Need Review',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '2 ultrasounds, 1 lab test',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToolCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brandSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildUltrasoundRecord(String patient, String date, String weeks, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo, color: Colors.purple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      weeks,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabTestRecord(String patient, String test, String date, String result, Color resultColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.science, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      test,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result,
              style: TextStyle(
                fontSize: 12,
                color: resultColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}