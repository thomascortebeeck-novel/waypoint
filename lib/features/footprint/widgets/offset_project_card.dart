import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/radius.dart';
import 'package:waypoint/core/theme/spacing.dart';

class OffsetProjectCard extends StatelessWidget {
  final String title;
  final String country;
  final String? imageUrl;
  final VoidCallback? onMoreInfo;
  final VoidCallback? onContribute;

  const OffsetProjectCard({
    super.key,
    required this.title,
    required this.country,
    this.imageUrl,
    this.onMoreInfo,
    this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: WaypointRadius.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            )
          else
            _placeholder(context),
          Padding(
            padding: const EdgeInsets.all(WaypointSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      country,
                      style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: WaypointSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: WaypointSpacing.sm),
                Row(
                  children: [
                    if (onMoreInfo != null)
                      OutlinedButton(
                        onPressed: onMoreInfo,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WaypointSpacing.md,
                            vertical: WaypointSpacing.sm,
                          ),
                        ),
                        child: const Text('More Info'),
                      ),
                    const SizedBox(width: WaypointSpacing.sm),
                    if (onContribute != null)
                      FilledButton.icon(
                        onPressed: onContribute,
                        icon: const Icon(Icons.eco, size: 18),
                        label: const Text('Contribute'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WaypointSpacing.md,
                            vertical: WaypointSpacing.sm,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      height: 120,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.forest,
        size: 48,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}
