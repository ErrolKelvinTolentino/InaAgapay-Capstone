// lib/screens/midwife/midwife_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

class MidwifeDashboard extends StatelessWidget {
  const MidwifeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Midwife! 👩‍⚕️',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(DateTime.now()),
                    style: TextStyle(
                      color: AppColors.brandSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // Stats Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  'Active Mothers',
                  '24',
                  Icons.pregnant_woman,
                  Colors.purple,
                  '+3 this month',
                ),
                _buildStatCard(
                  'Upcoming Checkups',
                  '8',
                  Icons.calendar_today,
                  Colors.blue,
                  'Today: 2',
                ),
                _buildStatCard(
                  'Pending Records',
                  '5',
                  Icons.folder_open,
                  Colors.orange,
                  'Need review',
                ),
                _buildStatCard(
                  'Due This Month',
                  '4',
                  Icons.child_care,
                  Colors.green,
                  'Expected deliveries',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Today's Schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to calendar
                    final bottomNav = context.findAncestorStateOfType<State<StatefulWidget>>();
                    // This would need proper implementation to switch tabs
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppColors.brandSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule List
            _buildScheduleItem(
              '09:00 AM',
              'Prenatal Checkup',
              'Maria Santos',
              '24 weeks',
              Colors.blue,
            ),
            const SizedBox(height: 10),
            _buildScheduleItem(
              '10:30 AM',
              'Ultrasound Review',
              'Juana Dela Cruz',
              '32 weeks',
              Colors.purple,
            ),
            const SizedBox(height: 10),
            _buildScheduleItem(
              '01:00 PM',
              'Lab Results Discussion',
              'Ana Lopez',
              '16 weeks',
              Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildScheduleItem(
              '02:30 PM',
              'New Patient Registration',
              'New Mother',
              'Initial visit',
              Colors.green,
            ),

            const SizedBox(height: 30),

            // Recent Activity
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildActivityItem(
              'Ultrasound uploaded by Maria Santos',
              '10 minutes ago',
              Icons.photo,
              Colors.purple.shade100,
              Colors.purple,
            ),
            const SizedBox(height: 10),
            _buildActivityItem(
              'Lab results added for Juana Dela Cruz',
              '1 hour ago',
              Icons.science,
              Colors.orange.shade100,
              Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildActivityItem(
              'Checkup completed for Ana Lopez',
              '3 hours ago',
              Icons.medical_services,
              Colors.blue.shade100,
              Colors.blue,
            ),

            const SizedBox(height: 30),

            // Quick Actions
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Add Mother',
                    Icons.person_add,
                    Colors.purple,
                    () {
                      // Navigate to add mother
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Schedule Checkup',
                    Icons.event,
                    Colors.blue,
                    () {
                      // Navigate to schedule
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Review Records',
                    Icons.folder,
                    Colors.orange,
                    () {
                      // Navigate to records tab
                      final bottomNav = context.findAncestorStateOfType<State<StatefulWidget>>();
                      // This would need proper implementation to switch tabs
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Generate Report',
                    Icons.bar_chart,
                    Colors.green,
                    () {
                      // Generate report
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String time, String title, String patient, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 2,
            height: 40,
            color: color,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      patient,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}