import 'package:flutter/material.dart';
import 'mother_prenatal_overview.dart';
import 'mother_growth.dart';
import 'mother_checkup_details.dart';

class MotherPrenatalStack extends StatefulWidget {
  const MotherPrenatalStack({super.key});

  @override
  State<MotherPrenatalStack> createState() => _MotherPrenatalStackState();
}

class _MotherPrenatalStackState extends State<MotherPrenatalStack> {
  int _currentIndex = 0;
  Map<String, dynamic> _selectedCheckup = {};

  void _goToGrowth() {
    setState(() => _currentIndex = 1);
  }

  void _goToCheckupDetails(Map<String, dynamic> checkupData) {
    setState(() {
      _selectedCheckup = checkupData;
      _currentIndex = 2;
    });
  }

  void _goBackToOverview() {
    setState(() {
      _selectedCheckup = {};
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        // 🟢 INDEX 0 — OVERVIEW
        MotherPrenatalOverview(
          onViewGrowth: _goToGrowth,
          onViewCheckupDetails: _goToCheckupDetails,
        ),

        // 🟡 INDEX 1 — GROWTH
        MotherGrowthPage(
          onBack: _goBackToOverview,
        ),

        // 🔵 INDEX 2 — CHECKUP DETAILS
        MotherCheckupDetailsPage(
          onBack: _goBackToOverview,
          checkupData: _selectedCheckup,
        ),
      ],
    );
  }
}