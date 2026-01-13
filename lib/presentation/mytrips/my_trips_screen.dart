import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
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
    final uid = _auth.currentUserId;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, isDesktop),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 8,
            ),
            sliver: uid == null
                ? SliverToBoxAdapter(child: _SignedOutState())
                : _buildTripsContent(context, uid, isDesktop),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 140 : 120,
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
                    'Your planned trips and itineraries',
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

  Widget _buildTripsContent(BuildContext context, String uid, bool isDesktop) {
    return StreamBuilder<List<Trip>>(
      stream: _trips.streamTripsForUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: _LoadingState(isDesktop: isDesktop),
          );
        }

        final trips = snapshot.data ?? [];
        if (trips.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyTripsState());
        }

        final planIds = trips.map((t) => t.planId).toSet().toList();

        return FutureBuilder<List<Plan>>(
          future: _plans.getPlansByIds(planIds),
          builder: (context, plansSnapshot) {
            if (!plansSnapshot.hasData) {
              return SliverToBoxAdapter(
                child: _LoadingState(isDesktop: isDesktop),
              );
            }

            final plans = plansSnapshot.data ?? [];
            if (plans.isEmpty) {
              return SliverToBoxAdapter(child: _EmptyTripsState());
            }

            return _buildTripsGrid(context, plans, isDesktop);
          },
        );
      },
    );
  }

  Widget _buildTripsGrid(BuildContext context, List<Plan> plans, bool isDesktop) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final crossAxisCount = width > 1200 ? 3 : (width > 700 ? 2 : 1);
        final aspectRatio = crossAxisCount == 1 ? 16 / 12 : 4 / 5;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: aspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final plan = plans[index];
              return AdventureCard(
                plan: plan,
                variant: AdventureCardVariant.fullWidth,
                onTap: () => context.go('/itinerary/${plan.id}'),
              );
            },
            childCount: plans.length,
          ),
        );
      },
    );
  }
}

class _SignedOutState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: 'Sign in to track your adventures',
      subtitle: 'Access your active trips, track progress, and manage your packing lists',
      actionLabel: 'Go to Profile',
      onAction: () => context.go('/profile'),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.backpack_outlined,
      title: 'Start your first adventure',
      subtitle: 'Browse expertly crafted routes and begin tracking your journey today',
      actionLabel: 'Explore Adventures',
      onAction: () => context.go('/'),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final bool isDesktop;

  const _LoadingState({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your adventures...',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
