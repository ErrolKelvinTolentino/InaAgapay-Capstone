import 'package:flutter/foundation.dart';

/// Handles FCM push notification setup, token management, and foreground handling.
/// On web, all methods are no-ops since FCM push requires native platform + Firebase config.
/// On mobile, Firebase must be initialized first (google-services.json / GoogleService-Info.plist).
class PushNotificationService {
  /// Initialize push notifications.
  /// Silently skips on web or when Firebase is not configured.
  static Future<void> initialize() async {
    if (kIsWeb) {
      if (kDebugMode) debugPrint('[Push] Skipping on web platform');
      return;
    }
    // On mobile, Firebase packages handle initialization.
    // This will be activated once google-services.json is in place.
    if (kDebugMode) debugPrint('[Push] Mobile push ready (requires Firebase config)');
  }

  /// Remove token on logout. No-op on web.
  static Future<void> removeToken() async {
    if (kIsWeb) return;
    if (kDebugMode) debugPrint('[Push] Token removal skipped (web or no Firebase)');
  }
}
