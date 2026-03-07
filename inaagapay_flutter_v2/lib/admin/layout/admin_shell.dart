import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../admin_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHELL  (ties Header + Sidebar + Content + Footer together)
// ─────────────────────────────────────────────────────────────────────────────
class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      drawer: isWide ? null : _buildDrawer(context),
      body: Row(
        children: [
          // ── Sidebar (desktop only) ──────────────────────────────────────
          if (isWide)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: SizedBox(
                width: _sidebarCollapsed ? 72 : 260,
                child: AdminSidebar(collapsed: _sidebarCollapsed),
              ),
            ),

          // ── Main area ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                AdminHeader(
                  onMenuTap: isWide
                      ? () => setState(
                          () => _sidebarCollapsed = !_sidebarCollapsed,
                        )
                      : () => Scaffold.of(context).openDrawer(),
                ),
                Expanded(
                  child: Container(color: AppTheme.bg, child: widget.child),
                ),
                const AdminFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AdminSidebar(collapsed: false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class AdminSidebar extends StatelessWidget {
  final bool collapsed;
  const AdminSidebar({super.key, required this.collapsed});

  static const _navItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      route: '/admin/dashboard',
    ),
    _NavItem(
      label: 'Account Management',
      icon: Icons.manage_accounts_rounded,
      route: '/admin/accounts',
    ),
    _NavItem(
      label: 'Account Creation',
      icon: Icons.person_add_rounded,
      route: '/admin/accounts/create',
    ),
    _NavItem(
      label: 'Midwife Assignment',
      icon: Icons.assignment_ind_rounded,
      route: '/admin/midwife-assignment',
    ),
    _NavItem(
      label: 'Audit Trail',
      icon: Icons.history_rounded,
      route: '/admin/audit-trail',
    ),
    _NavItem(
      label: 'Backup / Restore',
      icon: Icons.backup_rounded,
      route: '/admin/backup-restore',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.sidebarGradient),
      child: Column(
        children: [
          // ── Logo area ─────────────────────────────────────────────────
          _buildLogo(context),

          const SizedBox(height: 8),
          Divider(color: Colors.white.withAlpha(50), height: 1),
          const SizedBox(height: 8),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (ctx, i) {
                final item = _navItems[i];
                final isActive =
                    loc.startsWith(item.route) &&
                    (item.route != '/admin/accounts' ||
                        loc == '/admin/accounts');
                return _buildNavTile(context, item, isActive);
              },
            ),
          ),

          Divider(color: Colors.white.withAlpha(50), height: 1),
          const SizedBox(height: 8),

          // ── Logout ────────────────────────────────────────────────────
          _buildLogout(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Image.network(
              'images/logo_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.health_and_safety,
                color: AppTheme.primaryPink,
                size: 28,
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'InaAgapay',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, _NavItem item, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 14 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withAlpha(35) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: Colors.white.withAlpha(60), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isActive ? Colors.white : Colors.white.withAlpha(180),
                  size: 20,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withAlpha(180),
                        fontSize: 13.5,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _confirmLogout(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.white.withAlpha(200),
                  size: 20,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AdminSession.clear();
              context.go('/admin/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class AdminHeader extends StatelessWidget {
  final VoidCallback onMenuTap;
  const AdminHeader({super.key, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Hamburger ─────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textSecondary),
            onPressed: onMenuTap,
            tooltip: 'Toggle sidebar',
          ),

          const Spacer(),

          // ── Notification bell ──────────────────────────────────────────
          _buildBell(),
          const SizedBox(width: 8),

          // ── User chip ─────────────────────────────────────────────────
          _buildUserChip(context),
        ],
      ),
    );
  }

  Widget _buildBell() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppTheme.textSecondary,
          ),
          onPressed: () {},
          tooltip: 'Notifications',
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.primaryPink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.softPink,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppTheme.primaryPink,
            child: Text(
              AdminSession.displayName.isNotEmpty
                  ? AdminSession.displayName[0].toUpperCase()
                  : 'A',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AdminSession.displayName,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Administrator',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class AdminFooter extends StatelessWidget {
  const AdminFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withAlpha(120)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2025 InaAgapay – Maternal & Child Health Information System',
            style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 11),
          ),
          Text(
            'Admin Portal v1.0',
            style: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM DATA
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}
