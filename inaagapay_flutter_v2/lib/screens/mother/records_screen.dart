// lib/screens/mother/records_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/mother_profile_service.dart';
import '../../services/supabase_service.dart';
import '../shared/record_detail_screen.dart';
import '../../widgets/headline.dart';
import '../../widgets/main_button.dart';
import '../../widgets/full_screen_image_viewer.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  int? _motherId;

  List<Map<String, dynamic>> _checkups = [];
  List<Map<String, dynamic>> _ultrasounds = [];
  List<Map<String, dynamic>> _labTests = [];
  Map<int, int> _pregnancyFetalCounts = {};
  Map<int, String> _checkupSymptomSummaries = {};

  String _selectedFilter = 'all';
  String _sortOrder = 'desc';
  String _searchQuery = '';
  final Set<String> _expandedLabInsightAspects = <String>{};
  StateSetter? _recordDetailsModalSetState;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMotherData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshRecordDetailsUi() {
    final modalSetState = _recordDetailsModalSetState;
    if (modalSetState != null) {
      modalSetState(() {});
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadMotherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _motherId = await AuthStorage.getMotherId();

      if (_motherId == null) {
        throw Exception('Mother ID not found');
      }

      final pregnanciesResponse = await SupabaseService.client
          .from('pregnancies')
          .select('pregnancy_id')
          .eq('mother_id', _motherId!);

      if (pregnanciesResponse.isEmpty) {
        setState(() {
          _ultrasounds = [];
          _labTests = [];
        });
      } else {
        final pregnancyIds = pregnanciesResponse
            .map<int>((p) => p['pregnancy_id'] as int)
            .toList();
        await _loadRecordsForPregnancies(pregnancyIds);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecordsForPregnancies(List<int> pregnancyIds) async {
    if (pregnancyIds.isNotEmpty) {
      final checkupsResponse = await SupabaseService.client
          .from('prenatal_checkups')
          .select('*')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('checkup_datetime', ascending: false);

      final ultrasoundsResponse = await SupabaseService.client
          .from('ultrasounds')
          .select('*')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('ultrasound_date', ascending: false);

      final labTestsResponse = await SupabaseService.client
          .from('lab_tests')
          .select('*')
          .inFilter('pregnancy_id', pregnancyIds)
          .order('lab_test_date', ascending: false);

      final pregnancyResponse = await SupabaseService.client
          .from('pregnancies')
          .select('pregnancy_id, fetal_count')
          .inFilter('pregnancy_id', pregnancyIds);

      final checkupIds = (checkupsResponse as List)
          .map<int?>((c) => c['prenatal_checkup_id'] as int?)
          .whereType<int>()
          .toList();

      Map<int, String> symptomSummaries = {};
      if (checkupIds.isNotEmpty) {
        final symptomRows = await SupabaseService.client
            .from('pregnancy_symptoms')
            .select(
                'prenatal_checkup_id, symptom_type_id, notes, symptom_type:symptom_types(symptom_name, risk_category)')
            .inFilter('prenatal_checkup_id', checkupIds);

        for (final symbol
            in (symptomRows as List).cast<Map<String, dynamic>>()) {
          final checkupId = symbol['prenatal_checkup_id'] as int?;
          if (checkupId == null) continue;
          final symptomType = symbol['symptom_type'] as Map<String, dynamic>?;
          final name =
              symptomType?['symptom_name']?.toString() ?? 'Unknown symptom';
          final risk = symptomType?['risk_category']?.toString() ?? 'unknown';
          final note = (symbol['notes'] as String?)?.trim();
          final label = note != null && note.isNotEmpty
              ? '$name ($risk): $note'
              : '$name ($risk)';
          symptomSummaries.update(
            checkupId,
            (existing) {
              final items = existing.split('; ');
              items.add(label);
              return items.join('; ');
            },
            ifAbsent: () => label,
          );
        }
      }

      final fetalCounts = <int, int>{};
      for (final pregnancy
          in (pregnancyResponse as List).cast<Map<String, dynamic>>()) {
        final id = pregnancy['pregnancy_id'] as int?;
        final count = pregnancy['fetal_count'] as int?;
        if (id != null && count != null) {
          fetalCounts[id] = count;
        }
      }

      setState(() {
        _checkups = List<Map<String, dynamic>>.from(checkupsResponse);
        _ultrasounds = List<Map<String, dynamic>>.from(ultrasoundsResponse);
        _labTests = List<Map<String, dynamic>>.from(labTestsResponse);
        _pregnancyFetalCounts = fetalCounts;
        _checkupSymptomSummaries = symptomSummaries;
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return date.toString();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '—';
    try {
      final parsed = DateTime.tryParse(dateTime.toString());
      if (parsed == null) return dateTime.toString();
      return DateFormat('MMM d, yyyy h:mm a').format(parsed);
    } catch (e) {
      return dateTime.toString();
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    final str = value.toString().trim();
    return str.isEmpty ? '—' : str;
  }

  String _formatInputValue(dynamic value) {
    final formatted = _formatValue(value);
    return formatted == '—' ? 'Not inputted' : formatted;
  }

  List<String> _parseImageUrls(dynamic imageField) {
    List<String> urls = [];
    if (imageField != null) {
      final imageString = imageField.toString();
      if (imageString.contains(',')) {
        urls = imageString.split(',').map((url) => url.trim()).toList();
      } else if (imageString.isNotEmpty) {
        urls = [imageString];
      }
    }
    return urls;
  }

  ({String cleanRemarks, String? extractedAi}) _splitRemarksAndAi(
      String? rawRemarks) {
    final source = rawRemarks?.trim() ?? '';
    if (source.isEmpty) {
      return (cleanRemarks: '', extractedAi: null);
    }

    final marker = RegExp(r'\bAI\s*Analysis\s*:', caseSensitive: false);
    final match = marker.firstMatch(source);
    if (match == null) {
      return (cleanRemarks: source, extractedAi: null);
    }

    final notesPart = source.substring(0, match.start).trim();
    final aiPart = source.substring(match.end).trim();
    return (
      cleanRemarks: notesPart,
      extractedAi: aiPart.isEmpty ? null : aiPart,
    );
  }

  ({String cleanRemarks, String? extractedAi}) _splitLabRemarksAndAi(
      String? rawRemarks) {
    return _splitRemarksAndAi(rawRemarks);
  }

  void _showFullScreenImage(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showRecordDetails({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    List<String>? imageUrls,
    String? aiAnalysis,
    bool useStructuredAiInsights = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordDetailScreen(
          title: title,
          rows: rows,
          icon: icon,
          subtitle: subtitle,
          imageUrls: imageUrls,
          aiAnalysis: aiAnalysis,
          useStructuredAiInsights: useStructuredAiInsights,
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
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final List<TextSpan> spans = [];

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
            const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
        children: spans,
      ),
    );
  }

  Map<String, List<String>> _extractAiSections(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => _cleanResidualMarkdown(_normalizeMarkdownLine(l)).trim())
        .toList();

    final Map<String, List<String>> sections = {};
    String currentSection = 'Summary';
    sections[currentSection] = [];

    final headingPattern = RegExp(
      r'^(?:\d+\.\s*)?(RELEVANCE CHECK|RELEVANCE REASON|LABORATORY RESULTS|ABNORMAL FINDINGS|NORMAL RANGES|REFERENCE RANGES|OVERALL ASSESSMENT|RECOMMENDATIONS|KEY OBSERVATIONS|OVERALL HEALTH STATUS|GESTATIONAL AGE ASSESSMENT|DETAILED MEASUREMENTS ASSESSMENT|ANATOMICAL ASSESSMENT|RECOMMENDED NEXT ACTIONS)\s*:\s*(.*)$',
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
        _safeText(line).replaceFirst(RegExp(r'^[-\-*]\s*'), '').trim();
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex == -1) {
      return (testName: cleaned, value: '', status: 'UNKNOWN');
    }

    final testName = cleaned.substring(0, colonIndex).trim();
    final rawValue = _safeText(cleaned.substring(colonIndex + 1)).trim();
    final status = _classifyLabStatus(testName, rawValue);

    final value = rawValue
        .replaceAll('!', '')
        .replaceAll(RegExp(r'\bABNORMAL\b', caseSensitive: false), '')
        .trim();

    return (
      testName: _stripDecorativeDashes(testName),
      value: _stripDecorativeDashes(value),
      status: status
    );
  }

  String _safeText(Object? value) => value?.toString() ?? '';

  String _stripDecorativeDashes(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^[-_=]{2,}$').hasMatch(trimmed)) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'\s+--+\s+'), ' ').trim();
  }

  String _normalizeAspectKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _lineMatchesAspect(String line, String aspect) {
    final a = _normalizeAspectKey(_safeText(aspect));
    final l = _normalizeAspectKey(_safeText(line));
    return a.isNotEmpty && l.contains(a);
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
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
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Status guide: REVIEW = needs clinician review, BORDERLINE/OBSERVE = monitor and correlate, WITHIN NORMAL LIMITS = reassuring in context.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
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
            final expandedDetails = details.isNotEmpty
                ? details
                : 'No additional abnormal/reference details were attached for this test.';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderPrimary),
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
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          onPressed: () {
                            if (isExpanded) {
                              _expandedLabInsightAspects.remove(aspectKey);
                            } else {
                              _expandedLabInsightAspects.add(aspectKey);
                            }
                            _refreshRecordDetailsUi();
                          },
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
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
                  if (isExpanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildFormattedAiText(expandedDetails),
                    ),
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
          if (rest.startsWith('X') || rest.startsWith('✗'))
            rest = rest.substring(1).trim();
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

    IconData headerIcon = Icons.straighten_outlined;
    Color headerColor = AppColors.brandPrimary;

    if (title.toUpperCase().contains('ANATOMICAL')) {
      headerIcon = Icons.accessibility_new_outlined;
    } else if (title.toUpperCase().contains('ABNORMAL')) {
      headerIcon = Icons.warning_amber_outlined;
      headerColor = Colors.orange;
    } else if (title.toUpperCase().contains('NORMAL RANGES')) {
      headerIcon = Icons.analytics_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            headerColor == Colors.orange ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: headerColor == Colors.orange
                ? Colors.orange.shade200
                : AppColors.borderPrimary),
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

  String _friendlyAiSectionTitle(String title) {
    switch (title) {
      case 'LABORATORY RESULTS':
        return 'Laboratory Results';
      case 'ABNORMAL FINDINGS':
        return 'Abnormal Findings';
      case 'NORMAL RANGES':
        return 'Reference Ranges';
      case 'OVERALL ASSESSMENT':
        return 'Overall Assessment';
      case 'RECOMMENDATIONS':
        return 'Recommendations';
      case 'RELEVANCE CHECK':
        return 'Relevance Check';
      case 'RELEVANCE REASON':
        return 'Relevance Reason';
      case 'KEY OBSERVATIONS':
        return 'Key Observations';
      default:
        return title
            .split(' ')
            .map(
                (w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  Widget _buildAiSectionCard(String title, List<String> lines) {
    final safeTitle = title.toUpperCase();
    final isAbnormal = safeTitle.contains('ABNORMAL');
    final isRecommendation = safeTitle.contains('RECOMMENDATION') ||
        safeTitle.contains('RECOMMENDED');
    final isAssessment =
        safeTitle.contains('ASSESSMENT') || safeTitle.contains('HEALTH STATUS');

    final Color accent = isAbnormal
        ? Colors.red
        : isRecommendation
            ? Colors.blue
            : isAssessment
                ? Colors.deepPurple
                : AppColors.brandPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _friendlyAiSectionTitle(safeTitle),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          ...lines.map((line) {
            String cleaned = line.replaceFirst(RegExp(r'^[-*]\s*'), '').trim();
            if (RegExp(r'^[A-Z_]+$').hasMatch(cleaned)) {
              cleaned = cleaned
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((word) => word.isEmpty
                      ? ''
                      : '${word[0]}${word.substring(1).toLowerCase()}')
                  .join(' ');
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFormattedAiText(cleaned),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStructuredAiInsights(String text) {
    final sections = _extractAiSections(text);
    if (sections.isEmpty) return _buildFormattedAiText(text);

    const sectionOrder = [
      'OVERALL HEALTH STATUS',
      'OVERALL ASSESSMENT',
      'GESTATIONAL AGE ASSESSMENT',
      'LABORATORY RESULTS',
      'DETAILED MEASUREMENTS ASSESSMENT',
      'ANATOMICAL ASSESSMENT',
      'ABNORMAL FINDINGS',
      'NORMAL RANGES',
      'KEY OBSERVATIONS',
      'RECOMMENDATIONS',
      'RECOMMENDED NEXT ACTIONS',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _generateUltrasoundAIInsights(Map<String, dynamic> ultrasound) {
    final remarks = ultrasound['remarks']?.toString().toLowerCase() ?? '';
    final buffer = StringBuffer();

    buffer.write('🤖 Ultrasound AI Insights:\n\n');

    if (remarks.contains('normal') || remarks.contains('healthy')) {
      buffer.write(
          '✅ **Normal Findings**: Ultrasound appears normal with healthy fetal development.\n\n');
    } else if (remarks.contains('follow') || remarks.contains('monitor')) {
      buffer.write(
          '📊 **Follow-up Recommended**: Some findings require additional observation.\n\n');
    } else if (remarks.contains('concern') || remarks.contains('abnormal')) {
      buffer.write(
          '🔍 **Further Evaluation Needed**: Discuss findings with healthcare provider.\n\n');
    } else {
      buffer.write(
          '📋 **Diagnostic Information**: The ultrasound provides important diagnostic information.\n\n');
    }

    buffer.write('💡 **Key Recommendations**:\n');
    buffer.write('• Discuss findings with your healthcare provider\n');
    buffer.write('• Continue all scheduled prenatal appointments\n');

    return buffer.toString();
  }

  String _generatePrenatalAIInsights(Map<String, dynamic> checkup) {
    final bpSys = _toDouble(checkup['blood_pressure_systolic']);
    final bpDia = _toDouble(checkup['blood_pressure_diastolic']);
    final weight = _toDouble(checkup['checkup_weight']);
    final edemaRaw = _formatValue(checkup['edema']);
    final edema = edemaRaw.toLowerCase();
    final tdDose = _formatValue(checkup['td_vaccine_dose']);

    final fhrRaw = _formatValue(checkup['fetal_heart_beat']);
    final fhr = int.tryParse(fhrRaw);

    String overallAssessment =
        'Current prenatal checkup findings appear stable overall.';
    if (bpSys != null && bpDia != null && (bpSys >= 140 || bpDia >= 90)) {
      overallAssessment =
          'Blood pressure is elevated and needs closer monitoring for hypertensive disorders of pregnancy.';
    } else if (bpSys != null && bpDia != null && (bpSys < 90 || bpDia < 60)) {
      overallAssessment =
          'Blood pressure is lower than typical range; monitor hydration, symptoms, and follow-up trends.';
    } else if (fhr != null && (fhr < 120 || fhr > 160)) {
      overallAssessment =
          'Fetal heart rate is outside the usual expected range and should be reviewed clinically.';
    } else if (edema != '—' && edema != 'none') {
      overallAssessment =
          'Mild edema is noted; monitor progression and correlate with blood pressure and symptoms.';
    }

    final buffer = StringBuffer();
    buffer.write('OVERALL ASSESSMENT: $overallAssessment\n\n');

    buffer.write('KEY OBSERVATIONS:\n');
    if (bpSys != null && bpDia != null) {
      if (bpSys >= 140 || bpDia >= 90) {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [REVIEW].\n');
      } else if (bpSys < 90 || bpDia < 60) {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [MONITOR].\n');
      } else {
        buffer.write(
            '- Maternal Vitals - Blood Pressure: $bpSys/$bpDia mmHg [WITHIN NORMAL LIMITS].\n');
      }
    } else {
      buffer.write(
          '- Maternal Vitals - Blood Pressure: Not documented in this record.\n');
    }

    if (weight != null) {
      buffer.write(
          '- Maternal Vitals - Weight: ${weight.toStringAsFixed(1)} kg.\n');
    }

    if (fhr != null) {
      if (fhr >= 120 && fhr <= 160) {
        buffer.write(
            '- Fetal Status - Heart Rate: $fhr bpm [WITHIN NORMAL LIMITS].\n');
      } else {
        buffer.write('- Fetal Status - Heart Rate: $fhr bpm [REVIEW].\n');
      }
    } else if (fhrRaw != '—') {
      buffer.write('- Fetal Status - Heart Rate: $fhrRaw [REVIEW MANUALLY].\n');
    }

    final fetalPosition = _formatValue(checkup['fetal_position']);
    if (fetalPosition != '—') {
      buffer.write('- Fetal Status - Position: $fetalPosition.\n');
    }

    if (edemaRaw != '—') {
      if (edema == 'none') {
        buffer.write('- Maternal Observation - Edema: None reported.\n');
      } else {
        buffer.write('- Maternal Observation - Edema: $edemaRaw [MONITOR].\n');
      }
    }

    if (tdDose != '—') {
      buffer.write('- Preventive Care - TD Vaccine: $tdDose documented.\n');
    }

    final nextSchedule = _formatDate(checkup['next_schedule']);
    if (nextSchedule != '—') {
      buffer.write('- Follow-up - Next Schedule: $nextSchedule.\n');
    }

    buffer.write('\nRECOMMENDATIONS:\n');
    buffer.write('- Continue scheduled prenatal follow-up visits.\n');
    buffer
        .write('- Monitor maternal warning signs and fetal movement daily.\n');
    if ((bpSys != null && bpDia != null && (bpSys >= 140 || bpDia >= 90)) ||
        (fhr != null && (fhr < 120 || fhr > 160))) {
      buffer.write(
          '- Prioritize clinician review for blood pressure and/or fetal heart findings.\n');
    }
    if (edema != '—' && edema != 'none') {
      buffer.write('- Reassess edema severity in next checkup.\n');
    }

    return buffer.toString().trim();
  }

  Future<Map<String, dynamic>?> _fetchCheckupDetails(
      int prenatalCheckupId, dynamic checkupDateTime) async {
    try {
      final aiRow = await SupabaseService.client
          .from('ai_responses')
          .select('ai_response_id, response')
          .eq('reference_table', 'prenatal_checkups')
          .eq('reference_id', prenatalCheckupId)
          .eq('response_type', 'risk_assessment')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String? aiResponse = aiRow?['response'] as String?;
      String? riskLevel;
      String riskFactors = '';
      String medicationPlans = 'None';
      String givenMedications = 'None';
      String ferrousQuantity = 'Not given';
      String calciumQuantity = 'Not given';

      if (aiRow != null) {
        final aiResponseId = aiRow['ai_response_id'] as int?;
        if (aiResponseId != null) {
          final riskRow = await SupabaseService.client
              .from('pregnancy_risk_assessments')
              .select('pregnancy_risk_id, risk_level')
              .eq('ai_response_id', aiResponseId)
              .maybeSingle();

          if (riskRow != null) {
            riskLevel = riskRow['risk_level']?.toString();
            final factorRows = await SupabaseService.client
                .from('pregnancy_risk_factors')
                .select('factor, risk_influence')
                .eq('pregnancy_risk_id', riskRow['pregnancy_risk_id'])
                .order('risk_factor_id', ascending: true);

            final factorList = <String>[];
            for (final factor
                in (factorRows as List).cast<Map<String, dynamic>>()) {
              final factorText = factor['factor']?.toString() ?? '';
              final influence = factor['risk_influence']?.toString() ?? '';
              if (factorText.isNotEmpty) {
                factorList.add(
                    '$factorText${influence.isNotEmpty ? ' ($influence)' : ''}');
              }
            }
            riskFactors = factorList.join('; ');
          }
        }
      }

      if (checkupDateTime != null) {
        final date = DateTime.tryParse(checkupDateTime.toString());
        final checkupDateString =
            date != null ? date.toIso8601String().split('T')[0] : null;
        if (checkupDateString != null && _motherId != null) {
          final givenRows = await SupabaseService.client
              .from('given_medications')
              .select('given_medication_name, quantity')
              .eq('mother_id', _motherId!)
              .eq('date_given', checkupDateString);

          final medicationRows = await SupabaseService.client
              .from('mother_medications')
              .select(
                  'mother_medication_name, quantity, frequency, start_date, end_date')
              .eq('mother_id', _motherId!)
              .eq('start_date', checkupDateString);

          final givenItems = <String>[];
          for (final row in (givenRows as List).cast<Map<String, dynamic>>()) {
            final name = row['given_medication_name']?.toString() ?? 'Unknown';
            final quantity = row['quantity']?.toString() ?? '1';
            givenItems.add('$name x$quantity');
            if (name.toLowerCase().contains('ferrous')) {
              ferrousQuantity = quantity;
            }
            if (name.toLowerCase().contains('calcium')) {
              calciumQuantity = quantity;
            }
          }
          if (givenItems.isNotEmpty) {
            givenMedications = givenItems.join('; ');
          }

          final planItems = <String>[];
          for (final row
              in (medicationRows as List).cast<Map<String, dynamic>>()) {
            final name = row['mother_medication_name']?.toString() ?? 'Unknown';
            final qty = row['quantity']?.toString() ?? '1';
            final freq = row['frequency']?.toString();
            final start = row['start_date']?.toString();
            final end = row['end_date']?.toString();
            final details = [
              qty != 'null' ? 'Qty $qty' : null,
              freq,
              start != null ? 'Start $start' : null,
              end != null ? 'End $end' : null
            ].where((element) => element != null).join(' · ');
            planItems.add('$name${details.isNotEmpty ? ' ($details)' : ''}');
          }
          if (planItems.isNotEmpty) {
            medicationPlans = planItems.join('; ');
          }
        }
      }

      return {
        'aiResponse': aiResponse,
        'riskLevel': riskLevel,
        'riskFactors': riskFactors,
        'medicationPlans': medicationPlans,
        'givenMedications': givenMedications,
        'ferrousQuantity': ferrousQuantity,
        'calciumQuantity': calciumQuantity,
      };
    } catch (_) {
      return null;
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _getFilteredAndSortedRecords() {
    List<Map<String, dynamic>> allRecords = [];

    for (var checkup in _checkups) {
      allRecords.add({
        ...checkup,
        'record_type': 'checkup',
        'record_date': checkup['checkup_datetime'],
      });
    }

    for (var ultrasound in _ultrasounds) {
      allRecords.add({
        ...ultrasound,
        'record_type': 'ultrasound',
        'record_date': ultrasound['ultrasound_date'],
      });
    }

    for (var labTest in _labTests) {
      allRecords.add({
        ...labTest,
        'record_type': 'labtest',
        'record_date': labTest['lab_test_date'],
      });
    }

    if (_selectedFilter != 'all') {
      allRecords = allRecords
          .where((record) => record['record_type'] == _selectedFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allRecords = allRecords.where((record) {
        if (record['record_type'] == 'checkup') {
          return _formatDateTime(record['checkup_datetime'])
                  .toLowerCase()
                  .contains(query) ||
              (record['remarks']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (record['blood_pressure_systolic']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false) ||
              (record['blood_pressure_diastolic']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false);
        }

        if (record['record_type'] == 'ultrasound') {
          return _formatDate(record['ultrasound_date'])
                  .toLowerCase()
                  .contains(query) ||
              (record['remarks']?.toString().toLowerCase().contains(query) ??
                  false);
        }

        return _formatDate(record['lab_test_date'])
                .toLowerCase()
                .contains(query) ||
            (record['lab_test_type']
                    ?.toString()
                    .toLowerCase()
                    .contains(query) ??
                false) ||
            (record['remarks']?.toString().toLowerCase().contains(query) ??
                false);
      }).toList();
    }

    allRecords.sort((a, b) {
      final dateA = DateTime.tryParse(a['record_date'] ?? '');
      final dateB = DateTime.tryParse(b['record_date'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return _sortOrder == 'desc'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    return allRecords;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Headline(text: 'Failed to Load Records'),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MainButton(
                label: 'Retry',
                onPressed: _loadMotherData,
              ),
            ],
          ),
        ),
      );
    }

    final allRecords = _getFilteredAndSortedRecords();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.brandPrimary,
            labelColor: AppColors.brandPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'All Records'),
              Tab(text: 'Statistics'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecordsTab(allRecords),
              _buildStatisticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(List<Map<String, dynamic>> allRecords) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search records...',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Records')),
                          DropdownMenuItem(
                              value: 'checkup', child: Text('Checkups Only')),
                          DropdownMenuItem(
                              value: 'ultrasound',
                              child: Text('Ultrasounds Only')),
                          DropdownMenuItem(
                              value: 'labtest', child: Text('Lab Tests Only')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _sortOrder,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'desc', child: Text('Newest First')),
                        DropdownMenuItem(
                            value: 'asc', child: Text('Oldest First')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortOrder = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: allRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.folder_open,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matching records found'
                            : 'No records available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try adjusting your search or filters'
                            : 'Your medical records will appear here',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMotherData,
                  color: AppColors.brandPrimary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allRecords.length,
                    itemBuilder: (context, index) {
                      final record = allRecords[index];
                      final isCheckup = record['record_type'] == 'checkup';
                      final isUltrasound =
                          record['record_type'] == 'ultrasound';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isCheckup
                                  ? AppColors.brandPrimary.withOpacity(0.1)
                                  : isUltrasound
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isCheckup
                                  ? Icons.medical_services
                                  : isUltrasound
                                      ? Icons.photo
                                      : Icons.science,
                              color: isCheckup
                                  ? AppColors.brandPrimary
                                  : isUltrasound
                                      ? Colors.purple
                                      : Colors.orange,
                            ),
                          ),
                          title: Text(
                            isCheckup
                                ? 'Prenatal Checkup'
                                : isUltrasound
                                    ? 'Ultrasound'
                                    : (record['lab_test_type'] ?? 'Lab Test'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                isCheckup
                                    ? _formatDateTime(
                                        record['checkup_datetime'])
                                    : _formatDate(isUltrasound
                                        ? record['ultrasound_date']
                                        : record['lab_test_date']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (isCheckup) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'BP: ${_formatValue(record['blood_pressure_systolic'])}/${_formatValue(record['blood_pressure_diastolic'])}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (record['health_worker_name'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'By: ${record['health_worker_name']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () async {
                            if (isCheckup) {
                              final bpSys = _formatInputValue(
                                  record['blood_pressure_systolic']);
                              final bpDia = _formatInputValue(
                                  record['blood_pressure_diastolic']);
                              final checkupId = record['prenatal_checkup_id'];
                              String? aiAnalysis;
                              String? riskLevel;
                              String riskFactors = '';
                              String medicationPlansSummary = 'None';
                              String givenMedicationsSummary = 'None';
                              String ferrousSummary = 'Not given';
                              String calciumSummary = 'Not given';

                              if (checkupId is int) {
                                final checkupDetails =
                                    await _fetchCheckupDetails(
                                        checkupId, record['checkup_datetime']);
                                if (checkupDetails != null) {
                                  riskLevel =
                                      checkupDetails['riskLevel'] as String?;
                                  riskFactors =
                                      checkupDetails['riskFactors'] as String;
                                  aiAnalysis =
                                      checkupDetails['aiResponse'] as String?;
                                  medicationPlansSummary =
                                      checkupDetails['medicationPlans']
                                          as String;
                                  givenMedicationsSummary =
                                      checkupDetails['givenMedications']
                                          as String;
                                  ferrousSummary =
                                      checkupDetails['ferrousQuantity']
                                          as String;
                                  calciumSummary =
                                      checkupDetails['calciumQuantity']
                                          as String;
                                }

                                if (aiAnalysis == null ||
                                    aiAnalysis.trim().isEmpty) {
                                  aiAnalysis = await MotherProfileService
                                      .getCheckupAIAnalysis(
                                    checkupId,
                                  );
                                }
                              }

                              aiAnalysis = (aiAnalysis != null &&
                                      aiAnalysis.trim().isNotEmpty)
                                  ? aiAnalysis.trim()
                                  : _generatePrenatalAIInsights(record);
                              final symptomSummary = _checkupSymptomSummaries[
                                      record['prenatal_checkup_id'] as int? ??
                                          -1] ??
                                  'None recorded';
                              final fetalCount = (_pregnancyFetalCounts[
                                          record['pregnancy_id'] as int? ?? -1]
                                      ?.toString()) ??
                                  'Not inputted';
                              final riskLevelValue = (riskLevel != null &&
                                      riskLevel.trim().isNotEmpty)
                                  ? _formatInputValue(riskLevel)
                                  : 'Not inputted';
                              final riskFactorsValue =
                                  riskFactors.trim().isNotEmpty
                                      ? riskFactors
                                      : 'Not inputted';
                              _showRecordDetails(
                                title: 'Prenatal Checkup',
                                subtitle:
                                    _formatDateTime(record['checkup_datetime']),
                                icon: Icons.medical_services,
                                rows: [
                                  MapEntry(
                                      'Date',
                                      record['checkup_datetime'] == null
                                          ? 'Not inputted'
                                          : _formatDateTime(
                                              record['checkup_datetime'])),
                                  MapEntry('Fetal Count', fetalCount),
                                  MapEntry(
                                      'Age of Gestation',
                                      _formatInputValue(
                                          record['age_of_gestation'])),
                                  MapEntry(
                                      'Weight (kg)',
                                      _formatInputValue(
                                          record['checkup_weight'])),
                                  MapEntry('Blood Pressure', '$bpSys/$bpDia'),
                                  MapEntry(
                                      'Fetal Position',
                                      _formatInputValue(
                                          record['fetal_position'])),
                                  MapEntry(
                                      'Fetal Heart Tone',
                                      _formatInputValue(
                                          record['fetal_heart_tone'])),
                                  MapEntry(
                                      'Fetal Heart Beat',
                                      _formatInputValue(
                                          record['fetal_heart_beat'])),
                                  MapEntry('Symptoms', symptomSummary),
                                  MapEntry('Medication Plans',
                                      medicationPlansSummary),
                                  MapEntry('Given Medications',
                                      givenMedicationsSummary),
                                  MapEntry('Ferrous + FA', ferrousSummary),
                                  MapEntry('Calcium', calciumSummary),
                                  MapEntry('Risk Level', riskLevelValue),
                                  MapEntry('Risk Factors', riskFactorsValue),
                                  MapEntry(
                                      'TD Vaccine',
                                      _formatInputValue(
                                          record['td_vaccine_dose'])),
                                  MapEntry('Edema',
                                      _formatInputValue(record['edema'])),
                                  MapEntry('Remarks',
                                      _formatInputValue(record['remarks'])),
                                  MapEntry(
                                      'Next Schedule',
                                      record['next_schedule'] == null
                                          ? 'Not inputted'
                                          : _formatDate(
                                              record['next_schedule'])),
                                ],
                                aiAnalysis: aiAnalysis,
                                useStructuredAiInsights: true,
                              );
                            } else if (isUltrasound) {
                              final imageUrls =
                                  _parseImageUrls(record['ultrasound_image']);
                              final split = _splitRemarksAndAi(
                                  record['remarks']?.toString());
                              String? aiAnalysis;
                              final ultrasoundId = record['ultrasound_id'];
                              if (ultrasoundId is int) {
                                aiAnalysis = await MotherProfileService
                                    .getUltrasoundAIAnalysis(
                                  ultrasoundId,
                                );
                              }

                              String finalRemarks = split.cleanRemarks;
                              if (aiAnalysis != null &&
                                  aiAnalysis.trim() == finalRemarks.trim()) {
                                finalRemarks = '';
                              }

                              aiAnalysis = (aiAnalysis != null &&
                                      aiAnalysis.trim().isNotEmpty)
                                  ? aiAnalysis.trim()
                                  : split.extractedAi ??
                                      _generateUltrasoundAIInsights(record);
                              _showRecordDetails(
                                title: 'Ultrasound',
                                subtitle:
                                    _formatDate(record['ultrasound_date']),
                                icon: Icons.monitor_heart,
                                imageUrls:
                                    imageUrls.isNotEmpty ? imageUrls : null,
                                rows: [
                                  MapEntry('Ultrasound Date',
                                      _formatDate(record['ultrasound_date'])),
                                  MapEntry(
                                      'Location',
                                      _formatValue(
                                          record['ultrasound_location'])),
                                  MapEntry(
                                      'Full Name',
                                      _formatValue(
                                          record['health_worker_name'])),
                                  MapEntry(
                                      'Institution',
                                      _formatValue(
                                          record['health_worker_institution'])),
                                  MapEntry(
                                      'Profession',
                                      _formatValue(
                                          record['health_worker_profession'])),
                                  MapEntry(
                                      'Remarks', _formatValue(finalRemarks)),
                                ],
                                aiAnalysis: aiAnalysis,
                                useStructuredAiInsights:
                                    aiAnalysis != null && aiAnalysis.isNotEmpty,
                              );
                            } else {
                              final imageUrls =
                                  _parseImageUrls(record['lab_test_image']);
                              final split = _splitRemarksAndAi(
                                  record['remarks']?.toString());

                              String? aiAnalysis;
                              final labTestId = record['lab_test_id'];
                              if (labTestId is int) {
                                aiAnalysis = await MotherProfileService
                                    .getLabTestAIAnalysis(
                                  labTestId,
                                );
                              }

                              aiAnalysis = (aiAnalysis != null &&
                                      aiAnalysis.trim().isNotEmpty)
                                  ? aiAnalysis.trim()
                                  : split.extractedAi;

                              _showRecordDetails(
                                title: record['lab_test_type'] ?? 'Lab Test',
                                subtitle: _formatDate(record['lab_test_date']),
                                icon: Icons.science,
                                imageUrls:
                                    imageUrls.isNotEmpty ? imageUrls : null,
                                rows: [
                                  MapEntry('Lab Test Type',
                                      _formatValue(record['lab_test_type'])),
                                  MapEntry('Lab Test Date',
                                      _formatDate(record['lab_test_date'])),
                                  MapEntry(
                                      'Full Name',
                                      _formatValue(
                                          record['health_worker_name'])),
                                  MapEntry(
                                      'Institution',
                                      _formatValue(
                                          record['health_worker_institution'])),
                                  MapEntry(
                                      'Profession',
                                      _formatValue(
                                          record['health_worker_profession'])),
                                  MapEntry('Notes',
                                      _formatValue(split.cleanRemarks)),
                                ],
                                aiAnalysis: aiAnalysis,
                                useStructuredAiInsights:
                                    aiAnalysis != null && aiAnalysis.isNotEmpty,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    final totalCheckups = _checkups.length;
    final totalUltrasounds = _ultrasounds.length;
    final totalLabTests = _labTests.length;
    final totalRecords = totalCheckups + totalUltrasounds + totalLabTests;

    final allRecords = _getFilteredAndSortedRecords();
    final latestRecord = allRecords.isNotEmpty ? allRecords.first : null;

    final now = DateTime.now();
    final last6Months =
        List.generate(6, (i) => DateTime(now.year, now.month - i, 1))
            .reversed
            .toList();

    final Map<String, int> recordsByMonth = {};
    for (final month in last6Months) {
      recordsByMonth[DateFormat('MMM yyyy').format(month)] = 0;
    }

    for (final record in allRecords) {
      final dateStr = record['record_date'];
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final monthKey = DateFormat('MMM yyyy').format(date);
      if (recordsByMonth.containsKey(monthKey)) {
        recordsByMonth[monthKey] = (recordsByMonth[monthKey] ?? 0) + 1;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Records',
                  totalRecords.toString(),
                  Icons.folder,
                  AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Checkups',
                  totalCheckups.toString(),
                  Icons.medical_services,
                  AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Ultrasounds',
                  totalUltrasounds.toString(),
                  Icons.photo,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Lab Tests',
                  totalLabTests.toString(),
                  Icons.science,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (latestRecord != null) ...[
            const Text(
              'LATEST RECORD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (latestRecord['record_type'] == 'ultrasound'
                              ? Colors.purple
                              : latestRecord['record_type'] == 'checkup'
                                  ? AppColors.brandPrimary
                                  : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      latestRecord['record_type'] == 'ultrasound'
                          ? Icons.photo
                          : latestRecord['record_type'] == 'checkup'
                              ? Icons.medical_services
                              : Icons.science,
                      color: latestRecord['record_type'] == 'ultrasound'
                          ? Colors.purple
                          : latestRecord['record_type'] == 'checkup'
                              ? AppColors.brandPrimary
                              : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestRecord['record_type'] == 'checkup'
                              ? 'Prenatal Checkup'
                              : latestRecord['record_type'] == 'ultrasound'
                                  ? 'Ultrasound'
                                  : (latestRecord['lab_test_type'] ??
                                      'Lab Test'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestRecord['record_type'] == 'checkup'
                              ? _formatDateTime(latestRecord['record_date'])
                              : _formatDate(latestRecord['record_date']),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'RECORDS BY MONTH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...recordsByMonth.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Container(
                          height: 30,
                          width: (entry.value / 10) *
                              MediaQuery.of(context).size.width *
                              0.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.brandPrimary,
                                AppColors.brandSecondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'View Checkups',
                        Icons.medical_services,
                        AppColors.brandPrimary,
                        () {
                          setState(() {
                            _selectedFilter = 'checkup';
                            _tabController.animateTo(0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        'View Lab Tests',
                        Icons.science,
                        Colors.orange,
                        () {
                          setState(() {
                            _selectedFilter = 'labtest';
                            _tabController.animateTo(0);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'View Ultrasounds',
                        Icons.photo,
                        Colors.purple,
                        () {
                          setState(() {
                            _selectedFilter = 'ultrasound';
                            _tabController.animateTo(0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
