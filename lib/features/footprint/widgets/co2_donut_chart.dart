import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';

/// Segment colors for footprint categories (aligned with draft).
class FootprintChartColors {
  static const Color transport = Color(0xFF4CAF50);      // green
  static const Color accommodation = Color(0xFF2196F3); // blue
  static const Color restaurants = Color(0xFFFFC107);    // amber
  static const Color activities = Color(0xFFFF5722);     // orange
}

/// Semi-donut chart showing CO2 breakdown by category.
class Co2DonutChart extends StatelessWidget {
  final FootprintResult result;
  final double size;

  const Co2DonutChart({
    super.key,
    required this.result,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final total = result.totalKgCO2;
    if (total <= 0) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'No data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final values = [
      (result.transportKgCO2, FootprintChartColors.transport, 'Transport'),
      (result.accommodationKgCO2, FootprintChartColors.accommodation, 'Accommodation'),
      (result.restaurantKgCO2, FootprintChartColors.restaurants, 'Restaurants'),
      (result.activityKgCO2, FootprintChartColors.activities, 'Activities'),
    ];
    for (final v in values) {
      if (v.$1 > 0) {
        sections.add(
          PieChartSectionData(
            value: v.$1,
            color: v.$2,
            title: '',
            radius: size / 2 - 16,
            badgeWidget: null,
          ),
        );
      }
    }

    if (sections.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '0 kg',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 1,
              centerSpaceRadius: size / 4,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTotal(result.totalKgCO2),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              Text(
                'CO2 total',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTotal(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)} t';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }
}
