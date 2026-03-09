import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/hero_card.dart';
import '../widgets/overview_info.dart';
import '../widgets/midwife_statistics_card.dart';
import '../widgets/midwife_history_card.dart';
import '../widgets/chart_card.dart';
import '../services/auth_storage.dart';

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructive ? Colors.red : AppColors.textPrimary;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class MidwifeDashboard extends StatefulWidget {
  const MidwifeDashboard({super.key});

  @override
  State<MidwifeDashboard> createState() => _MidwifeDashboardState();
}

class _MidwifeDashboardState extends State<MidwifeDashboard> {
  late Future<DashboardData> _dashboardFuture;
  late Future<GreetingModel> _greetingFuture;
  final GlobalKey _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _greetingFuture = _fetchGreeting();
    _dashboardFuture = _fetchDashboardData();
  }

  // ================= API CALLS =================

  Future<GreetingModel> _fetchGreeting() async {
    final token = await AuthStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('https://inaagapay.alwaysdata.net/api/auth/greeting.php'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    final Map<String, dynamic> decoded = jsonDecode(res.body);

    if (decoded['success'] != true) {
      throw Exception('Greeting API failed');
    }

    return GreetingModel.fromJson(decoded);
  }

  Future<DashboardData> _fetchDashboardData() async {
    final token = await AuthStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/dashboard_stats.php',
      ),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return DashboardData.fromJson(data);
      } else {
        throw Exception(data['error'] ?? 'Failed to load dashboard data');
      }
    }

    throw Exception('Failed to load dashboard data');
  }

  Future<void> _logout() async {
    final token = await AuthStorage.getToken();
    try {
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('https://inaagapay.alwaysdata.net/api/auth/logout.php'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      }
    } catch (_) {
      // Ignore network errors; still clear local session.
    }

    await AuthStorage.clearToken();

    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _showProfileMenu() async {
    final RenderBox? avatarBox =
        _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    if (avatarBox == null || overlay == null) return;

    final Offset offset = avatarBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        offset.dx,
        offset.dy + avatarBox.size.height + 8,
        avatarBox.size.width,
        avatarBox.size.height,
      ),
      Offset.zero & overlay.size,
    );

    final String? selected = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: 'profile',
          child: _ProfileMenuRow(icon: Icons.person, label: 'Profile'),
        ),
        PopupMenuItem(
          value: 'settings',
          child: _ProfileMenuRow(icon: Icons.settings, label: 'Settings'),
        ),
        PopupMenuItem(
          value: 'logout',
          child: _ProfileMenuRow(
            icon: Icons.logout,
            label: 'Logout',
            isDestructive: true,
          ),
        ),
      ],
      elevation: 8,
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'profile':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile coming soon')));
        break;
      case 'settings':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
        break;
      case 'logout':
        await _logout();
        break;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _dashboardFuture = _fetchDashboardData();
      _greetingFuture = _fetchGreeting();
    });
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      body: Column(
        children: [
          /// 🔝 HEADER
          MainHeader(
            title: 'Home',
            onNotificationTap: () {},
            onAvatarTap: _showProfileMenu,
            avatarKey: _avatarKey,
          ),

          /// 🔽 BODY
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: FutureBuilder<GreetingModel>(
                future: _greetingFuture,
                builder: (context, greetingSnapshot) {
                  if (greetingSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (greetingSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${greetingSnapshot.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final greeting = greetingSnapshot.data!;

                  return FutureBuilder<DashboardData>(
                    future: _dashboardFuture,
                    builder: (context, dashboardSnapshot) {
                      if (dashboardSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (dashboardSnapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error: ${dashboardSnapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refreshData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final dashboardData = dashboardSnapshot.data!;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            /// 👋 HERO
                            HeroCard(
                              image: const AssetImage(
                                'assets/images/midwife.png',
                              ),
                              title:
                                  'Welcome, ${greeting.firstName ?? 'Midwife'}! 🌸',
                              subtitle:
                                  'Barangay ${greeting.bhcName ?? 'Health Center'} Midwife',
                              showWeekBadge: false,
                              showHeartRow: false,
                            ),
                            const SizedBox(height: 20),

                            /// 📊 QUICK OVERVIEW - Using real data
                            Row(
                              children: [
                                Expanded(
                                  child: OverviewInfo(
                                    value: dashboardData.registeredChildren,
                                    label: 'Registered\nChildren',
                                    icon: Icons.child_care_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OverviewInfo(
                                    value: dashboardData.registeredMothers,
                                    label: 'Registered\nMothers',
                                    icon: Icons.pregnant_woman,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: OverviewInfo(
                                    value: dashboardData.ferrousGiven,
                                    label: 'Ferrous + FA\ngiven',
                                    icon: Icons.medication,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OverviewInfo(
                                    value: dashboardData.calciumGiven,
                                    label: 'Calcium\ngiven',
                                    icon: Icons.local_pharmacy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OverviewInfo(
                                    value: dashboardData.tdDosesGiven,
                                    label: 'TD Vaccine\ndoses given',
                                    icon: Icons.vaccines,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            /// 🤰 ACTIVE PREGNANCIES CARD - Using real data
                            MidwifeStatisticsCard(
                              totalPregnancies: dashboardData.totalPregnancies,
                              firstTrimester: dashboardData.firstTrimester,
                              secondTrimester: dashboardData.secondTrimester,
                              thirdTrimester: dashboardData.thirdTrimester,
                            ),
                            const SizedBox(height: 20),

                            /// 🕘 RECENT VISITS - Using real data from API
                            MidwifeHistoryCard(
                              visits: dashboardData.recentVisits.map((visit) {
                                return MidwifeVisitItem(
                                  fullName: visit.fullName,
                                  visitType: visit.visitType,
                                  timeLabel: visit.timeLabel,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            /// 📈 BHC VISITS CHART - Using real data
                            ChartCard(
                              title: 'BHC Daily Visits Chart',
                              headerIcon: Icons.show_chart_rounded,
                              values: dashboardData.bhcVisitValues,
                              labels: dashboardData.bhcVisitDays,
                              unit: 'visits',
                              lineColor: AppColors.brandPrimary,
                              startingLabel: 'Lowest',
                              startingValue:
                                  '${dashboardData.lowestVisitCount} visits',
                              latestLabel: 'Highest',
                              latestValue:
                                  '${dashboardData.highestVisitCount} visits',
                              insightText: dashboardData.insightText,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MODELS =================

class GreetingModel {
  final String? accountType;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? extensionName;
  final String? bhcName;

  GreetingModel({
    this.accountType,
    this.firstName,
    this.middleName,
    this.lastName,
    this.extensionName,
    this.bhcName,
  });

  factory GreetingModel.fromJson(Map<String, dynamic> json) {
    return GreetingModel(
      accountType: json['role']?.toString(),
      firstName: json['first_name']?.toString(),
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString(),
      extensionName: json['extension_name']?.toString(),
      bhcName: json['bhc_name']?.toString(),
    );
  }

  String get displayName {
    final parts = [firstName, middleName, lastName, extensionName];
    return parts
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(' ');
  }

  String get roleLabel {
    switch (accountType) {
      case 'midwife':
        return 'Midwife';
      case 'mother':
        return 'Mother';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }
}

class DashboardData {
  final int registeredChildren;
  final int registeredMothers;
  final int ferrousGiven;
  final int calciumGiven;
  final int tdDosesGiven;
  final int totalPregnancies;
  final int firstTrimester;
  final int secondTrimester;
  final int thirdTrimester;
  final List<RecentVisit> recentVisits;
  final List<double> bhcVisitValues;
  final List<String> bhcVisitDays;
  final int highestVisitCount;
  final int lowestVisitCount;
  final String insightText;

  DashboardData({
    required this.registeredChildren,
    required this.registeredMothers,
    required this.ferrousGiven,
    required this.calciumGiven,
    required this.tdDosesGiven,
    required this.totalPregnancies,
    required this.firstTrimester,
    required this.secondTrimester,
    required this.thirdTrimester,
    required this.recentVisits,
    required this.bhcVisitValues,
    required this.bhcVisitDays,
    required this.highestVisitCount,
    required this.lowestVisitCount,
    required this.insightText,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    int safe(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

    // Parse trimester data
    final trimesterData = json['trimester'] as Map<String, dynamic>? ?? {};
    final firstTri = safe(trimesterData['first_trimester']);
    final secondTri = safe(trimesterData['second_trimester']);
    final thirdTri = safe(trimesterData['third_trimester']);

    // Parse registered counts
    final registeredData = json['registered'] as Map<String, dynamic>? ?? {};

    // Parse medication data
    final medicationData = json['medications'] as Map<String, dynamic>? ?? {};

    // Parse recent visits
    final recentVisitsJson = json['recent_visits'] as List<dynamic>? ?? [];
    final recentVisits = recentVisitsJson.map((item) {
      return RecentVisit.fromJson(item as Map<String, dynamic>);
    }).toList();

    // Parse chart data
    final chartData = json['chart_data'] as Map<String, dynamic>? ?? {};
    final chartValues =
        (chartData['values'] as List<dynamic>? ?? List.filled(7, 0))
            .map((v) => (v as num).toDouble())
            .toList();
    final chartLabels =
        (chartData['labels'] as List<dynamic>? ??
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            .map((v) => v.toString())
            .toList();

    final highest = safe(chartData['highest']);
    final lowest = safe(chartData['lowest']);

    // Generate insight text
    String insightText = 'No visits data available';
    if (chartValues.isNotEmpty && chartLabels.isNotEmpty) {
      final maxIndex = chartValues.indexOf(
        chartValues.reduce((a, b) => a > b ? a : b),
      );
      if (maxIndex < chartLabels.length) {
        insightText =
            '${chartLabels[maxIndex]} had the most prenatal visits this week!';
      }
    }

    return DashboardData(
      registeredChildren: safe(registeredData['children']),
      registeredMothers: safe(registeredData['mothers']),
      ferrousGiven: safe(medicationData['ferrous_given']),
      calciumGiven: safe(medicationData['calcium_given']),
      tdDosesGiven: safe(medicationData['td_doses_given']),
      totalPregnancies: firstTri + secondTri + thirdTri,
      firstTrimester: firstTri,
      secondTrimester: secondTri,
      thirdTrimester: thirdTri,
      recentVisits: recentVisits,
      bhcVisitValues: chartValues,
      bhcVisitDays: chartLabels,
      highestVisitCount: highest,
      lowestVisitCount: lowest,
      insightText: insightText,
    );
  }
}

class RecentVisit {
  final String fullName;
  final String visitType;
  final String timeLabel;

  RecentVisit({
    required this.fullName,
    required this.visitType,
    required this.timeLabel,
  });

  factory RecentVisit.fromJson(Map<String, dynamic> json) {
    return RecentVisit(
      fullName: json['full_name']?.toString() ?? 'Unknown Mother',
      visitType: json['visit_type']?.toString() ?? 'Prenatal Check-up',
      timeLabel: json['time_label']?.toString() ?? 'Recently',
    );
  }
}
