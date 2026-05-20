import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getNotifications(int accountId, {int limit = 50}) async {
    final result = await _client
        .from('notifications')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<int> getUnreadCount(int accountId) async {
    final result = await _client
        .from('notifications')
        .select('notification_id')
        .eq('account_id', accountId)
        .eq('is_read', false);
    return (result as List).length;
  }

  static Future<void> markAsRead(int notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('notification_id', notificationId);
  }

  static Future<void> markAllAsRead(int accountId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('account_id', accountId)
        .eq('is_read', false);
  }

  static RealtimeChannel subscribeToNotifications(int accountId, void Function(Map<String, dynamic>) onNew) {
    return _client
        .channel('notifications:$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (payload) {
            onNew(payload.newRecord);
          },
        )
        .subscribe();
  }
}
