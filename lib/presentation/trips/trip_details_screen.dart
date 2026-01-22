import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/plan_meta_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/presentation/trips/invite_share_sheet.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

enum DayViewTab { summary, map, waypoints }

/// Trip Details Screen - Shows trip customization based on a plan
/// Similar to PlanDetailsScreen but for user's trip with custom image, dates, selections
class TripDetailsScreen extends StatefulWidget {
  final String tripId;

  const TripDetailsScreen({super.key, required this.tripId});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  final PlanService _planService = PlanService();
  final TripService _tripService = TripService();

  // Trip and Plan data
  Trip? _trip;
  PlanMeta? _planMeta;
  Plan? _plan;
  PlanVersion? _selectedVersion;
  List<VersionSummary> _versionSummaries = [];
  final Map<String, PlanVersion> _versionCache = {};
  
  // Trip selections (owner's waypoint selections)
  final Map<int, TripDaySelection> _daySelections = {};
  
  // Member packing lists
  final Map<String, MemberPacking> _memberPackingLists = {};
  bool _isLoadingPacking = false;

  // Loading states
  bool _isLoading = true;
  bool _isLoadingVersion = false;
  String? _errorMessage;

  // Tab controller for main tabs (Overview | Itinerary)
  late TabController _mainTabController;
  int _currentMainTab = 0;

  // Timeline state - accordion style for days
  int? _expandedDayIndex;
  DayViewTab _expandedDayTab = DayViewTab.summary;

  // Description expansion
  bool _isDescriptionExpanded = false;

  // Performance caches
  double? _cachedTotalDistance;
  double? _cachedTotalElevation;
  Map<String, int>? _cachedWaypointCounts;
  Map<String, FAQItem>? _cachedFaqMap;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      setState(() => _currentMainTab = _mainTabController.index);
    });

    if (widget.tripId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid trip ID';
            _isLoading = false;
          });
        }
      });
      return;
    }

    _loadTripAndPlan();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _trip?.isOwner(_currentUserId ?? '') ?? false;

  Future<void> _loadTripAndPlan() async {
    try {
      // Load trip data
      final trip = await _tripService.getTripById(widget.tripId);
      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _errorMessage = 'Trip not found';
          _isLoading = false;
        });
        return;
      }

      setState(() => _trip = trip);

      // Load plan metadata
      final meta = await _planService.loadPlanMeta(trip.planId);
      if (!mounted) return;

      if (meta == null) {
        setState(() {
          _errorMessage = 'Plan not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _planMeta = meta;
        _versionSummaries = meta.versionSummaries;
      });

      // Load full plan for FAQ and other details
      final fullPlan = await _planService.loadFullPlan(trip.planId);
      if (!mounted) return;
      setState(() => _plan = fullPlan);

      // Load the selected version (or first version if none selected)
      final versionIdToLoad = trip.versionId ?? _versionSummaries.firstOrNull?.id;
      if (versionIdToLoad != null) {
        await _loadVersion(versionIdToLoad, isInitialLoad: true);
      } else {
        setState(() => _isLoading = false);
      }

      // Load trip selections
      await _loadTripSelections();
      
      // Load member packing lists
      await _loadMemberPackingLists();
    } catch (e) {
      debugPrint('Error loading trip and plan: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load trip details';
        _isLoading = false;
      });
    }
  }

  /// Load trip selections (waypoint selections by owner)
  Future<void> _loadTripSelections() async {
    if (_trip == null || _selectedVersion == null) return;

    try {
      for (int i = 0; i < _selectedVersion!.days.length; i++) {
        final selection = await _tripService.getDaySelection(widget.tripId, i + 1);
        if (selection != null) {
          _daySelections[i] = selection;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading trip selections: $e');
    }
  }
  
  /// Load member packing lists for all trip members
  Future<void> _loadMemberPackingLists() async {
    if (_trip == null || _selectedVersion == null) return;
    
    setState(() => _isLoadingPacking = true);
    
    try {
      for (final memberId in _trip!.memberIds) {
        final packing = await _tripService.getMemberPacking(widget.tripId, memberId);
        if (packing != null) {
          _memberPackingLists[memberId] = packing;
        } else {
          // Create empty packing list with all items from version
          final itemIds = _selectedVersion!.packingCategories
              .expand((cat) => cat.items.map((item) => item.id))
              .toList();
          _memberPackingLists[memberId] = MemberPacking.empty(
            tripId: widget.tripId,
            memberId: memberId,
            itemIds: itemIds,
          );
        }
      }
      if (mounted) setState(() => _isLoadingPacking = false);
    } catch (e) {
      debugPrint('Error loading member packing lists: $e');
      if (mounted) setState(() => _isLoadingPacking = false);
    }
  }
  
  /// Toggle packing item for a member
  Future<void> _togglePackingItem(String memberId, String itemId, bool checked) async {
    try {
      final currentPacking = _memberPackingLists[memberId];
      if (currentPacking == null) return;
      
      // Optimistic update
      final updatedItems = Map<String, bool>.from(currentPacking.items);
      updatedItems[itemId] = checked;
      
      setState(() {
        _memberPackingLists[memberId] = currentPacking.copyWith(items: updatedItems);
      });
      
      // Update in backend
      await _tripService.toggleMemberPackingItem(
        tripId: widget.tripId,
        memberId: memberId,
        itemId: itemId,
        checked: checked,
      );
    } catch (e) {
      debugPrint('Error toggling packing item: $e');
      // Reload on error
      await _loadMemberPackingLists();
    }
  }

  /// Load a specific version (with caching)
  Future<void> _loadVersion(String versionId, {bool isInitialLoad = false}) async {
    if (_trip == null || _planMeta == null) return;

    // Check cache first
    if (_versionCache.containsKey(versionId)) {
      setState(() {
        _selectedVersion = _versionCache[versionId];
        _expandedDayIndex = null;
        _cachedTotalDistance = null;
        _cachedTotalElevation = null;
        _cachedWaypointCounts = null;
        _cachedFaqMap = null;
        if (isInitialLoad) _isLoading = false;
        _isLoadingVersion = false;
      });

      // Update trip's selected version if owner
      if (_isOwner && _trip!.versionId != versionId) {
        _tripService.updateTripDetails(
          tripId: widget.tripId,
          versionId: versionId,
        );
      }
      return;
    }

    if (!isInitialLoad) {
      setState(() => _isLoadingVersion = true);
    }

    try {
      final version = await _planService.loadFullVersion(_trip!.planId, versionId);
      if (!mounted) return;

      if (version != null) {
        _versionCache[versionId] = version;

        setState(() {
          _selectedVersion = version;
          _expandedDayIndex = null;
          _cachedTotalDistance = null;
          _cachedTotalElevation = null;
          _cachedWaypointCounts = null;
          _cachedFaqMap = null;
          if (isInitialLoad) _isLoading = false;
          _isLoadingVersion = false;
        });

        // Update trip's selected version if owner changed it
        if (_isOwner && _trip!.versionId != versionId) {
          _tripService.updateTripDetails(
            tripId: widget.tripId,
            versionId: versionId,
          );
        }

        // Reload selections for new version
        await _loadTripSelections();
      } else {
        setState(() {
          if (isInitialLoad) _isLoading = false;
          _isLoadingVersion = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading version: $e');
      if (!mounted) return;

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

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  Color get _primary => const Color(0xFF10B981);
  Color get _primaryLight => const Color(0xFFECFDF5);
  Color get _textPrimary => const Color(0xFF111827);
  Color get _textSecondary => const Color(0xFF6B7280);
  Color get _textMuted => const Color(0xFF9CA3AF);
  Color get _border => const Color(0xFFE5E7EB);

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
              Text('Loading trip...', style: context.textStyles.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _trip == null || _planMeta == null) {
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
                  _errorMessage ?? 'Trip not found',
                  style: context.textStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/mytrips'),
                  icon: const Icon(Icons.map),
                  label: const Text('My Trips'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedVersion == null) {
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
                Text('No version available', style: context.textStyles.headlineSmall),
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

    return Scaffold(
      body: Column(
        children: [
          _buildHeroSection(context),
          _buildTabBar(context),
          if (_isLoadingVersion)
            LinearProgressIndicator(
              backgroundColor: context.colors.primaryContainer,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
              minHeight: 2,
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentMainTab == 0
                  ? _buildOverviewTab()
                  : _buildItineraryTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final imageUrl = _trip!.usePlanImage
        ? _planMeta!.heroImageUrl
        : (_trip!.customImages?['large'] ?? _trip!.customImages?['medium'] ?? _planMeta!.heroImageUrl);

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: context.colors.surfaceContainerLow,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: context.colors.surfaceContainerLow,
              child: Icon(Icons.image_not_supported, size: 64, color: context.colors.onSurfaceVariant),
            ),
          ),
          // Gradient overlay
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
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.arrow_back,
                        onPressed: () => context.go('/mytrips'),
                      ),
                      const Spacer(),
                      if (_isOwner)
                        _buildActionButton(
                          icon: Icons.share,
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => InviteShareSheet(trip: _trip!),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (_trip!.memberIds.length > 1)
                        _buildActionButton(
                          icon: Icons.group,
                          onPressed: () => context.push('/trip/${widget.tripId}/members'),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Trip title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trip!.title ?? _planMeta!.name,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Location row
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
                                _planMeta!.location,
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
                        // Version badge (bottom-left like plan page)
                        _buildVersionBadge(),
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

  Widget _buildVersionBadge() {
    final currentSummary = _versionSummaries.firstWhere(
      (v) => v.id == _selectedVersion!.id,
      orElse: () => VersionSummary(
        id: _selectedVersion!.id,
        name: _selectedVersion!.name,
        durationDays: _selectedVersion!.durationDays,
      ),
    );

    return Container(
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
          Column(
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
              ),
              const SizedBox(height: 2),
              Text(
                '${currentSummary.durationDays} days${currentSummary.totalDistanceKm != null ? ' • ${currentSummary.totalDistanceKm!.toStringAsFixed(0)}km' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              // Add trip dates if available
              if (_trip!.startDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  _trip!.endDate != null
                      ? '${DateFormat('d MMM').format(_trip!.startDate!)} - ${DateFormat('d MMM, yyyy').format(_trip!.endDate!)}'
                      : DateFormat('d MMM, yyyy').format(_trip!.startDate!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _border.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _mainTabController,
        labelColor: _primary,
        unselectedLabelColor: _textMuted,
        indicatorColor: _primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        dividerHeight: 0,
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsBar(),
          _buildDescriptionSection(),
          _buildCreatorSection(),
          if (_isOwner) _buildVersionsSection(),
          _buildWhatsIncludedSection(),
          _buildTransportationSection(),
          _buildPackingSection(),
          _buildFAQSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Cached getters for expensive calculations
  double get _totalDistance {
    if (_cachedTotalDistance == null && _selectedVersion != null) {
      _cachedTotalDistance = _selectedVersion!.days.fold<double>(
        0.0,
        (sum, day) => sum + (day.route?.distance ?? 0),
      );
    }
    return _cachedTotalDistance ?? 0.0;
  }

  double get _totalElevation {
    if (_cachedTotalElevation == null && _selectedVersion != null) {
      _cachedTotalElevation = _selectedVersion!.days.fold<double>(
        0.0,
        (sum, day) => sum + (day.route?.ascent ?? 0),
      );
    }
    return _cachedTotalElevation ?? 0.0;
  }

  Widget _buildStatsBar() {
    final totalDistance = _totalDistance;
    final totalElevation = _totalElevation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _border.withValues(alpha: 0.3),
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
              '${_selectedVersion?.durationDays ?? 0}',
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

  Widget _buildDescriptionSection() {
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
                return SizedBox(
                  width: constraints.maxWidth,
                  child: MarkdownBody(
                    data: _planMeta?.description ?? '',
                    shrinkWrap: true,
                    softLineBreak: true,
                    fitContent: false,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 16, height: 1.6, color: _textSecondary),
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
                                data: _planMeta?.description ?? '',
                                shrinkWrap: true,
                                softLineBreak: true,
                                fitContent: false,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(fontSize: 15, height: 1.6, color: _textSecondary),
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
                        data: _planMeta?.description ?? '',
                        shrinkWrap: true,
                        softLineBreak: true,
                        fitContent: false,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: 15, height: 1.6, color: _textSecondary),
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

  Widget _buildCreatorSection() {
    final creatorName = _planMeta?.creatorName ?? 'Unknown';
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

  Widget _buildVersionsSection() {
    if (_versionSummaries.length <= 1) return const SizedBox.shrink();

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
              itemCount: _versionSummaries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final version = _versionSummaries[index];
                final isSelected = version.id == _selectedVersion!.id;
                return GestureDetector(
                  onTap: () {
                    if (version.id != _selectedVersion!.id) {
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

  Map<String, int> _getWaypointCounts(PlanVersion version) {
    if (_cachedWaypointCounts != null) return _cachedWaypointCounts!;

    int restaurants = 0;
    int accommodations = 0;
    int activities = 0;
    int viewingPoints = 0;

    // Check if owner has made selections
    final hasAnySelections = _daySelections.values.any((selection) =>
        selection.selectedAccommodation != null ||
        selection.selectedRestaurants.isNotEmpty ||
        selection.selectedActivities.isNotEmpty);

    for (int i = 0; i < version.days.length; i++) {
      final day = version.days[i];
      final selection = _daySelections[i];

      if (hasAnySelections && selection != null) {
        // Show only selected waypoints
        if (selection.selectedAccommodation != null) accommodations++;
        restaurants += selection.selectedRestaurants.length;
        activities += selection.selectedActivities.length;
      } else {
        // Show all waypoints from POI waypoints in route
        if (day.route?.poiWaypoints.isNotEmpty ?? false) {
          for (final poiJson in day.route!.poiWaypoints) {
            try {
              final poi = RouteWaypoint.fromJson(poiJson);
              switch (poi.type) {
                case WaypointType.accommodation:
                  accommodations++;
                  break;
                case WaypointType.restaurant:
                  restaurants++;
                  break;
                case WaypointType.activity:
                  activities++;
                  break;
                case WaypointType.viewingPoint:
                  viewingPoints++;
                  break;
                default:
                  break;
              }
            } catch (e) {
              debugPrint('Error parsing waypoint for counts: $e');
            }
          }
        } else {
          // Fallback to legacy structure
          accommodations += day.accommodations.length;
          restaurants += day.restaurants.length;
          activities += day.activities.length;
        }
      }
    }

    _cachedWaypointCounts = {
      'restaurants': restaurants,
      'accommodations': accommodations,
      'activities': activities,
      'viewingPoints': viewingPoints,
    };

    return _cachedWaypointCounts!;
  }

  Widget _buildWhatsIncludedSection() {
    if (_selectedVersion == null) return const SizedBox.shrink();

    final waypointCounts = _getWaypointCounts(_selectedVersion!);
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
                    child: _buildIncludedCard(Icons.restaurant, 'Restaurants', waypointCounts['restaurants'] ?? 0, Colors.pink),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildIncludedCard(Icons.hotel, 'Accommodations', waypointCounts['accommodations'] ?? 0, Colors.purple),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildIncludedCard(Icons.local_activity, 'Activities', waypointCounts['activities'] ?? 0, Colors.blue),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildIncludedCard(Icons.visibility, 'Viewing Points', waypointCounts['viewingPoints'] ?? 0, Colors.cyan),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedCard(IconData icon, String label, int count, Color color) {
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

  Widget _buildTransportationSection() {
    if (_selectedVersion == null || _selectedVersion!.transportationOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to get there', style: context.textStyles.headlineSmall),
          const SizedBox(height: 16),
          Column(
            children: _selectedVersion!.transportationOptions.map((option) => _buildTransportationOption(option)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportationOption(TransportationOption option) {
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

  Widget _buildPackingSection() {
    if (_selectedVersion == null || _selectedVersion!.packingCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Packing list', style: context.textStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Each member has their own checklist',
            style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_isLoadingPacking)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
            )
          else
            ..._buildMemberPackingLists(),
        ],
      ),
    );
  }
  
  List<Widget> _buildMemberPackingLists() {
    if (_trip == null || _memberPackingLists.isEmpty) {
      return [const SizedBox.shrink()];
    }
    
    return _trip!.memberIds.map((memberId) {
      final packing = _memberPackingLists[memberId];
      if (packing == null) return const SizedBox.shrink();
      
      final isCurrentUser = memberId == _currentUserId;
      final userName = isCurrentUser ? 'My List' : 'Member ${_trip!.memberIds.indexOf(memberId) + 1}';
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? context.colors.primaryContainer.withValues(alpha: 0.3)
                    : context.colors.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrentUser ? Icons.person : Icons.person_outline,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userName,
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${packing.checkedCount}/${packing.totalCount}',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Packing items by category
            ..._selectedVersion!.packingCategories.map((category) {
              final categoryItems = category.items.where(
                (item) => packing.items.containsKey(item.id)
              ).toList();
              
              if (categoryItems.isEmpty) return const SizedBox.shrink();
              
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...categoryItems.map((item) {
                      final isChecked = packing.items[item.id] ?? false;
                      return CheckboxListTile(
                        value: isChecked,
                        onChanged: isCurrentUser
                            ? (checked) => _togglePackingItem(memberId, item.id, checked ?? false)
                            : null, // Only current user can check their own items
                        title: Text(
                          item.name,
                          style: context.textStyles.bodyMedium?.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked ? Colors.grey.shade600 : null,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  Map<String, FAQItem> _getFAQMap() {
    if (_cachedFaqMap != null) return _cachedFaqMap!;

    final faqMap = <String, FAQItem>{};

    // Add plan-level FAQs first
    final planFaqs = _plan?.faqItems ?? _planMeta?.faqItems ?? [];
    for (final faq in planFaqs) {
      faqMap[faq.question] = faq;
    }

    // Add version-level FAQs (will overwrite duplicates)
    if (_selectedVersion != null) {
      for (final faq in _selectedVersion!.faqItems) {
        faqMap[faq.question] = faq;
      }
    }

    _cachedFaqMap = faqMap;
    return faqMap;
  }

  Widget _buildFAQSection() {
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
          ...allFAQs.map((faq) => _FAQItem(faq: faq)),
        ],
      ),
    );
  }

  Widget _buildItineraryTab() {
    if (_selectedVersion == null || _selectedVersion!.days.isEmpty) {
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
      itemCount: _selectedVersion!.days.length,
      itemBuilder: (context, index) {
        final day = _selectedVersion!.days[index];
        final isExpanded = _expandedDayIndex == index;
        final isLastDay = index == _selectedVersion!.days.length - 1;

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
                _expandedDayTab = DayViewTab.summary;
              }
            });
          },
        );
      },
    );
  }

  Widget _buildDayTimelineCard({
    required DayItinerary day,
    required int dayNumber,
    required bool isExpanded,
    required bool isLastDay,
    required VoidCallback onToggle,
  }) {
    final selection = _daySelections[dayNumber - 1];
    
    // Calculate counts based on selections (if owner has made selections)
    int accommodationCount = 0;
    int mealCount = 0;
    int activityCount = 0;
    
    if (selection != null) {
      if (selection.selectedAccommodation != null) accommodationCount = 1;
      mealCount = selection.selectedRestaurants.length;
      activityCount = selection.selectedActivities.length;
    } else {
      // Show all waypoints counts if no selection yet
      accommodationCount = day.accommodations.length;
      mealCount = day.restaurants.length;
      activityCount = day.activities.length;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLastDay ? 0 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? _primary.withValues(alpha: 0.2) : _border.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
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
                              day.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.hotel, size: 14, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$accommodationCount', style: TextStyle(fontSize: 13, color: _textSecondary)),
                                const SizedBox(width: 12),
                                Icon(Icons.restaurant, size: 14, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$mealCount', style: TextStyle(fontSize: 13, color: _textSecondary)),
                                const SizedBox(width: 12),
                                Icon(Icons.local_activity, size: 14, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$activityCount', style: TextStyle(fontSize: 13, color: _textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: _textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildDayTabContent(day, dayNumber),
        ],
      ),
    );
  }

  Widget _buildDayTabContent(DayItinerary day, int dayNumber) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              top: BorderSide(
                color: _border.withValues(alpha: 0.1),
                width: 1,
              ),
              bottom: BorderSide(
                color: _border.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildDayTab('Summary', DayViewTab.summary),
              _buildDayTab('Map', DayViewTab.map),
              _buildDayTab('Waypoints', DayViewTab.waypoints),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Offstage(
            offstage: _expandedDayTab != DayViewTab.summary,
            child: _expandedDayTab == DayViewTab.summary ? _buildDaySummary(day) : const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Offstage(
            offstage: _expandedDayTab != DayViewTab.map,
            child: _expandedDayTab == DayViewTab.map ? _buildDayMap(day, dayNumber) : const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Offstage(
            offstage: _expandedDayTab != DayViewTab.waypoints,
            child: _expandedDayTab == DayViewTab.waypoints ? _buildWaypointsList(day, dayNumber) : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTab(String label, DayViewTab tab) {
    final isSelected = _expandedDayTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _expandedDayTab = tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: _border.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab == DayViewTab.summary
                      ? Icons.description_outlined
                      : tab == DayViewTab.map
                          ? Icons.map_outlined
                          : Icons.location_on_outlined,
                  size: 18,
                  color: isSelected ? _primary : _textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? _primary : _textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Check if day has any waypoints (POI or legacy)
  bool _hasAnyWaypoints(DayItinerary day) {
    final hasLegacyWaypoints = day.accommodations.isNotEmpty ||
        day.restaurants.isNotEmpty ||
        day.activities.isNotEmpty;
    final hasRouteWaypoints = day.route?.poiWaypoints.isNotEmpty ?? false;
    return hasLegacyWaypoints || hasRouteWaypoints;
  }

  /// Build highlight chips for waypoint counts (like plan page)
  List<Widget> _buildWaypointHighlights(DayItinerary day) {
    final chips = <Widget>[];

    // Count waypoints from route
    int accommodationCount = day.accommodations.length;
    int restaurantCount = day.restaurants.length;
    int activityCount = day.activities.length;
    int otherWaypointsCount = 0;

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
            default:
              otherWaypointsCount++;
          }
        } catch (e) {
          debugPrint('Failed to parse waypoint for highlights: $e');
        }
      }
    }

    if (accommodationCount > 0) {
      chips.add(_buildHighlightChip(
        Icons.hotel,
        '$accommodationCount accommodation${accommodationCount > 1 ? 's' : ''}',
        Colors.purple,
      ));
    }

    if (restaurantCount > 0) {
      chips.add(_buildHighlightChip(
        Icons.restaurant,
        '$restaurantCount meal${restaurantCount > 1 ? 's' : ''}',
        Colors.pink,
      ));
    }

    if (activityCount > 0) {
      chips.add(_buildHighlightChip(
        Icons.local_activity,
        '$activityCount activit${activityCount > 1 ? 'ies' : 'y'}',
        Colors.blue,
      ));
    }

    if (otherWaypointsCount > 0) {
      chips.add(_buildHighlightChip(
        Icons.location_on,
        '$otherWaypointsCount waypoint${otherWaypointsCount > 1 ? 's' : ''}',
        Colors.cyan,
      ));
    }

    return chips;
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

  Widget _buildDaySummary(DayItinerary day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (day.photos.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: day.photos.first,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          day.description,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: _textSecondary,
          ),
        ),
        // Show highlights section with waypoint chips (like plan page)
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
            children: _buildWaypointHighlights(day),
          ),
        ],
      ],
    );
  }

  Widget _buildDayMap(DayItinerary day, int dayNumber) {
    if (day.route == null || day.route!.routePoints.isEmpty) {
      return Center(
        child: Text(
          'No route available',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // Use geometry coordinates (snapped trail path) if available, otherwise fallback to routePoints
    final geometryCoords = day.route!.geometry['coordinates'] as List?;
    final coordinates = (geometryCoords != null && geometryCoords.isNotEmpty)
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
            .toList();

    // Get selected waypoints if available
    final selection = _daySelections[dayNumber - 1];
    final hasSelections = _dayHasSelections(dayNumber);

    // Build waypoint markers from POI waypoints
    final waypointMarkers = _buildWaypointMarkers(day, selection, hasSelections);

    // Calculate bounds including all points and markers
    final allPoints = <LatLng>[...coordinates];
    for (final marker in waypointMarkers) {
      allPoints.add(marker.point);
    }
    
    // Calculate bounds for fit-to-bounds
    LatLng center = coordinates.isNotEmpty ? coordinates.first : const LatLng(0, 0);
    double zoom = 13.0;
    LatLngBounds? bounds;
    
    if (allPoints.length > 1) {
      double minLat = allPoints.first.latitude;
      double maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude;
      double maxLng = allPoints.first.longitude;
      
      for (final point in allPoints) {
        minLat = point.latitude < minLat ? point.latitude : minLat;
        maxLat = point.latitude > maxLat ? point.latitude : maxLat;
        minLng = point.longitude < minLng ? point.longitude : minLng;
        maxLng = point.longitude > maxLng ? point.longitude : maxLng;
      }
      
      center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
      
      // Calculate zoom based on bounds
      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      
      if (maxDiff > 0.5) zoom = 9.0;
      else if (maxDiff > 0.2) zoom = 10.0;
      else if (maxDiff > 0.1) zoom = 11.0;
      else if (maxDiff > 0.05) zoom = 12.0;
      else zoom = 13.0;
    } else if (allPoints.length == 1) {
      bounds = LatLngBounds(allPoints.first, allPoints.first);
    }
    
    // Create fallback bounds if null
    bounds ??= LatLngBounds(center, center);

    return _TripDayMapWidget(
      coordinates: coordinates,
      waypointMarkers: waypointMarkers,
      initialCenter: center,
      initialZoom: zoom,
      bounds: bounds,
      day: day,
      primary: _primary,
      onExpandTap: () {
        // Navigate to fullscreen map
        final planId = _planMeta?.id ?? '';
        final tripId = widget.tripId;
        context.push(
          '/itinerary/$planId/day/$tripId/${dayNumber - 1}/map',
          extra: day,
        );
      },
    );
  }

  /// Check if a day has any waypoint selections
  bool _dayHasSelections(int dayNumber) {
    final selection = _daySelections[dayNumber - 1];
    if (selection == null) return false;
    return selection.selectedAccommodation != null ||
        selection.selectedRestaurants.isNotEmpty ||
        selection.selectedActivities.isNotEmpty;
  }

  List<Marker> _buildWaypointMarkers(DayItinerary day, TripDaySelection? selection, bool hasSelections) {
    final markers = <Marker>[];
    
    // Show all waypoints if: owner OR no selections made yet
    // Only show selected if: participant AND selections have been made
    final showAll = _isOwner || !hasSelections;
    
    // Add POI waypoint markers from route
    if (day.route?.poiWaypoints.isNotEmpty ?? false) {
      for (final poiJson in day.route!.poiWaypoints) {
        try {
          final poi = RouteWaypoint.fromJson(poiJson);
          
          // Check if this waypoint should be shown
          if (!showAll) {
            // Check if this waypoint is selected
            final isSelected = _isWaypointSelected(poi, selection);
            if (!isSelected) continue;
          }
          
          markers.add(
            Marker(
              point: poi.position,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: getWaypointColor(poi.type),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(getWaypointIcon(poi.type), color: Colors.white, size: 18),
              ),
            ),
          );
        } catch (e) {
          debugPrint('Failed to parse waypoint for map: $e');
        }
      }
    }
    
    return markers;
  }

  /// Check if a waypoint is selected in the current day selection
  bool _isWaypointSelected(RouteWaypoint waypoint, TripDaySelection? selection) {
    if (selection == null) return false;
    
    // Check by waypoint name (simplest matching)
    if (selection.selectedAccommodation?.name == waypoint.name) return true;
    
    for (final restaurant in selection.selectedRestaurants.values) {
      if (restaurant.name == waypoint.name) return true;
    }
    
    for (final activity in selection.selectedActivities) {
      if (activity.name == waypoint.name) return true;
    }
    
    return false;
  }

  /// Parse POI waypoints from route data
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

  Widget _buildWaypointsList(DayItinerary day, int dayNumber) {
    final allWaypoints = <Widget>[];
    int failedParseCount = 0;
    
    final selection = _daySelections[dayNumber - 1];
    final hasSelections = _dayHasSelections(dayNumber);
    
    // Determine visibility: 
    // - Owner sees all with checkboxes
    // - Participants see all if no selections, only selected if selections made
    final showAll = _isOwner || !hasSelections;

    // Add POI waypoints from route (new unified approach - same as Plan Details)
    if (day.route != null && day.route!.poiWaypoints.isNotEmpty) {
      final result = _parseWaypoints(day.route!.poiWaypoints);
      final waypoints = result.waypoints;
      failedParseCount = result.failedCount;

      for (final wp in waypoints) {
        final isSelected = _isWaypointSelected(wp, selection);
        
        // Skip if not showing all and not selected
        if (!showAll && !isSelected) continue;
        
        String subtitle = wp.description ?? '';
        if (wp.type == WaypointType.restaurant && wp.mealTime != null) {
          subtitle = getMealTimeLabel(wp.mealTime!);
        } else if (wp.type == WaypointType.activity && wp.activityTime != null) {
          subtitle = getActivityTimeLabel(wp.activityTime!);
        } else if (wp.type == WaypointType.accommodation && wp.accommodationType != null) {
          subtitle = wp.accommodationType!.name.toUpperCase();
        }

        allWaypoints.add(_buildWaypointItem(
          icon: getWaypointIcon(wp.type),
          name: wp.name,
          subtitle: subtitle,
          color: getWaypointColor(wp.type),
          photoUrl: wp.photoUrl,
          rating: wp.rating,
          isSelected: isSelected,
          showCheckbox: _isOwner,
          onSelectionChanged: _isOwner ? (selected) => _toggleWaypointSelection(
            dayNumber: dayNumber,
            waypoint: wp,
            selected: selected,
          ) : null,
        ));
      }
    }

    // Also add legacy accommodations/restaurants/activities for backwards compatibility
    for (final acc in day.accommodations) {
      final isSelected = selection?.selectedAccommodation?.name == acc.name;
      if (!showAll && !isSelected) continue;
      
      allWaypoints.add(_buildWaypointItem(
        icon: Icons.hotel,
        name: acc.name,
        subtitle: acc.type,
        color: Colors.purple,
        isSelected: isSelected,
        showCheckbox: _isOwner,
        onSelectionChanged: _isOwner ? (selected) => _toggleLegacyAccommodationSelection(
          dayNumber: dayNumber,
          accommodation: acc,
          selected: selected,
        ) : null,
      ));
    }

    for (final rest in day.restaurants) {
      final isSelected = selection?.selectedRestaurants.values.any((r) => r.name == rest.name) ?? false;
      if (!showAll && !isSelected) continue;
      
      allWaypoints.add(_buildWaypointItem(
        icon: Icons.restaurant,
        name: rest.name,
        subtitle: rest.mealType.name,
        color: Colors.pink,
        isSelected: isSelected,
        showCheckbox: _isOwner,
        onSelectionChanged: _isOwner ? (selected) => _toggleLegacyRestaurantSelection(
          dayNumber: dayNumber,
          restaurant: rest,
          selected: selected,
        ) : null,
      ));
    }

    for (final act in day.activities) {
      final isSelected = selection?.selectedActivities.any((a) => a.name == act.name) ?? false;
      if (!showAll && !isSelected) continue;
      
      allWaypoints.add(_buildWaypointItem(
        icon: Icons.local_activity,
        name: act.name,
        subtitle: act.description,
        color: Colors.blue,
        isSelected: isSelected,
        showCheckbox: _isOwner,
        onSelectionChanged: _isOwner ? (selected) => _toggleLegacyActivitySelection(
          dayNumber: dayNumber,
          activity: act,
          selected: selected,
        ) : null,
      ));
    }

    // Add error notice if some waypoints failed to parse
    if (failedParseCount > 0) {
      allWaypoints.insert(0, Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Some waypoints could not be loaded ($failedParseCount)',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
              ),
            ),
          ],
        ),
      ));
    }

    if (allWaypoints.isEmpty) {
      return Center(
        child: Padding(
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
        ),
      );
    }

    // Use Column instead of ListView to avoid height constraint issues
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show instruction text for owner
        if (_isOwner) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select waypoints to include in your trip. Participants will only see your selections.',
                    style: TextStyle(
                      color: _primary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ...allWaypoints,
      ],
    );
  }
  
  /// Toggle waypoint selection (for POI waypoints)
  Future<void> _toggleWaypointSelection({
    required int dayNumber,
    required RouteWaypoint waypoint,
    required bool selected,
  }) async {
    // Get or create selection for this day
    var selection = _daySelections[dayNumber - 1];
    if (selection == null) {
      selection = TripDaySelection.empty(
        tripId: widget.tripId,
        dayNum: dayNumber,
      );
    }
    
    // Update based on waypoint type
    switch (waypoint.type) {
      case WaypointType.accommodation:
        if (selected) {
          selection = selection.copyWith(
            selectedAccommodation: SelectedWaypoint.fromRouteWaypoint(waypoint),
          );
        } else {
          selection = TripDaySelection(
            id: selection.id,
            tripId: selection.tripId,
            dayNum: selection.dayNum,
            selectedAccommodation: null,
            selectedRestaurants: selection.selectedRestaurants,
            selectedActivities: selection.selectedActivities,
            notes: selection.notes,
            createdAt: selection.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        break;
      case WaypointType.restaurant:
        final restaurants = Map<String, SelectedWaypoint>.from(selection.selectedRestaurants);
        final mealKey = waypoint.mealTime?.name ?? 'other';
        if (selected) {
          restaurants[mealKey] = SelectedWaypoint.fromRouteWaypoint(waypoint);
        } else {
          restaurants.remove(mealKey);
        }
        selection = selection.copyWith(selectedRestaurants: restaurants);
        break;
      case WaypointType.activity:
        final activities = List<SelectedWaypoint>.from(selection.selectedActivities);
        if (selected) {
          activities.add(SelectedWaypoint.fromRouteWaypoint(waypoint));
        } else {
          activities.removeWhere((a) => a.name == waypoint.name);
        }
        selection = selection.copyWith(selectedActivities: activities);
        break;
      default:
        // For other waypoint types, treat as activity
        final activities = List<SelectedWaypoint>.from(selection.selectedActivities);
        if (selected) {
          activities.add(SelectedWaypoint.fromRouteWaypoint(waypoint));
        } else {
          activities.removeWhere((a) => a.name == waypoint.name);
        }
        selection = selection.copyWith(selectedActivities: activities);
    }
    
    // Update local state
    setState(() {
      _daySelections[dayNumber - 1] = selection!;
    });
    
    // Save to backend
    try {
      await _tripService.updateDaySelection(selection);
    } catch (e) {
      debugPrint('Error saving waypoint selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save selection'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Toggle legacy accommodation selection
  Future<void> _toggleLegacyAccommodationSelection({
    required int dayNumber,
    required AccommodationInfo accommodation,
    required bool selected,
  }) async {
    var selection = _daySelections[dayNumber - 1];
    if (selection == null) {
      selection = TripDaySelection.empty(
        tripId: widget.tripId,
        dayNum: dayNumber,
      );
    }
    
    if (selected) {
      selection = selection.copyWith(
        selectedAccommodation: SelectedWaypoint.fromAccommodation(accommodation),
      );
    } else {
      selection = TripDaySelection(
        id: selection.id,
        tripId: selection.tripId,
        dayNum: selection.dayNum,
        selectedAccommodation: null,
        selectedRestaurants: selection.selectedRestaurants,
        selectedActivities: selection.selectedActivities,
        notes: selection.notes,
        createdAt: selection.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    
    setState(() {
      _daySelections[dayNumber - 1] = selection!;
    });
    
    try {
      await _tripService.updateDaySelection(selection);
    } catch (e) {
      debugPrint('Error saving accommodation selection: $e');
    }
  }
  
  /// Toggle legacy restaurant selection
  Future<void> _toggleLegacyRestaurantSelection({
    required int dayNumber,
    required RestaurantInfo restaurant,
    required bool selected,
  }) async {
    var selection = _daySelections[dayNumber - 1];
    if (selection == null) {
      selection = TripDaySelection.empty(
        tripId: widget.tripId,
        dayNum: dayNumber,
      );
    }
    
    final restaurants = Map<String, SelectedWaypoint>.from(selection.selectedRestaurants);
    final mealKey = restaurant.mealType.name;
    
    if (selected) {
      restaurants[mealKey] = SelectedWaypoint.fromRestaurant(restaurant);
    } else {
      restaurants.remove(mealKey);
    }
    
    selection = selection.copyWith(selectedRestaurants: restaurants);
    
    setState(() {
      _daySelections[dayNumber - 1] = selection!;
    });
    
    try {
      await _tripService.updateDaySelection(selection);
    } catch (e) {
      debugPrint('Error saving restaurant selection: $e');
    }
  }
  
  /// Toggle legacy activity selection
  Future<void> _toggleLegacyActivitySelection({
    required int dayNumber,
    required ActivityInfo activity,
    required bool selected,
  }) async {
    var selection = _daySelections[dayNumber - 1];
    if (selection == null) {
      selection = TripDaySelection.empty(
        tripId: widget.tripId,
        dayNum: dayNumber,
      );
    }
    
    final activities = List<SelectedWaypoint>.from(selection.selectedActivities);
    
    if (selected) {
      activities.add(SelectedWaypoint.fromActivity(activity));
    } else {
      activities.removeWhere((a) => a.name == activity.name);
    }
    
    selection = selection.copyWith(selectedActivities: activities);
    
    setState(() {
      _daySelections[dayNumber - 1] = selection!;
    });
    
    try {
      await _tripService.updateDaySelection(selection);
    } catch (e) {
      debugPrint('Error saving activity selection: $e');
    }
  }

  Widget _buildWaypointItem({
    required IconData icon,
    required String name,
    required String subtitle,
    required Color color,
    String? photoUrl,
    double? rating,
    bool isSelected = false,
    bool showCheckbox = false,
    ValueChanged<bool>? onSelectionChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected && showCheckbox ? _primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected && showCheckbox 
              ? _primary.withValues(alpha: 0.5)
              : const Color(0xFFE5E7EB).withValues(alpha: 0.5),
          width: isSelected && showCheckbox ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: showCheckbox && onSelectionChanged != null 
            ? () => onSelectionChanged(!isSelected)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Checkbox for owner
            if (showCheckbox) ...[
              GestureDetector(
                onTap: onSelectionChanged != null 
                    ? () => onSelectionChanged(!isSelected)
                    : null,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? _primary : _border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  memCacheHeight: 100,
                  maxHeightDiskCache: 100,
                  placeholder: (context, url) => Container(
                    width: 50,
                    height: 50,
                    color: color.withValues(alpha: 0.1),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (!showCheckbox)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFD1D5DB),
              ),
          ],
        ),
      ),
    );
  }

}

/// FAQ Item Widget
class _FAQItem extends StatefulWidget {
  final FAQItem faq;

  const _FAQItem({required this.faq});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
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
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.remove : Icons.add,
                    size: 20,
                    color: context.colors.primary,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.faq.answer,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful map widget for trip day view with fit-bounds and zoom controls
class _TripDayMapWidget extends StatefulWidget {
  final List<LatLng> coordinates;
  final List<Marker> waypointMarkers;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLngBounds bounds;
  final DayItinerary day;
  final Color primary;
  final VoidCallback? onExpandTap;

  const _TripDayMapWidget({
    required this.coordinates,
    required this.waypointMarkers,
    required this.initialCenter,
    required this.initialZoom,
    required this.bounds,
    required this.day,
    required this.primary,
    this.onExpandTap,
  });

  @override
  State<_TripDayMapWidget> createState() => _TripDayMapWidgetState();
}

class _TripDayMapWidgetState extends State<_TripDayMapWidget> with AutomaticKeepAliveClientMixin {
  late final MapController _mapController;
  bool _mapReady = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBounds();
    });
  }
  
  void _fitBounds() {
    if (!_mapReady) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: widget.bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }
  
  void _zoomIn() {
    if (!_mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }
  
  void _zoomOut() {
    if (!_mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }
  
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: widget.initialZoom,
                    onMapReady: () {
                      setState(() => _mapReady = true);
                      _fitBounds();
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
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
                          points: widget.coordinates,
                          strokeWidth: 4.0,
                          color: widget.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Start marker (A)
                        if (widget.coordinates.isNotEmpty)
                          Marker(
                            point: widget.coordinates.first,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        // End marker (B)
                        if (widget.coordinates.isNotEmpty)
                          Marker(
                            point: widget.coordinates.last,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Text('B', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        // Waypoint markers
                        ...widget.waypointMarkers,
                      ],
                    ),
                  ],
                ),
                // Map controls (top-right) - zoom, fit bounds, and fullscreen
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Fullscreen/expand button
                      if (widget.onExpandTap != null)
                        _buildMapButton(
                          icon: Icons.fullscreen,
                          onTap: widget.onExpandTap!,
                        ),
                      if (widget.onExpandTap != null)
                        const SizedBox(height: 8),
                      // Fit to bounds button
                      _buildMapButton(
                        icon: Icons.fit_screen,
                        onTap: _fitBounds,
                      ),
                      const SizedBox(height: 8),
                      // Zoom in button
                      _buildMapButton(
                        icon: Icons.add,
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      // Zoom out button
                      _buildMapButton(
                        icon: Icons.remove,
                        onTap: _zoomOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Stats bar below map (matching plan page)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(
              top: BorderSide(color: context.colors.outline.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Icon(Icons.straighten, color: widget.primary),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.day.route!.distance / 1000).toStringAsFixed(1)} km',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('Distance', style: context.textStyles.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.access_time, color: widget.primary),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.day.estimatedTimeMinutes / 60).toStringAsFixed(1)}h',
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
  
  Widget _buildMapButton({required IconData icon, required VoidCallback onTap}) {
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
