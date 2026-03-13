import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/hero_card.dart';

import '../services/api_service.dart';
import '../utils/session.dart';

class MotherLabOverview extends StatefulWidget {
  final Function(Map<String, dynamic>) onViewDetails;

  const MotherLabOverview({
    super.key,
    required this.onViewDetails,
  });

  @override
  State<MotherLabOverview> createState() => _MotherLabOverviewState();
}

class _MotherLabOverviewState extends State<MotherLabOverview> {
  late Future<Map<String, dynamic>> _labFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _labFuture = _fetchLabTests();
  }

  Future<Map<String, dynamic>> _fetchLabTests() async {
    print('Fetching ALL lab test records...');
    
    try {
      final response = await ApiService.get(
        'mother/lab_records.php',
        token: Session.token,
      );
      
      print('API Response received');
      
      if (response == null) {
        print('API Response is null');
        return {'success': false, 'records': [], 'error': 'No response from server'};
      }
      
      if (response['success'] == true) {
        final records = response['records'] as List? ?? [];
        final total = response['total'] ?? records.length;
        print('Found $total lab test records from all pregnancies');
        
        // Debug: Print first record if exists
        if (records.isNotEmpty) {
          print('First record preview: ${records[0]}');
          print('Image URL in first record: ${records[0]['lab_test_image']}');
        }
        
        return {
          'success': true,
          'records': records,
          'total': total
        };
      } else {
        print('API returned success: false');
        return {
          'success': false, 
          'records': [], 
          'error': response['message'] ?? 'Unknown error',
          'total': 0
        };
      }
    } catch (e, stackTrace) {
      print('Error fetching lab tests: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'records': [], 'error': e.toString(), 'total': 0};
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _labFuture = _fetchLabTests();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SecondaryHeader(
          title: 'Laboratory Test Results',
          onBack: () => Navigator.pop(context),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _labFuture,
          builder: (context, snapshot) {
            // Show loading indicator
            if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Check for errors
            final hasError = snapshot.hasError || 
                            (snapshot.hasData && snapshot.data!['success'] != true);
            
            if (hasError) {
              final errorMessage = snapshot.hasError 
                ? snapshot.error.toString()
                : snapshot.data?['error'] ?? 'Unknown error';
                
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load records',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Get records from snapshot
            final records = (snapshot.data?['records'] as List? ?? []);
            final total = snapshot.data?['total'] ?? records.length;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 👩‍⚕️ HERO CARD
                  HeroCard(
                    image: const AssetImage('assets/images/lab.png'),
                    title: 'Laboratory Test Results',
                    subtitle: records.isNotEmpty 
                      ? '$total test${total > 1 ? 's' : ''} from all pregnancies'
                      : 'No lab test records found',
                    showHeartRow: false,
                    showWeekBadge: false,
                  ),

                  const SizedBox(height: 20),

                  if (records.isEmpty) ...[
                    // Empty state
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 60,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Lab Test Records',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You don\'t have any lab test results yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Results from all your pregnancies will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 🧪 LAB TEST HISTORY LIST
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'All Lab Test Results',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Divider
                          Container(
                            height: 1,
                            color: AppColors.borderPrimary.withOpacity(0.5),
                          ),
                          
                          // List items
                          ...records.map((record) {
                            final date = record['lab_test_date'] ?? 'No date';
                            final formattedDate = _formatDate(date);
                            final testType = record['lab_test_type'] ?? 'Lab Test';
                            final location = record['lab_test_location'] ?? '';
                            final hasImage = record['lab_test_image'] != null && 
                                            (record['lab_test_image'] as String).isNotEmpty;
                            
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Icon or image preview
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: AppColors.brandPrimary.withOpacity(0.1),
                                          border: Border.all(
                                            color: AppColors.brandPrimary.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Center(
                                          child: hasImage
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.network(
                                                    _getFullImageUrl(record['lab_test_image']),
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Center(
                                                        child: CircularProgressIndicator(
                                                          value: loadingProgress.expectedTotalBytes != null
                                                              ? loadingProgress.cumulativeBytesLoaded /
                                                                  loadingProgress.expectedTotalBytes!
                                                              : null,
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(
                                                        Icons.description,
                                                        color: AppColors.brandPrimary,
                                                        size: 24,
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.science_rounded,
                                                  color: AppColors.brandPrimary,
                                                  size: 24,
                                                ),
                                        ),
                                      ),
                                      
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              testType,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 14,
                                                  color: AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  formattedDate,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (location.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on_outlined,
                                                    size: 14,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      location,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (record['health_worker_name'] != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'By: ${record['health_worker_name']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // View Details Button
                                      _ViewDetailsPill(
                                        onTap: () => widget.onViewDetails(record),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Divider between items
                                if (records.last != record)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    height: 1,
                                    color: AppColors.borderPrimary.withOpacity(0.3),
                                  ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      
      // Debug/Refresh button
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    
    // If it's already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    
    // Remove leading slash if present
    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }
    
    // Otherwise, prepend the base URL
    return 'https://inaagapay.alwaysdata.net/$imagePath';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      print('Error parsing date: $dateString - $e');
      return dateString;
    }
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class _ViewDetailsPill extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewDetailsPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brandPrimary),
        ),
        child: const Text(
          'View Details',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}