import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';

/// Unified waypoint card component used across the app
/// Supports builder view, selection view, and trip participant view
class UnifiedWaypointCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  
  // Selection mode (for itinerary selection screen)
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onSelect;
  
  // Builder mode (for route builder)
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  // Presentation mode (view-only for trip participants)
  final bool isViewOnly;
  
  // Layout
  final bool isCompact; // Compact layout for selection screens
  
  const UnifiedWaypointCard({
    super.key,
    required this.waypoint,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelect,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
    this.isViewOnly = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    } else {
      return _buildFullCard(context);
    }
  }

  /// Full card with image, used in builder and trip day views
  Widget _buildFullCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelectable && isSelected
            ? BorderSide(color: context.colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectable ? onSelect : (waypoint.website != null ? () => _launchUrl(waypoint.website!) : null),
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image on the left (fixed width, stretches to match content height)
              SizedBox(
                width: 110,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: _buildImage(context),
                ),
              ),
              
              // Content on the right
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row with type badges and actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selection indicator (for selectable mode)
                          if (isSelectable) ...[
                            _buildSelectionIndicator(context),
                            const SizedBox(width: 8),
                          ],
                          // Type badges
                          Expanded(child: _buildTypeBadges(context)),
                          // Action buttons (for builder mode)
                          if (showActions && !isViewOnly) ...[
                            const SizedBox(width: 8),
                            if (onEdit != null)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: onEdit,
                                color: Colors.grey.shade600,
                                tooltip: 'Edit',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (onDelete != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: onDelete,
                                color: Colors.red.shade600,
                                tooltip: 'Delete',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Name
                      Text(
                        waypoint.name,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Description
                      if (waypoint.description != null && waypoint.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          waypoint.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Rating
                      if (waypoint.rating != null) ...[
                        const SizedBox(height: 4),
                        _buildRating(context),
                      ],

                      // Address (condensed)
                      if (waypoint.address != null) ...[
                        const SizedBox(height: 4),
                        _buildAddress(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact card without image, used in selection screens
  Widget _buildCompactCard(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? context.colors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            _buildSelectionIndicator(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    waypoint.name,
                    style: context.textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Type badge
                  _buildTypeBadges(context),
                ],
              ),
            ),
            // Link icon if website available
            if (waypoint.website != null)
              Icon(Icons.link, size: 18, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Build image or placeholder
  Widget _buildImage(BuildContext context) {
    if (waypoint.photoUrl != null) {
      return CachedNetworkImage(
        imageUrl: waypoint.photoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderImage(context),
        errorWidget: (context, url, error) => _buildPlaceholderImage(context),
      );
    } else {
      return _buildPlaceholderImage(context);
    }
  }

  /// Build placeholder image with category icon
  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      color: getWaypointColor(waypoint.type).withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          getWaypointIcon(waypoint.type),
          size: 36,
          color: getWaypointColor(waypoint.type).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  /// Build type badges (category + time tags)
  Widget _buildTypeBadges(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Main type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getWaypointColor(waypoint.type).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getWaypointIcon(waypoint.type),
                size: 14,
                color: getWaypointColor(waypoint.type),
              ),
              const SizedBox(width: 4),
              Text(
                getWaypointLabel(waypoint.type),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: getWaypointColor(waypoint.type),
                ),
              ),
            ],
          ),
        ),
        
        // Meal time tag (for restaurants)
        if (waypoint.mealTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getMealTimeIcon(waypoint.mealTime!),
                  size: 12,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  getMealTimeLabel(waypoint.mealTime!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        
        // Activity time tag (for activities)
        if (waypoint.activityTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getActivityTimeIcon(waypoint.activityTime!),
                  size: 12,
                  color: Colors.purple.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  getActivityTimeLabel(waypoint.activityTime!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Build type-specific info (hotel chain, amenities, etc.)
  List<Widget> _buildTypeSpecificInfo(BuildContext context) {
    final widgets = <Widget>[];
    
    // Hotel chain
    if (waypoint.hotelChain != null) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(
        Text(
          waypoint.hotelChain!,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    // Amenities (for accommodations)
    if (waypoint.amenities != null && waypoint.amenities!.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: waypoint.amenities!.map((amenity) => Chip(
            label: Text(amenity),
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.grey.shade100,
          )).toList(),
        ),
      );
    }
    
    return widgets;
  }

  /// Build rating display
  Widget _buildRating(BuildContext context) {
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            i < waypoint.rating!.round() ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Colors.amber.shade600,
            size: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          waypoint.rating!.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// Build address display
  Widget _buildAddress(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            waypoint.address!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build contact buttons (phone and website)
  Widget _buildContactButtons(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (waypoint.phoneNumber != null)
          OutlinedButton.icon(
            onPressed: () => _launchPhone(waypoint.phoneNumber!),
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (waypoint.website != null)
          OutlinedButton.icon(
            onPressed: () => _launchUrl(waypoint.website!),
            icon: const Icon(Icons.language, size: 16),
            label: const Text('Website'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  /// Build selection indicator (circle or checkbox)
  Widget _buildSelectionIndicator(BuildContext context) {
    // For activities, use checkbox; for others, use radio button
    if (waypoint.type == WaypointType.activity) {
      return Checkbox(
        value: isSelected,
        onChanged: onSelect != null ? (_) => onSelect!() : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.outline,
            width: 2,
          ),
          color: isSelected ? context.colors.primary : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      );
    }
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchUrl(String url) async {
    // Ensure URL has a scheme
    String formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://$url';
    }
    final uri = Uri.parse(formattedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
