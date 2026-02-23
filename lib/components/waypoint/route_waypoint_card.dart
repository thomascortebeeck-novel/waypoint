import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart' show RouteWaypoint, WaypointType, getWaypointIcon, getWaypointColor;

/// Route waypoint card component for route sections
/// Horizontal layout with order badge, larger image, and reorder controls
class RouteWaypointCard extends StatefulWidget {
  final RouteWaypoint waypoint;
  final int orderIndex;
  final bool isEditable;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const RouteWaypointCard({
    super.key,
    required this.waypoint,
    required this.orderIndex,
    this.isEditable = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
    this.onTap,
  });

  @override
  State<RouteWaypointCard> createState() => _RouteWaypointCardState();
}

class _RouteWaypointCardState extends State<RouteWaypointCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = getWaypointColor(widget.waypoint.type);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? typeColor.withValues(alpha: 0.4) : const Color(0xFFE9ECEF),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // ---- Order badge ----
              Container(
                width: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.orderIndex}',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _labelColor(typeColor),
                      ),
                    ),
                  ),
                ),
              ),

              // ---- Image (larger — 80px) ----
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: widget.waypoint.imageUrl != null
                      ? Image.network(
                          widget.waypoint.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(typeColor),
                        )
                      : _imageFallback(typeColor),
                ),
              ),

              const SizedBox(width: 12),

              // ---- Info ----
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.waypoint.type.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Name
                      Text(
                        widget.waypoint.name,
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212529),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Address
                      if (widget.waypoint.address?.isNotEmpty == true)
                        Text(
                          widget.waypoint.address!,
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Rating
                      if (widget.waypoint.rating != null)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFCBF49)),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.waypoint.rating} Google',
                              style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 12,
                                color: Color(0xFF495057),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Reorder controls (builder only) ----
              if (widget.isEditable)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBtn(Icons.keyboard_arrow_up, widget.onMoveUp),
                    _iconBtn(Icons.keyboard_arrow_down, widget.onMoveDown),
                    _iconBtn(Icons.more_vert, () => _showContextMenu(context)),
                  ],
                ),

              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(Color typeColor) => Container(
    color: typeColor.withValues(alpha: 0.1),
    child: Icon(
      getWaypointIcon(widget.waypoint.type),
      color: typeColor,
      size: 28,
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, size: 18, color: const Color(0xFF6C757D)),
    ),
  );

  Color _labelColor(Color bg) =>
      bg.computeLuminance() > 0.35 ? const Color(0xFF212529) : Colors.white;

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFD62828)),
            title: const Text('Remove waypoint'),
            onTap: () { 
              Navigator.pop(context); 
              widget.onDelete?.call(); 
            },
          ),
        ],
      ),
    );
  }
}

