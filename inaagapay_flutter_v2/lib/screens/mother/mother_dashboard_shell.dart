// lib/screens/mother/mother_dashboard_shell.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';
import 'mother_dashboard.dart';
import 'mother_journal_screen.dart';
import 'mother_children_screen.dart';
import 'records_screen.dart';
import 'mother_profile_page.dart';

class MotherDashboardShell extends StatefulWidget {
  const MotherDashboardShell({super.key});

  @override
  State<MotherDashboardShell> createState() => _MotherDashboardShellState();
}

class _MotherDashboardShellState extends State<MotherDashboardShell> {
  int _currentIndex = 0;
  String? _profilePictureUrl;
  int? _motherId;
  final ImagePicker _picker = ImagePicker();
  
  bool _showBHCRequiredDialog = false;

  final List<Widget> _screens = const [
    MotherDashboard(),
    MotherJournalScreen(),
    MotherChildrenScreen(),
    RecordsScreen(),
  ];

  final List<String> _titles = [
    'HOME',
    'JOURNAL',
    'CHILDREN',
    'RECORDS',
  ];

  @override
  void initState() {
    super.initState();
    _loadMotherData();
  }

  Future<void> _loadMotherData() async {
    _motherId = await AuthStorage.getMotherId();
    if (_motherId != null) {
      final url = await SupabaseService.getProfilePictureUrl(_motherId!);
      if (mounted) {
        setState(() {
          _profilePictureUrl = url;
        });
      }
    } else {
      _checkAndShowBHCRequiredDialog();
    }
  }

  Future<void> _checkAndShowBHCRequiredDialog() async {
    if (_showBHCRequiredDialog) return;
    
    final accountId = await AuthStorage.getUserId();
    if (accountId == null) return;
    
    try {
      final motherResponse = await SupabaseService.client
          .from('mothers')
          .select('mother_id, assigned_bhc_id')
          .eq('account_id', accountId)
          .maybeSingle();
      
      if (motherResponse == null || motherResponse['assigned_bhc_id'] == null) {
        _showBHCRequiredDialog = true;
        if (mounted) {
          await _showBHCRequiredMessage();
        }
      } else {
        final motherId = motherResponse['mother_id'] as int;
        await AuthStorage.saveMotherId(motherId);
        setState(() {
          _motherId = motherId;
        });
      }
    } catch (e) {
      debugPrint('Error checking mother record: $e');
    }
  }

  Future<void> _showBHCRequiredMessage() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Account Setup Incomplete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been created but needs to be linked to a Barangay Health Center (BHC) before you can fully access the system.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      size: 20,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please visit your Barangay Health Center (BHC) and ask a midwife to complete your account registration.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.brandPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _logout();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: const BorderSide(color: AppColors.borderPrimary),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthStorage.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _loadProfilePicture() async {
    if (_motherId != null) {
      final url = await SupabaseService.getProfilePictureUrl(_motherId!);
      if (mounted) {
        setState(() {
          _profilePictureUrl = url;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_motherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your account setup with a midwife first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null && _motherId != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final bytes = await image.readAsBytes();
        final url = await SupabaseService.uploadProfilePicture(_motherId!, bytes);

        if (mounted) {
          Navigator.pop(context);
          
          if (url != null) {
            setState(() {
              _profilePictureUrl = url;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showProfileMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          GestureDetector(
            onTap: () => entry.remove(),
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          Positioned(
            top: 80,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,  // ← FIXED: Increased width slightly
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,  // ← FIXED: Use min size
                  children: [
                    _MenuItem(
                      icon: Icons.photo_camera_outlined,
                      label: 'Change Photo',
                      onTap: () {
                        entry.remove();
                        _showImageSourceDialog(context);
                      },
                    ),
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'View Profile',
                      onTap: () {
                        entry.remove();
                        if (_motherId != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MotherProfilePage(motherId: _motherId!),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please complete your account setup with a midwife first.'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      },
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _MenuItem(
                      icon: Icons.help_outline,
                      label: 'Help',
                      onTap: () {
                        entry.remove();
                        Navigator.pushNamed(context, '/help');
                      },
                    ),
                    const Divider(height: 1, thickness: 1),  // ← FIXED: Thinner divider
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      isDanger: true,
                      onTap: () {
                        entry.remove();
                        _confirmLogout(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Source'),
        content: const Text('Select where to get your photo from:'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Gallery'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Camera'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 36,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.favorite, color: AppColors.brandPrimary, size: 30),
                    ),
                  ),
                  Text(
                    _titles[_currentIndex],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandText,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPrimary,
                        image: _profilePictureUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_profilePictureUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilePictureUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              isActive: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book,
              label: 'Journal',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavItem(
              icon: Icons.child_care_outlined,
              activeIcon: Icons.child_care,
              label: 'Children',
              isActive: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavItem(
              icon: Icons.folder_outlined,
              activeIcon: Icons.folder,
              label: 'Records',
              isActive: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.brandPrimary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 26,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(  // ← FIXED: Added Expanded to prevent overflow
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}