// lib/screens/midwife/midwife_shell.dart

import 'package:flutter/material.dart';
import '../../widgets/midwife_bottom_navigation.dart';
import 'midwife_dashboard.dart';
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const MidwifeDashboard(),
      const MidwifeMothersScreen(),
      const MidwifeChildrenScreen(),
      const MidwifeSchedulesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: MidwifeBottomNavigation(
        currentIndex: _currentIndex,
        onTabSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}