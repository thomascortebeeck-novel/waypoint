import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/components/unified/section_card.dart';
import 'package:waypoint/components/unified/inline_editable_field.dart';
import 'package:waypoint/components/unified/version_selector_bar.dart';
import 'package:waypoint/components/unified/inline_editable_dropdown.dart';
import 'package:waypoint/components/unified/inline_editable_chips.dart';
import 'package:waypoint/components/unified/activity_aware_builder.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/state/day_form_state.dart';
import 'package:waypoint/state/location_search_state.dart';
import 'package:waypoint/state/sub_form_states.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/services/adventure_save_service.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/components/builder/route_info_section.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/models/route_waypoint.dart' show
    RouteWaypoint,
    WaypointType,
    getWaypointIcon,
    getWaypointColor,
    generateChoiceGroupId,
    generateAutoChoiceLabel,
    getWaypointsInChoiceGroup;
import 'package:waypoint/models/waypoint_edit_result.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/utils/activity_utils.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/layout/responsive_content_layout.dart';
import 'package:waypoint/components/adventure/adventure_tags_row.dart';
import 'package:waypoint/components/adventure/review_score_row.dart';
import 'package:waypoint/components/adventure/version_carousel.dart';
import 'package:waypoint/components/adventure/creator_card.dart';
import 'package:waypoint/components/adventure/day_hero_image.dart';
import 'package:waypoint/components/adventure/stat_bar.dart';
import 'package:waypoint/services/seo_service.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/components/adventure/section_header.dart';
import 'package:waypoint/components/adventure/poi_card.dart';
import 'package:waypoint/components/adventure/external_links_row.dart';
import 'package:waypoint/components/adventure/gpx_import_area.dart';
import 'package:waypoint/components/adventure/buy_plan_card.dart';
import 'package:waypoint/components/adventure/breadcrumb_nav.dart';
import 'package:waypoint/components/adventure/action_buttons_row.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_list.dart';
import 'package:waypoint/components/common/price_display_widget.dart';
import 'package:waypoint/components/common/empty_state_widget.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';
import 'package:waypoint/presentation/adventure/tabs/comments_tab.dart';
import 'package:waypoint/services/comment_service.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:waypoint/components/media/media_carousel.dart';
import 'package:waypoint/utils/image_utils.dart';
import 'package:waypoint/components/adventure/stippl_navigation_drawer.dart';
import 'package:waypoint/components/builder/location_search_dialog.dart';
import 'package:waypoint/presentation/adventure/widgets/image_gallery.dart';
import 'package:waypoint/presentation/adventure/widgets/price_widgets.dart';
import 'dart:io';

/// Mode of the adventure detail screen
enum AdventureMode {
  /// Builder mode - editing adventure
  builder,
  
  /// Viewer mode - viewing plan (pre/post purchase)
  viewer,
  
  /// Trip mode - viewing/editing trip
  trip,
}

/// Itinerary view layout: full waypoints list, 50/50 split, or map-heavy (mobile).
enum ItineraryViewMode {
  fullWaypoints, // 100% waypoints, no map
  split50,       // desktop 50/50
  mapHeavy,      // mobile: map + draggable panel
}

/// Thin read-only wrapper for viewer mode
/// Builder uses AdventureFormState directly
class AdventureData {
  final Plan? plan;
  final Trip? trip;
  final PlanVersion? selectedVersion;
  final Map<int, TripDaySelection>? daySelections;
  final MemberPacking? memberPacking; // Current user only
  
  AdventureData.fromPlan(Plan plan, {PlanVersion? version})
      : plan = plan,
        trip = null,
        selectedVersion = version ?? (plan.versions.isNotEmpty ? plan.versions.first : null),
        daySelections = null,
        memberPacking = null;
  
  AdventureData.fromTrip(
    Trip trip,
    Plan sourcePlan, {
    PlanVersion? version,
    Map<int, TripDaySelection>? daySelections,
    MemberPacking? memberPacking,
  }) : plan = sourcePlan,
        trip = trip,
        selectedVersion = version ?? (sourcePlan.versions.isNotEmpty 
            ? sourcePlan.versions.firstWhere(
                (v) => v.id == trip.versionId,
                orElse: () => sourcePlan.versions.isNotEmpty ? sourcePlan.versions.first : throw StateError('No versions available'),
              )
            : null),
        daySelections = daySelections,
        memberPacking = memberPacking;
  
  String get displayName => trip?.title ?? plan?.name ?? '';
  String get displayImage => plan?.heroImageUrl ?? '';
  String get location => 
      (plan?.locations.isNotEmpty == true) 
          ? plan!.locations.first.shortName 
          : (plan?.location ?? '');
  List<DayItinerary> get days => selectedVersion?.days ?? const [];
  int get dayCount => selectedVersion?.durationDays ?? 0;
  Prepare? get prepare => selectedVersion?.prepare;
  LocalTips? get localTips => selectedVersion?.localTips;
  List<FAQItem> get faqItems => plan?.faqItems ?? const [];
  bool get isTrip => trip != null;
  ActivityCategory? get activityCategory => plan?.activityCategory;
}

/// Tab definition for navigation
class TabDefinition {
  final String label;
  final IconData icon;
  
  const TabDefinition(this.label, this.icon);
}

/// Unified adventure detail screen supporting builder, viewer, and trip modes
class AdventureDetailScreen extends StatefulWidget {
  final String? planId;
  final String? tripId;
  final AdventureMode mode;
  
  const AdventureDetailScreen({
    super.key,
    this.planId,
    this.tripId,
    required this.mode,
  }) : assert(
    planId != null || tripId != null || mode == AdventureMode.builder,
    'Either planId or tripId must be provided, or mode must be builder for new plan creation',
  );
  
  @override
  State<AdventureDetailScreen> createState() => _AdventureDetailScreenState();
}

class _AdventureDetailScreenState extends State<AdventureDetailScreen> with TickerProviderStateMixin {
  static const _kDefaultCenter = ll.LatLng(61.0, 8.5); // Norway default
  
  static const _kTransportIcons = <TransportationType, IconData>{
    TransportationType.car: Icons.directions_car,
    TransportationType.flying: Icons.flight,
    TransportationType.boat: Icons.directions_boat,
    TransportationType.foot: Icons.directions_walk,
    TransportationType.bike: Icons.directions_bike,
    TransportationType.train: Icons.train,
    TransportationType.bus: Icons.directions_bus,
    TransportationType.taxi: Icons.local_taxi,
  };
  
  static const _kTransportNames = <TransportationType, String>{
    TransportationType.car: 'Car',
    TransportationType.flying: 'Flying',
    TransportationType.boat: 'Boat',
    TransportationType.foot: 'By Foot',
    TransportationType.bike: 'Bike',
    TransportationType.train: 'Train',
    TransportationType.bus: 'Bus',
    TransportationType.taxi: 'Taxi',
  };
  
  final PlanService _planService = PlanService();
  final TripService _tripService = TripService();
  final StorageService _storageService = StorageService();
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();
  final CommentService _commentService = CommentService();
  late final AdventureSaveService _saveService;
  
  // Viewer mode data
  AdventureData? _adventureData;
  Plan? _plan;
  Trip? _trip;
  
  // Builder mode state
  AdventureFormState? _formState;
  
  bool _isLoading = true;
  String? _errorMessage;
  
  // FIX: Prevents DrawerController hit-test on Frame 0.
  // During Frame 0, Scaffold has drawer:null so no DrawerController/SizedBox.shrink
  // gets hit-tested. Frame 2 onward, drawer is permanently set.
  bool _drawerReady = false;
  bool _drawerHitTestReady = false;
  
  // Purchase status and trip ownership
  bool? _hasPurchased; // null = not checked yet, true/false = checked
  bool? _isTripOwner; // null = not trip mode, true/false = trip owner status
  
  // Version selection (persistent across tabs)
  int _selectedVersionIndex = 0;
  List<PlanVersion> _availableVersions = [];
  
  // Map controllers for each day (for auto-fit on tab switch)
  final Map<int, WaypointMapController> _dayMapControllers = {};
  
  // Cache for user futures to avoid duplicate FutureBuilder calls
  final Map<String, Future<UserModel?>> _userFutureCache = {};
  
  // Change tracking for tab-switch saving
  bool _hasUnsavedChanges = false;
  
  // Store original error handler to restore in dispose
  void Function(FlutterErrorDetails)? _originalErrorHandler;
  
  // Track LocalTips listeners for cleanup
  final List<VoidCallback> _localTipsListeners = [];
  
  // Auto-save lock to prevent concurrent saves
  bool _isAutoSaving = false;
  
  // Location search listener suppression and timer
  bool _suppressLocationListener = false;
  Timer? _locationSearchTimer;
  
  // Navigation drawer state (replaces TabController)
  NavigationItem _currentNavigationItem = NavigationItem.overview;
  int _selectedDay = 1; // For itinerary day tabs

  /// Itinerary layout mode (desktop: fullWaypoints or split50; mobile clamped to mapHeavy).
  ItineraryViewMode _itineraryViewMode = ItineraryViewMode.split50;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // TabController for day tabs (replaces custom horizontal scrolling)
  TabController? _dayTabController;

  /// Flag to prevent scheduling multiple simultaneous TabController updates.
  bool _dayTabControllerUpdateScheduled = false;

  // DraggableScrollableSheet controller for mobile itinerary panel (3-state drag)
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  
  // Snap sizes for mobile itinerary panel (fraction of screen height)
  static const double _snapMin = 0.12; // map ~full, handle peeking
  static const double _snapMid = 0.50; // 50/50
  static const double _snapMax = 0.92; // waypoints ~full, map mostly hidden
  
  // Map visibility for legacy layouts (e.g. desktop 50/50). Itinerary tab now uses
  // collapsible SliverAppBar, so this is vestigial there but still used by _buildItineraryLayout.
  bool _mapVisible = true;
  
  // Header height for sticky sidebar
  double _headerHeight = 220.0; // Safe default until first measurement
  
  // Highlight controllers map to prevent memory leaks
  final Map<int, TextEditingController> _highlightControllers = {};
  
  // Duration listener tracking
  VoidCallback? _durationListener;
  
  // Cached creator user future
  Future<UserModel?>? _creatorUserFuture;
  
  // Cached current user future (for privacy mode validation)
  Future<UserModel?>? _currentUserFuture;

  // Flag to track if we're in reassemble (hot reload) to prevent problematic operations
  bool _isReassembling = false;

  /// Safely call setState, deferring to post-frame if we're currently in a frame.
  /// This prevents DrawerController hit-test errors when setState is called
  /// during persistentCallbacks or postFrameCallbacks phase.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }
  
  /// Defers _isLoading = false until _drawerReady is true.
  /// Polls each frame to avoid the DrawerController hit-test crash.
  void _deferLoadingComplete() {
    void check(Duration _) {
      if (!mounted) return;
      if (_drawerReady) {
        setState(() => _isLoading = false);
      } else {
        WidgetsBinding.instance.addPostFrameCallback(check);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(check);
  }
  
  @override
  void initState() {
    super.initState();
    
    // Suppress known Flutter web DrawerController hit-test errors
    // These are non-fatal and occur during Scaffold layout on web
    // The drawer still functions correctly despite these errors
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is AssertionError) {
        final errorString = details.exception.toString();
        final stackString = details.stack?.toString() ?? '';
        
        // Suppress DrawerController hit-test errors (non-fatal on web)
        // These are framework timing issues that don't affect functionality
        if (errorString.contains('Cannot hit test a render box') &&
            (errorString.contains('DrawerController') || stackString.contains('DrawerController'))) {
          debugPrint('[suppressed] DrawerController hit-test during layout (non-fatal)');
          return;
        }
        
        // NOTE: Removed RenderFlex error suppression to see real layout errors
        // If errors occur, they need to be fixed at the source, not suppressed
      }
      // Call original error handler for all other errors
      if (_originalErrorHandler != null) {
        _originalErrorHandler!(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    
    // Initialize carousel controller for image gallery
    // Clear SEO for builder and trip modes (not for SEO)
    if (widget.mode == AdventureMode.builder || widget.mode == AdventureMode.trip) {
      if (kIsWeb) {
        SeoService.clearSeoMetaTags();
      }
    }
    _saveService = AdventureSaveService(
      planService: _planService,
      storageService: _storageService,
      userService: _userService,
    );
    
    // FIX: Delay drawer creation until after Scaffold's initial layout is fully complete.
    // The issue: Scaffold's CustomMultiChildLayout hit-tests the drawer slot during
    // its own layout phase, before the drawer widget has been laid out. We need to
    // ensure the drawer doesn't exist until Scaffold has completed at least one
    // full layout cycle.
    // Solution: Use persistent frame callback to wait for layout completion, then
    // add additional delays to ensure all hit-test operations finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[adventure_detail] Frame 1: Scaffold initial layout started');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[adventure_detail] Frame 2: Scaffold layout continuing');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[adventure_detail] Frame 3: Scaffold layout should be complete');
          // Use persistent frame callback to wait for next frame after layout
          SchedulerBinding.instance.addPostFrameCallback((_) {
            debugPrint('[adventure_detail] Frame 4: Post-layout frame, adding delay');
            // Additional delay to ensure all hit-test operations complete
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) {
                debugPrint('[adventure_detail] Setting _drawerReady = true');
                setState(() => _drawerReady = true);
                // Enable hit-testing after drawer has had time to lay out completely
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    debugPrint('[adventure_detail] Setting _drawerHitTestReady = true');
                    setState(() => _drawerHitTestReady = true);
                  }
                });
              }
            });
          });
        });
      });
    });
    
    // Load adventure data after first frame (existing fix)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAdventure();
      }
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // During hot reload, prevent operations that might cause layout issues
    // LayoutBuilder will rebuild naturally, but we shouldn't trigger
    // additional setState calls or controller recreations during reassemble
    _isReassembling = true;
    
    // Reset flag after reassemble completes (use multiple strategies to ensure it resets)
    // Strategy 1: Post-frame callback
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _isReassembling = false;
      }
    });
    
    // Strategy 2: Microtask as fallback
    Future.microtask(() {
      if (mounted) {
        _isReassembling = false;
      }
    });
    
    // Strategy 3: Timeout fallback (safety net)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isReassembling = false;
      }
    });
  }
  
  void _setupChangeTracker() {
    if (_formState == null || widget.mode != AdventureMode.builder) return;
    if (_formState!.editingPlan == null) return;
    
    // Set up listener for form changes (only tracks dirty state, no timer)
    _formState!.removeListener(_onFormStateChanged);
    _formState!.addListener(_onFormStateChanged);
  }
  
  void _onFormStateChanged() {
    if (_formState == null || _formState!.isSaving) return;
    if (!mounted) return; // Don't process changes if not mounted
    if (_isReassembling) return; // Skip during hot reload
    
    _hasUnsavedChanges = true;
    // Trigger rebuild to update save indicator (defensive for hot reload)
    try {
      if (mounted && !_isReassembling && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
        setState(() {});
      } else if (!_isReassembling) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isReassembling) {
      setState(() {});
          }
        });
      }
    } catch (e) {
      // Ignore errors during hot reload
      Log.w('adventure_detail', 'Error in _onFormStateChanged: $e');
    }
  }
  
  Future<bool> _performAutoSave() async {
    if (_formState == null || _formState!.editingPlan == null) return false;
    if (_formState!.isSaving || _isAutoSaving) return false; // Already saving
    
    _isAutoSaving = true;
    try {
      final result = await _saveService.saveDraft(_formState!);
      if (mounted && result.success) {
        _formState!.lastSavedAt = DateTime.now();
        _formState!.saveStatus = 'Saved';
        return true; // Success
      } else if (mounted && result.errors.isNotEmpty) {
        _formState!.saveStatus = 'Failed to save';
        return false; // Failure
      }
      return false;
    } catch (e) {
      if (mounted) {
        _formState?.saveStatus = 'Failed to save';
      }
      return false; // Failure
    } finally {
      _isAutoSaving = false;
    }
  }
  
  /// Handle navigation item selection with auto-save
  void _onNavigationItemSelected(NavigationItem item) {
    // Pre-create the day TabController when navigating TO itinerary so the
    // first build of _buildItineraryTab already has a controller and skips
    // the spinner + re-schedule cycle (avoids setState-during-build).
    if (item == NavigationItem.itinerary) {
      final dayCount = _dayCount;
      Log.i('adventure_detail', 'Itinerary selected: dayCount=$dayCount, controller=${_dayTabController != null ? "length=${_dayTabController!.length}" : "null"}');
      if (dayCount > 0 &&
          (_dayTabController == null || _dayTabController!.length != dayCount)) {
        Log.i('adventure_detail', 'Itinerary: creating day tab controller now (dayCount=$dayCount)');
        _createDayTabController(dayCount);
      } else {
        Log.i('adventure_detail', 'Itinerary: skipping create (dayCount=$dayCount, already correct)');
      }
    }

    if (widget.mode == AdventureMode.builder &&
        _formState != null &&
        _hasUnsavedChanges) {
      _performAutoSave().then((success) {
        if (mounted && success == true) {
          _hasUnsavedChanges = false; // Only clear if save succeeded
        }
      if (mounted) {
          setState(() => _currentNavigationItem = item); // Navigate regardless
        }
      });
    } else {
      setState(() => _currentNavigationItem = item);
    }
  }
  
  /// Handle day tab selection within itinerary (with auto-save)
  void _onDayTabChanged(int dayNum) {
    if (widget.mode == AdventureMode.builder &&
        _formState != null &&
        _hasUnsavedChanges) {
      _performAutoSave().then((success) {
        if (mounted && success == true) {
          _hasUnsavedChanges = false; // Only clear if save succeeded
        }
        if (mounted) {
          setState(() => _selectedDay = dayNum); // Navigate regardless
          _resetMobilePanelToMid();
        }
      });
    } else {
      setState(() => _selectedDay = dayNum);
      _resetMobilePanelToMid();
    }
  }

  /// Reset draggable panel to 50/50 when switching days (optional UX).
  void _resetMobilePanelToMid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _draggableController.isAttached) {
        _draggableController.animateTo(
          _snapMid,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _setupDurationListener() {
    if (_formState == null || _formState!.versions.isEmpty) return;
    final ctrl = _formState!.activeVersion.durationCtrl;
    if (_durationListener != null) ctrl.removeListener(_durationListener!);
    _durationListener = () {
      if (mounted) {
        setState(() {}); // Just rebuild, no tab controller needed
      }
    };
    ctrl.addListener(_durationListener!);
  }
  
  
  void _setupLocationSearchListener() {
    if (_formState == null) return;
    
    _formState!.locationCtrl.addListener(_onLocationQueryChanged);
  }
  
  void _onLocationQueryChanged() {
    if (_suppressLocationListener || _formState == null) return;
    
    final query = _formState!.locationCtrl.text.trim();
    final locationSearch = _formState!.locationSearch;
    
    // Cancel pending debounce
    _locationSearchTimer?.cancel();
    
    if (query.length < 2) {
      locationSearch.isSearching = false;
      locationSearch.suggestions = [];
      locationSearch.lastQuery = '';
      locationSearch.notifyListeners();
      return;
    }
    
    // Skip if query hasn't changed AND we already have suggestions (avoid duplicate searches)
    // But if we're currently searching for this query, don't start another search
    if (query == locationSearch.lastQuery) {
      if (locationSearch.suggestions.isNotEmpty) {
        // Already have results for this query
        locationSearch.isSearching = false;
        locationSearch.notifyListeners();
        return;
      }
      if (locationSearch.isSearching) {
        // Already searching for this query, wait for it to complete
        return;
      }
    }
    
    // Start new search
    locationSearch.isSearching = true;
    locationSearch.lastQuery = query;
    locationSearch.notifyListeners();
    
    _locationSearchTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _formState == null) return;
      if (_formState!.locationCtrl.text.trim() != query) return; // stale
      
      try {
        final placesService = GooglePlacesService();
        final predictions = await placesService.searchPlaces(query: query);
        
        if (!mounted || _formState == null) return;
        if (_formState!.locationCtrl.text.trim() != query) return; // stale
        
        // Update suggestions and clear loading state
        locationSearch.suggestions = predictions;
        locationSearch.isSearching = false;
        locationSearch.notifyListeners();
        
        Log.i('location_search', 'Found ${predictions.length} suggestions for "$query"');
      } catch (e, stackTrace) {
        // Log error for debugging
        Log.e('location_search', 'Failed to search places for "$query": $e', e, stackTrace);
        if (mounted && _formState != null) {
          // Always clear loading state on error
          locationSearch.isSearching = false;
          locationSearch.suggestions = [];
          locationSearch.notifyListeners();
        }
      }
    });
  }
  
  Future<void> _loadAdventure() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      if (widget.mode == AdventureMode.builder) {
        // Builder mode: load or create form state
        if (widget.planId != null) {
          Log.i('adventure_detail', 'Loading plan for builder mode: ${widget.planId}');
          // Editing existing plan - add timeout to prevent infinite loading
          final plan = await _planService.loadFullPlan(widget.planId!)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  Log.e('adventure_detail', 'Plan load timed out after 30 seconds for planId: ${widget.planId}');
                  throw TimeoutException('Loading plan timed out after 30 seconds');
                },
              );
          Log.i('adventure_detail', 'Plan loaded: ${plan?.name ?? "null"}');
          if (plan == null) {
            throw Exception('Plan not found');
          }
          _formState = AdventureFormState.fromPlan(plan);
          Log.i('adventure_detail', 'Form state created from plan');
        } else {
          // New plan
          Log.i('adventure_detail', 'Creating new plan form state');
          _formState = AdventureFormState.initial();
          Log.i('adventure_detail', 'New plan form state created');
        }
        
        // Setup duration listener for tab rebuild
        Log.i('adventure_detail', 'Setting up duration listener');
        _setupDurationListener();
        Log.i('adventure_detail', 'Duration listener setup complete');
        
        // Setup LocalTips listeners to sync controllers to model
        Log.i('adventure_detail', 'Setting up LocalTips listeners');
        _setupLocalTipsListeners();
        Log.i('adventure_detail', 'LocalTips listeners setup complete');
        
        // Setup location search listener
        Log.i('adventure_detail', 'Setting up location search listener');
        _setupLocationSearchListener();
        Log.i('adventure_detail', 'Location search listener setup complete');
        
        // Setup change tracker for tab-switch saving
        Log.i('adventure_detail', 'Setting up change tracker');
        _setupChangeTracker();
        Log.i('adventure_detail', 'Change tracker setup complete');
        
        // Cache creator user future
        Log.i('adventure_detail', 'Caching creator user future');
        _creatorUserFuture = _getCreatorUser();
        Log.i('adventure_detail', 'Creator user future cached');
        
        // Cache current user future for privacy mode validation
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          _currentUserFuture = _userService.getUserById(currentUser.uid);
        } else {
          _currentUserFuture = Future<UserModel?>.value(null);
        }
        
        Log.i('adventure_detail', 'Form state loaded, deferring _isLoading = false until drawer ready');
        _deferLoadingComplete();
        _ensureDayTabControllerAfterLoad();
        Log.i('adventure_detail', '_isLoading will be set to false when drawer is ready');
        Log.i('adventure_detail', 'Builder mode setup complete');
      } else if (widget.mode == AdventureMode.trip && widget.tripId != null) {
        // Load trip mode
        final trip = await _tripService.getTripById(widget.tripId!);
        if (trip == null) {
          throw Exception('Trip not found');
        }
        
        final plan = await _planService.loadFullPlan(trip.planId);
        if (plan == null) {
          throw Exception('Plan not found');
        }
        
        // Check if current user is trip owner
        final currentUser = FirebaseAuth.instance.currentUser;
        final isTripOwner = currentUser != null && trip.isOwner(currentUser.uid);
        
        // Check purchase status (owner always has access)
        bool hasPurchased;
        if (isTripOwner) {
          hasPurchased = true;
        } else {
          // Participant - check if they have access via trip membership
          hasPurchased = true; // Participants have access to the trip's plan
        }
        
        // Load day selections and member packing in parallel (type-safe, no casts)
        // Start both futures in parallel (both start before either await)
        final daySelectionsResult = _tripService.getDaySelections(widget.tripId!);
        final memberPackingResult = currentUser != null
            ? _tripService.getMemberPacking(widget.tripId!, currentUser.uid)
            : Future<MemberPacking?>.value(null);
        
        // Await both (still parallel execution, but type-safe)
        final daySelectionsList = await daySelectionsResult;
        final memberPacking = await memberPackingResult;
        
        // Convert List<TripDaySelection> to Map<int, TripDaySelection> using dayNum as key
        final daySelections = {
          for (final selection in daySelectionsList)
            selection.dayNum: selection
        };
        
        PlanVersion? selectedVersion;
        if (trip.versionId != null && plan.versions.isNotEmpty) {
          selectedVersion = plan.versions.firstWhere(
            (v) => v.id == trip.versionId,
            orElse: () => plan.versions.first,
          );
        } else {
          selectedVersion = plan.versions.isNotEmpty ? plan.versions.first : null;
        }
        
        _safeSetState(() {
          _trip = trip;
          _plan = plan;
          _availableVersions = plan.versions;
          _selectedVersionIndex = plan.versions.indexWhere(
            (v) => v.id == selectedVersion?.id,
          );
          if (_selectedVersionIndex < 0 && plan.versions.isNotEmpty) {
            _selectedVersionIndex = 0;
          } else if (plan.versions.isEmpty) {
            _selectedVersionIndex = -1;
          }
          _adventureData = AdventureData.fromTrip(
            trip,
            plan,
            version: selectedVersion,
            daySelections: daySelections,
            memberPacking: memberPacking,
          );
          _isTripOwner = isTripOwner;
          _hasPurchased = hasPurchased;
        });
        _deferLoadingComplete();
        _ensureDayTabControllerAfterLoad();
      } else if (widget.planId != null) {
        // Load viewer mode
        final plan = await _planService.loadFullPlan(widget.planId!);
        if (plan == null) {
          throw Exception('Plan not found');
        }
        
        // Check purchase status
        final currentUser = FirebaseAuth.instance.currentUser;
        bool? hasPurchased;
        if (currentUser != null && widget.planId != null) {
          hasPurchased = await _orderService.hasPurchased(currentUser.uid, widget.planId!);
        } else {
          hasPurchased = false;
        }
        
        final selectedVersion = plan.versions.isNotEmpty ? plan.versions.first : null;
        _safeSetState(() {
          _plan = plan;
          _availableVersions = plan.versions;
          _selectedVersionIndex = plan.versions.isNotEmpty ? 0 : -1;
          _adventureData = AdventureData.fromPlan(plan, version: selectedVersion);
          _hasPurchased = hasPurchased;
        });
        _deferLoadingComplete();
        _ensureDayTabControllerAfterLoad();

        // Cache creator user future for viewer mode
        _creatorUserFuture = _getCreatorUser();
        
        // Cache current user future for privacy mode validation
        if (currentUser != null) {
          _currentUserFuture = _userService.getUserById(currentUser.uid);
        } else {
          _currentUserFuture = Future<UserModel?>.value(null);
        }
        
        // Apply SEO for published plans in viewer mode
        if (plan.isPublished && kIsWeb) {
          SeoService.updatePlanDetailMetaTags(plan);
        } else if (kIsWeb) {
          // Unpublished plans should not be indexed
          SeoService.clearSeoMetaTags();
        }
      } else {
        throw Exception('Either planId or tripId must be provided');
      }
    } catch (e, stackTrace) {
      // Log the error for debugging
      Log.e('adventure_detail', 'Failed to load adventure: $e', e, stackTrace);
      if (mounted) {
        _safeSetState(() {
          _errorMessage = 'Failed to load adventure: ${e.toString()}';
          _hasPurchased = null; // Reset on error
          _isTripOwner = null;
        });
        _deferLoadingComplete();
      }
    }
  }
  
  void _onVersionChanged(int newIndex) {
    if (newIndex < 0 || newIndex >= _availableVersions.length) return;
    
    setState(() {
      _selectedVersionIndex = newIndex;
      final newVersion = _availableVersions[newIndex];
      if (_trip != null) {
        _adventureData = AdventureData.fromTrip(_trip!, _plan!, version: newVersion);
      } else {
        _adventureData = AdventureData.fromPlan(_plan!, version: newVersion);
      }
    });

  }
  int get _dayCount {
    if (widget.mode == AdventureMode.builder) {
      if (_formState == null || _formState!.versions.isEmpty) return 0;
      return _formState!.activeVersion.durationCtrl.text.isEmpty 
          ? 0 
          : int.tryParse(_formState!.activeVersion.durationCtrl.text) ?? 0;
    }
    return _adventureData?.dayCount ?? 0;
  }
  
  // ============================================================
  // CENTERED HEADER WRAPPER
  // Title + Stars + Owner Attribution + TabBar + Action icons
  // All constrained to same max-width as content
  // Breadcrumbs moved to unified nav bar
  // ============================================================
  Widget _buildCenteredHeader(BuildContext context) {
    // Safe MediaQuery access with error handling during resize
    bool isDesktop = false;
    try {
      final width = MediaQuery.maybeOf(context)?.size.width ?? 
                    MediaQuery.of(context).size.width;
      isDesktop = WaypointBreakpoints.isDesktop(width);
    } catch (e) {
      // During resize, MediaQuery might be temporarily unavailable
      // Default to mobile layout to avoid crashes
      isDesktop = false;
    }

    final headerContent = Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildTitleSection(context),     // title + stars
                const SizedBox(height: 4),      // tight gap to location line
                _buildLocationLine(context),
                const SizedBox(height: 12),
                _buildOwnerAttribution(context), // owner attribution row
                const SizedBox(height: 16),
                // Tabs removed - now using navigation drawer
              ],
            ),
          ),
        ),
      ),
    );

    // Return headerContent directly — no dynamic measurement to avoid layout crashes during resize
    // _headerHeight uses static default (220.0) which is close enough for sticky sidebar positioning
    return headerContent;
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    // Handle loading state where _formState or _adventureData might be null
    final displayName = widget.mode == AdventureMode.builder 
        ? (_formState?.nameCtrl.text.isEmpty ?? true ? 'New Adventure' : _formState?.nameCtrl.text ?? 'New Adventure')
        : (_adventureData?.displayName ?? 'Loading...');

    return BreadcrumbNav(
      activityCategory: widget.mode == AdventureMode.builder
          ? _formState?.activityCategory
          : _plan?.activityCategory,
      adventureTitle: displayName,
      locations: widget.mode == AdventureMode.builder
          ? _formState?.locations
          : _plan?.locations,
      onBackToExplore: () => context.go('/explore'),
      onActivityTap: () {
        final activity = widget.mode == AdventureMode.builder
            ? _formState?.activityCategory
            : _plan?.activityCategory;
        if (activity != null) {
          context.go('/explore?activity=${activity.name}');
        }
      },
    );
  }

  // ============================================================
  // TAB ROW + ACTION ICONS — REMOVED (replaced by drawer navigation)
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // *** SINGLE SCAFFOLD - prevents DrawerController from being recreated
    // when _isLoading changes, which caused:
    // "Cannot hit test a render box that has never been laid out"
    // Multiple Scaffold returns = new DrawerController each time = crash
    
    final displayName = (!_isLoading && widget.mode == AdventureMode.builder && _formState != null)
        ? (_formState!.nameCtrl.text.isEmpty ? 'New Adventure' : _formState!.nameCtrl.text)
        : (!_isLoading && _adventureData != null)
            ? _adventureData!.displayName
            : '';

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = WaypointBreakpoints.isDesktop(screenWidth);
    final effectiveMode = isDesktop ? _itineraryViewMode : ItineraryViewMode.mapHeavy;
    final useCompactBar = _currentNavigationItem == NavigationItem.itinerary;
    final showItineraryBottomBar = _currentNavigationItem == NavigationItem.itinerary &&
        widget.mode == AdventureMode.builder;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: !showItineraryBottomBar,
      appBar: useCompactBar ? _buildCompactItineraryAppBar(context) : _buildUnifiedNavBar(context),
      // CRITICAL: Only create drawer after both _drawerReady AND _drawerHitTestReady are true.
      // This ensures DrawerController is never hit-tested before it's fully laid out.
      drawer: (_drawerReady && _drawerHitTestReady)
          ? RepaintBoundary(
              // RepaintBoundary isolates the drawer from Scaffold's layout hit-testing
              child: StipplNavigationDrawer(
                // Both flags ensure DrawerController is only created AFTER
                // Scaffold's initial layout completes AND hit-testing is safe.
                // Once created, it's never destroyed — _isLoading only affects content inside.
                isLoading: _isLoading || _errorMessage != null,
                selectedItem: _currentNavigationItem,
                onItemSelected: _onNavigationItemSelected,
                title: displayName,
                isPlanMode: widget.mode != AdventureMode.trip,
                onShare: () {
                  // TODO: Implement share functionality
                },
                onLike: () {
                  // TODO: Implement like functionality
                },
                onInvite: widget.mode == AdventureMode.trip
                    ? () {
                        // TODO: Implement invite functionality
                      }
                    : null,
                isLiked: false,
              ),
            )
          : null,
      bottomNavigationBar: showItineraryBottomBar ? _buildItineraryBottomBar(context) : null,
      body: Builder(
        builder: (context) {
          // Error boundary: catch build errors and show fallback UI instead of blank screen
          try {
            return _buildBody(context);
          } catch (e, stackTrace) {
            Log.e('adventure_detail', 'Error building body', e, stackTrace);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: WaypointTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try refreshing the page',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Try to rebuild
                        setState(() {});
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAdventure,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Builder mode - no form state
    if (widget.mode == AdventureMode.builder && _formState == null) {
      return const Center(child: Text('No form state available'));
    }
    
    // Viewer/trip mode - no adventure data
    if (widget.mode != AdventureMode.builder && _adventureData == null) {
      return const Center(child: Text('No adventure data available'));
    }
    
    // Normal content - same as current try/catch LayoutBuilder block
    return LayoutBuilder(
      builder: (context, constraints) {
        // Defensive check: ensure constraints are valid
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        
        try {
          final screenWidth = constraints.maxWidth;
          final isDesktop = WaypointBreakpoints.isDesktop(screenWidth);
          
          // Safe MediaQuery access during resize
          double screenHeight;
          try {
            screenHeight = MediaQuery.maybeOf(context)?.size.height ??
                          MediaQuery.of(context).size.height;
          } catch (e) {
            // Fallback during resize
            screenHeight = constraints.maxHeight;
          }
          
          // KEY FIX: Itinerary tab needs bounded height (uses Expanded + Row).
          // NestedScrollView gives its body unbounded height → crashes.
          // Use direct Column layout for itinerary tab instead.
          if (_currentNavigationItem == NavigationItem.itinerary) {
            // Extra null guard: _isLoading is checked above but be defensive.
            if (widget.mode == AdventureMode.builder && _formState == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (widget.mode != AdventureMode.builder && _adventureData == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildItineraryTab();
          }
          
          return Stack(
            fit: StackFit.expand,
            children: [
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(child: _buildCenteredHeader(context)),
                ],
                body: _buildNavigationContent(),
              ),
              
              // Sticky price card sidebar (desktop, overview tab only)
              if (isDesktop && _currentNavigationItem == NavigationItem.overview)
                Positioned(
                  top: _headerHeight + 20,
                  right: 24,
                  width: 320,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight - _headerHeight - 60,
                    ),
                    child: SingleChildScrollView(
                      child: _buildPriceCard(context),
                    ),
                  ),
                ),
              
              // Sticky bottom bar for mobile/tablet
              if (!isDesktop)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMobileBuyPlanBar(),
                ),
            ],
          );
        } catch (e, stackTrace) {
          // Log so we don't mask the real cause of "endless loading" on itinerary.
          Log.e('adventure_detail', 'Body layout error (itinerary or resize): $e', e, stackTrace);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Layout error: ${e.toString()}', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
  
  double? _getPrice() {
    if (widget.mode == AdventureMode.builder) {
      return double.tryParse(_formState?.priceCtrl.text ?? '');
    } else if (_plan?.versions.isNotEmpty == true) {
      return _plan!.versions.first.price;
    }
    return null;
  }
  
  Widget _buildMobileBuyPlanBar() {
    // Get price (null-safe)
    final price = _getPrice();
    
    // Hide if price is null or 0 (free plan in viewer mode)
    if (price == null || (widget.mode != AdventureMode.builder && price == 0.0)) {
      return const SizedBox.shrink();
    }
    
    // In builder mode, require formState
    if (widget.mode == AdventureMode.builder && _formState == null) {
      return const SizedBox.shrink();
    }
    
    // Hide if purchase status is not yet checked (loading)
    if (_hasPurchased == null && widget.mode != AdventureMode.builder) {
      return const SizedBox.shrink();
    }
    
    // Hide in trip mode
    if (widget.mode == AdventureMode.trip) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border(
          top: BorderSide(
            color: WaypointColors.border,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WaypointSpacing.pagePaddingMobile,
        vertical: 12.0,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Price display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.mode == AdventureMode.builder)
                    Text(
                      'Set your price',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: WaypointColors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      'Get this adventure',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: WaypointColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 2),
                  PriceDisplayWidget(
                    price: price,
                    fontSize: 20,
                  ),
                ],
              ),
            ),
            // Buy/Edit/Start Trip button
            if (widget.mode == AdventureMode.builder)
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _formState!.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '€ ',
                    hintText: '0.00',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: WaypointColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: WaypointColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: WaypointColors.primary, width: 2),
                    ),
                  ),
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (_hasPurchased == true)
              SizedBox(
                width: 120,
                height: 40,
                child: FilledButton(
                  onPressed: () {
                    if (widget.planId != null) {
                      context.push('/mytrips/onboarding/${widget.planId}/name');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: WaypointColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Start Trip',
                    style: WaypointTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: 120,
                height: 40,
                child: FilledButton(
                  onPressed: () {
                    // TODO: Implement buy plan functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buy plan functionality coming soon')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: WaypointColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Buy',
                    style: WaypointTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // ============================================================================
  // VIEWER MODE TABS
  // ============================================================================
  
  Widget _buildUnlockBanner({String? customMessage}) {
    return Container(
      margin: const EdgeInsets.only(top: WaypointSpacing.sectionGap),
      padding: const EdgeInsets.all(WaypointSpacing.cardPadding),
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        border: Border.all(color: WaypointColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: WaypointColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customMessage ?? 'Unlock Full Plan',
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Purchase this plan to see all content',
                  style: WaypointTypography.bodyMedium.copyWith(
                    color: WaypointColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              // Scroll to buy bar or trigger purchase flow
              // For now, show snackbar - can be enhanced to scroll to buy bar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scroll down to purchase this plan')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: WaypointColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('View Pricing'),
          ),
        ],
      ),
    );
  }
  
  // ============================================================================
  // TRIP MODE TABS
  // ============================================================================
  
  Widget _buildTripOverviewTab() {
    if (_adventureData == null || _trip == null || _plan == null) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: ResponsiveContentLayout(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WaypointSpacing.sectionGap),
              
              // Trip Image (editable if owner)
              if (_trip!.usePlanImage || _trip!.customImages == null)
                _buildViewerHeroImage(_plan!.heroImageUrl)
              else if (_trip!.customImages != null)
                _buildViewerHeroImage(_trip!.customImages!['large'] ?? _trip!.customImages!['original'] ?? _plan!.heroImageUrl),
              
              const SizedBox(height: WaypointSpacing.sectionGap),
              
              // Trip Title (editable if owner)
              InlineEditableField(
                label: 'Trip Title',
                displayValue: _trip!.title ?? _plan!.name,
                isEditable: false, // TODO: Implement inline editing for trip title
              ),
              
              const SizedBox(height: WaypointSpacing.subsectionGap),
              
              // Trip Dates (editable if owner)
              if (_trip!.startDate != null || _trip!.endDate != null || _isTripOwner == true)
                SectionCard(
                  title: 'Trip Dates',
                  icon: Icons.calendar_today,
                  children: [
                    if (_trip!.startDate != null)
                      InlineEditableField(
                        label: 'Start Date',
                        displayValue: _trip!.startDate!.toString().split(' ')[0],
                        isEditable: false, // TODO: Implement date picker for trip dates
                      ),
                    if (_trip!.endDate != null)
                      InlineEditableField(
                        label: 'End Date',
                        displayValue: _trip!.endDate!.toString().split(' ')[0],
                        isEditable: false, // TODO: Implement date picker for trip dates
                      ),
                  ],
                ),
              
              const SizedBox(height: WaypointSpacing.subsectionGap),
              
              // Owner Info
              SectionCard(
                title: 'Trip Owner',
                icon: Icons.person,
                children: [
                  FutureBuilder<UserModel?>(
                    future: _userFutureCache.putIfAbsent(
                      _trip!.ownerId,
                      () => _userService.getUserById(_trip!.ownerId),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final user = snapshot.data!;
                        return CreatorCard(
                          avatarUrl: user.photoUrl,
                          name: user.displayName,
                          bio: null,
                          creatorId: _trip!.ownerId,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              
              // Participant List (if owner)
              if (_isTripOwner == true && _trip!.memberIds.isNotEmpty) ...[
                const SizedBox(height: WaypointSpacing.subsectionGap),
                SectionCard(
                  title: 'Participants',
                  icon: Icons.people,
                  children: _trip!.memberIds.map((memberId) {
                    // Cache the future to avoid duplicate calls
                    final userFuture = _userFutureCache.putIfAbsent(
                      memberId,
                      () => _userService.getUserById(memberId),
                    );
                    return FutureBuilder<UserModel?>(
                      future: userFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final user = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: CreatorCard(
                              avatarUrl: user.photoUrl,
                              name: user.displayName,
                              bio: null,
                              creatorId: memberId,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  }).toList(),
                ),
              ],
              
              // Invite Participants button (if owner)
              if (_isTripOwner == true) ...[
                const SizedBox(height: WaypointSpacing.subsectionGap),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Navigate to invite participants screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite participants coming soon')),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Participants'),
                  style: FilledButton.styleFrom(
                    backgroundColor: WaypointColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTripPrepareTab() {
    if (_adventureData == null) return const SizedBox.shrink();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: ResponsiveContentLayout(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WaypointSpacing.sectionGap),
              
              // Version selector if multiple versions
              if (_availableVersions.length > 1)
                VersionSelectorBar.fromPlanVersions(
                  versions: _availableVersions,
                  activeIndex: _selectedVersionIndex,
                  onChanged: _onVersionChanged,
                ),
              
              // Prepare content from plan (read-only)
              if (_adventureData!.prepare != null)
                _buildPrepareContent(_adventureData!.prepare!),
              
              // Packing checklist (inline, editable for both owner and participants)
              if (_adventureData!.selectedVersion?.packingCategories.isNotEmpty ?? false) ...[
                const SizedBox(height: WaypointSpacing.sectionGap),
                SectionCard(
                  title: 'Packing Checklist',
                  icon: Icons.backpack,
                  children: _adventureData!.selectedVersion!.packingCategories.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 8),
                          child: Text(
                            category.name,
                            style: WaypointTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...category.items.map((item) {
                          final isChecked = _adventureData!.memberPacking?.items[item.id] ?? false;
                          return CheckboxListTile(
                            title: Text(item.name),
                            subtitle: item.description != null && item.description!.isNotEmpty
                                ? Text(
                                    item.description!,
                                    style: WaypointTypography.bodyMedium.copyWith(
                                      color: WaypointColors.textSecondary,
                                    ),
                                  )
                                : null,
                            value: isChecked,
                            onChanged: (checked) async {
                              if (checked != null && widget.tripId != null) {
                                try {
                                  await _tripService.toggleMemberPackingItem(
                                    tripId: widget.tripId!,
                                    memberId: currentUser.uid,
                                    itemId: item.id,
                                    checked: checked,
                                  );
                                  // Update local state instead of full reload
                                  if (mounted) {
                                    setState(() {
                                      if (_adventureData?.memberPacking == null) {
                                        _adventureData = _adventureData != null
                                            ? AdventureData.fromTrip(
                                                _trip!,
                                                _plan!,
                                                version: _adventureData!.selectedVersion,
                                                daySelections: _adventureData!.daySelections,
                                                memberPacking: MemberPacking(
                                                  id: currentUser.uid,
                                                  tripId: widget.tripId!,
                                                  memberId: currentUser.uid,
                                                  items: {item.id: checked},
                                                  createdAt: DateTime.now(),
                                                  updatedAt: DateTime.now(),
                                                ),
                                              )
                                            : null;
                                      } else {
                                        final updatedItems = Map<String, bool>.from(_adventureData!.memberPacking!.items);
                                        updatedItems[item.id] = checked;
                                        _adventureData = AdventureData.fromTrip(
                                          _trip!,
                                          _plan!,
                                          version: _adventureData!.selectedVersion,
                                          daySelections: _adventureData!.daySelections,
                                          memberPacking: MemberPacking(
                                            id: currentUser.uid,
                                            tripId: widget.tripId!,
                                            memberId: currentUser.uid,
                                            items: updatedItems,
                                            createdAt: _adventureData!.memberPacking!.createdAt,
                                            updatedAt: DateTime.now(),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to update packing item: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTripDayTab(int dayIndex) {
    if (_adventureData == null || dayIndex >= _adventureData!.days.length) {
      return const Center(child: Text('Day not found'));
    }
    
    final day = _adventureData!.days[dayIndex];
    final dayNum = dayIndex + 1; // dayNum is 1-indexed
    final daySelection = _adventureData!.daySelections?[dayNum];
    
    // Get waypoints from route
    final waypoints = <RouteWaypoint>[];
    if (day.route != null && day.route!.poiWaypoints.isNotEmpty) {
      waypoints.addAll(
        day.route!.poiWaypoints
            .map((json) => RouteWaypoint.fromJson(json))
            .where((w) => w.type != WaypointType.routePoint)
            .toList(),
      );
      // Sort by order
      waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    }
    
    // Get selected waypoint IDs
    final selectedWaypointIds = daySelection?.selectedActivities.map((a) => a.id).toSet() ?? <String>{};
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: ResponsiveContentLayout(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WaypointSpacing.sectionGap),
              
              // Day title and description
              SectionCard(
                title: 'Day $dayNum',
                icon: Icons.calendar_today,
                children: [
                  if (day.title.isNotEmpty)
                    InlineEditableField(
                      label: 'Title',
                      displayValue: day.title,
                    ),
                  if (day.description.isNotEmpty)
                    InlineEditableField(
                      label: 'Description',
                      displayValue: day.description,
                      maxLines: 5,
                    ),
                ],
              ),
              
              const SizedBox(height: WaypointSpacing.subsectionGap),
              
              // Waypoints section
              if (waypoints.isNotEmpty)
                SectionCard(
                  title: _isTripOwner == true ? 'Select Waypoints' : 'Selected Waypoints',
                  icon: Icons.location_on,
                  children: [
                    if (_isTripOwner == true)
                      // Owner: show checkboxes for selection
                      ...waypoints.map((waypoint) {
                        final isSelected = selectedWaypointIds.contains(waypoint.id);
                        return CheckboxListTile(
                          title: Text(waypoint.name),
                          subtitle: waypoint.description != null && waypoint.description!.isNotEmpty
                              ? Text(
                                  waypoint.description!,
                                  style: WaypointTypography.bodyMedium.copyWith(
                                    color: WaypointColors.textSecondary,
                                  ),
                                )
                              : null,
                          value: isSelected,
                          onChanged: (checked) async {
                            if (checked != null && widget.tripId != null) {
                              try {
                                // Get or create day selection
                                var selection = daySelection;
                                if (selection == null) {
                                  final now = DateTime.now();
                                  selection = TripDaySelection(
                                    id: 'day_$dayNum',
                                    tripId: widget.tripId!,
                                    dayNum: dayNum,
                                    createdAt: now,
                                    updatedAt: now,
                                  );
                                }
                                
                                // Update activities list
                                final activities = List<SelectedWaypoint>.from(selection.selectedActivities);
                                if (checked) {
                                  // Add waypoint
                                  activities.add(SelectedWaypoint.fromRouteWaypoint(waypoint));
                                } else {
                                  // Remove waypoint
                                  activities.removeWhere((a) => a.id == waypoint.id);
                                }
                                
                                // Save selection
                                final updatedSelection = selection.copyWith(
                                  selectedActivities: activities,
                                  updatedAt: DateTime.now(),
                                );
                                await _tripService.updateDaySelection(updatedSelection);
                                
                                // Update local state instead of full reload
                                if (mounted) {
                                  setState(() {
                                    final updatedSelections = Map<int, TripDaySelection>.from(_adventureData?.daySelections ?? {});
                                    updatedSelections[dayNum] = updatedSelection;
                                    _adventureData = _adventureData != null
                                        ? AdventureData.fromTrip(
                                            _trip!,
                                            _plan!,
                                            version: _adventureData!.selectedVersion,
                                            daySelections: updatedSelections,
                                            memberPacking: _adventureData!.memberPacking,
                                          )
                                        : null;
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update waypoint selection: $e')),
                                  );
                                }
                              }
                            }
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: Icon(
                            getWaypointIcon(waypoint.type),
                            color: getWaypointColor(waypoint.type),
                          ),
                        );
                      }).toList()
                    else
                      // Participant: show read-only list of selected waypoints
                      daySelection?.selectedActivities.isNotEmpty == true
                          ? Column(
                              children: daySelection!.selectedActivities.map((selected) {
                                // Find matching waypoint for display
                                final waypoint = waypoints.firstWhere(
                                  (w) => w.id == selected.id,
                                  orElse: () => RouteWaypoint(
                                    id: selected.id,
                                    name: selected.name,
                                    type: WaypointType.attraction, // Default
                                    position: const ll.LatLng(0, 0),
                                    order: 0,
                                  ),
                                );
                                return ListTile(
                                  leading: Icon(
                                    getWaypointIcon(waypoint.type),
                                    color: getWaypointColor(waypoint.type),
                                  ),
                                  title: Text(selected.name),
                                  subtitle: selected.type.isNotEmpty
                                      ? Text(
                                          selected.type,
                                          style: WaypointTypography.bodyMedium.copyWith(
                                            color: WaypointColors.textSecondary,
                                          ),
                                        )
                                      : null,
                                );
                              }).toList(),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No waypoints selected for this day',
                                style: WaypointTypography.bodyMedium.copyWith(
                                  color: WaypointColors.textSecondary,
                                ),
                              ),
                            ),
                  ],
                ),
              
              // Map with selected waypoints (TODO: implement map display)
              // if (selectedWaypointIds.isNotEmpty) ...
            ],
          ),
        ),
      ),
    );
  }
  
  // ============================================================================
  // BUILDER MODE TABS
  // ============================================================================
  
  /// Helper method to build scrollable tab content with standard layout
  /// Optionally wraps content in ListenableBuilder for reactive updates
  /// Uses LayoutBuilder to handle NestedScrollView's unbounded height constraint
  Widget _buildScrollTab(List<Widget> children, {Listenable? listenable}) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        // NestedScrollView gives its body unbounded height during first layout
        // Use constraints.maxHeight when finite, fall back to MediaQuery when unbounded
        final minHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
            ),
            child: ResponsiveContentLayout(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        );
      },
    );

    if (listenable != null) {
      return ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => content,
      );
    }
    return content;
  }

  Widget _buildBuilderOverviewTab() {
    if (_formState == null) return const SizedBox.shrink();
    
    return _buildScrollTab(
      [
                // 1. Media carousel at top
                MediaCarousel(
                  mediaItems: _formState!.mediaItems,
                  isEditable: true,
                  onAddMedia: () => _pickMediaForCarousel(),
                  onRemoveMedia: (item) {
                    final index = _formState!.mediaItems.indexOf(item);
                    if (index >= 0) {
                      _formState!.removeMediaItem(index);
                    }
                  },
                ),
            const SizedBox(height: WaypointSpacing.sectionGap),
            
                // 2. Title field
            _buildInlineEditableTitle(
              label: 'Title',
                  controller: _formState!.nameCtrl,
            ),
            const SizedBox(height: WaypointSpacing.subsectionGap),
            
                // 3. Description field
            _buildInlineEditableDescription(
                  label: 'Description',
                  controller: _formState!.descriptionCtrl,
            ),
            const SizedBox(height: WaypointSpacing.subsectionGap),
            
                // 4. Activity category (required, dropdown)
                    InlineEditableDropdown<ActivityCategory>(
                  label: 'Activity Category *',
                      value: _formState!.activityCategory,
                      items: ActivityCategory.values.map((cat) => 
                        DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name),
                        )
                      ).toList(),
                      isEditable: true,
                      onChanged: (value) {
                        _formState!.activityCategory = value;
                      },
                  displayText: (cat) => cat?.name ?? 'Select activity category',
                ),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // 5. Accommodation type (required, dropdown)
                    InlineEditableDropdown<AccommodationType>(
                  label: 'Accommodation Type *',
                      value: _formState!.accommodationType,
                      items: AccommodationType.values.map((type) => 
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        )
                      ).toList(),
                      isEditable: true,
                      onChanged: (value) {
                        _formState!.accommodationType = value;
                      },
                  displayText: (type) => type?.name ?? 'Select accommodation type',
                ),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // 6. Location (read-only, from Step 1)
                InlineEditableField(
                  label: 'Location',
                  displayValue: _formState!.locations.isNotEmpty
                      ? _formState!.locations.map((l) => l.shortName).join(', ')
                      : _formState!.locationCtrl.text.isNotEmpty
                          ? _formState!.locationCtrl.text
                          : 'No location set',
                  isEditable: false,
                ),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // 7. Duration field (number of days, replaces version card)
                if (_formState!.versions.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showDurationEditDialog(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Duration (days)',
                              style: WaypointTypography.bodyMedium.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formState!.versions[_formState!.activeVersionIndex].daysCount.toString(),
                          style: WaypointTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                            color: WaypointColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_formState!.versions.isNotEmpty)
                  const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // 8. Privacy mode (new, 3 options)
                _buildPrivacyModeSelector(),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // 9. FAQ (optional, at bottom)
                if (_formState!.faqItems.isNotEmpty) ...[
                SectionCard(
                    title: "FAQ's",
                    icon: Icons.help_outline,
                  isEditable: true,
                  children: [
                      _buildFAQEditor(),
                  ],
                ),
                  const SizedBox(height: WaypointSpacing.subsectionGap),
                ],
                
                // 10. Best season (optional, moved to bottom)
                SectionCard(
                  title: 'Best Season (Optional)',
                  icon: Icons.calendar_month,
                  isEditable: true,
                  children: [
                    _buildBestSeasonsEditor(),
                  ],
                ),
      ],
      listenable: _formState!,
    );
  }
  
  Widget _buildPrivacyModeSelector() {
    // Use cached future (assigned in _loadAdventure())
    // If somehow null, create it as fallback (shouldn't happen)
    final userFuture = _currentUserFuture ?? Future<UserModel?>.value(null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
        Text(
          'Privacy Mode *',
          style: WaypointTypography.bodyMedium,
        ),
        const SizedBox(height: 8),
        FutureBuilder<UserModel?>(
          future: userFuture,
          builder: (context, snapshot) {
            final canCreatePublic = snapshot.data?.canCreatePublicPlans ?? false;
            
            return Column(
              children: [
                RadioListTile<PlanPrivacyMode>(
                  title: const Text('Invited'),
                  subtitle: const Text('Only invited people can see'),
                  value: PlanPrivacyMode.invited,
                  groupValue: _formState!.privacyMode,
                  onChanged: (value) {
                    if (value != null) {
                      _formState!.privacyMode = value;
                    }
                  },
                ),
                RadioListTile<PlanPrivacyMode>(
                  title: const Text('My Followers'),
                  subtitle: const Text('Only followers can see'),
                  value: PlanPrivacyMode.followers,
                  groupValue: _formState!.privacyMode,
                  onChanged: (value) {
                    if (value != null) {
                      _formState!.privacyMode = value;
                    }
                  },
                ),
                RadioListTile<PlanPrivacyMode>(
                  title: const Text('Everyone (Public)'),
                  subtitle: Text(canCreatePublic 
                      ? 'Everyone can see this plan'
                      : 'Only verified creators can create public plans'),
                  value: PlanPrivacyMode.public,
                  groupValue: _formState!.privacyMode,
                  onChanged: canCreatePublic ? (value) {
                    if (value != null) {
                      _formState!.privacyMode = value;
                    }
                  } : null,
                ),
                if (!canCreatePublic && _formState!.privacyMode == PlanPrivacyMode.public)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      'Only verified creators can create public plans',
                      style: WaypointTypography.bodySmall.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Future<void> _pickMediaForCarousel() async {
    if (_formState == null) return;
    
    // Show dialog to choose image or video
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Add Image'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Add Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    
    if (choice == null) return;
    
    try {
      if (choice == 'image') {
        final result = await _storageService.pickImage();
        if (result != null) {
          // Validate aspect ratio
          final aspectRatio = validateImageAspectRatioFromBytes(result.bytes);
          if (aspectRatio == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(getInvalidAspectRatioMessage())),
              );
            }
            return;
          }
          
          // Upload image
          final planId = _formState!.editingPlan?.id ?? 'draft';
          final index = _formState!.mediaItems.length;
          final path = _storageService.planMediaPath(planId, index, result.extension);
          final url = await _storageService.uploadImage(
            path: path,
            bytes: result.bytes,
            contentType: 'image/${result.extension}',
          );
          
          // Add to media items
          _formState!.addMediaItem(MediaItem(
            type: 'image',
            url: url,
            aspectRatio: aspectRatioToString(aspectRatio),
          ));
        }
      } else if (choice == 'video') {
        final result = await _storageService.pickVideo();
        if (result != null) {
          // TODO: Validate video aspect ratio using video_player
          // For now, assume valid and upload
          final planId = _formState!.editingPlan?.id ?? 'draft';
          final index = _formState!.mediaItems.length;
          final path = _storageService.planMediaPath(planId, index, result.extension);
          final url = await _storageService.uploadVideo(
            path: path,
            bytes: result.bytes,
            contentType: 'video/${result.extension}',
          );
          
          // Add to media items (default to 16:9, will be validated later)
          _formState!.addMediaItem(MediaItem(
            type: 'video',
            url: url,
            aspectRatio: '16:9', // TODO: Get actual aspect ratio from video
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
    }
  }
  
  Widget _buildHeroImage() {
    if (_formState == null) return const SizedBox.shrink();
    
    final hasImage = _formState!.coverImageBytes != null || 
                    _formState!.heroImageUrlCtrl.text.trim().isNotEmpty;
    
    if (!hasImage) {
      return GestureDetector(
        onTap: () {
          // TODO: Implement image picker
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image picker coming soon')),
          );
        },
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: WaypointColors.borderLight,
            borderRadius: BorderRadius.circular(WaypointSpacing.cardRadiusLg),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate, size: 48, color: WaypointColors.textTertiary),
                SizedBox(height: 8),
                Text('Tap to Upload Cover Image', style: TextStyle(color: WaypointColors.textTertiary)),
              ],
            ),
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WaypointSpacing.cardRadiusLg),
            image: _formState!.coverImageBytes != null
                ? DecorationImage(
                    image: MemoryImage(_formState!.coverImageBytes!),
                    fit: BoxFit.cover,
                  )
                : _formState!.heroImageUrlCtrl.text.trim().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_formState!.heroImageUrlCtrl.text.trim()),
                        fit: BoxFit.cover,
                      )
                    : null,
            color: WaypointColors.borderLight,
          ),
        ),
        // Edit button overlay - shows camera icon on hover
        Positioned.fill(
          child: _HeroImageHoverOverlay(
            onTap: () {
              // TODO: Implement image picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image picker coming soon')),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Future<UserModel?> _getCreatorUser() async {
    String? creatorId;
    
    // For builder mode, get creator ID from form state
    if (widget.mode == AdventureMode.builder) {
      if (_formState == null) return null;
      
      if (_formState!.editingPlan != null) {
        creatorId = _formState!.editingPlan!.creatorId;
      } else {
        // For new plans, use current user (if available)
        // Note: This requires auth manager - for now return null
        return null;
      }
    } else {
      // For viewer/trip mode, get creator ID from adventure data
      // Both viewer and trip modes have an associated plan, so use plan's creatorId
      if (_adventureData == null || _adventureData!.plan == null) return null;
      creatorId = _adventureData!.plan!.creatorId;
    }
    
    if (creatorId == null) return null;
    
    // Use cache to avoid duplicate calls
    if (_userFutureCache.containsKey(creatorId)) {
      return _userFutureCache[creatorId];
    }
    
    final future = _userService.getUserById(creatorId);
    _userFutureCache[creatorId] = future;
    return future;
  }
  
  Widget _buildInlineEditableTitle({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: WaypointTypography.chipLabel.copyWith(
            fontSize: 11.0,
            color: WaypointColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4.0),
        TextField(
          controller: controller,
          style: WaypointTypography.displayMedium,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: WaypointColors.primaryLight, width: 1.0),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            isDense: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInlineEditableDescription({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: WaypointTypography.chipLabel.copyWith(
            fontSize: 11.0,
            color: WaypointColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4.0),
        TextField(
          controller: controller,
          style: WaypointTypography.bodyLarge,
          maxLines: null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: WaypointColors.primaryLight, width: 1.0),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            isDense: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLocationField() {
    if (_formState == null) return const SizedBox.shrink();
    
    final locationSearch = _formState!.locationSearch;
    final locations = _formState!.locations;
    final isCityTrips = _formState!.activityCategory == ActivityCategory.cityTrips;
    final maxReached = isCityTrips && locations.length >= 1;
    
    return ListenableBuilder(
      listenable: locationSearch,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'Locations *',
            style: WaypointTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: WaypointColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Existing location chips
          if (locations.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: locations.asMap().entries.map((entry) {
                final index = entry.key;
                final location = entry.value;
                return InputChip(
                  label: Text(location.shortName),
                  onDeleted: () => _removeLocation(index),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: WaypointColors.primarySurface,
                  labelStyle: WaypointTypography.bodyMedium.copyWith(
                    color: WaypointColors.primary,
                  ),
                );
              }).toList(),
            ),
          
          // Search field (hidden for city trips when max reached)
          if (!maxReached) ...[
            if (locations.isNotEmpty) const SizedBox(height: 12),
          InlineEditableField(
              label: '',
            controller: _formState!.locationCtrl,
            isEditable: true,
              hint: 'Search a location...',
            ),
          ] else if (isCityTrips && locations.length >= 1) ...[
            const SizedBox(height: 8),
            Text(
              'City trips support one city only',
              style: WaypointTypography.chipLabel.copyWith(
                color: WaypointColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          // Loading indicator
          if (locationSearch.isSearching)
            const LinearProgressIndicator(minHeight: 2),
          
          // Suggestions dropdown
          if (locationSearch.suggestions.isNotEmpty && !maxReached)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: locationSearch.suggestions.length,
                itemBuilder: (context, index) {
                  final prediction = locationSearch.suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place),
                    title: Text(prediction.text),
                    onTap: () => _onLocationSelected(prediction),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _onLocationSelected(dynamic prediction) async {
    if (_formState == null) return;
    
    _suppressLocationListener = true; // Prevent listener from re-triggering
    _locationSearchTimer?.cancel();
    
    final locationSearch = _formState!.locationSearch;
    locationSearch.isSearching = true;
    locationSearch.suggestions = [];
    locationSearch.notifyListeners();
    
    try {
      final placesService = GooglePlacesService();
      final details = await placesService.getPlaceDetails(prediction.placeId);
      
      if (!mounted) return;
      
      if (details != null) {
        // Extract city/region name from address (first component before comma)
        final addressParts = details.address?.split(',') ?? [];
        final shortName = addressParts.isNotEmpty 
            ? addressParts.first.trim() 
            : (details.name ?? prediction.text);
        
        final locationInfo = LocationInfo(
          shortName: shortName,
          fullAddress: details.address ?? details.name ?? prediction.text,
          latitude: details.location.latitude,
          longitude: details.location.longitude,
          placeId: prediction.placeId,
          order: _formState!.locations.length,
        );
        
        _addLocation(locationInfo);
      } else {
        // Fallback: create LocationInfo from prediction text only
        final locationInfo = LocationInfo(
          shortName: prediction.text,
          fullAddress: prediction.text,
          placeId: prediction.placeId,
          order: _formState!.locations.length,
        );
        
        _addLocation(locationInfo);
      }
    } catch (e) {
      if (mounted && _formState != null) {
        // Fallback: create LocationInfo from prediction text only
        final locationInfo = LocationInfo(
          shortName: prediction.text,
          fullAddress: prediction.text,
          placeId: prediction.placeId,
          order: _formState!.locations.length,
        );
        
        _addLocation(locationInfo);
      }
    }
  }
  
  void _addLocation(LocationInfo info) {
    if (!mounted || _formState == null) return;
    
    setState(() {
      _formState!.addLocation(info);
    });
    
    _suppressLocationListener = true;
    _formState!.locationCtrl.clear();
    _formState!.locationSearch.suggestions = [];
    _formState!.locationSearch.isSearching = false;
    _formState!.locationSearch.notifyListeners();
    _suppressLocationListener = false;
    _hasUnsavedChanges = true;
  }
  
  void _removeLocation(int index) {
    if (!mounted || _formState == null) return;
    
    setState(() {
      _formState!.removeLocation(index);
    });
    
    _hasUnsavedChanges = true;
  }
  
  Widget _buildCoverImagePicker() {
    if (_formState == null) return const SizedBox.shrink();
    
    return ListenableBuilder(
      listenable: _formState!,
      builder: (context, _) {
        final hasImage = _formState!.coverImageBytes != null || 
                        _formState!.heroImageUrlCtrl.text.trim().isNotEmpty;
        
        return Column(
          children: [
            GestureDetector(
              onTap: _formState!.uploadingCoverImage ? null : () => _pickCoverImage(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: hasImage ? Colors.black : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  image: _formState!.coverImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_formState!.coverImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : _formState!.heroImageUrlCtrl.text.trim().isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_formState!.heroImageUrlCtrl.text.trim()),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child: _formState!.uploadingCoverImage
                    ? const Center(child: CircularProgressIndicator())
                    : !hasImage
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40),
                                const SizedBox(height: 8),
                                const Text('Tap to Upload Cover Image'),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      _formState!.coverImageBytes = null;
                                      _formState!.coverImageExtension = null;
                                      _formState!.heroImageUrlCtrl.clear();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 12),
            InlineEditableField(
              label: 'Or paste Image URL',
              controller: _formState!.heroImageUrlCtrl,
              isEditable: true,
              hint: 'https://...',
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildVersionCard(VersionFormState version, int index) {
    final isActive = _formState!.activeVersionIndex == index;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      color: isActive 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Version ${index + 1}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Version name
                      InlineEditableField(
                        label: 'Version Name',
                        controller: version.nameCtrl,
                        isEditable: true,
                        hint: 'e.g., Summer 2024, Winter Edition',
                      ),
                      const SizedBox(height: 12),
                      // Duration
                      Row(
                        children: [
                          Expanded(
                            child: InlineEditableField(
                              label: 'Duration (days)',
                              controller: version.durationCtrl,
                              isEditable: true,
                              hint: '1',
                              keyboardType: TextInputType.number,
                              onEditComplete: () {
                                // Trigger tab rebuild when duration changes
                                // Also setup listener for this version if it becomes active
                                if (_formState!.activeVersionIndex == index) {
                                  _setupDurationListener();
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'days',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isActive 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      onPressed: () {
                        // Reset listener flag for old version (if switching)
                        if (_formState!.activeVersionIndex != index) {
                          _formState!.versions[_formState!.activeVersionIndex].resetLocalTipsListenersAttached();
                        }
                        _formState!.activeVersionIndex = index;
                        // Clear map controllers when switching versions (old controllers from removed days linger)
                        _dayMapControllers.clear();
                        _setupDurationListener(); // Setup listener for new active version
                        _setupLocalTipsListeners(); // Setup LocalTips listeners for new active version
                        setState(() {}); // Trigger tab rebuild
                      },
                      tooltip: 'Set as active version',
                    ),
                    if (_formState!.versions.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteVersion(index),
                        tooltip: 'Delete version',
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _addNewVersion() {
    if (_formState == null || _formState!.versions.isEmpty) {
      // First version - create initial
      _formState!.versions.add(VersionFormState.initial());
      _formState!.activeVersionIndex = 0;
      _formState!.notifyListeners();
      setState(() {}); // Trigger tab rebuild
      return;
    }
    
    // Copy Prepare and LocalTips from active version
    final newVersion = VersionFormState.copyFrom(_formState!.activeVersion);
    _formState!.versions.add(newVersion);
    _formState!.activeVersionIndex = _formState!.versions.length - 1;
    _formState!.notifyListeners();
    setState(() {}); // Trigger tab rebuild
  }
  
  void _showVersionEditModal(int versionIndex) {
    if (_formState == null || versionIndex < 0 || versionIndex >= _formState!.versions.length) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Version ${versionIndex + 1}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Version card content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildVersionCard(_formState!.versions[versionIndex], versionIndex),
                ),
              ),
              // Done button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Trigger tab rebuild if duration changed
                      setState(() {});
                    },
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _deleteVersion(int index) {
    if (_formState == null) return;
    if (_formState!.versions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last version'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Version?'),
        content: Text(
          'Are you sure you want to delete Version ${index + 1}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Adjust active index if needed
              if (_formState!.activeVersionIndex >= index) {
                if (_formState!.activeVersionIndex > 0) {
                  _formState!.activeVersionIndex--;
                } else {
                  _formState!.activeVersionIndex = 0;
                }
              }
              
              // Dispose the version state
              _formState!.versions[index].dispose();
              _formState!.versions.removeAt(index);
              _formState!.notifyListeners();
              setState(() {}); // Trigger tab rebuild
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBuilderPrepareTab() {
    if (_formState == null || _formState!.versions.isEmpty) {
      return const Center(child: Text('Add at least one version first'));
    }
    
    final version = _formState!.activeVersion;
    
    return _buildScrollTab(
      [
              // Version selector
            VersionSelectorBar.fromFormStates(
              versions: _formState!.versions,
              activeIndex: _formState!.activeVersionIndex,
              onChanged: (index) {
                // Reset listener flag for old version (if switching)
                if (_formState!.activeVersionIndex != index) {
                  _formState!.versions[_formState!.activeVersionIndex].resetLocalTipsListenersAttached();
                }
                _formState!.activeVersionIndex = index;
                // Clear map controllers when switching versions
                _dayMapControllers.clear();
                _setupDurationListener();
                _setupLocalTipsListeners(); // Setup LocalTips listeners for new active version
                setState(() {});
              },
              isEditable: true,
            ),
            
            const SizedBox(height: 16),
            
            // Travel Preparation Section
            SectionCard(
              title: 'Travel Preparation',
              icon: Icons.shield_outlined,
              isEditable: true,
              children: [
                Text(
                  'Fill in travel preparation information',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPrepareSection(version),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Packing Section
            SectionCard(
              title: 'Packing List',
              icon: Icons.backpack,
              isEditable: true,
              children: [
                Text(
                  'Organize packing items by category',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ...version.packingCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  return _buildPackingCategoryCard(version, index, category);
                }),
                OutlinedButton.icon(
                  onPressed: () {
                    version.packingCategories.add(PackingCategoryFormState.initial());
                    version.notifyListeners();
                    setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Packing Category'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Transportation Section
            SectionCard(
              title: 'How to Get There',
              icon: Icons.directions_car,
              isEditable: true,
              children: [
                Text(
                  'Add different ways to reach the starting point',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ...version.transportationOptions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return _buildTransportationCard(version, index, option);
                }),
                OutlinedButton.icon(
                  onPressed: () {
                    version.transportationOptions.add(TransportationFormState.initial());
                    version.notifyListeners();
                    setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Transportation Option'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tip: Describe each route option (e.g., "Flying from Brussels") and select transport types that travelers can combine',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ],
      listenable: version,
    );
  }
  
  Widget _buildPrepareSection(VersionFormState version) {
    final prepare = version.generatedPrepare ?? Prepare();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Travel Insurance
        _buildPrepareInfoCard(
          icon: Icons.health_and_safety,
          title: 'Travel Insurance',
          children: [
            InlineEditableField(
              label: 'Recommended',
              controller: version.prepareInsuranceRecommendationCtrl,
              isEditable: true,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'URL',
              controller: version.prepareInsuranceUrlCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Why',
              controller: version.prepareInsuranceNoteCtrl,
              isEditable: true,
              maxLines: 2,
            ),
            if (version.prepareInsuranceUrlCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => launchUrl(Uri.parse(version.prepareInsuranceUrlCtrl.text)),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Visit website',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Visa
        _buildPrepareInfoCard(
          icon: Icons.airplane_ticket_outlined,
          title: 'Visa & Entry Requirements',
          children: [
            InlineEditableField(
              label: 'Visa',
              controller: version.prepareVisaRequirementCtrl,
              isEditable: true,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Medical insurance required for visa'),
              value: prepare.visa?.medicalInsuranceRequiredForVisa ?? false,
              onChanged: (value) {
                _syncPrepareFromControllers(version);
                final updated = version.generatedPrepare ?? Prepare();
                version.generatedPrepare = Prepare(
                  travelInsurance: updated.travelInsurance,
                  visa: VisaInfo(
                    requirement: updated.visa?.requirement ?? '',
                    medicalInsuranceRequiredForVisa: value ?? false,
                    note: updated.visa?.note,
                  ),
                  passport: updated.passport,
                  permits: updated.permits,
                  vaccines: updated.vaccines,
                  climate: updated.climate,
                );
                version.notifyListeners();
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Note',
              controller: version.prepareVisaNoteCtrl,
              isEditable: true,
              maxLines: 2,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Passport
        _buildPrepareInfoCard(
          icon: Icons.badge_outlined,
          title: 'Passport',
          children: [
            InlineEditableField(
              label: 'Validity',
              controller: version.preparePassportValidityCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Blank pages',
              controller: version.preparePassportNoteCtrl,
              isEditable: true,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Permits
        _buildPrepareInfoCard(
          icon: Icons.description_outlined,
          title: 'Permits',
          children: [
            ...version.permits.asMap().entries.map((entry) {
              final index = entry.key;
              final permit = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < version.permits.length - 1 ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InlineEditableField(
                      label: 'Type',
                      controller: permit.typeCtrl,
                      isEditable: true,
                    ),
                    const SizedBox(height: 8),
                    InlineEditableField(
                      label: 'Details',
                      controller: permit.detailsCtrl,
                      isEditable: true,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    InlineEditableField(
                      label: 'How to obtain',
                      controller: permit.howToObtainCtrl,
                      isEditable: true,
                      maxLines: 2,
                    ),
                    if (permit.costCtrl != null) ...[
                      const SizedBox(height: 8),
                      InlineEditableField(
                        label: 'Cost',
                        controller: permit.costCtrl!,
                        isEditable: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            version.permits.removeAt(index);
                            version.notifyListeners();
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () {
                version.permits.add(PermitFormState.initial());
                version.notifyListeners();
                setState(() {});
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Permit'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Vaccines
        _buildPrepareInfoCard(
          icon: Icons.medical_services_outlined,
          title: 'Vaccines',
          children: [
            InlineEditableField(
              label: 'Required (comma-separated)',
              controller: version.prepareVaccinesRequiredCtrl,
              isEditable: true,
              hint: 'e.g., Yellow Fever, Hepatitis A',
            ),
            const SizedBox(height: 12),
            InlineEditableField(
              label: 'Recommended (comma-separated)',
              controller: version.prepareVaccinesRecommendedCtrl,
              isEditable: true,
              hint: 'e.g., Tetanus, Typhoid',
            ),
            const SizedBox(height: 12),
            InlineEditableField(
              label: 'Note',
              controller: version.prepareVaccinesNoteCtrl,
              isEditable: true,
              maxLines: 2,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Climate
        if (prepare.climate != null && prepare.climate!.data.isNotEmpty)
          _buildPrepareInfoCard(
            icon: Icons.thermostat_outlined,
            title: 'Climate Data',
            children: [
              Text(
                prepare.climate!.location,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              ...prepare.climate!.data.map((month) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          month.month,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Temp: ${month.avgTempLowC.toStringAsFixed(0)}°C - ${month.avgTempHighC.toStringAsFixed(0)}°C'),
                            Text('Rain: ${month.avgRainMm.toStringAsFixed(0)}mm'),
                            Text('Days: ${month.avgDaylightHours.toStringAsFixed(1)}h'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
      ],
    );
  }
  
  Widget _buildPrepareInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildPackingCategoryCard(VersionFormState version, int index, PackingCategoryFormState category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: category.nameCtrl,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'Category name (e.g., Insurance)',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) {
                  category.notifyListeners();
                  version.notifyListeners();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                category.dispose();
                version.packingCategories.removeAt(index);
                version.notifyListeners();
                setState(() {});
              },
              tooltip: 'Delete category',
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          // Category description
          if (category.descriptionCtrl != null)
            InlineEditableField(
              label: 'Category Description (optional)',
              controller: category.descriptionCtrl!,
              isEditable: true,
              maxLines: 3,
              hint: 'Add helpful information with links',
            ),
          const SizedBox(height: 16),
          // Packing items
          Text(
            'Items',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...category.items.asMap().entries.map((entry) {
            final itemIndex = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: InlineEditableField(
                      label: 'Item name',
                      controller: item.nameCtrl,
                      isEditable: true,
                    ),
                  ),
                  Checkbox(
                    value: item.isEssential,
                    onChanged: (value) {
                      item.isEssential = value ?? false;
                      setState(() {});
                    },
                  ),
                  const Text('Essential'),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      item.dispose();
                      category.items.removeAt(itemIndex);
                      category.notifyListeners();
                      version.notifyListeners();
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              category.items.add(PackingItemFormState(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                nameCtrl: TextEditingController(),
                descriptionCtrl: null,
                isEssential: false,
              ));
              category.notifyListeners();
              version.notifyListeners();
              setState(() {});
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransportationCard(VersionFormState version, int index, TransportationFormState option) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            if (option.types.isNotEmpty)
              ...option.types.map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(_kTransportIcons[type] ?? Icons.directions, size: 20, color: Theme.of(context).colorScheme.primary),
              ))
            else
              Icon(Icons.directions, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.titleCtrl.text.isEmpty ? 'Transportation Option ${index + 1}' : option.titleCtrl.text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                option.dispose();
                version.transportationOptions.removeAt(index);
                version.notifyListeners();
                setState(() {});
              },
              tooltip: 'Delete option',
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          InlineEditableField(
            label: 'Title',
            controller: option.titleCtrl,
            isEditable: true,
            hint: 'e.g., Flying from Brussels',
          ),
          const SizedBox(height: 16),
          InlineEditableField(
            label: 'Description',
            controller: option.descCtrl,
            isEditable: true,
            maxLines: 5,
            hint: 'Describe this route option...',
          ),
          const SizedBox(height: 16),
          Text(
            'Transportation Types',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select one or more types that can be combined',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: TransportationType.values.map((type) {
              final isSelected = option.types.contains(type);
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _kTransportIcons[type] ?? Icons.directions,
                      size: 18,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimary 
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(_kTransportNames[type] ?? type.name),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      option.types.add(type);
                    } else {
                      option.types.remove(type);
                    }
                    option.notifyListeners();
                    version.notifyListeners();
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  
  void _syncPrepareFromControllers(VersionFormState version) {
    final existing = version.generatedPrepare;
    final prepare = Prepare(
      travelInsurance: TravelInsurance(
        recommendation: version.prepareInsuranceRecommendationCtrl.text,
        url: version.prepareInsuranceUrlCtrl.text,
        note: version.prepareInsuranceNoteCtrl.text,
      ),
      visa: VisaInfo(
        requirement: version.prepareVisaRequirementCtrl.text,
        note: version.prepareVisaNoteCtrl.text.isEmpty ? null : version.prepareVisaNoteCtrl.text,
        medicalInsuranceRequiredForVisa: existing?.visa?.medicalInsuranceRequiredForVisa ?? false,
      ),
      passport: PassportInfo(
        validityRequirement: version.preparePassportValidityCtrl.text,
        blankPagesRequired: existing?.passport?.blankPagesRequired ?? version.preparePassportNoteCtrl.text,
      ),
      permits: version.permits.map((p) => Permit(
        type: p.typeCtrl.text,
        details: p.detailsCtrl.text,
        howToObtain: p.howToObtainCtrl.text,
        cost: p.costCtrl?.text.isNotEmpty == true ? p.costCtrl!.text : null,
      )).toList(),
      vaccines: VaccineInfo(
        required: version.prepareVaccinesRequiredCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        recommended: version.prepareVaccinesRecommendedCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        note: version.prepareVaccinesNoteCtrl.text.isEmpty ? null : version.prepareVaccinesNoteCtrl.text,
      ),
      climate: version.prepareClimateDescriptionCtrl.text.isNotEmpty || version.prepareClimateBestTimeCtrl.text.isNotEmpty
          ? ClimateData(
              location: _formState?.locationCtrl.text.trim() ?? '',
              data: existing?.climate?.data ?? [],
            )
          : existing?.climate,
    );
    version.generatedPrepare = prepare;
  }
  
  Widget _buildBuilderLocalTipsTab() {
    if (_formState == null || _formState!.versions.isEmpty) {
      return const Center(child: Text('Add at least one version first'));
    }
    
    final version = _formState!.activeVersion;
    
    return _buildScrollTab(
      [
              // Version selector
            VersionSelectorBar.fromFormStates(
              versions: _formState!.versions,
              activeIndex: _formState!.activeVersionIndex,
              onChanged: (index) {
                if (_formState!.activeVersionIndex != index) {
                  _formState!.versions[_formState!.activeVersionIndex].resetLocalTipsListenersAttached();
                }
                _formState!.activeVersionIndex = index;
                // Clear map controllers when switching versions
                _dayMapControllers.clear();
                _setupDurationListener();
                _setupLocalTipsListeners(); // Setup LocalTips listeners for new active version
                setState(() {});
              },
              isEditable: true,
            ),
            
            const SizedBox(height: 16),
            
            // Local Tips Content
            ListenableBuilder(
              listenable: version,
              builder: (context, _) {
                // Sync controllers to LocalTips model when they change
                // This is done via listeners attached once in initState, not on every build
                return _buildLocalTipsContent(version);
              },
            ),
      ],
      listenable: version,
    );
  }
  
  Widget _buildLocalTipsContent(VersionFormState version) {
    final localTips = version.generatedLocalTips ?? LocalTips();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fill in local tips information',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Emergency Numbers
        SectionCard(
          title: 'Emergency Numbers',
          icon: Icons.emergency_outlined,
          isEditable: true,
          children: [
            InlineEditableField(
              label: 'General Emergency',
              controller: version.localTipsGeneralEmergencyCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Police',
              controller: version.localTipsEmergencyPoliceCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Ambulance',
              controller: version.localTipsEmergencyAmbulanceCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Fire',
              controller: version.localTipsEmergencyFireCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Mountain Rescue (optional)',
              controller: version.localTipsEmergencyTouristCtrl,
              isEditable: true,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Communication
        SectionCard(
          title: 'Communication',
          icon: Icons.chat_bubble_outline,
          isEditable: true,
          children: [
            InlineEditableField(
              label: 'Most used app',
              controller: version.localTipsMessagingAppNameCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Note',
              controller: version.localTipsMessagingAppNoteCtrl,
              isEditable: true,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Etiquette
        SectionCard(
          title: 'Etiquette',
          icon: Icons.handshake_outlined,
          isEditable: true,
          children: [
            if (version.etiquetteItems.isEmpty)
              Text(
                'No etiquette tips added yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              )
            else
              ...version.etiquetteItems.asMap().entries.map((entry) {
                final index = entry.key;
                final etiquette = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < version.etiquetteItems.length - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InlineEditableField(
                          label: 'Tip ${index + 1}',
                          controller: etiquette.tipCtrl,
                          isEditable: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () {
                          etiquette.dispose();
                          version.etiquetteItems.removeAt(index);
                          _syncLocalTipsFromControllers(version);
                          version.notifyListeners();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                version.etiquetteItems.add(EtiquetteFormState.fromString(''));
                version.notifyListeners();
                setState(() {});
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Etiquette Tip'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Tipping
        SectionCard(
          title: 'Tipping',
          icon: Icons.attach_money_outlined,
          isEditable: true,
          children: [
            InlineEditableField(
              label: 'General',
              controller: version.localTipsTippingPracticeCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Restaurant',
              controller: version.localTipsTippingRestaurantCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Taxi',
              controller: version.localTipsTippingTaxiCtrl,
              isEditable: true,
            ),
            const SizedBox(height: 8),
            InlineEditableField(
              label: 'Hotel',
              controller: version.localTipsTippingHotelCtrl,
              isEditable: true,
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Basic Phrases (read-only display)
        if (localTips.basicPhrases.isNotEmpty)
          SectionCard(
            title: 'Basic Phrases',
            icon: Icons.translate_outlined,
            isEditable: false,
            children: [
              ...localTips.basicPhrases.map((phrase) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phrase.english,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${phrase.local} (${phrase.pronunciation})',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Food Specialties (index-based updates)
        SectionCard(
          title: 'Food Specialties',
          icon: Icons.restaurant_outlined,
          isEditable: true,
          children: [
            if (version.foodSpecialties.isEmpty)
              Text(
                'No food specialties added yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              )
            else
              ...version.foodSpecialties.asMap().entries.map((entry) {
                final index = entry.key;
                final food = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InlineEditableField(
                              label: 'Name',
                              controller: food.nameCtrl,
                              isEditable: true,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
                              food.dispose();
                              version.foodSpecialties.removeAt(index);
                              _syncLocalTipsFromControllers(version);
                              version.notifyListeners();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InlineEditableField(
                        label: 'Description',
                        controller: food.descriptionCtrl,
                        isEditable: true,
                        maxLines: 2,
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                version.foodSpecialties.add(FoodSpecialtyFormState.initial());
                version.notifyListeners();
                setState(() {});
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Food Specialty'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Food Warnings
        SectionCard(
          title: 'Food Warnings',
          icon: Icons.warning_amber_outlined,
          isEditable: true,
          children: [
            if (version.foodWarnings.isEmpty)
              Text(
                'No warnings added yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              )
            else
              ...version.foodWarnings.asMap().entries.map((entry) {
                final index = entry.key;
                final warning = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < version.foodWarnings.length - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InlineEditableField(
                          label: 'Warning ${index + 1}',
                          controller: warning.warningCtrl,
                          isEditable: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () {
                          warning.dispose();
                          version.foodWarnings.removeAt(index);
                          _syncLocalTipsFromControllers(version);
                          version.notifyListeners();
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                version.foodWarnings.add(FoodWarningFormState.initial());
                _syncLocalTipsFromControllers(version);
                version.notifyListeners();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Food Warning'),
            ),
          ],
        ),
      ],
    );
  }
  
  void _syncLocalTipsFromControllers(VersionFormState version) {
    final existing = version.generatedLocalTips;
    final localTips = LocalTips(
      emergency: EmergencyInfo(
        generalEmergency: version.localTipsGeneralEmergencyCtrl.text,
        police: version.localTipsEmergencyPoliceCtrl.text,
        ambulance: version.localTipsEmergencyAmbulanceCtrl.text,
        fire: version.localTipsEmergencyFireCtrl.text,
        mountainRescue: version.localTipsEmergencyTouristCtrl.text.isNotEmpty 
            ? version.localTipsEmergencyTouristCtrl.text 
            : existing?.emergency?.mountainRescue,
      ),
      messagingApp: MessagingApp(
        name: version.localTipsMessagingAppNameCtrl.text,
        note: version.localTipsMessagingAppNoteCtrl.text,
      ),
      etiquette: version.etiquetteItems.map((e) => e.tipCtrl.text).where((s) => s.isNotEmpty).toList(),
      tipping: TippingInfo(
        practice: version.localTipsTippingPracticeCtrl.text,
        restaurant: version.localTipsTippingRestaurantCtrl.text,
        taxi: version.localTipsTippingTaxiCtrl.text,
        hotel: version.localTipsTippingHotelCtrl.text,
      ),
      basicPhrases: existing?.basicPhrases ?? [],
      foodSpecialties: version.foodSpecialties.map((f) => FoodSpecialty(
        name: f.nameCtrl.text,
        description: f.descriptionCtrl.text,
      )).toList(),
      foodWarnings: version.foodWarnings.map((w) => w.warningCtrl.text).where((s) => s.isNotEmpty).toList(),
    );
    version.generatedLocalTips = localTips;
  }
  
  void _setupLocalTipsListeners() {
    if (_formState == null || _formState!.versions.isEmpty) return;
    
    final version = _formState!.activeVersion;
    
    // Guard: Skip if listeners already attached to this version
    if (version.localTipsListenersAttached) return;
    
    // Remove any existing listeners first to prevent duplicates
    for (final listener in _localTipsListeners) {
      try {
        version.localTipsGeneralEmergencyCtrl.removeListener(listener);
        version.localTipsEmergencyPoliceCtrl.removeListener(listener);
        version.localTipsEmergencyAmbulanceCtrl.removeListener(listener);
        version.localTipsEmergencyFireCtrl.removeListener(listener);
        version.localTipsEmergencyTouristCtrl.removeListener(listener);
        version.localTipsMessagingAppNameCtrl.removeListener(listener);
        version.localTipsMessagingAppNoteCtrl.removeListener(listener);
        version.localTipsTippingPracticeCtrl.removeListener(listener);
        version.localTipsTippingRestaurantCtrl.removeListener(listener);
        version.localTipsTippingTaxiCtrl.removeListener(listener);
        version.localTipsTippingHotelCtrl.removeListener(listener);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    _localTipsListeners.clear();
    
    // Mark as attached before adding listeners to prevent race conditions
    version.markLocalTipsListenersAttached();
    
    // Add listeners once to sync LocalTips model when controllers change
    // These listeners are added once when form state is loaded, not on every build
    // Use a closure that always references the current version from _formState
    void addSyncListener(TextEditingController ctrl) {
      final listener = () {
        // Always use current active version to avoid stale closure capture
        if (_formState != null) {
          _syncLocalTipsFromControllers(_formState!.activeVersion);
        }
      };
      ctrl.addListener(listener);
      _localTipsListeners.add(listener);
    }
    
    addSyncListener(version.localTipsGeneralEmergencyCtrl);
    addSyncListener(version.localTipsEmergencyPoliceCtrl);
    addSyncListener(version.localTipsEmergencyAmbulanceCtrl);
    addSyncListener(version.localTipsEmergencyFireCtrl);
    addSyncListener(version.localTipsEmergencyTouristCtrl);
    addSyncListener(version.localTipsMessagingAppNameCtrl);
    addSyncListener(version.localTipsMessagingAppNoteCtrl);
    addSyncListener(version.localTipsTippingPracticeCtrl);
    addSyncListener(version.localTipsTippingRestaurantCtrl);
    addSyncListener(version.localTipsTippingTaxiCtrl);
    addSyncListener(version.localTipsTippingHotelCtrl);
  }
  
  String? _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return null;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    }
    return null;
  }
  
  double? _getDistanceKm(DayRoute? existingRoute, DayFormState dayState) {
    if (existingRoute != null && existingRoute.distance > 0) {
      return existingRoute.distance / 1000.0;
    }
    final distanceText = dayState.distanceCtrl.text;
    if (distanceText.isNotEmpty) {
      return double.tryParse(distanceText);
    }
    return null;
  }
  
  String? _getDuration(DayRoute? existingRoute, DayFormState dayState) {
    if (existingRoute != null && existingRoute.duration > 0) {
      return _formatDuration(existingRoute.duration);
    }
    final timeText = dayState.timeCtrl.text;
    if (timeText.isNotEmpty) {
      final hours = double.tryParse(timeText);
      if (hours != null) {
        return _formatDuration((hours * 3600).round());
      }
    }
    return null;
  }
  
  String? _getDifficulty(DayFormState dayState) {
    if (dayState.routeInfo != null && dayState.routeInfo!.difficulty != null && dayState.routeInfo!.difficulty!.isNotEmpty) {
      return dayState.routeInfo!.difficulty;
    }
    return null;
  }
  
  Widget _buildBuilderDayTab(int dayNum) {
    if (_formState == null || _formState!.versions.isEmpty) {
      return const Center(child: Text('Add at least one version first'));
    }
    
    final version = _formState!.activeVersion;
    final dayState = version.getDayState(dayNum);
    final existingRoute = dayState.route;
    final dayImageBytes = dayState.newImageBytes.isNotEmpty ? dayState.newImageBytes.first : null;
    final existingImageUrl = dayState.existingImageUrls.isNotEmpty ? dayState.existingImageUrls.first : null;
    
    return ListenableBuilder(
      listenable: dayState,
      builder: (context, _) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: ResponsiveContentLayout(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Hero Image
            DayHeroImage(
              imageUrl: existingImageUrl,
              imageBytes: dayImageBytes,
              dayTitle: dayState.titleCtrl.text.isEmpty ? 'Day $dayNum' : dayState.titleCtrl.text,
              dayNumber: dayNum,
              totalDays: version.daysCount,
              location: _formState!.locationCtrl.text.isNotEmpty ? _formState!.locationCtrl.text : null,
              statusBadge: !_formState!.isPublished ? 'Draft' : null,
              isBuilder: true,
              onImageTap: () => _pickDayImage(dayNum),
            ),
            const SizedBox(height: WaypointSpacing.sectionGap),
            
            // Title (inline editable)
            _buildInlineEditableTitle(
              label: 'Title',
              controller: dayState.titleCtrl,
            ),
            const SizedBox(height: WaypointSpacing.subsectionGap),
            
            // Description (inline editable)
            _buildInlineEditableDescription(
              label: 'Description',
              controller: dayState.descCtrl,
            ),
            const SizedBox(height: WaypointSpacing.sectionGap),
            
            // Stat Bar (activity-aware)
            ActivityAwareBuilder(
              activityCategory: _formState!.activityCategory,
              showFor: {
                ActivityCategory.hiking,
                ActivityCategory.cycling,
                ActivityCategory.skis,
                ActivityCategory.climbing,
              },
              child: StatBar(
                distance: _getDistanceKm(existingRoute, dayState),
                elevation: existingRoute?.ascent?.round(),
                duration: _getDuration(existingRoute, dayState),
                difficulty: _getDifficulty(dayState),
                isEditable: true,
                onDistanceTap: () {
                  // TODO: Open edit dialog for distance
                },
                onElevationTap: () {
                  // TODO: Open edit dialog for elevation
                },
                onDurationTap: () {
                  // TODO: Open edit dialog for duration
                },
                onDifficultyTap: () {
                  // TODO: Open edit dialog for difficulty
                },
              ),
            ),
            
            // External Links Row
            ActivityAwareBuilder(
              activityCategory: _formState!.activityCategory,
              showFor: {
                ActivityCategory.hiking,
                ActivityCategory.cycling,
                ActivityCategory.skis,
                ActivityCategory.climbing,
              },
              child: ExternalLinksRow(
                komootLink: dayState.komootLinkCtrl.text.isNotEmpty ? dayState.komootLinkCtrl.text : null,
                allTrailsLink: dayState.allTrailsLinkCtrl.text.isNotEmpty ? dayState.allTrailsLinkCtrl.text : null,
                hasGpx: existingRoute != null && existingRoute.routeType == RouteType.gpx,
                onDownloadGpx: existingRoute != null && existingRoute.routeType == RouteType.gpx
                    ? () {
                        // TODO: Implement GPX download
                      }
                    : null,
              ),
            ),
            
            // GPX Import is handled by RouteInfoSection (activity-aware, shown below)
            // For now, we show it inline here if no route exists
            ActivityAwareBuilder(
              activityCategory: _formState!.activityCategory,
              showFor: {
                ActivityCategory.hiking,
                ActivityCategory.cycling,
                ActivityCategory.skis,
                ActivityCategory.climbing,
              },
              child: existingRoute == null
                  ? RouteInfoSection(
                activityCategory: _formState!.activityCategory,
                route: existingRoute,
                routeInfo: dayState.routeInfo,
                komootLinkController: dayState.komootLinkCtrl,
                allTrailsLinkController: dayState.allTrailsLinkCtrl,
                gpxRoute: dayState.gpxRoute,
                onRouteInfoChanged: (routeInfo) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      dayState.routeInfo = routeInfo;
                    });
                  });
                },
                onGpxRouteChanged: (gpxRoute) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      dayState.gpxRoute = gpxRoute;
                      
                      // Create DayRoute from GPX data if GPX route exists
                      if (gpxRoute != null) {
                        final gpxPoints = gpxRoute.simplifiedPoints;
                        final geometry = {
                          'type': 'LineString',
                          'coordinates': gpxPoints
                              .map((p) => [p.longitude, p.latitude])
                              .toList(),
                        };
                        
                        int durationSeconds = gpxRoute.estimatedDuration?.inSeconds ?? 0;
                        if (durationSeconds == 0 && _formState!.activityCategory != null) {
                                durationSeconds = (gpxRoute.totalDistanceKm * 3600 / 5).round();
                        }
                        
                        final existingWaypoints = existingRoute?.poiWaypoints
                            .map((json) => RouteWaypoint.fromJson(json))
                            .where((w) => w.type != WaypointType.routePoint)
                            .map((w) => w.toJson())
                            .toList() ?? [];
                        
                        final dayRoute = DayRoute(
                          geometry: geometry,
                          distance: (gpxRoute.totalDistanceKm * 1000).roundToDouble(),
                          duration: durationSeconds,
                          routePoints: const [],
                          ascent: gpxRoute.totalElevationGainM,
                          descent: null,
                          routeType: RouteType.gpx,
                          poiWaypoints: existingWaypoints,
                        );
                        
                        dayState.route = dayRoute;
                        dayState.distanceCtrl.text = gpxRoute.totalDistanceKm.toStringAsFixed(2);
                        final hours = durationSeconds / 3600.0;
                        dayState.timeCtrl.text = hours.toStringAsFixed(1);
                      } else {
                        if (existingRoute?.routeType == RouteType.gpx) {
                          dayState.route = null;
                        }
                        dayState.routeInfo = null;
                        dayState.distanceCtrl.clear();
                        dayState.timeCtrl.clear();
                      }
                    });
                  });
                },
                    )
                  : const SizedBox.shrink(),
            ),
            
            const SizedBox(height: WaypointSpacing.sectionGap),
            
            // Map Section
            ActivityAwareBuilder(
              activityCategory: _formState!.activityCategory,
              showFor: {
                ActivityCategory.hiking,
                ActivityCategory.cycling,
                ActivityCategory.skis,
                ActivityCategory.climbing,
                ActivityCategory.cityTrips,
                ActivityCategory.tours,
                ActivityCategory.roadTripping,
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDayRouteMap(existingRoute, dayNum, version),
                  // Edit Route + Import GPX buttons under map (builder mode only)
                  if (widget.mode == AdventureMode.builder) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
            FilledButton.icon(
              onPressed: () async {
                try {
                  final planId = _formState!.editingPlan?.id ?? 'new';
                  final route = await context.push<DayRoute>(
                    '/builder/route-builder/$planId/${_formState!.activeVersionIndex}/$dayNum',
                    extra: {
                      'start': dayState.start,
                      'end': dayState.end,
                      'initial': dayState.route,
                      'activityCategory': _formState!.activityCategory,
                      'location': _formState!.locationSearch.selectedLocation != null
                          ? ll.LatLng(
                              _formState!.locationSearch.selectedLocation!.latitude,
                              _formState!.locationSearch.selectedLocation!.longitude,
                            )
                          : null,
                    },
                  );
                  if (route != null && mounted) {
                    setState(() {
                      dayState.route = route;
                    });
                    final km = (route.distance / 1000.0);
                    dayState.distanceCtrl.text = km.toStringAsFixed(2);
                    final hours = route.duration / 3600.0;
                    dayState.timeCtrl.text = hours.toStringAsFixed(1);
                    dayState.notifyListeners();
                  }
                } catch (e) {
                  Log.e('adventure_detail', 'RouteBuilderScreen failed: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open route builder: $e')),
                    );
                  }
                }
              },
                          icon: const Icon(Icons.alt_route, size: 16),
              label: Text(existingRoute == null ? 'Create Route' : 'Edit Route'),
                          style: FilledButton.styleFrom(
                            backgroundColor: WaypointColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showGpxImportDialog(context, dayState, existingRoute);
                          },
                          icon: const Icon(Icons.file_upload, size: 16),
                          label: const Text('Import GPX'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: WaypointColors.primary,
                            side: const BorderSide(color: WaypointColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                ),
              ],
            ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: WaypointSpacing.sectionGap),
            
            // Waypoints Section (Route) - Timeline view
            // NOTE: POI sections (Stay/Eat/Do/Move) removed per redesign.
            // Waypoints are now managed in the Itinerary tab with chronological timeline.
            SectionHeader(
              title: 'Route',
              emoji: '🗺️',
              tintColor: WaypointColors.textPrimary,
              onAdd: () => _onAddWaypointTapped(context),
            ),
            const SizedBox(height: WaypointSpacing.subsectionGap),
            _buildWaypointTimeline(dayNum, version),
            
            // POI sections removed - waypoints are now managed in the Itinerary tab
            // which shows them chronologically without category separation
          ],
        ),
        ),
        ),
        // Sidebar is handled at Scaffold level for desktop, not here
      ),
    );
  }
  
  Widget _buildBuyPlanSidebar() {
    // Hide if purchase status is not yet checked (loading) or trip mode
    if (_hasPurchased == null && widget.mode != AdventureMode.builder) {
      return const SizedBox.shrink();
    }
    
    if (widget.mode == AdventureMode.trip) {
      return const SizedBox.shrink();
    }
    
    if (widget.mode == AdventureMode.builder) {
      if (_formState == null) return const SizedBox.shrink();
      
      final price = double.tryParse(_formState!.priceCtrl.text) ?? 0.0;
      
      return BuyPlanCard(
        price: price,
        isBuilder: true,
        adventureTitle: _formState!.nameCtrl.text.isEmpty ? 'Adventure' : _formState!.nameCtrl.text,
        priceController: _formState!.priceCtrl,
        onBuyTap: null,
        activityCategory: _formState!.activityCategory,
        accommodationType: _formState!.accommodationType,
        durationDays: _formState!.versions.isNotEmpty
            ? _formState!.versions[_formState!.activeVersionIndex].daysCount
            : null,
      );
    }
    
    // Viewer mode
    final price = _getPrice();
    if (price == null || price == 0.0) {
      return const SizedBox.shrink();
    }
    
    final displayName = _adventureData?.displayName ?? _plan?.name ?? 'Adventure';
    
    if (_hasPurchased == true) {
      // Show "Start Trip" button
      return BuyPlanCard(
        price: price,
        isBuilder: false,
        adventureTitle: displayName,
        priceController: null,
        onBuyTap: () {
          if (widget.planId != null) {
            context.push('/mytrips/onboarding/${widget.planId}/name');
          }
        },
        activityCategory: _plan?.activityCategory,
        accommodationType: _plan?.accommodationType,
        durationDays: _adventureData?.selectedVersion?.durationDays,
      );
    } else {
      // Show "Buy Plan" button
      return BuyPlanCard(
        price: price,
        isBuilder: false,
        adventureTitle: displayName,
        priceController: null,
        onBuyTap: () {
          // TODO: Implement buy plan functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buy plan functionality coming soon')),
          );
        },
        activityCategory: _plan?.activityCategory,
        accommodationType: _plan?.accommodationType,
        durationDays: _adventureData?.selectedVersion?.durationDays,
      );
    }
  }
  
  void _showGpxImportDialog(BuildContext context, DayFormState dayState, DayRoute? existingRoute) {
    // GPX import is handled inline via RouteInfoSection
    // This button should navigate to route builder with GPX mode, not pop
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Use the route builder to import GPX files')),
    );
  }
  
  Widget _buildPOISection(
    DayFormState dayState,
    int dayNum,
    VersionFormState version, {
    required String title,
    required String emoji,
    required Color tintColor,
    required WaypointType waypointType,
    required VoidCallback onAdd,
  }) {
    final waypoints = _getOrderedWaypoints(dayState)
        .where((w) => w.type == waypointType)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          emoji: emoji,
          tintColor: tintColor,
          onAdd: onAdd,
        ),
        if (waypoints.isEmpty)
          Padding(
            padding: const EdgeInsets.all(WaypointSpacing.cardPadding),
            child: Text(
              'No ${title.toLowerCase()} added yet',
              style: WaypointTypography.bodyMedium.copyWith(color: WaypointColors.textTertiary),
            ),
          )
        else
          _buildPoiGrid(
            context: context,
            waypoints: waypoints,
            waypointType: waypointType,
            onAdd: onAdd,
            addLabel: 'Add $title',
            onEdit: (waypoint) => _editWaypoint(dayNum, waypoint, version),
            onDelete: (waypoint) => _deleteWaypoint(dayNum, waypoint, version),
          ),
        const SizedBox(height: WaypointSpacing.sectionGap),
      ],
    );
  }

  // POI grid helper — responsive grid with new PoiCard design
  Widget _buildPoiGrid({
    required BuildContext context,
    required List<RouteWaypoint> waypoints,
    required WaypointType waypointType,
    required VoidCallback? onAdd,
    required String addLabel,
    required Function(RouteWaypoint) onEdit,
    required Function(RouteWaypoint) onDelete,
  }) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = WaypointBreakpoints.isDesktop(width)
        ? 3
        : WaypointBreakpoints.isTablet(width)
            ? 2
            : 1; // mobile: 1 column

    final allItems = [
      ...waypoints.map((waypoint) => PoiCard(
                name: waypoint.name,
            type: _waypointTypeToString(waypointType),
            imageUrl: waypoint.photoUrl ?? waypoint.linkImageUrl,
            address: waypoint.address,
            url: waypoint.linkUrl ?? waypoint.website,
            cost: waypoint.estimatedPriceRange != null
                ? '€${waypoint.estimatedPriceRange!.min}-€${waypoint.estimatedPriceRange!.max}'
                : null,
            rating: waypoint.rating,
            mealType: waypoint.mealTime?.name,
            duration: waypoint.travelTime != null
                ? '${(waypoint.travelTime! / 60).round()} min'
                : null,
                isEditable: true,
            onEdit: () => onEdit(waypoint),
            onDelete: () => onDelete(waypoint),
          )),
      if (onAdd != null)
        _buildAddPoiCard(label: addLabel, onTap: onAdd),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 280, // Fixed height for consistent cards
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) => allItems[index],
    );
  }

  String _waypointTypeToString(WaypointType type) {
    switch (type) {
      case WaypointType.accommodation:
        return 'accommodation';
      case WaypointType.restaurant:
        return 'restaurant';
      case WaypointType.attraction:
      case WaypointType.activity:
        return 'activity';
      case WaypointType.service:
      case WaypointType.servicePoint:
        return 'logistics';
      default:
        return 'activity';
    }
  }

  Widget _buildAddPoiCard({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(
            color: const Color(0xFFE9ECEF),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              size: 24.0,
              color: Color(0xFF6C757D),
            ),
            const SizedBox(height: 6.0),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6C757D),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _refitDayMap(int dayNum) {
    final controller = _dayMapControllers[dayNum];
    if (controller == null || _formState == null || _formState!.versions.isEmpty) return;
    
    final version = _formState!.activeVersion;
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    
    // Parse route coordinates
    List<ll.LatLng> routeCoordinates = [];
    if (route?.geometry != null) {
      try {
        final coords = route!.geometry['coordinates'];
        if (coords is List && coords.isNotEmpty) {
          if (coords.first is List) {
            routeCoordinates = coords
                .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          }
        }
      } catch (e) {
        Log.e('adventure_detail', 'Failed to parse route coordinates: $e');
      }
    }
    
    // Extract waypoints
    final waypointMaps = route?.poiWaypoints ?? [];
    final waypoints = waypointMaps
        .map((w) {
          try {
            return RouteWaypoint.fromJson(w);
          } catch (e) {
            return null;
          }
        })
        .whereType<RouteWaypoint>()
        .toList();
    
    // Collect all points to fit
    final allPoints = <ll.LatLng>[];
    allPoints.addAll(waypoints.map((w) => w.position));
    allPoints.addAll(routeCoordinates);
    
    // Add GPX route points if available
    if (route?.routeType == RouteType.gpx) {
      final gpxRoute = dayState.gpxRoute;
      if (gpxRoute != null && gpxRoute.simplifiedPoints.isNotEmpty) {
        allPoints.addAll(gpxRoute.simplifiedPoints
            .map((p) => ll.LatLng(p.latitude, p.longitude))
            .toList());
      }
    }
    
    if (allPoints.isEmpty) {
      final selectedLocation = _formState!.locationSearch.selectedLocation;
      if (selectedLocation != null) {
        allPoints.add(ll.LatLng(selectedLocation.latitude, selectedLocation.longitude));
      }
    }
    
    if (allPoints.isNotEmpty) {
      _animateCameraToPoints(allPoints, controller);
    }
  }
  
  void _animateCameraToPoints(List<ll.LatLng> allPoints, WaypointMapController controller) {
    final lats = allPoints.map((p) => p.latitude).toList();
    final lngs = allPoints.map((p) => p.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    
    // Calculate center
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    
    // Calculate zoom level based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 10.0;
    if (maxDiff > 0) {
      if (maxDiff > 10) zoom = 4.0;
      else if (maxDiff > 5) zoom = 5.0;
      else if (maxDiff > 2) zoom = 6.0;
      else if (maxDiff > 1) zoom = 7.0;
      else if (maxDiff > 0.5) zoom = 8.0;
      else if (maxDiff > 0.2) zoom = 9.0;
      else if (maxDiff > 0.1) zoom = 10.0;
      else zoom = 12.0;
    }
    
    try {
      controller.animateCamera(
        ll.LatLng(centerLat, centerLng),
        zoom,
      );
    } catch (e) {
      // Controller was disposed before the deferred callback fired
      // (e.g. user switched tabs while the map was initialising).
      // This is safe to ignore — the map widget is already gone.
      Log.w('adventure_detail', 'Map camera animate skipped (controller disposed): $e');
    }
  }
  
  Widget _buildDayRouteMap(DayRoute? route, int dayNum, VersionFormState version) {
    if (_formState == null) {
      return const SizedBox.shrink();
    }
    
    // Parse route coordinates
    List<ll.LatLng> routeCoordinates = [];
    if (route?.geometry != null) {
      try {
        final coords = route!.geometry['coordinates'];
        if (coords is List && coords.isNotEmpty) {
          if (coords.first is List) {
            routeCoordinates = coords
                .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          }
        }
      } catch (e) {
        Log.e('adventure_detail', 'Failed to parse route coordinates: $e');
      }
    }
    
    // Extract waypoints
    final waypointMaps = route?.poiWaypoints ?? [];
    final waypoints = waypointMaps
        .map((w) {
          try {
            return RouteWaypoint.fromJson(w);
          } catch (e) {
            return null;
          }
        })
        .whereType<RouteWaypoint>()
        .toList();
    
    // Calculate center
    ll.LatLng center;
    if (waypoints.isNotEmpty) {
      final avgLat = waypoints.map((w) => w.position.latitude).reduce((a, b) => a + b) / waypoints.length;
      final avgLng = waypoints.map((w) => w.position.longitude).reduce((a, b) => a + b) / waypoints.length;
      center = ll.LatLng(avgLat, avgLng);
    } else if (routeCoordinates.isNotEmpty) {
      final avgLat = routeCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / routeCoordinates.length;
      final avgLng = routeCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / routeCoordinates.length;
      center = ll.LatLng(avgLat, avgLng);
    } else {
      final selectedLocation = _formState!.locationSearch.selectedLocation;
      if (selectedLocation != null) {
        center = ll.LatLng(selectedLocation.latitude, selectedLocation.longitude);
      } else {
        center = _kDefaultCenter;
      }
    }
    
    // Create annotations
    final isGpxRoute = route?.routeType == RouteType.gpx;
    final filteredWaypoints = isGpxRoute
        ? waypoints.where((wp) => wp.type != WaypointType.routePoint).toList()
        : waypoints;
    final annotations = filteredWaypoints
        .map((wp) => MapAnnotation.fromWaypoint(wp, onTap: () {}))
        .toList();
    
    // Create polylines
    final polylines = <MapPolyline>[];
    if (isGpxRoute) {
      final dayState = version.getDayState(dayNum);
      final gpxRoute = dayState.gpxRoute;
      if (gpxRoute != null && gpxRoute.simplifiedPoints.isNotEmpty) {
        final gpxTrailPoints = gpxRoute.simplifiedPoints
            .map((p) => ll.LatLng(p.latitude, p.longitude))
            .toList();
        polylines.add(MapPolyline(
          id: 'route_$dayNum',
          points: gpxTrailPoints,
          color: const Color(0xFF4CAF50),
          width: 4.0,
        ));
      }
    } else if (routeCoordinates.isNotEmpty) {
      polylines.add(MapPolyline(
        id: 'route_$dayNum',
        points: routeCoordinates,
        color: const Color(0xFF4CAF50),
        width: 4.0,
      ));
    }
    
    final mapConfig = MapConfiguration.mainMap(
      enable3DTerrain: false,
      initialZoom: 12.0,
    );
    
    return SizedBox(
      height: 300,
      child: AdaptiveMapWidget(
        key: ValueKey('day-map-$dayNum-${route?.poiWaypoints.length ?? 0}'),
        initialCenter: center,
        configuration: mapConfig,
        annotations: annotations,
        polylines: polylines,
        onMapCreated: (controller) {
          // Store controller for this day
          _dayMapControllers[dayNum] = controller;
          
          // Use post-frame callback to avoid setState during build.
          // Guard with mounted check: the widget (and the map) may have
          // been disposed by the time this frame fires (tab switch race).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Also verify the stored controller is still the one we created;
            // a rapid rebuild could have replaced it.
            if (_dayMapControllers[dayNum] != controller) return;

            // Fit bounds to show all waypoints and route
            final allPoints = <ll.LatLng>[];
            allPoints.addAll(waypoints.map((w) => w.position));
            allPoints.addAll(routeCoordinates);
            
            // Add GPX route points if available
            if (isGpxRoute) {
              final dayState = version.getDayState(dayNum);
              final gpxRoute = dayState.gpxRoute;
              if (gpxRoute != null && gpxRoute.simplifiedPoints.isNotEmpty) {
                allPoints.addAll(gpxRoute.simplifiedPoints
                    .map((p) => ll.LatLng(p.latitude, p.longitude))
                    .toList());
              }
            }
            
            if (allPoints.isEmpty) {
              final selectedLocation = _formState?.locationSearch.selectedLocation;
              if (selectedLocation != null) {
                allPoints.add(ll.LatLng(selectedLocation.latitude, selectedLocation.longitude));
              }
            }
            
            if (allPoints.isNotEmpty) {
              _animateCameraToPoints(allPoints, controller);
            }
          });
        },
      ),
    );
  }
  
  /// Helper function to get ordered waypoints from a day's route
  /// Returns empty list if route is null
  List<RouteWaypoint> _getOrderedWaypoints(DayFormState dayState) {
    final route = dayState.route;
    if (route == null) return [];
    
    final isGpxRoute = route.routeType == RouteType.gpx;
    final waypoints = route.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .where((wp) => !isGpxRoute || wp.type != WaypointType.routePoint)
        .toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    
    return waypoints;
  }
  
  Widget _buildWaypointTimeline(int dayNum, VersionFormState version) {
    if (_formState == null) return const SizedBox.shrink();
    
    final dayState = version.getDayState(dayNum);
    final existingRoute = dayState.route;
    
    if (existingRoute == null) {
      return EmptyStateWidget(
        icon: Icons.place,
        message: 'Create a route first to add waypoints',
        actionLabel: widget.mode == AdventureMode.builder ? 'Create Route' : null,
        onAction: widget.mode == AdventureMode.builder
            ? () {
                // Navigate to route builder
                final planId = _formState!.editingPlan?.id ?? 'new';
                context.push(
                  '/builder/route-builder/$planId/${_formState!.activeVersionIndex}/$dayNum',
                );
              }
            : null,
      );
    }
    
    // Get waypoints using helper function
    final waypoints = _getOrderedWaypoints(dayState);
    
    return WaypointTimelineList(
      waypoints: waypoints,
      isBuilder: widget.mode == AdventureMode.builder,
      collapseThreshold: 4,
      enableCollapse: true,
      onWaypointTap: (waypoint) {
        // TODO: Show waypoint details or navigate
      },
      onGetDirections: (waypoint) async {
        // Open Google Maps directions
        try {
          final url = 'https://www.google.com/maps/dir/?api=1&destination=${waypoint.position.latitude},${waypoint.position.longitude}';
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          // Silently fail - URL launch errors are not critical
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open directions: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onMoveUp: widget.mode == AdventureMode.builder
          ? (waypoint) => _moveWaypointUp(dayNum, waypoint, version)
          : null,
      onMoveDown: widget.mode == AdventureMode.builder
          ? (waypoint) => _moveWaypointDown(dayNum, waypoint, version)
          : null,
      onEdit: widget.mode == AdventureMode.builder
          ? (waypoint) => _editWaypoint(dayNum, waypoint, version)
          : null,
      onDelete: widget.mode == AdventureMode.builder
          ? (waypoint) => _deleteWaypoint(dayNum, waypoint, version)
          : null,
    );
  }
  
  /// Distinct order values for the day's waypoints (order-group aware).
  List<int> _getDistinctOrdersForDay(DayFormState dayState) {
    final waypoints = _getOrderedWaypoints(dayState);
    final orders = waypoints.map((w) => w.order ?? 0).toSet().toList()..sort();
    return orders;
  }

  /// Move a waypoint (or its entire choice group) up by swapping orders with the previous order group.
  void _moveWaypointUp(int dayNum, RouteWaypoint waypoint, VersionFormState version) {
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    if (route == null) return;

    final waypoints = _getOrderedWaypoints(dayState);
    final orders = _getDistinctOrdersForDay(dayState);
    final currentOrder = waypoint.order ?? 0;
    final currentOrderIndex = orders.indexOf(currentOrder);
    if (currentOrderIndex <= 0) return;

    final previousOrder = orders[currentOrderIndex - 1];

    final allWaypoints = route.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)).toList();
    final updatedWaypoints = allWaypoints.map((w) {
      final o = w.order ?? 0;
      if (o == currentOrder) return w.copyWith(order: previousOrder);
      if (o == previousOrder) return w.copyWith(order: currentOrder);
      return w;
    }).toList();

    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
      );
    });
  }

  /// Move a waypoint (or its entire choice group) down by swapping orders with the next order group.
  void _moveWaypointDown(int dayNum, RouteWaypoint waypoint, VersionFormState version) {
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    if (route == null) return;

    final waypoints = _getOrderedWaypoints(dayState);
    final orders = _getDistinctOrdersForDay(dayState);
    final currentOrder = waypoint.order ?? 0;
    final currentOrderIndex = orders.indexOf(currentOrder);
    if (currentOrderIndex < 0 || currentOrderIndex >= orders.length - 1) return;

    final nextOrder = orders[currentOrderIndex + 1];

    final allWaypoints = route.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)).toList();
    final updatedWaypoints = allWaypoints.map((w) {
      final o = w.order ?? 0;
      if (o == currentOrder) return w.copyWith(order: nextOrder);
      if (o == nextOrder) return w.copyWith(order: currentOrder);
      return w;
    }).toList();

    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
      );
    });
  }
  
  
  /// Show dialog to edit duration (number of days)
  void _showDurationEditDialog() {
    if (_formState == null || _formState!.versions.isEmpty) return;
    
    final version = _formState!.activeVersion;
    final currentDays = version.daysCount;
    final controller = TextEditingController(text: currentDays.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Duration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of days',
            hintText: 'Enter number of days',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final daysText = controller.text.trim();
              final days = int.tryParse(daysText);
              if (days != null && days > 0) {
                // Update version duration
                version.durationCtrl.text = days.toString();
                version.notifyListeners();
                _formState!.notifyListeners();
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number of days')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  /// Add-waypoint flow: push Stippl-style waypoint edit page. No LocationSearchDialog or type dialog.
  Future<void> _onAddWaypointTapped(BuildContext context) async {
    if (_formState == null || !mounted) return;
    final version = _formState!.activeVersion;
    if (version == null) return;
    final dayNum = _selectedDay;
    final dayState = version.getDayState(dayNum);
    dayState.route ??= const DayRoute(
      geometry: {},
      distance: 0,
      duration: 0,
      routePoints: [],
      poiWaypoints: [],
    );
    final planId = _formState!.editingPlan?.id ?? 'new';
    final path = '/builder/$planId/waypoint/${_formState!.activeVersionIndex}/$dayNum';
    final result = await context.push<WaypointEditResult>(
      path,
      extra: <String, dynamic>{
        'mode': 'add',
        'initialRoute': dayState.route,
        'existingWaypoint': null,
        'tripName': _formState!.nameCtrl.text.trim().isNotEmpty ? _formState!.nameCtrl.text.trim() : 'Trip',
      },
    );
    if (!mounted) return;
    if (result is WaypointSaved) {
      setState(() => version.getDayState(dayNum).route = result.route);
    }
    // WaypointDeleted cannot occur in add flow (delete action hidden in add mode).
  }

  /// Stippl-style bottom bar on itinerary tab (builder only): white pill bar with centered green + button.
  Widget _buildItineraryBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Center(
          child: Material(
            color: const Color(0xFF1B4332),
            borderRadius: BorderRadius.circular(28),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => _onAddWaypointTapped(context),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editWaypoint(int dayNum, RouteWaypoint waypoint, VersionFormState version) async {
    final planId = _formState!.editingPlan?.id ?? 'new';
    final dayState = version.getDayState(dayNum);
    dayState.route ??= const DayRoute(
      geometry: {},
      distance: 0,
      duration: 0,
      routePoints: [],
      poiWaypoints: [],
    );
    final path = '/builder/$planId/waypoint/${_formState!.activeVersionIndex}/$dayNum';
    final result = await context.push<WaypointEditResult>(
      path,
      extra: <String, dynamic>{
        'mode': 'edit',
        'initialRoute': dayState.route,
        'existingWaypoint': waypoint,
        'tripName': _formState!.nameCtrl.text.trim().isNotEmpty ? _formState!.nameCtrl.text.trim() : 'Trip',
      },
    );
    if (!mounted) return;
    if (result is WaypointSaved) {
      setState(() => version.getDayState(dayNum).route = result.route);
    } else if (result is WaypointDeleted) {
      final route = dayState.route;
      if (route != null) {
        final waypoints = route.poiWaypoints
            .map((e) => RouteWaypoint.fromJson(Map<String, dynamic>.from(e)))
            .where((w) => w.id != result.waypointId)
            .toList();
        setState(() {
          dayState.route = route.copyWith(
            poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
          );
        });
      }
    }
  }
  
  void _deleteWaypoint(int dayNum, RouteWaypoint waypoint, VersionFormState version) {
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    if (route == null) return;

    final waypoints = route.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .where((w) => w.id != waypoint.id)
        .toList();

    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
      );
    });
  }

  /// Ungroup a choice group: remove choiceGroupId/choiceLabel and assign sequential orders.
  void _ungroupChoiceGroup(int dayNum, String choiceGroupId, VersionFormState version) {
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    if (route == null) return;

    final allWaypoints = route.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)).toList();
    final inGroup = allWaypoints.where((w) => w.choiceGroupId == choiceGroupId).toList();
    if (inGroup.isEmpty) return;

    final baseOrder = inGroup.first.order ?? 0;
    final updates = <RouteWaypoint>[];
    int groupIndex = 0;
    for (final w in allWaypoints) {
      if (w.choiceGroupId == choiceGroupId) {
        updates.add(w.copyWith(
          choiceGroupId: null,
          choiceLabel: null,
          order: baseOrder + groupIndex,
        ));
        groupIndex++;
      } else {
        updates.add(w);
      }
    }
    // Renumber sequentially so orders stay 1,2,3,...
    updates.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    for (int i = 0; i < updates.length; i++) {
      updates[i] = updates[i].copyWith(order: i + 1);
    }

    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updates.map((w) => w.toJson()).toList(),
      );
    });
  }

  /// Link two waypoints as OR alternatives (same choice group).
  Future<void> _linkWaypointsAsChoice(
    int dayNum,
    RouteWaypoint sourceWaypoint,
    RouteWaypoint selectedWaypoint,
    VersionFormState version,
  ) async {
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    if (route == null) return;

    final choiceGroupId = sourceWaypoint.choiceGroupId ?? generateChoiceGroupId();
    final choiceLabel = sourceWaypoint.choiceLabel ??
        generateAutoChoiceLabel(
          sourceWaypoint.type,
          sourceWaypoint.mealTime,
          sourceWaypoint.activityTime,
        );
    final sourceOrder = sourceWaypoint.order ?? 0;

    final allWaypoints = route.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)).toList();
    final oldChoiceGroupId = selectedWaypoint.choiceGroupId;

    var updated = allWaypoints.map((w) {
      if (w.id == sourceWaypoint.id) {
        return w.copyWith(choiceGroupId: choiceGroupId, choiceLabel: choiceLabel);
      }
      if (w.id == selectedWaypoint.id) {
        return w.copyWith(
          order: sourceOrder,
          choiceGroupId: choiceGroupId,
          choiceLabel: choiceLabel,
        );
      }
      return w;
    }).toList();

    if (oldChoiceGroupId != null && oldChoiceGroupId != choiceGroupId) {
      final remainingInOld = updated.where((w) => w.choiceGroupId == oldChoiceGroupId).length;
      if (remainingInOld <= 1) {
        updated = updated.map((w) {
          if (w.choiceGroupId == oldChoiceGroupId) {
            return w.copyWith(choiceGroupId: null, choiceLabel: null);
          }
          return w;
        }).toList();
      }
    }

    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updated.map((w) => w.toJson()).toList(),
      );
    });
  }

  /// Pick and set cover image from device
  Future<void> _pickCoverImage() async {
    if (_formState == null) return;
    
    try {
      final result = await _storageService.pickImage();
      if (result != null && mounted) {
        setState(() {
          _formState!.coverImageBytes = result.bytes;
          _formState!.coverImageExtension = result.extension;
          _formState!.heroImageUrlCtrl.clear(); // Clear URL if image is picked
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      Log.e('adventure_detail', 'Failed to pick cover image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }
  
  Future<void> _pickDayImage(int dayNum) async {
    if (_formState == null || _formState!.versions.isEmpty) return;
    
    try {
      final result = await _storageService.pickImage();
      if (result != null && mounted) {
        setState(() {
          final dayState = _formState!.activeVersion.getDayState(dayNum);
          dayState.newImageBytes = [result.bytes];
          dayState.newImageExtensions = [result.extension];
          dayState.existingImageUrls = [];
          dayState.notifyListeners();
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      Log.e('adventure_detail', 'Failed to pick day image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }
  
  /// Helper to get month name from month number (1-12)
  String _getMonthName(int monthNum) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[monthNum - 1];
  }
  
  /// Build the Best Seasons editor widget
  Widget _buildBestSeasonsEditor() {
    if (_formState == null) return const SizedBox.shrink();
    
    return ListenableBuilder(
      listenable: _formState!,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entire Year Checkbox
            CheckboxListTile(
              title: const Text('Entire Year'),
              value: _formState!.isEntireYear,
              onChanged: (value) {
                setState(() {
                  _formState!.isEntireYear = value ?? false;
                  if (_formState!.isEntireYear) {
                    _formState!.bestSeasons.clear();
                  }
                  _hasUnsavedChanges = true;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            
            // Season Ranges List (only if not entire year)
            if (!_formState!.isEntireYear) ...[
              const SizedBox(height: 12),
              ...List.generate(_formState!.bestSeasons.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _formState!.bestSeasons[index].startMonth,
                          decoration: InputDecoration(
                            labelText: "Start Month",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: List.generate(12, (i) {
                            final monthNum = i + 1;
                            return DropdownMenuItem(
                              value: monthNum,
                              child: Text(_getMonthName(monthNum)),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _formState!.bestSeasons[index] = SeasonRange(
                                  startMonth: value,
                                  endMonth: _formState!.bestSeasons[index].endMonth,
                                );
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _formState!.bestSeasons[index].endMonth,
                          decoration: InputDecoration(
                            labelText: "End Month",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: List.generate(12, (i) {
                            final monthNum = i + 1;
                            return DropdownMenuItem(
                              value: monthNum,
                              child: Text(_getMonthName(monthNum)),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _formState!.bestSeasons[index] = SeasonRange(
                                  startMonth: _formState!.bestSeasons[index].startMonth,
                                  endMonth: value,
                                );
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _formState!.bestSeasons.removeAt(index);
                            _hasUnsavedChanges = true;
                          });
                        },
                        tooltip: "Remove season",
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Add Season Button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _formState!.bestSeasons.add(SeasonRange(
                      startMonth: 1,
                      endMonth: 12,
                    ));
                    _hasUnsavedChanges = true;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Season"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
  
  /// Build the FAQ editor widget
  Widget _buildFAQEditor() {
    if (_formState == null) return const SizedBox.shrink();
    
    return ListenableBuilder(
      listenable: _formState!,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ items
            ..._formState!.faqItems.asMap().entries.map((entry) {
              final index = entry.key;
              final faq = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildFAQEditorCard(index, faq),
              );
            }),
            
            // Add FAQ button
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _formState!.faqItems.add(FAQFormState.initial());
                  _hasUnsavedChanges = true;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add FAQ'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Build a single FAQ editor card
  Widget _buildFAQEditorCard(int index, FAQFormState faq) {
    return Container(
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        border: Border.all(color: LightModeColors.outline),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.help_outline, size: 20, color: WaypointColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: faq.questionCtrl,
                builder: (context, value, _) {
                  return Text(
                    value.text.isEmpty ? 'FAQ ${index + 1}' : value.text,
                    style: WaypointTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                setState(() {
                  _formState!.faqItems.removeAt(index);
                  _hasUnsavedChanges = true;
                });
              },
              tooltip: 'Delete FAQ',
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          InlineEditableField(
            label: 'Question',
            controller: faq.questionCtrl,
            isEditable: true,
            hint: 'What do you want to ask?',
            onEditComplete: () {
              _hasUnsavedChanges = true;
            },
          ),
          const SizedBox(height: 16),
          InlineEditableField(
            label: 'Answer',
            controller: faq.answerCtrl,
            isEditable: true,
            hint: 'Provide a helpful answer...',
            maxLines: 5,
            onEditComplete: () {
              _hasUnsavedChanges = true;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBuilderReviewTab() {
    if (_formState == null) return const SizedBox.shrink();
    
    return _buildScrollTab([
              const SizedBox(height: WaypointSpacing.sectionGap),
              
              // Page Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Your Adventure',
                    style: WaypointTypography.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure everything looks good before publishing',
                    style: WaypointTypography.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Publish Status Toggle
              _buildPublishStatusToggle(),
              const SizedBox(height: 24),
              
              // Summary Cards
              _buildReviewGeneralCard(),
              _buildReviewVersionsCard(),
              _buildReviewPrepareCard(),
              _buildReviewLocalTipsCard(),
              _buildReviewDaysCard(),
              
              const SizedBox(height: 80),
    ]);
  }
  
  Widget _buildPublishStatusToggle() {
    if (_formState == null) return const SizedBox.shrink();
    
    return SectionCard(
      title: 'Publish Status',
      icon: _formState!.isPublished ? Icons.public : Icons.edit_note,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formState!.isPublished
                        ? 'Visible on marketplace'
                        : 'Saved as draft (not visible)',
                    style: WaypointTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: _formState!.isPublished,
              onChanged: (value) async {
                if (_formState != null) {
                  _formState!.isPublished = value;
                  setState(() {});
                  
                  // Save publish status
                  try {
                    await _saveService.saveDraft(_formState!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Adventure published successfully'
                                : 'Adventure saved as draft',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update publish status: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      // Revert on error
                      _formState!.isPublished = !value;
                      setState(() {});
                    }
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _formState!.isPublished
                    ? WaypointColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formState!.isPublished ? 'Published' : 'Draft',
                style: WaypointTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _formState!.isPublished
                      ? WaypointColors.primary
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildReviewGeneralCard() {
    if (_formState == null) return const SizedBox.shrink();
    
    final isComplete = _formState!.nameCtrl.text.trim().isNotEmpty &&
        _formState!.descriptionCtrl.text.trim().isNotEmpty &&
        _formState!.locationCtrl.text.trim().isNotEmpty;
    
    return _ReviewSummaryCard(
      icon: Icons.info_outline,
      title: 'General Information',
      isComplete: isComplete,
      onEdit: () {
        // Switch to Overview navigation item
        _onNavigationItemSelected(NavigationItem.overview);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _formState!.coverImageBytes != null
                    ? Image.memory(
                        _formState!.coverImageBytes!,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : _formState!.heroImageUrlCtrl.text.trim().isNotEmpty
                        ? Image.network(
                            _formState!.heroImageUrlCtrl.text,
                            width: 100,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, color: Colors.grey.shade400),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: Icon(Icons.image, color: Colors.grey.shade400),
                          ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formState!.nameCtrl.text.trim().isNotEmpty
                          ? _formState!.nameCtrl.text
                          : 'Untitled Adventure',
                      style: WaypointTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _formState!.nameCtrl.text.trim().isNotEmpty
                            ? WaypointColors.textPrimary
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formState!.descriptionCtrl.text.trim().isNotEmpty
                          ? _formState!.descriptionCtrl.text
                          : 'No description added',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WaypointTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_formState!.locationCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formState!.locationCtrl.text,
                    style: WaypointTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildReviewVersionsCard() {
    if (_formState == null) return const SizedBox.shrink();
    
    final hasVersions = _formState!.versions.isNotEmpty &&
        _formState!.versions.any((v) => v.daysCount > 0);
    
    return _ReviewSummaryCard(
      icon: Icons.layers_outlined,
      title: 'Versions',
      badge: '${_formState!.versions.length} version${_formState!.versions.length != 1 ? 's' : ''}',
      isComplete: hasVersions,
      onEdit: () {
        // Switch to Overview navigation item where versions are managed via VersionCarousel
        _onNavigationItemSelected(NavigationItem.overview);
      },
      child: hasVersions
          ? Column(
              children: _formState!.versions.asMap().entries.map((entry) {
                final index = entry.key;
                final version = entry.value;
                final duration = version.daysCount;
                if (duration == 0) return const SizedBox.shrink();
                
                final price = double.tryParse(
                      _formState!.priceCtrl.text.replaceAll(',', '.'),
                    ) ??
                    0.0;
                
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < _formState!.versions.length - 1 ? 12 : 0,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              version.nameCtrl.text.trim().isNotEmpty
                                  ? version.nameCtrl.text
                                  : 'Version ${index + 1}',
                              style: WaypointTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$duration day${duration != 1 ? 's' : ''}',
                                  style: WaypointTypography.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: price == 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          price == 0 ? 'FREE' : '€${price.toStringAsFixed(2)}',
                          style: WaypointTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: price == 0
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No versions added yet',
                style: WaypointTypography.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
    );
  }
  
  Widget _buildReviewPrepareCard() {
    if (_formState == null || _formState!.versions.isEmpty) return const SizedBox.shrink();
    
    final activeVersion = _formState!.activeVersion;
    
    final hasPacking = activeVersion.packingCategories.isNotEmpty;
    int totalItems = 0;
    for (final cat in activeVersion.packingCategories) {
      totalItems += cat.items.length;
    }
    
    final hasPrepare = activeVersion.generatedPrepare != null;
    
    return _ReviewSummaryCard(
      icon: Icons.backpack_outlined,
      title: 'Travel Preparation',
      badge: hasPacking ? '$totalItems items' : null,
      isComplete: hasPacking || hasPrepare,
      onEdit: () {
        // Switch to Checklist navigation item
        _onNavigationItemSelected(NavigationItem.checklist);
      },
      child: (hasPacking || hasPrepare)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPacking) ...[
                  Text(
                    'Packing Categories',
                    style: WaypointTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...activeVersion.packingCategories.take(3).map((cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${cat.nameCtrl.text} (${cat.items.length} items)',
                                style: WaypointTypography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (activeVersion.packingCategories.length > 3)
                    Text(
                      '+ ${activeVersion.packingCategories.length - 3} more categories',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (hasPrepare && hasPacking) const SizedBox(height: 16),
                if (hasPrepare)
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Travel preparation info added',
                        style: WaypointTypography.bodyMedium,
                      ),
                    ],
                  ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No preparation content added yet',
                style: WaypointTypography.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
    );
  }
  
  Widget _buildReviewLocalTipsCard() {
    if (_formState == null || _formState!.versions.isEmpty) return const SizedBox.shrink();
    
    final activeVersion = _formState!.activeVersion;
    
    final hasLocalTips = activeVersion.generatedLocalTips != null;
    final foodCount = activeVersion.generatedLocalTips?.foodSpecialties.length ?? 0;
    
    return _ReviewSummaryCard(
      icon: Icons.lightbulb_outline,
      title: 'Local Tips',
      badge: hasLocalTips && foodCount > 0 ? '$foodCount specialties' : null,
      isComplete: hasLocalTips,
      onEdit: () {
        // Switch to Local Tips navigation item
        _onNavigationItemSelected(NavigationItem.localTips);
      },
      child: hasLocalTips
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (foodCount > 0) ...[
                  Text(
                    'Food Specialties',
                    style: WaypointTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...activeVersion.generatedLocalTips!.foodSpecialties.take(3).map((food) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                food.name,
                                style: WaypointTypography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (foodCount > 3)
                    Text(
                      '+ ${foodCount - 3} more specialties',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No local tips added yet',
                style: WaypointTypography.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
    );
  }
  
  Widget _buildReviewDaysCard() {
    if (_formState == null || _formState!.versions.isEmpty) return const SizedBox.shrink();
    
    final activeVersion = _formState!.activeVersion;
    
    final daysCount = activeVersion.daysCount;
    final hasDays = daysCount > 0;
    
    // Count total waypoints across all days
    int totalWaypoints = 0;
    for (int dayNum = 1; dayNum <= daysCount; dayNum++) {
      final dayState = activeVersion.getDayState(dayNum);
      if (dayState.route != null) {
        totalWaypoints += dayState.route!.poiWaypoints.length;
      }
    }
    
    return _ReviewSummaryCard(
      icon: Icons.calendar_view_day,
      title: 'Day Itineraries',
      badge: hasDays ? '$daysCount days, $totalWaypoints waypoints' : null,
      isComplete: hasDays,
      onEdit: () {
        // Switch to Itinerary navigation item
        _onNavigationItemSelected(NavigationItem.itinerary);
      },
      child: hasDays
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                daysCount > 3 ? 3 : daysCount,
                (index) {
                  final dayNum = index + 1;
                  final dayState = activeVersion.getDayState(dayNum);
                  final waypointCount =
                      dayState.route?.poiWaypoints.length ?? 0;
                  
                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index < (daysCount > 3 ? 3 : daysCount) - 1
                          ? 12
                          : 0,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: WaypointColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: WaypointTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: WaypointColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Day $dayNum',
                                style: WaypointTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (waypointCount > 0)
                                Text(
                                  '$waypointCount waypoint${waypointCount != 1 ? 's' : ''}',
                                  style: WaypointTypography.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )..addAll(
                  daysCount > 3
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${daysCount - 3} more days',
                              style: WaypointTypography.bodyMedium.copyWith(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ]
                      : [],
                ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No days added yet',
                style: WaypointTypography.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_adventureData == null || _plan == null) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20), // Consistent 20px spacing

                        // ★ IMAGE GALLERY (full-width within the 960px left col)
                        AdventureImageGallery(
                          imageUrls: _adventureImageUrls,
                          isDesktop: WaypointBreakpoints.isDesktop(
                            MediaQuery.of(context).size.width),
                        ),

                        // Mobile price card (appears after image gallery)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Defensive check: ensure constraints are valid
                            if (constraints.maxWidth <= 0) {
                              return const SizedBox.shrink();
                            }
                            
                            try {
                            final isMobile = WaypointBreakpoints.isMobile(constraints.maxWidth);
                            if (isMobile) {
                              return Column(
                                children: [
                                  const SizedBox(height: 24),
                                  _buildPriceCard(context),
                                  const SizedBox(height: 24),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                            } catch (e) {
                              // Ignore errors during hot reload
                              return const SizedBox.shrink();
                            }
                          },
                        ),

                        // Quick stats row
                        _buildQuickStats(context),
                        const SizedBox(height: 32),

                        // Description below image
                        if (_plan!.description.isNotEmpty)
                          _hasPurchased == false && _plan!.description.length > 200
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_plan!.description.substring(0, 200)}...',
                                      style: const TextStyle(
                                        fontFamily: 'DMSans',
                                        fontSize: 16,
                                        height: 1.6,
                                        color: Color(0xFF495057),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Unlock to see full description',
                                      style: const TextStyle(
                                        fontFamily: 'DMSans',
                                        fontSize: 15,
                                        color: Color(0xFF1B4332),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _plan!.description,
                                  style: const TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Color(0xFF495057),
                                  ),
                                ),
                        const SizedBox(height: WaypointSpacing.subsectionGap),
                        
                        // Highlights section (between description and owner card)
                        _buildHighlightsSection(context),
                        const SizedBox(height: WaypointSpacing.subsectionGap),
                        
                        // Owner card
                        _buildOwnerCard(context),
                        const SizedBox(height: WaypointSpacing.subsectionGap),
                        
                        // Tags Row
                        AdventureTagsRow(
                          activityCategory: _plan!.activityCategory,
                          accommodationType: _plan!.accommodationType,
                          bestSeasons: _plan!.bestSeasons,
                          isEntireYear: _plan!.isEntireYear,
                          location: _plan!.location,
                        ),
                        const SizedBox(height: WaypointSpacing.subsectionGap),
                        
                        // Review Score (viewer only)
                        if (_plan!.reviewStats != null && _plan!.reviewStats!.totalReviews > 0)
                          ReviewScoreRow(
                            score: _plan!.reviewStats!.averageRating,
                            count: _plan!.reviewStats!.totalReviews,
                          ),
                        if (_plan!.reviewStats != null && _plan!.reviewStats!.totalReviews > 0)
                          const SizedBox(height: WaypointSpacing.subsectionGap),
                        
                        // Version selector (if multiple versions)
                        if (_availableVersions.length > 1) ...[
                          VersionSelectorBar.fromPlanVersions(
                            versions: _availableVersions,
                            activeIndex: _selectedVersionIndex,
                            onChanged: _onVersionChanged,
                          ),
                          const SizedBox(height: WaypointSpacing.subsectionGap),
                        ],
                        
                        // Creator Card (uses cached _creatorUserFuture)
                        if (_plan!.creatorId.isNotEmpty && _creatorUserFuture != null)
                          FutureBuilder<UserModel?>(
                            future: _creatorUserFuture,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                final user = snapshot.data!;
                                return CreatorCard(
                                  avatarUrl: user.photoUrl,
                                  name: user.displayName,
                                  bio: user.shortBio,
                                  creatorId: _plan!.creatorId,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        const SizedBox(height: WaypointSpacing.sectionGap),
                        
                        // FAQ Section
                        if (_adventureData!.faqItems.isNotEmpty) ...[
                          SectionCard(
                            title: "FAQ's",
                            icon: Icons.help_outline,
                            children: _hasPurchased == false
                                ? _adventureData!.faqItems.take(3).map((faq) => _buildFAQItem(faq)).toList()
                                    + [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            'Unlock to see all ${_adventureData!.faqItems.length} FAQ items',
                                            style: WaypointTypography.bodyMedium.copyWith(
                                              color: WaypointColors.textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ]
                                : _adventureData!.faqItems.map((faq) => _buildFAQItem(faq)).toList(),
                          ),
                        ],
                        
                        // Unlock banner for non-purchased plans
                        if (_hasPurchased == false) _buildUnlockBanner(),
                      ],
                    ),
                  ),

                  // Sidebar — only on desktop
                  if (MediaQuery.of(context).size.width >= 1024) ...[
                    const SizedBox(width: 40),
                    SizedBox(
                      width: 280,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildBuyPlanSidebar(), // price card here
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewerHeroImage(String imageUrl) {
    final isDesktop = WaypointBreakpoints.isDesktop(
      MediaQuery.of(context).size.width);

    return ClipRRect(
      borderRadius: isDesktop
          ? BorderRadius.circular(12)
          : BorderRadius.zero, // full-bleed on mobile
      child: AspectRatio(
        aspectRatio: isDesktop ? 21 / 9 : 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFE9ECEF),
            child: const Icon(Icons.landscape, size: 64, color: Color(0xFFADB5BD)),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UNIFIED NAVIGATION BAR — logo + breadcrumbs + save status
  // ============================================================
  PreferredSizeWidget _buildUnifiedNavBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1)),
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ---- Hamburger menu button ----
                if (!_isLoading && _errorMessage == null)
                  IconButton(
                    icon: const Icon(Icons.menu, size: 24, color: Colors.black87),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    tooltip: 'Menu',
                  )
                else
                  const SizedBox(width: 48), // preserve layout spacing
                const SizedBox(width: 12),

                // ---- Waypoint logo mark ----
                _buildLogoMark(),
                const SizedBox(width: 12),

                // Divider between logo and breadcrumbs
                Container(width: 1, height: 20, color: const Color(0xFFE9ECEF)),
                const SizedBox(width: 12),

                // ---- Breadcrumb row (LayoutBuilder constrains width so inner
                // scroll/tabs never get unbounded constraints) ----
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: constraints.maxWidth,
                      child: _buildBreadcrumbs(context),
                    ),
                  ),
                ),

                // ---- Save status (top-right) ----
                _buildSaveStatus(),
              ],
            ),
        ),
      ),
    );
  }

  /// Compact app bar for itinerary fullWaypoints mode: hamburger, logo, trip title, save status only.
  PreferredSizeWidget _buildCompactItineraryAppBar(BuildContext context) {
    final title = widget.mode == AdventureMode.builder && _formState != null
        ? (_formState!.nameCtrl.text.isEmpty ? 'Trip' : _formState!.nameCtrl.text)
        : (_adventureData?.displayName ?? 'Trip');
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_isLoading && _errorMessage == null)
                IconButton(
                  icon: const Icon(Icons.menu, size: 24, color: Colors.black87),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Menu',
                )
              else
                const SizedBox(width: 48),
              const SizedBox(width: 12),
              _buildLogoMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildSaveStatus(),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build content based on current navigation item (replaces TabBarView)
  Widget _buildNavigationContent() {
    switch (_currentNavigationItem) {
      case NavigationItem.overview:
        // Use builder overview for builder mode, viewer overview for viewer/trip modes
        if (widget.mode == AdventureMode.builder) {
          return _buildBuilderOverviewTab();
        } else {
          return _buildOverviewTab();
        }
      case NavigationItem.itinerary:
        return _buildItineraryTab();
      case NavigationItem.checklist:
        if (widget.mode == AdventureMode.builder) {
          return _buildBuilderPrepareTab();
        } else if (widget.mode == AdventureMode.trip) {
          return _buildTripPrepareTab();
        } else {
          return _buildPrepareTab();
        }
      case NavigationItem.localTips:
        if (widget.mode == AdventureMode.builder) {
          return _buildBuilderLocalTipsTab();
        } else {
          return _buildLocalTipsTab();
        }
      case NavigationItem.comments:
        return _buildCommentsTab();
      case NavigationItem.review:
        return _buildBuilderReviewTab();
    }
  }
  
  /// Build itinerary tab: desktop = static 50/50; mobile = full-screen map + draggable panel.
  /// Mobile panel has 3 snap states: 12% (map full), 50% (50/50), 92% (waypoints full).
  Widget _buildItineraryTab() {
    final dayCount = _dayCount;
    final ctrlLen = _dayTabController?.length;
    Log.i('adventure_detail', 'Itinerary build: dayCount=$dayCount, controller=${_dayTabController != null ? "length=$ctrlLen" : "null"}');
    if (dayCount == 0) {
      Log.i('adventure_detail', 'Itinerary build: showing "No days" (dayCount=0)');
      return const Center(
        child: Text('No days available. Set duration in Overview.'),
      );
    }

    if (_selectedDay > dayCount) _selectedDay = dayCount;
    if (_selectedDay < 1) _selectedDay = 1;

    // Controller is created/updated outside build (from _onNavigationItemSelected,
    // _onDayTabChanged, and _loadAdventure). Never call _scheduleDayTabControllerUpdate
    // here in a way that causes setState-during-build; only schedule once and show spinner.
    if (_dayTabController == null || _dayTabController!.length != dayCount) {
      Log.i('adventure_detail', 'Itinerary build: showing spinner, scheduling controller (need length=$dayCount)');
      _scheduleDayTabControllerUpdate(dayCount);
      return const Center(child: CircularProgressIndicator());
    }

    Log.i('adventure_detail', 'Itinerary build: rendering content (desktop/mobile)');
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = WaypointBreakpoints.isDesktop(screenWidth);
    // On mobile/narrow viewports force mapHeavy (map + draggable panel); desktop uses selected mode.
    final effectiveMode = isDesktop ? _itineraryViewMode : ItineraryViewMode.mapHeavy;

    switch (effectiveMode) {
      case ItineraryViewMode.fullWaypoints:
        return _buildFullWaypointsItinerary();
      case ItineraryViewMode.split50:
        return _buildDesktopItinerary();
      case ItineraryViewMode.mapHeavy:
        return _buildMobileItinerary(dayCount);
    }
  }

  /// Full-waypoints layout: day tab bar (with mode switcher) + waypoint list, no map.
  Widget _buildFullWaypointsItinerary() {
    final (waypoints, isBuilder) = _getWaypointsForSelectedDay();
    return Column(
      children: [
        _buildCustomDayTabBar(compact: false, trailing: _buildModeSwitcher()),
        Expanded(
          child: _buildWaypointListContent(waypoints, isBuilder),
        ),
      ],
    );
  }

  /// Row of icon buttons to switch itinerary view mode (list / split). Map mode not offered on desktop.
  Widget _buildModeSwitcher() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.view_list, size: 22),
          tooltip: 'Full waypoints',
          onPressed: () => setState(() => _itineraryViewMode = ItineraryViewMode.fullWaypoints),
        ),
        IconButton(
          icon: const Icon(Icons.view_column, size: 22),
          tooltip: '50/50 split',
          onPressed: () => setState(() => _itineraryViewMode = ItineraryViewMode.split50),
        ),
      ],
    );
  }

  /// Schedules TabController creation/update. Uses post-frame callback with
  /// phase guard so setState never runs during layout; after creation we
  /// schedule a frame so the rebuild is applied (fixes stuck spinner on web).
  void _scheduleDayTabControllerUpdate(int dayCount) {
    if (_dayTabController != null && _dayTabController!.length == dayCount) {
      Log.i('adventure_detail', 'Itinerary schedule: skip (controller already length=$dayCount)');
      return;
    }
    if (_dayTabControllerUpdateScheduled) {
      Log.i('adventure_detail', 'Itinerary schedule: skip (already scheduled)');
      return;
    }
    _dayTabControllerUpdateScheduled = true;
    Log.i('adventure_detail', 'Itinerary schedule: post-frame callback registered (dayCount=$dayCount)');

    void runCreation() {
      _dayTabControllerUpdateScheduled = false;
      if (!mounted) {
        Log.i('adventure_detail', 'Itinerary runCreation: skip (not mounted)');
        return;
      }
      if (_dayTabController != null && _dayTabController!.length == dayCount) {
        Log.i('adventure_detail', 'Itinerary runCreation: skip (controller already length=$dayCount)');
        return;
      }
      Log.i('adventure_detail', 'Itinerary runCreation: calling _createDayTabController($dayCount)');
      _createDayTabController(dayCount);
      // Ensure a frame is scheduled so the new controller triggers a repaint (web).
      SchedulerBinding.instance.scheduleFrame();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phase = SchedulerBinding.instance.schedulerPhase;
      Log.i('adventure_detail', 'Itinerary postFrameCallback: phase=$phase');
      if (phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.postFrameCallbacks) {
        Log.i('adventure_detail', 'Itinerary postFrameCallback: deferring one more frame (phase guard)');
        _dayTabControllerUpdateScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => runCreation());
        return;
      }
      runCreation();
    });
  }

  void _createDayTabController(int dayCount) {
    if (!mounted) {
      Log.i('adventure_detail', 'Itinerary createController: skip (not mounted)');
      return;
    }
    if (_dayTabController != null && _dayTabController!.length == dayCount) {
      Log.i('adventure_detail', 'Itinerary createController: skip (already length=$dayCount)');
      return;
    }
    Log.i('adventure_detail', 'Itinerary createController: setState creating TabController(length=$dayCount)');
    setState(() {
      _dayTabController?.dispose();
      _dayTabController = TabController(
        length: dayCount,
        vsync: this,
        initialIndex: (_selectedDay - 1).clamp(0, dayCount - 1),
      );
      _dayTabController!.addListener(() {
        if (!_dayTabController!.indexIsChanging && mounted) {
          final newDay = _dayTabController!.index + 1;
          if (newDay != _selectedDay) _onDayTabChanged(newDay);
        }
      });
    });
  }

  /// Pre-warm day TabController after load so itinerary tab has a controller
  /// ready when user switches to Itinerary (avoids stuck spinner).
  void _ensureDayTabControllerAfterLoad() {
    Log.i('adventure_detail', 'Itinerary ensureAfterLoad: scheduling post-frame callback');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        Log.i('adventure_detail', 'Itinerary ensureAfterLoad: skip (not mounted)');
        return;
      }
      final dayCount = _dayCount;
      final needCreate = dayCount > 0 &&
          (_dayTabController == null || _dayTabController!.length != dayCount);
      Log.i('adventure_detail', 'Itinerary ensureAfterLoad: dayCount=$dayCount, needCreate=$needCreate');
      if (needCreate) {
        _createDayTabController(dayCount);
      }
    });
  }

  /// Desktop: static 50/50 Row (map | day tabs + waypoints).
  Widget _buildDesktopItinerary() {
    final (waypoints, isBuilder) = _getWaypointsForSelectedDay();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => _buildMapForSelectedDay(height: constraints.maxHeight),
          ),
        ),
        Container(width: 1, color: Colors.grey.shade200),
        Expanded(
          child: Column(
            children: [
              _buildDesktopDayTabBar(),
              Expanded(
                child: _buildWaypointListContent(waypoints, isBuilder),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDayTabBar() {
    if (_dayTabController == null) return const SizedBox(height: 46);
    return _buildCustomDayTabBar(compact: false, trailing: _buildModeSwitcher());
  }

  /// Mobile: full-screen map with draggable waypoints panel (3 snap states).
  /// On short screens (<700px) use slightly smaller initial size so day tabs stay visible.
  Widget _buildMobileItinerary(int dayCount) {
    final screenHeight = MediaQuery.of(context).size.height;
    final initialSize = screenHeight < 700 ? 0.45 : _snapMid;

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => _buildMapForSelectedDay(height: constraints.maxHeight),
          ),
        ),
        DraggableScrollableSheet(
          controller: _draggableController,
          initialChildSize: initialSize,
          minChildSize: _snapMin,
          maxChildSize: _snapMax,
          snap: true,
          snapSizes: const [_snapMin, _snapMid, _snapMax],
          builder: (context, scrollController) {
            return _buildDraggablePanel(scrollController);
          },
        ),
      ],
    );
  }

  Widget _buildDraggablePanel(ScrollController scrollController) {
    final (waypoints, isBuilder) = _getWaypointsForSelectedDay();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildPanelDayTabBar(),
          Expanded(
            child: _buildWaypointListContent(
              waypoints,
              isBuilder,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _cyclePanelState,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.drag_handle, size: 20, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  /// Tap handle cycles: mid → max → min → mid.
  void _cyclePanelState() {
    if (!_draggableController.isAttached) return;
    final current = _draggableController.size;
    double next;
    if (current <= _snapMin + 0.05) {
      next = _snapMid;
    } else if (current <= _snapMid + 0.05) {
      next = _snapMax;
    } else {
      next = _snapMin;
    }
    _draggableController.animateTo(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildPanelDayTabBar() {
    if (_dayTabController == null) return const SizedBox(height: 46);
    return _buildCustomDayTabBar(compact: true);
  }

  /// Custom scrollable day tab bar that avoids TabBar(isScrollable:true)'s
  /// unbounded-width bug. Uses a plain SingleChildScrollView + Row so we
  /// fully control width constraints — no infinity propagation.
  /// [trailing] is optional (e.g. mode switcher icons); shown at the end of the row.
  Widget _buildCustomDayTabBar({required bool compact, Widget? trailing}) {
    final length = _dayTabController?.length ?? 0;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: compact ? Colors.grey.shade100 : Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(length, (i) {
            final isSelected = _selectedDay == i + 1;
            return GestureDetector(
              onTap: () {
                _dayTabController?.animateTo(i);
                _onDayTabChanged(i + 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'Day ${i + 1}',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF1B4332) : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// Shared waypoint list for desktop and mobile panel. Pass [scrollController] from
  /// DraggableScrollableSheet on mobile so list scroll and panel drag don't fight.
  /// Groups by order; choice groups (same choiceGroupId) shown as one section with up/down/ungroup.
  Widget _buildWaypointListContent(
    List<RouteWaypoint> waypoints,
    bool isBuilder, {
    ScrollController? scrollController,
  }) {
    if (waypoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No waypoints for Day $_selectedDay',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (isBuilder) ...[
              const SizedBox(height: 8),
              Text(
                'Create a route to add waypoints',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    final grouped = <int, List<RouteWaypoint>>{};
    for (final w in waypoints) {
      final o = w.order ?? 0;
      grouped.putIfAbsent(o, () => []).add(w);
    }
    final orders = grouped.keys.toList()..sort();
    final version = isBuilder && _formState != null ? _formState!.activeVersion : null;
    final dayNum = _selectedDay;

    final children = <Widget>[];
    for (int i = 0; i < orders.length; i++) {
      final order = orders[i];
      final waypointsAtOrder = grouped[order]!;
      final firstWp = waypointsAtOrder.first;
      final isChoiceGroup = firstWp.choiceGroupId != null && waypointsAtOrder.length > 1;
      final canMoveUp = isBuilder && i > 0 && version != null;
      final canMoveDown = isBuilder && i < orders.length - 1 && version != null;

      if (isChoiceGroup) {
        final v = version;
        children.add(
          _buildChoiceGroupRow(
            waypointsAtOrder: waypointsAtOrder,
            isBuilder: isBuilder,
            version: version,
            dayNum: dayNum,
            onMoveUp: canMoveUp && v != null ? () => _moveWaypointUp(dayNum, firstWp, v) : null,
            onMoveDown: canMoveDown && v != null ? () => _moveWaypointDown(dayNum, firstWp, v) : null,
            onUngroup: (firstWp.choiceGroupId != null && v != null)
                ? () => _ungroupChoiceGroup(dayNum, firstWp.choiceGroupId!, v)
                : null,
          ),
        );
      } else {
        for (final wp in waypointsAtOrder) {
          final availableForLink = isBuilder &&
              version != null &&
              waypoints.any((other) =>
                  other.id != wp.id &&
                  (wp.choiceGroupId == null || other.choiceGroupId != wp.choiceGroupId));
          children.add(
            _buildWaypointCard(
              wp,
              waypoints.indexOf(wp),
              isBuilder,
              onMoveUp: canMoveUp ? () => _moveWaypointUp(dayNum, wp, version) : null,
              onMoveDown: canMoveDown ? () => _moveWaypointDown(dayNum, wp, version) : null,
              onEdit: isBuilder && version != null ? () => _editWaypoint(dayNum, wp, version) : null,
              onDelete: isBuilder && version != null ? () => _deleteWaypoint(dayNum, wp, version) : null,
              onLinkAsOr: availableForLink ? () => _showLinkAsOrDialog(dayNum, wp, version, waypoints) : null,
            ),
          );
        }
      }
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: children,
    );
  }

  /// One row for a choice group: label, list of waypoints, ungroup and reorder actions.
  Widget _buildChoiceGroupRow({
    required List<RouteWaypoint> waypointsAtOrder,
    required bool isBuilder,
    required VersionFormState? version,
    required int dayNum,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    VoidCallback? onUngroup,
  }) {
    final firstWp = waypointsAtOrder.first;
    final label = firstWp.choiceLabel ?? 'Choose an option';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label (choose one)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D21),
                    ),
                  ),
                ),
                if (isBuilder) ...[
                  if (onMoveUp != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: onMoveUp,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onMoveDown != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      onPressed: onMoveDown,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onUngroup != null)
                    IconButton(
                      icon: const Icon(Icons.link_off, size: 18),
                      tooltip: 'Ungroup',
                      onPressed: onUngroup,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ...waypointsAtOrder.map((wp) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: getWaypointColor(wp.type).withValues(alpha: 0.2),
                        child: Icon(getWaypointIcon(wp.type), size: 16, color: getWaypointColor(wp.type)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wp.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBuilder && version != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editWaypoint(dayNum, wp, version),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Show dialog to pick a waypoint to link as OR with [sourceWaypoint].
  Future<void> _showLinkAsOrDialog(
    int dayNum,
    RouteWaypoint sourceWaypoint,
    VersionFormState version,
    List<RouteWaypoint> allWaypoints,
  ) async {
    final inSourceGroup = sourceWaypoint.choiceGroupId != null
        ? getWaypointsInChoiceGroup(allWaypoints, sourceWaypoint.choiceGroupId!)
        : <RouteWaypoint>[];
    final sourceGroupIds = inSourceGroup.map((w) => w.id).toSet();
    final available = allWaypoints
        .where((w) => w.id != sourceWaypoint.id && !sourceGroupIds.contains(w.id))
        .toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other waypoints to link with')),
        );
      }
      return;
    }
    final selected = await showDialog<RouteWaypoint>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link as OR with'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: available.map((wp) => ListTile(
                  leading: Icon(getWaypointIcon(wp.type), color: getWaypointColor(wp.type), size: 22),
                  title: Text(wp.name),
                  onTap: () => Navigator.of(context).pop(wp),
                )).toList(),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _linkWaypointsAsChoice(dayNum, sourceWaypoint, selected, version);
    }
  }
  
  /// Build main itinerary content (map + waypoints).
  /// Uses _selectedDay by default, or can specify a day number.
  /// TODO: Kept for potential desktop 50/50 or other layouts; main itinerary tab now uses
  /// collapsible CustomScrollView in _buildItineraryTab(). Callers: none currently.
  Widget _buildItineraryContent([int? dayNum]) {
    final day = dayNum ?? _selectedDay;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = WaypointBreakpoints.isDesktop(screenWidth);
    
    if (widget.mode == AdventureMode.builder && _formState != null) {
      return _buildBuilderItineraryContentForDay(day, isDesktop);
    } else if (_adventureData != null) {
      return _buildViewerItineraryContentForDay(day, isDesktop);
    }
    
    return const Center(child: Text('No itinerary data available'));
  }
  
  /// Build builder mode itinerary content for a specific day
  Widget _buildBuilderItineraryContentForDay(int dayNum, bool isDesktop) {
    final version = _formState!.activeVersion;
    final dayState = version.getDayState(dayNum);
    final route = dayState.route;
    
    // Get waypoints from route, sorted by order
    final waypoints = <RouteWaypoint>[];
    if (route != null && route.poiWaypoints.isNotEmpty) {
      waypoints.addAll(
        route.poiWaypoints
            .map((json) => RouteWaypoint.fromJson(json))
            .where((w) => w.type != WaypointType.routePoint)
            .toList(),
      );
      waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    }
    
    return _buildItineraryLayout(
      waypoints: waypoints,
      mapBuilder: () => _buildItineraryMap(route, dayNum, version),
      isDesktop: isDesktop,
      isBuilder: true,
    );
  }
  
  /// Build viewer mode itinerary content for a specific day
  Widget _buildViewerItineraryContentForDay(int dayNum, bool isDesktop) {
    if (dayNum > _adventureData!.days.length) {
      return const Center(child: Text('Day not found'));
    }
    
    final day = _adventureData!.days[dayNum - 1];
    final route = day.route;
    
    // Get waypoints from route
    final waypoints = <RouteWaypoint>[];
    if (route != null && route.poiWaypoints.isNotEmpty) {
      waypoints.addAll(
        route.poiWaypoints
            .map((json) => RouteWaypoint.fromJson(json))
            .where((w) => w.type != WaypointType.routePoint)
            .toList(),
      );
      waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    }
    
    return _buildItineraryLayout(
      waypoints: waypoints,
      mapBuilder: () => _buildViewerDayMap(day),
      isDesktop: isDesktop,
      isBuilder: false,
    );
  }
  
  /// Unified itinerary layout (desktop 50/50 or mobile stacked with _mapVisible toggle).
  /// Handles both builder and viewer modes. Kept for potential reuse; main itinerary tab
  /// now uses collapsible CustomScrollView. Uses _mapVisible (vestigial for itinerary tab).
  Widget _buildItineraryLayout({
    required List<RouteWaypoint> waypoints,
    required Widget Function() mapBuilder,
    required bool isDesktop,
    required bool isBuilder,
  }) {
    if (isDesktop && _mapVisible) {
      // Desktop: 50/50 split with toggle
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map section (toggleable)
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: mapBuilder(),
            ),
          ),
          // Waypoints section
          Expanded(
            flex: 1,
            child: _buildWaypointsList(waypoints, isBuilder: isBuilder),
          ),
        ],
      );
    } else if (!isDesktop && _mapVisible) {
      // Mobile: Stacked with toggle
      return Column(
        children: [
          // Map (toggleable) - fixed height, not MediaQuery fraction
          SizedBox(
            height: 280,
            child: mapBuilder(),
          ),
          // Waypoints
          Expanded(
            child: _buildWaypointsList(waypoints, isBuilder: isBuilder),
          ),
        ],
      );
    } else {
      // Map hidden - full waypoints
      return _buildWaypointsList(waypoints, isBuilder: isBuilder);
    }
  }
  
  
  /// Build waypoints list (chronological, no categories).
  /// Used by _buildItineraryLayout (legacy desktop/mobile layouts).
  Widget _buildWaypointsList(
    List<RouteWaypoint> waypoints, {
    required bool isBuilder,
  }) {
    if (waypoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No waypoints yet',
              style: WaypointTypography.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            if (isBuilder) ...[
              const SizedBox(height: 8),
              Text(
                'Add waypoints by editing the route',
                style: WaypointTypography.bodySmall.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: waypoints.length,
      itemBuilder: (context, index) {
        final waypoint = waypoints[index];
        return _buildWaypointCard(waypoint, index, isBuilder);
      },
    );
  }
  
  /// Build individual waypoint card with optional reorder and menu actions.
  Widget _buildWaypointCard(
    RouteWaypoint waypoint,
    int index,
    bool isBuilder, {
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onLinkAsOr,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getWaypointColor(waypoint.type).withOpacity(0.2),
          child: Icon(
            getWaypointIcon(waypoint.type),
            color: getWaypointColor(waypoint.type),
            size: 20,
          ),
        ),
        title: Text(
          waypoint.name,
          style: WaypointTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: waypoint.description != null && waypoint.description!.isNotEmpty
            ? Text(waypoint.description!)
            : null,
        trailing: isBuilder && (onMoveUp != null || onMoveDown != null || onEdit != null || onDelete != null || onLinkAsOr != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMoveUp != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: onMoveUp,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onMoveDown != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      onPressed: onMoveDown,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) onEdit();
                      if (value == 'delete' && onDelete != null) onDelete();
                      if (value == 'link_as_or' && onLinkAsOr != null) onLinkAsOr();
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                      if (onDelete != null)
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Delete')])),
                      if (onLinkAsOr != null)
                        const PopupMenuItem(value: 'link_as_or', child: Row(children: [Icon(Icons.link, size: 18), SizedBox(width: 8), Text('Link as OR with...')])),
                    ],
                  ),
                ],
              )
            : (isBuilder
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  )
                : null),
      ),
    );
  }
  
  /// Build viewer day map.
  /// [mapHeight] when set (e.g. from SliverAppBar) sizes the map to fill the sliver; otherwise 300.
  Widget _buildViewerDayMap(DayItinerary day, {double? mapHeight}) {
    final route = day.route;
    
    // Count waypoints from route
    int waypointCount = 0;
    if (route != null && route.poiWaypoints.isNotEmpty) {
      waypointCount = route.poiWaypoints
          .map((json) {
            try {
              return RouteWaypoint.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<RouteWaypoint>()
          .where((w) => w.type != WaypointType.routePoint)
          .length;
    }
    
    if (route == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: constraints.maxHeight > 0 ? constraints.maxHeight : 400,
            color: Colors.grey.shade100,
            child: Center(
              child: Text(
                'No route for Day ${_selectedDay}',
                style: WaypointTypography.bodyMedium,
              ),
            ),
          );
        },
      );
    }
    
    // Parse route coordinates (same logic as _buildDayRouteMap)
    List<ll.LatLng> routeCoordinates = [];
    if (route.geometry != null) {
      try {
        final coords = route.geometry!['coordinates'];
        if (coords is List && coords.isNotEmpty) {
          if (coords.first is List) {
            routeCoordinates = coords
                .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          }
        }
      } catch (e) {
        Log.e('adventure_detail', 'Failed to parse route coordinates: $e');
      }
    }
    
    // Extract waypoints
    final waypointMaps = route.poiWaypoints;
    final waypoints = waypointMaps
        .map((w) {
          try {
            return RouteWaypoint.fromJson(w);
          } catch (e) {
            return null;
          }
        })
        .whereType<RouteWaypoint>()
        .toList();
    
    // Calculate center
    ll.LatLng center;
    if (waypoints.isNotEmpty) {
      final avgLat = waypoints.map((w) => w.position.latitude).reduce((a, b) => a + b) / waypoints.length;
      final avgLng = waypoints.map((w) => w.position.longitude).reduce((a, b) => a + b) / waypoints.length;
      center = ll.LatLng(avgLat, avgLng);
    } else if (routeCoordinates.isNotEmpty) {
      final avgLat = routeCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / routeCoordinates.length;
      final avgLng = routeCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / routeCoordinates.length;
      center = ll.LatLng(avgLat, avgLng);
    } else {
      // Fallback to default center
      center = _kDefaultCenter;
    }
    
    // Create annotations
    final isGpxRoute = route.routeType == RouteType.gpx;
    final filteredWaypoints = isGpxRoute
        ? waypoints.where((wp) => wp.type != WaypointType.routePoint).toList()
        : waypoints;
    final annotations = filteredWaypoints
        .map((wp) => MapAnnotation.fromWaypoint(wp, onTap: () {}))
        .toList();
    
    // Create polylines
    final polylines = <MapPolyline>[];
    if (isGpxRoute && day.gpxRoute != null && day.gpxRoute!.simplifiedPoints.isNotEmpty) {
      final gpxTrailPoints = day.gpxRoute!.simplifiedPoints
          .map((p) => ll.LatLng(p.latitude, p.longitude))
          .toList();
      polylines.add(MapPolyline(
        id: 'route_${_selectedDay}',
        points: gpxTrailPoints,
        color: const Color(0xFF4CAF50),
        width: 4.0,
      ));
    } else if (routeCoordinates.isNotEmpty) {
      polylines.add(MapPolyline(
        id: 'route_${_selectedDay}',
        points: routeCoordinates,
        color: const Color(0xFF4CAF50),
        width: 4.0,
      ));
    }
    
    final mapConfig = MapConfiguration.mainMap(
      enable3DTerrain: false,
      initialZoom: 12.0,
    );
    
    final height = mapHeight ?? 300.0;
    return SizedBox(
      height: height,
      child: AdaptiveMapWidget(
        key: ValueKey('viewer-day-map-${_selectedDay}-${route.poiWaypoints.length}'),
        initialCenter: center,
        configuration: mapConfig,
        annotations: annotations,
        polylines: polylines,
        onMapCreated: (controller) {
          // Store controller for this day
          _dayMapControllers[_selectedDay] = controller;
          
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_dayMapControllers[_selectedDay] != controller) return;

            // Fit bounds to show all waypoints and route
            final allPoints = <ll.LatLng>[];
            allPoints.addAll(waypoints.map((w) => w.position));
            allPoints.addAll(routeCoordinates);
            
            // Add GPX route points if available
            if (isGpxRoute && day.gpxRoute != null && day.gpxRoute!.simplifiedPoints.isNotEmpty) {
              allPoints.addAll(day.gpxRoute!.simplifiedPoints
                  .map((p) => ll.LatLng(p.latitude, p.longitude))
                  .toList());
            }
            
            if (allPoints.isNotEmpty) {
              _animateCameraToPoints(allPoints, controller);
            }
          });
        },
      ),
    );
  }
  
  /// Returns waypoints for the currently selected day and whether we're in builder mode.
  (List<RouteWaypoint> waypoints, bool isBuilder) _getWaypointsForSelectedDay() {
    if (widget.mode == AdventureMode.builder && _formState != null) {
      final version = _formState!.activeVersion;
      final dayState = version.getDayState(_selectedDay);
      final route = dayState.route;
      final waypoints = <RouteWaypoint>[];
      if (route != null && route.poiWaypoints.isNotEmpty) {
        waypoints.addAll(
          route.poiWaypoints
              .map((json) => RouteWaypoint.fromJson(json))
              .where((w) => w.type != WaypointType.routePoint)
              .toList(),
        );
        waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      }
      return (waypoints, true);
    }
    if (_adventureData != null && _selectedDay <= _adventureData!.days.length) {
      final day = _adventureData!.days[_selectedDay - 1];
      final route = day.route;
      final waypoints = <RouteWaypoint>[];
      if (route != null && route.poiWaypoints.isNotEmpty) {
        waypoints.addAll(
          route.poiWaypoints
              .map((json) => RouteWaypoint.fromJson(json))
              .where((w) => w.type != WaypointType.routePoint)
              .toList(),
        );
        waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      }
      return (waypoints, false);
    }
    return ([], false);
  }
  
  /// Builds the map widget for the selected day (for use in SliverAppBar).
  /// [height] is used in viewer mode to size the map to the expanded sliver height.
  Widget _buildMapForSelectedDay({double? height}) {
    if (widget.mode == AdventureMode.builder && _formState != null) {
      final version = _formState!.activeVersion;
      final dayState = version.getDayState(_selectedDay);
      final route = dayState.route;
      return _buildItineraryMap(route, _selectedDay, version);
    }
    if (_adventureData != null && _selectedDay <= _adventureData!.days.length) {
      final day = _adventureData!.days[_selectedDay - 1];
      return _buildViewerDayMap(day, mapHeight: height);
    }
    return Container(
      height: height ?? 200,
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          'No map for Day $_selectedDay',
          style: WaypointTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
        ),
      ),
    );
  }
  
  /// Build itinerary map (wrapper for _buildDayRouteMap with proper sizing)
  Widget _buildItineraryMap(DayRoute? route, int dayNum, VersionFormState version) {
    // Use Expanded or SizedBox with constraints to ensure proper sizing
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have valid constraints before building
        if (constraints.maxHeight <= 0 || constraints.maxHeight.isInfinite) {
          return const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth > 0 ? constraints.maxWidth : double.infinity,
          child: _buildDayRouteMap(route, dayNum, version),
        );
      },
    );
  }

  // Logo mark — use actual SVG asset or the W glyph
  Widget _buildLogoMark() {
    // On web, skip loading the logo asset to avoid 404 (asset may be missing in web build)
    final logoWidget = kIsWeb
        ? _buildLogoPlaceholder()
        : Image.asset(
            'assets/images/waypoint_logo_mark.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
          );
    return GestureDetector(
      onTap: () => context.go('/explore'),
      child: SizedBox(
        width: 28,
        height: 28,
        child: logoWidget,
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text(
          'W',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Save status indicator (builder mode only)
  Widget _buildSaveStatus() {
    if (widget.mode != AdventureMode.builder || 
        _formState == null || 
        _formState!.editingPlan == null) {
      return const SizedBox.shrink();
    }
    
    return ListenableBuilder(
      listenable: _formState!,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_formState!.isSaving)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6C757D)),
            )
          else
            Icon(
              _formState!.saveStatus == 'Saved'
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              size: 16,
              color: const Color(0xFF6C757D),
            ),
          const SizedBox(width: 6),
          Text(
            _formState!.saveStatus == 'Saved' ? 'Saved' : 'Not saved yet',
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CIRCULAR ICON BUTTON — AllTrails style
  // ============================================================
  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE9ECEF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF212529)),
        ),
      ),
    );
  }

  // ============================================================
  // DIFFICULTY COLOR HELPER
  // ============================================================
  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return const Color(0xFF52B788);
      case 'moderate': return const Color(0xFFFCBF49);
      case 'hard': return const Color(0xFFD62828);
      default: return const Color(0xFF6C757D);
    }
  }

  // ============================================================
  // GET ADVENTURE DATA FOR UI
  // ============================================================
  String get _adventureDisplayName => widget.mode == AdventureMode.builder 
      ? (_formState?.nameCtrl.text.isEmpty ?? true ? 'Untitled Adventure' : _formState!.nameCtrl.text)
      : (_adventureData?.displayName ?? 'Untitled Adventure');

  double get _adventureRating {
    if (widget.mode == AdventureMode.builder) return 0.0;
    return _plan?.reviewStats?.averageRating ?? 0.0;
  }

  int get _adventureReviewCount {
    if (widget.mode == AdventureMode.builder) return 0;
    return _plan?.reviewStats?.totalReviews ?? 0;
  }

  String? get _adventureDifficulty {
    // TODO: Add difficulty field to Plan model if not exists
    // For now return null
    return null;
  }

  String get _adventureLocation {
    if (widget.mode == AdventureMode.builder) {
      return _formState?.locationCtrl.text ?? '';
    }
    return _adventureData?.location ?? '';
  }

  List<String> get _adventureImageUrls {
    // For now, use heroImageUrl as single image
    // TODO: Add imageUrls List<String> to Plan model
    if (widget.mode == AdventureMode.builder) {
      final url = _formState?.heroImageUrlCtrl.text ?? '';
      return url.isNotEmpty ? [url] : [];
    }
    final url = _plan?.heroImageUrl ?? '';
    return url.isNotEmpty ? [url] : [];
  }

  // ============================================================
  // TITLE SECTION — name + stars + review count + difficulty dot
  // ============================================================
  Widget _buildTitleSection(BuildContext context) {
    final rating = _adventureRating;
    final reviewCount = _adventureReviewCount;
    final difficulty = _adventureDifficulty;
    final location = _adventureLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Adventure title — DM Serif Display
        Text(
          _adventureDisplayName,
          style: const TextStyle(
            fontFamily: 'DMSerifDisplay',
            fontSize: 36,
            height: 1.15,
            letterSpacing: -0.5,
            color: Color(0xFF212529),
          ),
        ),

        const SizedBox(height: 10),

        // Stars + review count + difficulty + location
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Star rating
            if (rating > 0 || reviewCount > 0) ...[
              Row(
                children: List.generate(5, (i) => Icon(
                  i < rating.floor()
                      ? Icons.star_rounded
                      : (i < rating
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded),
                  size: 18,
                  color: const Color(0xFFFCBF49),
                )),
              ),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212529),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($reviewCount reviews)',
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1B4332),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF1B4332),
                ),
              ),
            ],

            // Separator dot
            if ((rating > 0 || reviewCount > 0) && (difficulty != null || location.isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ),

            // Difficulty pill
            if (difficulty != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _difficultyColor(difficulty),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                difficulty,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF212529),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Location line — separate from title section
  Widget _buildLocationLine(BuildContext context) {
    final location = _adventureLocation;
    if (location.isEmpty) return const SizedBox.shrink();
    
    return Text(
                location,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1B4332),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF1B4332),
      ),
    );
  }

  // Owner attribution row
  Widget _buildOwnerAttribution(BuildContext context) {
    // Get creator info
    String? creatorId;
    String? creatorName;
    
    if (widget.mode == AdventureMode.builder) {
      if (_formState?.editingPlan != null) {
        creatorId = _formState!.editingPlan!.creatorId;
        creatorName = _formState!.editingPlan!.creatorName;
      } else {
        return const SizedBox.shrink(); // New plan, no creator yet
      }
    } else {
      if (_plan != null) {
        creatorId = _plan!.creatorId;
        creatorName = _plan!.creatorName;
      } else {
        return const SizedBox.shrink();
      }
    }
    
    if (creatorId == null || creatorName?.isEmpty != false) {
      return const SizedBox.shrink();
    }
    
    // Fetch user profile for avatar (cached to avoid duplicate calls)
    // creatorId is guaranteed non-null after the check above
    final nonNullCreatorId = creatorId!;
    final userFuture = _userFutureCache.putIfAbsent(
      nonNullCreatorId,
      () => _userService.getUserById(nonNullCreatorId),
    );
    return FutureBuilder<UserModel?>(
      future: userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final avatarUrl = user?.photoUrl;
        final displayName = user?.displayName ?? creatorName;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: const Color(0xFF1B4332),
                child: avatarUrl == null
                    ? Text(
                        (displayName?.isNotEmpty ?? false)
                            ? displayName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              const Text(
                'By ',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  color: Color(0xFF6C757D),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/profile/$creatorId'),
                child: Text(
                  displayName ?? creatorName ?? '',
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4332),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF1B4332),
                  ),
                ),
              ),
          ],
        ),
        );
      },
    );
  }

  // Price card for sticky sidebar (desktop) or inline (mobile)
  Widget _buildPriceCard(BuildContext context) {
    final price = _getPrice();
    final adventure = widget.mode == AdventureMode.builder
        ? _formState?.editingPlan
        : _plan;
    
    if (adventure == null) return const SizedBox.shrink();
    
    // Compute fields
    final totalDays = widget.mode == AdventureMode.builder
        ? (_formState?.activeVersion.daysCount ?? 0)
        : (adventure.versions.isNotEmpty
            ? adventure.versions.first.durationDays
            : 0);
    
    final totalWaypoints = widget.mode == AdventureMode.builder
        ? (() {
            if (_formState?.activeVersion == null) return 0;
            int sum = 0;
            for (int i = 1; i <= (_formState!.activeVersion.daysCount); i++) {
              final day = _formState!.activeVersion.getDayState(i);
              sum += (day.route?.poiWaypoints.length ?? 0);
            }
            return sum;
          }())
        : (adventure.versions.isNotEmpty
            ? adventure.versions.first.days.fold<int>(
                0, (sum, day) => sum + (day.route?.poiWaypoints.length ?? 0))
            : 0);
    
    final languages = adventure.languages ?? [];
    
    return AdventurePriceCard(
      price: price,
      totalDays: totalDays,
      totalWaypoints: totalWaypoints,
      languages: languages,
      showBuyButton: widget.mode == AdventureMode.viewer,
      onBuyPlan: () {
        // TODO: Navigate to purchase flow
      },
    );
  }

  // Quick stats row ("Ups")
  Widget _buildQuickStats(BuildContext context) {
    final adventure = widget.mode == AdventureMode.builder
        ? _formState?.editingPlan
        : _plan;
    
    if (adventure == null) return const SizedBox.shrink();
    
    final days = widget.mode == AdventureMode.builder
        ? (_formState?.activeVersion.daysCount ?? 0)
        : (adventure.versions.isNotEmpty
            ? adventure.versions.first.durationDays
            : 0);
    
    // Count waypoints by type across all days
    final restaurants = countWaypointsByType(adventure, 'restaurant');
    final activities = countWaypointsByType(adventure, 'activity');
    final stays = countWaypointsByType(adventure, 'accommodation');
    final transport = countWaypointsByType(adventure, 'service');
    
    final languages = adventure.languages ?? [];
    
    return AdventureQuickStats(
      days: days,
      restaurants: restaurants,
      activities: activities,
      stays: stays,
      transport: transport,
      languages: languages,
    );
  }

  // Owner card (detailed view with bio)
  Widget _buildOwnerCard(BuildContext context) {
    final adventure = widget.mode == AdventureMode.builder
        ? _formState?.editingPlan
        : _plan;
    
    if (adventure == null || adventure.creatorId.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Cache the future to avoid duplicate calls
    final userFuture = _userFutureCache.putIfAbsent(
      adventure.creatorId,
      () => _userService.getUserById(adventure.creatorId),
    );
    return FutureBuilder<UserModel?>(
      future: userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final avatarUrl = user?.photoUrl;
        final displayName = user?.displayName ?? adventure.creatorName;
        final shortBio = user?.shortBio;
        
        if (displayName.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ABOUT THE CREATOR',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    backgroundColor: const Color(0xFF1B4332),
                    child: avatarUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                          displayName,
                          style: const TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212529),
                          ),
                        ),
                        if (shortBio?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            shortBio!,
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              color: Color(0xFF6C757D),
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Highlights section
  Widget _buildHighlightsSection(BuildContext context) {
    final adventure = widget.mode == AdventureMode.builder
        ? _formState?.editingPlan
        : _plan;
    
    if (adventure == null) return const SizedBox.shrink();
    
    final highlights = widget.mode == AdventureMode.builder
        ? (_formState?.highlights ?? [])
        : (adventure.highlights ?? []);
    
    final isEditable = widget.mode == AdventureMode.builder;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Highlights',
              style: TextStyle(
                fontFamily: 'DMSerifDisplay',
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: Color(0xFF212529),
              ),
            ),
            if (isEditable && highlights.length < 10)
              TextButton.icon(
                onPressed: () {
                  _formState?.addHighlight('');
                  setState(() {});
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1B4332),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (highlights.isEmpty && !isEditable)
          const Text(
            'No highlights yet',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
          )
        else if (highlights.isEmpty && isEditable)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: const Text(
              'Add highlights to showcase what makes this adventure special',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: Color(0xFF6C757D),
              ),
            ),
          )
        else
          ...highlights.asMap().entries.map((entry) {
            final index = entry.key;
            final highlight = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF1B4332),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isEditable
                        ? _buildInlineHighlightEditor(index, highlight)
                        : Text(
                            highlight,
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              color: Color(0xFF212529),
                            ),
                          ),
                  ),
                  if (isEditable) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: const Color(0xFFD62828),
                      onPressed: () {
                        // Dispose controller before removing highlight
                        _highlightControllers[index]?.dispose();
                        _highlightControllers.remove(index);
                        // Rebuild map by re-keying all entries with indices > index
                        final rebuilt = <int, TextEditingController>{};
                        for (final entry in _highlightControllers.entries) {
                          if (entry.key < index) {
                            rebuilt[entry.key] = entry.value;
                          } else if (entry.key > index) {
                            rebuilt[entry.key - 1] = entry.value;
                          }
                          // entry.key == index was already disposed and skipped
                        }
                        _highlightControllers
                          ..clear()
                          ..addAll(rebuilt);
                        _formState?.removeHighlight(index);
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInlineHighlightEditor(int index, String value) {
    // Reuse or create controller — never leak
    final ctrl = _highlightControllers.putIfAbsent(
      index,
      () => TextEditingController(),
    );
    // Only update text if it differs (avoid cursor jump)
    if (ctrl.text != value) {
      ctrl.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    final highlightsLength = _formState?.highlights.length ?? 0;
    return TextField(
      controller: ctrl,
      autofocus: value.isEmpty && index == highlightsLength - 1,
      maxLength: 150,
      style: const TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        color: Color(0xFF212529),
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      ),
      onChanged: (newValue) {
        _formState?.updateHighlight(index, newValue);
      },
      onSubmitted: (_) {
        if (index == (_formState?.highlights.length ?? 0) - 1) {
          _formState?.addHighlight('');
          setState(() {});
        }
      },
    );
  }
  
  Widget _buildFAQItem(FAQItem faq) {
    return ExpansionTile(
      title: Text(faq.question),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            faq.answer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPrepareTab() {
    if (_adventureData == null) return const SizedBox.shrink();
    
    return _buildScrollTab([
            // Version selector if multiple versions
            if (_availableVersions.length > 1)
              VersionSelectorBar.fromPlanVersions(
                versions: _availableVersions,
                activeIndex: _selectedVersionIndex,
                onChanged: _onVersionChanged,
              ),
            
            // Prepare content
          if (_adventureData!.prepare != null)
            _buildPrepareContent(_adventureData!.prepare!),
          
          // Packing section
          if (_adventureData!.selectedVersion?.packingCategories.isNotEmpty ?? false)
            SectionCard(
              title: 'What to bring',
              icon: Icons.backpack,
              children: _hasPurchased == false
                  ? _adventureData!.selectedVersion!.packingCategories.take(2).expand((category) {
                      return category.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20, color: WaypointColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.name)),
                          ],
                        ),
                      ));
                    }).toList()
                      + [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Unlock to see all packing items',
                              style: WaypointTypography.bodyMedium.copyWith(
                                color: WaypointColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ]
                  : [
                      // TODO: Display all packing categories
                      Text('Packing categories will be displayed here'),
                    ],
            ),
          
          // Transportation section (hidden in limited preview)
          if (_hasPurchased != false && (_adventureData!.selectedVersion?.transportationOptions.isNotEmpty ?? false))
            SectionCard(
              title: 'Transportation',
              icon: Icons.directions_car,
              children: [
                // TODO: Display transportation options
                Text('Transportation options will be displayed here'),
              ],
            ),
          
          // Unlock banner for non-purchased plans
          if (_hasPurchased == false) _buildUnlockBanner(customMessage: 'Unlock to see full prepare guide'),
    ]);
  }
  
  Widget _buildPrepareContent(Prepare prepare) {
    final isLimited = _hasPurchased == false;
    
    return Column(
      children: [
        if (prepare.travelInsurance != null)
          SectionCard(
            title: 'Travel Insurance',
            icon: Icons.health_and_safety,
            children: [
              InlineEditableField(
                label: 'Recommendation',
                displayValue: isLimited && prepare.travelInsurance!.recommendation.length > 150
                    ? '${prepare.travelInsurance!.recommendation.substring(0, 150)}...'
                    : prepare.travelInsurance!.recommendation,
              ),
            ],
          ),
        if (prepare.visa != null)
          SectionCard(
            title: 'Visa',
            icon: Icons.description,
            children: [
              InlineEditableField(
                label: 'Requirement',
                displayValue: prepare.visa!.requirement,
              ),
              if (prepare.visa!.note != null)
                InlineEditableField(
                  label: 'Note',
                  displayValue: prepare.visa!.note!,
                ),
            ],
          ),
        if (prepare.passport != null)
          SectionCard(
            title: 'Passport',
            icon: Icons.credit_card,
            children: [
              InlineEditableField(
                label: 'Validity Requirement',
                displayValue: prepare.passport!.validityRequirement,
              ),
              InlineEditableField(
                label: 'Blank Pages Required',
                displayValue: prepare.passport!.blankPagesRequired,
              ),
            ],
          ),
        if (prepare.permits.isNotEmpty)
          SectionCard(
            title: 'Permits',
            icon: Icons.assignment,
            children: prepare.permits.map((permit) => InlineEditableField(
              label: permit.type,
              displayValue: permit.details,
              maxLines: 3,
            )).toList(),
          ),
        if (prepare.vaccines != null)
          SectionCard(
            title: 'Vaccines',
            icon: Icons.medical_services,
            children: [
              if (prepare.vaccines!.required.isNotEmpty)
                InlineEditableField(
                  label: 'Required',
                  displayValue: prepare.vaccines!.required.join(', '),
                ),
              if (prepare.vaccines!.recommended.isNotEmpty)
                InlineEditableField(
                  label: 'Recommended',
                  displayValue: prepare.vaccines!.recommended.join(', '),
                ),
              if (prepare.vaccines!.note != null)
                InlineEditableField(
                  label: 'Note',
                  displayValue: prepare.vaccines!.note!,
                ),
            ],
          ),
        if (prepare.climate != null)
          SectionCard(
            title: 'Climate',
            icon: Icons.wb_sunny,
            children: [
              InlineEditableField(
                label: 'Location',
                displayValue: prepare.climate!.location,
              ),
              // TODO: Display climate data (monthly averages)
            ],
          ),
      ],
    );
  }
  
  Widget _buildLocalTipsTab() {
    if (_adventureData == null) return const SizedBox.shrink();
    
    return _buildScrollTab([
            // Version selector if multiple versions
            if (_availableVersions.length > 1)
              VersionSelectorBar.fromPlanVersions(
                versions: _availableVersions,
                activeIndex: _selectedVersionIndex,
                onChanged: _onVersionChanged,
              ),
            
            // Local tips content
          if (_adventureData!.localTips != null) ...[
            // Food Specialties (limited preview: first 2, name only)
            if (_adventureData!.localTips!.foodSpecialties.isNotEmpty)
              SectionCard(
                title: 'Food Specialties',
                icon: Icons.restaurant,
                children: _hasPurchased == false
                    ? _adventureData!.localTips!.foodSpecialties.take(2).map((specialty) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          specialty.name,
                          style: WaypointTypography.bodyMedium,
                        ),
                      )).toList()
                      + [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Unlock to see all food specialties with descriptions',
                              style: WaypointTypography.bodyMedium.copyWith(
                                color: WaypointColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ]
                    : _adventureData!.localTips!.foodSpecialties.map((specialty) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              specialty.name,
                              style: WaypointTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (specialty.description != null && specialty.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  specialty.description!,
                                  style: WaypointTypography.bodyMedium.copyWith(
                                    color: WaypointColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )).toList(),
              ),
            
            // Cultural Tips (etiquette - limited preview: first 150 chars)
            if (_adventureData!.localTips!.etiquette.isNotEmpty)
              SectionCard(
                title: 'Cultural Tips',
                icon: Icons.people,
                children: [
                  InlineEditableField(
                    label: 'Etiquette',
                    displayValue: _hasPurchased == false
                        ? _adventureData!.localTips!.etiquette.join(' ').length > 150
                            ? '${_adventureData!.localTips!.etiquette.join(' ').substring(0, 150)}...'
                            : _adventureData!.localTips!.etiquette.join(' ')
                        : _adventureData!.localTips!.etiquette.join(' '),
                    maxLines: _hasPurchased == false ? 3 : 5,
                  ),
                ],
              ),
            
            // Other sections (language, currency, etc.) - hidden in limited preview
            if (_hasPurchased != false) ...[
              // TODO: Add other local tips sections when not in limited preview
            ],
          ],
          
          // Unlock banner for non-purchased plans
          if (_hasPurchased == false) _buildUnlockBanner(customMessage: 'Unlock to see all local tips'),
    ]);
  }
  
  Widget _buildDayTab(int dayIndex) {
    if (_adventureData == null || dayIndex >= _adventureData!.days.length) {
      return const Center(child: Text('Day not found'));
    }
    
    final day = _adventureData!.days[dayIndex];
    final isLimited = _hasPurchased == false;
    
    // Get waypoints from route
    final waypoints = <RouteWaypoint>[];
    if (day.route != null && day.route!.poiWaypoints.isNotEmpty) {
      waypoints.addAll(
        day.route!.poiWaypoints
            .map((json) => RouteWaypoint.fromJson(json))
            .where((w) => w.type != WaypointType.routePoint)
            .toList(),
      );
      // Sort by order
      waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    }
    
    return _buildScrollTab([
      const SizedBox(height: 20), // Consistent 20px spacing
      SectionCard(
        title: 'Day ${dayIndex + 1}',
        icon: Icons.calendar_today,
        children: [
              if (day.title.isNotEmpty)
                InlineEditableField(
                  label: 'Title',
                  displayValue: day.title,
                ),
              if (day.description.isNotEmpty)
                InlineEditableField(
                  label: 'Description',
                  displayValue: isLimited && day.description.length > 100
                      ? '${day.description.substring(0, 100)}...'
                      : day.description,
                  maxLines: isLimited ? 3 : 5,
                ),
              
              // Waypoints (limited preview: first 3, name and type only)
              if (waypoints.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Waypoints',
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...(isLimited ? waypoints.take(3) : waypoints).map((waypoint) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        getWaypointIcon(waypoint.type),
                        size: 20,
                        color: getWaypointColor(waypoint.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          waypoint.name,
                          style: WaypointTypography.bodyMedium,
                        ),
                      ),
                      if (isLimited && waypoints.indexOf(waypoint) == 2 && waypoints.length > 3)
                        Text(
                          '...',
                          style: WaypointTypography.bodyMedium.copyWith(
                            color: WaypointColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                )).toList(),
                if (isLimited && waypoints.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Unlock to see all ${waypoints.length} waypoints',
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: WaypointColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              
              // Route/map hidden in limited preview
              if (!isLimited) ...[
                // TODO: Add route info, map, etc. when not in limited preview
              ],
            ],
          ),
      
      // Unlock banner for non-purchased plans
      if (isLimited) _buildUnlockBanner(customMessage: 'Unlock to see full itinerary'),
    ]);
  }

  Widget _buildCommentsTab() {
    String? planId;
    String? creatorId;

    if (widget.mode == AdventureMode.builder) {
      planId = _formState?.editingPlan?.id;
      creatorId = _formState?.editingPlan?.creatorId;
    } else if (widget.mode == AdventureMode.viewer) {
      planId = widget.planId;
      creatorId = _plan?.creatorId;
    } else if (widget.mode == AdventureMode.trip) {
      planId = _plan?.id;
      creatorId = _plan?.creatorId;
    }

    if (planId == null) {
      return const Center(child: Text('Plan not available'));
    }

    return CommentsTab(
      planId: planId,
      creatorId: creatorId,
      commentService: _commentService,
    );
  }
  
  @override
  @override
  void dispose() {
    // Restore original error handler to prevent leaking error suppression
    if (_originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
    }
    
    // Remove LocalTips listeners to prevent memory leaks
    if (_formState != null && _formState!.versions.isNotEmpty) {
      final version = _formState!.activeVersion;
      for (final listener in _localTipsListeners) {
        try {
          // Remove listener from all controllers
          version.localTipsGeneralEmergencyCtrl.removeListener(listener);
          version.localTipsEmergencyPoliceCtrl.removeListener(listener);
          version.localTipsEmergencyAmbulanceCtrl.removeListener(listener);
          version.localTipsEmergencyFireCtrl.removeListener(listener);
          version.localTipsEmergencyTouristCtrl.removeListener(listener);
          version.localTipsMessagingAppNameCtrl.removeListener(listener);
          version.localTipsMessagingAppNoteCtrl.removeListener(listener);
          version.localTipsTippingPracticeCtrl.removeListener(listener);
          version.localTipsTippingRestaurantCtrl.removeListener(listener);
          version.localTipsTippingTaxiCtrl.removeListener(listener);
          version.localTipsTippingHotelCtrl.removeListener(listener);
        } catch (e) {
          Log.w('adventure_detail', 'Error removing LocalTips listener: $e');
        }
      }
      _localTipsListeners.clear();
      // Reset the flag so listeners can be reattached if needed
      version.resetLocalTipsListenersAttached();
    }
    
    // Clear SEO when leaving page (for navigation)
    if (kIsWeb) {
      SeoService.clearSeoMetaTags();
    }
    
    
    _locationSearchTimer?.cancel();
    
    // Safely remove listeners (defensive for hot reload)
    try {
    _formState?.removeListener(_onFormStateChanged);
    _formState?.locationCtrl.removeListener(_onLocationQueryChanged);
    } catch (e) {
      Log.w('adventure_detail', 'Error removing form state listeners: $e');
    }
    
    // Clear map controller references (controllers are disposed by AdaptiveMapWidget)
    _dayMapControllers.clear();
    
    // Clear user future cache
    _userFutureCache.clear();
    
    // Tab controller removed - no longer needed with drawer navigation
    
    // Clean up duration listener (defensive for hot reload)
    if (_durationListener != null) {
      try {
        if (_formState != null && _formState!.versions.isNotEmpty) {
          _formState!.activeVersion.durationCtrl.removeListener(_durationListener!);
        }
      } catch (e) {
        Log.w('adventure_detail', 'Error removing duration listener: $e');
      }
      _durationListener = null;
    }
    
    // Dispose highlight controllers (defensive for hot reload)
    for (final ctrl in _highlightControllers.values) {
      try {
      ctrl.dispose();
      } catch (e) {
        Log.w('adventure_detail', 'Error disposing highlight controller: $e');
      }
    }
    _highlightControllers.clear();
    
    // Dispose form state if it exists (defensive for hot reload)
    try {
    _formState?.dispose();
    } catch (e) {
      Log.w('adventure_detail', 'Error disposing form state: $e');
    }
    
    _draggableController.dispose();
    _dayTabController?.dispose();
    _dayTabController = null;
    
    super.dispose();
  }
  
}

// ============================================================
// FULLSCREEN GALLERY DIALOG
// ============================================================
/// Hero image hover overlay widget
/// Shows camera icon on hover for editing the hero image
class _HeroImageHoverOverlay extends StatefulWidget {
  final VoidCallback onTap;
  
  const _HeroImageHoverOverlay({required this.onTap});
  
  @override
  State<_HeroImageHoverOverlay> createState() => _HeroImageHoverOverlayState();
}

class _HeroImageHoverOverlayState extends State<_HeroImageHoverOverlay> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _isHovering ? Colors.black.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(WaypointSpacing.cardRadiusLg),
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: _isHovering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Summary card widget for Review tab
class _ReviewSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final VoidCallback onEdit;
  final bool isComplete;
  final Widget child;

  const _ReviewSummaryCard({
    required this.icon,
    required this.title,
    this.badge,
    required this.onEdit,
    required this.isComplete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: WaypointColors.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: WaypointTypography.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: onEdit,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Edit'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: WaypointColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),

          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isComplete
                  ? WaypointColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFFFF8E1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: isComplete
                      ? WaypointColors.primary
                      : const Color(0xFFF9A825),
                ),
                const SizedBox(width: 6),
                Text(
                  isComplete ? 'Complete' : 'Incomplete',
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isComplete
                        ? WaypointColors.primary
                        : const Color(0xFFF57F17),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

