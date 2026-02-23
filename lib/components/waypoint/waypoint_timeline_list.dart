import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_card.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';

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
        // Timeline with waypoint cards
        ...visibleWaypoints.asMap().entries.map((entry) {
          final index = entry.key;
          final waypoint = entry.value;
          final isLast = index == visibleWaypoints.length - 1 && hiddenCount == 0;
          
          return _buildTimelineItem(
            waypoint: waypoint,
            order: waypoint.order,
            isLast: isLast,
            showConnectingLine: !isLast || (shouldCollapse && !_showAll && hiddenCount > 0),
          );
        }).toList(),

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
    final config = _getCategoryConfig(waypoint.type);
    
    // IntrinsicHeight wraps the Row so both children measure naturally
    // This gives the Row a finite height from its tallest child (WaypointTimelineCard),
    // allowing Expanded in the Column to work properly inside SingleChildScrollView
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column (circle + connecting line)
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Numbered circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: config.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: config.color.withValues(alpha: 0.27),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$order',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ),
                ),
                
                // Connecting line — fills remaining height via Expanded inside IntrinsicHeight Row
                if (showConnectingLine)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CustomPaint(
                          painter: DashedLinePainter(
                            color: const Color(0xFFD1D5DB),
                            dashHeight: 5,
                            dashSpace: 5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Waypoint card — drives the row height
          Expanded(
            child: WaypointTimelineCard(
              waypoint: waypoint,
              order: order,
              isBuilder: widget.isBuilder,
              onTap: widget.onWaypointTap != null
                  ? () => widget.onWaypointTap!(waypoint)
                  : null,
              onGetDirections: widget.onGetDirections != null
                  ? () => widget.onGetDirections!(waypoint)
                  : null,
              onMoveUp: widget.onMoveUp != null
                  ? () => widget.onMoveUp!(waypoint)
                  : null,
              onMoveDown: widget.onMoveDown != null
                  ? () => widget.onMoveDown!(waypoint)
                  : null,
              onEdit: widget.onEdit != null
                  ? () => widget.onEdit!(waypoint)
                  : null,
              onDelete: widget.onDelete != null
                  ? () => widget.onDelete!(waypoint)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineContinuation() {
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 4),
      child: SizedBox(
        width: 2,
        height: 20,
        child: CustomPaint(
          painter: DashedLinePainter(
            color: const Color(0xFFD1D5DB),
            dashHeight: 5,
            dashSpace: 5,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, top: 4),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _showAll ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _showAll
                      ? 'Show less'
                      : 'See $hiddenCount more stop${hiddenCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                    fontFamily: 'DM Sans',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.not_listed_location,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No waypoints',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  CategoryConfig _getCategoryConfig(WaypointType type) {
    return getCategoryConfig(type);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
