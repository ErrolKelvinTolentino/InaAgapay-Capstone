import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_model.dart';
import '../models/bhc_model.dart';
import 'supabase_service.dart';

class AdminService {
  static SupabaseClient get _db => SupabaseService.client;

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> loginAdmin(
    String email,
    String password,
  ) async {
    final result = await _db
        .from('accounts')
        .select(
          'account_id, email_address, first_name, last_name, password_hash, '
          'account_type, is_verified, status',
        )
        .eq('email_address', email.trim())
        .eq('account_type', 'admin')
        .maybeSingle();

    if (result == null) return null;
    if (result['is_verified'] != true) return null;
    if (result['status'] != 'active') return null;

    final storedHash = result['password_hash'] as String? ?? '';
    if (storedHash.isEmpty || !BCrypt.checkpw(password, storedHash)) {
      return null;
    }

    final accountId = (result['account_id'] as num).toInt();

    await _db
        .from('accounts')
        .update({'last_login_at': DateTime.now().toIso8601String()})
        .eq('account_id', accountId);

    await _logAudit(
      accountId: accountId,
      action: 'LOGIN',
      description: 'Admin logged in',
    );

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, int>> getDashboardCounts() async {
    final results = await Future.wait([
      _db
          .from('accounts')
          .select('account_id')
          .eq('account_type', 'mother')
          .eq('status', 'active'),
      _db
          .from('accounts')
          .select('account_id')
          .eq('account_type', 'midwife')
          .eq('status', 'active'),
      _db
          .from('accounts')
          .select('account_id')
          .eq('account_type', 'admin')
          .eq('status', 'active'),
      _db.from('pregnancies').select('pregnancy_id'),
      _db.from('children').select('child_id'),
    ]);

    return {
      'mothers': (results[0] as List).length,
      'midwives': (results[1] as List).length,
      'admins': (results[2] as List).length,
      'pregnancies': (results[3] as List).length,
      'children': (results[4] as List).length,
    };
  }

  static Future<Map<String, int>> getRiskDistribution() async {
    final rows = await _db
        .from('pregnancies')
        .select('pregnancy_risk_level')
        .eq('status', 'ongoing');

    final Map<String, int> counts = {
      'low': 0,
      'medium': 0,
      'high': 0,
      'unknown': 0,
    };
    for (final row in rows as List) {
      final level = (row['pregnancy_risk_level'] as String?) ?? 'unknown';
      counts[level] = (counts[level] ?? 0) + 1;
    }
    return counts;
  }

  static Future<List<Map<String, dynamic>>> getRecentAuditTrail({
    int limit = 10,
  }) async {
    final result = await _db
        .from('audit_trail')
        .select(
          'audit_id, action, description, action_timestamp, '
          'accounts!audit_trail_account_id_fkey(first_name, last_name, account_type)',
        )
        .order('action_timestamp', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCOUNTS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<AccountModel>> getAccounts({String? type}) async {
    var query = _db
        .from('accounts')
        .select(
          'account_id, email_address, account_type, first_name, middle_name, '
          'last_name, extension_name, phone_number, is_verified, status, '
          'last_login_at, created_at',
        );

    if (type != null && type != 'all') {
      query = query.eq('account_type', type) as dynamic;
    }

    final result = await (query as dynamic).order(
      'created_at',
      ascending: false,
    );
    return (result as List).map((j) => AccountModel.fromJson(j)).toList();
  }

  static Future<void> updateAccountStatus(int accountId, String status) async {
    await _db
        .from('accounts')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('account_id', accountId);

    await _logAudit(
      accountId: accountId,
      action: 'UPDATE_STATUS',
      tableName: 'accounts',
      description: 'Account status changed to $status',
    );
  }

  static Future<void> resetPassword(int accountId, String newPassword) async {
    final hash = BCrypt.hashpw(newPassword, BCrypt.gensalt(logRounds: 10));
    await _db
        .from('accounts')
        .update({
          'password_hash': hash,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('account_id', accountId);

    await _logAudit(
      accountId: accountId,
      action: 'RESET_PASSWORD',
      tableName: 'accounts',
      description: 'Password reset for account ID $accountId',
    );
  }

  static Future<void> deleteAccount(int accountId) async {
    await _db.from('accounts').delete().eq('account_id', accountId);

    await _logAudit(
      accountId: accountId,
      action: 'DELETE_ACCOUNT',
      tableName: 'accounts',
      description: 'Account ID $accountId deleted',
    );
  }

  static Future<void> createAccount({
    required String accountType,
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extensionName,
    String? phoneNumber,
    int? bhcId,
  }) async {
    final hash = BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10));

    final result = await _db
        .from('accounts')
        .insert({
          'email_address': email.trim(),
          'password_hash': hash,
          'account_type': accountType,
          'first_name': firstName.trim(),
          'middle_name': middleName?.trim(),
          'last_name': lastName.trim(),
          'extension_name': extensionName?.trim(),
          'phone_number': phoneNumber?.trim(),
          'is_verified': true,
          'status': 'active',
        })
        .select('account_id')
        .single();

    final newAccountId = (result['account_id'] as num).toInt();

    if (accountType == 'midwife' && bhcId != null) {
      await _db.from('midwives').insert({
        'account_id': newAccountId,
        'assigned_bhc_id': bhcId,
      });
    }

    await _logAudit(
      accountId: newAccountId,
      action: 'CREATE_ACCOUNT',
      tableName: 'accounts',
      description: 'New $accountType account created: $email',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BHC (Barangay Health Center)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<BhcModel>> getBHCs() async {
    final result = await _db
        .from('bhc')
        .select('bhc_id, bhc_name')
        .order('bhc_name');
    return result.map<BhcModel>((j) => BhcModel.fromJson(j)).toList();
  }

  static Future<void> addBHC(String name) async {
    await _db.from('bhc').insert({'bhc_name': name.trim()});
  }

  static Future<void> updateBHC(int bhcId, String name) async {
    await _db.from('bhc').update({'bhc_name': name.trim()}).eq('bhc_id', bhcId);
  }

  static Future<void> deleteBHC(int bhcId) async {
    await _db.from('bhc').delete().eq('bhc_id', bhcId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MIDWIFE ASSIGNMENT
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getMidwivesWithAssignments() async {
    final result = await _db
        .from('accounts')
        .select(
          'account_id, first_name, middle_name, last_name, email_address, status, '
          'midwives(midwife_id, assigned_bhc_id)',
        )
        .eq('account_type', 'midwife')
        .order('first_name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> assignMidwifeToBHC(int accountId, int bhcId) async {
    final existing = await _db
        .from('midwives')
        .select('midwife_id')
        .eq('account_id', accountId)
        .maybeSingle();

    if (existing != null) {
      await _db
          .from('midwives')
          .update({'assigned_bhc_id': bhcId})
          .eq('account_id', accountId);
    } else {
      await _db.from('midwives').insert({
        'account_id': accountId,
        'assigned_bhc_id': bhcId,
      });
    }

    await _logAudit(
      accountId: accountId,
      action: 'ASSIGN_MIDWIFE',
      tableName: 'midwives',
      description: 'Midwife (account $accountId) assigned to BHC $bhcId',
    );
  }

  static Future<void> removeMidwifeAssignment(int accountId) async {
    await _db.from('midwives').delete().eq('account_id', accountId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUDIT TRAIL
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAuditTrail({
    int limit = 100,
    int offset = 0,
    String? actionFilter,
  }) async {
    final base = _db
        .from('audit_trail')
        .select(
          'audit_id, action, table_name, description, action_timestamp, ip_address, '
          'accounts!audit_trail_account_id_fkey(first_name, last_name, email_address, account_type)',
        );

    final List result;
    if (actionFilter != null && actionFilter.isNotEmpty) {
      result = await base
          .eq('action', actionFilter)
          .order('action_timestamp', ascending: false)
          .range(offset, offset + limit - 1);
    } else {
      result = await base
          .order('action_timestamp', ascending: false)
          .range(offset, offset + limit - 1);
    }
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> _logAudit({
    required int accountId,
    required String action,
    String? tableName,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? description,
  }) async {
    try {
      await _db.from('audit_trail').insert({
        'account_id': accountId,
        'action': action,
        'table_name': tableName,
        'old_data': oldData,
        'new_data': newData,
        'description': description,
        'action_timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-critical — don't let audit failure block the main operation
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BACKUP / EXPORT
  // ══════════════════════════════════════════════════════════════════════════

  static const List<String> exportableTables = [
    'accounts',
    'bhc',
    'midwives',
    'mothers',
    'pregnancies',
    'prenatal_checkups',
    'children',
    'birth_details',
    'vaccines',
    'immunization_record',
    'audit_trail',
  ];

  static Future<Map<String, dynamic>> exportTable(String table) async {
    final data = await _db.from(table).select('*');
    return {
      'table': table,
      'exported_at': DateTime.now().toIso8601String(),
      'rows': data,
    };
  }

  static Future<Map<String, int>> getTableCounts() async {
    final Map<String, int> counts = {};
    for (final t in exportableTables) {
      try {
        final rows = await _db.from(t).select('*');
        counts[t] = (rows as List).length;
      } catch (_) {
        counts[t] = 0;
      }
    }
    return counts;
  }
}
