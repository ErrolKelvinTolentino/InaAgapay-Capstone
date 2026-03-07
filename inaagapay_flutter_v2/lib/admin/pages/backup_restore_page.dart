import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  late Future<Map<String, int>> _countsFuture;
  final Map<String, bool> _exportLoading = {};
  bool _exportingAll = false;
  String? _lastExportTime;

  @override
  void initState() {
    super.initState();
    _countsFuture = AdminService.getTableCounts();
  }

  Future<void> _exportTable(String tableName) async {
    setState(() => _exportLoading[tableName] = true);
    try {
      final data = await AdminService.exportTable(tableName);
      _downloadJson(data, 'inaagapay_${tableName}_backup.json');
      if (mounted) {
        setState(
          () => _lastExportTime = DateFormat(
            'MMM d, yyyy – hh:mm a',
          ).format(DateTime.now()),
        );
        _showSnack('$tableName exported successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportLoading[tableName] = false);
    }
  }

  Future<void> _exportAll() async {
    setState(() => _exportingAll = true);
    try {
      final Map<String, dynamic> backup = {
        'system': 'InaAgapay',
        'export_date': DateTime.now().toIso8601String(),
        'version': '1.0',
        'tables': {},
      };

      for (final table in AdminService.exportableTables) {
        try {
          final data = await AdminService.exportTable(table);
          backup['tables'][table] = data['rows'];
        } catch (_) {
          backup['tables'][table] = [];
        }
      }

      _downloadJson(
        backup,
        'inaagapay_full_backup_'
        '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
      );

      if (mounted) {
        setState(
          () => _lastExportTime = DateFormat(
            'MMM d, yyyy – hh:mm a',
          ).format(DateTime.now()),
        );
        _showSnack('Full backup exported successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack('Full export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingAll = false);
    }
  }

  void _downloadJson(Map<String, dynamic> data, String filename) {
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(data);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildInfoBanner(),
              const SizedBox(height: 24),
              _buildFullBackupCard(),
              const SizedBox(height: 24),
              _buildTableCards(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Database Backup & Restore',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          'Export and manage InaAgapay database records',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        if (_lastExportTime != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: AppTheme.success,
              ),
              const SizedBox(width: 6),
              Text(
                'Last export: $_lastExportTime',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Data Export',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.info,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exports download as JSON files to your device. '
                  'Regular backups help protect against data loss. '
                  'Store backups in a secure location. '
                  'Full backup includes all tables at once.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBackupCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          final iconWidget = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_download_rounded,
              color: Colors.white,
              size: 36,
            ),
          );
          final textWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Full Database Backup',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Export all ${AdminService.exportableTables.length} tables '
                'as a single JSON file',
                style: GoogleFonts.poppins(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13,
                ),
              ),
            ],
          );
          final buttonWidget = SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _exportingAll ? null : _exportAll,
              icon: _exportingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPink,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: AppTheme.primaryPink,
                    ),
              label: Text(
                _exportingAll ? 'Exporting…' : 'Export All',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          );
          if (box.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 16),
                    Expanded(child: textWidget),
                  ],
                ),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: buttonWidget),
              ],
            );
          }
          return Row(
            children: [
              iconWidget,
              const SizedBox(width: 20),
              Expanded(child: textWidget),
              const SizedBox(width: 20),
              buttonWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTableCards() {
    return FutureBuilder<Map<String, int>>(
      future: _countsFuture,
      builder: (ctx, snap) {
        final counts = snap.data ?? {};
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Individual Table Export',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPink,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cols = constraints.maxWidth > 1100
                    ? 3
                    : constraints.maxWidth > 700
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: loading ? 2.8 : 2.8,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: AdminService.exportableTables.length,
                  itemBuilder: (_, i) {
                    final table = AdminService.exportableTables[i];
                    final count = counts[table];
                    return _TableExportCard(
                      tableName: table,
                      rowCount: count,
                      isLoading: _exportLoading[table] ?? false,
                      onExport: () => _exportTable(table),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual table export card
// ─────────────────────────────────────────────────────────────────────────────
class _TableExportCard extends StatelessWidget {
  final String tableName;
  final int? rowCount;
  final bool isLoading;
  final VoidCallback onExport;

  const _TableExportCard({
    required this.tableName,
    required this.rowCount,
    required this.isLoading,
    required this.onExport,
  });

  static const _tableIcons = <String, IconData>{
    'accounts': Icons.people_rounded,
    'bhc': Icons.location_on_rounded,
    'midwives': Icons.medical_services_rounded,
    'mothers': Icons.pregnant_woman_rounded,
    'pregnancies': Icons.monitor_heart_rounded,
    'prenatal_checkups': Icons.health_and_safety_rounded,
    'children': Icons.child_care_rounded,
    'birth_details': Icons.cake_rounded,
    'vaccines': Icons.vaccines_rounded,
    'immunization_record': Icons.fact_check_rounded,
    'audit_trail': Icons.history_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _tableIcons[tableName] ?? Icons.table_chart_rounded;
    final displayName = tableName
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              color: AppTheme.softPink,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Icon(icon, color: AppTheme.primaryPink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  rowCount != null
                      ? '$rowCount record${rowCount == 1 ? '' : 's'}'
                      : 'Loading…',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: isLoading ? null : onExport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.poppins(fontSize: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Export',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
