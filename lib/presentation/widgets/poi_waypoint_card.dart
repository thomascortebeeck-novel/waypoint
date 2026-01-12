import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card widget for restaurant, activity, and viewing point waypoints
class PoiWaypointCard extends StatelessWidget {
  final RouteWaypoint waypoint;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const PoiWaypointCard({
    super.key,
    required this.waypoint,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
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
                  // Type badge and name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getWaypointColor(waypoint.type).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getWaypointIcon(waypoint.type),
                              size: 14,
                              color: getWaypointColor(waypoint.type),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              getWaypointLabel(waypoint.type),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: getWaypointColor(waypoint.type),
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

                  // Description
                  if (waypoint.description != null && waypoint.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        waypoint.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                  // Contact info and links
                  if (waypoint.phoneNumber != null || waypoint.website != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (waypoint.phoneNumber != null)
                            OutlinedButton.icon(
                              onPressed: () => _launchPhone(waypoint.phoneNumber!),
                              icon: Icon(Icons.phone, size: 16),
                              label: Text('Call'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          if (waypoint.website != null)
                            OutlinedButton.icon(
                              onPressed: () => _launchUrl(waypoint.website!),
                              icon: Icon(Icons.language, size: 16),
                              label: Text('Website'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
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
        decoration: BoxDecoration(
          color: getWaypointColor(waypoint.type).withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Center(
          child: Icon(
            getWaypointIcon(waypoint.type),
            size: 64,
            color: getWaypointColor(waypoint.type).withValues(alpha: 0.3),
          ),
        ),
      );

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

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
