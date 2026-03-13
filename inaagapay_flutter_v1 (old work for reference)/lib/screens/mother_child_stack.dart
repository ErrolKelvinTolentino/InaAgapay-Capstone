import 'package:flutter/material.dart';

import 'mother_view_child.dart';
import 'mother_child_growth.dart';
import 'mother_child_vaccine.dart';

class MotherChildStack extends StatefulWidget {
  final int childId;
  final String childName;
  final String childAge;

  const MotherChildStack({
    super.key,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<MotherChildStack> createState() => _MotherChildStackState();
}

class _MotherChildStackState extends State<MotherChildStack> {
  int _currentIndex = 0;

  void _goTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _goBackToOverview() {
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        // 🟢 OVERVIEW
// 🟢 OVERVIEW
MotherViewChildPage(
  childId: widget.childId,
  onBackToChildren: () => Navigator.pop(context),
  onViewGrowth: () => _goTo(1),
  onViewVaccines: () => _goTo(2),
),

        // 🟡 GROWTH
        MotherChildGrowthPage(
          onBack: _goBackToOverview,
          childId: widget.childId,
          childName: widget.childName,
          childAge: widget.childAge,
        ),

        // 🔵 VACCINES
        MotherChildVaccinePage(
          onBack: _goBackToOverview,
          childId: widget.childId,
          childName: widget.childName,
          childAge: widget.childAge,
        ),
      ],
    );
  }
}
