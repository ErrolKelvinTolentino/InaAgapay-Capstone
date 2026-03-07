import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bhc_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class MidwifeAssignmentPage extends StatefulWidget {
  const MidwifeAssignmentPage({super.key});

  @override
  State<MidwifeAssignmentPage> createState() => _MidwifeAssignmentPageState();
}

class _MidwifeAssignmentPageState extends State<MidwifeAssignmentPage> {
  late Future<List<Map<String, dynamic>>> _midwivesFuture;
  late Future<List<BhcModel>> _bhcFuture;
  String _search = '';

  // BHC management
  final _bhcNameCtrl = TextEditingController();
  bool _showBhcPanel = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _midwivesFuture = AdminService.getMidwivesWithAssignments();
    _bhcFuture = AdminService.getBHCs();
  }

  @override
  void dispose() {
    _bhcNameCtrl.dispose();
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
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_showBhcPanel) ...[
                _buildBhcPanel(),
                const SizedBox(height: 20),
              ],
              _buildMidwifeTable(),
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
                'Midwife Assignment',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Assign midwives to Barangay Health Centers',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showBhcPanel = !_showBhcPanel),
          icon: Icon(
            _showBhcPanel
                ? Icons.keyboard_arrow_up_rounded
                : Icons.add_location_rounded,
            size: 18,
          ),
          label: Text(_showBhcPanel ? 'Hide BHC Panel' : 'Manage BHCs'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  // ─── BHC Management panel ─────────────────────────────────────────────────
  Widget _buildBhcPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_city_rounded,
                color: AppTheme.primaryPink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Barangay Health Centers',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Add BHC row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bhcNameCtrl,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'BHC name (e.g. Barangay Poblacion…)',
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
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.add_location_alt_outlined,
                      size: 18,
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addBHC,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add BHC'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // BHC list
          FutureBuilder<List<BhcModel>>(
            future: _bhcFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPink),
                );
              }
              final bhcs = snap.data ?? [];
              if (bhcs.isEmpty) {
                return Text(
                  'No BHCs added yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bhcs
                    .map(
                      (b) => _BhcChip(
                        bhc: b,
                        onDelete: () async {
                          await AdminService.deleteBHC(b.bhcId);
                          setState(_reload);
                        },
                        onEdit: (newName) async {
                          await AdminService.updateBHC(b.bhcId, newName);
                          setState(_reload);
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addBHC() async {
    final name = _bhcNameCtrl.text.trim();
    if (name.isEmpty) return;
    await AdminService.addBHC(name);
    _bhcNameCtrl.clear();
    setState(_reload);
  }

  // ─── Midwife table ────────────────────────────────────────────────────────
  Widget _buildMidwifeTable() {
    return FutureBuilder<(List<Map<String, dynamic>>, List<BhcModel>)>(
      future: Future.wait([_midwivesFuture, _bhcFuture]).then(
        (r) => (r[0] as List<Map<String, dynamic>>, r[1] as List<BhcModel>),
      ),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPink),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: GoogleFonts.poppins(color: AppTheme.danger),
            ),
          );
        }

        final midwives = snap.data?.$1 ?? [];
        final bhcs = snap.data?.$2 ?? [];

        final filtered = _search.isEmpty
            ? midwives
            : midwives.where((m) {
                final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'
                    .toLowerCase();
                final email = (m['email_address'] as String? ?? '')
                    .toLowerCase();
                return name.contains(_search) || email.contains(_search);
              }).toList();

        return Container(
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Midwife List (${midwives.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search midwife…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppTheme.textLight,
                          ),
                          filled: true,
                          fillColor: AppTheme.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryPink,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v.toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: AppTheme.borderColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No midwives found',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.softPink.withAlpha(120),
                      ),
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 72,
                      columnSpacing: 20,
                      columns: [
                        _col('Midwife'),
                        _col('Email'),
                        _col('Status'),
                        _col('Assigned BHC'),
                        _col('Action'),
                      ],
                      rows: filtered
                          .map((m) => _buildRow(ctx, m, bhcs))
                          .toList(),
                    ),
                  ),
                ),
            ],
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

  DataRow _buildRow(
    BuildContext context,
    Map<String, dynamic> m,
    List<BhcModel> bhcs,
  ) {
    final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    final email = m['email_address'] as String? ?? '';
    final status = m['status'] as String? ?? 'active';
    final midwifeRecord = m['midwives'];
    int? currentBhcId;
    if (midwifeRecord is Map) {
      currentBhcId = midwifeRecord['assigned_bhc_id'] as int?;
    } else if (midwifeRecord is List && midwifeRecord.isNotEmpty) {
      currentBhcId = midwifeRecord.first['assigned_bhc_id'] as int?;
    }

    final accountId = (m['account_id'] as num).toInt();

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryPink.withAlpha(25),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryPink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            email,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        DataCell(_statusBadge(status)),
        DataCell(
          currentBhcId != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.softPink,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: AppTheme.primaryPink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bhcs
                            .firstWhere(
                              (b) => b.bhcId == currentBhcId,
                              orElse: () => BhcModel(
                                bhcId: 0,
                                bhcName: 'BHC #$currentBhcId',
                              ),
                            )
                            .bhcName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  '— Unassigned —',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
        ),
        DataCell(
          _AssignDropdown(
            bhcs: bhcs,
            currentBhcId: currentBhcId,
            onAssign: (bhcId) async {
              await AdminService.assignMidwifeToBHC(accountId, bhcId);
              setState(_reload);
            },
            onRemove: currentBhcId != null
                ? () async {
                    await AdminService.removeMidwifeAssignment(accountId);
                    setState(_reload);
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppTheme.successLight : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: active ? AppTheme.success : const Color(0xFF757575),
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Active' : 'Inactive',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppTheme.success : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BHC chip (with edit/delete) ─────────────────────────────────────────────
class _BhcChip extends StatelessWidget {
  final BhcModel bhc;
  final VoidCallback onDelete;
  final Future<void> Function(String) onEdit;

  const _BhcChip({
    required this.bhc,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.softPink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 14,
            color: AppTheme.primaryPink,
          ),
          const SizedBox(width: 6),
          Text(
            bhc.bhcName,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showEditDialog(context),
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.edit_rounded,
              size: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: bhc.bhcName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit BHC Name',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'BHC Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await onEdit(ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Assign dropdown ──────────────────────────────────────────────────────────
class _AssignDropdown extends StatefulWidget {
  final List<BhcModel> bhcs;
  final int? currentBhcId;
  final Future<void> Function(int) onAssign;
  final Future<void> Function()? onRemove;

  const _AssignDropdown({
    required this.bhcs,
    required this.currentBhcId,
    required this.onAssign,
    this.onRemove,
  });

  @override
  State<_AssignDropdown> createState() => _AssignDropdownState();
}

class _AssignDropdownState extends State<_AssignDropdown> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    if (widget.bhcs.isEmpty) {
      return Text(
        'No BHCs available',
        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textLight),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int>(
            value: widget.currentBhcId,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              filled: true,
              fillColor: AppTheme.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryPink,
                  width: 1.5,
                ),
              ),
            ),
            hint: Text(
              'Select BHC',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textLight,
              ),
            ),
            items: widget.bhcs
                .map(
                  (b) => DropdownMenuItem(
                    value: b.bhcId,
                    child: Text(
                      b.bhcName,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) async {
                    if (v == null) return;
                    setState(() => _saving = true);
                    await widget.onAssign(v);
                    if (mounted) setState(() => _saving = false);
                  },
          ),
        ),
        if (widget.onRemove != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Remove assignment',
            child: InkWell(
              onTap: _saving ? null : widget.onRemove,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.link_off_rounded,
                  size: 15,
                  color: AppTheme.danger,
                ),
              ),
            ),
          ),
        ],
        if (_saving) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: AppTheme.primaryPink,
              strokeWidth: 2,
            ),
          ),
        ],
      ],
    );
  }
}
