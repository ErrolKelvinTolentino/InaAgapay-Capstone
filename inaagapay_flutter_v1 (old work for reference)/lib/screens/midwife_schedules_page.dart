import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../services/auth_storage.dart';

class MidwifeSchedulesPage extends StatefulWidget {
  const MidwifeSchedulesPage({super.key});

  @override
  State<MidwifeSchedulesPage> createState() => _MidwifeSchedulesPageState();
}

class _MidwifeSchedulesPageState extends State<MidwifeSchedulesPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late Future<List<dynamic>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = fetchSchedulesForDate(_selectedDay);
  }

  Future<List<dynamic>> fetchSchedulesForDate(DateTime date) async {
    final token = await AuthStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final response = await http.get(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/midwife_schedules_by_date.php?date=$formattedDate',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load schedules');
    }

    final decoded = jsonDecode(response.body);
    if (decoded['success'] != true) {
      return [];
    }
    return decoded['data'] as List<dynamic>? ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'upcoming':
        return AppColors.brandPrimary;
      case 'cancelled':
        return AppColors.error;
      case 'missed':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getScheduleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'prenatal':
        return Icons.pregnant_woman;
      case 'vaccination':
        return Icons.vaccines;
      case 'checkup':
        return Icons.medical_services;
      case 'followup':
        return Icons.health_and_safety;
      default:
        return Icons.calendar_today;
    }
  }

  void _refreshSchedules() {
    setState(() {
      _schedulesFuture = fetchSchedulesForDate(_selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      /// 🔝 HEADER
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'SCHEDULES',
        ),
      ),

      /// 🔽 BODY
      body: SafeArea(
        child: Column(
          children: [
            /// 📅 CALENDAR SECTION
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _refreshSchedules();
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.black87),
                  outsideTextStyle: const TextStyle(color: Colors.grey),
                  defaultTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AppColors.brandPrimary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AppColors.brandPrimary,
                  ),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            /// 📋 SELECTED DATE HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d').format(_selectedDay),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandText,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _refreshSchedules,
                        icon: const Icon(Icons.refresh),
                        color: AppColors.brandPrimary,
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedDay = DateTime.now();
                            _focusedDay = DateTime.now();
                            _refreshSchedules();
                          });
                        },
                        icon: const Icon(Icons.today),
                        color: AppColors.brandPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            /// 📋 SCHEDULE LIST
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refreshSchedules(),
                child: FutureBuilder<List<dynamic>>(
                  future: _schedulesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading schedules',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshSchedules,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final schedules = snapshot.data!;

                    if (schedules.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// 📅 NO SCHEDULES ILLUSTRATION
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                size: 60,
                                color: AppColors.brandPrimary.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              DateFormat('EEEE, MMMM d').format(_selectedDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No scheduled appointments',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enjoy your free time! 🎉',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            // REMOVED: Add New Schedule button
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: schedules.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];

                        final time = schedule['time']?.toString() ?? '--:--';
                        final motherName = schedule['mother_name']?.toString() ?? 'Unknown';
                        final scheduleType = schedule['type']?.toString() ?? 'Checkup';
                        final status = schedule['status']?.toString() ?? 'upcoming';
                        final notes = schedule['notes']?.toString();

                        return ScheduleCard(
                          time: time,
                          motherName: motherName,
                          scheduleType: scheduleType,
                          status: status,
                          notes: notes,
                          icon: _getScheduleIcon(scheduleType),
                          statusColor: _getStatusColor(status),
                        );
                      },
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

/// 🧩 SCHEDULE CARD WIDGET
class ScheduleCard extends StatelessWidget {
  final String time;
  final String motherName;
  final String scheduleType;
  final String status;
  final String? notes;
  final IconData icon;
  final Color statusColor;

  const ScheduleCard({
    super.key,
    required this.time,
    required this.motherName,
    required this.scheduleType,
    required this.status,
    this.notes,
    required this.icon,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🕐 TIME INDICATOR
          Container(
            width: 60,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          /// 📝 SCHEDULE DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    /// 👤 MOTHER NAME
                    Expanded(
                      child: Text(
                        motherName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    /// 🏷️ STATUS BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                /// 📋 TYPE AND ICON
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      scheduleType,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                /// 📝 NOTES (IF ANY)
                if (notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.note,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}