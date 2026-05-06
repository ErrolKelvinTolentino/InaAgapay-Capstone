import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
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
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final IconData icon;
  final String? subtitle;
  final List<String>? imageUrls;
  final String? aiAnalysis;
  final bool useStructuredAiInsights;

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final Set<String> _expandedLabInsightAspects = <String>{};

  // Section accent colors — pink palette variations
  static const _accentRecord = Color(0xFFE6398D); // deep rose
  static const _accentWorker = Color(0xFFD44B8A); // medium pink
  static const _accentNotes = Color(0xFFC7607E); // warm coral-pink

  @override
  Widget build(BuildContext context) {
    final hasAi =
        widget.aiAnalysis != null && widget.aiAnalysis!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(widget.title),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
              if (hasAi) ...[
                const SizedBox(height: 14),
                if (_shouldShowPrenatalRiskSummary())
                  _buildPrenatalRiskSummaryCard(),
                if (_shouldShowPrenatalRiskSummary())
                  const SizedBox(height: 14),
                _buildAiCard(widget.aiAnalysis!.trim()),
              ],
            ],
          ),
        ),
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
              const Text(
                'Attached Images',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${imageUrls.length} file${imageUrls.length > 1 ? 's' : ''}',
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
      if (t == 'pregnancy symptoms') return const Color(0xFFF06292);
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
      if (t == 'pregnancy symptoms') return Icons.healing;
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
            child: const Text(
              'No additional details available.',
              style: TextStyle(color: AppColors.textSecondary),
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
    return _normalizeForCompare(label);
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
        if (['date', 'ageofgestation', 'weight(kg)', 'bloodpressure']
            .contains(key)) {
          vitals.add(row);
        } else if ([
          'fetalcount',
          'fetalposition',
          'fetalhearttone',
          'fetalheartbeat',
          'edema'
        ].contains(key)) {
          fetal.add(row);
        } else if (['symptoms'].contains(key)) {
          symptoms.add(row);
        } else if ([
          'medicationplans',
          'givenmedications',
          'ferrous+fa',
          'calcium',
          'tdvaccine'
        ].contains(key)) {
          meds.add(row);
        } else if (['nextschedule', 'remarks'].contains(key)) {
          schedule.add(row);
        } else if (['risklevel', 'riskfactors'].contains(key)) {
          // Skip risk level and factors (they go to the AI card area or can be ignored here since they're in card now)
        } else {
          vitals.add(row); // fallback
        }
      }

      return {
        'Vitals': vitals,
        if (fetal.isNotEmpty) 'Fetal Assessment': fetal,
        if (symptoms.isNotEmpty) 'Pregnancy Symptoms': symptoms,
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

  Widget _buildDetailSection(
      String title, List<MapEntry<String, String>> rows) {
    final accent = _sectionAccent(title);
    final icon = _sectionIcon(title);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                      title,
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
          value == '-' || value == '—' ? 'Not provided' : value;
      filtered.add(MapEntry(label, displayValue));
    }

    return filtered;
  }

  Widget _buildDetailRow(String label, String value) {
    final isNotProvided = value.toLowerCase() == 'not provided';
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFFE4EE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.useStructuredAiInsights)
            _buildStructuredAiInsights(aiText)
          else
            _buildFormattedAiText(aiText),
        ],
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
      return const Text(
        'No AI insights available.',
        style: TextStyle(color: AppColors.textSecondary),
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
    if (_isConcerningStatus(status)) return Colors.red.shade50;
    if (_isCautionStatus(status)) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _statusChipBorder(String status) {
    if (_isConcerningStatus(status)) return Colors.red.shade200;
    if (_isCautionStatus(status)) return Colors.orange.shade200;
    return Colors.green.shade200;
  }

  Color _statusChipTextColor(String status) {
    if (_isConcerningStatus(status)) return Colors.red;
    if (_isCautionStatus(status)) return Colors.orange.shade800;
    return Colors.green;
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
      headerColor = Colors.green;
      headerIcon = Icons.child_care_outlined;
    } else if (normalized == 'ABNORMAL FINDINGS') {
      headerColor = Colors.red;
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
      color = hasHealthy ? Colors.green : Colors.orange;
      icon = Icons.monitor_heart_outlined;
    } else if (normalized == 'DETAILED MEASUREMENTS ASSESSMENT') {
      color = Colors.teal;
      icon = Icons.straighten;
    } else if (normalized == 'ANATOMICAL ASSESSMENT') {
      color = Colors.green;
      icon = Icons.child_care_outlined;
    } else if (normalized == 'ABNORMAL FINDINGS') {
      color = Colors.red;
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
    if (!widget.useStructuredAiInsights) return false;
    final title = widget.title.toLowerCase();
    if (!title.contains('prenatal') && !title.contains('checkup')) {
      return false;
    }
    return _rowValue('Risk Level') != null || _rowValue('Risk Factors') != null;
  }

  String? _rowValue(String label) {
    try {
      return widget.rows
          .firstWhere(
            (row) =>
                _normalizeForCompare(row.key) == _normalizeForCompare(label),
          )
          .value;
    } catch (_) {
      return null;
    }
  }

  Color _riskLevelBadgeColor(String riskLevel) {
    final normalized = riskLevel.toLowerCase();
    if (normalized.contains('high')) return AppColors.error;
    if (normalized.contains('low')) return AppColors.success;
    return AppColors.brandPrimary;
  }

  Widget _buildPrenatalRiskSummaryCard() {
    final riskLevel = _rowValue('Risk Level') ?? 'Not inputted';
    final riskFactors = _rowValue('Risk Factors') ?? 'Not inputted';
    final factorCount = riskFactors.toLowerCase() == 'not inputted'
        ? 0
        : riskFactors.split(RegExp(r';\s*')).length;

    return Container(
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
              const Expanded(
                child: Text(
                  'Prenatal Risk Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryPill(
                icon: Icons.flag_outlined,
                label: riskLevel,
                color: _riskLevelBadgeColor(riskLevel),
              ),
              const SizedBox(width: 10),
              _buildSummaryPill(
                icon: Icons.fact_check_outlined,
                label: 'Factors $factorCount',
                color: AppColors.brandAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Clinical Signals',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            riskFactors,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
