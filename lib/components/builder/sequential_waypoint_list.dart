import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/services/waypoint_grouping_service.dart';
import 'package:waypoint/services/travel_calculator_service.dart';
import 'package:waypoint/integrations/google_directions_service.dart';
import 'package:uuid/uuid.dart';

/// Sequential waypoint list with drag-and-drop reordering
/// Replaces category-based organization with simple sequential ordering
class SequentialWaypointList extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final Function(RouteWaypoint) onEdit;
  final Function(RouteWaypoint) onDelete;
  final Function(int, int) onReorder; // (oldIndex, newIndex)
  final Function(List<RouteWaypoint>) onWaypointsChanged; // Callback when waypoints are modified
  final Function(RouteWaypoint, String)? onTravelModeChanged; // Callback when transportation mode changes

  const SequentialWaypointList({
    super.key,
    required this.waypoints,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onWaypointsChanged,
    this.onTravelModeChanged,
  });

  @override
  State<SequentialWaypointList> createState() => _SequentialWaypointListState();
}

class _SequentialWaypointListState extends State<SequentialWaypointList> {
  // Removed unused _groupingService - groupingService is created locally in _groupWaypoints

  @override
  Widget build(BuildContext context) {
    // Sort waypoints by order
    final sortedWaypoints = List<RouteWaypoint>.from(widget.waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedWaypoints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.schedule, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No waypoints added yet',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button or click on the map to add waypoints',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        // Adjust for the fact that ReorderableListView uses visual indices
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        widget.onReorder(oldIndex, newIndex);
      },
      children: sortedWaypoints.map((waypoint) {
        // Check if this is part of a choice group
        final isChoiceGroup = waypoint.choiceGroupId != null;
        final choiceGroupWaypoints = isChoiceGroup
            ? sortedWaypoints
                .where((w) => w.choiceGroupId == waypoint.choiceGroupId)
                .toList()
            : [waypoint];

        // Only show the first waypoint in a choice group, or show individual waypoints
        // Use a visible placeholder instead of SizedBox.shrink() to maintain correct indices
        if (isChoiceGroup && choiceGroupWaypoints.first.id != waypoint.id) {
          return Container(
            key: ValueKey(waypoint.id),
            height: 0,
            width: 0,
          ); // Invisible but maintains index for ReorderableListView
        }

        return _WaypointListItem(
          key: ValueKey(waypoint.id),
          waypoint: waypoint,
          allWaypoints: sortedWaypoints,
          onEdit: () => widget.onEdit(waypoint),
          onDelete: () => widget.onDelete(waypoint),
          onGroupWith: (otherWaypoint) => _groupWaypoints(waypoint, otherWaypoint),
          onUngroup: () => _ungroupWaypoint(waypoint),
          onRenameChoiceLabel: (newLabel) => _renameChoiceLabel(waypoint, newLabel),
          onTravelModeChanged: widget.onTravelModeChanged,
        );
      }).toList(),
    );
  }

  void _groupWaypoints(RouteWaypoint waypoint1, RouteWaypoint waypoint2) {
    final groupingService = WaypointGroupingService();
    final choiceGroupId = const Uuid().v4();
    final choiceLabel = groupingService.generateAutoChoiceLabel(
      waypoint1.type,
      waypoint1.suggestedStartTime,
      waypoint1.mealTime,
      waypoint1.activityTime,
    );

    final updatedWaypoints = widget.waypoints.map((w) {
      if (w.id == waypoint1.id || w.id == waypoint2.id) {
        return w.copyWith(
          order: waypoint1.order,
          choiceGroupId: choiceGroupId,
          choiceLabel: choiceLabel,
        );
      }
      return w;
    }).toList();

    widget.onWaypointsChanged(updatedWaypoints);
  }

  void _ungroupWaypoint(RouteWaypoint waypoint) {
    if (waypoint.choiceGroupId == null) return;

    final oldChoiceGroupId = waypoint.choiceGroupId!;
    
    // Remove choice group from this waypoint
    final updatedWaypoints = widget.waypoints.map((w) {
      if (w.id == waypoint.id) {
        return w.copyWith(
          choiceGroupId: null,
          choiceLabel: null,
        );
      }
      return w;
    }).toList();

    // Check if old group has any remaining members
    final remainingInOldGroup = updatedWaypoints
        .where((w) => w.choiceGroupId == oldChoiceGroupId)
        .toList();
    
    // If only 1 or 0 members left, remove choice group from all
    if (remainingInOldGroup.length <= 1) {
      for (final wp in remainingInOldGroup) {
        final idx = updatedWaypoints.indexWhere((w) => w.id == wp.id);
        if (idx >= 0) {
          updatedWaypoints[idx] = updatedWaypoints[idx].copyWith(
            choiceGroupId: null,
            choiceLabel: null,
          );
        }
      }
    }

    widget.onWaypointsChanged(updatedWaypoints);
  }

  void _renameChoiceLabel(RouteWaypoint waypoint, String newLabel) {
    if (waypoint.choiceGroupId == null) return;

    final updatedWaypoints = widget.waypoints.map((w) {
      if (w.choiceGroupId == waypoint.choiceGroupId) {
        return w.copyWith(choiceLabel: newLabel);
      }
      return w;
    }).toList();

    widget.onWaypointsChanged(updatedWaypoints);
  }
}

/// Individual waypoint list item with drag handle
class _WaypointListItem extends StatelessWidget {
  final RouteWaypoint waypoint;
  final List<RouteWaypoint> allWaypoints;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(RouteWaypoint)? onGroupWith;
  final VoidCallback? onUngroup;
  final Function(String)? onRenameChoiceLabel;
  final Function(RouteWaypoint, String)? onTravelModeChanged;

  const _WaypointListItem({
    super.key,
    required this.waypoint,
    required this.allWaypoints,
    required this.onEdit,
    required this.onDelete,
    this.onGroupWith,
    this.onUngroup,
    this.onRenameChoiceLabel,
    this.onTravelModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isChoiceGroup = waypoint.choiceGroupId != null;
    final choiceGroupWaypoints = isChoiceGroup
        ? allWaypoints
            .where((w) => w.choiceGroupId == waypoint.choiceGroupId)
            .toList()
        : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Drag handle
                Icon(
                  Icons.drag_handle,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // Order number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${waypoint.order}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Waypoint icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: getWaypointColor(waypoint.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getWaypointIcon(waypoint.type),
                    color: getWaypointColor(waypoint.type),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Waypoint name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waypoint.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (waypoint.suggestedStartTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          waypoint.suggestedStartTime!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    switch (value) {
                      case 'group':
                        _showGroupDialog(context);
                        break;
                      case 'ungroup':
                        onUngroup?.call();
                        break;
                      case 'rename':
                        _showRenameDialog(context);
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (waypoint.choiceGroupId == null)
                      const PopupMenuItem(
                        value: 'group',
                        child: Row(
                          children: [
                            Icon(Icons.group, size: 18),
                            SizedBox(width: 8),
                            Text('Group with...'),
                          ],
                        ),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'ungroup',
                        child: Row(
                          children: [
                            Icon(Icons.call_split, size: 18),
                            SizedBox(width: 8),
                            Text('Ungroup'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.label, size: 18),
                            SizedBox(width: 8),
                            Text('Rename choice label'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Choice group indicator
            if (isChoiceGroup && choiceGroupWaypoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_checked, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      waypoint.choiceLabel ?? 'Choice Group',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${choiceGroupWaypoints.length} options)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Travel segment - show distance and transportation mode
            _buildTravelSegment(context),
          ],
        ),
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
        return Icons.arrow_forward;
    }
  }

  String _formatTravelTime(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }

  /// Build travel segment showing distance, time, and transportation mode selector
  Widget _buildTravelSegment(BuildContext context) {
    // Find previous waypoint(s) - handle OR conditions
    final currentOrder = waypoint.order;
    final previousWaypoints = allWaypoints
        .where((w) => w.order < currentOrder)
        .toList()
      ..sort((a, b) => b.order.compareTo(a.order)); // Get highest order first
    
    if (previousWaypoints.isEmpty) {
      return const SizedBox.shrink(); // No previous waypoint
    }

    // Get the most recent waypoint(s) - could be multiple if OR conditions
    final maxOrder = previousWaypoints.first.order;
    final previousWaypointGroup = previousWaypoints
        .where((w) => w.order == maxOrder)
        .toList();

    // If previous waypoint has OR conditions, show distances from all options
    if (previousWaypointGroup.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: previousWaypointGroup.map((prevWp) {
          return _ORDistanceRow(
            fromWaypoint: prevWp,
            toWaypoint: waypoint,
            onTravelModeChanged: onTravelModeChanged,
            getTravelIcon: _getTravelIcon,
            getTravelModeLabel: _getTravelModeLabel,
            formatTravelTime: _formatTravelTime,
          );
        }).toList(),
      );
    }

    // Single previous waypoint
    final prevWp = previousWaypointGroup.first;
    return _buildDistanceRow(context, prevWp, waypoint);
  }

  /// Build a single distance row with transportation mode selector
  /// For OR conditions, this shows distance from a specific previous waypoint option
  Widget _buildDistanceRow(BuildContext context, RouteWaypoint fromWaypoint, RouteWaypoint toWaypoint) {
    // Check if this waypoint has travel info calculated from this specific previous waypoint
    // For OR conditions, we need to store multiple travel infos - for now, use the main one
    // TODO: Enhance to support multiple travel infos per waypoint for OR conditions
    
    final hasTravelInfo = toWaypoint.travelTime != null && 
                          toWaypoint.travelMode != null && 
                          toWaypoint.travelDistance != null;
    
    final distanceKm = hasTravelInfo 
        ? (toWaypoint.travelDistance! / 1000.0).toStringAsFixed(1)
        : null;
    final timeStr = hasTravelInfo ? _formatTravelTime(toWaypoint.travelTime!) : null;
    final mode = toWaypoint.travelMode ?? 'walking';
    final modeLabel = _getTravelModeLabel(mode);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show "From Location X" if previous waypoint is part of OR group or if multiple previous options
          if (fromWaypoint.choiceGroupId != null || 
              allWaypoints.where((w) => w.order == fromWaypoint.order).length > 1) ...[
            Text(
              'From ${fromWaypoint.name}:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              // Transportation mode dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: mode,
                  isDense: true,
                  underline: const SizedBox(),
                  iconSize: 16,
                  items: TravelMode.values.map((tm) {
                    return DropdownMenuItem(
                      value: tm.name,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getTravelIcon(tm.name), size: 16),
                          const SizedBox(width: 4),
                          Text(_getTravelModeLabel(tm.name), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newMode) {
                    if (newMode != null && onTravelModeChanged != null) {
                      onTravelModeChanged!(toWaypoint, newMode);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Distance and time display
              if (distanceKm != null && timeStr != null) ...[
                Icon(
                  _getTravelIcon(mode),
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '$distanceKm km ($timeStr)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  'Distance not calculated',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getTravelModeLabel(String mode) {
    switch (mode) {
      case 'walking':
        return 'Foot';
      case 'transit':
        return 'Transit';
      case 'driving':
        return 'Car';
      case 'bicycling':
        return 'Bike';
      default:
        return mode;
    }
  }

  void _showGroupDialog(BuildContext context) {
    // Find waypoints that can be grouped (same order or adjacent)
    final candidates = allWaypoints
        .where((w) => w.id != waypoint.id && w.choiceGroupId == null)
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No waypoints available to group with')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group with...'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              return ListTile(
                leading: Icon(
                  getWaypointIcon(candidate.type),
                  color: getWaypointColor(candidate.type),
                ),
                title: Text(candidate.name),
                subtitle: Text('Order ${candidate.order}'),
                onTap: () {
                  Navigator.pop(context);
                  onGroupWith?.call(candidate);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: waypoint.choiceLabel ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Choice Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Choice Label',
            hintText: 'e.g., Lunch Options',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onRenameChoiceLabel?.call(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Distance row for OR conditions - calculates distance on-the-fly
class _ORDistanceRow extends StatefulWidget {
  final RouteWaypoint fromWaypoint;
  final RouteWaypoint toWaypoint;
  final Function(RouteWaypoint, String)? onTravelModeChanged;
  final IconData Function(String) getTravelIcon;
  final String Function(String) getTravelModeLabel;
  final String Function(int) formatTravelTime;

  const _ORDistanceRow({
    required this.fromWaypoint,
    required this.toWaypoint,
    this.onTravelModeChanged,
    required this.getTravelIcon,
    required this.getTravelModeLabel,
    required this.formatTravelTime,
  });

  @override
  State<_ORDistanceRow> createState() => _ORDistanceRowState();
}

class _ORDistanceRowState extends State<_ORDistanceRow> {
  String _selectedMode = 'walking';
  bool _calculating = false;
  double? _distanceKm;
  int? _timeSeconds;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.toWaypoint.travelMode ?? 'walking';
    // Use stored values if available (from primary calculation)
    if (widget.toWaypoint.travelDistance != null && widget.toWaypoint.travelTime != null) {
      _distanceKm = widget.toWaypoint.travelDistance! / 1000.0;
      _timeSeconds = widget.toWaypoint.travelTime;
    } else {
      // Calculate on-the-fly
      _calculateDistance();
    }
  }

  Future<void> _calculateDistance() async {
    setState(() => _calculating = true);
    try {
      final travelService = TravelCalculatorService();
      final mode = TravelMode.values.firstWhere(
        (tm) => tm.name == _selectedMode,
        orElse: () => TravelMode.walking,
      );
      final travelInfo = await travelService.calculateTravel(
        from: widget.fromWaypoint.position,
        to: widget.toWaypoint.position,
        travelMode: mode,
      );
      if (travelInfo != null && mounted) {
        setState(() {
          _distanceKm = travelInfo.distanceKm;
          _timeSeconds = travelInfo.durationSeconds;
          _calculating = false;
        });
      } else if (mounted) {
        setState(() => _calculating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _calculating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show "From Location X" label
          Text(
            'From ${widget.fromWaypoint.name}:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Transportation mode dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedMode,
                  isDense: true,
                  underline: const SizedBox(),
                  iconSize: 16,
                  items: TravelMode.values.map((tm) {
                    return DropdownMenuItem(
                      value: tm.name,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.getTravelIcon(tm.name), size: 16),
                          const SizedBox(width: 4),
                          Text(widget.getTravelModeLabel(tm.name), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newMode) async {
                    if (newMode != null) {
                      setState(() => _selectedMode = newMode);
                      await _calculateDistance();
                      if (widget.onTravelModeChanged != null) {
                        widget.onTravelModeChanged!(widget.toWaypoint, newMode);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Distance and time display
              if (_calculating) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 4),
                Text(
                  'Calculating...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else if (_distanceKm != null && _timeSeconds != null) ...[
                Icon(
                  widget.getTravelIcon(_selectedMode),
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_distanceKm!.toStringAsFixed(1)} km (${widget.formatTravelTime(_timeSeconds!)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  'Distance not calculated',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

