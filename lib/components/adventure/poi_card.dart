import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart' show getWaypointIcon, getWaypointColor, WaypointType;
import 'package:url_launcher/url_launcher.dart';

/// POI card component - vertical design with image on top
/// Used for Stay/Eat/Do/Move sections in adventure detail screen
class PoiCard extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final String type;          // 'accommodation', 'restaurant', 'activity', 'logistics'
  final String? address;
  final String? url;
  final String? cost;
  final double? rating;
  final String? mealType;     // for restaurants: breakfast/lunch/dinner
  final String? duration;     // for activities
  final bool isEditable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PoiCard({
    super.key,
    required this.name,
    required this.type,
    this.imageUrl,
    this.address,
    this.url,
    this.cost,
    this.rating,
    this.mealType,
    this.duration,
    this.isEditable = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<PoiCard> createState() => _PoiCardState();
}

class _PoiCardState extends State<PoiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(widget.type);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? typeColor.withValues(alpha: 0.3)
                : const Color(0xFFE9ECEF),
            width: 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- IMAGE TOP (160px tall) ----
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  widget.imageUrl != null
                      ? Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(typeColor),
                        )
                      : _imageFallback(typeColor),

                  // Type badge (top-left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _typeIcon(widget.type),
                            size: 12,
                            color: typeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.mealType?.toUpperCase() ??
                                _typeLabel(widget.type),
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Cost badge (top-right) if available
                  if (widget.cost?.isNotEmpty == true)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.cost!,
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Edit/delete controls overlay (builder only)
                  if (widget.isEditable)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        children: [
                          _overlayIconBtn(
                              Icons.edit_outlined, widget.onEdit),
                          const SizedBox(width: 4),
                          _overlayIconBtn(
                              Icons.delete_outline, widget.onDelete,
                              color: const Color(0xFFD62828)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ---- INFO BELOW ----
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212529),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Rating row
                  if (widget.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFCBF49)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.rating!.toStringAsFixed(1)} · Google',
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF495057),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Address
                  if (widget.address?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: Color(0xFF6C757D)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.address!,
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: Color(0xFF6C757D),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Duration (activities)
                  if (widget.duration?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined,
                            size: 13, color: Color(0xFF6C757D)),
                        const SizedBox(width: 3),
                        Text(
                          widget.duration!,
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // URL link
                  if (widget.url?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(widget.url!)),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new_rounded,
                              size: 13, color: Color(0xFF1B4332)),
                          const SizedBox(width: 4),
                          Text(
                            'View details',
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B4332),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF1B4332),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback(Color typeColor) => Container(
    color: typeColor.withValues(alpha: 0.08),
    child: Center(
      child: Icon(
        _typeIcon(widget.type),
        size: 40,
        color: typeColor.withValues(alpha: 0.5),
      ),
    ),
  );

  Widget _overlayIconBtn(IconData icon, VoidCallback? onTap,
      {Color color = Colors.white}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      );

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accommodation': return Icons.hotel_outlined;
      case 'restaurant': return Icons.restaurant_outlined;
      case 'activity': return Icons.local_activity_outlined;
      case 'logistics': return Icons.directions_car_outlined;
      default: return Icons.place_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'accommodation': return 'STAY';
      case 'restaurant': return 'EAT';
      case 'activity': return 'DO';
      case 'logistics': return 'MOVE';
      default: return type.toUpperCase();
    }
  }

  Color _getTypeColor(String type) {
    // Map string type to WaypointType enum for color lookup
    WaypointType waypointType;
    switch (type.toLowerCase()) {
      case 'accommodation':
        waypointType = WaypointType.accommodation;
        break;
      case 'restaurant':
        waypointType = WaypointType.restaurant;
        break;
      case 'activity':
        waypointType = WaypointType.attraction;
        break;
      case 'logistics':
        waypointType = WaypointType.service;
        break;
      default:
        waypointType = WaypointType.attraction;
    }
    return getWaypointColor(waypointType);
  }
}
