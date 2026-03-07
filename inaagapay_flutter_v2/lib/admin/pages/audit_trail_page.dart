import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  late Future<List<Map<String, dynamic>>> _auditFuture;
  String _search = '';
  String? _actionFilter;
  int _page = 0;
  static const int _pageSize = 50;

  static const _actionColors = <String, Color>{
    'LOGIN': Color(0xFF1565C0),
    'CREATE_ACCOUNT': Color(0xFF2E7D32),
    'DELETE_ACCOUNT': Color(0xFFC62828),
    'UPDATE_STATUS': Color(0xFFE65100),
    'RESET_PASSWORD': Color(0xFF6A1B9A),
    'ASSIGN_MIDWIFE': Color(0xFF00695C),
    'BACKUP': Color(0xFF37474F),
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _auditFuture = AdminService.getAuditTrail(
      limit: _pageSize,
      offset: _page * _pageSize,
      actionFilter: _actionFilter,
    );
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
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildTable()),
              _buildPagination(),
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
                'Audit Trail',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Track all system actions and user activities',
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

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Search
        SizedBox(
          width: 280,
          child: TextField(
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search by action or description…',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.textLight,
              ),
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryPink,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() {
              _search = v.toLowerCase();
            }),
          ),
        ),
        // Action filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _actionFilter,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
              hint: Text(
                'All Actions',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'All Actions',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
                ..._actionColors.keys.map(
                  (a) => DropdownMenuItem(
                    value: a,
                    child: Text(a, style: GoogleFonts.poppins(fontSize: 13)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                _actionFilter = v;
                _page = 0;
                _reload();
              }),
            ),
          ),
        ),
        if (_actionFilter != null)
          InkWell(
            onTap: () => setState(() {
              _actionFilter = null;
              _page = 0;
              _reload();
            }),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.dangerLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppTheme.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Clear Filter',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _auditFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPink),
          );
        }
        if (snap.hasError) {
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
                  'Failed to load audit trail',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var rows = snap.data ?? [];
        if (_search.isNotEmpty) {
          rows = rows.where((r) {
            final action = (r['action'] as String? ?? '').toLowerCase();
            final desc = (r['description'] as String? ?? '').toLowerCase();
            final acct = r['accounts'] as Map<String, dynamic>?;
            final name = acct != null
                ? '${acct['first_name'] ?? ''} ${acct['last_name'] ?? ''}'
                      .toLowerCase()
                : '';
            return action.contains(_search) ||
                desc.contains(_search) ||
                name.contains(_search);
          }).toList();
        }

        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: AppTheme.borderColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No audit records found',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
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
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 70,
                  columnSpacing: 16,
                  columns: [
                    _col('#'),
                    _col('Timestamp'),
                    _col('Action'),
                    _col('Performed By'),
                    _col('Description'),
                    _col('IP Address'),
                  ],
                  rows: rows.asMap().entries.map((e) {
                    return _buildRow(e.key + 1 + (_page * _pageSize), e.value);
                  }).toList(),
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

  DataRow _buildRow(int index, Map<String, dynamic> row) {
    final action = row['action'] as String? ?? '';
    final desc = row['description'] as String? ?? '—';
    final ts = row['action_timestamp'] as String? ?? '';
    final ip = row['ip_address'] as String? ?? '—';
    final acct = row['accounts'] as Map<String, dynamic>?;
    final name = acct != null
        ? '${acct['first_name'] ?? ''} ${acct['last_name'] ?? ''}'.trim()
        : 'System';
    final role = acct?['account_type'] as String? ?? '';

    final dt = DateTime.tryParse(ts);
    final fmtDate = dt != null
        ? DateFormat('MMM d, yyyy').format(dt.toLocal())
        : '—';
    final fmtTime = dt != null
        ? DateFormat('hh:mm:ss a').format(dt.toLocal())
        : '';

    final actionColor = _actionColors[action] ?? AppTheme.primaryPink;

    return DataRow(
      color: WidgetStateProperty.resolveWith(
        (s) => index.isOdd ? AppTheme.bg.withAlpha(80) : AppTheme.white,
      ),
      cells: [
        DataCell(
          Text(
            index.toString(),
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textLight),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fmtDate,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                fmtTime,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
        DataCell(_actionBadge(action, actionColor)),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Unknown' : name,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (role.isNotEmpty)
                Text(
                  role[0].toUpperCase() + role.substring(1),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppTheme.textLight,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              desc,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        DataCell(
          Text(
            ip,
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: AppTheme.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBadge(String action, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        action.replaceAll('_', ' '),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page == 0
                ? null
                : () => setState(() {
                    _page--;
                    _reload();
                  }),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.softPink,
              foregroundColor: AppTheme.primaryPink,
              disabledBackgroundColor: AppTheme.bg,
              disabledForegroundColor: AppTheme.borderColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page ${_page + 1}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() {
              _page++;
              _reload();
            }),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.softPink,
              foregroundColor: AppTheme.primaryPink,
            ),
          ),
        ],
      ),
    );
  }
}
