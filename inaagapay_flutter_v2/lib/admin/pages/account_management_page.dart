import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/account_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<AccountModel>> _accountsFuture;
  String _search = '';

  static const _tabs = [
    ('All Staff', 'all'),
    ('Admins', 'admin'),
    ('Midwives', 'midwife'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(_reload);
    });
    _reload();
  }

  void _reload() {
    final type = _tabs[_tabCtrl.index].$2;
    _accountsFuture = AdminService.getAccounts(
      type: type == 'all' ? null : type,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600
            ? 16.0
            : constraints.maxWidth < 900
            ? 20.0
            : 24.0;
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTabBar(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildTable()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Management',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Manage admin and midwife accounts',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.softPink.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPink.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by name or email…',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.textLight,
          size: 20,
        ),
        filled: true,
        fillColor: AppTheme.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: (v) => setState(() => _search = v.toLowerCase()),
    );
  }

  Widget _buildTable() {
    return FutureBuilder<List<AccountModel>>(
      future: _accountsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPink),
          );
        }
        if (snap.hasError) {
          return _errorWidget(snap.error.toString());
        }

        final all = snap.data ?? [];
        final filtered = _search.isEmpty
            ? all
            : all
                  .where(
                    (a) =>
                        a.fullName.toLowerCase().contains(_search) ||
                        a.email.toLowerCase().contains(_search),
                  )
                  .toList();

        if (filtered.isEmpty) {
          return _emptyState();
        }

        return Container(
          decoration: AppTheme.cardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppTheme.softPink.withAlpha(120),
                  ),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 68,
                  columnSpacing: 20,
                  columns: [
                    _col('Name'),
                    _col('Email'),
                    _col('Role'),
                    _col('Status'),
                    _col('Last Login'),
                    _col('Actions'),
                  ],
                  rows: filtered.map((a) => _buildRow(ctx, a)).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(
      label,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppTheme.textPrimary,
      ),
    ),
  );

  DataRow _buildRow(BuildContext context, AccountModel a) {
    final fmtDate = a.lastLoginAt != null
        ? DateFormat('MMM d, yyyy').format(a.lastLoginAt!.toLocal())
        : '—';

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryPink.withAlpha(30),
                child: Text(
                  a.initials,
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryPink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  a.fullName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            a.email,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        DataCell(_roleBadge(a.accountType)),
        DataCell(_statusBadge(a.status)),
        DataCell(
          Text(
            fmtDate,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        DataCell(_actionButtons(context, a)),
      ],
    );
  }

  Widget _roleBadge(String type) {
    final colors = <String, (Color, Color)>{
      'admin': (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
      'midwife': (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'mother': (AppTheme.softPink, AppTheme.primaryPink),
    };
    final c = colors[type] ?? (AppTheme.softPink, AppTheme.primaryPink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c.$2,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    switch (status) {
      case 'active':
        bg = AppTheme.successLight;
        fg = AppTheme.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'inactive':
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF616161);
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = AppTheme.dangerLight;
        fg = AppTheme.danger;
        icon = Icons.block_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, AccountModel a) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle status
        _iconBtn(
          icon: a.status == 'active'
              ? Icons.person_off_rounded
              : Icons.person_rounded,
          tooltip: a.status == 'active' ? 'Deactivate' : 'Activate',
          color: a.status == 'active' ? AppTheme.warning : AppTheme.success,
          onTap: () => _confirmToggle(context, a),
        ),
        const SizedBox(width: 4),
        // Reset password
        _iconBtn(
          icon: Icons.lock_reset_rounded,
          tooltip: 'Reset Password',
          color: AppTheme.info,
          onTap: () => _showResetPasswordDialog(context, a),
        ),
        const SizedBox(width: 4),
        // Delete
        _iconBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          color: AppTheme.danger,
          onTap: () => _confirmDelete(context, a),
        ),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  void _confirmToggle(BuildContext context, AccountModel a) {
    final newStatus = a.status == 'active' ? 'inactive' : 'active';
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: newStatus == 'inactive'
            ? 'Deactivate Account'
            : 'Activate Account',
        message:
            'Are you sure you want to ${newStatus == 'inactive' ? 'deactivate' : 'activate'} '
            '${a.fullName}?',
        confirmLabel: newStatus == 'inactive' ? 'Deactivate' : 'Activate',
        confirmColor: newStatus == 'inactive'
            ? AppTheme.warning
            : AppTheme.success,
        onConfirm: () async {
          await AdminService.updateAccountStatus(a.accountId, newStatus);
          if (mounted) setState(_reload);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, AccountModel a) {
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Account',
        message: 'Permanently delete ${a.fullName}? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: AppTheme.danger,
        onConfirm: () async {
          await AdminService.deleteAccount(a.accountId);
          if (mounted) setState(_reload);
        },
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, AccountModel a) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set a new password for ${a.fullName}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                obscureText: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                await AdminService.resetPassword(a.accountId, ctrl.text);
                if (mounted) _showSnack('Password reset successfully.');
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: AppTheme.borderColor,
          ),
          const SizedBox(height: 12),
          Text(
            'No accounts found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            'Try a different filter or search term',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(String err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.danger,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load accounts',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            err,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable confirm dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final Future<void> Function() onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Text(
        widget.message,
        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  final nav = Navigator.of(context);
                  try {
                    await widget.onConfirm();
                  } finally {
                    nav.pop();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.confirmColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
