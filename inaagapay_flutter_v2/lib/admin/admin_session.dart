/// Holds the currently logged-in admin's session in memory.
/// In a production app you'd persist this to secure storage.
class AdminSession {
  static Map<String, dynamic>? _currentAdmin;

  static Map<String, dynamic>? get currentAdmin => _currentAdmin;
  static bool get isLoggedIn => _currentAdmin != null;

  static int? get accountId => _currentAdmin != null
      ? (_currentAdmin!['account_id'] as num).toInt()
      : null;

  static String get displayName {
    if (_currentAdmin == null) return 'Admin';
    final first = _currentAdmin!['first_name'] as String? ?? '';
    final last = _currentAdmin!['last_name'] as String? ?? '';
    return '$first $last'.trim();
  }

  static String get email => _currentAdmin?['email_address'] as String? ?? '';

  static void setAdmin(Map<String, dynamic> admin) => _currentAdmin = admin;

  static void clear() => _currentAdmin = null;
}
