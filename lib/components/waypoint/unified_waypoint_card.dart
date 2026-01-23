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
  final bool showDragHandle;
  
  // Presentation mode (view-only for trip participants)
  final bool isViewOnly;
  
  // Layout
  final bool isCompact; // Compact layout for selection screens
  final bool showTimeline; // Show timeline connector
  final bool isFirstInDay; // First waypoint in day (no top connector)
  final bool isLastInDay; // Last waypoint in day (no bottom connector)
  
  // Booking/Status (for trip owner view)
  final bool? isBooked;
  final String? bookingReference;
  final bool isRequired; // Required selection vs optional
  final int? optionCount; // Number of options available (e.g., "1 of 3")
  final int? selectedOptionIndex; // Which option is selected
  
  const UnifiedWaypointCard({
    super.key,
    required this.waypoint,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelect,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
    this.showDragHandle = false,
    this.isViewOnly = false,
    this.isCompact = false,
    this.showTimeline = false,
    this.isFirstInDay = false,
    this.isLastInDay = false,
    this.isBooked,
    this.bookingReference,
    this.isRequired = false,
    this.optionCount,
    this.selectedOptionIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  /// Full card with image, used in builder and trip day views
  Widget _buildFullCard(BuildContext context) {
    // Timeline layout wrapper
    if (showTimeline) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          _buildTimelineIndicator(context),
          const SizedBox(width: 12),
          // Card content
          Expanded(child: _buildCardContent(context)),
        ],
      );
    }
    
    return _buildCardContent(context);
  }
  
  /// Build timeline indicator (vertical line with dot)
  Widget _buildTimelineIndicator(BuildContext context) {
    final color = getWaypointColor(waypoint.type);
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          // Top connector line
          if (!isFirstInDay)
            Container(
              width: 2,
              height: 20,
              color: context.colors.outline.withValues(alpha: 0.3),
            ),
          // Dot/Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 2.5,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
              getWaypointIcon(waypoint.type),
              size: 20,
              color: isSelected ? Colors.white : color,
            ),
          ),
          // Bottom connector line
          if (!isLastInDay)
            Expanded(
              child: Container(
                width: 2,
                color: context.colors.outline.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build status header showing required/optional, booking status, selection count
  Widget _buildStatusHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isRequired 
            ? Colors.amber.shade50 
            : isBooked == true
                ? Colors.green.shade50
                : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: context.colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Required indicator
          if (isRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber.shade800),
                  const SizedBox(width: 5),
                  Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          
          // Option count (e.g., "Choose 1 of 3 options")
          if (optionCount != null) ...[
            if (isRequired) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                selectedOptionIndex != null
                    ? 'Option ${selectedOptionIndex! + 1} of $optionCount'
                    : 'Choose 1 of $optionCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
          ],
          
          const Spacer(),
          
          // Booking status
          if (isBooked != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isBooked! ? Colors.green.shade100 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isBooked! ? Colors.green.shade300 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBooked! ? Icons.check_circle : Icons.schedule,
                    size: 14,
                    color: isBooked! ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isBooked! ? 'Booked' : 'Not booked',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isBooked! ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  if (bookingReference != null && isBooked!) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• $bookingReference',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build discrete action icons (edit/delete) - AllTrails style
  Widget _buildDiscreteActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: Colors.grey.shade400,
            ),
            tooltip: 'Edit',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(
              foregroundColor: context.colors.primary,
              hoverColor: context.colors.primary.withValues(alpha: 0.1),
            ),
          ),
        if (onDelete != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.grey.shade400,
            ),
            tooltip: 'Remove',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              hoverColor: Colors.red.shade50,
            ),
          ),
        ],
      ],
    );
  }
  
  /// Build category badge - AllTrails style pill badge
  Widget _buildCategoryBadge(BuildContext context) {
    final color = getWaypointColor(waypoint.type);
    final label = getWaypointLabel(waypoint.type).toUpperCase();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  /// Build card content (image + details) - AllTrails inspired horizontal layout
  Widget _buildCardContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelectable && isSelected
              ? context.colors.primary
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status header (required, booking status, etc.)
          if (isRequired || isBooked != null || optionCount != null)
            _buildStatusHeader(context),
          
          InkWell(
            onTap: isSelectable ? onSelect : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square 1:1 image on the left - clickable to open website
                  GestureDetector(
                    onTap: waypoint.website != null ? () => _launchUrl(waypoint.website!) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: _buildImage(context),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Content in the center
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category badge
                        _buildCategoryBadge(context),
                        
                        const SizedBox(height: 8),
                        
                        // Title - clickable to open website
                        GestureDetector(
                          onTap: waypoint.website != null ? () => _launchUrl(waypoint.website!) : null,
                          child: Text(
                            waypoint.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Rating and Address in one line
                        Row(
                          children: [
                            if (waypoint.rating != null) ...[
                              Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                              const SizedBox(width: 4),
                              Text(
                                waypoint.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (waypoint.address != null) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '\u2022',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                            if (waypoint.address != null)
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        waypoint.address!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action icons on the right (discrete)
                  if (showActions && !isViewOnly)
                    _buildDiscreteActions(context),
                  
                  // Selection indicator
                  if (isSelectable)
                    _buildSelectionIndicator(context),
                  
                  // Drag handle
                  if (showDragHandle && showActions) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.drag_indicator, color: Colors.grey.shade400, size: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact card without image, used in selection screens
  Widget _buildCompactCard(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            // Thumbnail image
            if (waypoint.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CachedNetworkImage(
                    imageUrl: waypoint.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholderImage(context),
                    errorWidget: (context, url, error) => _buildPlaceholderImage(context),
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: getWaypointColor(waypoint.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getWaypointIcon(waypoint.type),
                  color: getWaypointColor(waypoint.type),
                  size: 28,
                ),
              ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Type badges and rating
                  Row(
                    children: [
                      Flexible(child: _buildTypeBadges(context)),
                      if (waypoint.rating != null) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                            const SizedBox(width: 2),
                            Text(
                              waypoint.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Link icon if website available
            if (waypoint.website != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.link, size: 18, color: context.colors.onSurfaceVariant),
              ),
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
          size: 40,
          color: getWaypointColor(waypoint.type).withValues(alpha: 0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: getWaypointColor(waypoint.type).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: getWaypointColor(waypoint.type).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getWaypointIcon(waypoint.type),
                size: 14,
                color: getWaypointColor(waypoint.type),
              ),
              const SizedBox(width: 5),
              Text(
                getWaypointLabel(waypoint.type),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: getWaypointColor(waypoint.type),
                ),
              ),
            ],
          ),
        ),
        
        // Meal time tag (for restaurants)
        if (waypoint.mealTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        
        // Activity time tag (for activities)
        if (waypoint.activityTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.w700,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Build rating display
  Widget _buildRating(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            i < waypoint.rating!.round() ? Icons.star : Icons.star_border,
            color: Colors.amber.shade600,
            size: 15,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          waypoint.rating!.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            waypoint.address!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build selection indicator (circle or checkbox)
  Widget _buildSelectionIndicator(BuildContext context) {
    // For activities, use checkbox; for others, use radio button
    if (waypoint.type == WaypointType.activity) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
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
    } else {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.outline,
            width: 2.5,
          ),
          color: isSelected ? context.colors.primary : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(Icons.circle, size: 12, color: Colors.white)
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
