import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/theme.dart';

/// Card widget to display route metadata extracted from Komoot or AllTrails
class RouteInfoCard extends StatelessWidget {
  final RouteInfo routeInfo;

  const RouteInfoCard({
    super.key,
    required this.routeInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and source link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Route Info',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(routeInfo.sourceUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'via ${routeInfo.sourceDisplayName}',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: context.colors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (routeInfo.distanceKm != null)
                _StatItem(
                  icon: Icons.straighten,
                  label: '${routeInfo.distanceKm!.toStringAsFixed(1)} km',
                ),
              if (routeInfo.elevationM != null)
                _StatItem(
                  icon: Icons.terrain,
                  label: '${routeInfo.elevationM} m',
                ),
              if (routeInfo.estimatedTime != null)
                _StatItem(
                  icon: Icons.access_time,
                  label: routeInfo.estimatedTime!,
                ),
              if (routeInfo.difficulty != null)
                _DifficultyBadge(
                  difficulty: routeInfo.difficulty!,
                  color: routeInfo.difficultyColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.colors.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textStyles.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  final Color color;

  const _DifficultyBadge({
    required this.difficulty,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = difficulty[0].toUpperCase() + difficulty.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayName,
            style: context.textStyles.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

