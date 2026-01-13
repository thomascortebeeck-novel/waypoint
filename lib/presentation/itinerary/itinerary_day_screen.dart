import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

class ItineraryDayScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  final int dayIndex;

  const ItineraryDayScreen({
    super.key,
    required this.planId,
    required this.tripId,
    required this.dayIndex,
  });

  @override
  State<ItineraryDayScreen> createState() => _ItineraryDayScreenState();
}

class _ItineraryDayScreenState extends State<ItineraryDayScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  Trip? _trip;
  PlanVersion? _version;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await _plans.getPlanById(widget.planId);
    final trip = await _trips.getTripById(widget.tripId);
    final version = plan?.versions.firstWhere(
      (v) => v.id == trip?.versionId,
      orElse: () => plan!.versions.first,
    );
    setState(() {
      _plan = plan;
      _trip = trip;
      _version = version;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_version == null || _plan == null || _trip == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/itinerary/${widget.planId}'),
          ),
        ),
        body: const Center(child: Text('Failed to load day info')),
      );
    }

    final days = _version!.days;
    if (days.isEmpty || widget.dayIndex >= days.length) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/itinerary/${widget.planId}'),
          ),
          title: const Text('Day not found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 64, color: context.colors.outline),
              const SizedBox(height: 16),
              Text('No day information available', style: context.textStyles.bodyLarge),
            ],
          ),
        ),
      );
    }

    final day = days[widget.dayIndex];
    final totalDays = days.length;
    final isFirstDay = widget.dayIndex == 0;
    final isLastDay = widget.dayIndex == totalDays - 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Image AppBar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () {
                if (isFirstDay) {
                  context.go('/itinerary/${widget.planId}/travel/${widget.tripId}');
                } else {
                  context.go('/itinerary/${widget.planId}/day/${widget.tripId}/${widget.dayIndex - 1}');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Day ${day.dayNum}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (day.photos.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: day.photos.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: context.colors.surfaceContainer,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: context.colors.surfaceContainer,
                        child: Icon(Icons.landscape, size: 64, color: context.colors.outline),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.primary,
                            context.colors.secondary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.landscape, size: 80, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sticky day navigator
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayNavigatorHeader(
              totalDays: totalDays,
              currentIndex: widget.dayIndex,
              onPrev: isFirstDay
                  ? () => context.go('/itinerary/${widget.planId}/travel/${widget.tripId}')
                  : () => context.go('/itinerary/${widget.planId}/day/${widget.tripId}/${widget.dayIndex - 1}'),
              onNext: isLastDay
                  ? null
                  : () => context.go('/itinerary/${widget.planId}/day/${widget.tripId}/${widget.dayIndex + 1}'),
            ),
          ),

          // Content
          SliverPadding(
            padding: AppSpacing.paddingLg,
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Title
                Text(
                  day.title,
                  style: context.textStyles.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // Distance and time
                if (day.distanceKm > 0 || day.estimatedTimeMinutes > 0)
                  Wrap(
                    spacing: 16,
                    children: [
                      if (day.distanceKm > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten, size: 18, color: context.colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${day.distanceKm.toStringAsFixed(1)} km',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (day.estimatedTimeMinutes > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 18, color: context.colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(day.estimatedTimeMinutes),
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: MarkdownBody(
                    data: day.description.isEmpty ? 'No description available.' : day.description,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                      a: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final uri = Uri.tryParse(href);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Waypoints Summary
                _buildWaypointsSummary(context, day),

                // Accommodations
                if (day.accommodations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    title: 'Where to stay',
                    icon: Icons.hotel,
                    children: day.accommodations.map((a) => _buildAccommodationCard(context, a)).toList(),
                  ),
                ],

                // Restaurants
                if (day.restaurants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    title: 'Where to eat',
                    icon: Icons.restaurant,
                    children: day.restaurants.map((r) => _buildRestaurantCard(context, r)).toList(),
                  ),
                ],

                // Activities
                if (day.activities.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    title: 'Activities',
                    icon: Icons.local_activity,
                    children: day.activities.map((a) => _buildActivityCard(context, a)).toList(),
                  ),
                ],

                // Photo gallery
                if (day.photos.length > 1) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Photos',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: day.photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: day.photos[i],
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 100), // Bottom padding for nav bar
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (isFirstDay) {
                    context.go('/itinerary/${widget.planId}/travel/${widget.tripId}');
                  } else {
                    context.go('/itinerary/${widget.planId}/day/${widget.tripId}/${widget.dayIndex - 1}');
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                label: Text(isFirstDay ? 'Travel Info' : 'Day ${widget.dayIndex}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: context.colors.onSurfaceVariant,
                ),
              ),
              if (isLastDay)
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to map or finish
                    context.go('/itinerary/${widget.planId}');
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Finish'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    context.go('/itinerary/${widget.planId}/day/${widget.tripId}/${widget.dayIndex + 1}');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Day ${widget.dayIndex + 2}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

 

  Widget _buildWaypointsSummary(BuildContext context, DayItinerary day) {
    final waypoints = <Map<String, dynamic>>[];

    // Start point
    if (day.startLat != null && day.startLng != null) {
      waypoints.add({
        'type': 'start',
        'title': 'Start',
        'icon': Icons.play_circle_filled,
        'color': context.colors.primary,
      });
    }

    // Activities as waypoints
    for (final activity in day.activities) {
      waypoints.add({
        'type': 'activity',
        'title': activity.name,
        'icon': Icons.local_activity,
        'color': context.colors.tertiary,
      });
    }

    // Restaurants
    for (final restaurant in day.restaurants) {
      waypoints.add({
        'type': 'restaurant',
        'title': restaurant.name,
        'icon': Icons.restaurant,
        'color': context.colors.error,
      });
    }

    // Accommodation
    for (final acc in day.accommodations) {
      waypoints.add({
        'type': 'accommodation',
        'title': acc.name,
        'icon': Icons.hotel,
        'color': context.colors.secondary,
      });
    }

    // End point
    if (day.endLat != null && day.endLng != null) {
      waypoints.add({
        'type': 'end',
        'title': 'End',
        'icon': Icons.flag_circle,
        'color': context.colors.primary,
      });
    }

    if (waypoints.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Route',
          style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            children: waypoints.asMap().entries.map((entry) {
              final index = entry.key;
              final wp = entry.value;
              final isLast = index == waypoints.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (wp['color'] as Color).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(wp['icon'] as IconData, size: 16, color: wp['color'] as Color),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 24,
                          color: context.colors.outline.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Text(
                        wp['title'] as String,
                        style: context.textStyles.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.colors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildAccommodationCard(BuildContext context, AccommodationInfo acc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hotel, color: context.colors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.name,
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  acc.type,
                  style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, RestaurantInfo restaurant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.restaurant, color: context.colors.error),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  restaurant.mealType.name[0].toUpperCase() + restaurant.mealType.name.substring(1),
                  style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityInfo activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_activity, color: context.colors.tertiary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (activity.description.isNotEmpty)
                  Text(
                    activity.description,
                    style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }
}

class _DayNavigatorHeader extends SliverPersistentHeaderDelegate {
  final int totalDays;
  final int currentIndex;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  _DayNavigatorHeader({required this.totalDays, required this.currentIndex, this.onPrev, this.onNext});

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: List.generate(totalDays, (i) {
                final active = i == currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Center(
                      child: Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              })),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayNavigatorHeader oldDelegate) =>
      totalDays != oldDelegate.totalDays || currentIndex != oldDelegate.currentIndex || onPrev != oldDelegate.onPrev || onNext != oldDelegate.onNext;
}
