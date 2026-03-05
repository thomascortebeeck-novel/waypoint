import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/mytrips/widgets/horizontal_trip_card.dart';
import 'package:waypoint/components/feedback/waypoint_skeleton.dart';
import 'package:waypoint/components/feedback/waypoint_empty_state.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

enum _TripFilter { all, upcoming, active, completed }

class _MyTripsScreenState extends State<MyTripsScreen> {
  final _auth = FirebaseAuthManager();
  final _trips = TripService();
  final _plans = PlanService();
  _TripFilter? _selectedFilter;

  /// Cache of plans by sorted planIds key so revisit shows cards immediately.
  List<Plan>? _cachedPlans;
  String? _cachedPlanIdsKey;

  /// Effective filter (guards against hot-reload leaving state null).
  _TripFilter get _effectiveFilter => _selectedFilter ?? _TripFilter.all;

  static String _tripStatus(Trip t) {
    final now = DateTime.now();
    final start = t.startDate;
    final end = t.endDate;
    if (start != null && start.isAfter(now)) return 'Upcoming';
    if (end != null && end.isBefore(now)) return 'Completed';
    if (start != null && (end == null || (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))))) return 'Active';
    return 'Upcoming';
  }

  static _TripFilter _statusToFilter(String status) {
    switch (status) {
      case 'Active': return _TripFilter.active;
      case 'Completed': return _TripFilter.completed;
      default: return _TripFilter.upcoming;
    }
  }

  List<Trip> _filterTrips(List<Trip> trips) {
    if (_effectiveFilter == _TripFilter.all) return trips;
    return trips.where((t) => _statusToFilter(_tripStatus(t)) == _effectiveFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return StreamBuilder(
      stream: _auth.authStateChanges,
      builder: (context, authSnapshot) {
        final uid = authSnapshot.data?.uid;

        return Scaffold(
          floatingActionButton: uid == null
              ? null
              : WaypointFAB(
                  icon: Icons.add,
                  label: 'New Itinerary',
                  onPressed: () => context.go('/mytrips/create'),
                ),
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: WaypointPageHeader(
                title: 'My Trips',
                subtitle: 'Your personalized trip plans',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16, 12, isDesktop ? 32 : 16, 0,
                ),
                child: SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    children: [
                      WaypointCreamChip(
                        label: 'All',
                        selected: _effectiveFilter == _TripFilter.all,
                        prominent: true,
                        onTap: () => setState(() => _selectedFilter = _TripFilter.all),
                      ),
                      WaypointCreamChip(
                        label: 'Upcoming',
                        selected: _effectiveFilter == _TripFilter.upcoming,
                        prominent: true,
                        onTap: () => setState(() => _selectedFilter = _TripFilter.upcoming),
                      ),
                      WaypointCreamChip(
                        label: 'Active',
                        selected: _effectiveFilter == _TripFilter.active,
                        prominent: true,
                        onTap: () => setState(() => _selectedFilter = _TripFilter.active),
                      ),
                      WaypointCreamChip(
                        label: 'Completed',
                        selected: _effectiveFilter == _TripFilter.completed,
                        prominent: true,
                        onTap: () => setState(() => _selectedFilter = _TripFilter.completed),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
              sliver: uid == null 
                  ? SliverToBoxAdapter(child: SizedBox(height: 380, child: _SignedOutState())) 
                  : StreamBuilder<List<Trip>>(
                      stream: _trips.streamTripsForUser(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SliverToBoxAdapter(child: SizedBox(height: 300, child: _LoadingState(isDesktop: isDesktop)));
                        }
                        if (snapshot.hasError) {
                          return SliverToBoxAdapter(
                            child: SizedBox(
                              height: 320,
                              child: WaypointEmptyState.error(
                                message: 'Error loading trips: ${snapshot.error}',
                                onRetry: () => setState(() {}),
                              ),
                            ),
                          );
                        }
                        final trips = snapshot.data ?? [];
                        final filtered = _filterTrips(trips);
                        return _buildTripsContent(context, uid, isDesktop, filtered);
                      },
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
        );
      }
    );
  }

  Widget _buildTripsContent(BuildContext context, String uid, bool isDesktop, List<Trip> trips) {
    if (trips.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox(height: 320, child: _EmptyTripsState()));
    }

    // Get plans for these trips (use cache when same planIds so cards appear instantly on revisit)
    final planIds = trips.map((t) => t.planId).toSet().toList();
    final planIdsKey = (planIds.toList()..sort()).join(',');
    final Future<List<Plan>> plansFuture = _cachedPlanIdsKey == planIdsKey && _cachedPlans != null
        ? Future.value(_cachedPlans!)
        : _plans.getPlansByIds(planIds).then((list) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {
                _cachedPlanIdsKey = planIdsKey;
                _cachedPlans = list;
              });
            });
            return list;
          });

    return FutureBuilder<List<Plan>>(
      future: plansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(child: SizedBox(height: 300, child: _LoadingState(isDesktop: isDesktop)));
        }
        
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: WaypointEmptyState.error(
                message: 'Error loading plans: ${snapshot.error}',
                onRetry: () => setState(() {}),
              ),
            ),
          );
        }
        
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return SliverToBoxAdapter(child: SizedBox(height: 320, child: _EmptyTripsState()));
        }

        // Merge plans by id for quick lookup; only show trips that have a plan (avoids null + zero-height sliver children)
        final map = {for (final p in plans) p.id: p};
        final ownedTrips = trips.where((t) => t.isOwner(uid) && map[t.planId] != null).toList();
        final joinedTrips = trips.where((t) => !t.isOwner(uid) && map[t.planId] != null).toList();

        final listChildren = <Widget>[
          // Owned trips section
          ...ownedTrips.map((trip) {
            final plan = map[trip.planId]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HorizontalTripCard(trip: trip, plan: plan, userId: uid),
            );
          }),
        ];
        if (joinedTrips.isNotEmpty) {
          listChildren.addAll([
            const SizedBox(height: 24),
            _SectionLabel(
              title: "Trips I've Joined",
              subtitle:
                  '${joinedTrips.length} trip${joinedTrips.length != 1 ? 's' : ''} from others',
            ),
            const SizedBox(height: 12),
            ...joinedTrips.map((trip) {
              final plan = map[trip.planId]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HorizontalTripCard(trip: trip, plan: plan, userId: uid),
              );
            }),
          ]);
        }

        return SliverList(
          delegate: SliverChildListDelegate(listChildren),
        );
      },
    );
  }

  Widget _buildTripsGrid(BuildContext context, List<Trip> trips, Map<String, Plan> plansById, bool isDesktop, String userId) {
    // Deprecated: grid layout no longer used. Kept for reference.
    return const SizedBox.shrink();
  }
}

class _SignedOutState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Restricted Access',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This page is restricted to certain users. You need to apply to become a builder for now.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WaypointEmptyState(
      icon: Icons.backpack_outlined,
      title: 'No itineraries yet',
      description: 'Create your first personalized trip itinerary',
      actionLabel: 'Create Itinerary',
      onAction: () => context.go('/mytrips/create'),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final bool isDesktop;

  const _LoadingState({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    // Skeleton list loading state; constrained to avoid RenderFlex overflow
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          WaypointListItemSkeleton(),
          SizedBox(height: 12),
          WaypointListItemSkeleton(),
          SizedBox(height: 12),
          WaypointListItemSkeleton(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: BrandingLightTokens.formLabel,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: BrandingLightTokens.hint),
        ),
      ],
    );
  }
}
