// lib/screens/midwife_shell.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import 'midwife/midwife_dashboard.dart';
import 'midwife/midwife_mother_list.dart';
import 'midwife/midwife_records.dart';
import 'midwife/midwife_calendar.dart';

class MidwifeShell extends StatefulWidget {
  const MidwifeShell({super.key});

  @override
  State<MidwifeShell> createState() => _MidwifeShellState();
}

class _MidwifeShellState extends State<MidwifeShell> {
  int _currentIndex = 0;

  // Remove const from this list
  final List<Widget> _screens = [
    const MidwifeDashboard(),
    const MidwifeMotherList(),
    const MidwifeRecords(),
    const MidwifeCalendar(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Mothers',
    'Records',
    'Calendar',
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
        backgroundColor: AppColors.brandSecondary,
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
        selectedItemColor: AppColors.brandSecondary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Mothers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}