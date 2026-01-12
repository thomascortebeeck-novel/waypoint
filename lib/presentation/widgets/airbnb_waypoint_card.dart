import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card widget for Airbnb accommodation waypoints
class AirbnbWaypointCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;
  final DateTime? checkIn;
  final DateTime? checkOut;

  const AirbnbWaypointCard({
    super.key,
    required this.waypoint,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
    this.checkIn,
    this.checkOut,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            if (waypoint.photoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  waypoint.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                ),
              )
            else
              _buildPlaceholderImage(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Airbnb badge and actions
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A5F).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.home,
                              size: 14,
                              color: Color(0xFFFF5A5F),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Airbnb',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF5A5F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showActions) ...[
                        const Spacer(),
                        if (onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: onEdit,
                            color: Colors.grey.shade700,
                            tooltip: 'Edit',
                          ),
                        if (onDelete != null)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: onDelete,
                            color: Colors.red.shade700,
                            tooltip: 'Delete',
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    waypoint.name,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Address
                  if (waypoint.address != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              waypoint.address!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Description
                  if (waypoint.description != null && waypoint.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        waypoint.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                  // Estimated price range
                  if (waypoint.estimatedPriceRange != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A5F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.euro,
                            size: 18,
                            color: Color(0xFFFF5A5F),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Est. €${waypoint.estimatedPriceRange!.min.toInt()}-${waypoint.estimatedPriceRange!.max.toInt()}/night',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5A5F),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Check availability button
                  if (waypoint.airbnbPropertyUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.icon(
                        onPressed: _openAirbnb,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Check Availability on Airbnb'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: const Color(0xFFFF5A5F),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildPlaceholderImage() => Container(
        height: 180,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFF5A5F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Center(
          child: Icon(
            Icons.home,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      );

  void _openAirbnb() async {
    if (waypoint.airbnbPropertyUrl == null) return;

    String url = waypoint.airbnbPropertyUrl!;

    // Add check-in/check-out dates to URL if available
    if (checkIn != null && checkOut != null) {
      final checkInStr = '${checkIn!.year}-${checkIn!.month.toString().padLeft(2, '0')}-${checkIn!.day.toString().padLeft(2, '0')}';
      final checkOutStr = '${checkOut!.year}-${checkOut!.month.toString().padLeft(2, '0')}-${checkOut!.day.toString().padLeft(2, '0')}';
      
      // Add query parameters
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}check_in=$checkInStr&check_out=$checkOutStr';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
