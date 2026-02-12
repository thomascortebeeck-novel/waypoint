import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/travel_calculator_service.dart';
import 'package:waypoint/theme.dart';

/// Timeline itinerary widget displaying waypoints in a vertical timeline
/// Matches the design with numbered circles, cards, and travel segments
class TimelineItineraryWidget extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final int? dayNumber; // Day number for color coding (1 = red, 2 = teal, 3 = yellow)
  final bool isBuilderView; // Builder can edit, users can only view
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;
  final Function(RouteWaypoint, String)? onChoiceSelected; // For choice groups

  const TimelineItineraryWidget({
    super.key,
    required this.waypoints,
    this.dayNumber,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
    this.onChoiceSelected,
  });

  @override
  State<TimelineItineraryWidget> createState() => _TimelineItineraryWidgetState();
}

class _TimelineItineraryWidgetState extends State<TimelineItineraryWidget> {
  // Track selected waypoint per choice group
  final Map<String, String> _selectedWaypointIds = {}; // choiceGroupId -> waypointId

  @override
  Widget build(BuildContext context) {
    if (widget.waypoints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No waypoints in itinerary',
                style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Group waypoints by choice groups
    final groupedWaypoints = _groupWaypointsByChoice(widget.waypoints);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedWaypoints.length,
      itemBuilder: (context, index) {
        final group = groupedWaypoints[index];
        final isLast = index == groupedWaypoints.length - 1;
        
        return Column(
          children: [
            // Waypoint card(s)
            if (group.isChoiceGroup)
              _ChoiceGroupCard(
                waypoints: group.waypoints,
                order: group.order,
                dayNumber: widget.dayNumber,
                isBuilderView: widget.isBuilderView,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                onChoiceSelected: (waypoint, groupId) {
                  setState(() {
                    _selectedWaypointIds[groupId] = waypoint.id;
                  });
                  widget.onChoiceSelected?.call(waypoint, groupId);
                },
                selectedWaypointId: group.waypoints.first.choiceGroupId != null
                    ? _selectedWaypointIds[group.waypoints.first.choiceGroupId!]
                    : null,
              )
            else
              _TimelineWaypointCard(
                waypoint: group.waypoints.first,
                order: group.order,
                dayNumber: widget.dayNumber,
                isBuilderView: widget.isBuilderView,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
            
            // Travel segment (if not last)
            if (!isLast && group.waypoints.isNotEmpty)
              _TravelSegment(
                from: group.isChoiceGroup && group.waypoints.first.choiceGroupId != null
                    ? group.waypoints.firstWhere(
                        (w) => w.id == _selectedWaypointIds[group.waypoints.first.choiceGroupId!],
                        orElse: () => group.waypoints.first,
                      )
                    : group.waypoints.first,
                to: groupedWaypoints[index + 1].waypoints.first,
              ),
          ],
        );
      },
    );
  }

  /// Group waypoints by choice groups and order
  List<_WaypointGroup> _groupWaypointsByChoice(List<RouteWaypoint> waypoints) {
    final groups = <_WaypointGroup>[];
    final processed = <String>{};

    for (final wp in waypoints) {
      if (processed.contains(wp.id)) continue;

      if (wp.choiceGroupId != null) {
        // Find all waypoints in this choice group
        final choiceGroup = waypoints
            .where((w) => w.choiceGroupId == wp.choiceGroupId)
            .toList();
        groups.add(_WaypointGroup(
          order: wp.order,
          isChoiceGroup: true,
          waypoints: choiceGroup,
        ));
        processed.addAll(choiceGroup.map((w) => w.id));
      } else {
        groups.add(_WaypointGroup(
          order: wp.order,
          isChoiceGroup: false,
          waypoints: [wp],
        ));
        processed.add(wp.id);
      }
    }

    // Sort by order
    groups.sort((a, b) => a.order.compareTo(b.order));
    return groups;
  }
}

/// Internal class to represent a group of waypoints (single or choice group)
class _WaypointGroup {
  final int order;
  final bool isChoiceGroup;
  final List<RouteWaypoint> waypoints;

  _WaypointGroup({
    required this.order,
    required this.isChoiceGroup,
    required this.waypoints,
  });
}

/// Timeline waypoint card with numbered circle and content
class _TimelineWaypointCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int order;
  final int? dayNumber;
  final bool isBuilderView;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;

  const _TimelineWaypointCard({
    required this.waypoint,
    required this.order,
    this.dayNumber,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dayColor = _getDayColor(dayNumber ?? 1);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator with number
        _TimelineIndicator(
          order: order,
          color: dayColor,
        ),
        const SizedBox(width: 16),
        // Card content
        Expanded(
          child: _WaypointCardContent(
            waypoint: waypoint,
            isBuilderView: isBuilderView,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }

  Color _getDayColor(int day) {
    switch (day) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.teal;
      case 3:
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }
}

/// Timeline indicator with numbered circle
class _TimelineIndicator extends StatelessWidget {
  final int order;
  final Color color;

  const _TimelineIndicator({
    required this.order,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$order',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Waypoint card content with image and details
class _WaypointCardContent extends StatefulWidget {
  final RouteWaypoint waypoint;
  final bool isBuilderView;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;

  const _WaypointCardContent({
    required this.waypoint,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_WaypointCardContent> createState() => _WaypointCardContentState();
}

class _WaypointCardContentState extends State<_WaypointCardContent> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and content row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (128px)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 128,
                    height: 128,
                    child: _buildImage(),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time
                      if (widget.waypoint.suggestedStartTime != null)
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              widget.waypoint.suggestedStartTime!,
                              style: context.textStyles.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // Name
                      Text(
                        widget.waypoint.name,
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Location/Address
                      if (widget.waypoint.address != null)
                        Row(
                          children: [
                            Icon(
                              _getLocationIcon(widget.waypoint.type),
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.waypoint.address!,
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // Rating and price
                      if (widget.waypoint.rating != null)
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.waypoint.rating!.toStringAsFixed(1)}',
                              style: context.textStyles.bodySmall,
                            ),
                            if (widget.waypoint.estimatedPriceRange != null) ...[
                              const SizedBox(width: 16),
                              Text(
                                _getPriceRangeString(widget.waypoint.estimatedPriceRange!),
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          // Directions button
                          ElevatedButton.icon(
                            onPressed: () => _openDirections(widget.waypoint),
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Website button
                          if (widget.waypoint.website != null)
                            OutlinedButton.icon(
                              onPressed: () => _launchUrl(widget.waypoint.website!),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Website'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Expandable details
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'More details',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.waypoint.description != null) ...[
                    Text(
                      widget.waypoint.description!,
                      style: context.textStyles.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.waypoint.phoneNumber != null) ...[
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          widget.waypoint.phoneNumber!,
                          style: context.textStyles.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.isBuilderView) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => widget.onEdit?.call(widget.waypoint),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => widget.onDelete?.call(widget.waypoint),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (widget.waypoint.photoUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.waypoint.photoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: getWaypointColor(widget.waypoint.type).withValues(alpha: 0.1),
      child: Icon(
        getWaypointIcon(widget.waypoint.type),
        size: 48,
        color: getWaypointColor(widget.waypoint.type),
      ),
    );
  }

  IconData _getLocationIcon(WaypointType type) {
    switch (type) {
      case WaypointType.restaurant:
        return Icons.restaurant;
      case WaypointType.accommodation:
        return Icons.hotel;
      case WaypointType.attraction:
      case WaypointType.activity:
        return Icons.local_activity;
      case WaypointType.bar:
        return Icons.local_bar;
      default:
        return Icons.location_on;
    }
  }

  String _getPriceRangeString(PriceRange priceRange) {
    // Use average price to determine price level
    // Standard ranges: $ = <€30, $$ = €30-60, $$$ = €60-120, $$$$ = >€120
    final avgPrice = (priceRange.min + priceRange.max) / 2;
    if (avgPrice < 30) {
      return '\$';
    } else if (avgPrice < 60) {
      return '\$\$';
    } else if (avgPrice < 120) {
      return '\$\$\$';
    } else {
      return '\$\$\$\$';
    }
  }

  Future<void> _openDirections(RouteWaypoint waypoint) async {
    final lat = waypoint.position.latitude;
    final lng = waypoint.position.longitude;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Travel segment between waypoints
class _TravelSegment extends StatelessWidget {
  final RouteWaypoint from;
  final RouteWaypoint to;

  const _TravelSegment({
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    // Use travel info from 'to' waypoint (calculated from previous)
    final travelMode = to.travelMode;
    final travelTime = to.travelTime;
    
    if (travelMode == null || travelTime == null) {
      return const SizedBox(height: 16);
    }

    final icon = _getTravelIcon(travelMode);
    final color = _getTravelColor(travelMode);
    final duration = _formatDuration(travelTime);

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            duration,
            style: context.textStyles.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTravelIcon(String mode) {
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_transit;
      case 'driving':
        return Icons.directions_car;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.arrow_downward;
    }
  }

  Color _getTravelColor(String mode) {
    switch (mode) {
      case 'walking':
        return Colors.green;
      case 'transit':
      case 'driving':
        return Colors.blue;
      case 'bicycling':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    final mode = to.travelMode ?? 'walking';
    final modeLabel = _getTravelModeLabel(mode);
    
    if (minutes < 60) {
      return '$minutes min $modeLabel';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h $modeLabel';
    }
    return '$hours h $remainingMinutes min $modeLabel';
  }

  String _getTravelModeLabel(String mode) {
    switch (mode) {
      case 'walking':
        return 'walk';
      case 'transit':
        return 'transit';
      case 'driving':
        return 'drive';
      case 'bicycling':
        return 'bike';
      default:
        return '';
    }
  }
}

/// Choice group card for rendering OR options
class _ChoiceGroupCard extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final int order;
  final int? dayNumber;
  final bool isBuilderView;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;
  final Function(RouteWaypoint, String)? onChoiceSelected;
  final String? selectedWaypointId; // Selected waypoint ID for this choice group

  const _ChoiceGroupCard({
    required this.waypoints,
    required this.order,
    this.dayNumber,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
    this.onChoiceSelected,
    this.selectedWaypointId,
  });

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) return const SizedBox.shrink();
    
    final dayColor = _getDayColor(dayNumber ?? 1);
    final choiceLabel = waypoints.first.choiceLabel ?? 'Choose an option';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        _TimelineIndicator(
          order: order,
          color: dayColor,
        ),
        const SizedBox(width: 16),
        // Choice group content
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choiceLabel,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Choice options
                  ...waypoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final waypoint = entry.value;
                    final isSelected = selectedWaypointId == waypoint.id;
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < waypoints.length - 1 ? 12 : 0),
                      child: _ChoiceOption(
                        waypoint: waypoint,
                        isSelected: isSelected,
                        isBuilderView: isBuilderView,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onSelected: onChoiceSelected != null
                            ? () => onChoiceSelected!(waypoint, waypoint.choiceGroupId ?? '')
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getDayColor(int day) {
    switch (day) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.teal;
      case 3:
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }
}

/// Individual choice option within a choice group
class _ChoiceOption extends StatelessWidget {
  final RouteWaypoint waypoint;
  final bool isSelected;
  final bool isBuilderView;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;
  final VoidCallback? onSelected;

  const _ChoiceOption({
    required this.waypoint,
    required this.isSelected,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Radio button
          if (onSelected != null)
            Radio<RouteWaypoint>(
              value: waypoint,
              groupValue: isSelected ? waypoint : null,
              onChanged: (_) => onSelected?.call(),
            )
          else
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
          const SizedBox(width: 12),
          // Waypoint name
          Expanded(
            child: Text(
              waypoint.name,
              style: context.textStyles.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Actions (builder only)
          if (isBuilderView) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => onEdit?.call(waypoint),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: () => onDelete?.call(waypoint),
              tooltip: 'Remove',
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
}

