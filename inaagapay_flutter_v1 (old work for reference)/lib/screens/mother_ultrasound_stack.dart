import 'package:flutter/material.dart';
import 'mother_ultrasound_overview.dart';
import 'mother_ultrasound_details.dart';

class MotherUltrasoundStack extends StatefulWidget {
  const MotherUltrasoundStack({super.key});

  @override
  State<MotherUltrasoundStack> createState() =>
      _MotherUltrasoundStackState();
}

class _MotherUltrasoundStackState extends State<MotherUltrasoundStack> {
  int _index = 0;
  Map<String, dynamic> _selectedUltrasound = {};

  void _goToDetails(Map<String, dynamic> ultrasoundData) {
    setState(() {
      _selectedUltrasound = ultrasoundData;
      _index = 1;
    });
  }

  void _goBack() {
    setState(() {
      _selectedUltrasound = {};
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _index,
      children: [
        MotherUltrasoundOverview(
          onViewDetails: _goToDetails,
        ),
        MotherUltrasoundDetailsPage(
          onBack: _goBack,
          ultrasoundData: _selectedUltrasound,
        ),
      ],
    );
  }
}