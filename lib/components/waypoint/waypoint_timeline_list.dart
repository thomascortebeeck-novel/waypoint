import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart' show RouteWaypoint;
import 'package:waypoint/components/waypoint/waypoint_timeline_card.dart';
import 'package:waypoint/components/waypoint/waypoint_itinerary_card.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_badge.dart';

/// Single timeline row: order circle + connector + [WaypointTimelineCard].
/// Used by [WaypointTimelineList] and by itinerary waypoint list in adventure detail.
const double kTimelineColumnWidth = 44.0;
const double kTimelineConnectorLineWidth = 2.0;
/// Left offset for the 2px connector line so it is centered in the timeline column.
const double kTimelineConnectorLeft = kTimelineColumnWidth / 2 - kTimelineConnectorLineWidth / 2;

class WaypointTimelineItem extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int order;
  final bool showConnectingLine;
  final bool isBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onGetDirections;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  /// Use Stippl-style itinerary card (time row, Show more). When true, [canEditTime] and [onTimeChanged] apply.
  final bool useItineraryCard;
  final bool canEditTime;
  final void Function(String?)? onTimeChanged;
  final String? timeOverride;
  /// Opens add-alternative flow (builder, primaries). Passed to [WaypointItineraryCard].
  final VoidCallback? onAddAlternative;
  /// Removes alternative relationship (builder, alternatives). Passed to [WaypointItineraryCard].
  final VoidCallback? onRemoveAlternative;
  /// Trip owner pickOne: this option is selected.
  final bool isSelectedInPickOne;
  /// Trip owner pickOne: tap to select this option.
  final VoidCallback? onSelectInPickOne;
  /// Trip owner addOn: this alternative is disabled.
  final bool isAddOnDisabled;
  /// Trip owner addOn: toggle disabled.
  final VoidCallback? onToggleAddOn;
  /// Trip owner: promote this alternative to standalone.
  final VoidCallback? onPromoteToStandalone;
  /// Trip owner: this waypoint is promoted (show transport hint).
  final bool isPromoted;

  const WaypointTimelineItem({
    super.key,
    required this.waypoint,
    required this.order,
    this.showConnectingLine = false,
    this.isBuilder = false,
    this.onTap,
    this.onGetDirections,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
    this.useItineraryCard = false,
    this.canEditTime = false,
    this.onTimeChanged,
    this.timeOverride,
    this.onAddAlternative,
    this.onRemoveAlternative,
    this.isSelectedInPickOne = false,
    this.onSelectInPickOne,
    this.isAddOnDisabled = false,
    this.onToggleAddOn,
    this.onPromoteToStandalone,
    this.isPromoted = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = getCategoryConfig(waypoint.type);
    final circleColor = config.color;
    final theme = Theme.of(context);
    final connectorColor = const Color(0xFFD2B48C);

    return IntrinsicHeight(
      key: ValueKey(waypoint.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kTimelineColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                WaypointPinBadge(
                  orderIndex: order,
                  color: circleColor,
                ),
                if (showConnectingLine)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: DashedLinePainter(color: connectorColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: useItineraryCard
                ? WaypointItineraryCard(
                    waypoint: waypoint,
                    order: order,
                    isBuilder: isBuilder,
                    canEditTime: canEditTime,
                    timeOverride: timeOverride,
                    onTap: onTap,
                    onGetDirections: onGetDirections,
                    onTimeChanged: onTimeChanged,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onAddAlternative: onAddAlternative,
                    onRemoveAlternative: onRemoveAlternative,
                    isSelectedInPickOne: isSelectedInPickOne,
                    onSelectInPickOne: onSelectInPickOne,
                    isAddOnDisabled: isAddOnDisabled,
                    onToggleAddOn: onToggleAddOn,
                    onPromoteToStandalone: onPromoteToStandalone,
                    isPromoted: isPromoted,
                  )
                : WaypointTimelineCard(
                    waypoint: waypoint,
                    order: order,
                    isBuilder: isBuilder,
                    onTap: onTap,
                    onGetDirections: onGetDirections,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Timeline-style waypoint list component
/// Displays waypoints in a connected timeline with numbered circles
/// Used in builder screen, route builder screen, plan detail page, and trip detail page
class WaypointTimelineList extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final bool isBuilder; // Builder mode shows reorder controls, user mode shows directions
  
  // Callbacks
  final void Function(RouteWaypoint)? onWaypointTap;
  final void Function(RouteWaypoint)? onGetDirections;
  final void Function(RouteWaypoint)? onMoveUp;
  final void Function(RouteWaypoint)? onMoveDown;
  final void Function(RouteWaypoint)? onEdit;
  final void Function(RouteWaypoint)? onDelete;
  
  // Collapse settings
  final int collapseThreshold; // Number of waypoints to show before collapsing (default: 4)
  final bool enableCollapse; // Whether to enable collapse functionality
  
  const WaypointTimelineList({
    super.key,
    required this.waypoints,
    this.isBuilder = false,
    this.onWaypointTap,
    this.onGetDirections,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
    this.collapseThreshold = 4,
    this.enableCollapse = true,
  });

  @override
  State<WaypointTimelineList> createState() => _WaypointTimelineListState();
}

class _WaypointTimelineListState extends State<WaypointTimelineList> {
  bool _showAll = false;

  /// Left padding so the 2px continuation line is centered under the circle.
  static const double _kLineContinuationLeft = kTimelineColumnWidth / 2 - 1;

  @override
  Widget build(BuildContext context) {
    if (widget.waypoints.isEmpty) {
      return _buildEmptyState();
    }

    // Sort waypoints by order
    final sortedWaypoints = List<RouteWaypoint>.from(widget.waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Determine visible waypoints
    final shouldCollapse = widget.enableCollapse && 
                          sortedWaypoints.length > widget.collapseThreshold;
    final visibleWaypoints = shouldCollapse && !_showAll
        ? sortedWaypoints.take(widget.collapseThreshold).toList()
        : sortedWaypoints;
    
    final hiddenCount = sortedWaypoints.length - visibleWaypoints.length;

    // NOTE: AnimatedSize removed to prevent layout crashes inside TabBarView.
    // AnimatedSize calls markNeedsLayout() during layout, which triggers
    // !_debugDoingThisLayout assertion in SliverFillViewport contexts.
    // The collapse toggle still has AnimatedRotation (safe - transform only).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timeline with waypoint cards (8px gap between items per plan)
        ...visibleWaypoints.asMap().entries.expand((entry) {
          final index = entry.key;
          final waypoint = entry.value;
          final isLast = index == visibleWaypoints.length - 1 && hiddenCount == 0;
          return [
            if (index > 0) const SizedBox(height: 8),
            _buildTimelineItem(
              waypoint: waypoint,
              order: waypoint.order,
              isLast: isLast,
              showConnectingLine: !isLast || (shouldCollapse && !_showAll && hiddenCount > 0),
            ),
          ];
        }),

        // Collapsed line continuation hint
        if (shouldCollapse && !_showAll && hiddenCount > 0)
          _buildLineContinuation(),

        // "See more" / "Show less" button
        if (shouldCollapse && hiddenCount > 0)
          _buildCollapseButton(hiddenCount),
      ],
    );
  }

  Widget _buildTimelineItem({
    required RouteWaypoint waypoint,
    required int order,
    required bool isLast,
    required bool showConnectingLine,
  }) {
    return WaypointTimelineItem(
      key: ValueKey(waypoint.id),
      waypoint: waypoint,
      order: order,
      showConnectingLine: showConnectingLine,
      isBuilder: widget.isBuilder,
      onTap: widget.onWaypointTap != null ? () => widget.onWaypointTap!(waypoint) : null,
      onGetDirections: widget.onGetDirections != null ? () => widget.onGetDirections!(waypoint) : null,
      onMoveUp: widget.onMoveUp != null ? () => widget.onMoveUp!(waypoint) : null,
      onMoveDown: widget.onMoveDown != null ? () => widget.onMoveDown!(waypoint) : null,
      onEdit: widget.onEdit != null ? () => widget.onEdit!(waypoint) : null,
      onDelete: widget.onDelete != null ? () => widget.onDelete!(waypoint) : null,
    );
  }

  Widget _buildLineContinuation() {
    const connectorColor = Color(0xFFD2B48C);
    return Padding(
      padding: const EdgeInsets.only(left: _kLineContinuationLeft, bottom: 4),
      child: SizedBox(
        width: 2,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: connectorColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  /// Called only when [hiddenCount] > 0 (guarded at callsite).
  Widget _buildCollapseButton(int hiddenCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: kTimelineColumnWidth + 12, top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _showAll = !_showAll;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _showAll ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _showAll
                      ? 'Show less'
                      : 'See $hiddenCount more stop${hiddenCount > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.not_listed_location,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No waypoints',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for dashed lines
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashHeight = 5,
    this.dashSpace = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, (startY + dashHeight).clamp(0, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashHeight != dashHeight ||
      oldDelegate.dashSpace != dashSpace;
}
