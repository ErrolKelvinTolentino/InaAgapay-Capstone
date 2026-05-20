import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../services/auth_storage.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final accountId = await AuthStorage.getUserId();
      if (accountId == null || !mounted) return;
      _accountId = accountId;
      final notifications = await NotificationService.getNotifications(accountId);
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_accountId == null) return;
    await NotificationService.markAllAsRead(_accountId!);
    if (!mounted) return;
    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
    });
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'checkup_reminder':
        return Icons.medical_services_outlined;
      case 'vaccine_reminder':
        return Icons.vaccines_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'checkup_reminder':
        return AppColors.brandPrimary;
      case 'vaccine_reminder':
        return AppColors.brandAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;
                      final type = n['type'] as String?;
                      final createdAt = DateTime.tryParse(n['created_at'] ?? '');
                      final timeText = createdAt != null
                          ? DateFormat('MMM d, h:mm a').format(createdAt.toLocal())
                          : '';

                      return GestureDetector(
                        onTap: () async {
                          if (!isRead) {
                            await NotificationService.markAsRead(n['notification_id']);
                            setState(() => n['is_read'] = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : AppColors.brandPrimary.withValues(alpha:0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: isRead ? null : Border.all(color: AppColors.brandPrimary.withValues(alpha:0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_iconForType(type), color: _colorForType(type), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n['message'] ?? '',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeText,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
