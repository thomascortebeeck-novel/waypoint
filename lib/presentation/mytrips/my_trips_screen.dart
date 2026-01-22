import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/mytrips/widgets/itinerary_overview_card.dart';
import 'package:waypoint/presentation/mytrips/widgets/horizontal_trip_card.dart';
import 'package:waypoint/components/feedback/waypoint_skeleton.dart';
import 'package:waypoint/components/feedback/waypoint_empty_state.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final _auth = FirebaseAuthManager();
  final _trips = TripService();
  final _plans = PlanService();

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
              : (isDesktop
                  ? FloatingActionButton.extended(onPressed: () => context.go('/mytrips/create'), icon: const Icon(Icons.add), label: const Text('New Itinerary'))
                  : FloatingActionButton(onPressed: () => context.go('/mytrips/create'), child: const Icon(Icons.add))),
          body: CustomScrollView(slivers: [
            _buildHeader(context, isDesktop),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
              sliver: uid == null 
                  ? SliverToBoxAdapter(child: _SignedOutState()) 
                  : StreamBuilder<List<Trip>>(
                      stream: _trips.streamTripsForUser(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SliverToBoxAdapter(child: _LoadingState(isDesktop: isDesktop));
                        }
                        if (snapshot.hasError) {
                          return SliverToBoxAdapter(
                            child: WaypointEmptyState.error(
                              message: 'Error loading trips: ${snapshot.error}',
                              onRetry: () => setState(() {}),
                            ),
                          );
                        }
                        final trips = snapshot.data ?? [];
                        return _buildTripsContent(context, uid, isDesktop, trips);
                      },
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]),
        );
      }
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 160 : 130,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: context.colors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.primary.withValues(alpha: 0.08),
                context.colors.surface,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 24 : 16,
                isDesktop ? 32 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'My Trips',
                    style: context.textStyles.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your personalized trip plans',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed = constraints.biggest.height < 80;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                'My Trips',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripsContent(BuildContext context, String uid, bool isDesktop, List<Trip> trips) {
    if (trips.isEmpty) {
      return SliverToBoxAdapter(child: _EmptyTripsState());
    }

    // Get plans for these trips
    final planIds = trips.map((t) => t.planId).toSet().toList();
    
    return FutureBuilder<List<Plan>>(
      future: _plans.getPlansByIds(planIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(child: _LoadingState(isDesktop: isDesktop));
        }
        
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: WaypointEmptyState.error(
              message: 'Error loading plans: ${snapshot.error}',
              onRetry: () => setState(() {}),
            ),
          );
        }
        
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyTripsState());
        }

        // Merge plans by id for quick lookup
        final map = {for (final p in plans) p.id: p};
        
        // Separate trips by ownership
        final ownedTrips = trips.where((t) => t.isOwner(uid)).toList();
        final joinedTrips = trips.where((t) => !t.isOwner(uid)).toList();

        return SliverList(
          delegate: SliverChildListDelegate([
            // Owned trips section
            if (ownedTrips.isNotEmpty) ...[
              ...ownedTrips.map((trip) {
                final plan = map[trip.planId];
                if (plan == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HorizontalTripCard(trip: trip, plan: plan, userId: uid),
                );
              }),
            ],
            
            // Joined trips section
            if (joinedTrips.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Trips I\'ve Joined',
                subtitle: '${joinedTrips.length} trip${joinedTrips.length != 1 ? 's' : ''} from others',
                icon: Icons.group,
              ),
              const SizedBox(height: 12),
              ...joinedTrips.map((trip) {
                final plan = map[trip.planId];
                if (plan == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HorizontalTripCard(trip: trip, plan: plan, userId: uid),
                );
              }),
            ],
          ]),
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
    return WaypointEmptyState(
      icon: Icons.lock_outline,
      title: 'Sign in to view your itineraries',
      description: 'Create and manage your personalized trip plans',
      actionLabel: 'Go to Profile',
      onAction: () => context.go('/profile'),
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
    // Skeleton list loading state to match horizontal list layout
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: const [
        WaypointListItemSkeleton(),
        SizedBox(height: 16),
        WaypointListItemSkeleton(),
        SizedBox(height: 16),
        WaypointListItemSkeleton(),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: context.colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
