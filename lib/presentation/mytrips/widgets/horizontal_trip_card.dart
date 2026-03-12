// Redesigned to match the My Trips mockup:
// ┌────────────────────────────────────────────────────────┐
// │ [image 120px] │ Title                             ⋮   │
// │               │ 📅 Oct 12 – Oct 18                    │
// │               │ Based on: Plan Name                   │
// │               │ 📍 Location                           │
// │               │ [JD][AS][MK]         [Upcoming]       │
// └────────────────────────────────────────────────────────┘
//
// Uses only BrandingLightTokens — no hardcoded hex (except status pill colors).
// Chips via status pill; avatar group via WaypointUserAvatarGroup.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';

class HorizontalTripCard extends StatelessWidget {
  const HorizontalTripCard({
    super.key,
    required this.trip,
    required this.plan,
    required this.userId,
  });

  final Trip trip;
  final Plan plan;
  final String userId;

  // ── Derive status from dates ─────────────────────────────────────────────
  String get _status {
    final now = DateTime.now();
    final start = trip.startDate;
    final end = trip.endDate;
    if (start != null && start.isAfter(now)) return 'Upcoming';
    if (end != null && end.isBefore(now)) return 'Completed';
    if (start != null &&
        (end == null ||
            (now.isAfter(start) &&
                now.isBefore(end.add(const Duration(days: 1)))))) {
      return 'Active';
    }
    return 'Upcoming';
  }

  // ── Format date range ────────────────────────────────────────────────────
  String get _dateRange {
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null) return '';
    final s = _fmt(start);
    if (end == null) return s;
    final e = _fmt(end);
    final days = end.difference(start).inDays + 1;
    return '$s – $e • $days days';
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // ── Status colors (theme-aware) ──────────────────────────────────────────
  Color _statusBg(BuildContext context) {
    switch (_status) {
      case 'Upcoming':
        return context.colors.primaryContainer;
      case 'Active':
        return context.colors.tertiaryContainer;
      default:
        return context.colors.surfaceContainerHighest;
    }
  }

  Color _statusFg(BuildContext context) {
    switch (_status) {
      case 'Upcoming':
        return context.colors.onPrimaryContainer;
      case 'Active':
        return context.colors.onTertiaryContainer;
      default:
        return context.colors.onSurface.withValues(alpha: 0.6);
    }
  }

  // ── Image URL: trip custom image or plan hero ─────────────────────────────
  String? get _imageUrl {
    if (trip.customImages != null && !trip.usePlanImage) {
      final large = trip.customImages!['large'] as String?;
      final original = trip.customImages!['original'] as String?;
      if (large != null && large.isNotEmpty) return large;
      if (original != null && original.isNotEmpty) return original;
    }
    return plan.heroImageUrl.isNotEmpty ? plan.heroImageUrl : null;
  }

  /// Initials from user: first letter first name + first letter last name, else from displayName.
  static String _initialsForUser(UserModel u) {
    final first = u.firstName?.trim();
    final last = u.lastName?.trim();
    if (first != null && first.isNotEmpty && last != null && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final name = u.displayName.trim();
    if (name.isEmpty) return '?';
    if (name.length >= 2) return name.substring(0, 2).toUpperCase();
    return name.toUpperCase();
  }

  /// Fixed height so the card has a definite size when used in a SliverList (avoids "RenderBox was not laid out").
  /// Fits content without excess spacing below members/status.
  static const double cardHeight = 174;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.outline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/trip/${trip.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImage(context),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Left-side image: full height of card (top to bottom), fixed width.
  Widget _buildImage(BuildContext context) {
    final imageUrl = _imageUrl;

    return SizedBox(
      width: 120,
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _imagePlaceholder(context),
              errorWidget: (_, __, ___) => _imagePlaceholder(context),
            )
          : _imagePlaceholder(context),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(
      color: context.colors.surfaceContainerHighest,
      child: Icon(Icons.landscape_outlined,
          size: 36, color: context.colors.onSurface.withValues(alpha: 0.5)),
    );
  }

  Widget _buildContent(BuildContext context) {
    final title =
        trip.title?.isNotEmpty == true ? trip.title! : plan.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.onSurface,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _MenuButton(trip: trip, plan: plan, userId: userId),
                ],
              ),
              const SizedBox(height: 5),
              if (_dateRange.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: context.colors.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _dateRange,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.colors.onSurface.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                'Based on:',
                style: TextStyle(fontSize: 11, color: context.colors.onSurface.withValues(alpha: 0.6)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                plan.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (plan.location.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 11, color: context.colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        plan.location,
                        style: TextStyle(
                            fontSize: 11, color: context.colors.onSurface.withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<List<UserModel>>(
                    future: InviteService().getMembersDetails(trip.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return WaypointUserAvatarGroup(initials: ['?']);
                      }
                      final members = snapshot.data!.take(4).toList();
                      final initials = members.map(_initialsForUser).toList();
                      final imageUrls = members.map((u) => u.photoUrl).toList();
                      return WaypointUserAvatarGroup(
                        initials: initials,
                        imageUrls: imageUrls,
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBg(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusFg(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
      ),
        ),
      ),
    );
  }
}

// ── Menu button ─────────────────────────────────────────────────────────────
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.trip,
    required this.plan,
    required this.userId,
  });

  final Trip trip;
  final Plan plan;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert,
            size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        onSelected: (value) {
          switch (value) {
            case 'open':
              context.go('/trip/${trip.id}');
              break;
            case 'delete':
              _confirmDelete(context);
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('Open trip')),
          PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await TripService().deleteTrip(trip.id);
                if (context.mounted) {
                  context.go('/mytrips');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete trip: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
