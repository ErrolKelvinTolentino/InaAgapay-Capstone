import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/main_bottom_navigation.dart';
import '../widgets/headline.dart';
import '../widgets/long_info_box.dart';
import '../widgets/main_button.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class MotherMoreInfoPage extends StatefulWidget {
  const MotherMoreInfoPage({super.key});

  @override
  State<MotherMoreInfoPage> createState() => _MotherMoreInfoPageState();
}

class _MotherMoreInfoPageState extends State<MotherMoreInfoPage> {
  bool _loadingMedications = true;
  List<dynamic> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedicationPlan();
  }

  Future<void> _loadMedicationPlan() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        setState(() => _loadingMedications = false);
        return;
      }

      final res = await ApiService.get(
        'mother/mother_medication_plan.php',
        token: token,
      );

      if (res['success'] == true && res['medications'] is List) {
        setState(() {
          _medications = res['medications'];
          _loadingMedications = false;
        });
      } else {
        setState(() => _loadingMedications = false);
      }
    } catch (_) {
      setState(() => _loadingMedications = false);
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '—';
    try {
      final d = DateTime.parse(value);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'PREGNANCY CARE',
          onNotificationTap: () {},
          onAvatarTap: () {},
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Headline(
                text: 'Taking Care of Yourself 🌷',
                textAlign: TextAlign.left,
              ),

              const SizedBox(height: 12),

              const Text(
                'Pregnancy is a special journey. Here are simple tips to help keep you and your baby healthy.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 24),

              LongInfoBox(
                icon: Icons.restaurant,
                text: const [
                  TextSpan(
                    text: 'Nutrition & Hydration\n',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        '• Eat balanced meals daily.\n'
                        '• Drink plenty of water.\n'
                        '• Take prenatal vitamins if prescribed.\n'
                        '• Avoid alcohol and smoking.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              LongInfoBox(
                icon: Icons.favorite,
                text: const [
                  TextSpan(
                    text: 'Body Changes\n',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        '• Fatigue and nausea are normal.\n'
                        '• Back pain may occur.\n'
                        '• Get enough rest.\n'
                        '• Avoid heavy lifting.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              LongInfoBox(
                icon: Icons.self_improvement,
                text: const [
                  TextSpan(
                    text: 'Mental Health\n',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        '• Mood changes are normal.\n'
                        '• Talk to loved ones.\n'
                        '• Do relaxing activities.\n'
                        '• Ask for help if needed.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              LongInfoBox(
                icon: Icons.health_and_safety,
                text: const [
                  TextSpan(
                    text: 'Safety Tips\n',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        '• Avoid self-medication.\n'
                        '• Stay away from smoke.\n'
                        '• Wear comfortable footwear.\n'
                        '• Attend prenatal checkups.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),

              // ================= MEDICATION PLAN =================
              const SizedBox(height: 24),

              const Text(
                'Medication Plan 💊',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              if (_loadingMedications)
                const Center(child: CircularProgressIndicator()),

              if (!_loadingMedications && _medications.isEmpty)
                const Text(
                  'No prescribed medications available.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),

              if (!_loadingMedications)
                ..._medications.map((med) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LongInfoBox(
                      icon: Icons.medication_rounded,
                      text: [
                        TextSpan(
                          text:
                              '${med['mother_medication_name'] ?? 'Medication'}\n',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text:
                              'Frequency: ${med['frequency'] ?? '—'}\n'
                              'Quantity: ${med['quantity'] ?? '—'}\n'
                              'Start: ${_formatDate(med['start_date'])}\n'
                              'End: ${_formatDate(med['end_date'])}\n'
                              'Status: ${med['status'] ?? '—'}',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),

              const SizedBox(height: 32),

              // ✅ EXIT BUTTON (UNCHANGED)
              MainButton(
                label: 'Exit',
                showIcons: true,
                leadingIcon: Icons.arrow_back,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const MainBottomNavigation(currentIndex: 0),
    );
  }
}
