import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Review score row component
/// 
/// Displays review score with stars, numeric score, count, and label badge.
/// Only shown in viewer mode (not builder formState).

class ReviewScoreRow extends StatelessWidget {
  final double? score; // 0.0 to 5.0
  final int? count; // Number of reviews
  
  const ReviewScoreRow({
    super.key,
    this.score,
    this.count,
  });
  
  @override
  Widget build(BuildContext context) {
    if (score == null || score == 0.0) {
      return const SizedBox.shrink();
    }
    
    final label = _getRatingLabel(score!);
    final labelColor = _getLabelColor(score!);
    final labelBackground = _getLabelBackground(score!);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border.all(color: WaypointColors.border, width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      ),
      child: Row(
        children: [
          // Stars
          Row(
            children: List.generate(5, (index) {
              return Icon(
                Icons.star,
                size: 16.0,
                color: index < score!.floor()
                    ? WaypointColors.gold
                    : WaypointColors.border,
              );
            }),
          ),
          const SizedBox(width: 10.0),
          // Score
          Text(
            score!.toStringAsFixed(1),
            style: WaypointTypography.statValue.copyWith(
              fontSize: 20.0,
            ),
          ),
          // Count
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4.0),
            Text(
              '($count reviews)',
              style: WaypointTypography.bodyMedium.copyWith(
                color: WaypointColors.textTertiary,
              ),
            ),
          ],
          const Spacer(),
          // Label badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: labelBackground,
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Text(
              label,
              style: WaypointTypography.chipLabel.copyWith(
                fontSize: 12.0,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRatingLabel(double score) {
    if (score >= 4.5) return 'Excellent';
    if (score >= 3.5) return 'Good';
    if (score >= 2.5) return 'Average';
    return 'Poor';
  }
  
  Color _getLabelColor(double score) {
    if (score >= 4.5) return WaypointColors.catStay; // Green
    if (score >= 3.5) return WaypointColors.catDo; // Blue
    if (score >= 2.5) return WaypointColors.accent; // Orange/Yellow
    return WaypointColors.textTertiary; // Gray
  }
  
  Color _getLabelBackground(double score) {
    if (score >= 4.5) return WaypointColors.catStaySurface;
    if (score >= 3.5) return WaypointColors.catDoSurface;
    if (score >= 2.5) return WaypointColors.accentLight;
    return WaypointColors.borderLight;
  }
}

