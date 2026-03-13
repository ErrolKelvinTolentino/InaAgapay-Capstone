import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/main_header.dart';
import '../widgets/small_description.dart';
import '../widgets/app_input_field.dart';
import '../widgets/floating_add_child_button.dart';
import 'mother_profile_page.dart';
import 'add_mother_flow.dart';

class MidwifeMothersPage extends StatefulWidget {
  const MidwifeMothersPage({super.key});

  @override
  State<MidwifeMothersPage> createState() => _MidwifeMothersPageState();
}

class _MidwifeMothersPageState extends State<MidwifeMothersPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _riskFilter = 'all';
  String _sort = 'name';
  String _bhcFilter = 'All BHCs';
  String? _assignedBhcName;
  bool _bhcLoading = true;
  List<Map<String, dynamic>> _allMothers = [];
  List<Map<String, dynamic>> _filteredMothers = [];
  bool _isDataEnhanced = false;

  static const List<String> _bhcOptions = [
    'San Jose',
    'Tarcan',
    'Sta. Barbara',
    'Tiaong',
    'Pinagbarilan',
    'No Assigned BHC',
  ];

  @override
  void initState() {
    super.initState();
    _future = _loadContextAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _reload() async {
    _safeSetState(() {
      _bhcLoading = true;
      _isDataEnhanced = false;
      _allMothers = [];
      _filteredMothers = [];
    });

    final future = _loadContextAndData();
    _safeSetState(() {
      _future = future;
    });
    await future;
  }

  Future<List<Map<String, dynamic>>> _loadContextAndData() async {
    await _loadContext();
    return fetchMothers();
  }

  Future<void> _loadContext() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('https://inaagapay.alwaysdata.net/api/midwife/context.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final decoded = jsonDecode(res.body);
      if (decoded['success'] == true) {
        final bhcName = decoded['bhc_name']?.toString();
        _safeSetState(() {
          _assignedBhcName = bhcName;
          _bhcFilter = bhcName ?? 'All BHCs';
        });
      }
    } catch (_) {
      // ignore context errors; fallback to all
    } finally {
      _safeSetState(() => _bhcLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMothers() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final res = await http.get(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/midwife_mothers.php',
      ),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    final decoded = jsonDecode(res.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Failed to load mothers');
    }

    final List list = decoded['data'] ?? [];
    _allMothers = list.cast<Map<String, dynamic>>();

    for (final mother in _allMothers) {
      mother['pregnancy_risk_level'] = (mother['pregnancy_risk_level'] ?? 'low')
          .toString();
    }

    if (!_isDataEnhanced && _allMothers.isNotEmpty) {
      await _enhanceMothersWithRiskData();
    }

    _filteredMothers = _applyFilters(_allMothers);
    return _allMothers;
  }

  Future<void> _enhanceMothersWithRiskData() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;

    try {
      final batchRes = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/mothers_batch_risk.php',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (batchRes.statusCode == 200) {
        final batchData = jsonDecode(batchRes.body);
        if (batchData['success'] == true && batchData['mothers'] != null) {
          final batchMothers = Map.fromIterable(
            (batchData['mothers'] as List).cast<Map<String, dynamic>>(),
            key: (m) => m['mother_id'].toString(),
            value: (m) => m,
          );

          for (var mother in _allMothers) {
            final motherId = mother['mother_id'].toString();
            final batchMother = batchMothers[motherId];
            if (batchMother != null) {
              mother['pregnancy_risk_level'] =
                  (batchMother['pregnancy_risk_level'] ?? 'low').toString();
              mother['pregnancy_risk'] = batchMother['pregnancy_risk'];
            }
          }

          _safeSetState(() {
            _isDataEnhanced = true;
            _filteredMothers = _applyFilters(_allMothers);
          });
          return;
        }
      }
    } catch (_) {
      // fall back to per-mother requests
    }

    const maxConcurrentRequests = 3;
    for (var i = 0; i < _allMothers.length; i += maxConcurrentRequests) {
      final end = (i + maxConcurrentRequests < _allMothers.length)
          ? i + maxConcurrentRequests
          : _allMothers.length;
      final batch = _allMothers.sublist(i, end);

      await Future.wait(
        batch.map((mother) async {
          final motherId = mother['mother_id'];
          try {
            final profileRes = await http
                .get(
                  Uri.parse(
                    'https://inaagapay.alwaysdata.net/api/midwife/mother_profile.php?mother_id=$motherId',
                  ),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                )
                .timeout(const Duration(seconds: 10));

            if (profileRes.statusCode == 200) {
              final profileData = jsonDecode(profileRes.body);
              if (profileData['success'] == true &&
                  profileData['mother'] != null) {
                mother['pregnancy_risk_level'] =
                    (profileData['mother']['pregnancy_risk_level'] ??
                            mother['pregnancy_risk_level'] ??
                            'low')
                        .toString();

                if (profileData['mother']['pregnancy_risk'] != null) {
                  mother['pregnancy_risk'] =
                      profileData['mother']['pregnancy_risk'];
                }
              }
            }
          } catch (e) {
            print('Error fetching risk for mother $motherId: $e');
            mother['pregnancy_risk_level'] =
                (mother['pregnancy_risk_level'] ?? 'low').toString();
          }
        }),
      );

      _safeSetState(() {
        _filteredMothers = _applyFilters(_allMothers);
      });

      if (end < _allMothers.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _safeSetState(() {
      _isDataEnhanced = true;
      _filteredMothers = _applyFilters(_allMothers);
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> list) {
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> filtered = list.where((m) {
      final motherBhc = _normalizeBhc(
        m['barangay'] ?? m['bhc_name'] ?? m['assigned_bhc'] ?? '',
      );
      final selectedBhc = _normalizeBhc(_bhcFilter);

      final matchesBhc = _bhcFilter == 'All BHCs'
          ? true
          : (_bhcFilter == 'No Assigned BHC'
                ? motherBhc.isEmpty
                : motherBhc == selectedBhc);

      final matchesSearch = query.isEmpty
          ? true
          : ([
              m['first_name'],
              m['middle_name'],
              m['last_name'],
              m['extension_name'],
              m['barangay'],
              m['city_municipality'],
            ].whereType<String>().any((v) => v.toLowerCase().contains(query)));

      final matchesRisk = _riskFilter == 'all'
          ? true
          : ((m['pregnancy_risk_level']?.toString().toLowerCase() ?? 'low') ==
                _riskFilter);

      return matchesSearch && matchesRisk && matchesBhc;
    }).toList();

    int levelRank(String? level) {
      switch ((level ?? '').toLowerCase()) {
        case 'high':
          return 2;
        case 'medium':
          return 1;
        default:
          return 0;
      }
    }

    filtered.sort((a, b) {
      switch (_sort) {
        case 'risk':
          return levelRank(
            b['pregnancy_risk_level'],
          ).compareTo(levelRank(a['pregnancy_risk_level']));
        case 'edd':
          final eddA = DateTime.tryParse(
            (a['expected_date_of_delivery'] ?? '').toString(),
          );
          final eddB = DateTime.tryParse(
            (b['expected_date_of_delivery'] ?? '').toString(),
          );
          if (eddA == null && eddB == null) return 0;
          if (eddA == null) return 1;
          if (eddB == null) return -1;
          return eddA.compareTo(eddB);
        case 'name':
        default:
          final nameA = [
            a['last_name'] ?? '',
            a['first_name'] ?? '',
          ].join(' ').toLowerCase();
          final nameB = [
            b['last_name'] ?? '',
            b['first_name'] ?? '',
          ].join(' ').toLowerCase();
          return nameA.compareTo(nameB);
      }
    });

    return filtered;
  }

  String calculatePregnancyWeeks(String? lastMenstrualDate) {
    if (lastMenstrualDate == null || lastMenstrualDate.isEmpty) {
      return 'No LMP recorded';
    }

    try {
      final lmp = DateTime.parse(lastMenstrualDate.split(' ')[0]);
      final now = DateTime.now();

      if (lmp.isAfter(now)) {
        return 'Invalid LMP date';
      }

      final difference = now.difference(lmp);
      final weeks = (difference.inDays / 7).floor();

      if (weeks < 0) return '0 weeks';
      if (weeks >= 42) return 'Post-term (42+ weeks)';
      if (weeks >= 40) return 'Full term (40+ weeks)';
      if (weeks >= 37) return 'Late term ($weeks weeks)';

      return '$weeks weeks';
    } catch (e) {
      return 'Invalid date format';
    }
  }

  Color _getRiskColor(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  void _applyFiltersAndSort() {
    _safeSetState(() {
      _filteredMothers = _applyFilters(_allMothers);
    });
  }

  List<DropdownMenuItem<String>> _bhcDropdownItems() {
    final opts = <String>{'All BHCs', ..._bhcOptions};
    if (_assignedBhcName != null && _assignedBhcName!.isNotEmpty) {
      opts.add(_assignedBhcName!);
    }
    return opts
        .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
        .toList();
  }

  String _normalizeBhc(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  void _openMotherProfile(Map<String, dynamic> mother) async {
    final motherId = int.tryParse(mother['mother_id']?.toString() ?? '') ?? 0;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MotherProfilePage(motherId: motherId)),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(title: 'MOTHERS'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (snapshot.hasError) {
                return _buildErrorScreen(snapshot.error.toString());
              }

              return _buildContent();
            },
          ),
        ),
      ),
      floatingActionButton: FloatingAddChildButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMotherFlow()),
          );
          if (added == true) _reload();
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final showingRiskProgress = _allMothers.isNotEmpty && !_isDataEnhanced;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            showingRiskProgress ? 'Loading risk data...' : 'Loading mothers...',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (showingRiskProgress) ...[
            const SizedBox(height: 8),
            const Text(
              'This may take a moment...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reload, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: const DecorationImage(
                image: AssetImage('assets/images/pinkbg.png'),
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'There are\n',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          TextSpan(
                            text: '${_filteredMothers.length} Mothers!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/pregnant1.png',
                    height: 72,
                    width: 72,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          AppInputField(
            hintText: 'Search Mother',
            controller: _searchController,
            trailingIcon: Icons.search,
            onTrailingTap: () {},
            onChanged: (_) => _applyFiltersAndSort(),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _bhcFilter,
            decoration: const InputDecoration(labelText: 'Filter by BHC'),
            isExpanded: true,
            items: _bhcDropdownItems(),
            onChanged: _bhcLoading
                ? null
                : (v) {
                    if (v == null) return;
                    _safeSetState(() {
                      _bhcFilter = v;
                      _applyFiltersAndSort();
                    });
                  },
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _riskFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All risks')),
                    DropdownMenuItem(value: 'low', child: Text('Low risk')),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium risk'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('High risk')),
                  ],
                  onChanged: (v) {
                    _safeSetState(() {
                      _riskFilter = v ?? 'all';
                      _applyFiltersAndSort();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _sort,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                    DropdownMenuItem(value: 'risk', child: Text('Sort: Risk')),
                    DropdownMenuItem(value: 'edd', child: Text('Sort: EDD')),
                  ],
                  onChanged: (v) {
                    _safeSetState(() {
                      _sort = v ?? 'name';
                      _applyFiltersAndSort();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!_isDataEnhanced && _allMothers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Risk levels updating...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SmallDescription(
            text: 'Tap a mother to view health records',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (_filteredMothers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  _searchController.text.isNotEmpty || _riskFilter != 'all'
                      ? 'No mothers match your search'
                      : 'No mothers found',
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            )
          else
            Column(
              children: _filteredMothers.map((mother) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MotherCard(
                    mother: mother,
                    onTap: () => _openMotherProfile(mother),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class MotherCard extends StatelessWidget {
  final Map<String, dynamic> mother;
  final VoidCallback onTap;

  const MotherCard({super.key, required this.mother, required this.onTap});

  String getFullName() {
    return [
      mother['first_name'],
      mother['middle_name'],
      mother['last_name'],
      mother['extension_name'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
  }

  String getPregnancyText() {
    final weeks = calculatePregnancyWeeks(mother['last_menstrual_period']);
    final edd = mother['expected_date_of_delivery']?.toString();
    if (edd != null && edd.isNotEmpty) {
      try {
        final eddDate = DateTime.parse(edd.split(' ')[0]);
        final formattedEdd =
            "${eddDate.year}-${eddDate.month.toString().padLeft(2, '0')}-${eddDate.day.toString().padLeft(2, '0')}";
        return '$weeks • EDD: $formattedEdd';
      } catch (e) {
        return '$weeks • EDD: $edd';
      }
    }
    return weeks;
  }

  String calculatePregnancyWeeks(String? lastMenstrualDate) {
    if (lastMenstrualDate == null || lastMenstrualDate.isEmpty) {
      return 'No Pregnancy recorded';
    }

    try {
      final lmp = DateTime.parse(lastMenstrualDate.split(' ')[0]);
      final now = DateTime.now();

      if (lmp.isAfter(now)) {
        return 'Invalid LMP date';
      }

      final difference = now.difference(lmp);
      final weeks = (difference.inDays / 7).floor();

      if (weeks < 0) return '0 weeks';
      if (weeks >= 42) return 'Post-term (42+ weeks)';
      if (weeks >= 40) return 'Full term (40+ weeks)';
      if (weeks >= 37) return 'Late term ($weeks weeks)';

      return '$weeks weeks';
    } catch (e) {
      return 'Invalid date format';
    }
  }

  Color _getRiskColor(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = mother['pregnancy_risk_level']?.toString() ?? 'low';
    final riskColor = _getRiskColor(riskLevel);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: riskColor,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getFullName(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getPregnancyText(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: riskColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${riskLevel.toUpperCase()} RISK',
                      style: TextStyle(
                        fontSize: 10,
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.brandPrimary),
          ],
        ),
      ),
    );
  }
}
