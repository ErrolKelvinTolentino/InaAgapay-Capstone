import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';

class MotherLabDetails extends StatelessWidget {
  final VoidCallback onBack;
  final Map<String, dynamic> labTestData;

  const MotherLabDetails({
    super.key,
    required this.onBack,
    required this.labTestData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data
    final date = labTestData['lab_test_date'] ?? 'Not specified';
    final testType = labTestData['lab_test_type'] ?? 'Not specified';
    final location = labTestData['lab_test_location'] ?? 'Not specified';
    final healthWorker = labTestData['health_worker_name'] ?? 'Not specified';
    final institution = labTestData['health_worker_institution'] ?? 'Not specified';
    final profession = labTestData['health_worker_profession'] ?? 'Not specified';
    final remarks = labTestData['remarks'] ?? 'No remarks available';
    final imageUrl = labTestData['lab_test_image'];
    
    // Format date
    final formattedDate = _formatDate(date);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: 'Laboratory Test Details',
          onBack: onBack,
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 📋 LAB TEST IMAGE/RESULT
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        color: AppColors.brandText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Test Result / Image',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (imageUrl != null && imageUrl.toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      child: Container(
                        height: 280,
                        width: double.infinity,
                        color: AppColors.bgSecondary,
                        child: Image.network(
                          _getFullImageUrl(imageUrl.toString()),
                          fit: BoxFit.contain,
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
                            print('Image loading error: $error');
                            print('Image URL: ${_getFullImageUrl(imageUrl.toString())}');
                            return Container(
                              color: AppColors.bgPrimary,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_rounded,
                                    size: 48,
                                    color: AppColors.textSecondary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unable to load test result image',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'URL: ${_getFullImageUrl(imageUrl.toString())}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.borderPrimary.withOpacity(0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No test result image available',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🧪 LAB TEST DETAILS
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Test Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Details list
                  _detailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Test Date',
                    value: formattedDate,
                  ),
                  const SizedBox(height: 12),
                  
                  _detailRow(
                    icon: Icons.science_rounded,
                    label: 'Test Type',
                    value: testType,
                  ),
                  const SizedBox(height: 12),
                  
                  _detailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: location,
                  ),
                  const SizedBox(height: 12),
                  
                  _detailRow(
                    icon: Icons.person_rounded,
                    label: 'Health Worker',
                    value: healthWorker,
                  ),
                  const SizedBox(height: 12),
                  
                  _detailRow(
                    icon: Icons.business_rounded,
                    label: 'Institution',
                    value: institution,
                  ),
                  const SizedBox(height: 12),
                  
                  _detailRow(
                    icon: Icons.work_rounded,
                    label: 'Profession',
                    value: profession,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 📝 REMARKS
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remarks & Findings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Remarks content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      remarks,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🤖 AI ANALYSIS
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: Color(0xFF7E57C2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Insights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // AI content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE3F2FD),
                          Color(0xFFE8F5E9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Color(0xFF1976D2),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Test Analysis',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _generateAIAnalysis(remarks, formattedDate, testType, healthWorker),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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

  String _getFullImageUrl(String imagePath) {
    if (imagePath.isEmpty) {
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _generateAIAnalysis(String remarks, String date, String testType, String healthWorker) {
    // Simple AI-like analysis based on available data
    final lowerRemarks = remarks.toLowerCase();
    final analysis = StringBuffer();
    
    analysis.write('Analysis of $testType conducted on $date');
    
    if (healthWorker != 'Not specified') {
      analysis.write(' by $healthWorker');
    }
    
    analysis.write(':\n\n');
    
    // Analyze based on test type
    if (testType.toLowerCase().contains('blood') || testType.toLowerCase().contains('cbc')) {
      analysis.write('🩸 **Blood Test Results**:\n');
      if (lowerRemarks.contains('normal') || lowerRemarks.contains('within range')) {
        analysis.write('Your blood test results appear to be within normal ranges. '
            'This indicates good overall health and proper nutrient levels for pregnancy.');
      } else if (lowerRemarks.contains('low') || lowerRemarks.contains('deficiency')) {
        analysis.write('The results suggest some values may be below optimal levels. '
            'This could indicate nutrient deficiencies that may require dietary adjustments or supplements.');
      } else if (lowerRemarks.contains('high') || lowerRemarks.contains('elevated')) {
        analysis.write('Some values appear elevated. This is common during pregnancy '
            'but should be monitored by your healthcare provider.');
      }
    } else if (testType.toLowerCase().contains('urine') || testType.toLowerCase().contains('uti')) {
      analysis.write('💧 **Urine Test Results**:\n');
      if (lowerRemarks.contains('normal') || lowerRemarks.contains('negative')) {
        analysis.write('Your urine test results are normal, indicating no signs of infection '
            'or concerning abnormalities.');
      } else if (lowerRemarks.contains('infection') || lowerRemarks.contains('bacteria')) {
        analysis.write('The test indicates a possible urinary tract infection. '
            'Prompt treatment is important during pregnancy to prevent complications.');
      } else if (lowerRemarks.contains('protein') || lowerRemarks.contains('glucose')) {
        analysis.write('The presence of protein or glucose requires monitoring '
            'as it can be related to pregnancy-related conditions.');
      }
    } else if (testType.toLowerCase().contains('glucose') || testType.toLowerCase().contains('sugar')) {
      analysis.write('🍬 **Glucose Test Results**:\n');
      if (lowerRemarks.contains('normal') || lowerRemarks.contains('passed')) {
        analysis.write('Your glucose levels are within the normal range for pregnancy. '
            'Continue maintaining a balanced diet.');
      } else if (lowerRemarks.contains('high') || lowerRemarks.contains('gestational diabetes')) {
        analysis.write('Elevated glucose levels detected. This may indicate gestational diabetes '
            'requiring dietary management and possibly medication.');
      }
    } else if (testType.toLowerCase().contains('ultrasound') || testType.toLowerCase().contains('scan')) {
      analysis.write('👶 **Ultrasound/Imaging Results**:\n');
      analysis.write('Imaging tests provide valuable information about fetal development '
            'and maternal health. Follow up with your provider for detailed interpretation.');
    } else {
      analysis.write('🔬 **Laboratory Findings**:\n');
      if (lowerRemarks.contains('normal') || lowerRemarks.contains('unremarkable')) {
        analysis.write('The test results appear normal and unremarkable, '
            'which is positive news for your pregnancy health.');
      } else if (lowerRemarks.contains('abnormal') || lowerRemarks.contains('concerning')) {
        analysis.write('Some abnormal findings were noted. These require '
            'further evaluation and discussion with your healthcare provider.');
      } else {
        analysis.write('These laboratory results provide important diagnostic information. '
            'Review them with your healthcare provider for proper interpretation.');
      }
    }
    
    // Add general advice
    analysis.write('\n\n💡 **Next Steps**:\n');
    analysis.write('• Discuss these results with your healthcare provider\n');
    analysis.write('• Follow any recommended treatment or monitoring plans\n');
    analysis.write('• Attend all scheduled follow-up appointments\n');
    analysis.write('• Report any new symptoms or concerns promptly\n');
    
    return analysis.toString();
  }
}