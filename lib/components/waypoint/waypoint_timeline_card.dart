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
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EAED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail image
            _buildThumbnail(config),
            
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category chip
                    _buildCategoryChip(config),
                    const SizedBox(height: 3),
                    
                    // Name
                    Text(
                      waypoint.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D21),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    
                    // Address
                    if (waypoint.address != null)
                      Text(
                        waypoint.address!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B9099),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    // Rating
                    if (waypoint.rating != null) ...[
                      const SizedBox(height: 1),
                      _buildRating(waypoint.rating!),
                    ],
                  ],
                ),
              ),
            ),
            
            // Right actions column
            _buildActionsColumn(config),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(CategoryConfig config) {
    final hasImage = waypoint.photoUrl != null || waypoint.linkImageUrl != null;
    final imageUrl = waypoint.photoUrl ?? waypoint.linkImageUrl;
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          bottomLeft: Radius.circular(14),
        ),
        border: Border(
          right: BorderSide(color: const Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: hasImage && imageUrl != null
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: config.color.withValues(alpha: 0.15),
                  child: Icon(
                    config.icon,
                    size: 26,
                    color: config.color,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: config.color.withValues(alpha: 0.15),
                  child: Icon(
                    config.icon,
                    size: 26,
                    color: config.color,
                  ),
                ),
              ),
            )
          : Icon(
              config.icon,
              size: 26,
              color: config.color,
            ),
    );
  }

  Widget _buildCategoryChip(CategoryConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: config.color,
          letterSpacing: 0.05,
        ),
      ),
    );
  }

  Widget _buildRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '⭐',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Google',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFAAAAAA),
          ),
        ),
      ],
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

