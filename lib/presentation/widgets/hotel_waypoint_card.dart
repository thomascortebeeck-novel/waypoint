import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card widget for hotel accommodation waypoints
class HotelWaypointCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCheckAvailability;
  final bool showActions;
  final bool isUserView; // true when user is viewing purchased plan

  const HotelWaypointCard({
    super.key,
    required this.waypoint,
    this.onEdit,
    this.onDelete,
    this.onCheckAvailability,
    this.showActions = true,
    this.isUserView = false,
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
                  // Type badge and actions
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getWaypointColor(WaypointType.accommodation).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hotel,
                              size: 14,
                              color: getWaypointColor(WaypointType.accommodation),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hotel',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: getWaypointColor(WaypointType.accommodation),
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

                  // Name and hotel chain
                  Text(
                    waypoint.name,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (waypoint.hotelChain != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        waypoint.hotelChain!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Rating
                  if (waypoint.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < waypoint.rating!.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            waypoint.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  // Amenities
                  if (waypoint.amenities != null && waypoint.amenities!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: waypoint.amenities!.map((amenity) => Chip(
                          label: Text(amenity),
                          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.grey.shade100,
                        )).toList(),
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

                  // Price range
                  if (waypoint.estimatedPriceRange != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.euro, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Est. €${waypoint.estimatedPriceRange!.min.toInt()}-${waypoint.estimatedPriceRange!.max.toInt()}/night',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Actions
                  if (!isUserView) ...[
                    // Admin view: show booking.com link
                    if (waypoint.bookingComUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => _launchUrl(waypoint.bookingComUrl!),
                          icon: Icon(Icons.open_in_new, size: 16),
                          label: Text('View on Booking.com'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ),
                  ] else ...[
                    // User view: show check availability button (Phase 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onCheckAvailability,
                              icon: Icon(Icons.calendar_today, size: 16),
                              label: Text('Check Availability'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                          ),
                          if (waypoint.bookingComUrl != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _launchUrl(waypoint.bookingComUrl!),
                              icon: Icon(Icons.open_in_new),
                              tooltip: 'View on Booking.com',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildPlaceholderImage() => Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: getWaypointColor(WaypointType.accommodation).withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Center(
          child: Icon(
            Icons.hotel,
            size: 64,
            color: getWaypointColor(WaypointType.accommodation).withValues(alpha: 0.3),
          ),
        ),
      );

  void _launchUrl(String url) async {
    // Ensure URL has a scheme
    String formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://$url';
    }
    final uri = Uri.parse(formattedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
