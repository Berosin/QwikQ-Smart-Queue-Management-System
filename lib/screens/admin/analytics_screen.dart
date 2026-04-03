import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/ai_prediction_service.dart';

// ============================================================
// analytics_screen.dart
// ============================================================
class AnalyticsScreen extends ConsumerStatefulWidget {
  final String shopId;
  const AnalyticsScreen({super.key, required this.shopId});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<String, dynamic> _peakData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final data = await AiPredictionService().getPeakHoursAnalysis(widget.shopId);
      if (mounted) setState(() {
        _peakData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(title: 'TODAY', value: '47', subtitle: 'customers', color: AppColors.electricBlue)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(title: 'AVG WAIT', value: '8m', subtitle: 'per person', color: AppColors.neonGreen)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(title: 'PEAK', value: '2PM', subtitle: 'busiest hour', color: AppColors.statusWaiting)),
                    ],
                  ).animate().fadeIn(),

                  const SizedBox(height: 24),

                  Text('HOURLY TRAFFIC', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 14),

                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 20,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (val, _) => Text(
                                  '${val.toInt()}h',
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(12, (i) {
                            final hour = i + 8; // 8am to 8pm
                            final count = (_peakData['hourly_averages'] as Map?)?['$hour'] ?? (i * 3 % 18);
                            final isPeak = hour == (_peakData['peak_hour'] ?? 14);
                            return BarChartGroupData(
                              x: hour,
                              barRods: [
                                BarChartRodData(
                                  toY: (count as num).toDouble(),
                                  gradient: LinearGradient(
                                    colors: isPeak
                                        ? AppColors.primaryGradient
                                        : [
                                            AppColors.electricBlue.withOpacity(0.5),
                                            AppColors.electricBlue.withOpacity(0.3),
                                          ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 24),
                  Text('WEEKLY OVERVIEW', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 14),

                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: Colors.white10,
                              strokeWidth: 1,
                            ),
                            drawVerticalLine: false,
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (val, _) {
                                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  final i = val.toInt();
                                  if (i < 0 || i >= days.length) return const SizedBox();
                                  return Text(days[i], style: AppTextStyles.bodySmall.copyWith(fontSize: 10));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                const FlSpot(0, 32),
                                const FlSpot(1, 45),
                                const FlSpot(2, 38),
                                const FlSpot(3, 52),
                                const FlSpot(4, 60),
                                const FlSpot(5, 72),
                                const FlSpot(6, 41),
                              ],
                              isCurved: true,
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              barWidth: 3,
                              dotData: FlDotData(
                                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.neonGreen,
                                  strokeWidth: 0,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.electricBlue.withOpacity(0.3),
                                    AppColors.neonGreen.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: 350.ms).fadeIn(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.neonGlow(color, size: 22)),
            Text(subtitle, style: AppTextStyles.bodySmall),
          ],
        ),
      );
}
