import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/secondary_header.dart';
import '../widgets/records_display_card.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class PregnancyDetailsPage extends StatefulWidget {
  const PregnancyDetailsPage({super.key});

  @override
  State<PregnancyDetailsPage> createState() => _PregnancyDetailsPageState();
}

class _PregnancyDetailsPageState extends State<PregnancyDetailsPage> {
  bool _isLoading = true;
  List<dynamic> _pregnancyHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchPregnancyHistory();
  }

  Future<void> _fetchPregnancyHistory() async {
    try {
      setState(() => _isLoading = true);

      // 🔐 GET AUTH TOKEN
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Unauthorized: token missing');
      }

      // ✅ CORRECT ENDPOINT + TOKEN
      final response = await ApiService.get(
        'mother/pregnancy_history.php',
        token: token,
      );

      if (response['success'] == true) {
        setState(() {
          _pregnancyHistory =
              response['history'] is List ? response['history'] : [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError(response['message'] ?? 'Unable to load records');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not recorded';
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[month - 1];
  }

  String _getOutcomeText(String? outcome) {
    const map = {
      'live_birth': 'Live Birth',
      'stillbirth': 'Stillbirth',
      'miscarriage': 'Miscarriage',
      'abortion': 'Abortion',
      'ectopic': 'Ectopic Pregnancy',
    };
    return map[outcome] ?? 'Not recorded';
  }

  String _getMethodFromOutcome(String? outcome) {
    return outcome == 'live_birth' ? 'Normal Delivery' : 'N/A';
  }

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SecondaryHeader(
          title: 'Pregnancy History',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPregnancyHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pregnancyHistory.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.pregnant_woman_rounded,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No pregnancy history found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        for (int i = 0; i < _pregnancyHistory.length; i++) ...[
                          PregnancyCard(
                            pregnancyNumber: i + 1,
                            pregnancyData: _pregnancyHistory[i],
                            formatDate: _formatDate,
                            getOutcomeText: _getOutcomeText,
                            getMethodFromOutcome: _getMethodFromOutcome,
                            titleCase: _titleCase,
                          ),
                          if (i < _pregnancyHistory.length - 1)
                            const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              PREGNANCY CARD                                */
/* -------------------------------------------------------------------------- */

class PregnancyCard extends StatelessWidget {
  final int pregnancyNumber;
  final Map<String, dynamic> pregnancyData;
  final String Function(String?) formatDate;
  final String Function(String?) getOutcomeText;
  final String Function(String?) getMethodFromOutcome;
  final String Function(String) titleCase;

  const PregnancyCard({
    required this.pregnancyNumber,
    required this.pregnancyData,
    required this.formatDate,
    required this.getOutcomeText,
    required this.getMethodFromOutcome,
    required this.titleCase,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryPlace =
        pregnancyData['place_of_delivery'] ?? 'Not recorded';

    final deliveryMethod =
        pregnancyData['method_display'] ??
        pregnancyData['delivery_method'] ??
        getMethodFromOutcome(pregnancyData['outcome']);

    final deliveryDate =
        pregnancyData['delivery_date'] ??
        pregnancyData['outcome_date'] ??
        pregnancyData['expected_date_of_delivery'];

    return RecordsDisplayCard(
      title: 'Pregnancy #$pregnancyNumber Details',
      headerIcon: Icons.info_outline_rounded,
      items: [
        if (pregnancyData['last_menstrual_period'] != null) ...[
          const RecordItem(
            leadingIcon: Icons.calendar_today_rounded,
            label: 'Last Menstrual Period',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.event_rounded,
            label: 'Date',
            value: formatDate(pregnancyData['last_menstrual_period']),
          ),
        ],

        if (pregnancyData['expected_date_of_delivery'] != null) ...[
          const RecordItem(
            leadingIcon: Icons.event_note_rounded,
            label: 'Expected Delivery Date',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.assignment_turned_in_rounded,
            label: 'Date',
            value: formatDate(
              pregnancyData['expected_date_of_delivery'],
            ),
          ),
        ],

        if (deliveryPlace != 'Not recorded') ...[
          const RecordItem(
            leadingIcon: Icons.location_on_rounded,
            label: 'Delivery Place',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.local_hospital_rounded,
            label: 'Institution',
            value: deliveryPlace,
          ),
        ],

        if (deliveryDate != null) ...[
          const RecordItem(
            leadingIcon: Icons.calendar_month_rounded,
            label: 'Delivery Date',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.date_range_rounded,
            label: 'Date',
            value: formatDate(deliveryDate),
          ),
        ],

        const RecordItem(
          leadingIcon: Icons.medical_services_rounded,
          label: 'Method of Delivery',
          value: '',
        ),
        RecordItem(
          leadingIcon: Icons.delivery_dining_rounded,
          label: 'Method',
          value: deliveryMethod,
        ),

        const RecordItem(
          leadingIcon: Icons.fact_check_rounded,
          label: 'Outcome',
          value: '',
        ),
        RecordItem(
          leadingIcon: Icons.child_care_rounded,
          label: 'Result',
          value: getOutcomeText(pregnancyData['outcome']),
        ),

        if (pregnancyData['gestational_age_at_end'] != null) ...[
          const RecordItem(
            leadingIcon: Icons.timeline_rounded,
            label: 'Gestational Age at End',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.timeline_rounded,
            label: 'Weeks',
            value: '${pregnancyData['gestational_age_at_end']} weeks',
          ),
        ],

        if (pregnancyData['status'] != null) ...[
          const RecordItem(
            leadingIcon: Icons.info_rounded,
            label: 'Status',
            value: '',
          ),
          RecordItem(
            leadingIcon: Icons.circle_rounded,
            label: 'Status',
            value: titleCase(pregnancyData['status']),
          ),
        ],
      ],
    );
  }
}
