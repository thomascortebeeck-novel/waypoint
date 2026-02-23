import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Price card widget for adventure detail screens
/// Displays price, duration, waypoints, and languages
class AdventurePriceCard extends StatelessWidget {
  final double? price;
  final int totalDays;
  final int totalWaypoints;
  final List<String> languages;
  final bool showBuyButton;
  final VoidCallback? onBuyPlan;

  const AdventurePriceCard({
    super.key,
    this.price,
    required this.totalDays,
    required this.totalWaypoints,
    required this.languages,
    this.showBuyButton = false,
    this.onBuyPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Price
          if (price != null) ...[
            Text(
              '€${price!.toStringAsFixed(2)}',
              style: const TextStyle(
                fontFamily: 'DMSerifDisplay',
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Color(0xFF212529),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'per person',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Essential data rows
          _PriceCardRow(Icons.calendar_today_outlined, '$totalDays days'),
          const SizedBox(height: 12),
          _PriceCardRow(Icons.location_on_outlined, '$totalWaypoints stops'),
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PriceCardRow(
              Icons.language_outlined,
              languages.length > 2
                  ? '${languages.take(2).join(', ')} +${languages.length - 2}'
                  : languages.join(', '),
            ),
          ],

          // CTA button
          if (showBuyButton && price != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBuyPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4332),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Get this plan',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper widget for price card rows
class _PriceCardRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PriceCardRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6C757D)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              color: Color(0xFF212529),
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick stats widget showing adventure highlights
/// Displays days, restaurants, activities, stays, transport, and languages
class AdventureQuickStats extends StatelessWidget {
  final int days;
  final int restaurants;
  final int activities;
  final int stays;
  final int transport;
  final List<String> languages;

  const AdventureQuickStats({
    super.key,
    required this.days,
    required this.restaurants,
    required this.activities,
    required this.stays,
    required this.transport,
    required this.languages,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        if (days > 0)
          _QuickStatItem(Icons.calendar_today_outlined, '$days days'),
        if (restaurants > 0)
          _QuickStatItem(Icons.restaurant_outlined, '$restaurants restaurants'),
        if (activities > 0)
          _QuickStatItem(Icons.local_activity_outlined, '$activities activities'),
        if (stays > 0)
          _QuickStatItem(Icons.hotel_outlined, '$stays stays'),
        if (transport > 0)
          _QuickStatItem(Icons.directions_car_outlined, '$transport transport'),
        if (languages.isNotEmpty)
          _QuickStatItem(Icons.language_outlined, languages.join(', ')),
      ],
    );
  }
}

/// Helper widget for quick stat items
class _QuickStatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickStatItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6C757D)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: Color(0xFF495057),
          ),
        ),
      ],
    );
  }
}

/// Utility function to count waypoints by type across all versions and days
int countWaypointsByType(Plan adventure, String type) {
  int count = 0;
  for (final version in adventure.versions) {
    for (final day in version.days) {
      if (day.route?.poiWaypoints != null) {
        for (final wpJson in day.route!.poiWaypoints) {
          try {
            final wp = RouteWaypoint.fromJson(wpJson);
            if (wp.type.name.toLowerCase() == type.toLowerCase()) {
              count++;
            }
          } catch (_) {
            // Skip invalid waypoints
          }
        }
      }
    }
  }
  return count;
}

