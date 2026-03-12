import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/core/constants/breakpoints.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/presentation/mytrips/widgets/horizontal_trip_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/services/follow_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/utils/plan_display_utils.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';
import 'package:waypoint/presentation/marketplace/marketplace_components.dart'
    show ActivityCard, ActivityCircle, ActivityItem, PromoCard, PromoVariant, TestimonialsSection, UspStepsSection;

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _planService = PlanService();
  final _tripService = TripService();
  final _userService = UserService();
  final _followService = FollowService();
  final _auth = FirebaseAuthManager();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  Timer? _carouselTimer;
  List<Plan> _searchResults = [];
  bool _isSearching = false;
  final PageController _carouselController = PageController();
  final ValueNotifier<int> _carouselPageNotifier = ValueNotifier<int>(0);
  List<String> _locationSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _startCarouselAutoRotation();
  }

  void _startCarouselAutoRotation() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_carouselController.hasClients) return;
      final current = _carouselPageNotifier.value;
      final nextPage = current < 3 ? current + 1 : 0;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _carouselTimer?.cancel();
    _carouselPageNotifier.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;

    setState(() {
      _searchQuery = query;
    });

    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _locationSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Debounce location suggestions (300ms)
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchLocationSuggestions(query);
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    try {
      // Get all published plans and extract unique locations
      final allPlans = await _planService.getAllPlans();
      final lowerQuery = query.toLowerCase();
      
      // Filter locations that match the query
      final matchingLocations = allPlans
          .map((plan) => plan.location)
          .where((location) => location.toLowerCase().contains(lowerQuery))
          .toSet() // Remove duplicates
          .toList()
          ..sort(); // Sort alphabetically
      
      if (mounted && _searchQuery == query) {
        setState(() {
          _locationSuggestions = matchingLocations.take(10).toList();
          _showSuggestions = matchingLocations.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error fetching location suggestions: $e');
      if (mounted) {
        setState(() {
          _locationSuggestions = [];
          _showSuggestions = false;
        });
      }
    }
  }

  void _searchLocation(String location) {
    // Hide suggestions
    setState(() {
      _showSuggestions = false;
    });
    
    // Unfocus search bar
    _searchFocusNode.unfocus();
    
    // Navigate to search results page
    context.push('/search/location/${Uri.encodeComponent(location)}');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero + search bar overlapping bottom edge (50% on hero, 50% below)
          SliverToBoxAdapter(
            child: _buildHeroWithSearch(context, isDesktop, screenWidth),
          ),
          // Featured Travel Experts (above 3 USPs)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _CenteredSection(
                  child: _SwimmingLane(
                    title: 'Featured Travel Experts',
                    subtitle: 'Discover their hand-crafted adventures',
                    stream: _planService.streamFeaturedPlans(),
                    isDesktop: isDesktop,
                    onSeeAll: () => context.go('/explore'),
                  ),
                ),
                SizedBox(height: isDesktop ? 48 : 32),
              ],
            ),
          ),
          // 3-step USP section
          SliverToBoxAdapter(
            child: UspStepsSection(isDesktop: isDesktop),
          ),
          // Regular Content (search results handled by separate page)
          if (false) // Don't show inline search results anymore
            _buildSearchResults(context, isDesktop)
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Following Lane (only show if user is logged in and follows creators)
                  _FollowingLane(
                    auth: _auth,
                    planService: _planService,
                    followService: _followService,
                    isDesktop: isDesktop,
                  ),
                  SizedBox(height: isDesktop ? 48 : 32),
                  // Activity Categories - Full width with centered header
                  _buildExploreByActivitySection(context, isDesktop),
                  SizedBox(height: isDesktop ? 48 : 32),
                  _CenteredSection(
                    child: _SwimmingLane(
                      title: 'Discover More',
                      subtitle: 'Popular routes from our community',
                      stream: _planService.streamDiscoverPlans(),
                      isDesktop: isDesktop,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 48 : 32),
                  _CenteredSection(
                    child: PromoCard(
                      variant: PromoVariant.upgrade,
                      removeMargin: true,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 48 : 32),
                  _CenteredSection(
                    child: _YourPlansLane(
                      auth: _auth,
                      tripService: _tripService,
                      planService: _planService,
                      isDesktop: isDesktop,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 48 : 32),
                  TestimonialsSection(isDesktop: isDesktop),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroWithSearch(BuildContext context, bool isDesktop, double screenWidth) {
    final heroHeight = isDesktop ? 500.0 : 400.0;
    final searchBarHeight = isDesktop ? 64.0 : 56.0;
    final overlap = searchBarHeight / 2;
    return SizedBox(
      height: heroHeight + overlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _buildHeroCarousel(context, isDesktop, heroHeight),
          ),
          // Search bar: bottom aligned with Stack so 50% sits on hero, 50% below
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: searchBarHeight,
            child: Center(
              child: SizedBox(
                width: math.min(isDesktop ? 760 : 700, screenWidth - (isDesktop ? 96 : 32)),
                height: searchBarHeight,
                child: _buildSearchBar(context, isDesktop, inline: true, searchBarHeight: searchBarHeight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel(BuildContext context, bool isDesktop, [double? heroHeight]) {
    final height = heroHeight ?? (isDesktop ? 500.0 : 400.0);
    final carouselImages = [
      'https://images.unsplash.com/photo-1551632811-561732d1e306?w=1200',
      'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=1200',
      'https://images.unsplash.com/photo-1464207687429-7505649dae38?w=1200',
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=1200',
    ];

    return Container(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top gradient scrim for nav bar readability
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                ),
              ),
            ),
          ),
          // Image Carousel
          PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              _carouselPageNotifier.value = index;
            },
            itemCount: carouselImages.length,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: carouselImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: context.colors.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  color: context.colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.image_not_supported,
                    color: context.colors.onSurface.withValues(alpha: 0.3),
                    size: 48,
                  ),
                ),
              );
            },
          ),
          
          // Gradient Overlay for Text Readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          
          // Text Content Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Discover Your\nNext Adventure',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 48 : 32,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expert-curated routes for the wild at heart.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: isDesktop ? 18 : 14,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/explore'),
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandingLightTokens.appBarGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Explore Now'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/mytrips'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Your trips'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Carousel Indicators (ValueListenableBuilder so only dots rebuild, not whole screen)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<int>(
              valueListenable: _carouselPageNotifier,
              builder: (context, currentPage, _) =>
                  _buildCarouselIndicators(carouselImages.length, currentPage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicators(int count, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentPage == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildLogoRow(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Image.asset(
        'assets/images/logo-waypoint.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.terrain, color: context.colors.primary, size: 28),
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 32,
        vertical: isDesktop ? 40 : 32,
      ),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '500,000+', 'Routes'),
                _buildStatDivider(context),
                _buildStatItem(context, '90M+', 'Reviews'),
                _buildStatDivider(context),
                _buildStatItem(context, '2M+', 'Adventurers'),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatItem(context, '500,000+', 'Routes')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildStatItem(context, '90M+', 'Reviews')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatItem(context, '2M+', 'Adventurers'),
              ],
            ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.textStyles.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: context.colors.onSurface.withValues(alpha: 0.1),
    );
  }


  Widget _buildExploreByActivitySection(BuildContext context, bool isDesktop) {
    final horizontalPadding = isDesktop ? 48.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CenteredSection(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore by Activity',
                  style: context.textStyles.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Popular activities from our community',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isDesktop ? 280 : 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: horizontalPadding),
            itemCount: 6,
            separatorBuilder: (_, __) => SizedBox(width: isDesktop ? 20 : 14),
            itemBuilder: (context, index) {
              final activities = [
                ActivityItem(ActivityCategory.hiking, 'Hiking', 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=200'),
                ActivityItem(ActivityCategory.cycling, 'Cycling', 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=200'),
                ActivityItem(ActivityCategory.skis, 'Skiing', 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=200'),
                ActivityItem(ActivityCategory.climbing, 'Climbing', 'https://images.unsplash.com/photo-1522163182402-834f871fd851?w=200'),
                ActivityItem(ActivityCategory.cityTrips, 'City Trips', 'https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=200'),
                ActivityItem(ActivityCategory.tours, 'Tours', 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200'),
              ];
              final circleSize = isDesktop ? 200.0 : 92.0;
              final containerWidth = isDesktop ? 240.0 : 105.0;
              return ActivityCircle(
                activity: activities[index],
                circleSize: circleSize,
                containerWidth: containerWidth,
                onTap: () {
                  context.go('/explore?activity=${activities[index].category.name}');
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDesktop, {bool inline = false, double? searchBarHeight}) {
    return Container(
      margin: inline ? EdgeInsets.zero : EdgeInsets.symmetric(vertical: isDesktop ? 24 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: WaypointBreakpoints.contentMaxWidth),
          padding: EdgeInsets.symmetric(horizontal: inline ? 0 : (isDesktop ? 48 : 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inline)
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: WaypointSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    placeholder: 'Where to next …',
                    margin: EdgeInsets.zero,
                    height: searchBarHeight,
                    transparentBackground: true,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) _searchLocation(value.trim());
                    },
                    onClear: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                      setState(() {
                        _showSuggestions = false;
                        _locationSuggestions = [];
                      });
                    },
                  ),
                )
              else
                WaypointSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeholder: 'Where to next …',
                  margin: EdgeInsets.zero,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) _searchLocation(value.trim());
                  },
                  onClear: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    setState(() {
                      _showSuggestions = false;
                      _locationSuggestions = [];
                    });
                  },
                ),
              // Autocomplete Dropdown (hidden when inline to keep overlay height 52px)
              if (!inline && _showSuggestions && _locationSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _locationSuggestions.length,
                    itemBuilder: (context, index) {
                      final location = _locationSuggestions[index];
                      return ListTile(
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: context.colors.primary,
                          size: 20,
                        ),
                        title: Text(
                          location,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.colors.onSurface,
                          ),
                        ),
                        onTap: () => _searchLocation(location),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, bool isDesktop) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 16,
            ),
            child: Row(
              children: [
                Text(
                  'Search Results',
                  style: context.textStyles.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isSearching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '(${_searchResults.length})',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: context.colors.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try searching with different keywords',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _CenteredSection(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount;
                  double childAspectRatio;
                  if (width >= 1024) {
                    crossAxisCount = 3;
                    childAspectRatio = 0.75;
                  } else if (width >= 640) {
                    crossAxisCount = 2;
                    childAspectRatio = 0.75;
                  } else {
                    crossAxisCount = 1;
                    childAspectRatio = 0.8;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final plan = _searchResults[index];
                      return AdventureCard(
                        plan: plan,
                        variant: AdventureCardVariant.standard,
                        showFavoriteButton: true,
                        onTap: () {
                          context.push('/details/${plan.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Helper widget to center content with max-width constraint
class _CenteredSection extends StatelessWidget {
  const _CenteredSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: WaypointBreakpoints.contentMaxWidth),
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24),
        child: child,
      ),
    );
  }
}

class _SwimmingLane extends StatelessWidget {
  const _SwimmingLane({
    required this.title,
    this.subtitle,
    required this.stream,
    required this.isDesktop,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final Stream<List<Plan>> stream;
  final bool isDesktop;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, onSeeAll: onSeeAll),
        const SizedBox(height: 16),
        SizedBox(
          height: isDesktop ? 400 : 380,
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
    final cardWidth = isDesktop ? 300.0 : 280.0;
    final userService = UserService();

    return ListView.separated(
      padding: EdgeInsets.zero,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(width: 24),
      itemBuilder: (context, index) {
        final plan = plans[index];
        final tagLabels = activityTagLabelsForPlan(plan);
        return SizedBox(
          width: cardWidth,
          child: FutureBuilder(
            future: userService.getUserById(plan.creatorId),
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
                        placeholder: (_, __) => Container(color: context.colors.surfaceContainerHighest),
                        errorWidget: (_, __, ___) => Container(color: context.colors.surfaceContainerHighest, child: Icon(Icons.landscape_outlined, color: context.colors.onSurface.withValues(alpha: 0.5))),
                      )
                    : null,
                initials: [initialsStr],
                creatorAvatarUrl: creatorAvatarUrl,
                tagLabels: tagLabels,
                onTap: () => context.push('/details/${plan.id}'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero, // Padding handled by parent _CenteredSection
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 24),
      itemBuilder: (_, __) => SizedBox(
        width: isDesktop ? 300.0 : 280.0,
        child: const SkeletonAdventureCard(),
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
  _YourPlansLane({
    required this.auth,
    required this.tripService,
    required this.planService,
    required this.isDesktop,
  });

  final FirebaseAuthManager auth;
  final TripService tripService;
  final PlanService planService;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUserId;
    final cardWidth = isDesktop ? 320.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Your Recent Trips',
          subtitle: 'Quick access to your itineraries',
        ),
        const SizedBox(height: 16),
        if (userId == null)
          _buildSignedOutState(context)
        else
          SizedBox(
            height: isDesktop ? 230 : 220,
            child: StreamBuilder<List<Trip>>(
              stream: tripService.streamTripsForUser(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonLoader(context, cardWidth);
                }
                final trips = snapshot.data ?? [];
                if (trips.isEmpty) {
                  return _buildEmptyState(context);
                }
                final planIds = trips.map((t) => t.planId).toSet().toList();
                return FutureBuilder<List<Plan>>(
                  future: planService.getPlansByIds(planIds),
                  builder: (context, plansSnap) {
                    if (plansSnap.connectionState != ConnectionState.done || !plansSnap.hasData) {
                      return _buildSkeletonLoader(context, cardWidth);
                    }
                    final plans = plansSnap.data ?? [];
                    final planMap = {for (final p in plans) p.id: p};
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        final plan = planMap[trip.planId];
                        if (plan == null) return const SizedBox.shrink();
                        return SizedBox(
                          width: cardWidth,
                          child: HorizontalTripCard(
                            trip: trip,
                            plan: plan,
                            userId: userId,
                          ),
                        );
                      },
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
      padding: EdgeInsets.zero, // Padding handled by parent _CenteredSection
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (_, __) => SizedBox(
        width: cardWidth,
        child: const SkeletonAdventureCard(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.backpack_outlined,
            size: 40,
            color: context.colors.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No itineraries yet',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first trip from My Trips',
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

class _FollowingLane extends StatelessWidget {
  const _FollowingLane({
    required this.auth,
    required this.planService,
    required this.followService,
    required this.isDesktop,
  });

  final FirebaseAuthManager auth;
  final PlanService planService;
  final FollowService followService;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUserId;

    // Only show if user is logged in
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<String>>(
      stream: followService.streamFollowing(userId),
      builder: (context, followingSnapshot) {
        // Check if user follows any creators
        final followingIds = followingSnapshot.data ?? [];
        if (followingIds.isEmpty) {
          return const SizedBox.shrink(); // Hide section if no following
        }

        // Stream plans from feed
        return StreamBuilder<List<Plan>>(
          stream: planService.streamFeedPlans(userId),
          builder: (context, plansSnapshot) {
            final plans = plansSnapshot.data ?? [];

            // Hide section if no plans in feed
            if (plans.isEmpty && plansSnapshot.connectionState == ConnectionState.done) {
              return const SizedBox.shrink();
            }

            return _CenteredSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Your favorite creators',
                    subtitle: 'Latest adventures from creators you follow',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: isDesktop ? 380 : 350,
                    child: plansSnapshot.connectionState == ConnectionState.waiting
                        ? _buildSkeletonLoader(context)
                        : plans.isEmpty
                            ? _buildEmptyState(context)
                            : _buildCarousel(context, plans),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCarousel(BuildContext context, List<Plan> plans) {
    final cardWidth = isDesktop ? 300.0 : 280.0;

    return ListView.separated(
      padding: EdgeInsets.zero,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(width: 24),
      itemBuilder: (context, index) => SizedBox(
        width: cardWidth,
        child: AdventureCard(
          plan: plans[index],
          variant: AdventureCardVariant.standard,
          showFavoriteButton: true,
          onTap: () {
            context.push('/details/${plans[index].id}');
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 24),
      itemBuilder: (_, __) => SizedBox(
        width: isDesktop ? 300.0 : 280.0,
        child: const SkeletonAdventureCard(),
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
              Icons.person_outline,
              size: 40,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No new adventures yet',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Follow more creators to see their latest adventures here',
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
