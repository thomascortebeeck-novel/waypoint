import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';
import 'package:waypoint/utils/plan_display_utils.dart';
import 'package:waypoint/utils/activity_icons.dart';
import 'package:waypoint/nav.dart' show kDesktopNavHeight;

/// Pinterest-style explore screen with masonry grid
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PlanService _planService = PlanService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Plan> _allPlans = [];
  List<Plan> _filteredPlans = [];
  bool _isLoading = true;
  ActivityCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_applyFilters);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always sync filter from URL when navigating from Home (e.g. /explore?activity=hiking).
    final activityName = GoRouterState.of(context).uri.queryParameters['activity'];
    if (activityName != null && activityName.isNotEmpty) {
      ActivityCategory? category;
      try {
        category = ActivityCategory.values.firstWhere((c) => c.name == activityName);
      } catch (_) {
        category = null;
      }
      if (category != null && _selectedCategory != category) {
        _selectedCategory = category;
        _applyFilters();
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plans = await _planService.getAllPlans();
      if (mounted) {
        setState(() {
          _allPlans = plans;
          _filteredPlans = plans;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load adventures: $e')),
        );
      }
    }
  }

  void _onScroll() {
    // Implement infinite scroll if needed
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more plans
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredPlans = _allPlans.where((plan) {
        if (query.isNotEmpty) {
          final matchesSearch = plan.name.toLowerCase().contains(query) ||
              plan.description.toLowerCase().contains(query) ||
              plan.location.toLowerCase().contains(query);
          if (!matchesSearch) return false;
        }
        if (_selectedCategory != null) {
          if (plan.activityCategory != _selectedCategory) return false;
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Depend on route so we rebuild when navigating with ?activity= (e.g. from Home).
    final _ = GoRouterState.of(context).uri;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final topPadding = isDesktop ? kDesktopNavHeight : MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaypointSearchBar(
            placeholder: 'Search destinations, trails, or activi…',
            showFilterIcon: true,
            controller: _searchController,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                WaypointCreamChip(
                  label: 'All',
                  selected: _selectedCategory == null,
                  prominent: true,
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _applyFilters();
                    });
                  },
                ),
                ...ActivityCategory.values.map((category) => WaypointCreamChip(
                  label: _getCategoryLabel(category),
                  selected: _selectedCategory == category,
                  prominent: true,
                  icon: _getCategoryIcon(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _applyFilters();
                    });
                  },
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPlans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.explore_off, size: 64, color: WaypointColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'No adventures found',
                              style: WaypointTypography.headlineSmall?.copyWith(color: WaypointColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filters',
                              style: WaypointTypography.bodyMedium?.copyWith(color: WaypointColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : MasonryGridView.count(
                        controller: _scrollController,
                        crossAxisCount: isDesktop ? 4 : 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredPlans.length,
                        itemBuilder: (context, index) {
                          final plan = _filteredPlans[index];
                          final tagLabels = activityTagLabelsForPlan(plan);
                          return FutureBuilder(
                            future: UserService().getUserById(plan.creatorId),
                            builder: (context, userSnap) {
                              final user = userSnap.data;
                              final creatorAvatarUrl = user?.photoUrl;
                              String initialsStr;
                              if (user != null &&
                                  user.firstName != null &&
                                  user.firstName!.isNotEmpty &&
                                  user.lastName != null &&
                                  user.lastName!.isNotEmpty) {
                                initialsStr = '${user.firstName![0]}${user.lastName![0]}'.toUpperCase();
                              } else {
                                final parts = plan.creatorName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
                                initialsStr = parts.isEmpty
                                    ? '?'
                                    : parts.length == 1
                                        ? parts.first[0].toUpperCase()
                                        : '${parts.first[0]}${parts.elementAt(1)[0]}'.toUpperCase();
                              }
                              return WaypointFeaturedPlanCard(
                                title: plan.name,
                                creatorName: plan.creatorName,
                                rating: plan.reviewStats?.averageRating ?? 0.0,
                                reviewCount: (plan.reviewStats?.totalReviews ?? 0) > 0 ? plan.reviewStats!.totalReviews : null,
                                price: plan.minPrice > 0 ? plan.minPrice : null,
                                location: plan.location.isNotEmpty ? plan.location : null,
                                isFree: plan.minPrice == 0,
                                imageWidget: plan.heroImageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: plan.heroImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: BrandingLightTokens.surface),
                                        errorWidget: (_, __, ___) => Container(
                                          color: BrandingLightTokens.surface,
                                          child: const Icon(Icons.landscape_outlined),
                                        ),
                                      )
                                    : null,
                                initials: [initialsStr],
                                creatorAvatarUrl: creatorAvatarUrl,
                                tagLabels: tagLabels,
                                onTap: () => context.push('/details/${plan.id}'),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
        ),
      ),
      floatingActionButton: WaypointFAB(
        heroTag: 'explore_map_fab',
        icon: Icons.map_outlined,
        label: 'Map View',
        onPressed: () {},
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  String _getCategoryLabel(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trips';
      case ActivityCategory.tours:
        return 'Tours';
      case ActivityCategory.roadTripping:
        return 'Road Trips';
    }
  }

  IconData _getCategoryIcon(ActivityCategory category) {
    return getActivityIconData(category);
  }
}
