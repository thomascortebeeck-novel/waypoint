import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/like_button.dart';
import 'package:waypoint/presentation/widgets/sign_in_bottom_sheet.dart';
import 'package:waypoint/services/favorite_service.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/review_service.dart';
import 'package:waypoint/models/review_model.dart';
import 'package:waypoint/theme.dart';

class PlanDetailsScreen extends StatefulWidget {
  final String planId;

  const PlanDetailsScreen({super.key, required this.planId});

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  final PlanService _planService = PlanService();
  final FavoriteService _favoriteService = FavoriteService();
  final OrderService _orderService = OrderService();
  final ReviewService _reviewService = ReviewService();
  Plan? plan;
  PlanVersion? selectedVersion;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyNav = false;
  bool _isDescriptionExpanded = false;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Optimistic updates for like button
  bool _isLikedOptimistic = false;
  int _favoriteCountOptimistic = 0;
  bool _hasPurchasedOptimistic = false;
  
  // Review data
  List<Review> _reviews = [];
  bool _canUserReview = false;
  bool _hasUserReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _scrollController.addListener(_handleScroll);
  }
  
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  
  bool get _isAuthenticated => _currentUserId != null;

  Future<void> _loadPlan() async {
    try {
      // Use loadFullPlan to properly load from subcollections
      final loadedPlan = await _planService.loadFullPlan(widget.planId);
      if (!mounted) return;
      
      setState(() {
        plan = loadedPlan;
        if (plan != null && plan!.versions.isNotEmpty) {
          selectedVersion = plan!.versions.first;
          _favoriteCountOptimistic = plan!.favoriteCount;
        }
        _isLoading = false;
      });
      
      // Load favorite and purchase status if authenticated
      if (_isAuthenticated && plan != null) {
        final isFavorited = await _favoriteService.isFavorited(_currentUserId!, plan!.id);
        final hasPurchased = await _orderService.hasPurchased(_currentUserId!, plan!.id);
        if (!mounted) return;
        setState(() {
          _isLikedOptimistic = isFavorited;
          _hasPurchasedOptimistic = hasPurchased;
        });
      }
      
      // Load reviews
      await _loadReviews();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load adventure details';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (plan == null) return;
    
    try {
      final reviews = await _reviewService.getReviewsForPlan(
        planId: plan!.id,
        limit: 5,
        sort: ReviewSortOption.mostRecent,
      );
      
      if (_isAuthenticated) {
        final canReview = await _reviewService.canUserReview(_currentUserId!, plan!.id);
        final hasReviewed = await _reviewService.hasUserReviewed(_currentUserId!, plan!.id);
        
        if (!mounted) return;
        setState(() {
          _reviews = reviews;
          _canUserReview = canReview;
          _hasUserReviewed = hasReviewed;
        });
      } else {
        if (!mounted) return;
        setState(() => _reviews = reviews);
      }
    } catch (e) {
      debugPrint('Failed to load reviews: $e');
    }
  }

  void _handleScroll() {
    final shouldShowNav = _scrollController.hasClients && _scrollController.offset > 400;
    if (shouldShowNav != _showStickyNav) {
      setState(() => _showStickyNav = shouldShowNav);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: context.colors.primary),
              const SizedBox(height: 16),
              Text('Loading adventure...', style: context.textStyles.bodyLarge),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (_errorMessage != null || plan == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Adventure not found',
                  style: context.textStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This adventure may have been removed or is no longer available.',
                  style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.explore),
                  label: const Text('Browse Adventures'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show empty versions state
    if (plan!.versions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No versions available',
                  style: context.textStyles.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'This adventure doesn\'t have any versions yet.',
                  style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show plan details
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeroSection(context),
              SliverToBoxAdapter(child: _buildQuickStatsBar(context)),
              SliverToBoxAdapter(child: _buildDescriptionSection(context)),
              SliverToBoxAdapter(child: _buildRouteMapSection(context)),
              SliverToBoxAdapter(child: _buildDaysCarousel(context)),
              SliverToBoxAdapter(child: _buildWaypointsSummary(context)),
              SliverToBoxAdapter(child: _buildVersionsSection(context)),
              SliverToBoxAdapter(child: _buildReviewsSection(context)),
              SliverToBoxAdapter(child: _buildFAQSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          if (_showStickyNav) _buildStickyNavBar(context),
        ],
      ),
      bottomSheet: _buildStickyBottomBar(context),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.5,
      pinned: false,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: LikeButton(
            isLiked: _isLikedOptimistic,
            likeCount: _favoriteCountOptimistic,
            onTap: _handleLikeToggle,
            size: 20,
            backgroundColor: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: _handleShare,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: plan!.heroImageUrl,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan!.name,
                    style: context.textStyles.displaySmall?.copyWith(
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan!.location,
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      shadows: [
                        const Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (selectedVersion?.difficulty != null && selectedVersion?.difficulty != Difficulty.none)
                        _buildBadge(
                          context,
                          _getDifficultyColor(selectedVersion?.difficulty),
                          selectedVersion?.difficulty.name.toUpperCase() ?? 'MODERATE',
                        ),
                      _buildBadge(
                        context,
                        Colors.white.withValues(alpha: 0.3),
                        '${selectedVersion?.durationDays ?? 0} days',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsBar(BuildContext context) {
    final totalDistance = selectedVersion?.days.fold<double>(
      0.0,
      (sum, day) => sum + (day.route?.distance ?? 0),
    ) ?? 0.0;
    final totalElevation = selectedVersion?.days.fold<double>(
      0.0,
      (sum, day) => sum + (day.route?.ascent ?? 0),
    ) ?? 0.0;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.outline, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final showDifficulty = selectedVersion?.difficulty != null && selectedVersion?.difficulty != Difficulty.none;
          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatItem(context, Icons.route, '${(totalDistance / 1000).toStringAsFixed(1)} km', 'Distance')),
                    Expanded(child: _buildStatItem(context, Icons.access_time, '${selectedVersion?.durationDays ?? 0} days', 'Duration')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatItem(context, Icons.terrain, '${totalElevation.toStringAsFixed(0)} m', 'Elevation')),
                    if (showDifficulty)
                      Expanded(child: _buildStatItem(context, Icons.speed, selectedVersion!.difficulty.name.toUpperCase(), 'Difficulty')),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(context, Icons.route, '${(totalDistance / 1000).toStringAsFixed(1)} km', 'Distance'),
                Container(width: 1, height: 40, color: context.colors.outline),
                _buildStatItem(context, Icons.access_time, '${selectedVersion?.durationDays ?? 0} days', 'Duration'),
                Container(width: 1, height: 40, color: context.colors.outline),
                _buildStatItem(context, Icons.terrain, '${totalElevation.toStringAsFixed(0)} m', 'Elevation'),
                if (showDifficulty) ...[
                  Container(width: 1, height: 40, color: context.colors.outline),
                  _buildStatItem(context, Icons.speed, selectedVersion!.difficulty.name.toUpperCase(), 'Difficulty'),
                ],
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildStickyNavBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _showStickyNav ? Offset.zero : const Offset(0, -1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showStickyNav ? 1.0 : 0.0,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.2),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      plan!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: _handleShare,
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: Icon(
                      _isLikedOptimistic ? Icons.favorite : Icons.favorite_border,
                      color: _isLikedOptimistic ? Colors.red : null,
                    ),
                    onPressed: _handleLikeToggle,
                    tooltip: _isLikedOptimistic ? 'Unlike' : 'Like',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: context.colors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    final hasMultipleParagraphs = plan!.description.contains('\n\n') || plan!.description.length > 200;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About this adventure', style: context.textStyles.headlineSmall),
              const SizedBox(height: 12),
              // Desktop/Tablet: Show full description always
              // Mobile: Show expandable description
              if (!isMobile)
                MarkdownBody(
                  data: plan!.description,
                  styleSheet: MarkdownStyleSheet(
                    p: context.textStyles.bodyLarge?.copyWith(height: 1.7),
                    strong: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    em: context.textStyles.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                  ),
                )
              else
                _isDescriptionExpanded
                    ? MarkdownBody(
                        data: plan!.description,
                        styleSheet: MarkdownStyleSheet(
                          p: context.textStyles.bodyLarge?.copyWith(height: 1.7),
                          strong: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          em: context.textStyles.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      )
                    : MarkdownBody(
                        data: _truncateMarkdown(plan!.description, 200),
                        styleSheet: MarkdownStyleSheet(
                          p: context.textStyles.bodyLarge?.copyWith(height: 1.7),
                          strong: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          em: context.textStyles.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
              if (isMobile && hasMultipleParagraphs) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDescriptionExpanded ? 'Show less' : 'Read more',
                    style: context.textStyles.labelLarge?.copyWith(color: context.colors.primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: context.colors.primary,
                  ),
                ],
              ),
            ),
          ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _truncateMarkdown(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final truncated = text.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    return lastSpace > 0 ? '${truncated.substring(0, lastSpace)}...' : '$truncated...';
  }

  Widget _buildWaypointsSummary(BuildContext context) {
    if (selectedVersion == null) return const SizedBox.shrink();

    final waypointCounts = _getWaypointCounts(selectedVersion!);
    if (waypointCounts.isEmpty) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("What's included", style: context.textStyles.headlineSmall),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                  return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildWaypointCard(context, Icons.restaurant, 'Restaurants', waypointCounts['restaurants'] ?? 0, Colors.pink),
                  _buildWaypointCard(context, Icons.hotel, 'Accommodations', waypointCounts['accommodations'] ?? 0, Colors.purple),
                  _buildWaypointCard(context, Icons.local_activity, 'Activities', waypointCounts['activities'] ?? 0, Colors.blue),
                    _buildWaypointCard(context, Icons.photo_camera, 'Waypoints', waypointCounts['waypoints'] ?? 0, Colors.cyan),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildWaypointCard(BuildContext context, IconData icon, String label, int count, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.outline),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMapSection(BuildContext context) {
    if (selectedVersion == null) return const SizedBox.shrink();

    // Check if we have route coordinates
    final allCoordinates = _getAllRouteCoordinates();
    if (allCoordinates.isEmpty) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Route Overview', style: context.textStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Preview of the complete trail',
                style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildStaticMap(allCoordinates),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _getAllRouteCoordinates() {
    final coordinates = <LatLng>[];
    if (selectedVersion == null) return coordinates;

    for (final day in selectedVersion!.days) {
      if (day.route != null && day.route!.routePoints.isNotEmpty) {
        for (final point in day.route!.routePoints) {
          final lat = point['lat'];
          final lng = point['lng'];
          if (lat != null && lng != null) {
            coordinates.add(LatLng(lat, lng));
          }
        }
      }
    }

    return coordinates;
  }

  Widget _buildStaticMap(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Route map not available',
              style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calculate bounds
    final bounds = _calculateBounds(coordinates);
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: _calculateZoomLevel(bounds),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
          userAgentPackageName: 'com.waypoint.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: coordinates,
              strokeWidth: 4.0,
              color: context.colors.primary,
            ),
          ],
        ),
        // Start marker
        if (coordinates.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: coordinates.first,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 16),
                ),
              ),
              Marker(
                point: coordinates.last,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
      ],
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> coordinates) {
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  double _calculateZoomLevel(LatLngBounds bounds) {
    // Calculate appropriate zoom level based on bounds
    final latDiff = bounds.north - bounds.south;
    final lngDiff = bounds.east - bounds.west;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Rough zoom level calculation
    if (maxDiff > 10) return 5;
    if (maxDiff > 5) return 6;
    if (maxDiff > 2) return 7;
    if (maxDiff > 1) return 8;
    if (maxDiff > 0.5) return 9;
    if (maxDiff > 0.25) return 10;
    if (maxDiff > 0.1) return 11;
    return 12;
  }

  Widget _buildDaysCarousel(BuildContext context) {
    if (selectedVersion == null) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The itinerary', style: context.textStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${selectedVersion!.days.length} days of adventure through ${plan!.location}',
                style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 380,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedVersion!.days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 20),
                  itemBuilder: (context, index) => _buildDayCard(context, selectedVersion!.days[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, DayItinerary day) {
    final imageUrl = day.photos.isNotEmpty
        ? day.photos.first
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800';

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Day ${day.dayNum}',
                    style: context.textStyles.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.title,
                    style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${day.distanceKm.toStringAsFixed(1)} km',
                        style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${(day.estimatedTimeMinutes / 60).toStringAsFixed(0)}h',
                        style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (day.route != null && day.route!.ascent != null)
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '+${day.route!.ascent!.toStringAsFixed(0)}m',
                          style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionsSection(BuildContext context) {
    // Hide version section if only 1 version
    if (plan!.versions.length <= 1) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select your adventure', style: context.textStyles.headlineSmall),
              const SizedBox(height: 16),
              SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan!.versions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final version = plan!.versions[index];
                  final isSelected = selectedVersion == version;
                  return _buildVersionCard(version, isSelected);
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildVersionCard(PlanVersion version, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => selectedVersion = version),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primaryContainer : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? context.colors.onPrimaryContainer : context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${version.durationDays} Days',
                  style: context.textStyles.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (version.comfortType != ComfortType.none)
                  Icon(
                    version.comfortType == ComfortType.comfort
                        ? FontAwesomeIcons.bed
                        : FontAwesomeIcons.campground,
                    size: 16,
                    color: isSelected ? context.colors.primary : Colors.grey,
                  )
                else
                  const SizedBox.shrink(),
                if (version.difficulty != Difficulty.none)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(version.difficulty).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      version.difficulty.name.toUpperCase(),
                      style: context.textStyles.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyColor(version.difficulty),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final reviewStats = plan?.reviewStats ?? ReviewStats.empty();
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reviews', style: context.textStyles.headlineSmall),
                      if (reviewStats.totalReviews > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                final rating = reviewStats.averageRating;
                                if (index < rating.floor()) {
                                  return Icon(Icons.star, size: 18, color: Colors.amber.shade600);
                                } else if (index < rating) {
                                  return Icon(Icons.star_half, size: 18, color: Colors.amber.shade600);
                                } else {
                                  return Icon(Icons.star_border, size: 18, color: Colors.grey.shade400);
                                }
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${reviewStats.averageRating.toStringAsFixed(1)} (${reviewStats.totalReviews} review${reviewStats.totalReviews != 1 ? 's' : ''})',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (_isAuthenticated && _canUserReview && !_hasUserReviewed)
                    TextButton.icon(
                      onPressed: _showWriteReviewSheet,
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text('Write Review'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (_reviews.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_isAuthenticated && _canUserReview && !_hasUserReviewed) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to review this adventure!',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ..._reviews.map((review) => _ReviewCard(
                  review: review,
                  onHelpful: () => _handleReviewHelpful(review.id),
                  onReport: () => _handleReportReview(review.id),
                )),
              
              if (_reviews.length >= 5 && reviewStats.totalReviews > _reviews.length)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: TextButton(
                      onPressed: () => _showAllReviews(),
                      child: Text('View all ${reviewStats.totalReviews} reviews'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showWriteReviewSheet() {
    // TODO: Implement write review bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Write review feature coming soon')),
    );
  }
  
  Future<void> _handleReviewHelpful(String reviewId) async {
    if (!_isAuthenticated) {
      showModalBottomSheet(
        context: context,
        builder: (context) => const SignInBottomSheet(),
      );
      return;
    }
    
    try {
      await _reviewService.markHelpful(reviewId, _currentUserId!);
      await _loadReviews();
    } catch (e) {
      debugPrint('Failed to mark review helpful: $e');
    }
  }
  
  void _handleReportReview(String reviewId) {
    // TODO: Implement report review dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report feature coming soon')),
    );
  }
  
  void _showAllReviews() {
    // TODO: Navigate to full reviews screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('View all reviews coming soon')),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    if (selectedVersion == null || selectedVersion!.faqItems.isEmpty) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("FAQ's", style: context.textStyles.headlineSmall),
              const SizedBox(height: 16),
              ...selectedVersion!.faqItems.map((faq) => _buildFAQItem(context, faq)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, FAQItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.outline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: AppSpacing.paddingMd,
          childrenPadding: AppSpacing.paddingMd.copyWith(top: 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  size: 20,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  faq.question,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: MarkdownBody(
                data: faq.answer,
                styleSheet: MarkdownStyleSheet(
                  p: context.textStyles.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                  strong: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                  em: context.textStyles.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context) {
    if (selectedVersion == null) return const SizedBox.shrink();

    // Determine button text
    // Requirement: If NOT purchased => show "Unlock Plan" (free or paid)
    // If purchased => show "Start Adventure"
    final isFree = plan!.basePrice == 0;
    String buttonText = _hasPurchasedOptimistic ? 'Start Adventure' : 'Unlock Plan';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFree ? 'Free' : '€${plan!.basePrice.toStringAsFixed(0)}',
                    style: context.textStyles.headlineMedium?.copyWith(
                      color: isFree ? Colors.green.shade700 : context.colors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'All ${plan!.versions.length} version${plan!.versions.length != 1 ? 's' : ''} included',
                    style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  if (_hasPurchasedOptimistic) {
                    // Purchased: start a new itinerary for this plan
                    context.go('/itinerary/${plan!.id}/new');
                  } else {
                    // Not purchased: go through checkout (free or paid)
                    _handleCheckout();
                  }
                },
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, Color backgroundColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: context.textStyles.labelLarge?.copyWith(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getDifficultyColor(Difficulty? difficulty) {
    switch (difficulty) {
      case Difficulty.none:
        return Colors.grey;
      case Difficulty.easy:
        return const Color(0xFF4CAF50);
      case Difficulty.moderate:
        return const Color(0xFFFF9800);
      case Difficulty.hard:
        return const Color(0xFFF44336);
      case Difficulty.extreme:
        return const Color(0xFF212121);
      default:
        return const Color(0xFFFF9800);
    }
  }

  Map<String, int> _getWaypointCounts(PlanVersion version) {
    int restaurants = 0;
    int accommodations = 0;
    int activities = 0;
    int waypoints = 0;

    for (final day in version.days) {
      restaurants += day.restaurants.length;
      accommodations += day.accommodations.length;
      activities += day.activities.length;
      waypoints += (day.route?.waypoints.length ?? 0);
    }

    return {
      'restaurants': restaurants,
      'accommodations': accommodations,
      'activities': activities,
      'waypoints': waypoints,
    };
  }

  double _estimatedStayCost(PlanVersion version) {
    double total = 0;
    for (final day in version.days) {
      if (day.stay?.cost != null) total += day.stay!.cost!;
    }
    return total;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  /// Handle like button tap with auth guard and optimistic updates
  Future<void> _handleLikeToggle() async {
    if (!_isAuthenticated) {
      // Show sign-in prompt
      await SignInBottomSheet.show(
        context,
        title: 'Save Your Favorites',
        message: 'Sign in to save this adventure to your favorites and access it anytime.',
      );
      return;
    }
    
    if (plan == null) return;
    
    // Optimistic update
    setState(() {
      _isLikedOptimistic = !_isLikedOptimistic;
      _favoriteCountOptimistic = _isLikedOptimistic 
          ? _favoriteCountOptimistic + 1 
          : _favoriteCountOptimistic - 1;
    });
    
    try {
      // Perform the actual toggle
      final newStatus = await _favoriteService.toggleFavorite(_currentUserId!, plan!.id);
      
      // Reload plan to get accurate favorite count
      final updatedPlan = await _planService.loadFullPlan(plan!.id);
      if (!mounted) return;
      
      if (updatedPlan != null) {
        setState(() {
          plan = updatedPlan;
          _isLikedOptimistic = newStatus;
          _favoriteCountOptimistic = updatedPlan.favoriteCount;
        });
      }
    } catch (e) {
      // Revert optimistic update on error
      if (!mounted) return;
      setState(() {
        _isLikedOptimistic = !_isLikedOptimistic;
        _favoriteCountOptimistic = _isLikedOptimistic 
            ? _favoriteCountOptimistic + 1 
            : _favoriteCountOptimistic - 1;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update favorite. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Handle share button tap - show centered dialog
  Future<void> _handleShare() async {
    if (plan == null) return;
    await _showShareDialog(context, plan!);
  }
  
  /// Show share dialog as centered modal
  Future<void> _showShareDialog(BuildContext context, Plan plan) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 450,
          ),
          child: _ShareDialogContent(plan: plan),
        ),
      ),
    );
  }
  
  /// Handle checkout button tap - navigates to full-page checkout
  Future<void> _handleCheckout() async {
    if (!_isAuthenticated) {
      // Show sign-in prompt
      await SignInBottomSheet.show(
        context,
        title: 'Unlock This Adventure',
        message: 'Sign in to purchase and access the full adventure plan.',
      );
      return;
    }
    
    if (plan == null) return;
    
    // Navigate to full-page checkout
    context.push('/checkout/${plan!.id}', extra: {'plan': plan});
  }
}

/// Share dialog content widget
class _ShareDialogContent extends StatelessWidget {
  final Plan plan;

  const _ShareDialogContent({required this.plan});

  /// Get the base URL for sharing based on current environment
  static String get _baseUrl {
    if (kIsWeb) {
      // On web, use the current domain
      final uri = Uri.base;
      final baseUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
      return baseUrl;
    }
    // On mobile, use production URL
    return 'https://waypoint.app';
  }

  /// Generate the deep link URL for the plan
  String get shareUrl => '$_baseUrl/plan/${plan.id}';

  /// Generate share text
  String get shareText => '${plan.name}\n\n${plan.description.length > 100 ? '${plan.description.substring(0, 100)}...' : plan.description}\n\n$shareUrl';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Share Adventure',
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Plan preview card
          _buildPreviewCard(context),
          const SizedBox(height: 24),
          
          // Share options grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = isMobile ? 2 : 4;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _buildShareButton(
                    context,
                    icon: Icons.link,
                    label: 'Copy Link',
                    color: Colors.green,
                    onTap: () => _copyLink(context),
                  ),
                  _buildShareButton(
                    context,
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.blue,
                    onTap: () => _systemShare(context),
                  ),
                  _buildShareButton(
                    context,
                    icon: Icons.message,
                    label: 'SMS',
                    color: Colors.green.shade700,
                    onTap: () => _sendSms(context),
                  ),
                  _buildShareButton(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: Colors.orange,
                    onTap: () => _sendEmail(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: plan.heroImageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade300,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Plan info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        plan.location,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan.basePrice == 0 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : context.colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    plan.basePrice == 0 ? 'Free' : '€${plan.basePrice.toStringAsFixed(0)}',
                    style: context.textStyles.labelMedium?.copyWith(
                      color: plan.basePrice == 0 ? Colors.green.shade700 : context.colors.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: context.textStyles.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Link Copied!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _systemShare(BuildContext context) async {
    Navigator.pop(context);
    await Share.share(shareText);
  }

  Future<void> _sendSms(BuildContext context) async {
    Navigator.pop(context);
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': shareText},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    Navigator.pop(context);
    final uri = Uri(
      scheme: 'mailto',
      path: '',
      queryParameters: {
        'subject': 'Check out this adventure: ${plan.name}',
        'body': shareText,
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onHelpful;
  final VoidCallback onReport;

  const _ReviewCard({
    required this.review,
    required this.onHelpful,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and rating
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.colors.primaryContainer,
                backgroundImage: review.userAvatar != null
                    ? CachedNetworkImageProvider(review.userAvatar!)
                    : null,
                child: review.userAvatar == null
                    ? Text(
                        review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                        style: context.textStyles.titleMedium?.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.userName,
                          style: context.textStyles.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (review.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: context.colors.primary,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < review.rating ? Icons.star : Icons.star_border,
                              size: 14,
                              color: index < review.rating ? Colors.amber.shade600 : Colors.grey.shade400,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'report') onReport();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 18),
                        SizedBox(width: 8),
                        Text('Report'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (review.title != null) ...[
            const SizedBox(height: 12),
            Text(
              review.title!,
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            review.text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          
          // Photos
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: review.photos[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          
          // Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.onPrimaryContainer,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          
          // Actions
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onHelpful,
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: Text(
                  review.helpfulCount > 0
                      ? 'Helpful (${review.helpfulCount})'
                      : 'Helpful',
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }
}
