import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/components/waypoint/unified_waypoint_card.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/core/theme/spacing.dart';

/// A minimalist timeline section with "Ghost Timeline" aesthetic
/// Features a vertical journey line with category nodes
class DayTimelineSection extends StatefulWidget {
  final TimeSlotCategory category;
  final List<RouteWaypoint> waypoints;
  final VoidCallback? onAddWaypoint;
  final Function(RouteWaypoint) onEditWaypoint;
  final Function(RouteWaypoint) onDeleteWaypoint;
  final Function(RouteWaypoint, String?)? onTimeChange;
  final Function(RouteWaypoint, bool)? onBookingChange; // Toggle booking status
  final Function(int, int)? onReorder;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  
  // Selection mode (for trip owner)
  final bool isSelectable;
  final Set<String> selectedWaypointIds;
  final Function(RouteWaypoint, bool)? onToggleSelection;
  final Map<String, bool> waypointBookingStatus; // Map of waypoint ID to booking status
  final bool useActualTime; // Use actualStartTime instead of suggestedStartTime
  
  // View mode configuration
  final bool showActions; // Show edit/delete buttons (builder mode)
  final bool isViewOnly; // Read-only mode (trip participants, plan details)

  const DayTimelineSection({
    super.key,
    required this.category,
    required this.waypoints,
    this.onAddWaypoint,
    required this.onEditWaypoint,
    required this.onDeleteWaypoint,
    this.onTimeChange,
    this.onBookingChange,
    this.onReorder,
    this.isExpanded = true,
    this.onToggleExpanded,
    this.isSelectable = false,
    this.selectedWaypointIds = const {},
    this.onToggleSelection,
    this.waypointBookingStatus = const {},
    this.useActualTime = false,
    this.showActions = true,
    this.isViewOnly = false,
  });

  @override
  State<DayTimelineSection> createState() => _DayTimelineSectionState();
}

class _DayTimelineSectionState extends State<DayTimelineSection> {
  @override
  Widget build(BuildContext context) {
    // Ghost Timeline aesthetic - no container, just clean content
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        if (widget.isExpanded) _buildContent(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final icon = getTimeSlotIcon(widget.category);
    final color = getTimeSlotColor(widget.category);
    final label = getTimeSlotLabel(widget.category);
    final waypointCount = widget.waypoints.length;
    final showTime = shouldShowTimeInput(widget.category);

    return InkWell(
      onTap: widget.onToggleExpanded,
      borderRadius: BorderRadius.circular(8),
      hoverColor: NeutralColors.neutral100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Timeline rail with colored icon node (matching map markers)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Vertical timeline line
                Positioned(
                  left: 19,
                  top: -16,
                  bottom: -16,
                  child: Container(
                    width: 2,
                    color: NeutralColors.neutral200,
                  ),
                ),
                // Colored icon node on the timeline (matches map markers)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Category label and inline time
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: NeutralColors.neutral900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (showTime && widget.waypoints.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _buildInlineTime(context),
                  ],
                ],
              ),
            ),
            
            // Subtle expand/collapse chevron (only on hover)
            if (waypointCount > 0)
              Icon(
                widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: NeutralColors.neutral400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineTime(BuildContext context) {
    final timeText = _getTimeRangeSummary();
    if (timeText.isEmpty) return const SizedBox.shrink();
    
    final isSuggested = !widget.useActualTime && timeText.contains('Suggested');
    final displayTime = timeText.replaceAll('Suggested: ', '');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: 14,
          color: NeutralColors.neutral500,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            displayTime,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: NeutralColors.neutral600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isSuggested) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Suggested time by plan builder',
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: NeutralColors.neutral500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final showTime = shouldShowTimeInput(widget.category);
    
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Waypoints with connecting bracket
          if (widget.waypoints.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: NeutralColors.neutral200,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (widget.onReorder != null)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.waypoints.length,
                      onReorder: (oldIndex, newIndex) {
                        if (widget.onReorder != null) {
                          widget.onReorder!(oldIndex, newIndex);
                        }
                      },
                      itemBuilder: (context, index) {
                        final waypoint = widget.waypoints[index];
                        final isSelected = widget.selectedWaypointIds.contains(waypoint.id);
                      return Padding(
                        key: ValueKey(waypoint.id),
                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showTime && !widget.isViewOnly) _buildWaypointTimeInput(context, waypoint),
                              if (widget.isSelectable && widget.onBookingChange != null && isSelected) 
                                _buildBookingCheckbox(context, waypoint),
                              UnifiedWaypointCard(
                                waypoint: waypoint,
                                showActions: widget.showActions,
                                onEdit: widget.showActions ? () => widget.onEditWaypoint(waypoint) : null,
                                onDelete: widget.showActions ? () => widget.onDeleteWaypoint(waypoint) : null,
                                showDragHandle: false, // Never show drag handle in categories
                                isSelectable: widget.isSelectable,
                                isSelected: isSelected,
                                onSelect: widget.isSelectable && widget.onToggleSelection != null
                                    ? () => widget.onToggleSelection!(waypoint, !isSelected)
                                    : null,
                                isViewOnly: widget.isViewOnly,
                                isCompact: true, // Use compact layout for builder screen
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    ...widget.waypoints.asMap().entries.map((entry) {
                      final waypoint = entry.value;
                      final isSelected = widget.selectedWaypointIds.contains(waypoint.id);
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTime && !widget.isViewOnly) _buildWaypointTimeInput(context, waypoint),
                            if (widget.isSelectable && widget.onBookingChange != null && isSelected) 
                              _buildBookingCheckbox(context, waypoint),
                            UnifiedWaypointCard(
                              waypoint: waypoint,
                              showActions: widget.showActions,
                              onEdit: widget.showActions ? () => widget.onEditWaypoint(waypoint) : null,
                              onDelete: widget.showActions ? () => widget.onDeleteWaypoint(waypoint) : null,
                              showDragHandle: false,
                              isSelectable: widget.isSelectable,
                              isSelected: isSelected,
                              onSelect: widget.isSelectable && widget.onToggleSelection != null
                                  ? () => widget.onToggleSelection!(waypoint, !isSelected)
                                  : null,
                              isViewOnly: widget.isViewOnly,
                              isCompact: true, // Use compact layout for builder screen
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          
          // Minimalist Add link (only show in builder mode)
          if (widget.showActions && widget.onAddWaypoint != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: widget.onAddWaypoint,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 16,
                      color: BrandColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add waypoint',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.primary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingCheckbox(BuildContext context, RouteWaypoint waypoint) {
    final isBooked = widget.waypointBookingStatus[waypoint.id] ?? false;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (widget.onBookingChange != null) {
            widget.onBookingChange!(waypoint, !isBooked);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isBooked ? Colors.green.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isBooked ? Colors.green.shade300 : NeutralColors.neutral200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBooked ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: isBooked ? Colors.green.shade700 : NeutralColors.neutral500,
              ),
              const SizedBox(width: 8),
              Text(
                isBooked ? 'Booked' : 'Not booked',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isBooked ? Colors.green.shade700 : NeutralColors.neutral600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointTimeInput(BuildContext context, RouteWaypoint waypoint) {
    // Use actualStartTime for trip owners, suggestedStartTime for plan builders
    final timeValue = widget.useActualTime ? waypoint.actualStartTime : waypoint.suggestedStartTime;
    final hasTime = timeValue != null;
    final displayTime = hasTime 
        ? timeValue 
        : getDefaultSuggestedTime(widget.category) ?? 'Set time';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showTimePicker(context, waypoint),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hasTime ? NeutralColors.neutral50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasTime ? NeutralColors.neutral200 : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: hasTime ? NeutralColors.neutral700 : NeutralColors.neutral400,
              ),
              const SizedBox(width: 6),
              Text(
                displayTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasTime ? NeutralColors.neutral900 : NeutralColors.neutral500,
                ),
              ),
              if (hasTime) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (widget.onTimeChange != null) {
                      widget.onTimeChange!(waypoint, null);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: NeutralColors.neutral500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTimePicker(BuildContext context, RouteWaypoint waypoint) async {
    // Use actualStartTime for trip owners, suggestedStartTime for plan builders
    final currentTimeValue = widget.useActualTime ? waypoint.actualStartTime : waypoint.suggestedStartTime;
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(currentTimeValue) ?? 
                   _parseTime(getDefaultSuggestedTime(widget.category)) ??
                   const TimeOfDay(hour: 12, minute: 0),
    );
    
    if (picked != null && widget.onTimeChange != null) {
      final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      widget.onTimeChange!(waypoint, timeString);
    }
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _getTimeRangeSummary() {
    if (widget.waypoints.isEmpty) return '';
    
    // Use actualStartTime for trip owners, suggestedStartTime for plan builders
    final times = widget.waypoints
        .where((w) => widget.useActualTime ? w.actualStartTime != null : w.suggestedStartTime != null)
        .map((w) => widget.useActualTime ? w.actualStartTime! : w.suggestedStartTime!)
        .toList();
    
    // Don't show default time if no waypoints have time set
    if (times.isEmpty) return '';
    
    final label = widget.useActualTime ? '' : 'Suggested: ';
    
    if (times.length == 1) {
      return '$label${times.first}';
    }
    
    times.sort();
    return '$label${times.first} - ${times.last}';
  }
}
