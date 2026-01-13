import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context, isDesktop),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _SwimmingLane(
                  title: 'Featured Adventures',
                  subtitle: 'Hand-picked by experts',
                  stream: _planService.streamFeaturedPlans(),
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 8),
                _SwimmingLane(
                  title: 'Discover More',
                  subtitle: 'Popular routes from our community',
                  stream: _planService.streamDiscoverPlans(),
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 8),
                _YourPlansLane(
                  auth: _auth,
                  userService: _userService,
                  planService: _planService,
                  isDesktop: isDesktop,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, bool isDesktop) {
    final heroHeight = isDesktop ? 0.45 : 0.38;
    final maxHeight = isDesktop ? 420.0 : 340.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final calculatedHeight = (screenHeight * heroHeight).clamp(280.0, maxHeight);

    return SliverAppBar(
      expandedHeight: calculatedHeight,
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
                context.colors.primary.withValues(alpha: 0.15),
                context.colors.primaryContainer.withValues(alpha: 0.08),
                context.colors.surface,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 32 : 24,
                isDesktop ? 32 : 20,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDesktop) ...[
                    _buildLogoRow(context),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],
                  Text(
                    'Discover Your\nNext Adventure',
                    style: context.textStyles.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Expert-guided treks, detailed itineraries,\nand offline maps for your journey',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.65),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed = constraints.biggest.height < 100;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: isDesktop
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        Icon(Icons.terrain, color: context.colors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'WAYPOINT',
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: context.colors.onSurface,
          ),
          tooltip: 'Search',
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLogoRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.terrain, color: context.colors.primary, size: 28),
        const SizedBox(width: 8),
        Text(
          'WAYPOINT',
          style: context.textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: context.colors.primary,
          ),
        ),
      ],
    );
  }
}

class _SwimmingLane extends StatelessWidget {
  const _SwimmingLane({
    required this.title,
    this.subtitle,
    required this.stream,
    required this.isDesktop,
  });

  final String title;
  final String? subtitle;
  final Stream<List<Plan>> stream;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 16),
        SizedBox(
          height: isDesktop ? 280 : 260,
          child: StreamBuilder<List<Plan>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonLoader(context);
              }
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildCarousel(context, plans);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCarousel(BuildContext context, List<Plan> plans) {
    final cardWidth = isDesktop ? 280.0 : 260.0;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) => SizedBox(
        width: cardWidth,
        child: AdventureCard(
          plan: plans[index],
          variant: AdventureCardVariant.standard,
          showFavoriteButton: !plans[index].isFeatured,
          onTap: () => context.push('/details/${plans[index].id}'),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (_, __) => SizedBox(
        width: isDesktop ? 280.0 : 260.0,
        child: const SkeletonAdventureCard(variant: AdventureCardVariant.standard),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 40,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No adventures yet',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to discover amazing trails',
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

class _YourPlansLane extends StatelessWidget {
  const _YourPlansLane({
    required this.auth,
    required this.userService,
    required this.planService,
    required this.isDesktop,
  });

  final FirebaseAuthManager auth;
  final UserService userService;
  final PlanService planService;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUserId;
    final cardWidth = isDesktop ? 280.0 : 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Your Plans',
          subtitle: 'Quick access to your adventures',
        ),
        const SizedBox(height: 16),
        if (userId == null)
          _buildSignedOutState(context)
        else
          SizedBox(
            height: isDesktop ? 280 : 260,
            child: StreamBuilder(
              stream: userService.streamUser(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _buildSkeletonLoader(context, cardWidth);
                }
                final user = snapshot.data;
                final ids = <String>{
                  ...?user?.purchasedPlanIds,
                  ...?user?.invitedPlanIds,
                }.toList();
                if (ids.isEmpty) {
                  return _buildEmptyState(context);
                }
                return FutureBuilder<List<Plan>>(
                  future: planService.getPlansByIds(ids),
                  builder: (context, plansSnap) {
                    if (!plansSnap.hasData) {
                      return _buildSkeletonLoader(context, cardWidth);
                    }
                    final plans = plansSnap.data ?? [];
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: plans.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) => SizedBox(
                        width: cardWidth,
                        child: AdventureCard(
                          plan: plans[index],
                          variant: AdventureCardVariant.standard,
                          onTap: () => context.go('/itinerary/${plans[index].id}'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSignedOutState(BuildContext context) {
    return SizedBox(
      height: isDesktop ? 200 : 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 32,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view your plans',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Access your purchased and shared adventures',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.go('/profile'),
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context, double cardWidth) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (_, __) => SizedBox(
        width: cardWidth,
        child: const SkeletonAdventureCard(variant: AdventureCardVariant.standard),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 40,
            color: context.colors.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No adventures in your collection',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore the marketplace to find your next journey',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
