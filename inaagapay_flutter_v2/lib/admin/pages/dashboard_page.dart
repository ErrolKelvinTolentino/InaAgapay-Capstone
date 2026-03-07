import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../admin_session.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, int>> _countsFuture;
  late Future<Map<String, int>> _riskFuture;
  late Future<List<Map<String, dynamic>>> _auditFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _countsFuture = AdminService.getDashboardCounts();
    _riskFuture = AdminService.getRiskDistribution();
    _auditFuture = AdminService.getRecentAuditTrail(limit: 8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600
            ? 16.0
            : constraints.maxWidth < 900
            ? 20.0
            : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              SizedBox(height: pad),
              _buildStatCards(),
              SizedBox(height: pad),
              _buildChartsRow(),
              SizedBox(height: pad),
              _buildRecentActivity(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Welcome back, ${AdminSession.displayName}! Here\'s an overview.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Refresh button
        OutlinedButton.icon(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Stat Cards ──────────────────────────────────────────────────────────
  Widget _buildStatCards() {
    return FutureBuilder<Map<String, int>>(
      future: _countsFuture,
      builder: (ctx, snap) {
        final data =
            snap.data ??
            {
              'mothers': 0,
              'midwives': 0,
              'admins': 0,
              'pregnancies': 0,
              'children': 0,
            };
        final loading = snap.connectionState == ConnectionState.waiting;

        final cards = [
          _StatCardData(
            title: 'Registered Mothers',
            value: data['mothers'] ?? 0,
            icon: Icons.pregnant_woman_rounded,
            gradient: AppTheme.stat1,
            sub: 'Active accounts',
          ),
          _StatCardData(
            title: 'Midwives',
            value: data['midwives'] ?? 0,
            icon: Icons.medical_services_rounded,
            gradient: AppTheme.stat2,
            sub: 'Active accounts',
          ),
          _StatCardData(
            title: 'Ongoing Pregnancies',
            value: data['pregnancies'] ?? 0,
            icon: Icons.monitor_heart_rounded,
            gradient: AppTheme.stat3,
            sub: 'Total records',
          ),
          _StatCardData(
            title: 'Children Registered',
            value: data['children'] ?? 0,
            icon: Icons.child_care_rounded,
            gradient: AppTheme.stat4,
            sub: 'Total records',
          ),
          _StatCardData(
            title: 'Administrators',
            value: data['admins'] ?? 0,
            icon: Icons.admin_panel_settings_rounded,
            gradient: AppTheme.stat5,
            sub: 'Active accounts',
          ),
        ];

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 1200
                ? 5
                : constraints.maxWidth > 900
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                childAspectRatio: 1.6,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: cards.length,
              itemBuilder: (_, i) =>
                  _StatCard(data: cards[i], loading: loading),
            );
          },
        );
      },
    );
  }

  // ─── Charts ───────────────────────────────────────────────────────────────
  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth > 800) {
          return Row(
            children: [
              Expanded(child: _buildRiskChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildAccountTypeChart()),
            ],
          );
        }
        return Column(
          children: [
            _buildRiskChart(),
            const SizedBox(height: 16),
            _buildAccountTypeChart(),
          ],
        );
      },
    );
  }

  Widget _buildRiskChart() {
    return FutureBuilder<Map<String, int>>(
      future: _riskFuture,
      builder: (ctx, snap) {
        final data = snap.data ?? {};
        final loading = snap.connectionState == ConnectionState.waiting;

        final low = data['low'] ?? 0;
        final medium = data['medium'] ?? 0;
        final high = data['high'] ?? 0;
        final total = low + medium + high;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chartTitle(
                'Pregnancy Risk Distribution',
                Icons.pie_chart_rounded,
              ),
              const SizedBox(height: 20),
              loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPink,
                      ),
                    )
                  : total == 0
                  ? _emptyChart('No pregnancy data available')
                  : SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 50,
                                sections: [
                                  if (low > 0)
                                    PieChartSectionData(
                                      value: low.toDouble(),
                                      color: const Color(0xFF43A047),
                                      title:
                                          '${((low / total) * 100).round()}%',
                                      radius: 55,
                                      titleStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (medium > 0)
                                    PieChartSectionData(
                                      value: medium.toDouble(),
                                      color: const Color(0xFFFB8C00),
                                      title:
                                          '${((medium / total) * 100).round()}%',
                                      radius: 55,
                                      titleStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (high > 0)
                                    PieChartSectionData(
                                      value: high.toDouble(),
                                      color: const Color(0xFFE53935),
                                      title:
                                          '${((high / total) * 100).round()}%',
                                      radius: 55,
                                      titleStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legend('Low Risk', const Color(0xFF43A047), low),
                              const SizedBox(height: 10),
                              _legend(
                                'Medium Risk',
                                const Color(0xFFFB8C00),
                                medium,
                              ),
                              const SizedBox(height: 10),
                              _legend(
                                'High Risk',
                                const Color(0xFFE53935),
                                high,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountTypeChart() {
    return FutureBuilder<Map<String, int>>(
      future: _countsFuture,
      builder: (ctx, snap) {
        final data = snap.data ?? {'mothers': 0, 'midwives': 0, 'admins': 0};
        final loading = snap.connectionState == ConnectionState.waiting;

        final barData = [
          _BarItem('Mothers', data['mothers'] ?? 0, AppTheme.primaryPink),
          _BarItem('Midwives', data['midwives'] ?? 0, const Color(0xFF8E24AA)),
          _BarItem('Admins', data['admins'] ?? 0, const Color(0xFF00897B)),
        ];
        final maxY =
            barData
                .map((b) => b.value)
                .reduce((a, b) => a > b ? a : b)
                .toDouble() +
            2;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chartTitle('Account Overview', Icons.bar_chart_rounded),
              const SizedBox(height: 20),
              loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPink,
                      ),
                    )
                  : SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          maxY: maxY < 4 ? 4 : maxY,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (v, meta) => Text(
                                  v.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= barData.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      barData[i].label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) => const FlLine(
                              color: AppTheme.borderColor,
                              strokeWidth: 0.5,
                            ),
                          ),
                          barGroups: barData
                              .asMap()
                              .entries
                              .map(
                                (e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value.value.toDouble(),
                                      color: e.value.color,
                                      width: 40,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                      backDrawRodData:
                                          BackgroundBarChartRodData(
                                            show: true,
                                            toY: maxY < 4 ? 4 : maxY,
                                            color: AppTheme.softPink.withAlpha(
                                              80,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  // ─── Recent Activity ──────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _auditFuture,
      builder: (ctx, snap) {
        final rows = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chartTitle('Recent Activity', Icons.history_rounded),
              const SizedBox(height: 16),
              if (loading)
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPink),
                )
              else if (rows.isEmpty)
                _emptyChart('No recent activity')
              else
                ...rows.map((row) {
                  final acct = row['accounts'] as Map<String, dynamic>?;
                  final name = acct != null
                      ? '${acct['first_name'] ?? ''} ${acct['last_name'] ?? ''}'
                            .trim()
                      : 'System';
                  final action = row['action'] as String? ?? '';
                  final ts = row['action_timestamp'] as String? ?? '';
                  final dt = DateTime.tryParse(ts);
                  final formatted = dt != null
                      ? DateFormat('MMM d, hh:mm a').format(dt.toLocal())
                      : ts;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.softPink.withAlpha(80),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.borderColor.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppTheme.heroGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'by $name',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatted,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _chartTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryPink, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($value)',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _emptyChart(String msg) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: AppTheme.borderColor,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data helpers ─────────────────────────────────────────────────────────
class _StatCardData {
  final String title;
  final int value;
  final IconData icon;
  final LinearGradient gradient;
  final String sub;
  _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.sub,
  });
}

class _BarItem {
  final String label;
  final int value;
  final Color color;
  _BarItem(this.label, this.value, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final bool loading;
  const _StatCard({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.gradient.colors.first.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: Colors.white, size: 20),
              ),
              Icon(
                Icons.trending_up_rounded,
                color: Colors.white.withAlpha(120),
                size: 18,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              loading
                  ? Container(
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      data.value.toString(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              Text(
                data.title,
                style: GoogleFonts.poppins(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                data.sub,
                style: GoogleFonts.poppins(
                  color: Colors.white.withAlpha(150),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
