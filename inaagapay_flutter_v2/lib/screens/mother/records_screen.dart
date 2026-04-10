// lib/screens/mother/records_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../widgets/full_screen_image_viewer.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int? _motherId;
  
  List<Map<String, dynamic>> _ultrasounds = [];
  List<Map<String, dynamic>> _labTests = [];
  List<Map<String, dynamic>> _prenatalCheckups = [];
  
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMotherData();
  }

  Future<void> _loadMotherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _motherId = await AuthStorage.getMotherId();
      
      if (_motherId == null) {
        throw Exception('Mother ID not found');
      }

      final pregnanciesResponse = await SupabaseService.client
          .from('pregnancies')
          .select('pregnancy_id')
          .eq('mother_id', _motherId!);

      if (pregnanciesResponse.isEmpty) {
        setState(() {
          _ultrasounds = [];
          _labTests = [];
          _prenatalCheckups = [];
          _isLoading = false;
        });
        return;
      }
      
      final pregnancyIds = pregnanciesResponse.map<int>((p) => p['pregnancy_id'] as int).toList();
      
      final ultrasoundsResponse = await SupabaseService.client
          .from('ultrasounds')
          .select('*')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('ultrasound_date', ascending: false);

      final labTestsResponse = await SupabaseService.client
          .from('lab_tests')
          .select('*')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('lab_test_date', ascending: false);

      final prenatalResponse = await SupabaseService.client
          .from('prenatal_checkups')
          .select('''
            *,
            pregnancy:pregnancy_id (
              mother_id
            )
          ''')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('checkup_datetime', ascending: false);

      setState(() {
        _ultrasounds = List<Map<String, dynamic>>.from(ultrasoundsResponse);
        _labTests = List<Map<String, dynamic>>.from(labTestsResponse);
        _prenatalCheckups = List<Map<String, dynamic>>.from(prenatalResponse);
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return date.toString();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '—';
    try {
      final parsed = DateTime.tryParse(dateTime.toString());
      if (parsed == null) return dateTime.toString();
      return DateFormat('MMM d, yyyy h:mm a').format(parsed);
    } catch (e) {
      return dateTime.toString();
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    final str = value.toString().trim();
    return str.isEmpty ? '—' : str;
  }

  List<String> _parseImageUrls(dynamic imageField) {
    List<String> urls = [];
    if (imageField != null) {
      final imageString = imageField.toString();
      if (imageString.contains(',')) {
        urls = imageString.split(',').map((url) => url.trim()).toList();
      } else if (imageString.isNotEmpty) {
        urls = [imageString];
      }
    }
    return urls;
  }

  void _showFullScreenImage(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showRecordDetails({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    List<String>? imageUrls,
    String? aiAnalysis,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: AppColors.brandPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (imageUrls != null && imageUrls.isNotEmpty) ...[
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(imageUrls, index),
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.bgSecondary,
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Image not available',
                                                  style: TextStyle(fontSize: 10),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: AppColors.bgSecondary,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (imageUrls.length > 1 && index == 0)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '+${imageUrls.length - 1} more',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Column(
                        children: rows.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),

                    if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF7E57C2).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology_rounded, color: const Color(0xFF7E57C2), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI-Powered Insights',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5E35B1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              aiAnalysis,
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Note: This is AI-generated analysis for informational purposes only.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generatePrenatalAIInsights(Map<String, dynamic> checkup) {
    final buffer = StringBuffer();
    buffer.write('Prenatal Checkup AI Insights:\n\n');
    
    final bpSys = checkup['blood_pressure_systolic'];
    final bpDia = checkup['blood_pressure_diastolic'];
    final weight = checkup['checkup_weight'];
    final fhr = checkup['fetal_heart_beat'];
    final remarks = checkup['remarks']?.toString().toLowerCase() ?? '';
    
    if (bpSys != null && bpDia != null) {
      if (bpSys >= 140 || bpDia >= 90) {
        buffer.write('⚠️ Blood Pressure: $bpSys/$bpDia mmHg is elevated. Monitor for preeclampsia symptoms.\n\n');
      } else if (bpSys < 90 || bpDia < 60) {
        buffer.write('📉 Blood Pressure: $bpSys/$bpDia mmHg is lower than expected. Ensure adequate hydration.\n\n');
      } else {
        buffer.write('✓ Blood Pressure: $bpSys/$bpDia mmHg is within normal range.\n\n');
      }
    }
    
    if (weight != null) {
      buffer.write('⚖️ Weight: ${weight.toStringAsFixed(1)} kg\n\n');
    }
    
    if (fhr != null) {
      if (fhr >= 120 && fhr <= 160) {
        buffer.write('💓 Fetal Heart Rate: $fhr bpm (Normal range)\n\n');
      } else {
        buffer.write('⚠️ Fetal Heart Rate: $fhr bpm (Outside normal range - needs review)\n\n');
      }
    }
    
    if (remarks.isNotEmpty && !remarks.contains('normal')) {
      buffer.write('📝 Remarks: $remarks\n\n');
    }
    
    buffer.write('Recommendations:\n');
    buffer.write('• Continue regular prenatal checkups\n');
    buffer.write('• Monitor fetal movements daily\n');
    buffer.write('• Report any unusual symptoms to your healthcare provider\n');
    
    return buffer.toString();
  }

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final buffer = StringBuffer();
    
    buffer.write('Ultrasound AI Insights:\n\n');
    
    if (remarks.contains('normal') || remarks.contains('healthy')) {
      buffer.write('✓ Normal Findings: Ultrasound appears normal with healthy fetal development.\n\n');
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      buffer.write('📊 Follow-up Recommended: Some findings require additional observation.\n\n');
    } else if (remarks.contains('concern') || remarks.contains('abnormal')) {
      buffer.write('🔍 Further Evaluation Needed: Discuss findings with healthcare provider.\n\n');
    } else {
      buffer.write('📋 Diagnostic Information: The ultrasound provides important diagnostic information.\n\n');
    }

    buffer.write('Key Recommendations:\n');
    buffer.write('• Discuss findings with your healthcare provider\n');
    buffer.write('• Continue all scheduled prenatal appointments\n');

    return buffer.toString();
  }

  String _generateLabTestAIInsights(Map<String, dynamic> labTest) {
    final remarks = labTest['remarks']?.toString().toLowerCase() ?? '';
    final buffer = StringBuffer();
    
    buffer.write('Lab Test AI Analysis:\n\n');
    
    if (remarks.contains('normal')) {
      buffer.write('✓ All results are within normal range.\n\n');
    } else if (remarks.contains('abnormal') || remarks.contains('borderline')) {
      buffer.write('⚠️ Some values require attention.\n\n');
    }

    buffer.write('Recommendations:\n');
    buffer.write('• Review results with your healthcare provider\n');
    buffer.write('• Follow any prescribed treatment plans\n');

    return buffer.toString();
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    List<Map<String, dynamic>> allRecords = [];
    
    // Add ultrasounds
    for (var ultrasound in _ultrasounds) {
      allRecords.add({
        ...ultrasound,
        'type': 'ultrasound',
        'type_display': 'Ultrasound',
        'date': ultrasound['ultrasound_date'],
        'title': 'Ultrasound',
        'icon': Icons.photo,
        'iconColor': Colors.purple,
        'subtitle': _formatDate(ultrasound['ultrasound_date']),
        'health_worker': ultrasound['health_worker_name'],
      });
    }
    
    // Add lab tests
    for (var labTest in _labTests) {
      allRecords.add({
        ...labTest,
        'type': 'labtest',
        'type_display': 'Lab Test',
        'date': labTest['lab_test_date'],
        'title': labTest['lab_test_type'] ?? 'Lab Test',
        'icon': Icons.science,
        'iconColor': Colors.orange,
        'subtitle': _formatDate(labTest['lab_test_date']),
        'health_worker': labTest['health_worker_name'],
      });
    }
    
    // Add prenatal checkups
    for (var checkup in _prenatalCheckups) {
      allRecords.add({
        ...checkup,
        'type': 'prenatal',
        'type_display': 'Prenatal Checkup',
        'date': checkup['checkup_datetime'],
        'title': 'Prenatal Checkup',
        'icon': Icons.medical_services,
        'iconColor': AppColors.brandPrimary,
        'subtitle': _formatDateTime(checkup['checkup_datetime']),
        'health_worker': null,
      });
    }
    
    // Apply filter
    if (_selectedFilter != 'all') {
      allRecords = allRecords.where((record) => record['type'] == _selectedFilter).toList();
    }
    
    // Apply search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allRecords = allRecords.where((record) {
        return record['title'].toString().toLowerCase().contains(query) ||
               record['subtitle'].toString().toLowerCase().contains(query) ||
               (record['remarks']?.toString().toLowerCase().contains(query) ?? false) ||
               (record['lab_test_type']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Sort by date (newest first)
    allRecords.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'] ?? '');
      final dateB = DateTime.tryParse(b['date'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });
    
    return allRecords;
  }

  @override
  Widget build(BuildContext context) {
    final records = _getFilteredRecords();
    final totalCount = _ultrasounds.length + _labTests.length + _prenatalCheckups.length;
    final filteredCount = records.length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Stats Card with Pink Background Image
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 110,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/pinkbg.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    top: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0, top: 4.0, bottom: 4.0),
                      child: Image.asset(
                        'assets/images/records.png',
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.folder,
                          size: 80,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You have',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$totalCount Medical ${totalCount == 1 ? 'Record' : 'Records'}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Search and Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search records...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedFilter == 'all',
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = 'all';
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                          checkmarkColor: AppColors.brandPrimary,
                          labelStyle: TextStyle(
                            color: _selectedFilter == 'all' ? AppColors.brandPrimary : AppColors.textSecondary,
                            fontWeight: _selectedFilter == 'all' ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Ultrasound'),
                          selected: _selectedFilter == 'ultrasound',
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = 'ultrasound';
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.purple.withValues(alpha: 0.1),
                          checkmarkColor: Colors.purple,
                          avatar: Icon(Icons.photo, size: 16, color: _selectedFilter == 'ultrasound' ? Colors.purple : Colors.grey),
                          labelStyle: TextStyle(
                            color: _selectedFilter == 'ultrasound' ? Colors.purple : AppColors.textSecondary,
                            fontWeight: _selectedFilter == 'ultrasound' ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Lab Test'),
                          selected: _selectedFilter == 'labtest',
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = 'labtest';
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.orange.withValues(alpha: 0.1),
                          checkmarkColor: Colors.orange,
                          avatar: Icon(Icons.science, size: 16, color: _selectedFilter == 'labtest' ? Colors.orange : Colors.grey),
                          labelStyle: TextStyle(
                            color: _selectedFilter == 'labtest' ? Colors.orange : AppColors.textSecondary,
                            fontWeight: _selectedFilter == 'labtest' ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Prenatal'),
                          selected: _selectedFilter == 'prenatal',
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = 'prenatal';
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                          checkmarkColor: AppColors.brandPrimary,
                          avatar: Icon(Icons.medical_services, size: 16, color: _selectedFilter == 'prenatal' ? AppColors.brandPrimary : Colors.grey),
                          labelStyle: TextStyle(
                            color: _selectedFilter == 'prenatal' ? AppColors.brandPrimary : AppColors.textSecondary,
                            fontWeight: _selectedFilter == 'prenatal' ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFilter != 'all' || _searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing $filteredCount of $totalCount records',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFilter = 'all';
                                _searchQuery = '';
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text(
                              'Clear filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Records List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to Load Records',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadMotherData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMotherData,
                          color: AppColors.brandPrimary,
                          child: records.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                            ? Icons.search_off
                                            : Icons.folder_open,
                                        size: 64,
                                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                            ? 'No matching records found'
                                            : 'No records available',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                            ? 'Try adjusting your search or filters'
                                            : 'Your medical records will appear here',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: records.length,
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    final color = record['iconColor'];
                                    final icon = record['icon'];
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        if (record['type'] == 'ultrasound') {
                                          final imageUrls = _parseImageUrls(record['ultrasound_image']);
                                          _showRecordDetails(
                                            title: 'Ultrasound',
                                            subtitle: _formatDate(record['ultrasound_date']),
                                            icon: Icons.monitor_heart,
                                            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                                            rows: [
                                              MapEntry('Date', _formatDate(record['ultrasound_date'])),
                                              MapEntry('Location', _formatValue(record['ultrasound_location'])),
                                              MapEntry('Health Worker', _formatValue(record['health_worker_name'])),
                                              MapEntry('Institution', _formatValue(record['health_worker_institution'])),
                                              MapEntry('Profession', _formatValue(record['health_worker_profession'])),
                                              MapEntry('Remarks', _formatValue(record['remarks'])),
                                            ],
                                            aiAnalysis: _generateUltrasoundAIInsights(record),
                                          );
                                        } else if (record['type'] == 'labtest') {
                                          final imageUrls = _parseImageUrls(record['lab_test_image']);
                                          _showRecordDetails(
                                            title: record['lab_test_type'] ?? 'Lab Test',
                                            subtitle: _formatDate(record['lab_test_date']),
                                            icon: Icons.science,
                                            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                                            rows: [
                                              MapEntry('Type', _formatValue(record['lab_test_type'])),
                                              MapEntry('Date', _formatDate(record['lab_test_date'])),
                                              MapEntry('Location', _formatValue(record['lab_test_location'])),
                                              MapEntry('Health Worker', _formatValue(record['health_worker_name'])),
                                              MapEntry('Institution', _formatValue(record['health_worker_institution'])),
                                              MapEntry('Profession', _formatValue(record['health_worker_profession'])),
                                              MapEntry('Remarks', _formatValue(record['remarks'])),
                                            ],
                                            aiAnalysis: _generateLabTestAIInsights(record),
                                          );
                                        } else {
                                          _showRecordDetails(
                                            title: 'Prenatal Checkup',
                                            subtitle: _formatDateTime(record['checkup_datetime']),
                                            icon: Icons.medical_services,
                                            imageUrls: null,
                                            rows: [
                                              MapEntry('Date', _formatDateTime(record['checkup_datetime'])),
                                              MapEntry('Age of Gestation', _formatValue(record['age_of_gestation'])),
                                              MapEntry('Weight (kg)', _formatValue(record['checkup_weight'])),
                                              MapEntry('Blood Pressure', '${_formatValue(record['blood_pressure_systolic'])}/${_formatValue(record['blood_pressure_diastolic'])}'),
                                              MapEntry('Fetal Heart Rate', _formatValue(record['fetal_heart_beat'])),
                                              MapEntry('Edema', _formatValue(record['edema'])),
                                              MapEntry('TD Vaccine', _formatValue(record['td_vaccine_dose'])),
                                              MapEntry('Remarks', _formatValue(record['remarks'])),
                                              MapEntry('Next Schedule', _formatDate(record['next_schedule'])),
                                            ],
                                            aiAnalysis: _generatePrenatalAIInsights(record),
                                          );
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(30),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            // Icon
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  icon,
                                                  color: color,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            
                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    record['title'],
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    record['subtitle'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  if (record['health_worker'] != null &&
                                                      record['health_worker'].toString().isNotEmpty)
                                                    Text(
                                                      'By: ${record['health_worker']}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Arrow
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 24,
                                              color: AppColors.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}