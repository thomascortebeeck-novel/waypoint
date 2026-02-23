import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/models/user_model.dart';

/// Creator card component
/// 
/// Displays the adventure creator's profile with avatar, name, and bio.
/// Handles null avatar by showing first letter of name in colored circle.
/// Tappable to navigate to creator profile.

class CreatorCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String? bio; // Optional bio text
  final String? creatorId; // Optional creator ID for navigation
  
  const CreatorCard({
    super.key,
    this.avatarUrl,
    required this.name,
    this.bio,
    this.creatorId,
  });
  
  @override
  Widget build(BuildContext context) {
    final cardContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        _buildAvatar(),
        const SizedBox(width: 14.0),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                'CREATED BY',
                style: WaypointTypography.chipLabel.copyWith(
                  fontSize: 10.0,
                  color: WaypointColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2.0),
              // Name
              Text(
                name,
                style: WaypointTypography.bodyLarge.copyWith(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w700,
                  color: WaypointColors.textPrimary,
                ),
              ),
              // Bio
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                Text(
                  bio!,
                  style: WaypointTypography.bodyMedium.copyWith(
                    color: WaypointColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: WaypointSpacing.cardPaddingInsets,
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border.all(color: WaypointColors.border, width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      ),
      child: creatorId != null
          ? InkWell(
              onTap: () => context.push('/creator/$creatorId'),
              borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
              child: cardContent,
            )
          : cardContent,
    );
  }
  
  Widget _buildAvatar() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 52.0,
          height: 52.0,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialAvatar();
          },
        ),
      );
    }
    return _buildInitialAvatar();
  }
  
  Widget _buildInitialAvatar() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 52.0,
      height: 52.0,
      decoration: BoxDecoration(
        color: WaypointColors.borderLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: WaypointTypography.headlineMedium.copyWith(
            fontSize: 22.0,
            color: WaypointColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

