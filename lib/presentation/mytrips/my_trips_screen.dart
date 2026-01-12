import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/widgets/plan_card.dart';
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 160,
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
                      context.colors.primary.withValues(alpha: 0.1),
                      context.colors.surface,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'My Adventures',
                        style: context.textStyles.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your planned trips and itineraries',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: context.colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final isCollapsed = constraints.biggest.height < 80;
                  return Opacity(
                    opacity: isCollapsed ? 1.0 : 0.0,
                    child: Text(
                      'My Adventures',
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: AppSpacing.paddingMd,
            sliver: uid == null
                ? SliverToBoxAdapter(child: _signedOut(context))
                : _buildTripsGrid(context, uid),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsGrid(BuildContext context, String uid) {
    return StreamBuilder<List<Trip>>(
      stream: _trips.streamTripsForUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
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

        final trips = snapshot.data ?? [];
        if (trips.isEmpty) {
          return SliverToBoxAdapter(child: _emptyState(context));
        }

        // Get unique plan IDs from trips
        final planIds = trips.map((t) => t.planId).toSet().toList();

        return FutureBuilder<List<Plan>>(
          future: _plans.getPlansByIds(planIds),
          builder: (context, plansSnapshot) {
            if (!plansSnapshot.hasData) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading plans...',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final plans = plansSnapshot.data ?? [];
            if (plans.isEmpty) {
              return SliverToBoxAdapter(child: _emptyState(context));
            }

            // Use responsive grid
            return SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
                final cardHeight = 280.0;
                final aspectRatio = (width / crossAxisCount - 16) / cardHeight;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final plan = plans[index];
                      return PlanCard(
                        plan: plan,
                        onTap: () => context.go('/itinerary/${plan.id}'),
                      );
                    },
                    childCount: plans.length,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _signedOut(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 56, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to track your adventures',
              style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Access your active trips, track progress, and manage your packing lists',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.login),
              label: const Text('Go to Profile'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ]),
        ),
      );

  Widget _emptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.backpack_outlined, size: 56, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Start your first adventure',
              style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Browse expertly crafted routes and begin tracking your journey today',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Adventures'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ]),
        ),
      );
}
