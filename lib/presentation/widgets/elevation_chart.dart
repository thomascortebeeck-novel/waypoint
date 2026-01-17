import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';

// Re-export ElevationPoint for backwards compatibility
export 'package:waypoint/models/plan_model.dart' show ElevationPoint;

class ElevationChart extends StatelessWidget {
  final List<ElevationPoint> data;
  const ElevationChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()} km', style: Theme.of(context).textTheme.labelSmall)),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()} m', style: Theme.of(context).textTheme.labelSmall)),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.map((e) => FlSpot(e.distance / 1000.0, e.elevation)).toList(),
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
