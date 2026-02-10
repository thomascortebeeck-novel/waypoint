import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';

/// Widget for rendering choice groups (OR options)
/// Displays multiple waypoints as radio button options
class ChoiceGroupWidget extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final String choiceLabel;
  final RouteWaypoint? selectedWaypoint;
  final Function(RouteWaypoint)? onSelected;
  final bool isBuilderView;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;

  const ChoiceGroupWidget({
    super.key,
    required this.waypoints,
    required this.choiceLabel,
    this.selectedWaypoint,
    this.onSelected,
    this.isBuilderView = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Choice label
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
              final isSelected = selectedWaypoint?.id == waypoint.id;
              
              return Padding(
                padding: EdgeInsets.only(bottom: index < waypoints.length - 1 ? 12 : 0),
                child: _ChoiceOption(
                  waypoint: waypoint,
                  isSelected: isSelected,
                  isBuilderView: isBuilderView,
                  onSelected: onSelected != null ? () => onSelected!(waypoint) : null,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Individual choice option within a choice group
class _ChoiceOption extends StatelessWidget {
  final RouteWaypoint waypoint;
  final bool isSelected;
  final bool isBuilderView;
  final VoidCallback? onSelected;
  final Function(RouteWaypoint)? onEdit;
  final Function(RouteWaypoint)? onDelete;

  const _ChoiceOption({
    required this.waypoint,
    required this.isSelected,
    this.isBuilderView = false,
    this.onSelected,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected 
              ? context.colors.primary 
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected 
            ? context.colors.primary.withValues(alpha: 0.05)
            : null,
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
              color: isSelected ? context.colors.primary : Colors.grey,
            ),
          const SizedBox(width: 12),
          // Waypoint name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waypoint.name,
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (waypoint.address != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    waypoint.address!,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
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

