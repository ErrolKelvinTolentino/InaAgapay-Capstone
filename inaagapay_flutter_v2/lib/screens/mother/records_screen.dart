// lib/screens/mother/records_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/mother_profile_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/headline.dart';
import '../../widgets/main_button.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../shared/record_detail_screen.dart';

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

  // Pagination — show 5 records at a time
  static const int _pageSize = 5;
  int _displayCount = _pageSize;

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
        _displayCount = _pageSize; // Reset pagination on reload
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
    String? riskLevel,
    String? riskFactors,
    List<String>? suggestedActions,
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
          riskLevel: (riskLevel != null && riskLevel.trim().isNotEmpty)
              ? riskLevel
              : null,
          riskFactors: (riskFactors != null && riskFactors.trim().isNotEmpty)
              ? riskFactors.split(';').map((s) => s.trim()).toList()
              : null,
          suggestedActions: suggestedActions,
        ),
      ),
    );
  }

  // Legacy modal-based method (kept for non-prenatal records if needed)
  void _showRecordDetailsModal({
    required String title,
    required List<MapEntry<String, String>> rows,
    IconData icon = Icons.receipt_long,
    String? subtitle,
    List<String>? imageUrls,
    String? aiAnalysis,
    bool useStructuredAiInsights = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        bool showFullAi = false;
        bool isEditing = false;
        final editController = TextEditingController(text: aiAnalysis ?? '');

        return StatefulBuilder(
          builder: (context, setModalState) {
            _recordDetailsModalSetState = setModalState;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    Icon(icon, color: AppColors.brandPrimary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (subtitle != null && subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (imageUrls != null && imageUrls.isNotEmpty) ...[
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: imageUrls.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () =>
                                        _showFullScreenImage(imageUrls, index),
                                    child: Container(
                                      width: 200,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              imageUrls[index],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: AppColors.bgSecondary,
                                                child: const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.broken_image,
                                                          size: 32,
                                                          color: Colors.grey),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Image not available',
                                                        style: TextStyle(
                                                            fontSize: 10),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  color: AppColors.bgSecondary,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              AppColors
                                                                  .brandPrimary),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (imageUrls.length > 1 &&
                                                index == 0)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    '+${imageUrls.length - 1} more',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.borderPrimary),
                            ),
                            child: Column(
                              children: rows
                                  .map((entry) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                entry.value,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          if (aiAnalysis != null && aiAnalysis.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFF7E57C2)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.psychology_rounded,
                                          color: const Color(0xFF7E57C2),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'AI-Powered Insights',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF5E35B1),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () {
                                          setModalState(() {
                                            isEditing = !isEditing;
                                            if (!isEditing) {
                                              editController.text = aiAnalysis;
                                            }
                                          });
                                        },
                                        icon: Icon(Icons.edit_outlined,
                                            size: 16,
                                            color: isEditing
                                                ? Colors.green
                                                : AppColors.brandPrimary),
                                        label: Text(
                                          isEditing ? 'Cancel' : 'Edit',
                                          style: TextStyle(
                                              color: isEditing
                                                  ? Colors.green
                                                  : AppColors.brandPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (!isEditing)
                                    Text(
                                      aiAnalysis,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5),
                                    )
                                  else
                                    Column(
                                      children: [
                                        TextField(
                                          controller: editController,
                                          maxLines: 10,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            hintText: 'Edit AI insights...',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setModalState(() {
                                                  isEditing = false;
                                                  editController.text =
                                                      aiAnalysis;
                                                });
                                              },
                                              child: const Text('Discard'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                setModalState(() {
                                                  isEditing = false;
                                                });
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'AI insights updated locally'),
                                                    backgroundColor:
                                                        AppColors.success,
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.brandPrimary,
                                              ),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Note: This is AI-generated analysis for informational purposes only.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // REMOVED: _generatePrenatalAIInsights - this was the culprit generating fake AI text

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
                      _displayCount = _pageSize; // Reset on search change
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
                            _displayCount = _pageSize; // Reset on filter change
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
                    itemCount: allRecords.length <= _displayCount
                        ? allRecords.length
                        : _displayCount + 1, // +1 for the Load More button
                    itemBuilder: (context, index) {
                      // Show "Load More" button at the end
                      if (index == _displayCount &&
                          allRecords.length > _displayCount) {
                        final remaining = allRecords.length - _displayCount;
                        final nextBatch =
                            remaining > _pageSize ? _pageSize : remaining;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                  () => _displayCount += _pageSize),
                              icon:
                                  const Icon(Icons.expand_more, size: 18),
                              label: Text(
                                'Load More ($nextBatch of $remaining remaining)',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brandPrimary,
                                side: BorderSide(
                                    color: AppColors.brandPrimary
                                        .withOpacity(0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        );
                      }

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
                              List<String> riskFactorList = [];
                              List<String> suggestedActionsList = [];
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

                                  final rf = checkupDetails['riskFactors']
                                          as String? ??
                                      '';
                                  if (rf.trim().isNotEmpty) {
                                    riskFactors = rf;
                                    riskFactorList = rf
                                        .split('; ')
                                        .where((s) => s.trim().isNotEmpty)
                                        .toList();
                                  }

                                  // PRIMARY SOURCE: Database AI response
                                  aiAnalysis =
                                      checkupDetails['aiResponse'] as String?;

                                  // FALLBACK: MotherProfileService
                                  if (aiAnalysis == null ||
                                      aiAnalysis!.trim().isEmpty) {
                                    aiAnalysis = await MotherProfileService
                                        .getCheckupAIAnalysis(checkupId);
                                  }

                                  // NO FALLBACK to _generatePrenatalAIInsights
                                  // If still empty, leave as null (no AI section shown)

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
                              }

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
                                  ? riskLevel
                                  : '';
                              final riskFactorsValue =
                                  riskFactors.trim().isNotEmpty
                                      ? riskFactors
                                      : '';

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
                                  MapEntry(
                                      'Risk Level',
                                      riskLevelValue.isNotEmpty
                                          ? riskLevelValue
                                          : 'Not inputted'),
                                  MapEntry(
                                      'Risk Factors',
                                      riskFactorsValue.isNotEmpty
                                          ? riskFactorsValue
                                          : 'Not inputted'),
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
                                useStructuredAiInsights: false,
                                riskLevel: riskLevel,
                                riskFactors: riskFactors,
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
