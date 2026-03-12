import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/spacing.dart';
import 'package:waypoint/features/footprint/widgets/co2_donut_chart.dart';

class CategoryBreakdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double share; // 0..1
  final double kgCO2;
  final Color color;

  const CategoryBreakdownRow({
    super.key,
    required this.icon,
    required this.label,
    required this.share,
    required this.kgCO2,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WaypointSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: WaypointSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: color,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: WaypointSpacing.sm),
          SizedBox(
            width: 56,
            child: Text(
              '${kgCO2.toStringAsFixed(1)} kg',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
