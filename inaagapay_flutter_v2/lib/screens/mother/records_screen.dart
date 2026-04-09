// lib/screens/mother/records_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../widgets/headline.dart';
import '../../widgets/main_button.dart';
import '../../widgets/full_screen_image_viewer.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  int? _motherId;

  List<Map<String, dynamic>> _ultrasounds = [];
  List<Map<String, dynamic>> _labTests = [];

  String _selectedFilter = 'all';
  String _sortOrder = 'desc';
  String _searchQuery = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMotherData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        });
      } else {
        final pregnancyIds = pregnanciesResponse
            .map<int>((p) => p['pregnancy_id'] as int)
            .toList();
        await _loadRecordsForPregnancies(pregnancyIds);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecordsForPregnancies(List<int> pregnancyIds) async {
    if (pregnancyIds.isNotEmpty) {
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

      setState(() {
        _ultrasounds = List<Map<String, dynamic>>.from(ultrasoundsResponse);
        _labTests = List<Map<String, dynamic>>.from(labTestsResponse);
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
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
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
                              onTap: () =>
                                  _showFullScreenImage(imageUrls, index),
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image,
                                                    size: 32,
                                                    color: Colors.grey),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Image not available',
                                                  style:
                                                      TextStyle(fontSize: 10),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            color: AppColors.bgSecondary,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        AppColors.brandPrimary),
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
                                              color:
                                                  Colors.black.withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                        children: rows
                            .map((entry) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                ))
                            .toList(),
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
                          border: Border.all(
                              color: const Color(0xFF7E57C2)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology_rounded,
                                    color: const Color(0xFF7E57C2), size: 20),
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

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final buffer = StringBuffer();

    buffer.write('🤖 Ultrasound AI Insights:\n\n');

    if (remarks.contains('normal') || remarks.contains('healthy')) {
      buffer.write(
          '✅ **Normal Findings**: Ultrasound appears normal with healthy fetal development.\n\n');
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      buffer.write(
          '📊 **Follow-up Recommended**: Some findings require additional observation.\n\n');
    } else if (remarks.contains('concern') || remarks.contains('abnormal')) {
      buffer.write(
          '🔍 **Further Evaluation Needed**: Discuss findings with healthcare provider.\n\n');
    } else {
      buffer.write(
          '📋 **Diagnostic Information**: The ultrasound provides important diagnostic information.\n\n');
    }

    buffer.write('💡 **Key Recommendations**:\n');
    buffer.write('• Discuss findings with your healthcare provider\n');
    buffer.write('• Continue all scheduled prenatal appointments\n');

    return buffer.toString();
  }

  String _generateLabTestAIInsights(Map<String, dynamic> labTest) {
    final remarks = labTest['remarks']?.toString().toLowerCase() ?? '';
    final buffer = StringBuffer();

    buffer.write('🤖 Lab Test AI Analysis:\n\n');

    if (remarks.contains('normal')) {
      buffer.write('✅ **All results are within normal range.**\n\n');
    } else if (remarks.contains('abnormal') || remarks.contains('borderline')) {
      buffer.write('⚠️ **Some values require attention.**\n\n');
    }

    buffer.write('🏥 **Recommendations**:\n');
    buffer.write('• Review results with your healthcare provider\n');
    buffer.write('• Follow any prescribed treatment plans\n');

    return buffer.toString();
  }

  List<Map<String, dynamic>> _getFilteredAndSortedRecords() {
    List<Map<String, dynamic>> allRecords = [];

    for (var ultrasound in _ultrasounds) {
      allRecords.add({
        ...ultrasound,
        'record_type': 'ultrasound',
        'record_date': ultrasound['ultrasound_date'],
      });
    }

    for (var labTest in _labTests) {
      allRecords.add({
        ...labTest,
        'record_type': 'labtest',
        'record_date': labTest['lab_test_date'],
      });
    }

    if (_selectedFilter != 'all') {
      allRecords = allRecords
          .where((record) => record['record_type'] == _selectedFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allRecords = allRecords.where((record) {
        if (record['record_type'] == 'ultrasound') {
          return _formatDate(record['ultrasound_date'])
                  .toLowerCase()
                  .contains(query) ||
              (record['remarks']?.toString().toLowerCase().contains(query) ??
                  false);
        } else {
          return _formatDate(record['lab_test_date'])
                  .toLowerCase()
                  .contains(query) ||
              (record['lab_test_type']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false) ||
              (record['remarks']?.toString().toLowerCase().contains(query) ??
                  false);
        }
      }).toList();
    }

    allRecords.sort((a, b) {
      final dateA = DateTime.tryParse(a['record_date'] ?? '');
      final dateB = DateTime.tryParse(b['record_date'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return _sortOrder == 'desc'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    return allRecords;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const Headline(text: 'Failed to Load Records'),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MainButton(
                label: 'Retry',
                onPressed: _loadMotherData,
              ),
            ],
          ),
        ),
      );
    }

    final allRecords = _getFilteredAndSortedRecords();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.brandPrimary,
            labelColor: AppColors.brandPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'All Records'),
              Tab(text: 'Statistics'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecordsTab(allRecords),
              _buildStatisticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(List<Map<String, dynamic>> allRecords) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search records...',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Records')),
                          DropdownMenuItem(
                              value: 'ultrasound',
                              child: Text('Ultrasounds Only')),
                          DropdownMenuItem(
                              value: 'labtest', child: Text('Lab Tests Only')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _sortOrder,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'desc', child: Text('Newest First')),
                        DropdownMenuItem(
                            value: 'asc', child: Text('Oldest First')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortOrder = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: allRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.folder_open,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
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
                        _searchQuery.isNotEmpty
                            ? 'Try adjusting your search or filters'
                            : 'Your medical records will appear here',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMotherData,
                  color: AppColors.brandPrimary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allRecords.length,
                    itemBuilder: (context, index) {
                      final record = allRecords[index];
                      final isUltrasound =
                          record['record_type'] == 'ultrasound';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isUltrasound
                                  ? Colors.purple.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isUltrasound ? Icons.photo : Icons.science,
                              color:
                                  isUltrasound ? Colors.purple : Colors.orange,
                            ),
                          ),
                          title: Text(
                            isUltrasound
                                ? 'Ultrasound'
                                : (record['lab_test_type'] ?? 'Lab Test'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(isUltrasound
                                    ? record['ultrasound_date']
                                    : record['lab_test_date']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (record['health_worker_name'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'By: ${record['health_worker_name']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () {
                            if (isUltrasound) {
                              final imageUrls =
                                  _parseImageUrls(record['ultrasound_image']);
                              _showRecordDetails(
                                title: 'Ultrasound',
                                subtitle:
                                    _formatDate(record['ultrasound_date']),
                                icon: Icons.monitor_heart,
                                imageUrls:
                                    imageUrls.isNotEmpty ? imageUrls : null,
                                rows: [
                                  MapEntry('Date',
                                      _formatDate(record['ultrasound_date'])),
                                  MapEntry(
                                      'Location',
                                      _formatValue(
                                          record['ultrasound_location'])),
                                  MapEntry(
                                      'Health Worker',
                                      _formatValue(
                                          record['health_worker_name'])),
                                  MapEntry(
                                      'Institution',
                                      _formatValue(
                                          record['health_worker_institution'])),
                                  MapEntry(
                                      'Profession',
                                      _formatValue(
                                          record['health_worker_profession'])),
                                  MapEntry('Remarks',
                                      _formatValue(record['remarks'])),
                                ],
                                aiAnalysis:
                                    _generateUltrasoundAIInsights(record),
                              );
                            } else {
                              final imageUrls =
                                  _parseImageUrls(record['lab_test_image']);
                              _showRecordDetails(
                                title: record['lab_test_type'] ?? 'Lab Test',
                                subtitle: _formatDate(record['lab_test_date']),
                                icon: Icons.science,
                                imageUrls:
                                    imageUrls.isNotEmpty ? imageUrls : null,
                                rows: [
                                  MapEntry('Type',
                                      _formatValue(record['lab_test_type'])),
                                  MapEntry('Date',
                                      _formatDate(record['lab_test_date'])),
                                  MapEntry(
                                      'Location',
                                      _formatValue(
                                          record['lab_test_location'])),
                                  MapEntry(
                                      'Health Worker',
                                      _formatValue(
                                          record['health_worker_name'])),
                                  MapEntry(
                                      'Institution',
                                      _formatValue(
                                          record['health_worker_institution'])),
                                  MapEntry(
                                      'Profession',
                                      _formatValue(
                                          record['health_worker_profession'])),
                                  MapEntry('Remarks',
                                      _formatValue(record['remarks'])),
                                ],
                                aiAnalysis: _generateLabTestAIInsights(record),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    final totalUltrasounds = _ultrasounds.length;
    final totalLabTests = _labTests.length;
    final totalRecords = totalUltrasounds + totalLabTests;

    final allRecords = _getFilteredAndSortedRecords();
    final latestRecord = allRecords.isNotEmpty ? allRecords.first : null;

    final now = DateTime.now();
    final last6Months = List.generate(6, (i) {
      return DateTime(now.year, now.month - i, 1);
    }).reversed.toList();

    Map<String, int> recordsByMonth = {};
    for (var month in last6Months) {
      final monthKey = DateFormat('MMM yyyy').format(month);
      recordsByMonth[monthKey] = 0;
    }

    for (var record in allRecords) {
      final dateStr = record['record_date'];
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final monthKey = DateFormat('MMM yyyy').format(date);
          if (recordsByMonth.containsKey(monthKey)) {
            recordsByMonth[monthKey] = (recordsByMonth[monthKey] ?? 0) + 1;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Records',
                  totalRecords.toString(),
                  Icons.folder,
                  AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ultrasounds',
                  totalUltrasounds.toString(),
                  Icons.photo,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Lab Tests',
                  totalLabTests.toString(),
                  Icons.science,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'With Images',
                  '${_ultrasounds.where((u) => u['ultrasound_image'] != null).length + _labTests.where((l) => l['lab_test_image'] != null).length}',
                  Icons.image,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (latestRecord != null) ...[
            const Text(
              'LATEST RECORD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (latestRecord['record_type'] == 'ultrasound'
                              ? Colors.purple
                              : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      latestRecord['record_type'] == 'ultrasound'
                          ? Icons.photo
                          : Icons.science,
                      color: latestRecord['record_type'] == 'ultrasound'
                          ? Colors.purple
                          : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestRecord['record_type'] == 'ultrasound'
                              ? 'Ultrasound'
                              : (latestRecord['lab_test_type'] ?? 'Lab Test'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(latestRecord['record_date']),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: latestRecord['ultrasound_image'] != null ||
                              latestRecord['lab_test_image'] != null
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      latestRecord['ultrasound_image'] != null ||
                              latestRecord['lab_test_image'] != null
                          ? 'Has Images'
                          : 'No Images',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: latestRecord['ultrasound_image'] != null ||
                                latestRecord['lab_test_image'] != null
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'RECORDS BY MONTH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...recordsByMonth.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Container(
                          height: 30,
                          width: (entry.value / 10) *
                              MediaQuery.of(context).size.width *
                              0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brandPrimary,
                                AppColors.brandSecondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'View All Ultrasounds',
                        Icons.photo,
                        Colors.purple,
                        () {
                          setState(() {
                            _selectedFilter = 'ultrasound';
                            _tabController.animateTo(0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        'View All Lab Tests',
                        Icons.science,
                        Colors.orange,
                        () {
                          setState(() {
                            _selectedFilter = 'labtest';
                            _tabController.animateTo(0);
                          });
                        },
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

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
