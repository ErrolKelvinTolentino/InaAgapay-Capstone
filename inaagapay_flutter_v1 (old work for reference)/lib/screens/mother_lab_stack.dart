import 'package:flutter/material.dart';
import 'mother_lab_overview.dart';
import 'mother_lab_details.dart';

class MotherLabStack extends StatefulWidget {
  const MotherLabStack({super.key});

  @override
  State<MotherLabStack> createState() => _MotherLabStackState();
}

class _MotherLabStackState extends State<MotherLabStack> {
  int _index = 0;
  Map<String, dynamic> _selectedLabTest = {};

  void _goToDetails(Map<String, dynamic> labTestData) {
    setState(() {
      _selectedLabTest = labTestData;
      _index = 1;
    });
  }

  void _goBack() {
    setState(() {
      _selectedLabTest = {};
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _index,
      children: [
        MotherLabOverview(
          onViewDetails: _goToDetails,
        ),
        MotherLabDetails(
          onBack: _goBack,
          labTestData: _selectedLabTest,
        ),
      ],
    );
  }
}