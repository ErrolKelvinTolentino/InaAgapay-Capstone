// lib/screens/midwife/midwife_mothers_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_input_field.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import 'midwife_add_mother_screen.dart';
import '../mother/mother_profile_page.dart';

class MidwifeMothersScreen extends StatefulWidget {
  const MidwifeMothersScreen({super.key});

  @override
  State<MidwifeMothersScreen> createState() => _MidwifeMothersScreenState();
}

class _MidwifeMothersScreenState extends State<MidwifeMothersScreen> {
  List<Map<String, dynamic>> _mothers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMothers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMothers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final data = await SupabaseService.client
          .from('accounts')
          .select('''
            account_id, 
            first_name, 
            last_name, 
            phone_number, 
            email_address, 
            status,
            mothers!inner(
              mother_id, 
              birthdate, 
              barangay, 
              city_municipality, 
              province, 
              status,
              pregnancies(
                status,
                last_menstrual_period
              )
            )
          ''')
          .eq('account_type', 'mother')
          .eq('is_verified', true)
          .order('first_name', ascending: true);

      final list = List<Map<String, dynamic>>.from(data);
      
      final processedList = list.map((mother) {
        final motherData = mother['mothers'] as Map<String, dynamic>? ?? {};
        final pregnancies = motherData['pregnancies'] as List? ?? [];
        
        final activePregnancies = pregnancies.where((p) => p['status'] == 'active').toList();
        final pregnancyCount = activePregnancies.length;
        final String? lmpString = pregnancyCount > 0 ? activePregnancies.first['last_menstrual_period'] : null;
        
        int? age;
        final birthdateStr = motherData['birthdate']?.toString();
        if (birthdateStr != null && birthdateStr.isNotEmpty) {
          final birthdate = DateTime.tryParse(birthdateStr);
          if (birthdate != null) {
            age = (DateTime.now().difference(birthdate).inDays / 365).floor();
          }
        }
        
        int? gestWeeks;
        if (lmpString != null && lmpString.isNotEmpty) {
          final lmpDate = DateTime.tryParse(lmpString);
          if (lmpDate != null) {
            gestWeeks = (DateTime.now().difference(lmpDate).inDays / 7).floor();
          }
        }
        
        return {
          ...mother,
          'full_name': [
            mother['first_name'],
            mother['last_name']
          ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' '),
          'pregnancy_count': pregnancyCount,
          'age': age,
          'gest_weeks': gestWeeks,
          'mother_id': motherData['mother_id'],
          'barangay': motherData['barangay'],
          'city': motherData['city_municipality'],
        };
      }).toList();

      setState(() {
        _mothers = processedList;
        _filtered = processedList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_mothers);
      } else {
        _filtered = _mothers.where((m) {
          final name = (m['full_name'] ?? '').toString().toLowerCase();
          final phone = (m['phone_number'] ?? '').toString().toLowerCase();
          final email = (m['email_address'] ?? '').toString().toLowerCase();
          final barangay = (m['barangay'] ?? '').toString().toLowerCase();
          
          return name.contains(query) || 
                 phone.contains(query) || 
                 email.contains(query) ||
                 barangay.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // 1. Header Banner
            Container(
              width: double.infinity,
              height: 110,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: AssetImage('assets/images/pinkbg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    top: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0, top: 4.0, bottom: 4.0),
                      child: Image.asset(
                        'assets/images/pregnant1.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'There are',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${_mothers.length} Mothers!', // Count based on actual mothers
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AppInputField(
                hintText: 'Search Mother',
                controller: _searchController,
                trailingIcon: _searchController.text.isNotEmpty ? Icons.clear : Icons.search,
                onTrailingTap: _searchController.text.isNotEmpty 
                    ? () {
                        _searchController.clear();
                        _onSearch();
                      }
                    : null,
              ),
            ),

            // 3. Helper Text
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                'Tap a mother to view health records',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brandPrimary),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                const Text(
                                  'Failed to load mothers',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadMothers,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _MotherCard(mother: _filtered[index], onTap: () {
                                    final motherId = _filtered[index]['mother_id'];
                                    if (motherId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MotherProfilePage(
                                            motherId: motherId,
                                          ),
                                        ),
                                      ).then((_) => _loadMothers());
                                    }
                                  }),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MidwifeAddMotherScreen(),
            ),
          );
          if (added == true) {
            _loadMothers();
          }
        },
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Add Mother',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildEmpty() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching
                ? Icons.search_off_rounded
                : Icons.pregnant_woman_rounded,
            size: 64,
            color: AppColors.brandPrimary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching ? 'No results found' : 'No mothers registered yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSearching
                ? 'Try a different search term'
                : 'Tap + to register the first mother',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MotherCard extends StatelessWidget {
  final Map<String, dynamic> mother;
  final VoidCallback onTap;

  const _MotherCard({required this.mother, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fullName = mother['full_name']?.toString() ?? 'Unnamed';
    final pregnancyCount = mother['pregnancy_count'] as int? ?? 0;
    final age = mother['age'] as int?;
    final gestWeeks = mother['gest_weeks'] as int?;

    String subtitleText = '';
    if (age != null) {
      subtitleText += '$age Years old';
    } else {
      subtitleText += 'Age unknown';
    }

    if (pregnancyCount > 0 && gestWeeks != null) {
      subtitleText += ' - $gestWeeks weeks pregnant';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.brandPrimary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty || fullName == 'Unnamed') return '?';
    
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}