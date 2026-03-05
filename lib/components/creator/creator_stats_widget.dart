import 'package:flutter/material.dart';
import 'package:waypoint/models/creator_stats_model.dart';
import 'package:waypoint/theme.dart';

/// Widget displaying creator statistics
/// Format: "12 Adventures" | "1.2k Followers" | "450 km"
/// Uses theme colors so it respects light/dark mode.
class CreatorStatsWidget extends StatelessWidget {
  final CreatorStats stats;

  const CreatorStatsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final useProfileLabels = stats.tripsCount != null;
    return Container(
      padding: WaypointSpacing.cardPadding,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: context.colors.outline.withValues(alpha: 0.5), width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: useProfileLabels
                ? (stats.tripsCount ?? 0).toString()
                : stats.adventuresCreated.toString(),
            label: useProfileLabels
                ? (stats.tripsCount == 1 ? 'Trip' : 'Trips')
                : (stats.adventuresCreated == 1 ? 'Adventure' : 'Adventures'),
          ),
          const _StatDivider(),
          _StatItem(
            value: useProfileLabels
                ? stats.adventuresCreated.toString()
                : stats.formattedFollowersCount,
            label: useProfileLabels ? 'Plans Built' : (stats.followersCount == 1 ? 'Follower' : 'Followers'),
          ),
          const _StatDivider(),
          _StatItem(
            value: useProfileLabels ? stats.formattedFollowersCount : stats.formattedDistance,
            label: useProfileLabels ? (stats.followersCount == 1 ? 'Follower' : 'Followers') : 'Total Distance',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.textStyles.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: context.colors.outline.withValues(alpha: 0.3),
    );
  }
}

