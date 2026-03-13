import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../widgets/main_header.dart';
import '../widgets/midwife_bottom_navigation.dart'; // Remove if not exists
import '../widgets/small_description.dart';
import '../widgets/app_input_field.dart';
import '../widgets/child_card.dart';
import '../widgets/vaccine_schedule_status.dart';
import '../widgets/floating_add_child_button.dart';
import 'child_profile_page.dart';
import 'add_child_step1.dart';

class MidwifeChildrenPage extends StatefulWidget {
  const MidwifeChildrenPage({super.key});

  @override
  State<MidwifeChildrenPage> createState() => _MidwifeChildrenPageState();
}

class _MidwifeChildrenPageState extends State<MidwifeChildrenPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allChildren = [];
  List<Map<String, dynamic>> _filteredChildren = [];
  bool _isLoading = true;
  String _bhcFilter = 'All BHCs';
  String? _assignedBhcName;
  bool _bhcLoading = true;

  // Added: Sorting functionality
  String _sortBy = 'recent'; // 'recent' or 'name'

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
    _loadContextAndChildren();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _loadContextAndChildren() async {
    await _loadContext();
    await _loadChildren();
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
      // ignore context errors
    } finally {
      _safeSetState(() => _bhcLoading = false);
    }
  }

  /// ================= FETCH CHILDREN =================
  Future<void> _loadChildren() async {
    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthStorage.getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse(
          'https://inaagapay.alwaysdata.net/api/midwife/midwife_children.php',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final decoded = jsonDecode(res.body);
      final data = decoded['data'] is List ? decoded['data'] : [];

      if (decoded['success'] == true) {
        _allChildren = List<Map<String, dynamic>>.from(data);
        _applyFilterAndSort();
      } else {
        _allChildren = [];
        _filteredChildren = [];
      }
    } catch (_) {
      _allChildren = [];
      _filteredChildren = [];
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// ================= AGE CALCULATOR =================
  String calculateAge(String? birthdate) {
    if (birthdate == null) return '-';

    final birth = DateTime.tryParse(birthdate);
    if (birth == null) return '-';

    final now = DateTime.now();

    int years = now.year - birth.year;
    int months = now.month - birth.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years <= 0) {
      return '$months months';
    } else {
      return '$years yrs${months > 0 ? ' $months mos' : ''}';
    }
  }

  /// ================= SEARCH FILTER =================
  void _filterChildren(String query) {
    _applyFilterAndSort(query: query);
  }

  /// ================= APPLY FILTER AND SORT =================
  void _applyFilterAndSort({String? query}) {
    final searchQuery = query ?? _searchController.text;
    final selectedBhc = _normalizeBhc(_bhcFilter);

    _safeSetState(() {
      final searchLower = searchQuery.toLowerCase();
      _filteredChildren = _allChildren.where((child) {
        final name =
            '${child['first_name'] ?? ''} ${child['middle_name'] ?? ''} ${child['last_name'] ?? ''}'
                .toLowerCase();
        final motherName = (child['mother_name'] ?? '')
            .toString()
            .toLowerCase();
        final bhc = _normalizeBhc(
          child['assigned_bhc_name'] ?? // mother's assigned BHC
              child['bhc_name'] ??
              child['barangay'] ??
              child['assigned_bhc'] ??
              '',
        );
        final matchesBhc = _bhcFilter == 'All BHCs'
            ? true
            : (_bhcFilter == 'No Assigned BHC'
                  ? bhc.isEmpty
                  : bhc == selectedBhc);

        if (!matchesBhc) return false;
        if (searchLower.isEmpty) return true;

        return name.contains(searchLower) || motherName.contains(searchLower);
      }).toList();

      // Apply sorting
      if (_sortBy == 'name') {
        _filteredChildren.sort((a, b) {
          final nameA =
              '${(a['last_name'] ?? '').toString()}${(a['first_name'] ?? '').toString()}';
          final nameB =
              '${(b['last_name'] ?? '').toString()}${(b['first_name'] ?? '').toString()}';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
      } else {
        // Sort by recent (created_at or added_at)
        _filteredChildren.sort((a, b) {
          DateTime? parseDate(dynamic value) {
            if (value == null) return null;
            return DateTime.tryParse(value.toString());
          }

          final dateA = parseDate(a['created_at'] ?? a['added_at']);
          final dateB = parseDate(b['created_at'] ?? b['added_at']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA); // Descending order (most recent first)
        });
      }
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

  /// ================= CHANGE SORTING =================
  void _changeSort(String newSort) {
    _safeSetState(() {
      _sortBy = newSort;
    });
    _applyFilterAndSort();
  }

  /// ================= VACCINE STATUS =================
  VaccineScheduleStatus _getVaccineStatus(Map<String, dynamic> child) {
    // This should be replaced with actual vaccine status logic from your database
    // For now, we'll use a simple placeholder logic
    final childId = child['child_id'].toString();
    final lastDigit = int.tryParse(childId.substring(childId.length - 1)) ?? 0;

    if (lastDigit % 3 == 0) {
      return VaccineScheduleStatus.overdue;
    } else if (lastDigit % 3 == 1) {
      return VaccineScheduleStatus.onSchedule;
    } else {
      // Return a default status
      return VaccineScheduleStatus.onSchedule;
    }
  }

  /// ================= NAVIGATION TO CHILD PROFILE =================
  void _openChildProfile(Map<String, dynamic> child) {
    final id = int.tryParse(child['child_id']?.toString() ?? '');
    if (id != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChildProfilePage(childId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      // 🔝 Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(title: 'CHILDREN'),
      ),

      // 🔽 Body
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadContextAndChildren,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🧸 TOP INFO CARD
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        // 📝 Text
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
                                  text: '${_filteredChildren.length} Children!',
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
                        // 👶 Image
                        Image.asset(
                          'assets/images/baby.png',
                          height: 72,
                          width: 72,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🔍 Search and Sort Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Column(
                    children: [
                      // Search Field
                      AppInputField(
                        hintText: 'Search Child',
                        controller: _searchController,
                        trailingIcon: Icons.search,
                        onTrailingTap: () {},
                        onChanged: _filterChildren,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _bhcFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by BHC',
                        ),
                        isExpanded: true,
                        items: _bhcDropdownItems(),
                        onChanged: _bhcLoading
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  _bhcFilter = v;
                                });
                                _applyFilterAndSort();
                              },
                      ),
                      const SizedBox(height: 12),

                      // Sort Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textSecondary,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'recent',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Sort: Most Recent',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'name',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Sort: Name A-Z',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _changeSort(value);
                              }
                            },
                          ),
                        ),
                      ),

                      // Count Text
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing ${_filteredChildren.length} of ${_allChildren.length} children',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                const SmallDescription(
                  text: 'Tap a child to view health records',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 👶 CHILD LIST
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredChildren.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'No children match your search'
                            : 'No children found',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: _filteredChildren.map((child) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ChildCard(
                          fullName:
                              '${child['first_name']} ${child['last_name']}',
                          ageText: calculateAge(child['birthdate']),
                          vaccineStatus: _getVaccineStatus(child),
                          image: const AssetImage('assets/images/child.png'),
                          onTap: () => _openChildProfile(child),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingAddChildButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddChildStep1Parent()),
          );
        },
      ),

      // 🔻 Bottom Nav - COMMENT OUT OR REPLACE
      // bottomNavigationBar: const MidwifeBottomNavigation(
      //   currentIndex: 2, // ✅ Children tab active
      // ),
    );
  }
}
