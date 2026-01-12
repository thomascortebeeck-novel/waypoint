import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/plan_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _planService = PlanService();
  final _userService = UserService();
  final _auth = FirebaseAuthManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 280,
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
                      Row(
                        children: [
                          Icon(Icons.terrain, color: context.colors.primary, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            "WAYPOINT",
                            style: context.textStyles.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Discover Your Next Adventure",
                        style: context.textStyles.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Expert-guided treks, detailed itineraries, and offline maps for your journey",
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: context.colors.onSurface.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  // Only show title when collapsed (constraints.biggest.height is small)
                  final isCollapsed = constraints.biggest.height < 100;
                  return Opacity(
                    opacity: isCollapsed ? 1.0 : 0.0,
                    child: Text(
                      "WAYPOINT",
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () {},
              ),
            ],
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _LaneSection(
                  title: 'Featured Adventures',
                  subtitle: 'Hand-picked by experts',
                  stream: _planService.streamFeaturedPlans(),
                ),
                _LaneSection(
                  title: 'Discover More',
                  subtitle: 'Popular routes from our community',
                  stream: _planService.streamDiscoverPlans(),
                ),
                _YourPlansLane(
                  auth: _auth,
                  userService: _userService,
                  planService: _planService,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _YourPlansLane extends StatelessWidget {
  const _YourPlansLane({required this.auth, required this.userService, required this.planService});
  final FirebaseAuthManager auth;
  final UserService userService;
  final PlanService planService;

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUserId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Plans',
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quick access to your adventures',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (userId == null)
          _buildEmptyLaneState(
            context,
            icon: Icons.lock_outline,
            title: 'Sign in to view your plans',
            subtitle: 'Access your purchased and shared adventures',
            actionLabel: 'Go to Profile',
            onAction: () => context.go('/profile'),
          )
        else
          SizedBox(
            height: 280,
            child: StreamBuilder(
              stream: userService.streamUser(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _buildSkeletonLoader(context);
                }
                final user = snapshot.data;
                final ids = <String>{
                  ...?user?.purchasedPlanIds,
                  ...?user?.invitedPlanIds,
                }.toList();
                if (ids.isEmpty) {
                  return _buildEmptyLaneState(
                    context,
                    icon: Icons.add_circle_outline,
                    title: 'No adventures in your collection',
                    subtitle: 'Explore the marketplace to find your next journey',
                  );
                }
                return FutureBuilder<List<Plan>>(
                  future: planService.getPlansByIds(ids),
                  builder: (context, plansSnap) {
                    if (!plansSnap.hasData) {
                      return _buildSkeletonLoader(context);
                    }
                    final plans = plansSnap.data ?? [];
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: plans.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 240,
                        child: PlanCard(plan: plans[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Skeleton loader for async content
  Widget _buildSkeletonLoader(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => _SkeletonPlanCard(),
    );
  }

  /// Professional empty state for lane sections
  Widget _buildEmptyLaneState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: context.colors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader helper function
Widget _buildSkeletonLoader(BuildContext context) {
  return ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    scrollDirection: Axis.horizontal,
    itemCount: 3,
    separatorBuilder: (_, __) => const SizedBox(width: 12),
    itemBuilder: (_, __) => _SkeletonPlanCard(),
  );
}

/// Empty state helper function
Widget _buildEmptyLaneState(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: context.colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LaneSection extends StatelessWidget {
  const _LaneSection({required this.title, this.subtitle, required this.stream});
  final String title;
  final String? subtitle;
  final Stream<List<Plan>> stream;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: StreamBuilder<List<Plan>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonLoader(context);
              }
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                return _buildEmptyLaneState(
                  context,
                  icon: Icons.explore_outlined,
                  title: 'No adventures yet',
                  subtitle: 'Be the first to discover amazing trails',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 240,
                  child: PlanCard(plan: plans[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Animated skeleton card for loading states
class _SkeletonPlanCard extends StatefulWidget {
  @override
  State<_SkeletonPlanCard> createState() => _SkeletonPlanCardState();
}

class _SkeletonPlanCardState extends State<_SkeletonPlanCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: context.colors.surfaceContainerHighest.withValues(alpha: _animation.value),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location skeleton
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title skeleton
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 20,
                      width: 140,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Footer skeleton
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 24,
                          width: 60,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
