import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/spacing.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';

IconData _iconForMode(FootprintTransportMode mode) {
  switch (mode) {
    case FootprintTransportMode.foot:
      return Icons.directions_walk;
    case FootprintTransportMode.bike:
      return Icons.directions_bike;
    case FootprintTransportMode.car:
      return Icons.directions_car;
    case FootprintTransportMode.train:
      return Icons.train;
    case FootprintTransportMode.publicTransport:
      return Icons.directions_transit;
    case FootprintTransportMode.taxi:
      return Icons.local_taxi;
    case FootprintTransportMode.flight:
      return Icons.flight;
    case FootprintTransportMode.boat:
      return Icons.directions_boat;
    case FootprintTransportMode.eScooter:
      return Icons.electric_scooter;
  }
}

class TransportLegTile extends StatelessWidget {
  final FootprintLeg leg;

  const TransportLegTile({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WaypointSpacing.xs),
      child: Row(
        children: [
          Icon(_iconForMode(leg.mode), size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: WaypointSpacing.sm),
          Expanded(
            child: Text(
              '${leg.fromWaypoint} → ${leg.toWaypoint}',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${leg.distanceKm.toStringAsFixed(1)} km',
            style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(width: WaypointSpacing.sm),
          Text(
            '${leg.kgCO2.toStringAsFixed(1)} kg',
            style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
