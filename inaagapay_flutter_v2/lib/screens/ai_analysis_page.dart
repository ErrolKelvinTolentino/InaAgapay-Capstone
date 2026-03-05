// lib/screens/ai_analysis_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/session_service.dart';
import '../services/gemini_service.dart';
import '../models/ai_analysis.dart';
import '../models/child.dart';

class AIAnalysisPage extends StatefulWidget {
  const AIAnalysisPage({super.key});

  @override
  State<AIAnalysisPage> createState() => _AIAnalysisPageState();
}

class _AIAnalysisPageState extends State<AIAnalysisPage> {
  final GeminiService _geminiService = GeminiService();
  AIAnalysis? _analysis;
  bool _isLoading = false;
  String? _errorMessage;
  Child? _selectedChild;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionService = Provider.of<SessionService>(context);
    if (sessionService.selectedChild != null && _selectedChild == null) {
      setState(() {
        _selectedChild = sessionService.selectedChild;
      });
    }
  }

  Future<void> _analyzeGrowth() async {
    if (_selectedChild == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysis = null;
    });

    try {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      final records = sessionService.getChildRecords(_selectedChild!.id);
      
      if (records.isEmpty) {
        setState(() {
          _errorMessage = 'No growth records available for this child. Please add some growth records first.';
          _isLoading = false;
        });
        return;
      }

      debugPrint('📊 Sending ${records.length} records to Gemini AI for analysis...');
      
      // This will use REAL Gemini AI
      final result = await _geminiService.analyzeGrowthData(_selectedChild!, records);
      
      if (mounted) {
        setState(() {
          _analysis = result;
          _isLoading = false;
        });
        debugPrint('✅ Real AI analysis completed successfully');
      }
    } catch (e) {
      debugPrint('❌ AI Analysis failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'AI Analysis failed: ${e.toString().replaceFirst('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend.toUpperCase()) {
      case 'EXCELLENT':
        return Colors.green;
      case 'GOOD':
        return Colors.lightGreen;
      case 'NORMAL':
        return Colors.blue;
      case 'CONCERNING':
        return Colors.orange;
      case 'CRITICAL':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toUpperCase()) {
      case 'EXCELLENT':
        return Icons.emoji_emotions;
      case 'GOOD':
        return Icons.sentiment_satisfied;
      case 'NORMAL':
        return Icons.sentiment_neutral;
      case 'CONCERNING':
        return Icons.sentiment_dissatisfied;
      case 'CRITICAL':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Growth Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child Selection Card
              _buildChildSelectionCard(sessionService.children),
              const SizedBox(height: 20),
              
              if (_selectedChild != null) ...[
                // Selected Child Info
                _buildSelectedChildCard(sessionService),
                const SizedBox(height: 20),
                
                // Analyze Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _analyzeGrowth,
                    icon: Icon(
                      Icons.auto_awesome,
                      color: _isLoading ? Colors.grey : Colors.white,
                    ),
                    label: Text(
                      _isLoading ? 'AI IS THINKING...' : 'ANALYZE WITH REAL GEMINI AI',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Results Section
                if (_isLoading)
                  _buildLoadingState()
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_analysis != null)
                  _buildAnalysisResult(),
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
                Icon(Icons.psychology, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text(
                  'Select Child for AI Analysis',
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
                  hint: const Text('Choose a child for AI analysis'),
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
                                  '${child.getAgeInWeeks()} weeks • ${child.gender}',
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
                    setState(() {
                      _selectedChild = newValue;
                      _analysis = null;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChildCard(SessionService sessionService) {
    if (_selectedChild == null) return const SizedBox.shrink();
    
    final recordCount = sessionService.getChildRecords(_selectedChild!.id).length;
    
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
                    Text(
                      'Records: $recordCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                size: 50,
                color: Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(
            backgroundColor: Colors.deepPurple,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gemini AI is analyzing your child\'s growth patterns...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take 10-15 seconds',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '• Analyzing weight trends against WHO standards\n'
            '• Evaluating height velocity and proportionality\n'
            '• Calculating BMI and body composition\n'
            '• Generating personalized recommendations',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
          const SizedBox(height: 16),
          Text(
            'AI Analysis Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _analyzeGrowth,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Analysis Results',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 5),
        Text(
          'Powered by Google Gemini AI',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 15),
        
        // Trend Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _getTrendColor(_analysis!.trend), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTrendColor(_analysis!.trend).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTrendIcon(_analysis!.trend),
                      color: _getTrendColor(_analysis!.trend),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Growth Trend',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _analysis!.trend,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _getTrendColor(_analysis!.trend),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Confidence: ${(_analysis!.confidenceScore * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        
        // Summary Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'AI Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _analysis!.summary,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        
        // Detailed Insights Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.insights, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'Detailed AI Insights',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ..._analysis!.insights.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatInsightKey(entry.key),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        
        // Recommendations Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.recommend, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'AI Recommendations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ..._analysis!.recommendations.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        
        // AI Disclaimer
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This analysis is generated by Google Gemini AI based on WHO growth standards and should not replace professional medical advice. Always consult with a healthcare provider.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatInsightKey(String key) {
    // Convert camelCase to Title Case with spaces
    final formatted = key.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}');
    return formatted[0].toUpperCase() + formatted.substring(1).toLowerCase();
  }
}