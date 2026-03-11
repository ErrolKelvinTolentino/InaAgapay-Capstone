// lib/screens/midwife/midwife_mothers_screen.dart
import 'package:flutter/material.dart';
// Change these:
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import '../../widgets/main_header.dart';
import 'midwife_add_mother_screen.dart';

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
              status
            )
          ''')
          .eq('account_type', 'mother')
          .eq('is_verified', true)
          .order('first_name', ascending: true);

      final list = List<Map<String, dynamic>>.from(data);
      setState(() {
        _mothers = list;
        _filtered = list;
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
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _mothers.where((m) {
        final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.toLowerCase();
        final phone = (m['phone_number'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          MainHeader(
            title: 'Mothers',
            onViewProfile: () => Navigator.pushNamed(context, '/profile'),
            onSettings: () => Navigator.pushNamed(context, '/settings'),
            onHelp: () => Navigator.pushNamed(context, '/help'),
            onLogout: () async {
              await AuthStorage.clearAll();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMothers,
              color: AppColors.brandPrimary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MidwifeAddMotherScreen(),
            ),
          );
          if (added == true) _loadMothers();
        },
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Add Mother',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }

    if (_error != null) {
      return Center(
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
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderPrimary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderPrimary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.brandPrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_filtered.length} mother${_filtered.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _filtered.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MotherCard(mother: _filtered[index]),
                ),
        ),
      ],
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

  const _MotherCard({required this.mother});

  @override
  Widget build(BuildContext context) {
    final firstName = (mother['first_name'] ?? '').toString();
    final lastName = (mother['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final phone = (mother['phone_number'] ?? 'No phone number').toString();

    final motherRecord = mother['mothers'];
    final Map<String, dynamic>? profile =
        motherRecord is Map ? Map<String, dynamic>.from(motherRecord) : null;
    final barangay = (profile?['barangay'] ?? '').toString();
    final city = (profile?['city_municipality'] ?? '').toString();
    final location = [barangay, city].where((s) => s.isNotEmpty).join(', ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          // TODO: navigate to mother detail
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderPrimary),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPrimary.withOpacity(0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(firstName, lastName),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Unnamed' : fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }
}