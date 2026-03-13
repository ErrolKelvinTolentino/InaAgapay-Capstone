import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/midwife_bottom_navigation.dart';

import 'midwife_dashboard.dart';
import 'midwife_mothers_page.dart';
import 'midwife_children_page.dart';
import 'midwife_schedules_page.dart';

class MidwifeShell extends StatefulWidget {
  const MidwifeShell({super.key});

  @override
  State<MidwifeShell> createState() => _MidwifeShellState();
}

class _MidwifeShellState extends State<MidwifeShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MidwifeDashboard(),     // 0
    const MidwifeMothersPage(),   // 1 ✅ NOW MATCHES
    const MidwifeChildrenPage(),  // 2
    const MidwifeSchedulesPage(), // 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),

      bottomNavigationBar: MidwifeBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
