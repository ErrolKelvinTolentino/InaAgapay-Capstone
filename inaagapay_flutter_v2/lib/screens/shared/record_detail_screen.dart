// lib/screens/midwife/record_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../widgets/full_screen_image_viewer.dart';

class RecordDetailScreen extends StatefulWidget {
  const RecordDetailScreen({
    super.key,
    required this.title,
    required this.rows,
    this.icon = Icons.receipt_long,
    this.subtitle,
    this.imageUrls,
    this.aiAnalysis,
    this.useStructuredAiInsights = false,
    this.riskLevel,
    this.riskFactors,
    this.suggestedActions,
    this.weightGainEval,
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final IconData icon;
  final String? subtitle;
  final List<String>? imageUrls;
  final String? aiAnalysis;
  final bool useStructuredAiInsights;
  final String? riskLevel;
  final List<String>? riskFactors;
  final List<String>? suggestedActions;
  final Map<String, dynamic>? weightGainEval;

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final Set<String> _expandedLabInsightAspects = <String>{};
  bool _showAiInFilipino = LanguageService.isFilipino;

  // Section accent colors — pink palette variations
  static const _accentRecord = Color(0xFFE6398D); // deep rose
  static const _accentWorker = Color(0xFFD44B8A); // medium pink
  static const _accentNotes = Color(0xFFC7607E); // warm coral-pink

  // Visual hierarchy card colors
  static const _aiCardBg = Color(0xFFEDE7F6); // light purple for AI
  static const _aiCardBorder = Color(0xFF9575CD); // purple border
  static const _recommendCardBg = Color(0xFFE8F5E9); // light green
  static const _recommendCardBorder = Color(0xFF66BB6A); // green border
  static const _riskHighCardBg = Color(0xFFFBE9E7); // light red/orange
  static const _riskHighCardBorder = Color(0xFFEF5350); // red border

  String _t(String english, String filipino) {
    return LanguageService.translate(english, filipino);
  }

  String _localizedSectionTitle(String title) {
    switch (title) {
      case 'Vitals':
        return _t('Vitals', 'Vital Signs');
      case 'Fetal Assessment':
        return _t('Fetal Assessment', 'Pagsusuri sa Sanggol');
      case 'Symptoms':
        return _t('Symptoms', 'Mga Sintomas');
      case 'Medications & Supplements':
        return _t('Medications & Supplements', 'Mga Gamot at Supplements');
      case 'Schedule & Remarks':
        return _t('Schedule & Remarks', 'Schedule at Mga Tala');
      case 'Ultrasound Information':
        return _t('Ultrasound Information', 'Impormasyon ng Ultrasound');
      case 'Checkup Information':
        return _t('Checkup Information', 'Impormasyon ng Checkup');
      case 'Lab Test Information':
        return _t('Lab Test Information', 'Impormasyon ng Lab Test');
      case 'Health Worker Information':
        return _t('Health Worker Information',
            'Impormasyon ng Health Worker');
      case 'Notes':
        return _t('Notes', 'Mga Tala');
      default:
        return title;
    }
  }

  void _exportReport() {
    final buf = StringBuffer();
    final divider = String.fromCharCodes(List.filled(43, 0x2550)); // ═

    buf.writeln(divider);
    buf.writeln('INAAGAPAY — ${widget.title.toUpperCase()} REPORT');
    buf.writeln(divider);

    // Subtitle (often contains date / mother info)
    if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) {
      buf.writeln(widget.subtitle!.trim());
    }
    buf.writeln();

    // Grouped rows
    final rows = _normalizedDisplayRows();
    final sections = _groupRows(rows);
    for (final entry in sections.entries) {
      buf.writeln(entry.key.toUpperCase());
      for (final row in entry.value) {
        buf.writeln('${row.key}: ${row.value}');
      }
      buf.writeln();
    }

    // Weight gain evaluation
    if (widget.weightGainEval != null) {
      final eval = widget.weightGainEval!;
      buf.writeln('WEIGHT GAIN MONITOR');
      if (eval['status'] != null) buf.writeln('Status: ${eval['status']}');
      if (eval['bmi_category'] != null) {
        buf.writeln('BMI Category: ${eval['bmi_category']}');
      }
      if (eval['message'] != null) buf.writeln(eval['message']);
      buf.writeln();
    }

    // Risk level / factors
    if (widget.riskLevel != null && widget.riskLevel!.trim().isNotEmpty) {
      buf.writeln('RISK LEVEL: ${widget.riskLevel!.toUpperCase()}');
    }
    if (widget.riskFactors != null && widget.riskFactors!.isNotEmpty) {
      buf.writeln('Risk Factors:');
      for (final f in widget.riskFactors!) {
        buf.writeln('- $f');
      }
      buf.writeln();
    }
    if (widget.suggestedActions != null &&
        widget.suggestedActions!.isNotEmpty) {
      buf.writeln('Suggested Actions:');
      for (final a in widget.suggestedActions!) {
        buf.writeln('- $a');
      }
      buf.writeln();
    }

    // AI analysis
    if (widget.aiAnalysis != null && widget.aiAnalysis!.trim().isNotEmpty) {
      buf.writeln('AI ASSESSMENT');
      buf.writeln(widget.aiAnalysis!.trim());
      buf.writeln();
    }

    buf.writeln(divider);
    buf.writeln('Generated by InaAgapay Health System');
    buf.writeln('This is not a medical prescription.');
    buf.writeln(divider);

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
              'Report copied to clipboard!',
              'Nakopya ang report sa clipboard!')),
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAi =
        widget.aiAnalysis != null && widget.aiAnalysis!.trim().isNotEmpty;
    final isPrenatal = widget.title.toLowerCase().contains('prenatal');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(widget.title),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: _t('Export Report', 'I-export ang Report'),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: AppColors.brandPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle!.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (widget.imageUrls != null && widget.imageUrls!.isNotEmpty) ...[
                _buildImageGallery(widget.imageUrls!),
                const SizedBox(height: 14),
              ],
              _buildDetailsCard(),
              if (widget.weightGainEval != null) ...[
                const SizedBox(height: 14),
                _buildWeightGainCard(widget.weightGainEval!),
              ],
              if (isPrenatal && _shouldShowPrenatalRiskSummary()) ...[
                const SizedBox(height: 14),
                _buildPrenatalRiskSummaryCard(),
              ],
              if (hasAi) ...[
                const SizedBox(height: 14),
                _buildAiCard(widget.aiAnalysis!.trim()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightGainCard(Map<String, dynamic> eval) {
    final status = eval['status']?.toString() ?? 'UNKNOWN';
    final mode = eval['mode']?.toString() ?? 'TREND';
    final message = eval['message']?.toString() ?? '';
    final bmiCat = eval['bmi_category']?.toString() ?? '';
    
    final isHigh = status == 'HIGH';
    final isLow = status == 'LOW';
    final isInsufficient = status == 'INSUFFICIENT';
    
    final color = isHigh ? AppColors.error : (isLow ? AppColors.warning : AppColors.success);
    final icon = isHigh ? Icons.trending_up : (isLow ? Icons.trending_down : (isInsufficient ? Icons.hourglass_empty : Icons.check_circle));
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('Weight Gain Monitor', 'Pagsubaybay sa Timbang'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Analysis Mode:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(mode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BMI Category:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(bmiCat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFFE4EE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    size: 16, color: AppColors.brandAccent),
              ),
              const SizedBox(width: 10),
              Text(
                _t('Attached Images', 'Mga Kalakip na Larawan'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                LanguageService.isFilipino
                    ? '${imageUrls.length} file'
                    : '${imageUrls.length} file${imageUrls.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImageViewer(
                          imageUrls: imageUrls,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(
                            imageUrls[index],
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.bgSecondary,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textSecondary, size: 28),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.zoom_in,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _sectionAccent(String title) {
    if (widget.title.toLowerCase().contains('prenatal checkup')) {
      final t = title.toLowerCase();
      if (t == 'vitals') return const Color(0xFFE6398D);
      if (t == 'fetal assessment') return const Color(0xFFD44B8A);
      if (t == 'symptoms') return const Color(0xFFF06292);
      if (t == 'medications & supplements') return const Color(0xFFBA68C8);
      if (t == 'schedule & remarks') return const Color(0xFF9575CD);
    }

    final t = title.toLowerCase();
    if (t.contains('health worker')) return _accentWorker;
    if (t.contains('notes')) return _accentNotes;
    return _accentRecord;
  }

  IconData _sectionIcon(String title) {
    if (widget.title.toLowerCase().contains('prenatal checkup')) {
      final t = title.toLowerCase();
      if (t == 'vitals') return Icons.favorite_border;
      if (t == 'fetal assessment') return Icons.child_care;
      if (t == 'symptoms') return Icons.healing;
      if (t == 'medications & supplements') return Icons.medication_outlined;
      if (t == 'schedule & remarks') return Icons.event_note;
    }

    final t = title.toLowerCase();
    if (t.contains('health worker')) return Icons.person_outline;
    if (t.contains('notes')) return Icons.sticky_note_2_outlined;
    if (t.contains('ultrasound')) return Icons.monitor_heart_outlined;
    if (t.contains('checkup')) return Icons.medical_services_outlined;
    return Icons.biotech_outlined;
  }

  Widget _buildDetailsCard() {
    final rows = _normalizedDisplayRows();
    final sections = _groupRows(rows);
    final sectionEntries =
        sections.entries.where((e) => e.value.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _t('No additional details available.',
                  'Walang karagdagang detalye.'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (int i = 0; i < sectionEntries.length; i++) ...[
            _buildDetailSection(sectionEntries[i].key, sectionEntries[i].value),
            if (i < sectionEntries.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  String _recordInfoTitle() {
    final t = widget.title.toLowerCase();
    if (t.contains('ultrasound')) return 'Ultrasound Information';
    if (t.contains('checkup')) return 'Checkup Information';
    return 'Lab Test Information';
  }

  String _labelKey(String label) {
    final normalized = _normalizeForCompare(label);
    const aliases = {
      'petsa': 'date',
      'bilangngsanggol': 'fetalcount',
      'edadngpagbubuntis': 'ageofgestation',
      'timbangkg': 'weight(kg)',
      'posisyonngsanggol': 'fetalposition',
      'tonongtibokngsanggol': 'fetalhearttone',
      'tibokngpusongsanggol': 'fetalheartbeat',
      'mgasintomas': 'symptoms',
      'planosagamot': 'medicationplans',
      'mgagamotnaibinigay': 'givenmedications',
      'bakunangtd': 'tdvaccine',
      'pamamaga': 'edema',
      'mgatala': 'remarks',
      'susunodnaschedule': 'nextschedule',
      'lokasyon': 'location',
      'buongpangalan': 'fullname',
      'institusyon': 'institution',
      'propesyon': 'profession',
      'ur nglabtest': 'labtesttype',
      'uringlabtest': 'labtesttype',
      'petsanglabtest': 'labtestdate',
      'petsangultrasound': 'ultrasounddate',
    };
    return aliases[normalized] ?? normalized;
  }

  Map<String, List<MapEntry<String, String>>> _groupRows(
      List<MapEntry<String, String>> rows) {
    if (widget.title.toLowerCase().contains('prenatal checkup')) {
      final vitals = <MapEntry<String, String>>[];
      final fetal = <MapEntry<String, String>>[];
      final symptoms = <MapEntry<String, String>>[];
      final meds = <MapEntry<String, String>>[];
      final schedule = <MapEntry<String, String>>[];

      for (final row in rows) {
        final key = _labelKey(row.key);
        // Skip date from vitals - it's shown in the header/subtitle
        if (key == 'date') continue;

        // Vitals: weight, height, BMI, blood pressure, AOG
        if ([
          'ageofgestation',
          'weight',
          'weight(kg)',
          'height',
          'bmi',
          'bloodpressure'
        ].contains(key)) {
          vitals.add(row);
        }
        // Fetal Assessment: fetal count, position, heart rate, heart tone (NOT edema)
        else if ([
          'fetalcount',
          'fetalposition',
          'fetalheartrate',
          'fetalheartbeat',
          'fetalhearttone'
        ].contains(key)) {
          fetal.add(row);
        }
        // Symptoms: symptoms list + edema
        else if (['symptoms', 'edema'].contains(key)) {
          symptoms.add(row);
        }
        // Medications & Supplements: plans, given meds, ferrous, calcium, TD vaccine
        else if ([
          'medicationplans',
          'givenmedications',
          'ferrous+fa',
          'ferrous',
          'calcium',
          'tdvaccine',
          'tddose'
        ].contains(key)) {
          meds.add(row);
        }
        // Schedule & Remarks: next schedule, remarks
        else if (['nextschedule', 'nextvisit', 'remarks'].contains(key)) {
          schedule.add(row);
        }
        // Skip risk level and factors (they go to the risk summary card)
        else if (['risklevel', 'riskfactors', 'suggestedactions']
            .contains(key)) {
          continue;
        } else {
          vitals.add(row); // fallback
        }
      }

      return {
        'Vitals': vitals,
        if (fetal.isNotEmpty) 'Fetal Assessment': fetal,
        if (symptoms.isNotEmpty) 'Symptoms': symptoms,
        if (meds.isNotEmpty) 'Medications & Supplements': meds,
        if (schedule.isNotEmpty) 'Schedule & Remarks': schedule,
      };
    }

    final record = <MapEntry<String, String>>[];
    final worker = <MapEntry<String, String>>[];
    final notes = <MapEntry<String, String>>[];

    for (final row in rows) {
      final key = _labelKey(row.key);
      if (key.contains('remarks') || key.contains('notes')) {
        notes.add(row);
        continue;
      }

      if (key.contains('healthworker') ||
          key == 'fullname' ||
          key == 'name' ||
          key == 'institution' ||
          key == 'profession') {
        worker.add(row);
        continue;
      }

      record.add(row);
    }

    return {
      _recordInfoTitle(): record,
      'Health Worker Information': worker,
      'Notes': notes,
    };
  }

  Color _sectionCardBackground(String title) {
    final t = title.toLowerCase();
    if (t == 'symptoms') return const Color(0xFFFFF3E0); // light orange for findings
    return Colors.white; // default white for vitals and others
  }

  Color? _sectionCardBorderColor(String title) {
    final t = title.toLowerCase();
    if (t == 'symptoms') return const Color(0xFFFFB74D).withValues(alpha: 0.3);
    return null;
  }

  Widget _buildDetailSection(
      String title, List<MapEntry<String, String>> rows) {
    final accent = _sectionAccent(title);
    final icon = _sectionIcon(title);
    final cardBg = _sectionCardBackground(title);
    final cardBorder = _sectionCardBorderColor(title);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: cardBorder != null ? Border.all(color: cardBorder) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accent, width: 3.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 15, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _localizedSectionTitle(title),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < rows.length; i++) ...[
                _buildDetailRow(rows[i].key, rows[i].value),
                if (i < rows.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      color: AppColors.borderPrimary,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeForCompare(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<MapEntry<String, String>> _normalizedDisplayRows() {
    final filtered = <MapEntry<String, String>>[];

    for (final row in widget.rows) {
      final label = row.key.trim();
      final value = row.value.trim();
      if (label.isEmpty) continue;

      final labelKey = _normalizeForCompare(label);
      final valueKey = _normalizeForCompare(value);

      final isEmptyValue = value.isEmpty || value == '-' || value == '—';
      if (isEmptyValue &&
          !(labelKey.contains('remarks') || labelKey.contains('notes'))) {
        continue;
      }

      if ((labelKey == 'location' || labelKey == 'labtestlocation') &&
          valueKey == 'mobileupload') {
        continue;
      }

      final displayValue =
          value == '-' || value == '—' ? _t('Not provided', 'Hindi nailagay') : value;
      filtered.add(MapEntry(label, displayValue));
    }

    return filtered;
  }

  Widget _buildDetailRow(String label, String value) {
    final isNotProvided = value.toLowerCase() == 'not provided' ||
        value.toLowerCase() == 'hindi nailagay';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isNotProvided
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontStyle: isNotProvided ? FontStyle.italic : FontStyle.normal,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(String aiText) {
    final isPrenatal = widget.title.toLowerCase().contains('prenatal');

    // Extract recommendations from AI text for separate display
    final recommendations = _extractRecommendations(aiText);
    final hasRecommendations = recommendations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Analysis card — distinct purple-tinted background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _aiCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _aiCardBorder.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _aiCardBorder.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        size: 16, color: Color(0xFF7E57C2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('AI Analysis', 'AI na Pagsusuri'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5E35B1),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _t('AI Generated', 'Gawa ng AI'),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7E57C2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Language toggle for AI insights
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildAiLanguageButton('English', !_showAiInFilipino),
                  const SizedBox(width: 8),
                  _buildAiLanguageButton('Filipino', _showAiInFilipino),
                ],
              ),
              const SizedBox(height: 8),
              if (isPrenatal)
                _buildPrenatalAiInsights(_getAiTextForLanguage(aiText))
              else if (widget.useStructuredAiInsights)
                _buildStructuredAiInsights(_getAiTextForLanguage(aiText))
              else
                _buildFormattedAiText(_getAiTextForLanguage(aiText)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _t(
                          'This is AI-generated analysis for informational purposes. Always consult your healthcare provider.',
                          'Ang pagsusuring ito ay gawa ng AI para sa impormasyon lamang. Kumonsulta palagi sa iyong healthcare provider.',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Recommendations card — distinct green-tinted background (if extracted)
        if (hasRecommendations) ...[
          const SizedBox(height: 14),
          _buildRecommendationsCard(recommendations),
        ],
      ],
    );
  }

  Widget _buildAiLanguageButton(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAiInFilipino = label == 'Filipino';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7E57C2).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF7E57C2).withValues(alpha: 0.4)
                : AppColors.borderPrimary,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF5E35B1) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Extract the language-appropriate section from AI text.
  /// If the text has ## English / ## Filipino sections, returns the appropriate one.
  /// Otherwise returns the full text.
  String _getAiTextForLanguage(String fullText) {
    final englishMatch = RegExp(
      r'## English\s*([\s\S]*?)(?=(## Filipino|\z))',
      caseSensitive: false,
    ).firstMatch(fullText);
    final filipinoMatch = RegExp(
      r'## Filipino\s*([\s\S]*?)(?=(## English|\z))',
      caseSensitive: false,
    ).firstMatch(fullText);

    final englishText = englishMatch?.group(1)?.trim();
    final filipinoText = filipinoMatch?.group(1)?.trim();

    // If no language sections found, return full text
    if (englishText == null && filipinoText == null) return fullText;

    if (_showAiInFilipino) {
      return filipinoText ?? englishText ?? fullText;
    }
    return englishText ?? filipinoText ?? fullText;
  }

  /// Extract recommendation lines from AI text
  List<String> _extractRecommendations(String aiText) {
    final lines = aiText.split('\n');
    final recommendations = <String>[];
    bool inRecommendations = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final upper = trimmed.toUpperCase();
      if (upper.contains('RECOMMENDATION') ||
          upper.contains('SUGGESTED ACTION') ||
          upper.contains('NEXT STEPS') ||
          upper.contains('FOLLOW-UP')) {
        inRecommendations = true;
        // If there's content after the header on the same line
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx != -1 && colonIdx < trimmed.length - 1) {
          final after = trimmed.substring(colonIdx + 1).trim();
          if (after.isNotEmpty) recommendations.add(after);
        }
        continue;
      }

      if (inRecommendations) {
        // Stop if we hit another section header
        if (RegExp(r'^[A-Z][A-Z\s]{3,}:').hasMatch(trimmed)) break;
        final cleaned = trimmed
            .replaceFirst(RegExp(r'^[\-\*\d.]+\s*'), '')
            .trim();
        if (cleaned.isNotEmpty) recommendations.add(cleaned);
      }
    }

    return recommendations;
  }

  /// Recommendations card with green tint
  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _recommendCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _recommendCardBorder.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _recommendCardBorder.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline,
                    size: 16, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 10),
              Text(
                _t('Recommendations', 'Mga Rekomendasyon'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // In record_detail_screen.dart, replace _buildPrenatalAiInsights with:

  Widget _buildPrenatalAiInsights(String aiText) {
    if (aiText.isEmpty) {
      return Text(
        _t('No AI insights available.', 'Walang available na AI analysis.'),
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }

    // Strip common prefixes that AI might add
    String displayText = aiText;
    final prefixesToStrip = [
      'AI INSIGHTS:',
      'OVERALL ASSESSMENT:',
      'OVERALL HEALTH STATUS:',
      'KEY OBSERVATIONS:',
      'RECOMMENDATIONS:',
      'RECOMMENDED NEXT ACTIONS:',
      'CLINICAL IMPRESSION:',
      'FOLLOW-UP SUGGESTIONS:',
      'DETAILED MEASUREMENTS ASSESSMENT:',
      'ANATOMICAL ASSESSMENT:',
      'GESTATIONAL AGE ASSESSMENT:',
      'LABORATORY RESULTS:',
      'ABNORMAL FINDINGS:',
      'NORMAL RANGES:',
      'SUMMARY:',
    ];

    for (final prefix in prefixesToStrip) {
      if (displayText.toUpperCase().startsWith(prefix)) {
        displayText = displayText.substring(prefix.length).trim();
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _aiCardBorder.withValues(alpha: 0.15)),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  String _normalizeMarkdownLine(String input) {
    var line = input;
    line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
    line = line.replaceFirst(RegExp(r'^\s*(?:[-*])\s+'), '');
    return line;
  }

  String _cleanResidualMarkdown(String input) {
    var text = input;
    text = text.replaceAll('**', '');
    text = text.replaceAll('##', '');
    text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
    return text;
  }

  List<TextSpan> _parseInlineMarkdown(String input) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int current = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > current) {
        spans.add(TextSpan(
          text: _cleanResidualMarkdown(input.substring(current, match.start)),
        ));
      }

      final boldText = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      current = match.end;
    }

    if (current < input.length) {
      spans.add(TextSpan(
        text: _cleanResidualMarkdown(input.substring(current)),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: _cleanResidualMarkdown(input)));
    }

    return spans;
  }

  Widget _buildFormattedAiText(String text) {
    if (text.isEmpty) {
      return Text(
        _t('No AI insights available.', 'Walang available na AI analysis.'),
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }

    final lines = text.split('\n');
    final spans = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final normalizedLine = _normalizeMarkdownLine(lines[i]);
      spans.addAll(_parseInlineMarkdown(normalizedLine));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style:
            const TextStyle(color: Colors.black87, fontSize: 14, height: 1.45),
        children: spans,
      ),
    );
  }

  Map<String, List<String>> _extractAiSections(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => _cleanResidualMarkdown(_normalizeMarkdownLine(l)).trim())
        .toList();

    final sections = <String, List<String>>{};
    String currentSection = 'SUMMARY';
    sections[currentSection] = [];

    final headingPattern = RegExp(
      r'^(?:\d+\.\s*)?(RELEVANCE CHECK|RELEVANCE REASON|LABORATORY RESULTS|ABNORMAL FINDINGS|NORMAL RANGES|REFERENCE RANGES|OVERALL ASSESSMENT|OVERALL HEALTH STATUS|RECOMMENDATIONS|RECOMMENDED NEXT ACTIONS|KEY OBSERVATIONS|DETAILED MEASUREMENTS ASSESSMENT|ANATOMICAL ASSESSMENT|GESTATIONAL AGE ASSESSMENT|CLINICAL IMPRESSION|FOLLOW-UP SUGGESTIONS)\s*:?\s*(.*)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.toUpperCase() == 'COMPREHENSIVE LABORATORY ANALYSIS') continue;
      if (RegExp(r'^[-_=]{2,}$').hasMatch(line.replaceAll(' ', ''))) {
        continue;
      }

      final heading = headingPattern.firstMatch(line);
      if (heading != null) {
        currentSection = heading.group(1)!.toUpperCase();
        if (currentSection == 'REFERENCE RANGES') {
          currentSection = 'NORMAL RANGES';
        }
        sections.putIfAbsent(currentSection, () => []);
        final inlineContent = heading.group(2)?.trim() ?? '';
        if (inlineContent.isNotEmpty) {
          sections[currentSection]!.add(inlineContent);
        }
        continue;
      }

      sections.putIfAbsent(currentSection, () => []);
      sections[currentSection]!.add(line);
    }

    sections.removeWhere((_, value) => value.isEmpty);
    return sections;
  }

  String _safeText(Object? value) => value?.toString() ?? '';

  String _stripDecorativeDashes(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^[-_=]{2,}$').hasMatch(trimmed)) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'\s+--+\s+'), ' ').trim();
  }

  bool _isConcerningAnalyte(String text) {
    final t = text.toLowerCase();
    return RegExp(
      r'protein|glucose|ketone|nitrite|leukocyte|blood|pus|bacteria|bilirubin|hiv|hbsag|vdrl|rpr|syphilis|infection|pathogen',
      caseSensitive: false,
    ).hasMatch(t);
  }

  String _classifyLabStatus(String testName, String rawValue) {
    final test = testName.toLowerCase();
    final value = rawValue.toLowerCase();
    final merged = '$test $value';

    final hasWithinNormal = RegExp(
      r'within normal limits|within normal range|normal range|wnl',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasWithinNormal) return 'WITHIN NORMAL LIMITS';

    final isColorFinding = test.contains('color') || test.contains('colour');
    if (isColorFinding) {
      if (RegExp(r'\byellow\b|\bstraw\b|\bpale\b|\bclear\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'WITHIN NORMAL LIMITS';
      }
      if (RegExp(r'\bdark\b|\bamber\b|\bbrown\b|\bred\b|\bbloody\b',
              caseSensitive: false)
          .hasMatch(value)) {
        return 'ABNORMAL (REVIEW)';
      }
      return 'OBSERVE';
    }

    if (RegExp(r'\bpositive\b', caseSensitive: false).hasMatch(value)) {
      if (_isConcerningAnalyte(merged)) return 'POSITIVE (REVIEW)';
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'POSITIVE (EXPECTED)';
      }
      return 'POSITIVE';
    }

    if (RegExp(r'\bnegative\b', caseSensitive: false).hasMatch(value)) {
      if (RegExp(r'pregnancy|hcg', caseSensitive: false).hasMatch(test)) {
        return 'NEGATIVE (REVIEW)';
      }
      if (_isConcerningAnalyte(merged)) return 'NEGATIVE (REASSURING)';
      return 'NEGATIVE';
    }

    if (RegExp(r'\btrace\b|\bfew\b|\bslight\b|\bmild\b|\bborderline\b',
            caseSensitive: false)
        .hasMatch(value)) {
      return 'BORDERLINE';
    }

    if (RegExp(
      r'\babnormal\b|\bcritical\b|outside normal range|higher than normal|lower than normal|\belevated\b|\bdecreased\b|\bincreased\b|!',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'ABNORMAL (REVIEW)';
    }

    if (RegExp(r'\bnormal\b', caseSensitive: false).hasMatch(value)) {
      return 'NORMAL';
    }

    return 'OBSERVE';
  }

  bool _isConcerningStatus(String status) {
    final s = status.toUpperCase();
    return s.contains('REVIEW') ||
        s.contains('ABNORMAL') ||
        s.contains('CONCERNING');
  }

  bool _isCautionStatus(String status) {
    final s = status.toUpperCase();
    return s == 'OBSERVE' ||
        s == 'BORDERLINE' ||
        s == 'POSITIVE' ||
        s == 'MONITOR';
  }

  Color _statusChipBackground(String status) {
    if (_isConcerningStatus(status)) return AppColors.error.withValues(alpha: 0.08);
    if (_isCautionStatus(status)) return AppColors.warning.withValues(alpha: 0.08);
    return AppColors.success.withValues(alpha: 0.08);
  }

  Color _statusChipBorder(String status) {
    if (_isConcerningStatus(status)) return AppColors.error.withValues(alpha: 0.25);
    if (_isCautionStatus(status)) return AppColors.warning.withValues(alpha: 0.25);
    return AppColors.success.withValues(alpha: 0.25);
  }

  Color _statusChipTextColor(String status) {
    if (_isConcerningStatus(status)) return AppColors.error;
    if (_isCautionStatus(status)) return AppColors.warning;
    return AppColors.success;
  }

  String _statusMeaning(String status) {
    switch (status.toUpperCase()) {
      case 'WITHIN NORMAL LIMITS':
        return 'Consistent with expected findings for this test.';
      case 'NORMAL':
        return 'Reported as normal for this parameter.';
      case 'ABNORMAL (REVIEW)':
      case 'ABNORMAL':
        return 'May need clinician review with symptoms and history.';
      case 'BORDERLINE':
        return 'Near threshold. Monitor trends and correlate clinically.';
      case 'OBSERVE':
        return 'Not clearly high-risk. Observe and compare with references.';
      case 'POSITIVE (REVIEW)':
        return 'Positive finding that may be clinically significant.';
      case 'POSITIVE (EXPECTED)':
        return 'Positive finding can be expected for this test context.';
      case 'NEGATIVE (REASSURING)':
        return 'No concerning marker detected for this parameter.';
      case 'NEGATIVE (REVIEW)':
        return 'Negative may be unexpected for this context; verify clinically.';
      case 'POSITIVE':
      case 'NEGATIVE':
        return 'Interpret this result based on the specific test context.';
      default:
        return 'Interpret this result together with reference ranges and overall assessment.';
    }
  }

  ({String testName, String value, String status}) _parseLabResultLine(
      String line) {
    final cleaned =
        _safeText(line).replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim();
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex == -1) {
      return (testName: cleaned, value: '', status: 'UNKNOWN');
    }

    final testName = cleaned.substring(0, colonIndex).trim();
    final rawValue = _safeText(cleaned.substring(colonIndex + 1)).trim();
    final status = _classifyLabStatus(testName, rawValue);

    final value = rawValue
        .replaceAll('!', '')
        .replaceAll('⚠️', '')
        .replaceAll('⚠', '')
        .replaceAll(RegExp(r'\bABNORMAL\b', caseSensitive: false), '')
        .trim();

    return (
      testName: _stripDecorativeDashes(testName),
      value: _stripDecorativeDashes(value),
      status: status
    );
  }

  String _normalizeAspectKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _extractAnalyteFromLine(String line) {
    var normalized = _safeText(line)
        .replaceFirst(RegExp(r'^[•\-*]\s*'), '')
        .replaceFirst(RegExp(r'^Reference\s*:\s*', caseSensitive: false), '')
        .trim();

    if (normalized.isEmpty) return '';

    final colonMatch =
        RegExp(r'^([A-Za-z0-9()/%+\-.]+)\s*:').firstMatch(normalized);
    if (colonMatch != null) {
      return (colonMatch.group(1) ?? '').trim();
    }

    final isMatch =
        RegExp(r'^([A-Za-z0-9()/%+\-.]+)\s+is\b', caseSensitive: false)
            .firstMatch(normalized);
    if (isMatch != null) {
      return (isMatch.group(1) ?? '').trim();
    }

    return '';
  }

  List<String> _aspectCandidates(String aspect) {
    final raw = _safeText(aspect).trim();
    if (raw.isEmpty) return const <String>[];

    final candidates = <String>{raw};
    final withoutParen = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (withoutParen.isNotEmpty) {
      candidates.add(withoutParen);
    }
    final firstToken = withoutParen.split(RegExp(r'\s+')).first.trim();
    if (firstToken.isNotEmpty) {
      candidates.add(firstToken);
    }

    return candidates.toList();
  }

  bool _lineMatchesAspect(String line, String aspect) {
    final lineAnalyte = _extractAnalyteFromLine(line);
    if (lineAnalyte.isNotEmpty) {
      final lineKey = _normalizeAspectKey(lineAnalyte);
      for (final candidate in _aspectCandidates(aspect)) {
        if (_normalizeAspectKey(candidate) == lineKey) {
          return true;
        }
      }
      return false;
    }

    final source = _safeText(line);
    for (final candidate in _aspectCandidates(aspect)) {
      final escaped = RegExp.escape(candidate);
      final bounded = RegExp(
        '(^|[^A-Za-z0-9])$escaped([^A-Za-z0-9]|\$)',
        caseSensitive: false,
      );
      if (bounded.hasMatch(source)) {
        return true;
      }
    }
    return false;
  }

  String _buildAspectDetails(
      String aspect, List<String> abnormalLines, List<String> rangeLines) {
    final matches = <String>[];
    for (final line in abnormalLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add(line);
      }
    }
    for (final line in rangeLines) {
      if (_lineMatchesAspect(line, aspect)) {
        matches.add('Reference: $line');
      }
    }
    return matches.join('\n\n').trim();
  }

  Widget _buildLabResultsSummaryCard(Map<String, List<String>> sections) {
    final labLines = sections['LABORATORY RESULTS'] ?? const <String>[];
    final abnormalLines = sections['ABNORMAL FINDINGS'] ?? const <String>[];
    final rangeLines = sections['NORMAL RANGES'] ?? const <String>[];

    final rows = labLines
        .map(_parseLabResultLine)
        .where((r) => r.testName.isNotEmpty && r.status != 'UNKNOWN')
        .toList();

    if (rows.isEmpty) {
      return _buildAiSectionCard('LABORATORY RESULTS', labLines);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 18, color: AppColors.brandPrimary),
              SizedBox(width: 8),
              Text(
                'Laboratory Results',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final details = _buildAspectDetails(
              row.testName,
              abnormalLines,
              rangeLines,
            );
            final aspectKey = _normalizeAspectKey(row.testName);
            final isExpanded = _expandedLabInsightAspects.contains(aspectKey);
            final hasDetails = details.isNotEmpty;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderPrimary),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.testName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasDetails)
                        IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          constraints: const BoxConstraints.tightFor(
                              width: 24, height: 24),
                          onPressed: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedLabInsightAspects.remove(aspectKey);
                              } else {
                                _expandedLabInsightAspects.add(aspectKey);
                              }
                            });
                          },
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusChipBackground(row.status),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _statusChipBorder(row.status),
                          ),
                        ),
                        child: Text(
                          row.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusChipTextColor(row.status),
                          ),
                        ),
                      ),
                      if (row.value.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            row.value,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusMeaning(row.status),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (isExpanded && hasDetails) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildFormattedAiText(details),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  ({String testName, String value, String status, String remark})
      _parseUltrasoundMetricLine(String line) {
    final cleaned =
        _safeText(line).replaceFirst(RegExp(r'^[-\*•]\s*'), '').trim();

    String testName = '';
    String value = '';
    String status = 'UNKNOWN';
    String remark = '';

    final bracketMatch = RegExp(r'\[(.*?)\]').firstMatch(cleaned);

    if (bracketMatch != null) {
      status = bracketMatch.group(1)!.trim().toUpperCase();
      testName = cleaned.substring(0, bracketMatch.start).trim();

      final colonIdx = testName.indexOf(':');
      if (colonIdx != -1) {
        value = testName.substring(colonIdx + 1).trim();
        testName = testName.substring(0, colonIdx).trim();
      }

      remark = cleaned.substring(bracketMatch.end).trim();
      remark = remark.replaceFirst(RegExp(r'^[-:]\s*'), '').trim();
    } else {
      final colonIndex = cleaned.indexOf(':');
      if (colonIndex != -1) {
        testName = cleaned.substring(0, colonIndex).trim();
        String rest = cleaned.substring(colonIndex + 1).trim();

        final parenMatch = RegExp(r'\(([^)]+)\)$').firstMatch(rest);
        if (parenMatch != null) {
          remark = parenMatch.group(1)!.trim();
          rest = rest.substring(0, parenMatch.start).trim();
        }

        if (rest.startsWith('✓') ||
            rest.toLowerCase() == 'normal' ||
            rest.toLowerCase() == 'present') {
          value = 'Present / Normal';
          status = 'NORMAL';
          if (rest.startsWith('✓')) rest = rest.substring(1).trim();
        } else if (rest.startsWith('X') ||
            rest.startsWith('✗') ||
            rest.toLowerCase() == 'abnormal' ||
            rest.toLowerCase() == 'absent') {
          value = 'Absent / Abnormal';
          status = 'ABNORMAL';
          if (rest.startsWith('X') || rest.startsWith('✗')) {
            rest = rest.substring(1).trim();
          }
        } else {
          final dashIndex = rest.lastIndexOf('-');
          if (dashIndex != -1) {
            final possibleStatus =
                rest.substring(dashIndex + 1).trim().toUpperCase();
            if (possibleStatus == 'NORMAL' ||
                possibleStatus == 'ABNORMAL' ||
                possibleStatus == 'REVIEW' ||
                possibleStatus == 'MONITOR' ||
                possibleStatus == 'BORDERLINE' ||
                possibleStatus == 'CONCERNING') {
              status = possibleStatus;
              value = rest.substring(0, dashIndex).trim();
            } else {
              value = rest;
            }
          } else {
            value = rest;
          }
        }
      } else {
        return (testName: cleaned, value: '', status: 'UNKNOWN', remark: '');
      }
    }

    if (status == 'CONCERNING') status = 'ABNORMAL';

    if (status == 'UNKNOWN' || status.isEmpty) {
      if (RegExp(r'\bnormal\b', caseSensitive: false).hasMatch(value)) {
        status = 'NORMAL';
      } else if (RegExp(
              r'\babnormal\b|\bcritical\b|outside normal range|concerning',
              caseSensitive: false)
          .hasMatch(value)) {
        status = 'ABNORMAL';
      } else {
        status = 'INFO';
      }
    }

    return (testName: testName, value: value, status: status, remark: remark);
  }

  Widget _buildUltrasoundMetricsSummaryCard(String title, List<String> lines) {
    if (lines.isEmpty) return _buildAiSectionCard(title, lines);

    final rows = lines
        .map(_parseUltrasoundMetricLine)
        .where((r) => r.testName.isNotEmpty)
        .toList();

    if (rows.isEmpty) {
      return _buildAiSectionCard(title, lines);
    }

    IconData headerIcon = Icons.article_outlined;
    Color headerColor = AppColors.brandPrimary;

    final normalized = title.trim().toUpperCase();
    if (normalized == 'DETAILED MEASUREMENTS ASSESSMENT') {
      headerColor = Colors.teal;
      headerIcon = Icons.straighten;
    } else if (normalized == 'ANATOMICAL ASSESSMENT') {
        headerColor = AppColors.success;
      headerIcon = Icons.child_care_outlined;
    } else if (normalized == 'ABNORMAL FINDINGS') {
        headerColor = AppColors.error;
      headerIcon = Icons.warning_amber_rounded;
    } else if (normalized.contains('NORMAL RANGES')) {
      headerIcon = Icons.analytics_outlined;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, size: 18, color: headerColor),
              const SizedBox(width: 8),
              Text(
                _friendlyAiSectionTitle(title),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderPrimary),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.testName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (row.status != 'UNKNOWN' && row.status != 'INFO')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusChipBackground(row.status),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _statusChipBorder(row.status),
                            ),
                          ),
                          child: Text(
                            row.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusChipTextColor(row.status),
                            ),
                          ),
                        ),
                      if (row.value.isNotEmpty &&
                          row.value != 'Present / Normal' &&
                          row.value != 'Absent / Abnormal')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            row.value,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (row.remark.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      row.remark,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiSectionCard(String title, List<String> lines) {
    final friendlyTitle = _friendlyAiSectionTitle(title);
    Color color = AppColors.brandPrimary;
    IconData icon = Icons.article_outlined;

    final normalized = title.trim().toUpperCase();
    if (normalized.contains('HEALTH STATUS')) {
      final hasHealthy = lines.any((v) => v.toLowerCase().contains('healthy'));
        color = hasHealthy ? AppColors.success : AppColors.warning;
      icon = Icons.monitor_heart_outlined;
    } else if (normalized == 'DETAILED MEASUREMENTS ASSESSMENT') {
      color = Colors.teal;
      icon = Icons.straighten;
    } else if (normalized == 'ANATOMICAL ASSESSMENT') {
        color = AppColors.success;
      icon = Icons.child_care_outlined;
    } else if (normalized == 'ABNORMAL FINDINGS') {
        color = AppColors.error;
      icon = Icons.warning_amber_rounded;
    } else if (normalized.contains('RECOMMENDED')) {
      color = Colors.blue;
      icon = Icons.lightbulb_outline;
    } else if (normalized == 'OVERALL ASSESSMENT') {
      icon = Icons.summarize_outlined;
    } else if (normalized == 'KEY OBSERVATIONS') {
      icon = Icons.visibility_outlined;
    } else if (normalized == 'CLINICAL IMPRESSION') {
      icon = Icons.medical_information_outlined;
      color = Colors.indigo;
    } else if (normalized == 'FOLLOW-UP SUGGESTIONS') {
      icon = Icons.follow_the_signs;
      color = Colors.blue;
    } else if (normalized == 'SUMMARY') {
      icon = Icons.analytics_outlined;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  friendlyTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFormattedAiText(lines.map((line) {
            String cleaned = line.trim();
            if (RegExp(r'^[A-Z_]+$').hasMatch(cleaned)) {
              cleaned = cleaned
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((word) => word.isEmpty
                      ? ''
                      : '${word[0]}${word.substring(1).toLowerCase()}')
                  .join(' ');
            }
            return cleaned;
          }).join('\n')),
        ],
      ),
    );
  }

  Widget _buildStructuredAiInsights(String text) {
    final sections = _extractAiSections(text);
    if (sections.isEmpty) return _buildFormattedAiText(text);

    // Eliminate redundancy between measurements and anatomical findings
    if (sections.containsKey('ANATOMICAL ASSESSMENT') &&
        sections.containsKey('DETAILED MEASUREMENTS ASSESSMENT')) {
      final measurements = sections['DETAILED MEASUREMENTS ASSESSMENT']!;
      final anatomical = sections['ANATOMICAL ASSESSMENT']!;

      final normalizedMeasurements =
          measurements.map((m) => m.trim().toLowerCase()).toSet();
      final filteredAnatomical = anatomical
          .where(
              (a) => !normalizedMeasurements.contains(a.trim().toLowerCase()))
          .toList();

      if (filteredAnatomical.isEmpty) {
        sections.remove('ANATOMICAL ASSESSMENT');
      } else {
        sections['ANATOMICAL ASSESSMENT'] = filteredAnatomical;
      }
    }

    const sectionOrder = [
      'OVERALL ASSESSMENT',
      'OVERALL HEALTH STATUS',
      'GESTATIONAL AGE ASSESSMENT',
      'DETAILED MEASUREMENTS ASSESSMENT',
      'ANATOMICAL ASSESSMENT',
      'CLINICAL IMPRESSION',
      'LABORATORY RESULTS',
      'ABNORMAL FINDINGS',
      'NORMAL RANGES',
      'KEY OBSERVATIONS',
      'RECOMMENDATIONS',
      'RECOMMENDED NEXT ACTIONS',
      'FOLLOW-UP SUGGESTIONS',
      'SUMMARY',
    ];

    final orderedEntries = <MapEntry<String, List<String>>>[];
    for (final key in sectionOrder) {
      if (sections.containsKey(key)) {
        orderedEntries.add(MapEntry(key, sections[key]!));
      }
    }
    for (final entry in sections.entries) {
      if (!sectionOrder.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    final widgets = <Widget>[];
    for (final entry in orderedEntries) {
      if (entry.key == 'RELEVANCE CHECK' || entry.key == 'RELEVANCE REASON') {
        continue;
      }

      // Skip recommendations here — they are rendered as a separate card
      // by _buildAiCard to avoid duplication.
      if (entry.key == 'RECOMMENDATIONS' ||
          entry.key == 'RECOMMENDED NEXT ACTIONS' ||
          entry.key == 'FOLLOW-UP SUGGESTIONS') {
        continue;
      }

      if (entry.key == 'LABORATORY RESULTS') {
        widgets.add(_buildLabResultsSummaryCard(sections));
        continue;
      }

      if (entry.key == 'DETAILED MEASUREMENTS ASSESSMENT' ||
          entry.key == 'ANATOMICAL ASSESSMENT' ||
          entry.key == 'ABNORMAL FINDINGS' ||
          entry.key == 'NORMAL RANGES') {
        if ((entry.key == 'ABNORMAL FINDINGS' ||
                entry.key == 'NORMAL RANGES') &&
            sections.containsKey('LABORATORY RESULTS')) {
          continue;
        }
        widgets.add(_buildUltrasoundMetricsSummaryCard(entry.key, entry.value));
        continue;
      }

      widgets.add(_buildAiSectionCard(entry.key, entry.value));
    }

    if (widgets.isEmpty) return _buildFormattedAiText(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _friendlyAiSectionTitle(String raw) {
    final normalized = raw.trim().toUpperCase();
    switch (normalized) {
      case 'OVERALL ASSESSMENT':
        return 'Overall Assessment';
      case 'OVERALL HEALTH STATUS':
        return 'Overall Health Status';
      case 'LABORATORY RESULTS':
        return 'Laboratory Results';
      case 'ABNORMAL FINDINGS':
        return 'Abnormal Findings';
      case 'NORMAL RANGES':
        return 'Reference Ranges';
      case 'KEY OBSERVATIONS':
        return 'Key Observations';
      case 'RECOMMENDATIONS':
        return 'Recommendations';
      case 'RECOMMENDED NEXT ACTIONS':
        return 'Recommended Next Actions';
      case 'CLINICAL IMPRESSION':
        return 'Clinical Impression';
      case 'FOLLOW-UP SUGGESTIONS':
        return 'Follow-up Suggestions';
      case 'DETAILED MEASUREMENTS ASSESSMENT':
        return 'Measurements';
      case 'ANATOMICAL ASSESSMENT':
        return 'Anatomical Assessment';
      case 'GESTATIONAL AGE ASSESSMENT':
        return 'Gestational Age';
      default:
        return raw
            .toLowerCase()
            .split(' ')
            .map(
                (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  bool _shouldShowPrenatalRiskSummary() {
    final title = widget.title.toLowerCase();
    if (!title.contains('prenatal')) return false;
    return widget.riskLevel != null ||
        (widget.riskFactors != null && widget.riskFactors!.isNotEmpty) ||
        (widget.suggestedActions != null &&
            widget.suggestedActions!.isNotEmpty);
  }

  Color _riskLevelBadgeColor(String riskLevel) {
    final normalized = riskLevel.toLowerCase();
    if (normalized.contains('high')) return AppColors.error;
    if (normalized.contains('low')) return AppColors.success;
    return AppColors.brandPrimary;
  }

  Widget _buildPrenatalRiskSummaryCard() {
    final riskLevel = widget.riskLevel ?? '';
    final riskFactors = widget.riskFactors ?? [];
    final suggestedActions = widget.suggestedActions ?? [];

    final isHighRisk = riskLevel.toLowerCase().contains('high');
    final cardBg = isHighRisk ? _riskHighCardBg : Colors.white;
    final cardBorder = isHighRisk ? _riskHighCardBorder.withValues(alpha: 0.3) : Colors.transparent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isHighRisk ? Border.all(color: cardBorder) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFFE4EE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.psychology_alt_outlined,
                    size: 16, color: AppColors.brandText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('Prenatal Risk Summary', 'Buod ng Prenatal Risk'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Risk Level Section
          if (riskLevel.isNotEmpty) ...[
            _buildRiskSubSection(
              title: _t('Risk Level', 'Antas ng Panganib'),
              icon: Icons.flag_outlined,
              child: Row(
                children: [
                  _buildRiskChip(
                    label: riskLevel.toUpperCase(),
                    color: _riskLevelBadgeColor(riskLevel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Risk Factors Section
          if (riskFactors.isNotEmpty) ...[
            _buildRiskSubSection(
              title: _t('Risk Factors', 'Mga Salik ng Panganib'),
              icon: Icons.warning_amber_rounded,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: riskFactors.map((factor) {
                  final parts = factor.split(':');
                  final factorName =
                      parts.length > 1 ? parts[0].trim() : factor;
                  final isHigh = factor.toLowerCase().contains('high') ||
                      (parts.length > 1 &&
                          parts[1].trim().toLowerCase() == 'high');
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHigh
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHigh
                            ? AppColors.error.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      factorName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isHigh ? AppColors.error : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Suggested Actions Section
          if (suggestedActions.isNotEmpty) ...[
            _buildRiskSubSection(
              title: _t('Suggested Actions', 'Mga Iminumungkahing Aksyon'),
              icon: Icons.lightbulb_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: suggestedActions.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskSubSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildRiskChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
