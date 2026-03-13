import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/hero_card.dart';

import '../services/api_service.dart';
import '../utils/session.dart';

class MotherPrenatalOverview extends StatefulWidget {
  final Function(Map<String, dynamic>) onViewCheckupDetails;
  final VoidCallback onViewGrowth;

  const MotherPrenatalOverview({
    super.key,
    required this.onViewCheckupDetails,
    required this.onViewGrowth,
  });

  @override
  State<MotherPrenatalOverview> createState() => _MotherPrenatalOverviewState();
}

class _MotherPrenatalOverviewState extends State<MotherPrenatalOverview> {
  late Future<Map<String, dynamic>> _prenatalFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _prenatalFuture = _fetchPrenatalData();
  }

  Future<Map<String, dynamic>> _fetchPrenatalData() async {
    print('=== FETCHING PRENATAL DATA ===');
    
    // Get token asynchronously
    final token = await Session.token;
    print('🔐 Token available: ${token != null && token.isNotEmpty}');
    
    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'error': 'Please log in again. No authentication token found.',
        'latest': null,
        'history': [],
        'total': 0
      };
    }
    
    try {
      final response = await ApiService.get(
        'mother/prenatal_checkups.php',
        token: token,
      );
      
      print('📦 API Response received');
      
      // Check if response indicates success
      if (response.containsKey('success')) {
        if (response['success'] == true) {
          print('✅ API Success');
          
          final checkups = response['history'] is List ? response['history'] : [];
          final latest = response['latest'];
          final total = response['total'] is int ? response['total'] : 0;
          
          print('📊 Found $total checkups');
          
          return {
            'success': true,
            'latest': latest,
            'history': checkups,
            'total': total,
            'message': response['message'] ?? 'Success'
          };
        } else {
          // API returned success: false
          print('❌ API Error: ${response['message']}');
          
          String errorMessage = response['message'] ?? 'Failed to load data';
          if (response.containsKey('statusCode')) {
            if (response['statusCode'] == 401) {
              errorMessage = 'Session expired. Please log in again.';
            }
          }
          
          return {
            'success': false,
            'error': errorMessage,
            'latest': null,
            'history': [],
            'total': 0
          };
        }
      } else {
        // Response doesn't have 'success' key
        print('❌ Malformed API response');
        
        return {
          'success': false,
          'error': 'Invalid server response',
          'latest': null,
          'history': [],
          'total': 0
        };
      }
    } catch (e) {
      print('❌ Exception: $e');
      
      return {
        'success': false,
        'error': 'Connection failed: $e',
        'latest': null,
        'history': [],
        'total': 0
      };
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _prenatalFuture = _fetchPrenatalData();
      });
    }
  }

  String _getMidwifeName(Map<String, dynamic>? checkup) {
    if (checkup == null) return 'Not specified';
    
    final firstName = checkup['midwife_first_name']?.toString() ?? '';
    final lastName = checkup['midwife_last_name']?.toString() ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty) {
      return 'Not specified';
    }
    
    return '$firstName $lastName'.trim();
  }

  String _getBPStatus(int? systolic, int? diastolic) {
    if (systolic == null || diastolic == null) return 'Normal';
    
    if (systolic >= 140 || diastolic >= 90) return 'High';
    if (systolic <= 90 || diastolic <= 60) return 'Low';
    return 'Normal';
  }

  Color _getBPStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: AppBar(
        title: const Text('Prenatal Check-ups'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _prenatalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState('Error: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return _buildErrorState('No data received');
          }

          final data = snapshot.data!;
          
          if (data['success'] != true) {
            return _buildErrorState(data['error'] ?? 'Failed to load data');
          }

          final checkups = (data['history'] as List?) ?? [];
          final latest = data['latest'] as Map<String, dynamic>?;
          final total = data['total'] ?? 0;

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 👩‍🍼 HERO CARD
                  HeroCard(
                    image: const AssetImage('assets/images/prenatal.png'),
                    title: 'Prenatal Check-ups',
                    subtitle: checkups.isNotEmpty 
                      ? '$total checkup${total > 1 ? 's' : ''} from all pregnancies'
                      : 'No prenatal checkup records found',
                    showHeartRow: false,
                    showWeekBadge: false,
                  ),

                  const SizedBox(height: 20),

                  if (checkups.isEmpty) ...[
                    _buildEmptyState(),
                  ] else ...[
                    // 🏥 LATEST CHECKUP OVERVIEW
                    _buildLatestCheckup(latest),
                    const SizedBox(height: 20),

                    // 📈 GROWTH STATISTICS BUTTON
                    _buildGrowthButton(),
                    const SizedBox(height: 20),

                    // 📋 CHECKUP HISTORY
                    _buildCheckupHistory(checkups, total),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
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

  Widget _buildEmptyState() {
    return Container(
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
            Icons.medical_services_outlined,
            size: 60,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Prenatal Records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any prenatal checkup records yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestCheckup(Map<String, dynamic>? latest) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Latest Checkup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Latest',
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
          
          Container(
            height: 1,
            color: AppColors.borderPrimary.withOpacity(0.5),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLatestCheckupDetails(latest),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestCheckupDetails(Map<String, dynamic>? latest) {
    final items = <Widget>[];
    
    // Date
    items.add(_detailRow(
      icon: Icons.calendar_today_rounded,
      label: 'Date',
      value: latest?['checkup_date']?.toString().isNotEmpty == true 
        ? _formatDate(latest!['checkup_date'].toString())
        : 'Not specified',
    ));
    items.add(const SizedBox(height: 12));
    
    // Gestation Age
    if (latest?['age_of_gestation']?.toString().isNotEmpty == true) {
      items.add(_detailRow(
        icon: Icons.timeline_rounded,
        label: 'Gestation Age',
        value: '${latest!['age_of_gestation']} weeks',
      ));
      items.add(const SizedBox(height: 12));
    }
    
    // Weight
    if (latest?['checkup_weight']?.toString().isNotEmpty == true) {
      items.add(_detailRow(
        icon: Icons.monitor_weight_rounded,
        label: 'Weight',
        value: '${latest!['checkup_weight']} kg',
      ));
      items.add(const SizedBox(height: 12));
    }
    
    // Blood Pressure
    if (latest?['blood_pressure_systolic']?.toString().isNotEmpty == true && 
        latest?['blood_pressure_diastolic']?.toString().isNotEmpty == true) {
      final systolic = int.tryParse(latest!['blood_pressure_systolic'].toString());
      final diastolic = int.tryParse(latest['blood_pressure_diastolic'].toString());
      final status = _getBPStatus(systolic, diastolic);
      
      items.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blood Pressure',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${latest['blood_pressure_systolic']}/${latest['blood_pressure_diastolic']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getBPStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getBPStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ));
      items.add(const SizedBox(height: 12));
    }
    
    // Midwife
    final midwifeName = _getMidwifeName(latest);
    if (midwifeName != 'Not specified') {
      items.add(_detailRow(
        icon: Icons.person_rounded,
        label: 'Midwife',
        value: midwifeName,
      ));
      items.add(const SizedBox(height: 12));
    }
    
    // Next Schedule
    if (latest?['next_schedule']?.toString().isNotEmpty == true) {
      items.add(_detailRow(
        icon: Icons.calendar_month_rounded,
        label: 'Next Schedule',
        value: _formatDate(latest!['next_schedule'].toString()),
      ));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildGrowthButton() {
    return GestureDetector(
      onTap: widget.onViewGrowth,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.show_chart_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Statistics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View weight and blood pressure trends',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckupHistory(List checkups, int total) {
    return Container(
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
                    'Checkup History',
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
          
          Container(
            height: 1,
            color: AppColors.borderPrimary.withOpacity(0.5),
          ),
          
          ...checkups.map((checkup) {
            final date = checkup['checkup_date']?.toString() ?? 'No date';
            final formattedDate = _formatDate(date);
            final gestation = checkup['age_of_gestation']?.toString().isNotEmpty == true
                ? '${checkup['age_of_gestation']} weeks'
                : '';
            final weight = checkup['checkup_weight']?.toString().isNotEmpty == true
                ? '${checkup['checkup_weight']} kg'
                : '';
            final midwifeName = _getMidwifeName(checkup);
            
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: AppColors.brandPrimary,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (gestation.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Gestation: $gestation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (weight.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Weight: $weight',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (midwifeName != 'Not specified') ...[
                              const SizedBox(height: 2),
                              Text(
                                'Midwife: $midwifeName',
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
                      
                      _ViewDetailsPill(
                        onTap: () => widget.onViewCheckupDetails(checkup),
                      ),
                    ],
                  ),
                ),
                
                if (checkups.last != checkup)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 1,
                    color: AppColors.borderPrimary.withOpacity(0.3),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
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