import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/plan_meta_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/presentation/widgets/like_button.dart';
import 'package:waypoint/presentation/widgets/sign_in_bottom_sheet.dart';
import 'package:waypoint/components/waypoint/unified_waypoint_card.dart';
import 'package:waypoint/components/builder/day_timeline_section.dart';
import 'package:waypoint/components/itinerary/timeline_itinerary_widget.dart';
import 'package:waypoint/utils/route_calculations.dart';
import 'package:waypoint/services/favorite_service.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/review_service.dart';
import 'package:waypoint/models/review_model.dart';
import 'package:waypoint/theme.dart';

enum DayViewTab { summary, map, waypoints }

/// @deprecated This screen is deprecated. Use [AdventureDetailScreen] with [AdventureMode.viewer] instead.
/// This file is kept for reference but should not be used in new code.
/// Migration: Replace `PlanDetailsScreen(planId: planId)` with `AdventureDetailScreen(mode: AdventureMode.viewer, planId: planId)`
@Deprecated('Use AdventureDetailScreen with AdventureMode.viewer instead')
class PlanDetailsScreen extends StatefulWidget {
final String planId;

const PlanDetailsScreen({super.key, required this.planId});

@override
State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> with SingleTickerProviderStateMixin {
final PlanService _planService = PlanService();
final FavoriteService _favoriteService = FavoriteService();
final OrderService _orderService = OrderService();
final ReviewService _reviewService = ReviewService();

// Plan metadata (lightweight, loaded first)
PlanMeta? _planMeta;
// Full plan data (for FAQ items at plan level)
Plan? plan;
// Selected version (fully loaded with days)
PlanVersion? selectedVersion;
// Version summaries for dropdown (lightweight)
List<VersionSummary> _versionSummaries = [];
// Selected version ID
String? _selectedVersionId;
// Cache for loaded versions (key: versionId, value: full PlanVersion)
final Map<String, PlanVersion> _versionCache = {};

bool _isLoading = true;
bool _isLoadingVersion = false; // Loading indicator for version switch
String? _errorMessage;

// Optimistic updates
bool _isLikedOptimistic = false;
int _favoriteCountOptimistic = 0;
bool _hasPurchasedOptimistic = false;

// Review data
List<Review> _reviews = [];
bool _canUserReview = false;
bool _hasUserReviewed = false;

// Tab controller for main tabs
late TabController _mainTabController;
int _currentMainTab = 0;

// Timeline state - accordion style
int? _expandedDayIndex; // null = all collapsed
DayViewTab _expandedDayTab = DayViewTab.summary; // Tab for expanded day

// Description expansion state
bool _isDescriptionExpanded = false;

// Performance caches
double? _cachedTotalDistance;
double? _cachedTotalElevation;
Map<String, FAQItem>? _cachedFaqMap;
Map<String, int>? _cachedWaypointCounts;

// Like toggle state
bool _isTogglingLike = false;

// FAQ lazy loading state
bool _faqDataLoaded = false;

// Scroll controller to track scroll position
final ScrollController _scrollController = ScrollController();
bool _showActionButtons = true;

@override
void initState() {
super.initState();
debugPrint('[PlanDetails] initState called with planId: "${widget.planId}"');
_mainTabController = TabController(length: 2, vsync: this);
_mainTabController.addListener(() {
final newIndex = _mainTabController.index;
setState(() => _currentMainTab = newIndex);
// Load FAQ data when user switches to Details tab
if (newIndex == 1 && !_faqDataLoaded) {
_loadPlanLevelData();
}
});

// Listen to scroll changes to hide/show action buttons
_scrollController.addListener(() {
final shouldShow = _scrollController.hasClients && _scrollController.offset < 200;
if (shouldShow != _showActionButtons) {
setState(() => _showActionButtons = shouldShow);
}
});

// Early validation - check for empty plan ID
if (widget.planId.isEmpty) {
debugPrint('[PlanDetails] ERROR: Empty planId provided!');
WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) {
setState(() {
_errorMessage = 'Invalid adventure link';
_isLoading = false;
});
}
});
return;
}

_loadPlan();

// Load reviews after main content (performance optimization)
// Skip scheduling if we already know planId is invalid
if (widget.planId.isNotEmpty) {
Future.delayed(const Duration(milliseconds: 500), () {
if (mounted) _loadReviews();
});
}
}

@override
void dispose() {
_mainTabController.dispose();
_scrollController.dispose();
super.dispose();
}

String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
bool get _isAuthenticated => _currentUserId != null;

/// Create a display-only Plan from PlanMeta (for UI when full plan not yet loaded)
Plan _createDisplayPlanFromMeta(PlanMeta meta) => Plan(
id: meta.id,
name: meta.name,
description: meta.description,
heroImageUrl: meta.heroImageUrl,
location: meta.location,
basePrice: meta.basePrice,
creatorId: meta.creatorId,
creatorName: meta.creatorName,
versions: [], // Versions loaded separately
isFeatured: meta.isFeatured,
isDiscover: meta.isDiscover,
isPublished: meta.isPublished,
favoriteCount: meta.favoriteCount,
salesCount: meta.salesCount,
createdAt: meta.createdAt,
updatedAt: meta.updatedAt,
faqItems: meta.faqItems,
activityCategory: meta.activityCategory,
accommodationType: meta.accommodationType,
);

Future<void> _loadPlan() async {
debugPrint('[PlanDetails] _loadPlan starting for planId: "${widget.planId}"');
try {
// Phase 1: Load lightweight metadata first (fast initial render)
final meta = await _planService.loadPlanMeta(widget.planId);
debugPrint('[PlanDetails] loadPlanMeta returned: ${meta?.name ?? "null"}');
if (!mounted) return;

if (meta == null) {
debugPrint('[PlanDetails] Plan metadata not found, showing error');
setState(() {
_errorMessage = 'Adventure not found';
_isLoading = false;
});
return;
}

// Store version summaries for dropdown
_versionSummaries = meta.versionSummaries;
_planMeta = meta;
_favoriteCountOptimistic = meta.favoriteCount;

// Phase 2: Load first version (this gives us day data)
if (_versionSummaries.isNotEmpty) {
await _loadVersion(_versionSummaries.first.id, isInitialLoad: true);
} else {
setState(() => _isLoading = false);
}

// Phase 3: Load auth-related data in background
if (_isAuthenticated) {
_loadAuthData();
}

// Phase 4: Load FAQ data ONLY if user is on Details tab
// Otherwise it will be loaded lazily when they switch to Details tab
if (_currentMainTab == 1) {
_loadPlanLevelData();
}
} catch (e) {
debugPrint('Error loading plan: $e');
if (!mounted) return;
setState(() {
_errorMessage = 'Failed to load adventure details';
_isLoading = false;
});
}
}

/// Load FAQ items and other plan-level data lazily (only when Details tab is viewed)
Future<void> _loadPlanLevelData() async {
if (_faqDataLoaded) return; // Already loaded

try {
final fullPlan = await _planService.loadFullPlan(widget.planId);
if (!mounted) return;

if (fullPlan != null) {
setState(() {
plan = fullPlan;
// Reset FAQ cache since we have new data
_cachedFaqMap = null;
_faqDataLoaded = true;
});

// If no version loaded yet (legacy plans), use embedded version
if (selectedVersion == null && fullPlan.versions.isNotEmpty) {
setState(() {
selectedVersion = fullPlan.versions.first;
_selectedVersionId = fullPlan.versions.first.id;
_isLoading = false;
});
}
}
} catch (e) {
debugPrint('Error loading plan-level data: $e');
}
}

/// Load auth-related data (favorites, purchases) in background
Future<void> _loadAuthData() async {
if (!_isAuthenticated || _planMeta == null) return;

try {
final isFavorited = await _favoriteService.isFavorited(_currentUserId!, _planMeta!.id);
final hasPurchased = await _orderService.hasPurchased(_currentUserId!, _planMeta!.id);
if (!mounted) return;
setState(() {
_isLikedOptimistic = isFavorited;
_hasPurchasedOptimistic = hasPurchased;
});
} catch (e) {
debugPrint('Error loading auth data: $e');
}
}

/// Load a specific version (with caching)
Future<void> _loadVersion(String versionId, {bool isInitialLoad = false}) async {
if (_selectedVersionId == versionId && selectedVersion != null && !isInitialLoad) {
return; // Already loaded
}

// Check cache first
if (_versionCache.containsKey(versionId)) {
setState(() {
selectedVersion = _versionCache[versionId];
_selectedVersionId = versionId;
_expandedDayIndex = null;
_cachedTotalDistance = null;
_cachedTotalElevation = null;
_cachedFaqMap = null;
_cachedWaypointCounts = null;
if (isInitialLoad) _isLoading = false;
_isLoadingVersion = false;
});
return;
}

// Show loading indicator for version switch (not initial load)
if (!isInitialLoad) {
setState(() => _isLoadingVersion = true);
}

try {
final version = await _planService.loadFullVersion(widget.planId, versionId);
if (!mounted) return;

if (version != null) {
// Cache the loaded version
_versionCache[versionId] = version;

setState(() {
selectedVersion = version;
_selectedVersionId = versionId;
_expandedDayIndex = null;
_cachedTotalDistance = null;
_cachedTotalElevation = null;
_cachedFaqMap = null;
_cachedWaypointCounts = null;
if (isInitialLoad) _isLoading = false;
_isLoadingVersion = false;
});
} else if (plan != null && plan!.versions.isNotEmpty) {
// Fallback: use embedded version from full plan
final embeddedVersion = plan!.versions.firstWhere(
(v) => v.id == versionId,
orElse: () => plan!.versions.first,
);
_versionCache[embeddedVersion.id] = embeddedVersion;

setState(() {
selectedVersion = embeddedVersion;
_selectedVersionId = embeddedVersion.id;
_expandedDayIndex = null;
_cachedTotalDistance = null;
_cachedTotalElevation = null;
_cachedFaqMap = null;
_cachedWaypointCounts = null;
if (isInitialLoad) _isLoading = false;
_isLoadingVersion = false;
});
} else {
setState(() {
if (isInitialLoad) _isLoading = false;
_isLoadingVersion = false;
});
}
} catch (e) {
debugPrint('Error loading version: $e');
if (!mounted) return;

// Show error but keep previous version visible
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Text('Failed to load version'),
backgroundColor: Colors.red.shade700,
behavior: SnackBarBehavior.floating,
),
);

setState(() {
if (isInitialLoad) _isLoading = false;
_isLoadingVersion = false;
});
}
}

Future<void> _loadReviews() async {
final planId = _effectivePlanId;
if (planId.isEmpty) return;

try {
final reviews = await _reviewService.getReviewsForPlan(
planId: planId,
limit: 5,
sort: ReviewSortOption.mostRecent,
);

if (_isAuthenticated) {
final canReview = await _reviewService.canUserReview(_currentUserId!, planId);
final hasReviewed = await _reviewService.hasUserReviewed(_currentUserId!, planId);

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

Color get _primary => BrandColors.primary; // #2D6A4F - Primary green
Color get _primaryLight => BrandColors.primaryContainerLight.withValues(alpha: 0.3); // Light green background
Color get _primaryDark => BrandColors.tertiaryDarkGreen; // Dark green for accents
Color get _surface => Colors.white;
Color get _background => const Color(0xFFF9FAFB);
Color get _border => const Color(0xFFE5E7EB);
Color get _borderLight => const Color(0xFFF3F4F6);
Color get _textPrimary => const Color(0xFF111827);
Color get _textSecondary => const Color(0xFF6B7280);
Color get _textMuted => const Color(0xFF9CA3AF);

@override
Widget build(BuildContext context) {
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

// Use planMeta for display when plan is still loading
final displayPlan = plan ?? (_planMeta != null ? _createDisplayPlanFromMeta(_planMeta!) : null);

if (_errorMessage != null || (displayPlan == null && _planMeta == null)) {
return Scaffold(
appBar: AppBar(
leading: IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: () => context.pop(),
),
),
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
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

// Check if no versions available
final hasVersions = _versionSummaries.isNotEmpty || (plan?.versions.isNotEmpty ?? false);
if (!hasVersions) {
return Scaffold(
appBar: AppBar(
leading: IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: () => context.pop(),
),
),
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
const SizedBox(height: 16),
Text('No versions available', style: context.textStyles.headlineSmall),
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

// Error boundary: Handle case where version failed to load
if (selectedVersion == null && !_isLoading && !_isLoadingVersion) {
return _buildVersionLoadError();
}

return Scaffold(
body: NestedScrollView(
controller: _scrollController,
headerSliverBuilder: (context, innerBoxIsScrolled) {
return [
SliverAppBar(
expandedHeight: 300,
floating: false,
pinned: true,
stretch: true,
toolbarHeight: 0,
backgroundColor: Colors.white,
surfaceTintColor: Colors.transparent,
automaticallyImplyLeading: false,
flexibleSpace: FlexibleSpaceBar(
background: Stack(
children: [
_buildHeroBackground(context),
// Action buttons overlaid on the hero image
if (_showActionButtons)
SafeArea(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
_buildActionButton(
icon: Icons.arrow_back,
onPressed: () => context.pop(),
),
Row(
children: [
_buildActionButton(
icon: _isLikedOptimistic ? Icons.favorite : Icons.favorite_border,
color: _isLikedOptimistic ? Colors.red : null,
onPressed: _handleLikeToggle,
),
const SizedBox(width: 12),
_buildActionButton(
icon: Icons.ios_share,
onPressed: _handleShare,
),
const SizedBox(width: 12),
],
),
],
),
),
),
],
),
collapseMode: CollapseMode.parallax,
),
bottom: PreferredSize(
preferredSize: const Size.fromHeight(52),
child: _buildTabBar(context),
),
),
if (_isLoadingVersion)
SliverToBoxAdapter(
child: LinearProgressIndicator(
backgroundColor: _primaryLight,
valueColor: AlwaysStoppedAnimation<Color>(_primary),
minHeight: 2,
),
),
];
},
body: AnimatedSwitcher(
duration: const Duration(milliseconds: 300),
switchInCurve: Curves.easeOut,
switchOutCurve: Curves.easeIn,
transitionBuilder: (child, animation) {
return FadeTransition(
opacity: animation,
child: child,
);
},
child: _isLoadingVersion
? _buildVersionLoadingState()
: TabBarView(
key: ValueKey(_selectedVersionId),
controller: _mainTabController,
children: [
_buildOverviewTab(context),
_buildItineraryTab(context),
],
),
),
),
bottomNavigationBar: _buildBottomBar(context),
);
}

/// Loading state while switching versions
Widget _buildVersionLoadingState() {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
SizedBox(
width: 32,
height: 32,
child: CircularProgressIndicator(
strokeWidth: 2.5,
color: _primary,
),
),
const SizedBox(height: 16),
Text(
'Loading version...',
style: TextStyle(
fontSize: 14,
color: _textSecondary,
),
),
],
),
);
}

/// Error state when version failed to load
Widget _buildVersionLoadError() {
return Scaffold(
appBar: AppBar(
leading: IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: () => context.pop(),
),
title: Text(_planMeta?.name ?? 'Adventure'),
),
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
const SizedBox(height: 16),
Text(
'Failed to load adventure details',
style: context.textStyles.headlineSmall,
textAlign: TextAlign.center,
),
const SizedBox(height: 8),
Text(
'The version data could not be loaded. Please try again.',
style: TextStyle(
fontSize: 14,
color: _textSecondary,
),
textAlign: TextAlign.center,
),
const SizedBox(height: 24),
ElevatedButton.icon(
onPressed: () {
setState(() {
_isLoading = true;
_errorMessage = null;
});
_loadPlan();
},
icon: const Icon(Icons.refresh),
label: const Text('Retry'),
style: ElevatedButton.styleFrom(
backgroundColor: _primary,
foregroundColor: Colors.white,
),
),
const SizedBox(height: 12),
TextButton(
onPressed: () => context.pop(),
child: const Text('Go Back'),
),
],
),
),
),
);
}

/// Get the effective plan data for display (prefers full plan, falls back to meta)
String get _effectiveHeroImageUrl => plan?.heroImageUrl ?? _planMeta?.heroImageUrl ?? '';
String get _effectiveName => plan?.name ?? _planMeta?.name ?? '';
String get _effectiveLocation => plan?.location ?? _planMeta?.location ?? '';
String get _effectiveDescription => plan?.description ?? _planMeta?.description ?? '';
String get _effectiveCreatorName => plan?.creatorName ?? _planMeta?.creatorName ?? '';
double get _effectiveBasePrice => plan?.basePrice ?? _planMeta?.basePrice ?? 0;
String get _effectivePlanId => plan?.id ?? _planMeta?.id ?? widget.planId;

  Widget _buildHeroSection(BuildContext context) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _effectiveHeroImageUrl,
            fit: BoxFit.cover,
            memCacheHeight: 600,
            maxHeightDiskCache: 600,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.arrow_back,
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      _buildActionButton(
                        icon: _isLikedOptimistic ? Icons.favorite : Icons.favorite_border,
                        color: _isLikedOptimistic ? Colors.red : null,
                        onPressed: _handleLikeToggle,
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.ios_share,
                        onPressed: _handleShare,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _effectiveName,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _effectiveLocation,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_versionSummaries.length > 1 || (plan?.versions.length ?? 0) > 1)
                          _buildVersionSelector()
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHeroBadge(
                                '${selectedVersion?.durationDays ?? 0} days',
                                Icons.calendar_today_outlined,
                              ),
                              if (selectedVersion != null && selectedVersion!.difficulty != Difficulty.none)
                                _buildHeroBadge(
                                  selectedVersion!.difficulty.name.toUpperCase(),
                                  Icons.trending_up,
                                  color: _getDifficultyColor(selectedVersion!.difficulty),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hero background for SliverAppBar FlexibleSpaceBar
  Widget _buildHeroBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: _effectiveHeroImageUrl,
          fit: BoxFit.cover,
          memCacheHeight: 600,
          maxHeightDiskCache: 600,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Content positioned at bottom, above the tab bar
        Positioned(
          left: 20,
          right: 20,
          bottom: 60, // Space for tab bar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _effectiveName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _effectiveLocation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_versionSummaries.length > 1 || (plan?.versions.length ?? 0) > 1)
                _buildVersionSelector()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroBadge(
                      '${selectedVersion?.durationDays ?? 0} days',
                      Icons.calendar_today_outlined,
                    ),
                    if (selectedVersion != null && selectedVersion!.difficulty != Difficulty.none)
                      _buildHeroBadge(
                        selectedVersion!.difficulty.name.toUpperCase(),
                        Icons.trending_up,
                        color: _getDifficultyColor(selectedVersion!.difficulty),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildActionButton({
required IconData icon,
required VoidCallback onPressed,
Color? color,
}) {
return Container(
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
shape: BoxShape.circle,
border: Border.all(
color: Colors.white.withValues(alpha: 0.3),
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.1),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: onPressed,
borderRadius: BorderRadius.circular(24),
child: Padding(
padding: const EdgeInsets.all(10),
child: Icon(
icon,
color: color ?? Colors.white,
size: 22,
),
),
),
),
);
}

Widget _buildHeroBadge(String text, IconData icon, {Color? color}) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
decoration: BoxDecoration(
color: (color ?? Colors.white).withValues(alpha: 0.25),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: Colors.white.withValues(alpha: 0.3),
width: 1,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 14, color: Colors.white),
const SizedBox(width: 6),
Text(
text,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: Colors.white,
letterSpacing: 0.3,
),
),
],
),
);
}

/// Version selector dropdown in hero section
Widget _buildVersionSelector() {
// Get current version info
final currentSummary = _versionSummaries.firstWhere(
(v) => v.id == _selectedVersionId,
orElse: () => _versionSummaries.isNotEmpty
? _versionSummaries.first
: VersionSummary(
id: selectedVersion?.id ?? '',
name: selectedVersion?.name ?? 'Version',
durationDays: selectedVersion?.durationDays ?? 0,
),
);

return GestureDetector(
onTap: _showVersionDropdown,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Colors.white.withValues(alpha: 0.3),
width: 1,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.layers_outlined,
size: 18,
color: Colors.white.withValues(alpha: 0.9),
),
const SizedBox(width: 10),
Flexible(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(
currentSummary.name,
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: Colors.white,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Text(
'${currentSummary.durationDays} days${currentSummary.totalDistanceKm != null ? ' • ${currentSummary.totalDistanceKm!.toStringAsFixed(0)}km' : ''}',
style: TextStyle(
fontSize: 12,
color: Colors.white.withValues(alpha: 0.8),
),
),
],
),
),
const SizedBox(width: 8),
Icon(
Icons.keyboard_arrow_down,
size: 20,
color: Colors.white.withValues(alpha: 0.9),
),
],
),
),
);
}

/// Show version dropdown bottom sheet
void _showVersionDropdown() {
// Use version summaries if available, fallback to plan versions
final versions = _versionSummaries.isNotEmpty
? _versionSummaries
: (plan?.versions.map((v) => VersionSummary(
id: v.id,
name: v.name,
durationDays: v.durationDays,
difficulty: v.difficulty,
)).toList() ?? []);

if (versions.isEmpty) return;

showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
isScrollControlled: true,
builder: (context) => _VersionSelectorSheet(
versions: versions,
selectedVersionId: _selectedVersionId,
isLoading: _isLoadingVersion,
onVersionSelected: (versionId) {
Navigator.pop(context);
if (versionId != _selectedVersionId) {
_loadVersion(versionId);
}
},
getDifficultyColor: _getDifficultyColor,
),
);
}

Widget _buildTabBar(BuildContext context) {
return Container(
decoration: const BoxDecoration(
color: Colors.white,
),
child: TabBar(
controller: _mainTabController,
labelColor: BrandColors.primary, // #2D6A4F - Primary green
unselectedLabelColor: const Color(0xFF9CA3AF),
indicatorColor: BrandColors.primary, // #2D6A4F - Primary green
indicatorWeight: 2,
indicatorSize: TabBarIndicatorSize.label,
splashFactory: NoSplash.splashFactory,
overlayColor: WidgetStateProperty.all(Colors.transparent),
dividerColor: Colors.transparent,
labelStyle: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
letterSpacing: 0.1,
),
unselectedLabelStyle: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w500,
letterSpacing: 0.1,
),
tabs: const [
Tab(height: 48, text: 'Overview'),
Tab(height: 48, text: 'Itinerary'),
],
),
);
}

Widget _buildOverviewTab(BuildContext context) {
return SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_buildStatsBar(context),
_buildDescriptionSection(context),
_buildCreatorSection(context),
_buildVersionsSection(context),
_buildWhatsIncludedSection(context),
_buildTransportationSection(context),
_buildPackingSection(context),
_buildReviewsSection(context),
_buildFAQSection(context),
const SizedBox(height: 100),
],
),
);
}

Widget _buildItineraryTab(BuildContext context) {
if (selectedVersion == null || selectedVersion!.days.isEmpty) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
const SizedBox(height: 16),
Text(
'No itinerary available',
style: context.textStyles.titleLarge,
),
],
),
),
);
}

return ListView.builder(
padding: const EdgeInsets.all(20),
itemCount: selectedVersion!.days.length,
itemBuilder: (context, index) {
final day = selectedVersion!.days[index];
final isExpanded = _expandedDayIndex == index;
final isLastDay = index == selectedVersion!.days.length - 1;

return _buildDayTimelineCard(
day: day,
dayNumber: index + 1,
isExpanded: isExpanded,
isLastDay: isLastDay,
onToggle: () {
setState(() {
if (isExpanded) {
_expandedDayIndex = null;
} else {
_expandedDayIndex = index;
_expandedDayTab = DayViewTab.summary; // Reset to summary on expand
}
});
},
);
},
);
}

// Cached getters for expensive calculations
double get _totalDistance {
if (_cachedTotalDistance == null && selectedVersion != null) {
_cachedTotalDistance = selectedVersion!.days.fold<double>(
0.0,
(sum, day) => sum + (day.route?.distance ?? 0),
);
}
return _cachedTotalDistance ?? 0.0;
}

double get _totalElevation {
  if (_cachedTotalElevation == null && selectedVersion != null) {
    _cachedTotalElevation = selectedVersion!.days.fold<double>(
      0.0,
      (sum, day) => sum + (day.route?.ascent ?? 0),
    );
  }
  return _cachedTotalElevation ?? 0.0;
}

/// Format season range as "Feb - Apr" or "Nov - Feb" (handles year wrapping)
String _formatSeasonRange(int startMonth, int endMonth) {
  const monthAbbreviations = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  
  if (startMonth >= 1 && startMonth <= 12 && endMonth >= 1 && endMonth <= 12) {
    final start = monthAbbreviations[startMonth - 1];
    final end = monthAbbreviations[endMonth - 1];
    return '$start - $end';
  }
  return '';
}

/// Format seasons for display (handles multiple seasons and entire year)
String _formatSeasons(Plan? plan, PlanMeta? planMeta) {
  final bestSeasons = plan?.bestSeasons ?? planMeta?.bestSeasons ?? [];
  final isEntireYear = plan?.isEntireYear ?? planMeta?.isEntireYear ?? false;
  
  if (isEntireYear) {
    return 'Year-round';
  }
  
  if (bestSeasons.isNotEmpty) {
    return bestSeasons.map((s) => _formatSeasonRange(s.startMonth, s.endMonth)).join(', ');
  }
  
  // Backward compatibility with old format
  final startMonth = plan?.bestSeasonStartMonth ?? planMeta?.bestSeasonStartMonth;
  final endMonth = plan?.bestSeasonEndMonth ?? planMeta?.bestSeasonEndMonth;
  if (startMonth != null && endMonth != null) {
    return _formatSeasonRange(startMonth, endMonth);
  }
  
  return '';
}

/// Check if plan has season information
bool _hasSeason(Plan? plan, PlanMeta? planMeta) {
  return (plan?.isEntireYear ?? planMeta?.isEntireYear ?? false) ||
         (plan?.bestSeasons.isNotEmpty ?? planMeta?.bestSeasons.isNotEmpty ?? false) ||
         ((plan?.bestSeasonStartMonth != null && plan?.bestSeasonEndMonth != null) ||
          (planMeta?.bestSeasonStartMonth != null && planMeta?.bestSeasonEndMonth != null));
}

/// Calculate estimated cost from all waypoints across all days
PriceRange? _calculateEstimatedCost(PlanVersion? version) {
  if (version == null) return null;
  
  double totalMin = 0.0;
  double totalMax = 0.0;
  bool hasAnyPrice = false;
  
  for (final day in version.days) {
    if (day.route?.poiWaypoints != null) {
      for (final waypointJson in day.route!.poiWaypoints) {
        final waypoint = RouteWaypoint.fromJson(waypointJson);
        if (waypoint.estimatedPriceRange != null) {
          totalMin += waypoint.estimatedPriceRange!.min;
          totalMax += waypoint.estimatedPriceRange!.max;
          hasAnyPrice = true;
        }
      }
    }
  }
  
  if (!hasAnyPrice || (totalMin == 0 && totalMax == 0)) return null;
  
  return PriceRange(
    min: totalMin,
    max: totalMax,
    currency: 'EUR',
  );
}

Widget _buildStatsBar(BuildContext context) {
final totalDistance = _totalDistance;
final totalElevation = _totalElevation;

return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
decoration: BoxDecoration(
color: Colors.white,
border: Border(
bottom: BorderSide(
color: const Color(0xFFE5E7EB).withValues(alpha: 0.3),
width: 0.5,
),
),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: [
Expanded(
child: _buildStatItem(
Icons.route,
'${(totalDistance / 1000).toStringAsFixed(1)}',
'km',
'Distance',
),
),
Container(
width: 1,
height: 40,
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.transparent,
_border,
Colors.transparent,
],
),
),
),
Expanded(
child: _buildStatItem(
Icons.calendar_today_outlined,
'${selectedVersion?.durationDays ?? 0}',
'days',
'Duration',
),
),
Container(
width: 1,
height: 40,
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.transparent,
_border,
Colors.transparent,
],
),
),
),
          Expanded(
            child: _buildStatItem(
              Icons.trending_up,
              '${totalElevation.toStringAsFixed(0)}',
              'm',
              'Elevation',
            ),
          ),
          // Best Season stat (4th item)
          if (_hasSeason(plan, _planMeta)) ...[
            Container(
              width: 1,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _border,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: _buildStatItem(
                Icons.calendar_month,
                _formatSeasons(plan, _planMeta),
                '',
                'Best Season',
              ),
            ),
          ],
          // Estimated Cost stat (5th item, only if showPrices is true)
          if ((plan?.showPrices ?? _planMeta?.showPrices ?? false) && selectedVersion != null) ...[
            Builder(
              builder: (context) {
                final estimatedCost = _calculateEstimatedCost(selectedVersion);
                if (estimatedCost == null || (estimatedCost.min == 0 && estimatedCost.max == 0)) {
                  return const SizedBox.shrink();
                }
                return Container(
                  width: 1,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _border,
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final estimatedCost = _calculateEstimatedCost(selectedVersion);
                if (estimatedCost == null || (estimatedCost.min == 0 && estimatedCost.max == 0)) {
                  return const SizedBox.shrink();
                }
                final costText = estimatedCost.min == estimatedCost.max
                    ? '€${estimatedCost.min.toStringAsFixed(0)}'
                    : '€${estimatedCost.min.toStringAsFixed(0)} - €${estimatedCost.max.toStringAsFixed(0)}';
                return Expanded(
                  child: _buildStatItem(
                    Icons.euro,
                    costText,
                    '',
                    'Est. Cost',
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

Widget _buildStatItem(
IconData icon,
String value,
String unit,
String label,
) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: _primaryLight,
shape: BoxShape.circle,
),
child: Icon(
icon,
size: 18,
color: _primary,
),
),
const SizedBox(height: 8),
FittedBox(
fit: BoxFit.scaleDown,
child: Row(
crossAxisAlignment: CrossAxisAlignment.baseline,
textBaseline: TextBaseline.alphabetic,
mainAxisSize: MainAxisSize.min,
children: [
Text(
value,
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w800,
color: _textPrimary,
),
),
Text(
' $unit',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: _textSecondary,
),
),
],
),
),
const SizedBox(height: 3),
FittedBox(
fit: BoxFit.scaleDown,
child: Text(
label,
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.w600,
color: _textMuted,
letterSpacing: 0.3,
),
),
),
],
);
}

Widget _buildDescriptionSection(BuildContext context) {
return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'About this adventure',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w700,
color: _textPrimary,
),
),
const SizedBox(height: 12),

LayoutBuilder(
builder: (context, constraints) {
final isMobile = constraints.maxWidth < 768;

if (!isMobile) {
// Desktop: Show full description
return SizedBox(
width: constraints.maxWidth,
child: MarkdownBody(
data: _effectiveDescription,
shrinkWrap: true,
softLineBreak: true,
fitContent: false,
styleSheet: MarkdownStyleSheet(
p: TextStyle(
fontSize: 16,
height: 1.6,
color: _textSecondary,
),
h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary),
h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
listBullet: TextStyle(fontSize: 16, color: _textSecondary),
strong: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
em: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: _textSecondary),
a: TextStyle(
fontSize: 16,
color: _primary,
decoration: TextDecoration.underline,
),
),
onTapLink: (text, href, title) {
if (href != null) {
launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
}
},
),
);
}

// Mobile: Collapsible description
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
AnimatedCrossFade(
firstChild: SizedBox(
width: constraints.maxWidth,
child: ConstrainedBox(
constraints: const BoxConstraints(maxHeight: 120),
child: Stack(
children: [
SizedBox(
width: constraints.maxWidth,
child: MarkdownBody(
data: _effectiveDescription,
shrinkWrap: true,
softLineBreak: true,
fitContent: false,
styleSheet: MarkdownStyleSheet(
p: TextStyle(
fontSize: 15,
height: 1.6,
color: _textSecondary,
),
strong: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary),
em: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: _textSecondary),
),
),
),
Positioned(
left: 0,
right: 0,
bottom: 0,
height: 40,
child: Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.white.withValues(alpha: 0),
Colors.white,
],
),
),
),
),
],
),
),
),
secondChild: SizedBox(
width: constraints.maxWidth,
child: MarkdownBody(
data: _effectiveDescription,
shrinkWrap: true,
softLineBreak: true,
fitContent: false,
styleSheet: MarkdownStyleSheet(
p: TextStyle(
fontSize: 15,
height: 1.6,
color: _textSecondary,
),
h1: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
h2: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _textPrimary),
h3: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary),
listBullet: TextStyle(fontSize: 15, color: _textSecondary),
strong: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary),
em: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: _textSecondary),
a: TextStyle(
fontSize: 15,
color: _primary,
decoration: TextDecoration.underline,
),
),
onTapLink: (text, href, title) {
if (href != null) {
launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
}
},
),
),
crossFadeState: _isDescriptionExpanded
? CrossFadeState.showSecond
: CrossFadeState.showFirst,
duration: const Duration(milliseconds: 300),
),
const SizedBox(height: 8),
InkWell(
onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 8),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
_isDescriptionExpanded ? 'Show less' : 'Read more',
style: TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: _primary,
),
),
const SizedBox(width: 4),
Icon(
_isDescriptionExpanded
? Icons.keyboard_arrow_up
: Icons.keyboard_arrow_down,
size: 20,
color: _primary,
),
],
),
),
),
],
);
},
),
],
),
);
}

Widget _buildCreatorSection(BuildContext context) {
    final creatorName = _effectiveCreatorName;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Creator', style: context.textStyles.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: context.colors.primaryContainer,
                child: Text(
                  creatorName.isNotEmpty ? creatorName[0].toUpperCase() : '?',
                  style: context.textStyles.titleLarge?.copyWith(
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creatorName,
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
const SizedBox(height: 4),
Text(
'Adventure Creator',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
),
],
),
),
],
),
],
),
);
}

Widget _buildVersionsSection(BuildContext context) {
// Use version summaries if available, otherwise fallback to plan versions
final versions = _versionSummaries.isNotEmpty
? _versionSummaries
: (plan?.versions.map((v) => VersionSummary(
id: v.id,
name: v.name,
durationDays: v.durationDays,
difficulty: v.difficulty,
)).toList() ?? []);

if (versions.length <= 1) return const SizedBox.shrink();

return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Select your adventure', style: context.textStyles.headlineSmall),
const SizedBox(height: 16),
SizedBox(
height: 140,
child: ListView.separated(
scrollDirection: Axis.horizontal,
itemCount: versions.length,
separatorBuilder: (_, __) => const SizedBox(width: 12),
itemBuilder: (context, index) {
final version = versions[index];
final isSelected = version.id == _selectedVersionId;
return GestureDetector(
onTap: () {
if (version.id != _selectedVersionId) {
_loadVersion(version.id);
}
},
child: Container(
width: 180,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: isSelected ? context.colors.primaryContainer : context.colors.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: isSelected ? context.colors.primary : context.colors.outline,
width: isSelected ? 2 : 1,
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
children: [
Expanded(
child: Text(
version.name,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
if (isSelected)
Icon(
Icons.check_circle,
size: 20,
color: context.colors.primary,
),
],
),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'${version.durationDays} Days',
style: context.textStyles.bodySmall,
),
if (version.totalDistanceKm != null) ...[
const SizedBox(height: 2),
Text(
'${version.totalDistanceKm!.toStringAsFixed(0)} km',
style: context.textStyles.bodySmall?.copyWith(
color: Colors.grey.shade600,
),
),
],
if (version.difficulty != Difficulty.none) ...[
const SizedBox(height: 4),
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
),
],
],
),
],
),
),
);
},
),
),
],
),
);
}

Widget _buildWhatsIncludedSection(BuildContext context) {
if (selectedVersion == null) return const SizedBox.shrink();

final waypointCounts = _getWaypointCounts(selectedVersion!);
if (waypointCounts.isEmpty) return const SizedBox.shrink();

return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text("What's included", style: context.textStyles.headlineSmall),
const SizedBox(height: 16),
LayoutBuilder(
builder: (context, constraints) {
final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
final itemWidth = (constraints.maxWidth - (12 * (crossAxisCount - 1))) / crossAxisCount;

return Wrap(
spacing: 12,
runSpacing: 12,
children: [
SizedBox(
width: itemWidth,
child: _buildIncludedCard(context, Icons.restaurant, 'Restaurants', waypointCounts['restaurants'] ?? 0, WaypointIconColors.getWaypointIconColor('restaurant')),
),
SizedBox(
width: itemWidth,
child: _buildIncludedCard(context, Icons.hotel, 'Accommodations', waypointCounts['accommodations'] ?? 0, WaypointIconColors.getWaypointIconColor('accommodation')),
),
SizedBox(
width: itemWidth,
child: _buildIncludedCard(context, Icons.local_activity, 'Activities', waypointCounts['activities'] ?? 0, WaypointIconColors.getWaypointIconColor('activity')),
),
SizedBox(
width: itemWidth,
child: _buildIncludedCard(context, Icons.location_on, 'Waypoints', waypointCounts['waypoints'] ?? 0, WaypointIconColors.getWaypointIconColor('waypoint')),
),
],
);
},
),
],
),
);
}

Widget _buildIncludedCard(BuildContext context, IconData icon, String label, int count, Color color) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
),
child: Column(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(7),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
shape: BoxShape.circle,
),
child: Icon(icon, size: 18, color: color),
),
const SizedBox(height: 6),
FittedBox(
fit: BoxFit.scaleDown,
child: Text(
'$count',
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
const SizedBox(height: 2),
FittedBox(
fit: BoxFit.scaleDown,
child: Text(
label,
style: TextStyle(
fontSize: 11,
color: Colors.grey.shade600,
),
textAlign: TextAlign.center,
),
),
],
),
);
}

Widget _buildTransportationSection(BuildContext context) {
if (selectedVersion == null || selectedVersion!.transportationOptions.isEmpty) {
return const SizedBox.shrink();
}

return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Text('How to get there', style: context.textStyles.headlineSmall),
),
if (!_hasPurchasedOptimistic)
Tooltip(
message: 'Purchase this plan to unlock transportation options',
child: Icon(
Icons.lock_outline,
size: 20,
color: _textMuted,
),
),
],
),
const SizedBox(height: 16),
if (_hasPurchasedOptimistic)
Column(
children: selectedVersion!.transportationOptions.map((option) => _buildTransportationOption(context, option)).toList(),
)
else
_buildLockedContentPlaceholder(
context,
icon: Icons.directions,
message: 'Purchase to unlock transportation details',
),
],
),
);
}

Widget _buildTransportationOption(BuildContext context, TransportationOption option) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
...option.types.map((type) => Padding(
padding: const EdgeInsets.only(right: 8),
child: Icon(_getTransportIcon(type), size: 20, color: context.colors.primary),
)),
const SizedBox(width: 8),
Expanded(
child: Text(
option.title,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
),
),
],
),
const SizedBox(height: 8),
MarkdownBody(
data: option.description,
styleSheet: MarkdownStyleSheet(
p: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.5),
h1: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
h2: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
h3: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
listBullet: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
a: context.textStyles.bodyMedium?.copyWith(
color: context.colors.primary,
decoration: TextDecoration.underline,
),
),
onTapLink: (text, href, title) {
if (href != null) {
launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
}
},
),
],
),
);
}

IconData _getTransportIcon(TransportationType type) {
switch (type) {
case TransportationType.car:
return Icons.directions_car;
case TransportationType.flying:
return Icons.flight;
case TransportationType.boat:
return Icons.directions_boat;
case TransportationType.foot:
return Icons.directions_walk;
case TransportationType.bike:
return Icons.directions_bike;
case TransportationType.train:
return Icons.train;
case TransportationType.bus:
return Icons.directions_bus;
case TransportationType.taxi:
return Icons.local_taxi;
}
}

Widget _buildPackingSection(BuildContext context) {
if (selectedVersion == null || selectedVersion!.packingCategories.isEmpty) {
return const SizedBox.shrink();
}

// Hide entire section for non-purchasers (like waypoints tab)
if (!_hasPurchasedOptimistic) {
return const SizedBox.shrink();
}

return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('What to bring', style: context.textStyles.headlineSmall),
const SizedBox(height: 16),
Column(
children: selectedVersion!.packingCategories.map((category) => _PackingCategoryWidget(category: category)).toList(),
),
],
),
);
}

Widget _buildReviewsSection(BuildContext context) {
final reviewStats = plan?.reviewStats ?? ReviewStats.empty();

return Padding(
padding: const EdgeInsets.all(24),
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
'${reviewStats.averageRating.toStringAsFixed(1)} (${reviewStats.totalReviews})',
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
],
),
const SizedBox(height: 16),

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
style: context.textStyles.titleMedium?.copyWith(color: Colors.grey.shade600),
),
],
),
),
)
else
..._reviews.take(3).map((review) => _ReviewCard(review: review)),
],
),
);
}

Map<String, FAQItem> _getFAQMap() {
if (_cachedFaqMap != null) return _cachedFaqMap!;

final faqMap = <String, FAQItem>{};

// Add plan-level FAQs first (if plan is loaded)
final planFaqs = plan?.faqItems ?? _planMeta?.faqItems ?? [];
for (final faq in planFaqs) {
faqMap[faq.question] = faq;
}

// Add version-level FAQs (will overwrite duplicates)
if (selectedVersion != null) {
for (final faq in selectedVersion!.faqItems) {
faqMap[faq.question] = faq;
}
}

_cachedFaqMap = faqMap;
return faqMap;
}

Widget _buildFAQSection(BuildContext context) {
final faqMap = _getFAQMap();
final allFAQs = faqMap.values.toList();

if (allFAQs.isEmpty) return const SizedBox.shrink();

return Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text("FAQ's", style: context.textStyles.headlineSmall),
const SizedBox(height: 16),
...allFAQs.map((faq) => _buildFAQItem(context, faq)),
],
),
);
}

Widget _buildFAQItem(BuildContext context, FAQItem faq) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
),
child: Theme(
data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
child: ExpansionTile(
tilePadding: const EdgeInsets.all(16),
childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
title: Text(
faq.question,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
),
children: [
Align(
alignment: Alignment.centerLeft,
child: MarkdownBody(
data: faq.answer,
styleSheet: MarkdownStyleSheet(
p: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.5),
h1: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
h2: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
h3: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
listBullet: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
a: context.textStyles.bodyMedium?.copyWith(
color: context.colors.primary,
decoration: TextDecoration.underline,
),
),
onTapLink: (text, href, title) {
if (href != null) {
launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
}
},
),
),
],
),
),
);
}

Widget _buildDayInternalTabs(DayItinerary day) {
return Container(
padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
decoration: BoxDecoration(
color: Colors.white,
border: Border(
bottom: BorderSide(
color: const Color(0xFFE5E7EB).withValues(alpha: 0.3),
width: 0.5,
),
),
),
child: Container(
padding: const EdgeInsets.all(3),
decoration: BoxDecoration(
color: const Color(0xFFF3F4F6),
borderRadius: BorderRadius.circular(10),
),
child: Row(
children: [
Expanded(
child: _buildSegment(
label: 'Summary',
icon: Icons.description_outlined,
tab: DayViewTab.summary,
),
),
Expanded(
child: _buildSegment(
label: 'Map',
icon: Icons.map_outlined,
tab: DayViewTab.map,
),
),
Expanded(
child: _buildSegment(
label: 'Waypoints',
icon: Icons.place_outlined,
tab: DayViewTab.waypoints,
),
),
],
),
),
);
}

Widget _buildSegment({
required String label,
required IconData icon,
required DayViewTab tab,
}) {
final isSelected = _expandedDayTab == tab;

return GestureDetector(
onTap: () => setState(() => _expandedDayTab = tab),
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOut,
padding: const EdgeInsets.symmetric(vertical: 10),
decoration: BoxDecoration(
color: isSelected ? Colors.white : Colors.transparent,
borderRadius: BorderRadius.circular(8),
boxShadow: isSelected ? [
BoxShadow(
color: Colors.black.withValues(alpha: 0.04),
blurRadius: 4,
offset: const Offset(0, 1),
),
] : null,
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 16,
color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
),
const SizedBox(width: 6),
Text(
label,
style: TextStyle(
fontSize: 14,
fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
),
),
],
),
),
);
}

Widget _buildDayTimelineCard({
required DayItinerary day,
required int dayNumber,
required bool isExpanded,
required bool isLastDay,
required VoidCallback onToggle,
}) {
return Column(
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 300),
curve: Curves.easeInOut,
margin: EdgeInsets.only(
bottom: isExpanded ? 16 : 12,
left: isExpanded ? 0 : 8,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(isExpanded ? 16 : 14),
border: Border.all(
color: isExpanded
? const Color(0xFF10B981).withValues(alpha: 0.3)
: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
width: isExpanded ? 1.5 : 0.5,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: isExpanded ? 0.04 : 0.02),
blurRadius: isExpanded ? 16 : 8,
offset: Offset(0, isExpanded ? 2 : 1),
),
],
),
child: Material(
color: Colors.transparent,
child: Column(
children: [
InkWell(
onTap: onToggle,
borderRadius: BorderRadius.vertical(
top: Radius.circular(isExpanded ? 20 : 16),
bottom: isExpanded ? Radius.zero : Radius.circular(16),
),
child: Padding(
padding: const EdgeInsets.all(20),
child: Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: isExpanded ? _primary : _primaryLight,
shape: BoxShape.circle,
boxShadow: isExpanded ? [
BoxShadow(
color: const Color(0xFF10B981).withValues(alpha: 0.2),
blurRadius: 8,
offset: const Offset(0, 2),
),
] : null,
),
child: Center(
child: Text(
'$dayNumber',
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.w700,
color: isExpanded ? Colors.white : _primary,
),
),
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Day $dayNumber',
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: Color(0xFF9CA3AF),
letterSpacing: 0.5,
),
),
const SizedBox(height: 4),
Text(
day.title,
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.w600,
color: Color(0xFF111827),
height: 1.3,
),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 8),
Wrap(
spacing: 20,
runSpacing: 8,
children: [
_buildDayStat(
Icons.straighten,
'${day.distanceKm.toStringAsFixed(1)} km',
),
_buildDayStat(
Icons.access_time_outlined,
'${(day.estimatedTimeMinutes / 60).toStringAsFixed(1)}h',
),
if (day.route?.ascent != null && day.route!.ascent! > 0)
_buildDayStat(
Icons.trending_up,
'${day.route!.ascent!.toStringAsFixed(0)}m',
),
],
),
],
),
),
AnimatedRotation(
turns: isExpanded ? 0.5 : 0,
duration: const Duration(milliseconds: 300),
child: Icon(
Icons.keyboard_arrow_down,
size: 24,
color: isExpanded ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
),
),
],
),
),
),
if (isExpanded) ...[
Container(
height: 0.5,
color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
),
_buildDayInternalTabs(day),
_buildDayTabContent(day),
],
],
),
),
),
if (!isLastDay && !isExpanded)
Container(
margin: const EdgeInsets.only(left: 32),
width: 2,
height: 24,
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
_primary.withValues(alpha: 0.3),
_primary.withValues(alpha: 0.1),
],
),
),
),
],
);
}

Widget _buildDayStat(IconData icon, String value) {
return Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
const SizedBox(width: 5),
Text(
value,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w500,
color: Color(0xFF6B7280),
),
),
],
);
}

Widget _buildDayTabContent(DayItinerary day) {
  // Use Stack with Offstage to pre-render map tiles while viewing other tabs
  // This prevents the grey map issue on first map tab visit
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Stack(
      children: [
        // Map tab - always rendered but hidden when not selected
        // This allows tiles to load in background
        Offstage(
          offstage: _expandedDayTab != DayViewTab.map,
          child: _buildDayMapContent(day),
        ),
        // Summary tab - only rendered when selected
        if (_expandedDayTab == DayViewTab.summary)
          _buildDaySummaryContent(day),
        // Waypoints tab - only rendered when selected
        if (_expandedDayTab == DayViewTab.waypoints)
          _buildDayWaypointsContent(day),
      ],
    ),
  );
}

Widget _buildDayContent(DayItinerary day) {
switch (_expandedDayTab) {
case DayViewTab.summary:
return _buildDaySummaryContent(day);
case DayViewTab.map:
return _buildDayMapContent(day);
case DayViewTab.waypoints:
return _buildDayWaypointsContent(day);
}
}

Widget _buildDaySummaryContent(DayItinerary day) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (day.photos.isNotEmpty) ...[
ClipRRect(
borderRadius: BorderRadius.circular(12),
child: CachedNetworkImage(
imageUrl: day.photos.first,
height: 200,
width: double.infinity,
fit: BoxFit.cover,
memCacheHeight: 400,
maxHeightDiskCache: 400,
fadeInDuration: const Duration(milliseconds: 200),
placeholder: (context, url) => Container(
height: 200,
color: const Color(0xFFF3F4F6),
child: Center(
child: CircularProgressIndicator(
color: _primary,
strokeWidth: 2,
),
),
),
),
),
const SizedBox(height: 16),
],
Text(
day.description,
style: const TextStyle(
fontSize: 15,
height: 1.6,
color: Color(0xFF374151),
),
),
if (_hasAnyWaypoints(day)) ...[
const SizedBox(height: 20),
Text(
'Highlights',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w700,
color: _textPrimary,
),
),
const SizedBox(height: 12),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
..._buildWaypointHighlights(day),
],
),
],
],
);
}

Widget _buildHighlightChip(IconData icon, String label, Color color) {
final chipColor = color is MaterialColor ? color.shade800 : color;
return Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.08),
borderRadius: BorderRadius.circular(8),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 15, color: color),
const SizedBox(width: 6),
Text(
label,
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: chipColor,
),
),
],
),
);
}

Widget _buildDayMapContent(DayItinerary day) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 400,
      child: IgnorePointer(
        ignoring: !_hasPurchasedOptimistic,
        child: _buildDayMap(context, day),
      ),
    ),
  );
}

Widget _buildDayWaypointsContent(DayItinerary day) {
if (!_hasPurchasedOptimistic) {
return SizedBox(
height: 300,
child: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.lock_outline,
size: 48,
color: _textMuted,
),
const SizedBox(height: 12),
Text(
'Purchase to unlock waypoints',
style: TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: _textPrimary,
),
),
],
),
),
);
}
return _buildDayWaypoints(context, day);
}

/// Reusable locked content placeholder for non-purchasers
Widget _buildLockedContentPlaceholder(
BuildContext context, {
required IconData icon,
required String message,
}) {
return Container(
padding: const EdgeInsets.symmetric(vertical: 48),
decoration: BoxDecoration(
color: _background,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: _border.withValues(alpha: 0.5)),
),
child: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: _border.withValues(alpha: 0.3),
shape: BoxShape.circle,
),
child: Icon(
Icons.lock_outline,
size: 32,
color: _textMuted,
),
),
const SizedBox(height: 16),
Text(
message,
style: TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: _textPrimary,
),
textAlign: TextAlign.center,
),
],
),
),
);
}

Widget _buildDayMap(BuildContext context, DayItinerary day) {
// Check if there are any waypoints to display
final hasWaypoints = day.route?.poiWaypoints.isNotEmpty ?? false;
final hasRoute = day.route != null && day.route!.routePoints.isNotEmpty;

if (!hasRoute && !hasWaypoints) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
const SizedBox(height: 16),
Text(
'No map available for this day',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
),
],
),
),
);
}

// Use geometry coordinates (snapped trail path) if available, otherwise fallback to routePoints
final geometryCoords = day.route?.geometry['coordinates'] as List?;
final coordinates = hasRoute
? (geometryCoords != null && geometryCoords.isNotEmpty)
? geometryCoords.map((c) {
if (c is Map) {
// Firestore-safe format: {lng, lat}
return LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
} else if (c is List) {
// GeoJSON format: [lng, lat]
return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
}
return null;
}).whereType<LatLng>().toList()
: day.route!.routePoints
.map((p) => LatLng(p['lat']!, p['lng']!))
.toList()
: <LatLng>[];

// Waypoint markers are now handled in _DayMapWidget via MapAnnotation

// Calculate bounds including waypoints
final allPoints = <LatLng>[...coordinates];
// Add waypoint positions from route
for (final poiJson in day.route?.poiWaypoints ?? []) {
  try {
    final poi = RouteWaypoint.fromJson(poiJson);
    allPoints.add(poi.position);
  } catch (e) {
    debugPrint('Failed to parse waypoint: $e');
  }
}

// Safety check: if no points at all, shouldn't happen but just in case
if (allPoints.isEmpty) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
const SizedBox(height: 16),
Text(
'No map data available',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
),
],
),
),
);
}

// Calculate center and zoom
LatLng center = allPoints.first;
double zoom = 12.0;

if (allPoints.length > 1) {
  double minLat = allPoints.first.latitude;
  double maxLat = allPoints.first.latitude;
  double minLng = allPoints.first.longitude;
  double maxLng = allPoints.first.longitude;
  
  for (final point in allPoints) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  
  center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  
  // Calculate zoom based on bounds
  final latDiff = maxLat - minLat;
  final lngDiff = maxLng - minLng;
  final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
  
  if (maxDiff > 0.0001) {
    // Calculate zoom
    if (maxDiff > 10) zoom = 5;
    else if (maxDiff > 5) zoom = 6;
    else if (maxDiff > 2) zoom = 7;
    else if (maxDiff > 1) zoom = 8;
    else if (maxDiff > 0.5) zoom = 9;
    else if (maxDiff > 0.25) zoom = 10;
    else if (maxDiff > 0.1) zoom = 11;
    else zoom = 12;
  } else {
    // All points are the same
    zoom = 14.0;
  }
}

return _DayMapWidget(
coordinates: coordinates,
initialCenter: center,
initialZoom: zoom,
day: day,
primary: context.colors.primary,
);
}

/// Helper method to parse waypoints with error tracking
({List<RouteWaypoint> waypoints, int failedCount}) _parseWaypoints(List<Map<String, dynamic>> poiWaypoints) {
final waypoints = <RouteWaypoint>[];
int failedCount = 0;

for (final poiJson in poiWaypoints) {
try {
waypoints.add(RouteWaypoint.fromJson(poiJson));
} catch (e) {
debugPrint('Failed to parse waypoint: $e');
failedCount++;
}
}

waypoints.sort((a, b) => a.order.compareTo(b.order));
return (waypoints: waypoints, failedCount: failedCount);
}

Widget _buildDayWaypoints(BuildContext context, DayItinerary day) {
int failedParseCount = 0;
final List<RouteWaypoint> allWaypoints = [];

// Add POI waypoints from route (new unified approach)
if (day.route != null && day.route!.poiWaypoints.isNotEmpty) {
final result = _parseWaypoints(day.route!.poiWaypoints);
allWaypoints.addAll(result.waypoints);
failedParseCount = result.failedCount;
}

// Also add legacy accommodations/restaurants/activities for backwards compatibility
// Convert them to RouteWaypoint objects
for (final acc in day.accommodations) {
allWaypoints.add(RouteWaypoint(
id: acc.name.hashCode.toString(),
name: acc.name,
type: WaypointType.accommodation,
description: acc.type,
position: const LatLng(0, 0),
order: allWaypoints.length,
photoUrl: null,
));
}

for (final rest in day.restaurants) {
allWaypoints.add(RouteWaypoint(
id: rest.name.hashCode.toString(),
name: rest.name,
type: WaypointType.restaurant,
description: rest.mealType.name,
position: const LatLng(0, 0),
order: allWaypoints.length,
photoUrl: null,
));
}

for (final act in day.activities) {
allWaypoints.add(RouteWaypoint(
id: act.name.hashCode.toString(),
name: act.name,
type: WaypointType.activity,
description: act.description,
position: const LatLng(0, 0),
order: allWaypoints.length,
photoUrl: null,
));
}

if (allWaypoints.isEmpty) {
return Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.not_listed_location, size: 64, color: Colors.grey.shade400),
const SizedBox(height: 16),
Text(
'No waypoints for this day',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey),
),
],
),
);
}

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Error notice if some waypoints failed to parse
if (failedParseCount > 0)
Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.orange.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
),
child: Row(
children: [
Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
const SizedBox(width: 8),
Expanded(
child: Text(
'Some waypoints could not be loaded ($failedParseCount)',
style: TextStyle(
color: Colors.orange.shade900,
fontSize: 13,
fontWeight: FontWeight.w500,
),
),
),
],
),
),
// Sequential timeline widget
TimelineItineraryWidget(
  waypoints: allWaypoints,
  dayNumber: null, // Plan details don't have day numbers
  isBuilderView: false,
),
],
);
}


Widget _buildBottomBar(BuildContext context) {
if (selectedVersion == null) return const SizedBox.shrink();

final isFree = _effectiveBasePrice == 0;
String buttonText = _hasPurchasedOptimistic ? 'Start Adventure' : (isFree ? 'Get Free Access' : 'Unlock Plan');

return Container(
padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
decoration: BoxDecoration(
color: Colors.white,
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 16,
offset: const Offset(0, -4),
),
],
),
child: SafeArea(
top: false,
child: Row(
children: [
Expanded(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
isFree ? 'Free' : '€${_effectiveBasePrice.toStringAsFixed(0)}',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.w800,
color: isFree ? _primary : _textPrimary,
),
),
Row(
children: [
Icon(
Icons.favorite_border,
size: 14,
color: _textMuted,
),
const SizedBox(width: 4),
Text(
'${_favoriteCountOptimistic} saves',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w500,
color: _textMuted,
),
),
],
),
],
),
),
const SizedBox(width: 16),
Expanded(
flex: 2,
child: Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
boxShadow: [
BoxShadow(
color: _primary.withValues(alpha: 0.25),
blurRadius: 12,
offset: const Offset(0, 4),
),
],
),
child: ElevatedButton(
onPressed: () {
if (_hasPurchasedOptimistic) {
context.go('/itinerary/$_effectivePlanId/new');
} else {
_handleCheckout();
}
},
style: ElevatedButton.styleFrom(
backgroundColor: _hasPurchasedOptimistic 
    ? BrandColors.secondary  // #FCBF49 - Yellow for "Start Adventure" CTA
    : _primary,                // #2D6A4F - Green for "Get Free Access" / "Unlock Plan"
foregroundColor: _hasPurchasedOptimistic 
    ? NeutralColors.textPrimary  // Dark text on yellow
    : Colors.white,              // White text on green
padding: const EdgeInsets.symmetric(vertical: 18),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 0,
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
if (!_hasPurchasedOptimistic)
const Padding(
padding: EdgeInsets.only(right: 8),
child: Icon(Icons.lock_open_outlined, size: 18),
),
Text(
buttonText,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w700,
letterSpacing: 0.2,
),
),
if (_hasPurchasedOptimistic) ...{
const SizedBox(width: 8),
const Icon(Icons.arrow_forward, size: 18),
},
],
),
),
),
),
],
),
),
);
}

double _calculateZoomLevelFromPoints(List<LatLng> points) {
  if (points.isEmpty) return 12.0;
  if (points.length == 1) return 14.0;
  
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;
  
  for (final point in points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  
  final latDiff = maxLat - minLat;
  final lngDiff = maxLng - minLng;
  final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
  
  if (maxDiff > 10) return 5;
  if (maxDiff > 5) return 6;
  if (maxDiff > 2) return 7;
  if (maxDiff > 1) return 8;
  if (maxDiff > 0.5) return 9;
  if (maxDiff > 0.25) return 10;
  if (maxDiff > 0.1) return 11;
return 12;
}

Color _getDifficultyColor(Difficulty? difficulty) {
switch (difficulty) {
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

bool _hasAnyWaypoints(DayItinerary day) {
final hasLegacyWaypoints = day.accommodations.isNotEmpty ||
day.restaurants.isNotEmpty ||
day.activities.isNotEmpty;
final hasRouteWaypoints = day.route?.poiWaypoints.isNotEmpty ?? false;
return hasLegacyWaypoints || hasRouteWaypoints;
}

List<Widget> _buildWaypointHighlights(DayItinerary day) {
final chips = <Widget>[];

// Count waypoints from route by type
int accommodationCount = day.accommodations.length;
int restaurantCount = day.restaurants.length;
int activityCount = day.activities.length;
int viewingPointCount = 0;
int logisticsCount = 0;

if (day.route?.poiWaypoints.isNotEmpty ?? false) {
for (final poiJson in day.route!.poiWaypoints) {
try {
final wp = RouteWaypoint.fromJson(poiJson);
switch (wp.type) {
case WaypointType.accommodation:
accommodationCount++;
break;
case WaypointType.restaurant:
restaurantCount++;
break;
case WaypointType.activity:
activityCount++;
break;
case WaypointType.viewingPoint:
viewingPointCount++;
break;
case WaypointType.servicePoint:
logisticsCount++;
break;
default:
break;
}
} catch (e) {
debugPrint('Failed to parse waypoint for highlights: $e');
}
}
}

// Always show all 5 types with their counts (0 if none)
chips.add(_buildHighlightChip(
Icons.hotel,
'$accommodationCount accommodation${accommodationCount != 1 ? 's' : ''}',
const Color(0xFF2196F3), // Blue
));

chips.add(_buildHighlightChip(
Icons.restaurant,
'$restaurantCount meal${restaurantCount != 1 ? 's' : ''}',
const Color(0xFFFF9800), // Orange
));

chips.add(_buildHighlightChip(
Icons.local_activity,
'$activityCount activit${activityCount != 1 ? 'ies' : 'y'}',
const Color(0xFF9C27B0), // Purple
));

chips.add(_buildHighlightChip(
Icons.visibility,
'$viewingPointCount viewpoint${viewingPointCount != 1 ? 's' : ''}',
const Color(0xFFFFC107), // Yellow/Gold
));

chips.add(_buildHighlightChip(
Icons.local_convenience_store,
'$logisticsCount logistics point${logisticsCount != 1 ? 's' : ''}',
const Color(0xFF4CAF50), // Green
));

return chips;
}

Map<String, int> _getWaypointCounts(PlanVersion version) {
// Return cached result if available
if (_cachedWaypointCounts != null) return _cachedWaypointCounts!;

int restaurants = 0;
int accommodations = 0;
int activities = 0;
int waypoints = 0;

for (final day in version.days) {
// Legacy counts
restaurants += day.restaurants.length;
accommodations += day.accommodations.length;
activities += day.activities.length;

// Count waypoints from route (new unified approach)
if (day.route?.poiWaypoints.isNotEmpty ?? false) {
final result = _parseWaypoints(day.route!.poiWaypoints);
for (final wp in result.waypoints) {
switch (wp.type) {
case WaypointType.accommodation:
accommodations++;
break;
case WaypointType.restaurant:
restaurants++;
break;
case WaypointType.activity:
activities++;
break;
default:
waypoints++;
}
}
}
}

_cachedWaypointCounts = {
'restaurants': restaurants,
'accommodations': accommodations,
'activities': activities,
'waypoints': waypoints,
};

return _cachedWaypointCounts!;
}

Future<void> _handleLikeToggle() async {
// Prevent rapid clicks
if (_isTogglingLike) return;

if (!_isAuthenticated) {
await SignInBottomSheet.show(
context,
title: 'Save Your Favorites',
message: 'Sign in to save this adventure to your favorites.',
);
return;
}

final planId = _effectivePlanId;
if (planId.isEmpty) return;

_isTogglingLike = true;

// Store original values for rollback on error
final wasLiked = _isLikedOptimistic;
final originalCount = _favoriteCountOptimistic;

// Apply optimistic update immediately
setState(() {
_isLikedOptimistic = !_isLikedOptimistic;
_favoriteCountOptimistic = _isLikedOptimistic
? _favoriteCountOptimistic + 1
: _favoriteCountOptimistic - 1;
});

try {
// Toggle favorite on server - returns the actual new status
final newStatus = await _favoriteService.toggleFavorite(_currentUserId!, planId);
if (!mounted) return;

// Only correct optimistic state if server disagrees (rare edge case)
if (newStatus != _isLikedOptimistic) {
setState(() {
_isLikedOptimistic = newStatus;
// Adjust count based on actual server status
_favoriteCountOptimistic = newStatus
? originalCount + 1
: originalCount - 1;
});
}
// Note: We trust the optimistic count - no need to reload full plan
// just to get an accurate favoriteCount. The difference is negligible
// for UX and avoids an expensive network call.
} catch (e) {
debugPrint('Failed to toggle favorite: $e');
if (!mounted) return;
// Rollback optimistic update on error
setState(() {
_isLikedOptimistic = wasLiked;
_favoriteCountOptimistic = originalCount;
});
} finally {
_isTogglingLike = false;
}
}

Future<void> _handleShare() async {
final planId = _effectivePlanId;
if (planId.isEmpty) return;

final shareUrl = kIsWeb
? '${Uri.base.scheme}://${Uri.base.host}/plan/$planId'
: 'https://waypoint.app/plan/$planId';

final description = _effectiveDescription;
final shareText = '$_effectiveName\n\n${description.length > 100 ? '${description.substring(0, 100)}...' : description}\n\n$shareUrl';

await Share.share(shareText);
}

Future<void> _handleCheckout() async {
if (!_isAuthenticated) {
await SignInBottomSheet.show(
context,
title: 'Unlock This Adventure',
message: 'Sign in to purchase and access the full adventure plan.',
);
return;
}

final planId = _effectivePlanId;
if (planId.isEmpty) return;

// Pass plan if loaded, otherwise checkout will load it
context.push('/checkout/$planId', extra: {'plan': plan, 'planMeta': _planMeta});
}

}

class _DayMapWidget extends StatefulWidget {
final List<LatLng> coordinates;
final LatLng initialCenter;
final double initialZoom;
final DayItinerary day;
final Color primary;

const _DayMapWidget({
required this.coordinates,
required this.initialCenter,
required this.initialZoom,
required this.day,
required this.primary,
});

@override
State<_DayMapWidget> createState() => _DayMapWidgetState();
}

class _DayMapWidgetState extends State<_DayMapWidget> with AutomaticKeepAliveClientMixin {
  WaypointMapController? _mapController;
  bool _mapReady = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    // Fit bounds after map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBounds();
    });
  }
  
  Future<void> _fitBounds() async {
    if (!_mapReady || _mapController == null) return;
    
    // Calculate bounds from coordinates and waypoints
    final allPoints = <LatLng>[];
    if (widget.coordinates.isNotEmpty) {
      allPoints.addAll(widget.coordinates);
    }
    // Add waypoint positions from route
    if (widget.day.route?.poiWaypoints.isNotEmpty ?? false) {
      for (final wpJson in widget.day.route!.poiWaypoints) {
        try {
          final wp = RouteWaypoint.fromJson(wpJson);
          allPoints.add(wp.position);
        } catch (_) {}
      }
    }
    
    if (allPoints.isEmpty) {
      // Fallback to initial center/zoom
      await _mapController!.animateCamera(widget.initialCenter, widget.initialZoom);
      return;
    }
    
    // Calculate bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    
    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;
    
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    // Calculate zoom
    double zoom = widget.initialZoom;
    if (maxDiff > 10) zoom = 5;
    else if (maxDiff > 5) zoom = 6;
    else if (maxDiff > 2) zoom = 7;
    else if (maxDiff > 1) zoom = 8;
    else if (maxDiff > 0.5) zoom = 9;
    else if (maxDiff > 0.25) zoom = 10;
    else if (maxDiff > 0.1) zoom = 11;
    else zoom = 12;
    
    try {
      await _mapController!.animateCamera(center, zoom);
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }
  
  Future<void> _zoomIn() async {
    if (!_mapReady || _mapController == null) return;
    final currentPos = _mapController!.currentPosition;
    if (currentPos == null) return;
    await _mapController!.animateCamera(currentPos.center, currentPos.zoom + 1);
  }
  
  Future<void> _zoomOut() async {
    if (!_mapReady || _mapController == null) return;
    final currentPos = _mapController!.currentPosition;
    if (currentPos == null) return;
    await _mapController!.animateCamera(currentPos.center, currentPos.zoom - 1);
  }
  
  void _onMapReady() {
    if (_mapReady) return;
    setState(() => _mapReady = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fitBounds();
    });
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  /// Convert waypoint markers to MapAnnotations
  List<MapAnnotation> _buildAnnotationsFromWaypoints() {
    final annotations = <MapAnnotation>[];
    
    // Start marker (A)
    if (widget.coordinates.isNotEmpty) {
      annotations.add(
        MapAnnotation(
          id: 'start',
          position: widget.coordinates.first,
          icon: Icons.flag,
          color: const Color(0xFF52B788),
          label: 'A',
          onTap: () {},
        ),
      );
    }
    
    // End marker (B)
    if (widget.coordinates.isNotEmpty) {
      annotations.add(
        MapAnnotation(
          id: 'end',
          position: widget.coordinates.last,
          icon: Icons.flag,
          color: const Color(0xFFD62828),
          label: 'B',
          onTap: () {},
        ),
      );
    }
    
    // Waypoint markers - try to extract RouteWaypoint from day data
    if (widget.day.route?.poiWaypoints.isNotEmpty ?? false) {
      for (final wpJson in widget.day.route!.poiWaypoints) {
        try {
          if (wpJson is Map<String, dynamic> && 
              wpJson['position'] != null &&
              wpJson['position']['lat'] != null && 
              wpJson['position']['lng'] != null) {
            final wp = RouteWaypoint.fromJson(wpJson);
            annotations.add(
              MapAnnotation.fromWaypoint(wp, onTap: () {}),
            );
          }
        } catch (_) {}
      }
    }
    
    return annotations;
  }

@override
Widget build(BuildContext context) {
super.build(context); // Required for AutomaticKeepAliveClientMixin

// Build annotations
final annotations = _buildAnnotationsFromWaypoints();

// Build polylines
final polylines = widget.coordinates.isNotEmpty
    ? [
        MapPolyline(
          id: 'route_${widget.day.title}',
          points: widget.coordinates,
          color: widget.primary,
          width: 4.0,
        )
      ]
    : <MapPolyline>[];

// Map configuration
final mapConfig = MapConfiguration.mainMap(
  styleUri: mapboxStyleUri,
  rasterTileUrl: defaultRasterTileUrl,
  enable3DTerrain: false, // Flat for preview
  initialZoom: widget.initialZoom,
);

return Column(
children: [
Expanded(
child: Stack(
children: [
// Map using AdaptiveMapWidget (Mapbox WebGL on web, Native on mobile)
AdaptiveMapWidget(
  initialCenter: widget.initialCenter,
  configuration: mapConfig,
  annotations: annotations,
  polylines: polylines,
  onMapCreated: (controller) {
    _mapController = controller;
    _onMapReady();
  },
),
// Map controls (fit bounds + zoom)
Positioned(
top: 12,
right: 12,
child: Column(
children: [
  // Fit to bounds button
  _buildMapControlButton(Icons.fit_screen, () => _fitBounds()),
  const SizedBox(height: 8),
  // Zoom in button
  _buildMapControlButton(Icons.add, () => _zoomIn()),
  const SizedBox(height: 8),
  // Zoom out button
  _buildMapControlButton(Icons.remove, () => _zoomOut()),
],
),
),
],
),
),
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: context.colors.surface,
border: Border(
top: BorderSide(color: context.colors.outline.withValues(alpha: 0.2)),
),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: [
Column(
children: [
Icon(Icons.straighten, color: context.colors.primary),
const SizedBox(height: 4),
Text(
'${RouteCalculations.formatDayDistanceKm(widget.day)} km',
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
),
Text('Distance', style: context.textStyles.bodySmall?.copyWith(color: Colors.grey)),
],
),
Column(
children: [
Icon(Icons.access_time, color: context.colors.primary),
const SizedBox(height: 4),
Text(
RouteCalculations.formatDayDuration(widget.day),
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
),
Text('Hiking time', style: context.textStyles.bodySmall?.copyWith(color: Colors.grey)),
],
),
],
),
),
],
);
}

Widget _buildMapControlButton(IconData icon, VoidCallback onTap) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: widget.primary,
          ),
        ),
      ),
    ),
  );
}
}

class _PackingCategoryWidget extends StatefulWidget {
final PackingCategory category;

const _PackingCategoryWidget({required this.category});

@override
State<_PackingCategoryWidget> createState() => _PackingCategoryWidgetState();
}

class _PackingCategoryWidgetState extends State<_PackingCategoryWidget> {
bool _isExpanded = false;

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
),
child: Theme(
data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
child: ExpansionTile(
tilePadding: const EdgeInsets.all(16),
childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
title: Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: context.colors.primary.withValues(alpha: 0.1),
shape: BoxShape.circle,
),
child: Icon(Icons.backpack, size: 20, color: context.colors.primary),
),
const SizedBox(width: 12),
Expanded(
child: Text(
widget.category.name,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
),
),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: context.colors.primaryContainer,
borderRadius: BorderRadius.circular(12),
),
child: Text(
'${widget.category.items.length}',
style: context.textStyles.labelSmall?.copyWith(
color: context.colors.onPrimaryContainer,
fontWeight: FontWeight.bold,
),
),
),
],
),
onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
children: widget.category.items.map((item) {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Row(
children: [
Icon(
Icons.circle,
size: 6,
color: context.colors.onSurfaceVariant,
),
const SizedBox(width: 12),
Expanded(
child: Text(
item.name,
style: context.textStyles.bodyMedium,
),
),
],
),
);
}).toList(),
),
),
);
}
}

class _ReviewCard extends StatelessWidget {
final Review review;

const _ReviewCard({required this.review});

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
Row(
children: [
CircleAvatar(
radius: 20,
backgroundColor: context.colors.primaryContainer,
backgroundImage: review.userAvatar != null
? CachedNetworkImageProvider(
review.userAvatar!,
maxHeight: 80,
maxWidth: 80,
)
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
Text(
review.userName,
style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
),
Row(
children: List.generate(5, (index) {
return Icon(
index < review.rating ? Icons.star : Icons.star_border,
size: 14,
color: index < review.rating ? Colors.amber.shade600 : Colors.grey.shade400,
);
}),
),
],
),
),
],
),
if (review.title != null) ...[
const SizedBox(height: 12),
Text(
review.title!,
style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
],
),
);
}
}

/// Version selector bottom sheet
class _VersionSelectorSheet extends StatelessWidget {
final List<VersionSummary> versions;
final String? selectedVersionId;
final bool isLoading;
final ValueChanged<String> onVersionSelected;
final Color Function(Difficulty?) getDifficultyColor;

const _VersionSelectorSheet({
required this.versions,
required this.selectedVersionId,
required this.isLoading,
required this.onVersionSelected,
required this.getDifficultyColor,
});

@override
Widget build(BuildContext context) {
return Container(
decoration: const BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// Handle bar
Container(
margin: const EdgeInsets.only(top: 12),
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.grey.shade300,
borderRadius: BorderRadius.circular(2),
),
),
// Header
Padding(
padding: const EdgeInsets.all(20),
child: Row(
children: [
Icon(
Icons.layers,
color: context.colors.primary,
size: 24,
),
const SizedBox(width: 12),
Text(
'Select Version',
style: context.textStyles.titleLarge?.copyWith(
fontWeight: FontWeight.w700,
),
),
],
),
),
const Divider(height: 1),
// Version list
ConstrainedBox(
constraints: BoxConstraints(
maxHeight: MediaQuery.of(context).size.height * 0.5,
),
child: ListView.builder(
shrinkWrap: true,
padding: const EdgeInsets.symmetric(vertical: 8),
itemCount: versions.length,
itemBuilder: (context, index) {
final version = versions[index];
final isSelected = version.id == selectedVersionId;

return Material(
color: Colors.transparent,
child: InkWell(
onTap: () => onVersionSelected(version.id),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
decoration: BoxDecoration(
color: isSelected
? context.colors.primary.withValues(alpha: 0.08)
: Colors.transparent,
),
child: Row(
children: [
// Version icon
Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: isSelected
? context.colors.primary.withValues(alpha: 0.15)
: Colors.grey.shade100,
borderRadius: BorderRadius.circular(12),
),
child: Center(
child: Text(
'${version.durationDays}',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
color: isSelected
? context.colors.primary
: Colors.grey.shade700,
),
),
),
),
const SizedBox(width: 16),
// Version info
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
version.name,
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
color: isSelected
? context.colors.primary
: Colors.grey.shade900,
),
),
const SizedBox(height: 4),
Row(
children: [
_buildStatChip(
Icons.calendar_today_outlined,
'${version.durationDays} days',
),
if (version.totalDistanceKm != null) ...[
const SizedBox(width: 12),
_buildStatChip(
Icons.route,
'${version.totalDistanceKm!.toStringAsFixed(0)} km',
),
],
if (version.totalElevationM != null && version.totalElevationM! > 0) ...[
const SizedBox(width: 12),
_buildStatChip(
Icons.trending_up,
'${version.totalElevationM!.toStringAsFixed(0)} m',
),
],
],
),
if (version.difficulty != Difficulty.none) ...[
const SizedBox(height: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
decoration: BoxDecoration(
color: getDifficultyColor(version.difficulty).withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(4),
),
child: Text(
version.difficulty.name.toUpperCase(),
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w700,
color: getDifficultyColor(version.difficulty),
letterSpacing: 0.5,
),
),
),
],
],
),
),
// Selection indicator
if (isSelected)
Container(
padding: const EdgeInsets.all(4),
decoration: BoxDecoration(
color: context.colors.primary,
shape: BoxShape.circle,
),
child: const Icon(
Icons.check,
size: 16,
color: Colors.white,
),
)
else
Icon(
Icons.chevron_right,
color: Colors.grey.shade400,
),
],
),
),
),
);
},
),
),
// Bottom safe area
SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
],
),
);
}

Widget _buildStatChip(IconData icon, String label) {
return Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 12, color: Colors.grey.shade500),
const SizedBox(width: 4),
Text(
label,
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade600,
),
),
],
);
}
}
