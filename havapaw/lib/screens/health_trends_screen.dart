import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/collar_data_service.dart';
import '../models/collar_data.dart';

class HealthTrendsScreen extends StatefulWidget {
  final String petId;

  const HealthTrendsScreen({super.key, required this.petId});

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends State<HealthTrendsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('health_trends'.tr()),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slateDark),
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<CollarData>>(
        stream: CollarDataService.getCollarDataForPet(widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 64, color: AppColors.alertRed.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'error_loading_data'.tr(),
                    style: const TextStyle(fontSize: 16, color: AppColors.slateDark),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const _ConnectCollarPrompt();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heart rate trend
                _TrendCard(
                  title: 'heart_rate_trend'.tr(),
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.alertRed,
                  child: _HeartRateChart(data: data),
                ),
                const SizedBox(height: 20),

                // Activity trend
                _TrendCard(
                  title: 'activity_trend'.tr(),
                  icon: Icons.directions_run_rounded,
                  iconColor: AppColors.primaryTeal,
                  child: _ActivityChart(data: data),
                ),
                const SizedBox(height: 20),

                // Temperature trend
                _TrendCard(
                  title: 'temperature_trend'.tr(),
                  icon: Icons.thermostat_rounded,
                  iconColor: AppColors.amber,
                  child: _TemperatureChart(data: data),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _TrendCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                ),
              ],
            ),
          ),
          // Chart
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(height: 200, child: child),
          ),
        ],
      ),
    );
  }
}

class _HeartRateChart extends StatelessWidget {
  final List<CollarData> data;

  const _HeartRateChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data.take(20).toList().reversed.toList();
    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value.heartRate?.toDouble() ?? 0),
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 0,
        maxY: 200,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.alertRed,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.alertRed,
                  strokeWidth: 2,
                  strokeColor: AppColors.cardWhite,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.alertRed.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            showOnTopOfTheChartBoxArea: true,
            fitInsideVertically: true,
            tooltipPadding: EdgeInsets.all(8),
            tooltipMargin: 8,
          ),
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<CollarData> data;

  const _ActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data.take(20).toList().reversed.toList();
    final barGroups = chartData.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: (entry.value.steps?.toDouble() ?? 0) / 100,
            color: AppColors.primaryTeal,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${(value * 100).toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${(rod.toY * 100).toInt()} steps',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TemperatureChart extends StatelessWidget {
  final List<CollarData> data;

  const _TemperatureChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data.take(20).toList().reversed.toList();
    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.temperature ?? 0,
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${value.toStringAsFixed(1)}°',
                    style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 35,
        maxY: 42,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.amber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.amber,
                  strokeWidth: 2,
                  strokeColor: AppColors.cardWhite,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.amber.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            showOnTopOfTheChartBoxArea: true,
            fitInsideVertically: true,
            tooltipPadding: EdgeInsets.all(8),
            tooltipMargin: 8,
          ),
        ),
      ),
    );
  }
}

class _ConnectCollarPrompt extends StatelessWidget {
  const _ConnectCollarPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryTeal, AppColors.darkTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'waiting_for_collar_data'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'waiting_for_collar_data_desc'.tr(namedArgs: {'petName': 'your pet'}),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'health_trends_note'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
