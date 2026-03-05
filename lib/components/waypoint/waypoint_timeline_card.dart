import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';

/// Reusable waypoint card for timeline-style lists
/// Used in builder screen, route builder screen, plan detail page, and trip detail page
class WaypointTimelineCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int order; // Order number for the timeline circle
  
  // Mode flags
  final bool isBuilder; // Builder mode shows reorder controls, user mode shows directions
  
  // Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onGetDirections;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  const WaypointTimelineCard({
    super.key,
    required this.waypoint,
    required this.order,
    this.isBuilder = false,
    this.onTap,
    this.onGetDirections,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getCategoryConfig(waypoint.type);
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Material(
          elevation: 1,
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color bar (4px)
              Container(width: 4, color: config.color),
              // Thumbnail image 100×90, right-only radius
              _buildThumbnail(config),
              // Main content — 12px padding
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Name — titleSmall, w600
                      Text(
                        waypoint.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1D21),
                          height: 1.3,
                        ) ?? const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D21),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Address — bodySmall grey
                      if (waypoint.address != null)
                        Text(
                          waypoint.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8B9099),
                            height: 1.3,
                          ) ?? const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B9099),
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // Rating and category on one row: ⭐ 4.5  |  • Cafe
                      _buildRatingAndCategoryRow(config, theme),
                    ],
                  ),
                ),
              ),
              _buildActionsColumn(config),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingAndCategoryRow(CategoryConfig config, ThemeData theme) {
    final hasRating = waypoint.rating != null;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: const Color(0xFF8B9099),
      height: 1.3,
    ) ?? const TextStyle(fontSize: 12, color: Color(0xFF8B9099), height: 1.3);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRating) ...[
            Text(
              '⭐',
              style: labelStyle?.copyWith(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Text(
              waypoint.rating!.toStringAsFixed(1),
              style: labelStyle?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
              ),
            ),
          ],
          if (hasRating) const SizedBox(width: 6),
          if (hasRating) Text('|', style: labelStyle),
          if (hasRating) const SizedBox(width: 6),
          // 6px colored dot + category label
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(config.label, style: labelStyle),
        ],
      ),
    );
  }

  Widget _buildThumbnail(CategoryConfig config) {
    final imageUrl = waypoint.photoUrls?.isNotEmpty == true
        ? waypoint.photoUrls!.first
        : (waypoint.photoUrl ?? waypoint.linkImageUrl);
    const double width = 100;
    const double height = 90;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: config.color.withValues(alpha: 0.15),
                  child: Icon(config.icon, size: 26, color: config.color),
                ),
                errorWidget: (context, url, error) => Container(
                  color: config.color.withValues(alpha: 0.15),
                  child: Icon(config.icon, size: 26, color: config.color),
                ),
              ),
            )
          : Center(
              child: Icon(config.icon, size: 26, color: config.color),
            ),
    );
  }

  Widget _buildActionsColumn(CategoryConfig config) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBuilder) ...[
            // Reorder controls
            if (onMoveUp != null)
              _buildActionButton(
                icon: Icons.keyboard_arrow_up,
                onTap: onMoveUp,
                config: config,
              ),
            if (onMoveUp != null && onMoveDown != null)
              const SizedBox(height: 4),
            if (onMoveDown != null)
              _buildActionButton(
                icon: Icons.keyboard_arrow_down,
                onTap: onMoveDown,
                config: config,
              ),
            // Three-dot menu
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF666666)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) {
                    onEdit!();
                  } else if (value == 'delete' && onDelete != null) {
                    onDelete!();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ] else ...[
            // Directions button in user mode
            if (onGetDirections != null)
              _buildDirectionsButton(config),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required CategoryConfig config,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(
            icon,
            size: 13,
            color: const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsButton(CategoryConfig config) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onGetDirections,
          borderRadius: BorderRadius.circular(19),
          child: Icon(
            Icons.arrow_forward,
            size: 18,
            color: config.color,
          ),
        ),
      ),
    );
  }

  CategoryConfig _getCategoryConfig(WaypointType type) {
    return getCategoryConfig(type);
  }
}

