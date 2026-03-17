import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';

class MotherUltrasoundDetailsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Map<String, dynamic> ultrasoundData;

  const MotherUltrasoundDetailsPage({
    super.key,
    required this.onBack,
    required this.ultrasoundData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data
    final date = ultrasoundData['ultrasound_date'] ?? 'Not specified';
    final location = ultrasoundData['ultrasound_location'] ?? 'Not specified';
    final healthWorker = ultrasoundData['health_worker_name'] ?? 'Not specified';
    final institution = ultrasoundData['health_worker_institution'] ?? 'Not specified';
    final profession = ultrasoundData['health_worker_profession'] ?? 'Not specified';
    final remarks = ultrasoundData['remarks'] ?? 'No remarks available';
    final imageUrl = ultrasoundData['ultrasound_image'];
    
    // Format date
    final formattedDate = _formatDate(date);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SecondaryHeader(
          title: 'Ultrasound Details',
          onBack: onBack,
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🖼 ULTRASOUND IMAGE
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
                        Icons.photo_library_rounded,
                        color: AppColors.brandText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ultrasound Image',
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
                                    'Unable to load image',
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
                            Icons.photo_library_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No ultrasound image available',
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

            // 📋 ULTRASOUND DETAILS
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
                        'Ultrasound Details',
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
                    label: 'Date',
                    value: formattedDate,
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
                        'Remarks',
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
                          Color(0xFFF3E5F5),
                          Color(0xFFE8EAF6),
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
                              color: Color(0xFF7E57C2),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Summary Analysis',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5E35B1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _generateAIAnalysis(remarks, formattedDate, location, healthWorker),
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

  String _generateAIAnalysis(String remarks, String date, String location, String healthWorker) {
    // Simple AI-like analysis based on available data
    final lowerRemarks = remarks.toLowerCase();
    final analysis = StringBuffer();
    
    analysis.write('Based on the ultrasound conducted on $date');
    
    if (location != 'Not specified') {
      analysis.write(' at $location');
    }
    
    if (healthWorker != 'Not specified') {
      analysis.write(' by $healthWorker');
    }
    
    analysis.write(':\n\n');
    
    // Analyze remarks
    if (lowerRemarks.contains('normal') || 
        lowerRemarks.contains('healthy') ||
        lowerRemarks.contains('good') ||
        lowerRemarks.contains('appropriate') ||
        lowerRemarks.contains('within normal limits')) {
      analysis.write('✅ The ultrasound findings appear normal and indicate healthy fetal development. '
          'All measurements and observations are within expected ranges for this stage of pregnancy.');
    } else if (lowerRemarks.contains('follow') || 
               lowerRemarks.contains('monitor') ||
               lowerRemarks.contains('repeat') ||
               lowerRemarks.contains('re-evaluate')) {
      analysis.write('📊 Follow-up monitoring is recommended. Some findings require additional observation '
          'or repeat ultrasound to track progression. This is a common precautionary measure.');
    } else if (lowerRemarks.contains('concern') ||
               lowerRemarks.contains('abnormal') ||
               lowerRemarks.contains('further') ||
               lowerRemarks.contains('investigation')) {
      analysis.write('🔍 These results indicate findings that may require additional evaluation. '
          'Please discuss these with your healthcare provider for appropriate guidance and next steps.');
    } else if (lowerRemarks.contains('growth') ||
               lowerRemarks.contains('measurement') ||
               lowerRemarks.contains('size')) {
      analysis.write('📏 Fetal growth and measurements appear consistent with gestational age. '
          'Regular monitoring will help ensure continued healthy development.');
    } else if (lowerRemarks.contains('position') ||
               lowerRemarks.contains('presentation') ||
               lowerRemarks.contains('placenta')) {
      analysis.write('📍 Fetal position and placental location are noted. These are important factors '
          'for monitoring pregnancy progression and planning for delivery.');
    } else {
      analysis.write('📋 The ultrasound provides important diagnostic information about your pregnancy. '
          'Continue with regular prenatal care and follow your healthcare provider\'s recommendations.');
    }
    
    // Add general advice
    analysis.write('\n\n💡 Remember to:\n');
    analysis.write('• Attend all scheduled prenatal appointments\n');
    analysis.write('• Report any unusual symptoms to your healthcare provider\n');
    analysis.write('• Maintain a healthy lifestyle with proper nutrition\n');
    analysis.write('• Stay hydrated and get adequate rest\n');
    
    if (lowerRemarks.contains('exercise') || lowerRemarks.contains('activity')) {
      analysis.write('• Continue moderate exercise as approved by your provider\n');
    }
    
    return analysis.toString();
  }
}