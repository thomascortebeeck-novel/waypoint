import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/reorder_controls.dart';

/// Reusable sidebar waypoint tile component
/// Displays a waypoint in the sidebar with number badge, reorder controls, and actions
class SidebarWaypointTile extends StatelessWidget {
  final RouteWaypoint waypoint; 
  final VoidCallback onEdit; 
  final VoidCallback? onMoveUp; 
  final VoidCallback? onMoveDown;
  final VoidCallback? onAddAlternative;
  final int? waypointNumber; // Number badge for this waypoint
  final bool showConnectingLine; // Whether to show connecting line below
  final bool isLastInGroup; // Whether this is the last waypoint in its order group

  const SidebarWaypointTile({
    super.key, 
    required this.waypoint, 
    required this.onEdit, 
    this.onMoveUp, 
    this.onMoveDown,
    this.onAddAlternative,
    this.waypointNumber,
    this.showConnectingLine = false,
    this.isLastInGroup = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final waypointColor = getWaypointColor(waypoint.type);
    
    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            // Number badge and icon container
            Stack(
              alignment: Alignment.center,
              children: [
                // Connecting line (vertical line on the left)
                if (waypointNumber != null)
                  Positioned(
                    left: 14,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
                // Number badge circle
                if (waypointNumber != null)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: waypointColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$waypointNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  // Fallback: icon without number
                  Container(
                    width: 28, 
                    height: 28, 
                    decoration: BoxDecoration(
                      color: waypointColor, 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Icon(getWaypointIcon(waypoint.type), color: Colors.white, size: 16)
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    waypoint.name, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontWeight: FontWeight.w600)
                  ),
                  Text(
                    getWaypointLabel(waypoint.type), 
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
                  ),
                ]
              )
            ),
            // Reorder controls for individual waypoints
            if (onMoveUp != null || onMoveDown != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ReorderControlsVertical(
                  canMoveUp: onMoveUp != null,
                  canMoveDown: onMoveDown != null,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'add_alternative' && onAddAlternative != null) {
                  onAddAlternative?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                if (onAddAlternative != null)
                  const PopupMenuItem(
                    value: 'add_alternative',
                    child: Row(children: [
                      Icon(Icons.alt_route, size: 18),
                      SizedBox(width: 8),
                      Text('Add OR alternative'),
                    ]),
                  ),
              ],
            ),
          ]),
        ),
        // Connecting line below waypoint (if not last in group or if showConnectingLine is true)
        if (showConnectingLine && (waypointNumber != null || !isLastInGroup))
          Container(
            width: 2,
            height: 8,
            margin: const EdgeInsets.only(left: 14),
            color: Colors.grey.shade300,
          ),
      ],
    );
  }
}

