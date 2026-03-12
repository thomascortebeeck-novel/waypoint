import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/radius.dart';
import 'package:waypoint/core/theme/spacing.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';

class FootprintEquivalents extends StatelessWidget {
  final List<FootprintEquivalent> equivalents;
  final String introText;

  const FootprintEquivalents({
    super.key,
    required this.equivalents,
    this.introText = 'This is equivalent to:',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          introText,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - WaypointSpacing.sm * 2) / 3;
            return Wrap(
              spacing: WaypointSpacing.sm,
              runSpacing: WaypointSpacing.sm,
              children: equivalents.map((e) {
                return SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: WaypointRadius.borderMd,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(WaypointSpacing.sm),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            e.icon,
                            size: 28,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: WaypointSpacing.xs),
                          Text(
                            _formatValue(e.value),
                            style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                          ),
                          Text(
                            e.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _formatValue(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toString();
  }
}
