import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/spacing.dart';

class EcoTips extends StatelessWidget {
  final List<String> tips;

  const EcoTips({super.key, required this.tips});

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: WaypointSpacing.sm),
            Text(
              'Eco tips',
              style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
            ),
          ],
        ),
        const SizedBox(height: WaypointSpacing.sm),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: WaypointSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                ),
                Expanded(
                  child: Text(
                    tip,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
