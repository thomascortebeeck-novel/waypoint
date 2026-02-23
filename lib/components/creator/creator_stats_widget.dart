import 'package:flutter/material.dart';
import 'package:waypoint/models/creator_stats_model.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Widget displaying creator statistics
/// Format: "12 Adventures" | "1.2k Followers" | "450 km"
class CreatorStatsWidget extends StatelessWidget {
  final CreatorStats stats;

  const CreatorStatsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: WaypointSpacing.cardPaddingInsets,
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border.all(color: WaypointColors.border, width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: stats.adventuresCreated.toString(),
            label: stats.adventuresCreated == 1 ? 'Adventure' : 'Adventures',
          ),
          _StatDivider(),
          _StatItem(
            value: stats.formattedFollowersCount,
            label: stats.followersCount == 1 ? 'Follower' : 'Followers',
          ),
          _StatDivider(),
          _StatItem(
            value: stats.formattedDistance,
            label: 'Total Distance',
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
          style: WaypointTypography.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: WaypointColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: WaypointTypography.bodySmall?.copyWith(
            color: WaypointColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: WaypointColors.border,
    );
  }
}

