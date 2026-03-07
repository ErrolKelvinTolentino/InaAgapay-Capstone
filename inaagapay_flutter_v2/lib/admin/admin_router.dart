import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_session.dart';
import 'layout/admin_shell.dart';
import 'login/admin_login_page.dart';
import 'pages/account_creation_page.dart';
import 'pages/account_management_page.dart';
import 'pages/audit_trail_page.dart';
import 'pages/backup_restore_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/midwife_assignment_page.dart';

final GoRouter adminRouter = GoRouter(
  initialLocation: '/admin/login',
  redirect: (BuildContext context, GoRouterState state) {
    final isLoggedIn = AdminSession.isLoggedIn;
    final loc = state.matchedLocation;
    final isLoginRoute = loc == '/admin/login' || loc == '/';

    if (!isLoggedIn && !isLoginRoute) return '/admin/login';
    if (isLoggedIn && isLoginRoute) return '/admin/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/admin/login'),
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/admin/accounts',
          builder: (context, state) => const AccountManagementPage(),
        ),
        GoRoute(
          path: '/admin/accounts/create',
          builder: (context, state) => const AccountCreationPage(),
        ),
        GoRoute(
          path: '/admin/midwife-assignment',
          builder: (context, state) => const MidwifeAssignmentPage(),
        ),
        GoRoute(
          path: '/admin/audit-trail',
          builder: (context, state) => const AuditTrailPage(),
        ),
        GoRoute(
          path: '/admin/backup-restore',
          builder: (context, state) => const BackupRestorePage(),
        ),
      ],
    ),
  ],
);
