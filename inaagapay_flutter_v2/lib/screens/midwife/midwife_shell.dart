// lib/screens/midwife_shell.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import 'midwife/midwife_dashboard.dart';
import 'midwife_mothers_screen.dart';
import 'midwife_children_screen.dart';
import 'midwife_schedules_screen.dart';

class MidwifeShell extends StatefulWidget {
  const MidwifeShell({super.key});

  @override
  State<MidwifeShell> createState() => _MidwifeShellState();
}

class _MidwifeShellState extends State<MidwifeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MidwifeDashboard(),
    MidwifeMothersScreen(),
    MidwifeChildrenScreen(),
    MidwifeSchedulesScreen(),
  ];

  final List<String> _titles = const [
    'Home',
    'Mothers',
    'Children',
    'Schedules',
  ];

  final List<IconData> _icons = const [
    Icons.dashboard_rounded,
    Icons.pregnant_woman_rounded,
    Icons.child_care_rounded,
    Icons.calendar_today_rounded,
  ];

  Future<void> _logout() async {
    await AuthStorage.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.brandPrimary,
        unselectedItemColor: AppColors.textSecondary,
        items: List.generate(_titles.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_icons[index]),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}