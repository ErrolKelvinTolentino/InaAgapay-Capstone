// lib/screens/growth_tracker_page.dart (Fixed with Dropdown)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/growth_calculator.dart';
import '../services/session_service.dart';
import '../models/growth_data.dart';
import '../models/child.dart';
import '../models/growth_record.dart';

class GrowthTrackerPage extends StatefulWidget {
  const GrowthTrackerPage({super.key});

  @override
  State<GrowthTrackerPage> createState() => _GrowthTrackerPageState();
}

class _GrowthTrackerPageState extends State<GrowthTrackerPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  GrowthAssessment? _weightAssessment;
  GrowthAssessment? _heightAssessment;
  Map<String, dynamic>? _bmiAssessment;
  double? _currentBMI;
  String? _currentBMIClassification;
  Color? _currentBMIColor;
  List<GrowthRecord> _childRecords = [];
  Child? _selectedChild; // Local selected child

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_updateBMI);
    _heightController.addListener(_updateBMI);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load the selected child from session service
    final sessionService = Provider.of<SessionService>(context);
    if (_selectedChild == null && sessionService.selectedChild != null) {
      setState(() {
        _selectedChild = sessionService.selectedChild;
      });
      _loadChildRecords();
    }
  }

  @override
  void dispose() {
    _weightController.removeListener(_updateBMI);
    _heightController.removeListener(_updateBMI);
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateBMI() {
    if (_selectedChild == null) return;

    double? weight = double.tryParse(_weightController.text);
    double? height = double.tryParse(_heightController.text);
    
    if (weight != null && height != null && weight > 0 && height > 0) {
      double heightInMeters = height / 100;
      double bmi = weight / (heightInMeters * heightInMeters);
      
      // Get real-time BMI classification using WHO standards
      double bmiZScore = GrowthCalculator.calculateBMIZScore(
        bmi,
        _selectedChild!.getAgeInWeeks(),
        _selectedChild!.gender
      );
      
      String classification = _getBMIClassificationText(bmiZScore);
      Color color = _getBMIColor(bmiZScore);
      
      if (mounted) {
        setState(() {
          _currentBMI = bmi;
          _currentBMIClassification = classification;
          _currentBMIColor = color;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentBMI = null;
          _currentBMIClassification = null;
          _currentBMIColor = null;
        });
      }
    }
  }

  void _loadChildRecords() {
    if (_selectedChild == null) return;
    
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final records = sessionService.getChildRecords(_selectedChild!.id);
    if (mounted) {
      setState(() {
        _childRecords = records;
      });
    }
  }

  void _onChildSelected(Child? child) {
    setState(() {
      _selectedChild = child;
      _weightController.clear();
      _heightController.clear();
      _clearAssessments();
      _currentBMI = null;
      _currentBMIClassification = null;
      _currentBMIColor = null;
    });
    
    if (child != null) {
      _loadChildRecords();
    } else {
      setState(() {
        _childRecords = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Growth Assessment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _weightController.clear();
                _heightController.clear();
                _clearAssessments();
                _currentBMI = null;
                _currentBMIClassification = null;
                _currentBMIColor = null;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child Selection Dropdown Card
              _buildChildSelectionCard(sessionService.children),
              const SizedBox(height: 20),
              
              // Only show the rest if a child is selected
              if (_selectedChild != null) ...[
                // Selected Child Info Card
                _buildSelectedChildCard(),
                const SizedBox(height: 20),
                
                // Input Section with BMI inside
                _buildInputCard(),
                const SizedBox(height: 20),
                
                // Results Section
                if (_weightAssessment != null || _heightAssessment != null || _bmiAssessment != null) ...[
                  const Text(
                    'Current Assessment Results',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 15),
                  
                  if (_weightAssessment != null) ...[
                    _buildResultCard(_weightAssessment!, 'Weight', Icons.monitor_weight, Colors.green),
                    const SizedBox(height: 15),
                  ],
                  
                  if (_heightAssessment != null) ...[
                    _buildResultCard(_heightAssessment!, 'Height', Icons.height, Colors.orange),
                    const SizedBox(height: 15),
                  ],
                  
                  if (_bmiAssessment != null) ...[
                    _buildBMIResultCard(),
                    const SizedBox(height: 15),
                  ],
                  
                  // Save Record Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveGrowthRecord,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'SAVE GROWTH RECORD',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Growth History Section
                if (_childRecords.isNotEmpty) ...[
                  const Text(
                    'Growth History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 15),
                  _buildGrowthHistory(),
                ],
              ] else ...[
                // No child selected message
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.child_care,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Select a child to begin',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose a child from the dropdown above',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelectionCard(List<Child> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Colors.blue),
                SizedBox(width: 10),
                Text(
                  'Select Child',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            
            if (children.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No children found',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Please add a child in Child Management first',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/child-management');
                      },
                      child: const Text('Add Child'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<Child>(
                  value: _selectedChild,
                  isExpanded: true,
                  hint: const Text('Choose a child'),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: children.map((Child child) {
                    return DropdownMenuItem<Child>(
                      value: child,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: child.gender == 'Girl' ? Colors.pink : Colors.blue,
                            child: Text(
                              child.name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${child.getAgeInWeeks()} weeks',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Child? newValue) {
                    _onChildSelected(newValue);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChildCard() {
    if (_selectedChild == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: _selectedChild!.gender == 'Girl' 
                ? [Colors.pink.shade300, Colors.pink.shade100]
                : [Colors.blue.shade300, Colors.blue.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  _selectedChild!.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _selectedChild!.gender == 'Girl' ? Colors.pink : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChild!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Born: ${DateFormat('MMM dd, yyyy').format(_selectedChild!.birthDate)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Age: ${_selectedChild!.getAgeInWeeks()} weeks • ${_selectedChild!.gender}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    if (_selectedChild == null) return const SizedBox.shrink();
    
    final ageInWeeks = _selectedChild!.getAgeInWeeks();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  'New Measurement - Week $ageInWeeks',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 30),
            
            // Info Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Age and gender are automatically set based on selected child',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Weight Input
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  hintText: 'Enter weight',
                  prefixIcon: const Icon(Icons.monitor_weight, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                onChanged: (value) {
                  _clearAssessments();
                },
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Height Input
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Height/Length (cm)',
                  hintText: 'Enter height',
                  prefixIcon: const Icon(Icons.height, color: Colors.orange),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
                onChanged: (value) {
                  _clearAssessments();
                },
              ),
            ),
            
            const SizedBox(height: 15),
            
            // BMI Display with Classification
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: _currentBMIColor?.withValues(alpha: 0.1) ?? Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _currentBMIColor ?? Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: _currentBMIColor ?? Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'BMI',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currentBMI != null 
                          ? _currentBMI!.toStringAsFixed(2)
                          : '—',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _currentBMI != null ? (_currentBMIColor ?? Colors.purple) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (_currentBMIClassification != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentBMIColor?.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentBMIClassification!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentBMIColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Assess Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _assessAll,
                icon: const Icon(Icons.assessment, size: 24),
                label: const Text(
                  'ASSESS WITH WHO STANDARDS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthHistory() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _childRecords.length,
      itemBuilder: (context, index) {
        final record = _childRecords[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getBMIColor(record.bmiZScore),
              child: Text(
                '${record.ageInWeeks}w',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            title: Text(
              DateFormat('MMM dd, yyyy').format(record.dateRecorded),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Weight: ${record.weight}kg | Height: ${record.height}cm | BMI: ${record.bmi.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHistoryRow('Weight', record.weight, record.weightClassification, record.weightZScore),
                    const Divider(),
                    _buildHistoryRow('Height', record.height, record.heightClassification, record.heightZScore),
                    const Divider(),
                    _buildHistoryRow('BMI', record.bmi, record.bmiClassification, record.bmiZScore),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryRow(String label, double value, String classification, double zScore) {
    Color color = label == 'BMI' ? _getBMIColor(zScore) : _getResultColor(zScore);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label: ${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              classification,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(GrowthAssessment assessment, String parameter, IconData icon, Color color) {
    Color resultColor = _getResultColor(assessment.zScore);
    String classification = _getClassificationText(assessment.zScore);
    String unit = parameter == 'Weight' ? 'kg' : 'cm';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        '$parameter Assessment',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  
                  _buildInfoRow('Measured Value', '${assessment.value.toStringAsFixed(2)} $unit'),
                  _buildInfoRow('Z-Score', assessment.zScore.toStringAsFixed(2)),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Classification',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                classification,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: resultColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: resultColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(assessment.zScore),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBMIResultCard() {
    double bmi = _bmiAssessment!['bmi'];
    double zScore = _bmiAssessment!['zScore'];
    String classification = _bmiAssessment!['classification'];
    Color resultColor = _bmiAssessment!['color'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.purple, width: 0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.purple, width: 8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.purple, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'WHO BMI Assessment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  
                  _buildInfoRow('BMI Value', bmi.toStringAsFixed(2)),
                  _buildInfoRow('Z-Score', zScore.toStringAsFixed(2)),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Classification',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                classification,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: resultColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: resultColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'BMI = weight(kg) / height(m)²',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getResultColor(double zScore) {
    if (zScore < -3) return Colors.red.shade900;
    if (zScore < -2) return Colors.red;
    if (zScore < -1) return Colors.orange;
    if (zScore <= 1) return Colors.green;
    if (zScore <= 2) return Colors.amber.shade700;
    if (zScore <= 3) return Colors.deepOrange;
    return Colors.red.shade900;
  }

  Color _getBMIColor(double zScore) {
    if (zScore < -1) return Colors.orange; // Underweight
    if (zScore <= 1) return Colors.green;   // Normal
    if (zScore <= 2) return Colors.amber.shade700; // Overweight
    if (zScore <= 3) return Colors.deepOrange; // Obese
    return Colors.red.shade900; // Morbidly Obese
  }

  IconData _getStatusIcon(double zScore) {
    if (zScore < -1) return Icons.warning;
    if (zScore <= 1) return Icons.check_circle;
    if (zScore <= 2) return Icons.info;
    if (zScore <= 3) return Icons.warning;
    return Icons.dangerous;
  }

  String _getClassificationText(double zScore) {
    if (zScore < -3) return 'Far Below Ideal';
    if (zScore < -2) return 'Below Ideal';
    if (zScore < -1) return 'Mildly Below Ideal';
    if (zScore <= 1) return 'Within Ideal';
    if (zScore <= 2) return 'Mildly Above Ideal';
    if (zScore <= 3) return 'Above Ideal';
    return 'Far Above Ideal';
  }

  String _getBMIClassificationText(double zScore) {
    if (zScore < -1) return 'Underweight';
    if (zScore <= 1) return 'Normal';
    if (zScore <= 2) return 'Overweight';
    if (zScore <= 3) return 'Obese';
    return 'Morbidly Obese';
  }

  void _clearAssessments() {
    if (mounted) {
      setState(() {
        _weightAssessment = null;
        _heightAssessment = null;
        _bmiAssessment = null;
      });
    }
  }

  void _assessAll() {
    if (_selectedChild == null) {
      _showErrorSnackBar('Please select a child first');
      return;
    }

    if (_weightController.text.isEmpty || _heightController.text.isEmpty) {
      _showErrorSnackBar('Please enter both weight and height');
      return;
    }

    double? weight = double.tryParse(_weightController.text);
    double? height = double.tryParse(_heightController.text);

    if (weight == null || height == null) {
      _showErrorSnackBar('Please enter valid numbers');
      return;
    }

    if (weight <= 0 || height <= 0) {
      _showErrorSnackBar('Values must be greater than zero');
      return;
    }

    final ageInWeeks = _selectedChild!.getAgeInWeeks();

    // Calculate Z-scores using WHO standards
    double weightZScore = GrowthCalculator.calculateWeightZScore(
      weight, 
      ageInWeeks, 
      _selectedChild!.gender
    );

    double heightZScore = GrowthCalculator.calculateHeightZScore(
      height, 
      ageInWeeks, 
      _selectedChild!.gender
    );

    // Calculate BMI using WHO standards
    double heightInMeters = height / 100;
    double bmi = weight / (heightInMeters * heightInMeters);
    double bmiZScore = GrowthCalculator.calculateBMIZScore(
      bmi,
      ageInWeeks,
      _selectedChild!.gender
    );

    if (mounted) {
      setState(() {
        _weightAssessment = GrowthAssessment(
          value: weight,
          week: ageInWeeks,
          gender: _selectedChild!.gender,
          parameter: 'Weight',
          zScore: weightZScore,
          classification: _getClassificationText(weightZScore),
        );

        _heightAssessment = GrowthAssessment(
          value: height,
          week: ageInWeeks,
          gender: _selectedChild!.gender,
          parameter: 'Height',
          zScore: heightZScore,
          classification: _getClassificationText(heightZScore),
        );

        _bmiAssessment = {
          'bmi': bmi,
          'zScore': bmiZScore,
          'classification': _getBMIClassificationText(bmiZScore),
          'color': _getBMIColor(bmiZScore),
        };
      });
    }
  }

  void _saveGrowthRecord() async {
    if (_selectedChild == null) return;
    
    if (_weightAssessment == null || _heightAssessment == null || _bmiAssessment == null) {
      _showErrorSnackBar('Please assess growth first');
      return;
    }

    final sessionService = Provider.of<SessionService>(context, listen: false);

    final record = GrowthRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: _selectedChild!.id,
      dateRecorded: DateTime.now(),
      ageInWeeks: _selectedChild!.getAgeInWeeks(),
      weight: _weightAssessment!.value,
      height: _heightAssessment!.value,
      bmi: _bmiAssessment!['bmi'],
      weightZScore: _weightAssessment!.zScore,
      heightZScore: _heightAssessment!.zScore,
      bmiZScore: _bmiAssessment!['zScore'],
      weightClassification: _weightAssessment!.classification,
      heightClassification: _heightAssessment!.classification,
      bmiClassification: _bmiAssessment!['classification'],
    );

    await sessionService.addGrowthRecord(record);
    
    // Refresh records
    _loadChildRecords();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Growth record saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Clear form
    if (mounted) {
      setState(() {
        _weightController.clear();
        _heightController.clear();
        _clearAssessments();
        _currentBMI = null;
        _currentBMIClassification = null;
        _currentBMIColor = null;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}