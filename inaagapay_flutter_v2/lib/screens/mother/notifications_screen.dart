import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../services/auth_storage.dart';
import '../../theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int? _accountId;
  bool _isUnlinked = false;

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

      final motherId = await AuthStorage.getMotherId();
      bool unlinked = false;
      if (motherId != null) {
        final motherResponse = await SupabaseService.client
            .from('mothers')
            .select('assigned_bhc_id')
            .eq('mother_id', motherId)
            .maybeSingle();
        unlinked = motherResponse == null || motherResponse['assigned_bhc_id'] == null;
      }

      final notifications = await NotificationService.getNotifications(accountId);
      if (!mounted) return;
      setState(() {
        _isUnlinked = unlinked;
        _notifications = List<Map<String, dynamic>>.from(notifications);
        if (_isUnlinked) {
          _notifications.insert(0, {
            'notification_id': -999,
            'title': LanguageService.translate('Action Required: Link BHC', 'Kailangang Aksyon: I-link ang BHC'),
            'message': LanguageService.translate(
              'Your account is not linked to a Barangay Health Center. Tap to view linking instructions.',
              'Ang iyong account ay hindi naka-link sa isang Barangay Health Center. Pindutin para sa detalye ng pag-link.'
            ),
            'type': 'unlinked_bhc',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
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
      case 'unlinked_bhc':
        return Icons.warning_amber_rounded;
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
      case 'unlinked_bhc':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showHowToLinkDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.brandPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LanguageService.translate('How to Link to a BHC', 'Paano I-link sa BHC'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                LanguageService.translate(
                  'To link your account to a Barangay Health Center (BHC) and begin official midwife monitoring, follow these steps:',
                  'Upang i-link ang iyong account sa isang Barangay Health Center (BHC) at magsimula ng opisyal na pagsubaybay ng midwife, sundin ang mga hakbang na ito:',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildStepRow(
                  '1',
                  LanguageService.translate('Visit your nearest Barangay Health Center (BHC).',
                      'Pumunta sa iyong pinakamalapit na Barangay Health Center (BHC).')),
              const SizedBox(height: 12),
              _buildStepRow(
                  '2',
                  LanguageService.translate('Provide the midwife with your registered email address or phone number.',
                      'Ibigay sa midwife ang iyong rehistradong email address o numero ng telepono.')),
              const SizedBox(height: 12),
              _buildStepRow(
                  '3',
                  LanguageService.translate('The midwife will complete your linking process in the system, and your record will update automatically.',
                      'Tatapusin ng midwife ang proseso ng pag-link sa system, at awtomatikong mag-a-update ang iyong tala.')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(LanguageService.translate('Got it!', 'Nakuha ko!')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.brandText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
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
                      final isUnlinkedBhc = type == 'unlinked_bhc';
                      final createdAt = DateTime.tryParse(n['created_at'] ?? '');
                      final timeText = createdAt != null
                          ? DateFormat('MMM d, h:mm a').format(createdAt.toLocal())
                          : '';

                      return GestureDetector(
                        onTap: () async {
                          if (isUnlinkedBhc) {
                            _showHowToLinkDialog();
                            return;
                          }
                          if (!isRead) {
                            await NotificationService.markAsRead(n['notification_id']);
                            setState(() => n['is_read'] = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnlinkedBhc
                                ? AppColors.warning.withValues(alpha: 0.05)
                                : (isRead ? Colors.white : AppColors.brandPrimary.withValues(alpha:0.06)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnlinkedBhc
                                  ? AppColors.warning.withValues(alpha: 0.25)
                                  : (isRead ? Colors.transparent : AppColors.brandPrimary.withValues(alpha:0.15)),
                            ),
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
                                    if (!isUnlinkedBhc) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        timeText,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isRead && !isUnlinkedBhc)
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
