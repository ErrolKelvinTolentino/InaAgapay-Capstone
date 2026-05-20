// lib/screens/midwife/midwife_schedules_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';

class MidwifeSchedulesScreen extends StatefulWidget {
  const MidwifeSchedulesScreen({super.key});

  @override
  State<MidwifeSchedulesScreen> createState() => _MidwifeSchedulesScreenState();
}

class _MidwifeSchedulesScreenState extends State<MidwifeSchedulesScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late Future<List<Map<String, dynamic>>> _schedulesFuture;
  int? _midwifeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMidwifeId();
  }

  Future<void> _loadMidwifeId() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId != null) {
        final response = await Supabase.instance.client
            .from('midwives')
            .select('midwife_id')
            .eq('account_id', accountId)
            .maybeSingle();

        if (response != null && response['midwife_id'] != null) {
          setState(() {
            _midwifeId = response['midwife_id'] as int;
            _isLoading = false;
          });
          _refreshSchedules();
        } else {
          setState(() {
            _midwifeId = null;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading midwife ID: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchSchedulesForDate(
      DateTime date) async {
    if (_midwifeId == null) return [];

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final midwifeIdValue = _midwifeId!;

      // Fetch prenatal checkups whose NEXT scheduled date falls on this day
      final checkupsResponse = await Supabase.instance.client
          .from('prenatal_checkups')
          .select('''
            prenatal_checkup_id,
            checkup_datetime,
            next_schedule,
            remarks,
            pregnancy:pregnancy_id (
              mother:mother_id (
                account:account_id (
                  first_name,
                  last_name
                )
              )
            )
          ''')
          .eq('midwife_id', midwifeIdValue)
          .eq('next_schedule', formattedDate)
          .order('next_schedule');

      // Also fetch from checkup_schedule table (only scheduled/upcoming entries)
      final scheduleResponse =
          await Supabase.instance.client.from('checkup_schedule').select('''
            schedule_id,
            scheduled_date,
            notes,
            status,
            mother:mother_id (
              account:account_id (
                first_name,
                last_name
              )
            )
          ''').eq('scheduled_date', formattedDate).eq('status', 'scheduled').order('scheduled_date');

      final List<Map<String, dynamic>> schedules = [];

      // Add prenatal checkups
      for (final checkup in checkupsResponse) {
        final pregnancy = checkup['pregnancy'] as Map<String, dynamic>?;
        final mother = pregnancy?['mother'] as Map<String, dynamic>?;
        final account = mother?['account'] as Map<String, dynamic>?;
        final firstName = account?['first_name']?.toString() ?? '';
        final lastName = account?['last_name']?.toString() ?? '';
        final motherName = '$firstName $lastName'.trim();

        schedules.add({
          'time': 'All Day',
          'mother_name': motherName.isNotEmpty ? motherName : 'Unknown Mother',
          'type': 'Prenatal Checkup',
          'status': 'upcoming',
          'notes': checkup['remarks']?.toString(),
          'icon': Icons.medical_services,
          'next_schedule': checkup['next_schedule']?.toString(),
        });
      }

      // Add scheduled checkups
      for (final schedule in scheduleResponse) {
        final mother = schedule['mother'] as Map<String, dynamic>?;
        final account = mother?['account'] as Map<String, dynamic>?;
        final firstName = account?['first_name']?.toString() ?? '';
        final lastName = account?['last_name']?.toString() ?? '';
        final motherName = '$firstName $lastName'.trim();

        final status = schedule['status']?.toString() ?? 'scheduled';
        final displayStatus = status == 'scheduled' ? 'upcoming' : status;

        schedules.add({
          'time': 'All Day',
          'mother_name': motherName.isNotEmpty ? motherName : 'Unknown Mother',
          'type': 'Scheduled Checkup',
          'status': displayStatus,
          'notes': schedule['notes']?.toString(),
          'icon': Icons.calendar_today,
        });
      }

      // Sort by time (All Day events go to bottom)
      schedules.sort((a, b) {
        final timeA = a['time'] as String;
        final timeB = b['time'] as String;
        if (timeA == 'All Day') return 1;
        if (timeB == 'All Day') return -1;
        return timeA.compareTo(timeB);
      });

      return schedules;
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      return [];
    }
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
      case 'prenatal checkup':
        return Icons.pregnant_woman;
      case 'vaccination':
        return Icons.vaccines;
      case 'scheduled checkup':
        return Icons.calendar_today;
      case 'followup':
        return Icons.health_and_safety;
      default:
        return Icons.medical_services;
    }
  }

  void _refreshSchedules() {
    setState(() {
      _schedulesFuture = fetchSchedulesForDate(_selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.brandPrimary,
          ),
        ),
      );
    }

    if (_midwifeId == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Midwife profile not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please ensure your account is properly set up.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMidwifeId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshSchedules();
            return Future.value();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 📅 CALENDAR SECTION
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TableCalendar(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
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
                        color: AppColors.brandPrimary.withValues(alpha: 0.2),
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

                const SizedBox(height: 16),

                /// 📋 SELECTED DATE HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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

                const SizedBox(height: 12),

                /// 📋 SCHEDULE LIST
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _schedulesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            color: AppColors.brandPrimary,
                          ),
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
                              color: AppColors.error,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading schedules',
                              style: TextStyle(
                                color: AppColors.error,
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
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              /// 📅 NO SCHEDULES ILLUSTRATION
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  size: 50,
                                  color: AppColors.brandPrimary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                DateFormat('EEEE, MMMM d').format(_selectedDay),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No scheduled appointments',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Enjoy your free time! 🎉',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: schedules.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];

                        return ScheduleCard(
                          time: schedule['time'] as String,
                          motherName: schedule['mother_name'] as String,
                          scheduleType: schedule['type'] as String,
                          status: schedule['status'] as String,
                          notes: schedule['notes'] as String?,
                          icon: schedule['icon'] as IconData? ??
                              _getScheduleIcon(schedule['type'] as String),
                          statusColor:
                              _getStatusColor(schedule['status'] as String),
                          nextSchedule: schedule['next_schedule'] as String?,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
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
  final String? nextSchedule;

  const ScheduleCard({
    super.key,
    required this.time,
    required this.motherName,
    required this.scheduleType,
    required this.status,
    this.notes,
    required this.icon,
    required this.statusColor,
    this.nextSchedule,
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🕐 TIME INDICATOR
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                    textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
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

                /// 📅 NEXT SCHEDULE (if available)
                if (nextSchedule != null && nextSchedule!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Next: ${DateFormat('MMM d, yyyy').format(DateTime.parse(nextSchedule!))}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],

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
