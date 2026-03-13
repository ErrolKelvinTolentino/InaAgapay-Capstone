// lib/widgets/vaccine_schedule_status.dart

import 'package:flutter/material.dart';

enum VaccineScheduleStatus {
  onSchedule,
  overdue,
  completed,
  pending,
}

class VaccineScheduleStatusBadge extends StatelessWidget {
  final VaccineScheduleStatus status;

  const VaccineScheduleStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case VaccineScheduleStatus.onSchedule:
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'On Schedule';
        icon = Icons.check_circle_outline;
        break;
      case VaccineScheduleStatus.overdue:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Overdue';
        icon = Icons.warning_amber_rounded;
        break;
      case VaccineScheduleStatus.completed:
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'Completed';
        icon = Icons.verified;
        break;
      case VaccineScheduleStatus.pending:
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        label = 'Pending';
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}