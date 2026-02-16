import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:waypoint/integrations/mapbox_service.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/services/poi_service.dart';
import 'package:waypoint/presentation/widgets/elevation_chart.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/utils/google_link_parser.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/components.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/map_feature_flags.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/components/widgets/scroll_blocking_dialog.dart';
import 'package:waypoint/components/day_content_builder.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:waypoint/models/orderable_item.dart';
import 'package:waypoint/components/reorder_controls.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/components/builder/sequential_waypoint_list.dart';
import 'package:waypoint/services/waypoint_grouping_service.dart';
import 'package:waypoint/services/travel_calculator_service.dart';
import 'package:waypoint/services/gpx_waypoint_snapper.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/utils/haversine_utils.dart';
import 'package:waypoint/utils/activity_utils.dart';
import 'package:waypoint/integrations/google_directions_service.dart';

/// Unified item type for sidebar reorderable list
/// Can be either a category group or an individual service/viewing point
class _SidebarItem {
  final String id;
  final bool isCategory;
  final TimeSlotCategory? category; // Category for section items
  final RouteWaypoint? waypoint;
  
  _SidebarItem.category(TimeSlotCategory cat)
      : id = 'category_${cat.name}',
        isCategory = true,
        category = cat,
        waypoint = null;
        
  _SidebarItem.waypoint(RouteWaypoint wp)
      : id = 'waypoint_${wp.id}',
        isCategory = false,
        category = null,
        waypoint = wp;
}

/// Full-page route builder screen
class RouteBuilderScreen extends StatefulWidget {
final String planId;
final String versionIndex;
final String dayNum;
final ll.LatLng? start;
final ll.LatLng? end;
final DayRoute? initial;
final ActivityCategory? activityCategory;
final ll.LatLng? location; // Location from step 1 (General Info)

const RouteBuilderScreen({
super.key,
required this.planId,
required this.versionIndex,
required this.dayNum,
this.start,
this.end,
this.initial,
this.activityCategory,
this.location,
});

@override
State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
// FlutterMap controller for web-based map
final fm.MapController _map = fm.MapController();
final _svc = MapboxService();
final _googlePlacesService = GooglePlacesService();
final _searchController = TextEditingController();
final _searchFocusNode = FocusNode();
final _sidebarSearchController = TextEditingController();
final _sidebarSearchFocusNode = FocusNode();
Timer? _searchDebounce;
Timer? _sidebarSearchDebounce;
// Legacy: snapToTrail removed
bool _busy = false;
bool _searching = false;
bool _sidebarSearching = false;
bool _isProgrammaticCameraMove = false; // Track programmatic camera moves to prevent map tap pop-up
bool _dialogOrBottomSheetOpen = false; // Track when dialogs/bottom sheets are open to prevent map taps
Map<String, dynamic>? _previewGeometry; // Legacy - kept for backward compatibility
List<Map<String, dynamic>>? _previewRouteSegments; // Per-segment routes with travel modes
double? _previewDistance;
int? _previewDuration;
List<ElevationPoint> _previewElevation = const [];
double? _previewAscent;
double? _previewDescent;
List<PlaceSuggestion> _searchResults = [];
List<PlaceSuggestion> _sidebarSearchResults = [];

// POI waypoints
final List<RouteWaypoint> _poiWaypoints = [];
bool _waypointsExpanded = true;
bool _hintDismissed = false;

// Day plan ordering (using day 1 for route builder)
DayPlanOrderManager? _routeOrderManager;

// OSM POIs
List<POI> _osmPOIs = [];
bool _loadingPOIs = false;
Timer? _poiDebounce;
ll.LatLng? _lastPOICenter;
double? _lastPOIZoom;

// Camera state for Mapbox mode (flutter_map uses _map.camera instead)
ll.LatLng? _currentCameraCenter;
double? _currentCameraZoom;

// Mapbox controller reference for camera commands
WaypointMapController? _mapboxController;

// Track if this is a GPX route (for conditional logic)
bool _isGpxRoute = false;

@override
void initState() {
super.initState();
Log.i('route_builder', 'RouteBuilderScreen init');
if (MapFeatureFlags.useLegacyEditor) {
  Log.i('route_builder', '🗺️ Using LEGACY flutter_map editor (feature flag enabled)');
} else if (MapFeatureFlags.useMapboxEverywhere) {
  Log.i('route_builder', '🗺️ Using NEW Mapbox editor (AdaptiveMapWidget)');
} else {
  Log.i('route_builder', '🗺️ Using flutter_map with raster tiles');
}
Log.i('route_builder', '🗺️ Tile URL: $defaultRasterTileUrl');

// Initialize camera state for Mapbox mode synchronously (Issue #5 fix - set earlier)
if (!MapFeatureFlags.useLegacyEditor && MapFeatureFlags.useMapboxEverywhere) {
  // Use location from step 1 if available, otherwise default to world map
  if (widget.location != null) {
    _currentCameraCenter = widget.location!;
    _currentCameraZoom = 10.0; // Reasonable zoom for a location
    Log.i('route_builder', '📍 Initial camera set to location from step 1: $_currentCameraCenter @ zoom $_currentCameraZoom');
  } else {
    // Default to world map if no waypoints exist
    _currentCameraZoom = 2.5;
    _currentCameraCenter = const ll.LatLng(0.0, 0.0);
    Log.i('route_builder', '📍 Initial camera set to world map: $_currentCameraCenter @ zoom $_currentCameraZoom');
  }
}

WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) {
// Check if we have waypoints to display
final hasWaypoints = _poiWaypoints.isNotEmpty || widget.initial != null;

if (hasWaypoints) {
  // Fit map to show all waypoints when editing existing route
  _fitToWaypoints();
  // LEGACY: OSM POI loading disabled - removed POI loading after fitting waypoints
} else {
  // No waypoints - use location from step 1 if available, otherwise show world map
  if (widget.location != null) {
    _moveCamera(widget.location!, 10.0);
    Log.i('route_builder', '📍 Showing location from step 1: ${widget.location}');
  } else if (!MapFeatureFlags.useLegacyEditor && MapFeatureFlags.useMapboxEverywhere) {
    if (_mapboxController != null) {
      _mapboxController!.animateCamera(const ll.LatLng(0.0, 0.0), 2.5);
      Log.i('route_builder', '📍 Showing world map (no waypoints)');
    }
  }
  // Don't load POIs yet, wait for user to search
  Log.i('route_builder', '📍 New route - POIs will load after user searches for a location');
}
}
});
try {
if (widget.initial != null) {
_previewGeometry = widget.initial!.geometry;
_previewDistance = widget.initial!.distance;
_previewDuration = widget.initial!.duration;
// Convert legacy route points to waypoints for backward compatibility
// BUT: Skip this for GPX routes - GPX geometry is the trail itself, not user-placed waypoints
// Defensive check: Also detect GPX routes even if routeType is missing (routePoints empty + many geometry points)
_isGpxRoute = widget.initial!.routeType == RouteType.gpx ||
    (widget.initial!.routeType == null &&
     widget.initial!.routePoints.isEmpty &&
     widget.initial!.geometry['coordinates'] is List &&
     (widget.initial!.geometry['coordinates'] as List).length > 100);

if (!_isGpxRoute && widget.initial!.routePoints.isNotEmpty) {
final convertedWaypoints = widget.initial!.routePoints.asMap().entries.map((entry) {
final index = entry.key;
final point = entry.value;
final waypoint = RouteWaypoint(
type: WaypointType.routePoint,
position: ll.LatLng(point['lat']!, point['lng']!),
name: index == 0 ? 'Start' : (index == widget.initial!.routePoints.length - 1 ? 'End' : 'Route Point ${index + 1}'),
order: index,
);
// Auto-assign time slot category if not set
final autoCategory = autoAssignTimeSlotCategory(waypoint);
return waypoint.copyWith(timeSlotCategory: autoCategory);
}).toList();
_poiWaypoints.addAll(convertedWaypoints);
Log.i('route_builder', '🔄 Converted ${convertedWaypoints.length} route points to waypoints for backward compatibility');
} else if (_isGpxRoute) {
Log.i('route_builder', '📍 GPX route detected (routeType=${widget.initial!.routeType?.name ?? "null"}) - skipping routePoints conversion (geometry is the trail)');
}
// Load existing POI waypoints and auto-assign categories if missing
if (widget.initial!.poiWaypoints.isNotEmpty) {
final loadedWaypoints = widget.initial!.poiWaypoints.map((w) {
final waypoint = RouteWaypoint.fromJson(w);
// For GPX routes, use snap point position ONLY if snap info is valid
// Invalid snap info (distanceAlongRouteKm == 0 for multiple waypoints) means they were incorrectly snapped
// In that case, use the original position instead
final hasValidSnapInfo = waypoint.waypointSnapInfo != null && 
    waypoint.waypointSnapInfo!.distanceAlongRouteKm > 0;
final position = (hasValidSnapInfo && _isGpxRoute) 
    ? waypoint.waypointSnapInfo!.snapPoint 
    : waypoint.position;
// Auto-assign time slot category if not set
final updatedWaypoint = waypoint.timeSlotCategory == null
    ? waypoint.copyWith(
        position: position,
        timeSlotCategory: autoAssignTimeSlotCategory(waypoint),
      )
    : waypoint.copyWith(position: position);
return updatedWaypoint;
}).toList();

// For GPX routes, filter out route points (they're in geometry, not waypoints)
final filteredWaypoints = _isGpxRoute
    ? loadedWaypoints.where((w) => w.type != WaypointType.routePoint).toList()
    : loadedWaypoints;

// Sort by order field to preserve the order from builder screen
filteredWaypoints.sort((a, b) => a.order.compareTo(b.order));
_poiWaypoints.addAll(filteredWaypoints);
Log.i('route_builder', '📍 Loaded ${filteredWaypoints.length} POI waypoints (GPX route: $_isGpxRoute, filtered from ${loadedWaypoints.length} total)');

// For GPX routes, check if waypoints need snapping
if (_isGpxRoute && _poiWaypoints.isNotEmpty) {
  final needsSnapping = _poiWaypoints.any((wp) => 
    wp.waypointSnapInfo == null || 
    wp.waypointSnapInfo!.distanceAlongRouteKm == 0.0
  );
  
  if (needsSnapping) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _snapWaypointsToGpxRoute();
      }
    });
  }
}

// Calculate travel times if we have 2+ waypoints
if (_poiWaypoints.length >= 2) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _calculateTravelTimes();
      _updatePreview();
    }
  });
}
}
// Initialize route ordering based on waypoints
_initializeRouteOrdering();
}
} catch (e, stack) {
Log.e('route_builder', 'init failed', e, stack);
}
}

@override
void dispose() {
_searchDebounce?.cancel();
_sidebarSearchDebounce?.cancel();
_poiDebounce?.cancel();
_searchController.dispose();
_searchFocusNode.dispose();
_sidebarSearchController.dispose();
_sidebarSearchFocusNode.dispose();
_mapboxController = null;
super.dispose();
}

/// Get current camera center - works in both flutter_map and Mapbox modes
ll.LatLng _getCameraCenter() {
  if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
    return _map.camera.center;
  }
  // Fallback chain for Mapbox mode
  return _currentCameraCenter ?? 
         _poiWaypoints.firstOrNull?.position ?? 
         widget.start ?? 
         const ll.LatLng(61.0, 8.5);
}

/// Get GPX route points from geometry coordinates
List<ll.LatLng> _getGpxRoutePointsFromGeometry() {
  if (widget.initial?.geometry['coordinates'] is! List) return [];
  final coords = widget.initial!.geometry['coordinates'] as List;
  return _coordsToLatLng(coords);
}

/// Snap waypoints to GPX route if snap info is missing or invalid
void _snapWaypointsToGpxRoute() {
  final routePoints = _getGpxRoutePointsFromGeometry();
  if (routePoints.isEmpty) {
    Log.w('route_builder', '⚠️ Cannot snap waypoints: no GPX route points found');
    return;
  }
  
  Log.i('route_builder', '🔧 Snapping ${_poiWaypoints.length} waypoints to GPX route (${routePoints.length} points)');
  
  final snapper = GpxWaypointSnapper();
  bool anyUpdated = false;
  
  for (int i = 0; i < _poiWaypoints.length; i++) {
    final wp = _poiWaypoints[i];
    // Only snap if missing snap info or distanceAlongRouteKm is 0
    if (wp.waypointSnapInfo == null || wp.waypointSnapInfo!.distanceAlongRouteKm == 0.0) {
      Log.i('route_builder', '🔍 Snapping waypoint: ${wp.name}, hasSnapInfo=${wp.waypointSnapInfo != null}, distanceAlongRoute=${wp.waypointSnapInfo?.distanceAlongRouteKm ?? 0.0}km');
      
      final snapResult = snapper.snapToRoute(wp.position, routePoints);
      final snapInfo = WaypointSnapInfo(
        snapPoint: snapResult.snapPoint,
        originalPosition: wp.position,
        distanceFromRouteM: snapResult.distanceFromRoute,
        distanceAlongRouteKm: snapResult.distanceAlongRoute,
        segmentIndex: snapResult.segmentIndex,
      );
      
      _poiWaypoints[i] = wp.copyWith(
        position: snapResult.snapPoint,
        waypointSnapInfo: snapInfo,
      );
      
      anyUpdated = true;
      Log.i('route_builder', '✅ Snapped ${wp.name}: distanceAlongRoute=${snapResult.distanceAlongRoute.toStringAsFixed(3)}km, distanceFromRoute=${snapResult.distanceFromRoute.toStringAsFixed(0)}m');
    }
  }
  
  if (anyUpdated) {
    setState(() {});
    // Recalculate travel times after snapping
    if (_poiWaypoints.length >= 2) {
      _calculateTravelTimes();
      _updatePreview();
    }
  } else {
    Log.i('route_builder', 'ℹ️ All waypoints already have valid snap info');
  }
}

/// Get current camera zoom - works in both flutter_map and Mapbox modes  
double _getCameraZoom() {
  if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
    return _map.camera.zoom;
  }
  return _currentCameraZoom ?? 11.0;
}

/// Handle zoom controls - works in both flutter_map and Mapbox modes
void _handleZoom(int delta) {
  // Set flag to prevent map tap pop-up during programmatic zoom
  setState(() => _isProgrammaticCameraMove = true);
  
  if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
    _map.move(_map.camera.center, _map.camera.zoom + delta);
    // Reset flag after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isProgrammaticCameraMove = false);
    });
  } else {
    // For Mapbox mode: Animate camera via controller and update state
    final newZoom = (_currentCameraZoom ?? 11.0) + delta;
    final center = _currentCameraCenter ?? _getCameraCenter();
    
    // Update state optimistically for immediate UI feedback (Issue #2 fix)
    setState(() {
      _currentCameraZoom = newZoom;
    });
    
    // Use controller to actually animate the map (with null-aware access)
    if (_mapboxController != null) {
      _mapboxController!.animateCamera(center, newZoom);
    } else {
      Log.w('route_builder', '⚠️ Map controller not ready, zoom command skipped');
    }
    Log.i('route_builder', 'Zoom changed to $newZoom');
    
    // Reset flag after zoom animation completes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isProgrammaticCameraMove = false);
    });
  }
}

/// Calculate approximate bounds from center and zoom level
/// This is a fallback when we don't have access to the actual visible bounds
Map<String, double> _calculateBoundsFromCenterZoom(ll.LatLng center, double zoom) {
  // Approximate degrees per pixel at given zoom level
  // At zoom 0, the entire world (360 degrees) fits in 256 pixels
  final scale = 256 * pow(2, zoom);
  final degreesPerPixel = 360 / scale;
  
  // Assume viewport is roughly 600x600 pixels (can be refined based on actual viewport)
  final halfWidth = 300 * degreesPerPixel;
  final halfHeight = 300 * degreesPerPixel;
  
  return {
    'south': center.latitude - halfHeight,
    'north': center.latitude + halfHeight,
    'west': center.longitude - halfWidth,
    'east': center.longitude + halfWidth,
  };
}

/// Fit map to show all waypoints
void _fitToWaypoints() {
  final allPoints = <ll.LatLng>[];
  
  // Add waypoint positions
  for (final wp in _poiWaypoints) {
    allPoints.add(wp.position);
  }
  
  // Add route geometry points if available
  if (_previewGeometry != null) {
    final routePoints = _coordsToLatLng(_previewGeometry!['coordinates']);
    if (routePoints.isNotEmpty) {
      allPoints.addAll(routePoints);
    }
  }
  
  if (allPoints.isEmpty) {
    Log.i('route_builder', '📍 No waypoints to fit - showing world map');
    // Show world map if no waypoints
    _moveCamera(const ll.LatLng(0.0, 0.0), 2.5);
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
  
  // Add padding (15%)
  final latPadding = (maxLat - minLat) * 0.15;
  final lngPadding = (maxLng - minLng) * 0.15;
  minLat -= latPadding;
  maxLat += latPadding;
  minLng -= lngPadding;
  maxLng += lngPadding;
  
  final center = ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  final latDiff = maxLat - minLat;
  final lngDiff = maxLng - minLng;
  final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
  
  // Calculate appropriate zoom level
  double zoom = 14.0;
  if (maxDiff > 0.5) {
    zoom = 10.0;
  } else if (maxDiff > 0.2) {
    zoom = 11.0;
  } else if (maxDiff > 0.1) {
    zoom = 12.0;
  } else if (maxDiff > 0.05) {
    zoom = 13.0;
  }
  
  Log.i('route_builder', '📍 Fitting map to ${allPoints.length} waypoints/points: center=$center, zoom=$zoom');
  _moveCamera(center, zoom);
}

/// Move camera - works in both flutter_map and Mapbox modes
void _moveCamera(ll.LatLng position, [double? zoom]) {
  // Set flag to prevent map tap pop-up during programmatic camera moves
  setState(() => _isProgrammaticCameraMove = true);
  
  if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
    _map.move(position, zoom ?? _getCameraZoom());
    // Reset flag after a short delay to allow camera animation to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProgrammaticCameraMove = false);
    });
  } else {
    // For Mapbox mode: Animate camera via controller and update state (Issue #2 fix)
    final targetZoom = zoom ?? _getCameraZoom();
    
    // Update state optimistically for immediate UI feedback
    setState(() {
      _currentCameraCenter = position;
      if (zoom != null) _currentCameraZoom = zoom;
    });
    
    // Use controller to actually animate the map (with null-aware access)
    if (_mapboxController != null) {
      _mapboxController!.animateCamera(position, targetZoom);
    } else {
      Log.w('route_builder', '⚠️ Map controller not ready, camera move skipped');
    }
    
    // Reset flag after camera animation completes (Mapbox animations are typically 500ms)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isProgrammaticCameraMove = false);
    });
  }
}

// Legacy: _getActivityLabel removed

/// Handle back button press - return current route state to keep waypoint order in sync
void _handleBackPress() {
// If we have waypoints or route data, return the current state
if (_poiWaypoints.isNotEmpty || _previewGeometry != null) {
// CRITICAL: For GPX routes with supported activities, always preserve the original GPX trail geometry
// This prevents creating waypoint-to-waypoint straight lines
final isGpxBack = widget.initial?.routeType == RouteType.gpx || _isGpxRoute;
final supportsGpxBack = supportsGpxRoute(widget.activityCategory);
  final requiresGpx = requiresGpxRoute(widget.activityCategory);

Map<String, dynamic> geometry;
if (isGpxBack && supportsGpxBack && widget.initial?.geometry != null) {
  // CRITICAL: Use the original GPX trail geometry, NOT waypoint connections
  geometry = widget.initial!.geometry;
  Log.i('route_builder', '✅ Back: preserving GPX trail geometry (${(widget.initial!.geometry['coordinates'] as List?)?.length ?? 0} points)');
} else if (requiresGpx) {
  // For GPX-required activities, never create geometry from waypoint positions
  if (widget.initial?.geometry != null) {
    // Use existing GPX geometry if available
    geometry = widget.initial!.geometry;
    Log.i('route_builder', '✅ Back: using existing GPX geometry for GPX-required activity');
  } else {
    // GPX is required but not found - just pop without geometry
    Log.w('route_builder', '⚠️ GPX route required but not found in _handleBackPress');
    context.pop();
    return;
  }
} else if (_previewGeometry != null) {
  geometry = _previewGeometry!;
} else if (_poiWaypoints.isNotEmpty) {
  // Create empty geometry centered on first waypoint as last resort (only for non-GPX-required activities)
  final firstWp = _poiWaypoints.first;
  geometry = {
    'type': 'LineString',
    'coordinates': [[firstWp.position.longitude, firstWp.position.latitude]],
  };
} else {
  // Nothing to save, just pop
  context.pop();
  return;
}

// Apply ordering one final time to ensure waypoints are in correct order
if (_routeOrderManager != null) {
  _applyRouteOrdering();
}

// Ensure order field is set correctly before saving
for (int i = 0; i < _poiWaypoints.length; i++) {
  _poiWaypoints[i].order = i;
}

final route = DayRoute(
geometry: geometry,
distance: _previewDistance ?? widget.initial?.distance ?? 0,  // Preserve GPX distance
duration: _previewDuration ?? widget.initial?.duration ?? 0,  // Preserve GPX duration
routePoints: [], // Route points removed - routes are built from waypoints only
elevationProfile: _previewElevation.isNotEmpty ? _previewElevation : widget.initial?.elevationProfile,
ascent: _previewAscent ?? widget.initial?.ascent,
descent: _previewDescent ?? widget.initial?.descent,
poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList(),
routeType: isGpxBack ? RouteType.gpx : widget.initial?.routeType,  // Preserve routeType
);
context.pop(route);
} else {
// No data to preserve, just pop normally
context.pop();
}
}

@override
Widget build(BuildContext context) {
// Use tracked camera center in Mapbox mode for consistency, otherwise fallback to data
// This ensures the map initializes at the correct position even after refinement
final center = (!MapFeatureFlags.useLegacyEditor && 
            MapFeatureFlags.useMapboxEverywhere && 
            _currentCameraCenter != null)
? _currentCameraCenter!
: (_poiWaypoints.isNotEmpty
    ? _poiWaypoints.first.position
    : (widget.start ?? const ll.LatLng(61.0, 8.5)));
return Scaffold(
backgroundColor: context.colors.surface,
appBar: AppBar(
backgroundColor: context.colors.surface.withValues(alpha: 0.9),
scrolledUnderElevation: 0,
elevation: 0,
toolbarHeight: 56,
leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBackPress),
actions: [
// Legacy: Snap to trail toggle removed
],
),
body: LayoutBuilder(builder: (context, constraints) {
final isDesktopSidebar = constraints.maxWidth >= 1280;
// Desktop (>=1280px): Sidebar + Map layout
if (isDesktopSidebar) {
return Row(
children: [
SizedBox(
width: 380,
child: _DesktopSidebar(
poiWaypoints: _poiWaypoints,
busy: _busy,
onAddWaypoint: _showAddWaypointDialog,
onEditWaypoint: _editWaypoint,
sidebarSearchController: _sidebarSearchController,
sidebarSearchFocusNode: _sidebarSearchFocusNode,
sidebarSearching: _sidebarSearching,
sidebarSearchResults: _sidebarSearchResults,
onSidebarSearchChanged: _debouncedSidebarSearch,
onSidebarSearchClear: () => setState(() => _sidebarSearchResults = []),
onSidebarSearchSelect: (s) => _selectPlace(s),
onPreview: _poiWaypoints.length < 2 ? null : _updatePreview,
onSave: (_poiWaypoints.isEmpty) ? null : _buildAndSave,
onReorder: (oldIndex, newIndex) {
setState(() {
if (newIndex > oldIndex) newIndex -= 1;
final item = _poiWaypoints.removeAt(oldIndex);
_poiWaypoints.insert(newIndex, item);
for (int i = 0; i < _poiWaypoints.length; i++) {
_poiWaypoints[i].order = i;
}
});
},
onCancel: _handleBackPress,
activityCategory: widget.activityCategory,
routeOrderManager: _routeOrderManager,
onTravelModeChanged: (waypoint, newMode) async {
  await _recalculateTravelForWaypoint(waypoint, newMode);
},
onAddAlternative: (waypoint) async {
  await _addAlternativeWaypoint(waypoint);
},
onWaypointUpdated: (updatedWp) {
  setState(() {
    final index = _poiWaypoints.indexWhere((w) => w.id == updatedWp.id);
    if (index != -1) {
      _poiWaypoints[index] = updatedWp;
    }
  });
},
onBulkWaypointUpdate: (updatedWps) {
  Log.i('route_builder', '📦 onBulkWaypointUpdate called with ${updatedWps.length} waypoints');
  for (final wp in updatedWps) {
    Log.i('route_builder', '  → ${wp.name} (id=${wp.id.substring(0, 8)}) order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
  setState(() {
    for (final updatedWp in updatedWps) {
      final index = _poiWaypoints.indexWhere((w) => w.id == updatedWp.id);
      if (index != -1) {
        _poiWaypoints[index] = updatedWp;
      }
    }
    _renumberWaypoints();
  });
  Log.i('route_builder', '📦 After renumber:');
  for (final wp in _poiWaypoints) {
    Log.i('route_builder', '  → ${wp.name} (id=${wp.id.substring(0, 8)}) order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
  _calculateTravelTimes();
  if (_poiWaypoints.length >= 2) {
    _updatePreview();
  }
},
onOrderChanged: () {
  _renumberWaypoints(); // Normalize orders to 1,2,3...
  _calculateTravelTimes(); // Recalculate travel times
  if (_poiWaypoints.length >= 2) {
    _updatePreview(); // Update route preview
  }
},
onUngroup: (choiceGroupId) {
  _ungroupChoiceGroup(choiceGroupId);
},
onMoveUp: (itemId) {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
if (_routeOrderManager != null) {
setState(() {
_routeOrderManager = _routeOrderManager!.moveUp(itemId);
_applyRouteOrdering();
});
}
},
onMoveDown: (itemId) {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
if (_routeOrderManager != null) {
setState(() {
_routeOrderManager = _routeOrderManager!.moveDown(itemId);
_applyRouteOrdering();
});
}
},
canMoveUp: (itemId) => _routeOrderManager?.canMoveUp(itemId) ?? false,
canMoveDown: (itemId) => _routeOrderManager?.canMoveDown(itemId) ?? false,
onInitializeOrdering: () {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
},
),
),
Expanded(
child: Stack(children: [
Positioned.fill(
child: _buildMapWidget(center),
),
// CRITICAL: PointerInterceptor creates an invisible HTML element above the
// Google Maps Platform View to block browser-level DOM events (scroll, click, drag).
// Flutter's gesture system cannot intercept events targeting Platform Views.
if (_dialogOrBottomSheetOpen)
  Positioned.fill(
    child: PointerInterceptor(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Consume taps
        child: Container(
          color: Colors.transparent,
        ),
      ),
    ),
  ),
// Floating Search Bar (top center of map area)
_FloatingSearchBar(
controller: _searchController,
focusNode: _searchFocusNode,
searching: _searching,
results: _searchResults,
onChanged: _debouncedSearch,
onClear: () => setState(() => _searchResults = []),
onSelect: (s) => _selectPlaceForMapNavigation(s),
mapAreaPaddingLeft: 0,
mapAreaWidth: null,
),
// Zoom controls (right center)
Positioned.fill(
child: Align(
alignment: Alignment.centerRight,
child: Padding(
padding: const EdgeInsets.only(right: 12),
child: _ZoomControls(
onZoomIn: () => _handleZoom(1),
onZoomOut: () => _handleZoom(-1),
onFitWaypoints: _poiWaypoints.isNotEmpty ? _fitToWaypoints : null,
),
),
),
),
]),
),
],
);
}
// Mobile/Tablet: original map-first with bottom panel
return Stack(
children: [
// Map layer
Positioned.fill(
child: _buildMapWidget(center),
),
// CRITICAL: PointerInterceptor creates an invisible HTML element above the
// Google Maps Platform View to block browser-level DOM events (scroll, click, drag).
// Flutter's gesture system cannot intercept events targeting Platform Views.
if (_dialogOrBottomSheetOpen)
  Positioned.fill(
    child: PointerInterceptor(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Consume taps
        child: Container(
          color: Colors.transparent,
        ),
      ),
    ),
  ),
// POI Loading Indicator (subtle overlay)
if (_loadingPOIs)
Positioned(
top: 16,
right: 16,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.7),
borderRadius: BorderRadius.circular(20),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2,
valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
),
),
const SizedBox(width: 8),
Text(
'Loading POIs...',
style: TextStyle(
color: Colors.white,
fontSize: 12,
fontWeight: FontWeight.w500,
),
),
],
),
),
),

// Floating Search Bar (center top)
_FloatingSearchBar(
controller: _searchController,
focusNode: _searchFocusNode,
searching: _searching,
results: _searchResults,
onChanged: _debouncedSearch,
onClear: () => setState(() => _searchResults = []),
onSelect: (s) => _selectPlaceForMapNavigation(s),
mapAreaPaddingLeft: 0,
mapAreaWidth: null,
),

// Hint chip (bottom-left on mobile/tablet)
if (_shouldShowHint && !isDesktopSidebar)
Positioned(
left: 16,
bottom: 24 + 180, // above bottom sheet collapsed height
child: _HintChip(
text: 'Tap map to add waypoints',
onDismiss: () => setState(() => _hintDismissed = true),
),
),

// Zoom + extra map controls (right, vertically centered)
Positioned.fill(
child: Align(
alignment: Alignment.centerRight,
child: Padding(
padding: const EdgeInsets.only(right: 12),
child: _ZoomControls(
onZoomIn: () => _handleZoom(1),
onZoomOut: () => _handleZoom(-1),
onFitWaypoints: _poiWaypoints.isNotEmpty ? _fitToWaypoints : null,
),
),
),
),
Positioned(
right: 12,
bottom: 12 + 180, // keep above bottom sheet when collapsed
child: Column(children: [
]),
),

// Bottom draggable panel
_BottomPanel(
poiWaypoints: _poiWaypoints,
previewDistance: _previewDistance,
previewDuration: _previewDuration,
elevation: _previewElevation,
ascent: _previewAscent,
descent: _previewDescent,
busy: _busy,
onAddWaypoint: _showAddWaypointDialog,
onEditWaypoint: _editWaypoint,
onPreview: _poiWaypoints.length < 2 ? null : _updatePreview,
onSave: _poiWaypoints.isEmpty ? null : _buildAndSave,
skipTravelSegments: _isGpxRoute && (widget.activityCategory == ActivityCategory.hiking ||
                                   widget.activityCategory == ActivityCategory.skis ||
                                   widget.activityCategory == ActivityCategory.cycling ||
                                   widget.activityCategory == ActivityCategory.climbing),
onReorder: (oldIndex, newIndex) {
setState(() {
if (newIndex > oldIndex) newIndex -= 1;
final item = _poiWaypoints.removeAt(oldIndex);
_poiWaypoints.insert(newIndex, item);
for (int i = 0; i < _poiWaypoints.length; i++) {
_poiWaypoints[i].order = i;
}
_renumberWaypoints(); // Ensure sequential ordering
});
// Recalculate travel times after reordering
_calculateTravelTimes();
// Auto-update preview to show route line when there are 2+ waypoints
if (_poiWaypoints.length >= 2) {
_updatePreview();
}
},
routeOrderManager: _routeOrderManager,
onTravelModeChanged: (waypoint, newMode) async {
  await _recalculateTravelForWaypoint(waypoint, newMode);
},
onAddAlternative: (waypoint) async {
  await _addAlternativeWaypoint(waypoint);
},
onWaypointUpdated: (updatedWp) {
  setState(() {
    final index = _poiWaypoints.indexWhere((w) => w.id == updatedWp.id);
    if (index != -1) {
      _poiWaypoints[index] = updatedWp;
    }
  });
},
onBulkWaypointUpdate: (updatedWps) {
  Log.i('route_builder', '📦 onBulkWaypointUpdate called with ${updatedWps.length} waypoints');
  for (final wp in updatedWps) {
    Log.i('route_builder', '  → ${wp.name} (id=${wp.id.substring(0, 8)}) order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
  setState(() {
    for (final updatedWp in updatedWps) {
      final index = _poiWaypoints.indexWhere((w) => w.id == updatedWp.id);
      if (index != -1) {
        _poiWaypoints[index] = updatedWp;
      }
    }
    _renumberWaypoints();
  });
  Log.i('route_builder', '📦 After renumber:');
  for (final wp in _poiWaypoints) {
    Log.i('route_builder', '  → ${wp.name} (id=${wp.id.substring(0, 8)}) order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
  _calculateTravelTimes();
  if (_poiWaypoints.length >= 2) {
    _updatePreview();
  }
},
onOrderChanged: () {
  _renumberWaypoints(); // Normalize orders to 1,2,3...
  _calculateTravelTimes(); // Recalculate travel times
  if (_poiWaypoints.length >= 2) {
    _updatePreview(); // Update route preview
  }
},
onUngroup: (choiceGroupId) {
  _ungroupChoiceGroup(choiceGroupId);
},
onMoveUp: (itemId) {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
if (_routeOrderManager != null) {
setState(() {
_routeOrderManager = _routeOrderManager!.moveUp(itemId);
_applyRouteOrdering();
});
}
},
onMoveDown: (itemId) {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
if (_routeOrderManager != null) {
setState(() {
_routeOrderManager = _routeOrderManager!.moveDown(itemId);
_applyRouteOrdering();
});
}
},
canMoveUp: (itemId) => _routeOrderManager?.canMoveUp(itemId) ?? false,
canMoveDown: (itemId) => _routeOrderManager?.canMoveDown(itemId) ?? false,
onInitializeOrdering: () {
if (_routeOrderManager == null) {
_initializeRouteOrdering();
}
},
),
],
);
}),
);
}

/// Build the map widget - either legacy flutter_map or new Mapbox editor
/// This method handles the switching logic based on feature flags
Widget _buildMapWidget(ll.LatLng center) {
  // Use legacy flutter_map if flag is set OR if useMapboxEverywhere is false
  if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
    return _buildLegacyFlutterMap(center);
  }
  
  // Otherwise use the new Mapbox editor
  return _buildMapboxEditor(center);
}

/// Helper to filter out waypoint connections (2-3 points = direct lines)
/// Only filters for GPX-required activities to avoid false positives on short legitimate routes
bool _isWaypointConnection(List<ll.LatLng> points, ActivityCategory? activityCategory) {
  // Waypoint connections have 2-3 points, GPX trails have 50+ points
  // Only filter for GPX-required activities to avoid false positives
  if (!requiresGpxRoute(activityCategory)) {
    return false; // Don't filter for city trips/tours
  }
  return points.length >= 2 && points.length <= 3;
}

// Helper functions moved to lib/utils/activity_utils.dart

/// NEW: Google Maps-powered editor using AdaptiveMapWidget
Widget _buildMapboxEditor(ll.LatLng center) {
  // Convert preview geometry to polyline
  final polylines = <MapPolyline>[];
  
  // Check if this is a GPX route with supported activities
  final isGpxRoute = widget.initial?.routeType == RouteType.gpx ||
      (widget.initial?.routeType == null &&
       widget.initial?.routePoints.isEmpty == true &&
       widget.initial?.geometry['coordinates'] is List &&
       (widget.initial?.geometry['coordinates'] as List).length > 100);
  
  final supportsGpx = supportsGpxRoute(widget.activityCategory);
  
  // Validate GPX requirement
  final requiresGpx = requiresGpxRoute(widget.activityCategory);
  if (requiresGpx && !isGpxRoute && widget.initial?.geometry == null) {
    Log.w('route_builder', '⚠️ GPX route required for ${widget.activityCategory?.name} but no GPX route found');
  }
  
  // For GPX routes with supported activities, ONLY show the GPX trail (no waypoint connections)
  // Completely ignore _previewRouteSegments and _previewGeometry for GPX routes
  if (isGpxRoute && supportsGpx && widget.initial?.geometry['coordinates'] is List && (widget.initial?.geometry['coordinates'] as List).isNotEmpty) {
    // Only show the GPX trail from widget.initial.geometry - this is the original trail
    final gpxCoords = widget.initial!.geometry['coordinates'] as List;
    final gpxPoints = _coordsToLatLng(gpxCoords);
    // Only show if we have a substantial number of points (actual GPX trail, not waypoint connections)
    // Waypoint connections would have 2-3 points, GPX trails have 50+ points
    if (gpxCoords.length >= 50 && gpxPoints.length >= 50) {
      polylines.add(MapPolyline(
        id: 'gpx_route',
        points: gpxPoints,
        color: const Color(0xFF4CAF50), // Green for GPX trail
        width: 4.0,
        borderColor: Colors.white,
        borderWidth: 2,
      ));
      Log.i('route_builder', '✅ Showing GPX trail from widget.initial.geometry: ${gpxPoints.length} points');
    }
    // Don't show any other routes - no waypoint connections, no preview segments
    // Explicitly skip _previewRouteSegments and _previewGeometry even if they exist
    // This ensures no waypoint-to-waypoint connections are rendered
  } else {
    // Non-GPX routes or non-supported activities: use per-segment routes if available
    // IMPORTANT: For GPX routes (even without supported activities), don't use _previewRouteSegments
    // as they might contain waypoint connections. Only use _previewRouteSegments for non-GPX routes.
    if (!isGpxRoute && _poiWaypoints.length >= 2 && _previewRouteSegments != null && _previewRouteSegments!.isNotEmpty) {
      for (int i = 0; i < _previewRouteSegments!.length; i++) {
        final segment = _previewRouteSegments![i];
        final mode = segment['travelMode'] as String;
        final coords = segment['geometry'] as List;
        final points = _coordsToLatLng(coords);
        final isChoiceRoute = segment['isChoiceRoute'] as bool? ?? false;
        
        // Only add if we have enough points (not a direct waypoint connection)
        // Direct connections would have 2-3 points, actual routes have more
        if (points.isNotEmpty && points.length > 3) {
          final color = _getTravelModeColor(mode);
          polylines.add(MapPolyline(
            id: 'route_${mode}_$i',
            points: points,
            color: isChoiceRoute ? color.withOpacity(0.6) : color, // Slightly transparent for choice routes
            width: isChoiceRoute ? 3 : 5, // Thinner for choice routes
            borderColor: Colors.white,
            borderWidth: isChoiceRoute ? 1 : 2,
          ));
        }
      }
    } else if (!isGpxRoute && _poiWaypoints.length >= 2 && _previewGeometry != null) {
      // IMPORTANT: Don't use _previewGeometry for GPX routes as it might contain waypoint connections
      final previewPoints = _coordsToLatLng(_previewGeometry!['coordinates']);
      // Only add if we have enough points (not a direct waypoint connection)
      if (previewPoints.isNotEmpty && previewPoints.length > 3) {
        // Legacy fallback: single route (only for non-GPX routes)
        polylines.add(MapPolyline(
          id: 'route',
          points: previewPoints,
          color: const Color(0xFF4CAF50),
          width: 5,
          borderColor: Colors.white,
          borderWidth: 2,
        ));
      }
    }
    
    // For GPX routes without supported activities, add green lines from waypoints to their snap points (if off-trail)
    if (isGpxRoute && !supportsGpx) {
      for (final wp in _poiWaypoints) {
        if (wp.waypointSnapInfo != null && wp.waypointSnapInfo!.distanceFromRouteM > 0) {
          // Waypoint is off-trail - draw green dashed line from original position to snap point
          polylines.add(MapPolyline(
            id: 'snap_${wp.id}',
            points: [wp.waypointSnapInfo!.originalPosition, wp.waypointSnapInfo!.snapPoint],
            color: const Color(0xFF4CAF50), // Green
            width: 2.0,
            isDashed: true,
            dashPattern: [5, 5],
          ));
        }
      }
    }
  }
  
  // CRITICAL: Filter out any polylines that look like waypoint connections
  // This is a defensive measure to catch any contaminated geometry
  // Only filter for GPX-required activities (hiking/cycling/skiing/climbing)
  // Note: requiresGpx is already declared above in this method
  final filteredPolylines = polylines.where((polyline) {
    final isConnection = _isWaypointConnection(polyline.points, widget.activityCategory);
    if (isConnection) {
      Log.w('route_builder', '⚠️ Filtered out waypoint connection polyline: ${polyline.id} (${polyline.points.length} points)');
      return false; // Remove this polyline
    }
    return true; // Keep this polyline
  }).toList();
  
  // Only log if filtering actually removed something (reduce noise)
  if (filteredPolylines.length < polylines.length) {
    Log.i('route_builder', '📊 Polylines after filtering: ${filteredPolylines.length} (removed ${polylines.length - filteredPolylines.length} waypoint connections)');
  }
  
  // Convert waypoints to annotations
  final annotations = <MapAnnotation>[];
  
  // OSM POI annotations removed - no longer showing red dots on map
  
  // Convert custom waypoints to annotations
  // showInfoWindow: false prevents Google Maps from showing its default
  // info window popup when the marker is tapped
  for (final wp in _poiWaypoints) {
    annotations.add(MapAnnotation.fromWaypoint(
      wp,
      draggable: false,
      showInfoWindow: false,
      onTap: () => _editWaypoint(wp),
    ));
  }
  
  return AdaptiveMapWidget(
    initialCenter: center,
    configuration: MapConfiguration.routeBuilder(),
    onMapCreated: (controller) {
      // Store controller reference for camera commands (Issue #2 fix)
      _mapboxController = controller;
      Log.i('route_builder', '🗺️ Mapbox controller stored for camera commands');
      
      // LEGACY: OSM POI loading disabled - removed POI loading after map ready
      // OSM POIs are no longer used in the application
    },
    onTap: (latLng) async {
      // Only clear search results when tapping map
      if (_searchResults.isNotEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      // Map tap no longer adds waypoints - users must use search bars
    },
    onCameraChanged: (cameraPos) {
      // Store camera state WITHOUT triggering rebuild (prevents marker jitter during zoom)
      // We use instance variables directly instead of setState to avoid visual artifacts
      final newCenter = cameraPos.center;
      final newZoom = cameraPos.zoom;
      
      _currentCameraCenter = newCenter;
      _currentCameraZoom = newZoom;
      
      // LEGACY: OSM POI loading disabled - removed POI refresh logic on camera changes
      // OSM POIs are no longer used in the application
    },
    annotations: annotations,
    polylines: filteredPolylines,
  );
}

/// LEGACY: Original flutter_map implementation (preserved for rollback)
Widget _buildLegacyFlutterMap(ll.LatLng center) {
  return fm.FlutterMap(
    mapController: _map,
    options: fm.MapOptions(
      initialCenter: center,
      initialZoom: 11,
      onPositionChanged: _onMapPositionChanged,
      onTap: (tapPos, latLng) async {
        // Only clear search results when tapping map
        if (_searchResults.isNotEmpty) {
          setState(() => _searchResults = []);
          return;
        }
        // Map tap no longer adds waypoints - users must use search bars
      },
    ),
    children: [
      fm.TileLayer(
        urlTemplate: defaultRasterTileUrl,
        userAgentPackageName: 'com.waypoint.app',
      ),
      // Use per-segment routes if available (with travel mode colors), otherwise fallback to legacy single route
      if (_poiWaypoints.length >= 2 && _previewRouteSegments != null && _previewRouteSegments!.isNotEmpty)
        fm.PolylineLayer(
          polylines: _previewRouteSegments!.asMap().entries.map((entry) {
            final i = entry.key;
            final segment = entry.value;
            final mode = segment['travelMode'] as String;
            final coords = segment['geometry'] as List;
            final points = _coordsToLatLng(coords);
            final isChoiceRoute = segment['isChoiceRoute'] as bool? ?? false;
            final color = _getTravelModeColor(mode);
            
            final routeType = segment['routeType'] as String? ?? 'directions';
            final isStraightLine = routeType == 'straightLine';
            final isGpx = routeType == 'gpx';
            
            // Determine color based on route type
            Color polyColor;
            if (isStraightLine) {
              polyColor = Colors.grey.shade600; // Muted grey for straight-line
            } else if (isGpx) {
              polyColor = const Color(0xFF2E7D32); // Trail green for GPX
            } else {
              polyColor = color;
            }
            
            return fm.Polyline(
              points: points,
              color: isChoiceRoute 
                  ? polyColor.withOpacity(0.6) 
                  : (isStraightLine ? polyColor.withOpacity(0.6) : polyColor),
              strokeWidth: isChoiceRoute ? 3 : (isStraightLine ? 4 : 5),
              borderColor: isStraightLine ? Colors.transparent : Colors.white,
              borderStrokeWidth: isStraightLine ? 0 : (isChoiceRoute ? 1 : 2),
              // Note: flutter_map doesn't support dash patterns directly
              // Visual distinction for straight-line routes is achieved through opacity and color
            );
          }).toList(),
        )
      else if (_poiWaypoints.length >= 2 && _previewGeometry != null && _coordsToLatLng(_previewGeometry!['coordinates']).isNotEmpty)
        fm.PolylineLayer(
          polylines: [
            fm.Polyline(
              points: _coordsToLatLng(_previewGeometry!['coordinates']),
              color: const Color(0xFF4CAF50),
              strokeWidth: 5,
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            )
          ],
        ),
      // Route points removed - routes are built from waypoints only
      // OSM POI markers removed - no longer showing red dots on map
      // Custom POI waypoints (larger than OSM/Mapbox POIs, using brand colors)
      if (_poiWaypoints.isNotEmpty)
        fm.MarkerLayer(
          markers: _poiWaypoints
              .map((wp) => fm.Marker(
                    point: wp.position,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => _editWaypoint(wp),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: getWaypointColor(wp.type), // FILL with brand color
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5), // WHITE border
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Material( // FIX: Prevents "box" icons on Web
                            type: MaterialType.transparency,
                            child: Icon(
                              getWaypointIcon(wp.type),
                              color: Colors.white, // WHITE icon for visibility
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
    ],
  );
}

Widget _controlButton({required IconData icon, String? label, required VoidCallback onTap}) {
return Material(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
elevation: 4,
shadowColor: Colors.black.withValues(alpha: 0.3),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(12),
child: Container(
padding: EdgeInsets.all(label != null ? 12 : 14),
child: label != null
? Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 22, color: Colors.grey.shade800),
const SizedBox(height: 4),
Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
],
)
: Icon(icon, size: 22, color: Colors.grey.shade800),
),
),
);
}

void _debouncedSearch(String query) {
_searchDebounce?.cancel();
if (query.trim().isEmpty) {
setState(() {
_searchResults = [];
_searching = false;
});
return;
}
setState(() => _searching = true);
_searchDebounce = Timer(const Duration(milliseconds: 800), () => _performSearch(query));
}

void _debouncedSidebarSearch(String query) {
_sidebarSearchDebounce?.cancel();
if (query.trim().isEmpty) {
setState(() {
_sidebarSearchResults = [];
_sidebarSearching = false;
});
return;
}
setState(() => _sidebarSearching = true);
_sidebarSearchDebounce = Timer(const Duration(milliseconds: 800), () => _performSidebarSearch(query));
}

Future<void> _performSidebarSearch(String query) async {
if (query.trim().isEmpty) {
if (mounted) setState(() => _sidebarSearchResults = []);
return;
}
try {
Log.i('route_builder', '🔍 Starting sidebar Google Places search for: "$query"');
final center = _getCameraCenter();
final predictions = await _googlePlacesService.searchPlaces(
query: query,
proximity: center,
);

Log.i('route_builder', '✅ Sidebar Google Places search returned ${predictions.length} results');

final results = predictions.map((prediction) {
  return PlaceSuggestion(
    id: prediction.placeId,
    text: prediction.text,
    placeName: prediction.text,
    longitude: 0.0,
    latitude: 0.0,
    isPoi: false,
  );
}).toList();

if (mounted) {
setState(() {
_sidebarSearchResults = results;
_sidebarSearching = false;
});
}
} catch (e, stack) {
Log.e('route_builder', '❌ Sidebar Google Places search failed', e, stack);
if (mounted) {
setState(() {
_sidebarSearching = false;
_sidebarSearchResults = [];
});
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Search failed: ${e.toString()}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
}
}

Future<void> _performSearch(String query) async {
if (query.trim().isEmpty) {
if (mounted) setState(() => _searchResults = []);
return;
}
try {
Log.i('route_builder', '🔍 Starting Google Places search for: "$query"');
final center = _getCameraCenter(); // Use helper method
final predictions = await _googlePlacesService.searchPlaces(
query: query,
proximity: center,
);

Log.i('route_builder', '✅ Google Places search returned ${predictions.length} results');

// Convert Google Places predictions to PlaceSuggestion format
final results = predictions.map((prediction) {
  // We need to get place details to get coordinates
  // For now, create a placeholder - we'll fetch details when selected
  return PlaceSuggestion(
    id: prediction.placeId,
    text: prediction.text,
    placeName: prediction.text,
    longitude: 0.0, // Will be fetched when selected
    latitude: 0.0, // Will be fetched when selected
    isPoi: false,
  );
}).toList();

if (mounted) {
setState(() {
_searchResults = results;
_searching = false;
});
}
} catch (e, stack) {
Log.e('route_builder', '❌ Google Places search failed', e, stack);
if (mounted) {
setState(() {
_searching = false;
_searchResults = [];
});
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Search failed: ${e.toString()}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
}
}

/// Select place from map search bar - only moves camera, does not show add waypoint dialog
Future<void> _selectPlaceForMapNavigation(PlaceSuggestion place) async {
Log.i('route_builder', 'Place selected for map navigation: ${place.text}');
_searchFocusNode.unfocus();
setState(() {
_searchResults = [];
_searchController.clear();
});

// Fetch place details from Google Places API
try {
  setState(() => _searching = true);
  final placeDetails = await _googlePlacesService.getPlaceDetails(place.id);
  
  if (placeDetails == null) {
    if (mounted) {
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch place details'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  // Move camera to selected location (no dialog)
  _moveCamera(placeDetails.location, 14);
  
  if (mounted) {
    setState(() => _searching = false);
  }

  // LEGACY: OSM POI loading disabled - removed POI refresh after location search
  // OSM POIs are no longer used in the application
} catch (e, stack) {
  Log.e('route_builder', '❌ Failed to fetch place details for map navigation', e, stack);
  if (mounted) {
    setState(() => _searching = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to load place details: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}

Future<void> _selectPlace(PlaceSuggestion place) async {
Log.i('route_builder', 'Place selected: ${place.text}');
_searchFocusNode.unfocus();
_sidebarSearchFocusNode.unfocus();
setState(() {
_searchResults = [];
_searchController.clear();
_sidebarSearchResults = [];
_sidebarSearchController.clear();
});

// Fetch place details from Google Places API
try {
  setState(() => _searching = true);
  final placeDetails = await _googlePlacesService.getPlaceDetails(place.id);
  
  if (placeDetails == null) {
    if (mounted) {
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch place details'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  // Move camera to selected location
  _moveCamera(placeDetails.location, 14);
  
  // Show unified waypoint dialog with pre-filled Google My Business data
  if (mounted) {
    setState(() => _searching = false);
    await _showAddWaypointDialog(preselectedPlace: placeDetails);
  }

  // LEGACY: OSM POI loading disabled - removed POI refresh after location search
  // OSM POIs are no longer used in the application
} catch (e, stack) {
  Log.e('route_builder', '❌ Failed to fetch place details', e, stack);
  if (mounted) {
    setState(() => _searching = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to load place details: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}

  /// Called when map position changes - debounce POI reload
  void _onMapPositionChanged(fm.MapCamera camera, bool hasGesture) {
    // Cancel any pending debounce
    _poiDebounce?.cancel();
    
    // Calculate if position or zoom changed significantly
    final positionChanged = _lastPOICenter != null && 
        _calculateDistance(_lastPOICenter!, camera.center) > 2.0; // 2km threshold
    final zoomChanged = _lastPOIZoom != null && 
        (camera.zoom - _lastPOIZoom!).abs() > 0.01; // Reload on ANY zoom change (was 0.5)
    
    // Reload if camera moved significantly, zoom changed, or no POIs loaded yet
    final shouldReload = _lastPOICenter == null ||
        positionChanged ||
        zoomChanged ||
        _osmPOIs.isEmpty;
    
    if (shouldReload) {
      // Clear old POIs immediately when zoom changes to prevent clustering artifacts
      if (zoomChanged && _lastPOIZoom != null) {
        setState(() {
          _osmPOIs = []; // Clear old POIs immediately
        });
      }
      
      // Debounce to avoid too many API calls
      _poiDebounce = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          _loadPOIs();
        }
      });
    }
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(ll.LatLng p1, ll.LatLng p2) {
    const double earthRadius = 6371; // km
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  /// Check if two names are similar (for deduplication)
  bool _areNamesSimilar(String name1, String name2) {
    // Remove common words and compare
    final words1 = name1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = name2.split(' ').where((w) => w.length > 3).toSet();
    
    // Check if significant words overlap
    final intersection = words1.intersection(words2);
    return intersection.length >= 2 || 
           (intersection.length >= 1 && (words1.length <= 3 || words2.length <= 3));
  }

  Future<void> _loadPOIs() async {
    // LEGACY: OSM POI loading is disabled - this is legacy code
    // OSM POIs are no longer used in the application
    return;
    
    // Disabled code below (legacy OSM POI loading)
    /*
    if (_loadingPOIs) return;

    // Get current zoom level
    final currentZoom = _getCameraZoom();
    
    // Best practice: Don't show POIs when zoomed out too far (zoom < 12)
    // This prevents performance issues and the "all POIs in one line" problem
    // Common practice: AllTrails, Komoot, and other platforms hide POIs below zoom 12-13
    const double minZoomForPOIs = 12.0;
    
    if (currentZoom < minZoomForPOIs) {
      // Clear POIs when zoomed out too far
      if (mounted && _osmPOIs.isNotEmpty) {
        setState(() {
          _osmPOIs = [];
          _loadingPOIs = false;
          _lastPOICenter = _getCameraCenter();
          _lastPOIZoom = currentZoom;
        });
        Log.i('route_builder', '📍 Zoomed out too far (${currentZoom.toStringAsFixed(1)} < $minZoomForPOIs), hiding POIs');
      }
      return;
    }

    setState(() => _loadingPOIs = true);
    Log.i('route_builder', '🔍 Starting to load OSM POIs at zoom ${currentZoom.toStringAsFixed(1)}...');

try {
// Get bounds that work in both flutter_map and Mapbox modes
Map<String, double> bounds;

if (MapFeatureFlags.useLegacyEditor || !MapFeatureFlags.useMapboxEverywhere) {
  // Use flutter_map bounds
  final mapBounds = _map.camera.visibleBounds;
  bounds = {
    'south': mapBounds.south,
    'north': mapBounds.north,
    'west': mapBounds.west,
    'east': mapBounds.east,
  };
} else {
  // Calculate bounds from camera position for Mapbox mode
  final center = _getCameraCenter();
  bounds = _calculateBoundsFromCenterZoom(center, currentZoom);
}

Log.i('route_builder', '📍 Map bounds: S=${bounds['south']!.toStringAsFixed(2)}, W=${bounds['west']!.toStringAsFixed(2)}, N=${bounds['north']!.toStringAsFixed(2)}, E=${bounds['east']!.toStringAsFixed(2)}');

// Adjust maxResults based on zoom level for better performance
// Higher zoom = more detail = more POIs, lower zoom = fewer POIs
int maxResults;
if (currentZoom >= 15) {
  maxResults = 200; // Very zoomed in: show more POIs
} else if (currentZoom >= 13) {
  maxResults = 150; // Medium zoom: moderate POIs
} else {
  maxResults = 100; // Zoom 12-13: fewer POIs
}

// Load main outdoor POI types
final pois = await POIService.fetchPOIs(
southWest: ll.LatLng(bounds['south']!, bounds['west']!),
northEast: ll.LatLng(bounds['north']!, bounds['east']!),
poiTypes: [
POIType.campsite,
POIType.hut,
POIType.viewpoint,
POIType.water,
POIType.shelter,
POIType.parking,
POIType.toilets,
POIType.picnicSite,
],
maxResults: maxResults,
);

// Apply corridor filtering if route geometry exists
List<POI> filteredPois = pois;
if (_previewGeometry != null || _poiWaypoints.length >= 2) {
  // Get route points from preview geometry (preferred) or waypoints
  List<ll.LatLng> routePoints;
  if (_previewGeometry != null) {
    routePoints = _coordsToLatLng(_previewGeometry!['coordinates']);
  } else {
    // Build route from waypoints in order
    final sortedWaypoints = List<RouteWaypoint>.from(_poiWaypoints)..sort((a, b) => a.order.compareTo(b.order));
    routePoints = sortedWaypoints.map((wp) => wp.position).toList();
  }
  
  if (routePoints.length >= 2) {
    Log.i('route_builder', '🔍 Filtering ${pois.length} POIs by route corridor (${routePoints.length} route points, 2km radius)...');
    try {
      filteredPois = await POIService.filterPOIsNearTrail(
        trail: routePoints,
        pois: pois,
        radiusMeters: 2000.0, // 2km corridor
      );
      Log.i('route_builder', '✅ Filtered to ${filteredPois.length} POIs within 2km of route (${pois.length - filteredPois.length} filtered out)');
    } catch (e, stack) {
      Log.e('route_builder', '❌ Corridor filter failed, showing all POIs', e, stack);
      // Fallback to showing all POIs if filtering fails
      filteredPois = pois;
    }
  }
}

if (mounted) {
// Instead of replacing all POIs, merge with existing ones to prevent marker flicker
// Only add new POIs that don't already exist (by ID)
final existingIds = _osmPOIs.map((p) => p.id).toSet();
final newPois = filteredPois.where((p) => !existingIds.contains(p.id)).toList();
final updatedPois = <POI>[];
// Update existing POIs with new data (in case coordinates changed slightly)
for (final existingPoi in _osmPOIs) {
  final updatedPoi = filteredPois.firstWhere(
    (p) => p.id == existingPoi.id,
    orElse: () => existingPoi,
  );
  updatedPois.add(updatedPoi);
}
// Combine updated and new POIs
final allPois = [...updatedPois, ...newPois];

setState(() {
  _osmPOIs = allPois;
  _loadingPOIs = false;
  _lastPOICenter = _getCameraCenter(); // Use helper method
  _lastPOIZoom = currentZoom; // Use helper method
});
Log.i('route_builder', '✅ Loaded ${filteredPois.length} OSM POIs from API (${newPois.length} new, ${updatedPois.length} updated) at zoom ${currentZoom.toStringAsFixed(1)} (maxResults: $maxResults, total in memory: ${allPois.length})');
if (filteredPois.length < maxResults && filteredPois.length == pois.length) {
  Log.i('route_builder', 'ℹ️ API returned fewer POIs than requested (${filteredPois.length} < $maxResults) - may indicate sparse POI coverage in this area');
}
}
} catch (e, stack) {
Log.e('route_builder', '❌ Failed to load POIs', e, stack);
if (mounted) {
setState(() => _loadingPOIs = false);
}
}
}
*/
}

// LEGACY: OSM POI details method - disabled
void _showOSMPOIDetails(POI poi) {
  // LEGACY: This method is disabled - OSM POIs are no longer used
  return;
// Set flag to prevent map taps while bottom sheet is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when bottom sheet opens
_mapboxController?.disableInteractions();

showModalBottomSheet(
context: context,
builder: (context) => Container(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: poi.type.color,
borderRadius: BorderRadius.circular(8),
),
child: Icon(poi.type.icon, color: Colors.white, size: 20),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
poi.name,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
Text(
'${poi.type.displayName} (OSM)',
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
),
),
],
),
),
],
),
if (poi.description != null) ...[
const SizedBox(height: 16),
Text(
poi.description!,
style: const TextStyle(fontSize: 15),
),
],
const SizedBox(height: 16),
Text(
'${poi.coordinates.latitude.toStringAsFixed(5)}, ${poi.coordinates.longitude.toStringAsFixed(5)}',
style: TextStyle(
fontSize: 13,
color: Colors.grey.shade600,
),
),
],
),
),
).whenComplete(() {
  // Clear flag when bottom sheet is dismissed (immediately, no delay)
  if (mounted) {
    setState(() => _dialogOrBottomSheetOpen = false);
    // Re-enable map scroll zoom when bottom sheet closes
    _mapboxController?.enableInteractions();
  }
});
}

Future<void> _updatePreview() async {
  // Check if this is a GPX route with supported activities
  // For GPX routes with supported activities, we don't need to calculate route segments
  // The GPX trail is already in widget.initial.geometry, and waypoints are just POIs
  final isGpxRoute = widget.initial?.routeType == RouteType.gpx ||
      (widget.initial?.routeType == null &&
       widget.initial?.routePoints.isEmpty == true &&
       widget.initial?.geometry['coordinates'] is List &&
       (widget.initial?.geometry['coordinates'] as List).length > 100);
  
  final supportsGpx = supportsGpxRoute(widget.activityCategory);
  
  // For GPX routes with supported activities, clear preview segments and return early
  // The map will use widget.initial.geometry directly (the GPX trail)
  if (isGpxRoute && supportsGpx) {
    setState(() {
      _previewGeometry = null;
      _previewRouteSegments = null; // Clear segments - we'll use GPX trail directly
      _previewDistance = widget.initial?.distance;
      _previewDuration = widget.initial?.duration;
      _previewElevation = [];
      _previewAscent = null;
      _previewDescent = null;
    });
    return; // Don't calculate route segments - waypoints are just POIs along the trail
  }
  
  // Group waypoints by order for choice group handling
  final grouped = <int, List<RouteWaypoint>>{};
  for (final wp in _poiWaypoints) {
    if (wp.position.latitude != null && wp.position.longitude != null) {
      grouped.putIfAbsent(wp.order, () => <RouteWaypoint>[]).add(wp);
    }
  }
  
  final sortedOrders = grouped.keys.toList()..sort();
  Log.i('route_builder', '_updatePreview called: ${_poiWaypoints.length} waypoints, ${sortedOrders.length} order groups');
  
  if (sortedOrders.length < 2) {
setState(() {
_previewGeometry = null;
      _previewRouteSegments = null;
_previewDistance = null;
_previewDuration = null;
_previewElevation = [];
_previewAscent = null;
_previewDescent = null;
});
return;
}

setState(() => _busy = true);
  
try {
    final travelService = TravelCalculatorService();
    final routeSegments = <Map<String, dynamic>>[];
    double totalDistance = 0;
    int totalDuration = 0;
    final allRoutePoints = <ll.LatLng>[];
    
    // For each adjacent pair of order groups, calculate all route combinations (cartesian product)
    for (int i = 0; i < sortedOrders.length - 1; i++) {
      final fromOrder = sortedOrders[i];
      final toOrder = sortedOrders[i + 1];
      final fromWaypoints = grouped[fromOrder]!;
      final toWaypoints = grouped[toOrder]!;
      final isChoiceRoute = fromWaypoints.length > 1 || toWaypoints.length > 1;
      
      // Cartesian product: every fromWp → every toWp
      for (final fromWp in fromWaypoints) {
        for (final toWp in toWaypoints) {
          // Use stored geometry if available, otherwise fetch
          List<ll.LatLng>? segmentGeometry = toWp.travelRouteGeometry;
          TravelInfo? travelInfo;
          String routeType = 'directions';
          
          // Check if we have stored geometry for this specific segment
          // (Note: currently geometry is stored on toWp, but we need per-segment storage)
          // For now, fetch if not available
          if (segmentGeometry == null || segmentGeometry.isEmpty) {
            // Check if this is a GPX route and waypoints have snap info
            final isGpxRoute = widget.initial?.routeType == RouteType.gpx ||
                (widget.initial?.routeType == null &&
                 widget.initial?.routePoints.isEmpty == true &&
                 widget.initial?.geometry['coordinates'] is List &&
                 (widget.initial?.geometry['coordinates'] as List).length > 100);
            
            // Check if activity supports GPX (hike/ski/biking/climbing)
            final supportsGpx = supportsGpxRoute(widget.activityCategory);
            
            if (isGpxRoute && supportsGpx) {
              // GPX Flow: Skip distance calculations for supported activities
              // Waypoints are just POIs along the route, not route segments
              // Use GPX total distance and duration instead
              final gpxDistanceM = widget.initial?.distance ?? 0.0;
              final gpxDurationS = widget.initial?.duration ?? 0;
              
              // Create simple route geometry from GPX trail
              final routeGeometry = _getGpxRoutePointsFromGeometry();
              
              travelInfo = TravelInfo(
                from: fromWp.position,
                to: toWp.position,
                distanceMeters: gpxDistanceM.round(),
                durationSeconds: gpxDurationS,
                travelMode: TravelMode.walking,
                routeGeometry: routeGeometry,
                routeType: RouteType.gpx,
              );
              segmentGeometry = routeGeometry;
              routeType = 'gpx';
            } else if (isGpxRoute) {
              // Legacy GPX behavior for non-supported activities
              // Use calculateTravelWithGpx() service method which handles this correctly
              if (widget.initial?.geometry['coordinates'] is List) {
                final coords = widget.initial!.geometry['coordinates'] as List;
                final trackPoints = _coordsToLatLng(coords);
                
                // Create GpxRoute model from widget.initial data
                final gpxRoute = GpxRoute(
                  name: widget.initial?.routeType == RouteType.gpx ? 'GPX Route' : null,
                  trackPoints: trackPoints,
                  simplifiedPoints: trackPoints, // Use same points for now
                  totalDistanceKm: (widget.initial?.distance ?? 0.0) / 1000.0,
                  totalElevationGainM: widget.initial?.ascent,
                  estimatedDuration: widget.initial?.duration != null 
                      ? Duration(seconds: widget.initial!.duration) 
                      : null,
                  bounds: GpxRoute.createBounds(trackPoints),
                  importedAt: DateTime.now(),
                  fileName: 'route',
                );
                
                // Use the service method which correctly calculates segment distances
                travelInfo = await travelService.calculateTravelWithGpx(
                  from: fromWp.position,
                  to: toWp.position,
                  gpxRoute: gpxRoute,
                  activityCategory: widget.activityCategory,
                );
                
                if (travelInfo != null) {
                  segmentGeometry = travelInfo.routeGeometry;
                  routeType = 'gpx';
                } else {
                  // Service returned null - skip this segment
                  continue;
                }
              } else {
                // No geometry available - skip
                continue;
              }
            } else {
              // Fetch route geometry using Directions API
            final travelMode = toWp.travelMode != null
                ? TravelMode.values.firstWhere(
                    (tm) => tm.name == toWp.travelMode,
                    orElse: () => TravelMode.walking,
                  )
                : null;
            
            travelInfo = await travelService.calculateTravel(
              from: fromWp.position,
              to: toWp.position,
              travelMode: travelMode,
              includeGeometry: true, // Request geometry
              activityCategory: widget.activityCategory,
            );
            }
            
            if (travelInfo != null && travelInfo.routeGeometry != null) {
              segmentGeometry = travelInfo.routeGeometry;
              routeType = travelInfo.routeType.name;
              
              // Store geometry on waypoint (for the primary route)
              // Note: For choice groups, we may need per-segment storage in the future
              if (fromWp == fromWaypoints.first && toWp == toWaypoints.first) {
                final index = _poiWaypoints.indexWhere((w) => w.id == toWp.id);
                if (index >= 0) {
                  final modeName = toWp.travelMode ?? travelInfo.travelMode.name;
                  _poiWaypoints[index] = _poiWaypoints[index].copyWith(
                    travelRouteGeometry: segmentGeometry,
                    travelMode: modeName,
                    travelTime: travelInfo.durationSeconds,
                    travelDistance: travelInfo.distanceMeters.toDouble(),
                  );
}
              }
              
              // Only count distance/duration once per segment (use first combination)
              if (fromWp == fromWaypoints.first && toWp == toWaypoints.first) {
                totalDistance += travelInfo.distanceMeters;
                totalDuration += travelInfo.durationSeconds;
              }
            }
          } else {
            // Use stored values (only count once)
            // Infer route type from geometry: if only 2 points, likely straight-line
            if (segmentGeometry.length == 2) {
              routeType = 'straightLine';
            }
            if (fromWp == fromWaypoints.first && toWp == toWaypoints.first) {
              if (toWp.travelDistance != null) totalDistance += toWp.travelDistance!;
              if (toWp.travelTime != null) totalDuration += toWp.travelTime!;
            }
          }
          
          if (segmentGeometry != null && segmentGeometry.isNotEmpty) {
            routeSegments.add({
              'geometry': segmentGeometry.map((p) => [p.longitude, p.latitude]).toList(),
              'travelMode': toWp.travelMode ?? 'walking',
              'isChoiceRoute': isChoiceRoute, // Flag for visual distinction
              'routeType': routeType, // Store route type for rendering
            });
            // Only add to allRoutePoints once (for legacy single route)
            if (fromWp == fromWaypoints.first && toWp == toWaypoints.first) {
              allRoutePoints.addAll(segmentGeometry);
            }
          }
        }
      }
}

    if (mounted && routeSegments.isNotEmpty) {
setState(() {
        // Store segments for multi-polyline rendering
        _previewRouteSegments = routeSegments;
        // Also create legacy single geometry for backward compatibility
        _previewGeometry = {
          'type': 'LineString',
          'coordinates': allRoutePoints.map((p) => [p.longitude, p.latitude]).toList(),
        };
        _previewDistance = totalDistance;
        _previewDuration = totalDuration;
});

      // Calculate elevation profile if needed
      try {
        if (allRoutePoints.isNotEmpty) {
          final coords = allRoutePoints.map((p) => [p.longitude, p.latitude]).toList();
final elev = await _svc.elevationProfile(
coordinates: coords,
sampleEveryMeters: 100,
);
if (mounted && elev != null) {
final points = (elev['elevations'] as List?)
?.map((e) => ElevationPoint(
(e['distance'] as num).toDouble(),
(e['elevation'] as num).toDouble(),
))
.toList() ??
const <ElevationPoint>[];
setState(() {
_previewElevation = points;
_previewAscent = (elev['ascent'] as num?)?.toDouble();
_previewDescent = (elev['descent'] as num?)?.toDouble();
});
          }
}
} catch (e) {
Log.w('route_builder', 'Elevation skipped: $e');
}
}
} catch (e, stack) {
Log.e('route_builder', 'Preview failed', e, stack);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Preview failed: $e'), backgroundColor: Colors.orange),
);
}
} finally {
    if (mounted) {
      setState(() => _busy = false);
    }
}
}

Future<void> _buildAndSave() async {
// If we have waypoints but no preview yet, generate it
final sortedWaypoints = List<RouteWaypoint>.from(_poiWaypoints)..sort((a, b) => a.order.compareTo(b.order));
if (sortedWaypoints.length >= 2 && _previewGeometry == null) {
await _updatePreview();
if (_previewGeometry == null) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please preview the route first')),
);
}
return;
}
}

setState(() => _busy = true);
try {
// CRITICAL: For GPX routes with supported activities, always preserve the original GPX trail geometry
// This prevents creating waypoint-to-waypoint straight lines
final isGpxSave = widget.initial?.routeType == RouteType.gpx || _isGpxRoute;
final supportsGpxSave = widget.activityCategory == ActivityCategory.hiking ||
                        widget.activityCategory == ActivityCategory.skis ||
                        widget.activityCategory == ActivityCategory.cycling ||
                        widget.activityCategory == ActivityCategory.climbing;
  final requiresGpx = requiresGpxRoute(widget.activityCategory);

Map<String, dynamic> geometry;
if (isGpxSave && supportsGpxSave && widget.initial?.geometry != null) {
  // CRITICAL: Use the original GPX trail geometry, NOT waypoint connections
  geometry = widget.initial!.geometry;
  Log.i('route_builder', '✅ Saving GPX route with original trail geometry (${(widget.initial!.geometry['coordinates'] as List?)?.length ?? 0} points)');
} else if (requiresGpx) {
  // For GPX-required activities, never create geometry from waypoint positions
  if (widget.initial?.geometry != null) {
    // Use existing GPX geometry if available
    geometry = widget.initial!.geometry;
    Log.i('route_builder', '✅ Using existing GPX geometry for GPX-required activity');
  } else {
    // GPX is required but not found - show error
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX route is required for ${widget.activityCategory?.name}. Please import a GPX file.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    setState(() => _busy = false);
    return;
  }
} else if (_previewGeometry != null) {
  geometry = _previewGeometry!;
} else if (sortedWaypoints.length >= 2) {
  // Create geometry from waypoints if no preview exists (only for non-GPX-required activities)
  final waypointPoints = sortedWaypoints.map((wp) => wp.position).toList();
  geometry = {
    'type': 'LineString',
    'coordinates': waypointPoints.map((p) => [p.longitude, p.latitude]).toList(),
  };
} else if (_poiWaypoints.isNotEmpty) {
  // Create empty geometry centered on first waypoint as last resort
  final firstWp = _poiWaypoints.first;
  geometry = {
    'type': 'LineString',
    'coordinates': [[firstWp.position.longitude, firstWp.position.latitude]],
  };
} else {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please add waypoints or route points first')),
    );
  }
  setState(() => _busy = false);
  return;
}

// Apply ordering one final time to ensure waypoints are in correct order
if (_routeOrderManager != null) {
  _applyRouteOrdering();
}

// Ensure order field is set correctly before saving
for (int i = 0; i < _poiWaypoints.length; i++) {
  _poiWaypoints[i].order = i;
}

final route = DayRoute(
geometry: geometry,
distance: _previewDistance ?? widget.initial?.distance ?? 0,  // Preserve GPX distance
duration: _previewDuration ?? widget.initial?.duration ?? 0,  // Preserve GPX duration
routePoints: [], // Route points removed - routes are built from waypoints only
elevationProfile: _previewElevation.isNotEmpty ? _previewElevation : widget.initial?.elevationProfile,
ascent: _previewAscent ?? widget.initial?.ascent,
descent: _previewDescent ?? widget.initial?.descent,
poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList(),
routeType: isGpxSave ? RouteType.gpx : widget.initial?.routeType,  // Preserve routeType
);

if (!mounted) return;
context.pop(route);
} catch (e, stack) {
Log.e('route_builder', 'Build failed', e, stack);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to build route: $e')),
);
} finally {
if (mounted) setState(() => _busy = false);
}
}

Future<Map<String, dynamic>?> _directionsApiFallback(List<ll.LatLng> waypoints, String profile) async {
try {
final coords = waypoints.map((w) => '${w.longitude},${w.latitude}').join(';');
final url = Uri.parse(
'https://api.mapbox.com/directions/v5/mapbox/$profile/$coords'
'?geometries=geojson&overview=full&access_token=$mapboxPublicToken',
);

final res = await http.get(url);
if (res.statusCode != 200) return null;

final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
final route = (data['routes'] as List?)?.first as Map<String, dynamic>?;
if (route == null) return null;

return {
'geometry': route['geometry'],
'distance': route['distance'],
'duration': route['duration'],
};
} catch (e) {
Log.e('route_builder', 'Direct API failed', e);
return null;
}
}

double _calculateStraightDistance(List<ll.LatLng> points) {
double total = 0;
for (int i = 1; i < points.length; i++) {
total += _haversineMeters(points[i - 1], points[i]);
}
return total;
}

double _haversineMeters(ll.LatLng a, ll.LatLng b) {
const R = 6371000.0;
final dLat = (b.latitude - a.latitude) * pi / 180;
final dLon = (b.longitude - a.longitude) * pi / 180;
final lat1 = a.latitude * pi / 180;
final lat2 = b.latitude * pi / 180;
final a2 = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
return 2 * R * asin(sqrt(a2));
}

List<ll.LatLng> _coordsToLatLng(dynamic coordinates) {
if (coordinates is! List) return const <ll.LatLng>[];
if (coordinates.isEmpty) return const <ll.LatLng>[];
// Support both [[lng,lat], ...] and [{lng,lat}, ...]
if (coordinates.first is List) {
final list = coordinates
.map((e) => (e as List).map((n) => (n as num).toDouble()).toList())
.toList();
return list.map((c) => ll.LatLng(c[1], c[0])).toList();
} else if (coordinates.first is Map) {
final list = coordinates
.map((e) => {
'lat': ((e as Map)['lat'] as num).toDouble(),
'lng': (e['lng'] as num).toDouble(),
})
.toList();
return list.map((c) => ll.LatLng(c['lat']!, c['lng']!)).toList();
}
return const <ll.LatLng>[];
}

String _formatDuration(int seconds) {
final h = seconds ~/ 3600;
final m = (seconds % 3600) ~/ 60;
if (h > 0) return '${h}h ${m}m';
return '${m}m';
}

Future<void> _showMapTapActionPicker(BuildContext context, ll.LatLng latLng) async {
// This function is no longer used - waypoints are added via search bars only
// Keeping for backward compatibility but it does nothing
return;
}

/// Show waypoint dialog at a specific location (when adding via map tap from + button)
Future<void> _showWaypointDialogAtLocation(ll.LatLng latLng) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);

// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: latLng,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (result != null && mounted) {
// Add waypoint (route points are now waypoints too)
setState(() {
// Auto-assign time slot category if not set
if (result.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(result);
_poiWaypoints.add(result.copyWith(timeSlotCategory: autoCategory));
} else {
_poiWaypoints.add(result);
}
_initializeRouteOrdering(); // Reinitialize ordering after adding waypoint
});
// Calculate travel times after adding waypoint
_calculateTravelTimes();
// Fit map to show all waypoints after adding
_fitToWaypoints();
}
}

Future<void> _addWaypointAtLocation(WaypointType type, ll.LatLng position) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
preselectedType: type,
proximityBias: position,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (result != null && mounted) {
setState(() {
// Auto-assign time slot category if not set
final finalCategory = result.timeSlotCategory ?? autoAssignTimeSlotCategory(result);
final waypointWithCategory = result.copyWith(timeSlotCategory: finalCategory);
_poiWaypoints.add(waypointWithCategory);

// Reinitialize ordering after adding waypoint
_initializeRouteOrdering();
});
// Calculate travel times after adding waypoint
_calculateTravelTimes();
// Fit map to show all waypoints after adding
_fitToWaypoints();
}
}

// _showWaypointEditorFromPlace removed - now using _showAddWaypointDialog with preselectedPlace parameter

Future<void> _editWaypoint(RouteWaypoint waypoint) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom and all interactions when dialog opens
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
existingWaypoint: waypoint,
proximityBias: waypoint.position,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (!mounted) return;

// Handle deletion (empty name signals deletion)
if (result != null && result.name.isEmpty) {
  setState(() {
    final deletedWp = waypoint;
    _poiWaypoints.removeWhere((w) => w.id == waypoint.id);
    
    // Clean up orphaned choice groups
    if (deletedWp.choiceGroupId != null) {
      final remaining = _poiWaypoints
          .where((w) => w.choiceGroupId == deletedWp.choiceGroupId)
          .toList();
      if (remaining.length <= 1) {
        for (final wp in remaining) {
          final idx = _poiWaypoints.indexWhere((w) => w.id == wp.id);
          if (idx >= 0) {
            _poiWaypoints[idx] = _poiWaypoints[idx].copyWith(
              choiceGroupId: null,
              choiceLabel: null,
            );
          }
        }
      }
    }
    
    _renumberWaypoints();
    _initializeRouteOrdering();
  });
  
  // Clear route preview if fewer than 2 waypoints remain
  if (_poiWaypoints.length < 2) {
    _clearRoutePreview();
    Log.i('route_builder', '🧹 Cleared route preview after deletion (${_poiWaypoints.length} waypoints remaining)');
  } else {
    // Recalculate route with remaining waypoints
    _calculateTravelTimes();
    _updatePreview();
  }
}
// Only update if user saved changes (result is not null and has a name)
else if (result != null && result.name.isNotEmpty) {
  setState(() {
    final index = _poiWaypoints.indexWhere((w) => w.id == waypoint.id);
    if (index >= 0) {
      _poiWaypoints[index] = result;
    } else {
      // Waypoint not found, add it (shouldn't happen but handle gracefully)
      _poiWaypoints.add(result);
      _initializeRouteOrdering();
    }
  });
  // Recalculate travel times after updating waypoint
  _calculateTravelTimes();
  // Fit map to show all waypoints after updating
  _fitToWaypoints();
  
  // Auto-update preview to show route line when there are 2+ waypoints
  if (_poiWaypoints.length >= 2) {
    _updatePreview();
  }
}
// If result is null, user cancelled - don't delete, just close
}

Future<void> _deleteWaypoint(RouteWaypoint waypoint) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final confirmed = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: const Text('Delete Waypoint'),
content: Text('Are you sure you want to delete "${waypoint.name}"?'),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(false),
child: const Text('Cancel'),
),
TextButton(
onPressed: () => Navigator.of(context).pop(true),
style: TextButton.styleFrom(foregroundColor: Colors.red),
child: const Text('Delete'),
),
],
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (confirmed == true && mounted) {
setState(() {
_poiWaypoints.removeWhere((w) => w.id == waypoint.id);
// Reinitialize ordering after deletion
_initializeRouteOrdering();
});
}
}


/// Initialize ordering for route waypoints
void _initializeRouteOrdering() {
  _routeOrderManager = DayPlanOrderBuilder.buildFromWaypoints(1, _poiWaypoints);
}

/// Get waypoints by section ID
Map<String, List<RouteWaypoint>> _getRouteWaypointsBySectionId() {
  // Initialize map explicitly to avoid JavaScript compilation issues
  final map = Map<String, List<RouteWaypoint>>();
  
  // Handle empty waypoints
  if (_poiWaypoints.isEmpty) {
    return map;
  }
  
  for (final wp in _poiWaypoints) {
    String? sectionId;
    switch (wp.type) {
      case WaypointType.restaurant:
        sectionId = 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
        break;
      case WaypointType.bar:
        sectionId = 'barSection_${wp.mealTime?.name ?? "dinner"}';
        break;
      case WaypointType.activity:
      case WaypointType.attraction:
        sectionId = 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
        break;
      case WaypointType.accommodation:
        sectionId = 'accommodationSection';
        break;
      case WaypointType.servicePoint:
      case WaypointType.service:
      case WaypointType.viewingPoint:
      case WaypointType.routePoint:
        // These are individual items, not sections
        break;
    }
    if (sectionId != null) {
      map.putIfAbsent(sectionId, () => <RouteWaypoint>[]).add(wp);
    }
  }
  
  return map;
}

/// Get waypoints by ID
Map<String, RouteWaypoint> _getRouteWaypointsById() {
  return { for (final wp in _poiWaypoints) wp.id: wp };
}

/// Move an item up
void _moveRouteItemUp(String itemId) {
  if (_routeOrderManager == null) return;
  
  setState(() {
    _routeOrderManager = _routeOrderManager!.moveUp(itemId);
    _applyRouteOrdering();
  });
}

/// Move an item down
void _moveRouteItemDown(String itemId) {
  if (_routeOrderManager == null) return;
  
  setState(() {
    _routeOrderManager = _routeOrderManager!.moveDown(itemId);
    _applyRouteOrdering();
  });
}

/// Apply ordering to waypoints
void _applyRouteOrdering() {
  if (_routeOrderManager == null) return;
  
  final orderedItems = _routeOrderManager!.sortedItems;
  final reorderedWaypoints = <RouteWaypoint>[];
  
  for (final item in orderedItems) {
    if (item.isSection) {
      // Add all waypoints in this section
      final sectionId = item.id;
      final sectionWaypoints = _poiWaypoints.where((wp) {
        String? wpSectionId;
        switch (wp.type) {
          case WaypointType.restaurant:
            wpSectionId = 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
            break;
          case WaypointType.activity:
            wpSectionId = 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
            break;
          case WaypointType.accommodation:
            wpSectionId = 'accommodationSection';
            break;
          default:
            break;
        }
        return wpSectionId == sectionId;
      }).toList();
      reorderedWaypoints.addAll(sectionWaypoints);
    } else if (item.isIndividualWaypoint && item.waypointId != null) {
      // Add this individual waypoint
      final wp = _poiWaypoints.firstWhere(
        (w) => w.id == item.waypointId,
        orElse: () => _poiWaypoints.first, // Fallback (shouldn't happen)
      );
      if (!reorderedWaypoints.contains(wp)) {
        reorderedWaypoints.add(wp);
      }
    }
  }
  
  // Add any remaining waypoints
  for (final wp in _poiWaypoints) {
    if (!reorderedWaypoints.contains(wp)) {
      reorderedWaypoints.add(wp);
    }
  }
  
  // Update order field to reflect new positions
  for (int i = 0; i < reorderedWaypoints.length; i++) {
    reorderedWaypoints[i].order = i;
  }
  
  _poiWaypoints.clear();
  _poiWaypoints.addAll(reorderedWaypoints);
  
  // Fit map to show all waypoints after reordering
  _fitToWaypoints();
}

Widget _buildWaypointsSection() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _waypointsExpanded = !_waypointsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _waypointsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Waypoints (${_poiWaypoints.length})',
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: context.colors.primary,
                  onPressed: () => _showAddWaypointDialog(),
                  tooltip: 'Add Waypoint',
                ),
              ],
            ),
          ),
        ),

        // Sequential waypoint list with drag-and-drop
        if (_waypointsExpanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SequentialWaypointList(
                waypoints: _poiWaypoints,
                onEdit: _editWaypoint,
                onDelete: (waypoint) {
                  setState(() {
                    _poiWaypoints.removeWhere((w) => w.id == waypoint.id);
                    _renumberWaypoints();
                  });
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _poiWaypoints.removeAt(oldIndex);
                    _poiWaypoints.insert(newIndex, item);
                    _renumberWaypoints();
                  });
                  // Fit map to show all waypoints after reordering
                  _fitToWaypoints();
                  // Recalculate travel times after reordering
                  _calculateTravelTimes();
                },
                onWaypointsChanged: (updatedWaypoints) {
                  setState(() {
                    _poiWaypoints.clear();
                    _poiWaypoints.addAll(updatedWaypoints);
                    _renumberWaypoints();
                  });
                  // Fit map to show all waypoints after updating
                  _fitToWaypoints();
                },
                onTravelModeChanged: (waypoint, newMode) async {
                  // Recalculate distance/time with new transportation mode
                  await _recalculateTravelForWaypoint(waypoint, newMode);
                },
              ),
            ),
                        ),
                      ],
                    ),
  );
}

/// Renumber waypoints sequentially (1, 2, 3...)
/// Handles choice groups by keeping waypoints with same choiceGroupId at same order
void _renumberWaypoints() {
  Log.i('route_builder', '🔢 _renumberWaypoints called with ${_poiWaypoints.length} waypoints');
  for (final wp in _poiWaypoints) {
    Log.i('route_builder', '  BEFORE: ${wp.name} order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
  
  // Sort by current order first
  _poiWaypoints.sort((a, b) {
    final orderCompare = a.order.compareTo(b.order);
    if (orderCompare != 0) return orderCompare;
    // If same order, maintain stable sort (for choice groups)
    return a.id.compareTo(b.id);
  });
  
  // Work on a snapshot to avoid read-during-mutation issues
  final snapshot = List<RouteWaypoint>.from(_poiWaypoints);
  
  // Assign sequential order numbers, keeping choice groups together
  int order = 1;
  String? lastChoiceGroupId;
  int? lastAssignedOrder;
  
  for (int i = 0; i < snapshot.length; i++) {
    final wp = snapshot[i];
    // If this waypoint is in a choice group
    if (wp.choiceGroupId != null) {
      // If this is a new choice group, assign current order first, then increment
      if (wp.choiceGroupId != lastChoiceGroupId) {
        lastChoiceGroupId = wp.choiceGroupId;
        lastAssignedOrder = order;
        order++; // Increment for next group
      }
      // Assign the same order as other waypoints in this choice group
      _poiWaypoints[i] = _poiWaypoints[i].copyWith(order: lastAssignedOrder!);
    } else {
      // Individual waypoint - assign current order, then increment
      _poiWaypoints[i] = _poiWaypoints[i].copyWith(order: order);
      lastAssignedOrder = order;
      lastChoiceGroupId = null;
      order++; // Increment for next waypoint
    }
  }
  
  Log.i('route_builder', '🔢 _renumberWaypoints complete:');
  for (final wp in _poiWaypoints) {
    Log.i('route_builder', '  AFTER: ${wp.name} order=${wp.order} choiceGroupId=${wp.choiceGroupId}');
  }
}

/// Clear all route preview data (geometry, segments, distance, duration, elevation)
/// Called when waypoints are deleted and route is no longer valid
void _clearRoutePreview() {
  Log.i('route_builder', '🧹 Clearing route preview data');
  setState(() {
    _previewGeometry = null;
    _previewRouteSegments = null;
    _previewDistance = null;
    _previewDuration = null;
    _previewElevation = const [];
    _previewAscent = null;
    _previewDescent = null;
  });
}

/// Calculate travel times and distances between consecutive waypoints
/// Handles OR conditions by calculating distances from all previous waypoint options
Future<void> _calculateTravelTimes() async {
  if (_poiWaypoints.length < 2) return;

  // Group waypoints by order for choice group handling
  final grouped = <int, List<RouteWaypoint>>{};
  for (final wp in _poiWaypoints) {
    if (wp.position.latitude != null && wp.position.longitude != null) {
      grouped.putIfAbsent(wp.order, () => <RouteWaypoint>[]).add(wp);
    }
  }

  final sortedOrders = grouped.keys.toList()..sort();
  if (sortedOrders.length < 2) return;

  final travelService = TravelCalculatorService();

  // For each adjacent pair of order groups, calculate all route combinations (cartesian product)
  for (int i = 0; i < sortedOrders.length - 1; i++) {
    final fromOrder = sortedOrders[i];
    final toOrder = sortedOrders[i + 1];
    final fromWaypoints = grouped[fromOrder]!;
    final toWaypoints = grouped[toOrder]!;

    // Cartesian product: every fromWp → every toWp
    for (final fromWp in fromWaypoints) {
      for (final toWp in toWaypoints) {
        TravelInfo? travelInfo;
        
        // Check if this is a GPX route and waypoints have snap info
        final isGpxRoute = widget.initial?.routeType == RouteType.gpx ||
            (widget.initial?.routeType == null &&
             widget.initial?.routePoints.isEmpty == true &&
             widget.initial?.geometry['coordinates'] is List &&
             (widget.initial?.geometry['coordinates'] as List).length > 100);
        
        // Check if activity supports GPX (hike/ski/biking/climbing)
        final supportsGpx = supportsGpxRoute(widget.activityCategory);
        
        if (isGpxRoute && supportsGpx) {
          // GPX Flow: Skip per-segment distance calculations for supported activities
          // Waypoints are just POIs along the route, not route-defining points
          // Total distance/duration come from the GPX itself
          // Don't assign travel info to individual waypoints - they're not route segments
          continue; // Skip this segment calculation
        } else if (isGpxRoute) {
          // Legacy GPX behavior for non-supported activities
          // Use calculateTravelWithGpx() service method which handles this correctly
          if (widget.initial?.geometry['coordinates'] is List) {
            final coords = widget.initial!.geometry['coordinates'] as List;
            final trackPoints = _coordsToLatLng(coords);
            
            // Create GpxRoute model from widget.initial data
            final gpxRoute = GpxRoute(
              name: widget.initial?.routeType == RouteType.gpx ? 'GPX Route' : null,
              trackPoints: trackPoints,
              simplifiedPoints: trackPoints, // Use same points for now
              totalDistanceKm: (widget.initial?.distance ?? 0.0) / 1000.0,
              totalElevationGainM: widget.initial?.ascent,
              estimatedDuration: widget.initial?.duration != null 
                  ? Duration(seconds: widget.initial!.duration) 
                  : null,
              bounds: GpxRoute.createBounds(trackPoints),
              importedAt: DateTime.now(),
              fileName: 'route',
            );
            
            // Use the service method which correctly calculates segment distances
            travelInfo = await travelService.calculateTravelWithGpx(
              from: fromWp.position,
              to: toWp.position,
              gpxRoute: gpxRoute,
              activityCategory: widget.activityCategory,
            );
            
            if (travelInfo == null) {
              // Service returned null - skip this waypoint
              continue;
            }
          } else {
            // No geometry available - skip
            continue;
          }
        } else {
          // Use standard Directions API calculation
    // Use existing travel mode if set, otherwise let service choose
        final travelMode = toWp.travelMode != null
        ? TravelMode.values.firstWhere(
                (tm) => tm.name == toWp.travelMode,
            orElse: () => TravelMode.walking,
          )
        : null;
    
          travelInfo = await travelService.calculateTravel(
          from: fromWp.position,
          to: toWp.position,
      travelMode: travelMode,
          includeGeometry: true, // Request geometry for route preview
          activityCategory: widget.activityCategory,
    );
        }
    
    if (travelInfo != null && mounted) {
                        setState(() {
            final index = _poiWaypoints.indexWhere((w) => w.id == toWp.id);
        if (index >= 0) {
              // Store geometry and travel info on the destination waypoint
              // For choice groups, we store the primary route (first combination)
              // In the future, we may need per-segment storage
          if (fromWp == fromWaypoints.first && travelInfo != null) {
            final updatedWaypoint = _poiWaypoints[index].copyWith(
              travelMode: toWp.travelMode ?? travelInfo.travelMode.name,
            travelTime: travelInfo.durationSeconds,
            travelDistance: travelInfo.distanceMeters.toDouble(),
                  travelRouteGeometry: travelInfo.routeGeometry,
          );
            _poiWaypoints[index] = updatedWaypoint;
            Log.i('route_builder', '✅ Updated ${toWp.name}: distance=${travelInfo.distanceMeters}m, time=${travelInfo.durationSeconds}s');
              }
        }
      });
        }
      }
    }
  }
}

/// Recalculate travel for a specific waypoint when transportation mode changes
Future<void> _recalculateTravelForWaypoint(RouteWaypoint waypoint, String newMode) async {
  final sortedWaypoints = List<RouteWaypoint>.from(_poiWaypoints)
    ..sort((a, b) => a.order.compareTo(b.order));
  
  final waypointIndex = sortedWaypoints.indexWhere((w) => w.id == waypoint.id);
  if (waypointIndex < 1) return; // No previous waypoint
  
  final currentOrder = waypoint.order;
  final previousWaypoints = sortedWaypoints
      .where((w) => w.order < currentOrder)
      .toList()
    ..sort((a, b) => b.order.compareTo(a.order));
  
  if (previousWaypoints.isEmpty) return;
  
  final maxOrder = previousWaypoints.first.order;
  final previousGroup = previousWaypoints
      .where((w) => w.order == maxOrder)
      .toList();
  
  final fromWaypoint = previousGroup.first;
  final travelMode = TravelMode.values.firstWhere(
    (tm) => tm.name == newMode,
    orElse: () => TravelMode.walking,
  );
  
  final travelService = TravelCalculatorService();
  final travelInfo = await travelService.calculateTravel(
    from: fromWaypoint.position,
    to: waypoint.position,
    travelMode: travelMode,
    includeGeometry: true, // Request geometry for route preview
    activityCategory: widget.activityCategory,
  );
  
  if (travelInfo != null && mounted) {
    setState(() {
      final index = _poiWaypoints.indexWhere((w) => w.id == waypoint.id);
      if (index >= 0) {
        _poiWaypoints[index] = _poiWaypoints[index].copyWith(
          travelMode: newMode,
          travelTime: travelInfo.durationSeconds,
          travelDistance: travelInfo.distanceMeters.toDouble(),
          travelRouteGeometry: travelInfo.routeGeometry,
        );
      }
    });
    
    // Auto-update preview to show route line when there are 2+ waypoints
    if (_poiWaypoints.length >= 2) {
      _updatePreview();
    }
  }
}

/// Handle new waypoint addition with auto-grouping detection
Future<void> _handleNewWaypoint(RouteWaypoint newWaypoint) async {
  // Assign sequential order number
  final nextOrder = _poiWaypoints.isEmpty ? 1 : (_poiWaypoints.map((w) => w.order ?? 0).reduce((a, b) => a > b ? a : b) + 1);
  var waypointWithOrder = newWaypoint.copyWith(order: nextOrder);

  // Check for auto-grouping
  final groupingService = WaypointGroupingService();
  final existingMatch = groupingService.shouldAutoGroup(_poiWaypoints, waypointWithOrder);

  if (existingMatch != null) {
    // Show auto-grouping prompt
    final shouldGroup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group as Choice?'),
        content: Text(
          'This looks like an alternative to "${existingMatch.name}". '
          'Group as choice?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, keep separate'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
      ],
    ),
    );

    if (shouldGroup == true && mounted) {
      // Group as choice
      final choiceGroupId = existingMatch.choiceGroupId ?? const Uuid().v4();
      final choiceLabel = existingMatch.choiceLabel ?? 
          groupingService.generateAutoChoiceLabel(
            waypointWithOrder.type,
            waypointWithOrder.suggestedStartTime,
            waypointWithOrder.mealTime,
            waypointWithOrder.activityTime,
          );

      // Update existing waypoint if it doesn't have choiceGroupId yet
      if (existingMatch.choiceGroupId == null) {
        final existingIndex = _poiWaypoints.indexWhere((w) => w.id == existingMatch.id);
        if (existingIndex >= 0) {
          _poiWaypoints[existingIndex] = existingMatch.copyWith(
            choiceGroupId: choiceGroupId,
            choiceLabel: choiceLabel,
          );
        }
      }

      // Set choice group for new waypoint
      waypointWithOrder = waypointWithOrder.copyWith(
        order: existingMatch.order,
        choiceGroupId: choiceGroupId,
        choiceLabel: choiceLabel,
      );
    } else if (shouldGroup == false && mounted) {
      // Keep separate - order is already set to nextOrder
      // No changes needed
    }
  }

  // Add waypoint - ensure it has a timeSlotCategory
  if (mounted) {
    setState(() {
      // Auto-assign time slot category if not set
      final finalCategory = waypointWithOrder.timeSlotCategory ?? autoAssignTimeSlotCategory(waypointWithOrder);
      final waypointWithCategory = waypointWithOrder.copyWith(timeSlotCategory: finalCategory);
      _poiWaypoints.add(waypointWithCategory);
      _renumberWaypoints(); // Ensure sequential ordering
    });
    
    // Fit map to show all waypoints after adding
    _fitToWaypoints();
    
    // Calculate travel times after adding waypoint
    _calculateTravelTimes();
    
    // Auto-update preview to show route line when there are 2+ waypoints
    if (_poiWaypoints.length >= 2) {
      _updatePreview();
    }
  }
}

/// Ungroup a choice group - removes choiceGroupId and choiceLabel from all waypoints in the group
/// and assigns sequential order numbers
void _ungroupChoiceGroup(String choiceGroupId) {
  Log.i('route_builder', '🔴 Ungrouping choice group: $choiceGroupId');
  
  // Find all waypoints in this choice group
  final waypointsInGroup = _poiWaypoints
      .where((w) => w.choiceGroupId == choiceGroupId)
      .toList();
  
  Log.i('route_builder', 'Found ${waypointsInGroup.length} waypoints in group');
  
  if (waypointsInGroup.isEmpty) {
    Log.w('route_builder', 'No waypoints found in group, returning');
    return;
  }
  
  // Get the base order (the order of the first waypoint in the group)
  final baseOrder = waypointsInGroup.first.order;
  
  // Single setState for consistent state - ungroup and renumber together
  setState(() {
    // Remove choice group info and assign sequential orders
    for (int i = 0; i < waypointsInGroup.length; i++) {
      final wp = waypointsInGroup[i];
      final index = _poiWaypoints.indexWhere((w) => w.id == wp.id);
      if (index >= 0) {
        _poiWaypoints[index] = _poiWaypoints[index].copyWith(
          choiceGroupId: null,
          choiceLabel: null,
          order: baseOrder + i,
        );
      }
    }
    // Renumber all waypoints to ensure sequential ordering
    _renumberWaypoints();
  });
  
  // Recalculate travel times after ungrouping
  _calculateTravelTimes();
  
  // Auto-update preview to show route line when there are 2+ waypoints
  if (_poiWaypoints.length >= 2) {
    _updatePreview();
  }
}

Future<void> _showAddWaypointDialogForCategory(TimeSlotCategory category) async {
WaypointType? preselectedType;

// Determine preselected type based on category
switch (category) {
case TimeSlotCategory.breakfast:
case TimeSlotCategory.lunch:
case TimeSlotCategory.dinner:
preselectedType = WaypointType.restaurant;
break;
case TimeSlotCategory.morningActivity:
case TimeSlotCategory.allDayActivity:
case TimeSlotCategory.afternoonActivity:
case TimeSlotCategory.eveningActivity:
preselectedType = WaypointType.activity;
break;
case TimeSlotCategory.accommodation:
preselectedType = WaypointType.accommodation;
break;
case TimeSlotCategory.logisticsGear:
case TimeSlotCategory.logisticsTransportation:
case TimeSlotCategory.logisticsFood:
preselectedType = WaypointType.servicePoint;
break;
case TimeSlotCategory.viewingPoint:
preselectedType = WaypointType.viewingPoint;
break;
}

// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);

final center = _getCameraCenter(); // Use helper method
// Set flag and disable map scroll zoom when dialog opens
setState(() => _dialogOrBottomSheetOpen = true);
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: center,
excludeRoutePoint: true,
preselectedType: preselectedType,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (result != null && mounted) {
  await _handleNewWaypoint(result);
}
}

/// Handle map tap to add waypoint at tapped location
/// This allows users to add waypoints by tapping on the map or POIs
/// When user taps near a POI, we'll search for places at that location
/// Add an alternative waypoint (OR option) to an existing waypoint
/// Groups an existing waypoint with the source waypoint as a choice group
Future<void> _addAlternativeWaypoint(RouteWaypoint sourceWaypoint) async {
  // Filter available waypoints: exclude source and any already in the same choice group
  final availableWaypoints = _poiWaypoints.where((wp) {
    // Exclude the source waypoint itself
    if (wp.id == sourceWaypoint.id) return false;
    // Exclude waypoints already in the same choice group
    if (sourceWaypoint.choiceGroupId != null && 
        wp.choiceGroupId == sourceWaypoint.choiceGroupId) {
      return false;
    }
    return true;
  }).toList();

  // If no available waypoints, don't show the dialog
  if (availableWaypoints.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other waypoints available to group with'),
        ),
      );
    }
    return;
  }

  // Set flag to prevent map taps while dialog is open
  setState(() => _dialogOrBottomSheetOpen = true);
  // Disable map scroll zoom when dialog opens
  _mapboxController?.disableInteractions();

  final selectedWaypoint = await showDialog<RouteWaypoint>(
    context: context,
    builder: (context) => _SelectWaypointForGroupDialog(
      availableWaypoints: availableWaypoints,
      sourceWaypoint: sourceWaypoint,
    ),
  );

  // Clear flag when dialog closes
  if (mounted) {
    setState(() => _dialogOrBottomSheetOpen = false);
    // Re-enable map scroll zoom when dialog closes
    _mapboxController?.enableInteractions();
  }

  if (selectedWaypoint != null && mounted) {
    // Get or create choice group ID
    final choiceGroupId = sourceWaypoint.choiceGroupId ?? const Uuid().v4();
    final groupingService = WaypointGroupingService();
    final choiceLabel = sourceWaypoint.choiceLabel ?? 
        groupingService.generateAutoChoiceLabel(
          sourceWaypoint.type,
          sourceWaypoint.suggestedStartTime,
          sourceWaypoint.mealTime,
          sourceWaypoint.activityTime,
        );

    // Consolidate all updates into a single setState
      final sourceIndex = _poiWaypoints.indexWhere((w) => w.id == sourceWaypoint.id);
    final selectedIndex = _poiWaypoints.indexWhere((w) => w.id == selectedWaypoint.id);
    
    if (selectedIndex >= 0) {
        setState(() {
        // 1. Update source waypoint if it doesn't have choiceGroupId yet
        if (sourceIndex >= 0 && sourceWaypoint.choiceGroupId == null) {
          _poiWaypoints[sourceIndex] = sourceWaypoint.copyWith(
            choiceGroupId: choiceGroupId,
            choiceLabel: choiceLabel,
          );
        }
        
        // 2. Update selected waypoint to join the choice group
        final oldChoiceGroupId = selectedWaypoint.choiceGroupId;
        _poiWaypoints[selectedIndex] = selectedWaypoint.copyWith(
          order: sourceWaypoint.order, // Same order as source waypoint
          choiceGroupId: choiceGroupId,
          choiceLabel: choiceLabel,
        );
        
        // 3. Clean up orphaned choice groups
        if (oldChoiceGroupId != null && oldChoiceGroupId != choiceGroupId) {
          final remainingInOldGroup = _poiWaypoints
              .where((w) => w.choiceGroupId == oldChoiceGroupId)
              .toList();
          
          // If only 1 or 0 members left, remove choice group from all
          if (remainingInOldGroup.length <= 1) {
            for (final wp in remainingInOldGroup) {
              final idx = _poiWaypoints.indexWhere((w) => w.id == wp.id);
              if (idx >= 0) {
                _poiWaypoints[idx] = _poiWaypoints[idx].copyWith(
                  choiceGroupId: null,
                  choiceLabel: null,
                );
              }
            }
          }
        }
        
        // 4. Renumber ONCE after all mutations
        _renumberWaypoints();
      });
    }

    // Fit map to show all waypoints after grouping
    _fitToWaypoints();
    
    // Recalculate travel times after grouping (order may have changed)
    _calculateTravelTimes();
    
    // Auto-update preview to show route line when there are 2+ waypoints
    if (_poiWaypoints.length >= 2) {
      _updatePreview();
    }
}
}

Future<void> _showAddWaypointDialog({PlaceDetails? preselectedPlace}) async {
// Show the waypoint dialog directly (using user's current map center as proximity bias)
// Exclude routePoint type since this is for POI waypoints only
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);

final center = preselectedPlace?.location ?? _getCameraCenter(); // Use place location if provided
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: center,
excludeRoutePoint: true,
preselectedPlace: preselectedPlace,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (result != null && mounted) {
  await _handleNewWaypoint(result);
}
}
}

// --- Floating UI pieces ---

bool _hintDismissed = false; // module-level to persist within session

extension _HintLogic on _RouteBuilderScreenState {
bool get _shouldShowHint => !_hintDismissed && _poiWaypoints.isEmpty;
}

class _HintChip extends StatelessWidget {
final String text; final VoidCallback onDismiss;
const _HintChip({required this.text, required this.onDismiss});
@override
Widget build(BuildContext context) => Material(
color: Colors.transparent,
child: Container(
constraints: const BoxConstraints(maxWidth: 280),
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.85),
borderRadius: BorderRadius.circular(999),
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
),
child: Row(mainAxisSize: MainAxisSize.min, children: [
const Icon(Icons.info_outline, color: Colors.white, size: 14),
const SizedBox(width: 8),
Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
const SizedBox(width: 8),
InkWell(onTap: onDismiss, child: const Icon(Icons.close, color: Colors.white, size: 16)),
]),
),
);
}

class _ZoomControls extends StatelessWidget {
final VoidCallback onZoomIn; 
final VoidCallback onZoomOut;
final VoidCallback? onFitWaypoints;
const _ZoomControls({
  required this.onZoomIn, 
  required this.onZoomOut,
  this.onFitWaypoints,
});
@override
Widget build(BuildContext context) => Material(
color: Colors.transparent,
child: Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
),
child: Column(mainAxisSize: MainAxisSize.min, children: [
_IconBtn(icon: Icons.add, onTap: onZoomIn),
Container(height: 1, width: 44, color: Colors.grey.shade200),
_IconBtn(icon: Icons.remove, onTap: onZoomOut),
if (onFitWaypoints != null) ...[
  Container(height: 1, width: 44, color: Colors.grey.shade200),
  _IconBtn(icon: Icons.fit_screen, onTap: onFitWaypoints!),
],
]),
),
);
}

class _IconBtn extends StatelessWidget {
final IconData icon; final VoidCallback onTap;
const _IconBtn({required this.icon, required this.onTap});
@override
Widget build(BuildContext context) => InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(12),
child: SizedBox(
width: 44,
height: 44,
child: Icon(icon, size: 20, color: Colors.grey.shade700),
),
);
}

class _SmallControlButton extends StatelessWidget {
final IconData icon; final String label; final VoidCallback onTap;
const _SmallControlButton({required this.icon, required this.label, required this.onTap});
@override
Widget build(BuildContext context) => Material(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
elevation: 4,
shadowColor: Colors.black.withValues(alpha: 0.2),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(12),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
child: Row(mainAxisSize: MainAxisSize.min, children: [
Icon(icon, size: 18, color: Colors.grey.shade800),
const SizedBox(width: 6),
Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
]),
),
),
);
}

class _FloatingSearchBar extends StatefulWidget {
final TextEditingController controller; final FocusNode focusNode; final bool searching;
final List<PlaceSuggestion> results; final ValueChanged<String> onChanged; final VoidCallback onClear;
final ValueChanged<PlaceSuggestion> onSelect;
// When inside desktop map area, the parent may provide padding/width overrides
final double? mapAreaPaddingLeft; // left offset padding inside map area
final double? mapAreaWidth; // explicit width of map area; if null, uses screen width
final bool usePositioned; // If false, don't wrap in Positioned (for use in Column/ListView)
const _FloatingSearchBar({
required this.controller,
required this.focusNode,
required this.searching,
required this.results,
required this.onChanged,
required this.onClear,
required this.onSelect,
this.mapAreaPaddingLeft,
this.mapAreaWidth,
this.usePositioned = true, // Default to true for backward compatibility
});
@override
State<_FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<_FloatingSearchBar> {
bool _focused = false;

@override
void initState() {
super.initState();
widget.focusNode.addListener(_onFocusChange);
}

@override
void didUpdateWidget(covariant _FloatingSearchBar oldWidget) {
super.didUpdateWidget(oldWidget);
if (oldWidget.focusNode != widget.focusNode) {
oldWidget.focusNode.removeListener(_onFocusChange);
widget.focusNode.addListener(_onFocusChange);
_focused = widget.focusNode.hasFocus;
}
}

@override
void dispose() {
widget.focusNode.removeListener(_onFocusChange);
super.dispose();
}

void _onFocusChange() => setState(() => _focused = widget.focusNode.hasFocus);

@override
Widget build(BuildContext context) {
final size = MediaQuery.of(context).size;
final isMobile = size.width < 600;
final barWidth = isMobile ? size.width * 0.9 : 400.0;
final containerWidth = widget.mapAreaWidth ?? size.width;
final leftOffset = ((containerWidth - barWidth) / 2) + (widget.mapAreaPaddingLeft ?? 0);
// Single-layer decoration: outer container owns all visuals; TextField has no decoration
final borderColor = _focused ? context.colors.primary : Colors.grey.shade300;
final boxShadow = [
BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
if (_focused) BoxShadow(color: context.colors.primary.withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 2),
];

final searchContent = Column(mainAxisSize: MainAxisSize.min, children: [
// SINGLE container - no nesting, TextField has collapsed decoration
Material(
color: Colors.transparent,
child: Container(
height: 48,
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(24),
border: Border.all(color: borderColor, width: _focused ? 2 : 1),
boxShadow: boxShadow,
),
child: ClipRRect(
borderRadius: BorderRadius.circular(24),
child: Row(children: [
const SizedBox(width: 16),
Icon(Icons.search, color: _focused ? context.colors.primary : Colors.grey.shade500, size: 20),
const SizedBox(width: 12),
Expanded(
// Ensure no inner focus/enable borders appear from global theme
child: Theme(
data: Theme.of(context).copyWith(
inputDecorationTheme: const InputDecorationTheme(
border: InputBorder.none,
focusedBorder: InputBorder.none,
enabledBorder: InputBorder.none,
errorBorder: InputBorder.none,
disabledBorder: InputBorder.none,
),
),
child: TextField(
controller: widget.controller,
focusNode: widget.focusNode,
onChanged: widget.onChanged,
style: const TextStyle(fontSize: 15),
cursorColor: context.colors.primary,
decoration: InputDecoration.collapsed(
hintText: 'Search location...',
hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
),
),
),
),
if (widget.controller.text.isNotEmpty)
GestureDetector(
onTap: () {
widget.controller.clear();
widget.onClear();
},
child: Padding(
padding: const EdgeInsets.all(12),
child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
),
)
else if (widget.searching)
const Padding(
padding: EdgeInsets.all(14),
child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
)
else
const SizedBox(width: 16),
]),
),
),
),
if (widget.results.isNotEmpty)
Container(
margin: const EdgeInsets.only(top: 8),
constraints: const BoxConstraints(maxHeight: 240),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(16),
child: ListView.separated(
shrinkWrap: true,
padding: const EdgeInsets.symmetric(vertical: 8),
itemCount: widget.results.length,
separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: Colors.grey.shade200),
itemBuilder: (context, index) {
final result = widget.results[index];
return ListTile(
dense: true,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
leading: Container(
width: 36,
height: 36,
decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
child: Icon(result.isPoi ? Icons.place : Icons.location_city, size: 18, color: context.colors.primary),
),
title: Text(result.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
subtitle: Text(result.placeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
onTap: () => widget.onSelect(result),
);
},
),
),
),
]);

// If usePositioned is false, return content directly (for use in Column/ListView)
if (!widget.usePositioned) {
  return SizedBox(
    width: double.infinity,
    child: searchContent,
  );
}

// Otherwise, wrap in Positioned for Stack parent
return Positioned(
  top: isMobile ? 56 + 12 : 12, // kToolbarHeight is typically 56
  left: leftOffset,
  width: barWidth,
  child: searchContent,
);
}
}

class _BottomPanel extends StatelessWidget {
final List<RouteWaypoint> poiWaypoints;
final double? previewDistance; final int? previewDuration;
final List<ElevationPoint> elevation; final double? ascent; final double? descent;
final bool busy;
final VoidCallback onAddWaypoint; final void Function(RouteWaypoint) onEditWaypoint;
final VoidCallback? onPreview; final VoidCallback? onSave;
final void Function(int oldIndex, int newIndex) onReorder;
final DayPlanOrderManager? routeOrderManager;
final void Function(String) onMoveUp;
final void Function(String) onMoveDown;
final bool Function(String) canMoveUp;
final bool Function(String) canMoveDown;
final VoidCallback onInitializeOrdering;
final Future<void> Function(RouteWaypoint waypoint, String newMode) onTravelModeChanged;
final Future<void> Function(RouteWaypoint waypoint) onAddAlternative;
final void Function(RouteWaypoint updatedWaypoint)? onWaypointUpdated;
final void Function(List<RouteWaypoint> updatedWaypoints)? onBulkWaypointUpdate;
final VoidCallback? onOrderChanged;
final void Function(String choiceGroupId)? onUngroup;
final bool skipTravelSegments; // Skip travel segments for GPX routes with supported activities

const _BottomPanel({
required this.poiWaypoints,
required this.previewDistance,
required this.previewDuration,
required this.elevation,
required this.ascent,
required this.descent,
required this.busy,
required this.onAddWaypoint,
required this.onEditWaypoint,
required this.onPreview,
required this.onSave,
required this.onReorder,
required this.routeOrderManager,
required this.onMoveUp,
required this.onMoveDown,
required this.canMoveUp,
required this.canMoveDown,
required this.onInitializeOrdering,
required this.onTravelModeChanged,
required this.onAddAlternative,
this.onWaypointUpdated,
this.onBulkWaypointUpdate,
this.onOrderChanged,
this.onUngroup,
this.skipTravelSegments = false,
});

@override
Widget build(BuildContext context) => DraggableScrollableSheet(
initialChildSize: 0.24,
minChildSize: 0.16,
maxChildSize: 0.8,
builder: (context, controller) {
final size = MediaQuery.of(context).size;
final isDesktop = size.width >= 1024;
final panelContent = Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const SizedBox(height: 8),
Center(
child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
),
// Waypoints Section
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
child: Align(
alignment: Alignment.center,
child: ConstrainedBox(
constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
child: Row(children: [
Text('Waypoints', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
child: Text('${poiWaypoints.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
),
const Spacer(),
IconButton(
onPressed: onAddWaypoint,
style: IconButton.styleFrom(backgroundColor: context.colors.primary.withValues(alpha: 0.1)),
icon: Icon(Icons.add, color: context.colors.primary),
tooltip: 'Add waypoint',
),
]),
),
),
),
if (poiWaypoints.isEmpty)
Padding(
padding: const EdgeInsets.only(top: 20, bottom: 12),
child: Column(children: [
Icon(Icons.location_on_outlined, size: 32, color: Colors.grey.shade400),
const SizedBox(height: 8),
Text('No waypoints added yet', style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600)),
Text('Tap on the map or use +', style: context.textStyles.labelSmall?.copyWith(color: Colors.grey.shade500)),
]),
)
else
Padding(
padding: const EdgeInsets.symmetric(horizontal: 8),
child: _SidebarWaypointOrderedList(
waypoints: poiWaypoints,
onEdit: onEditWaypoint,
onMoveUp: onMoveUp,
onMoveDown: onMoveDown,
canMoveUp: canMoveUp,
canMoveDown: canMoveDown,
orderManager: routeOrderManager,
onInitializeOrdering: onInitializeOrdering,
onTravelModeChanged: onTravelModeChanged,
onAddAlternative: onAddAlternative,
onWaypointUpdated: onWaypointUpdated,
onBulkWaypointUpdate: onBulkWaypointUpdate,
onOrderChanged: onOrderChanged,
onUngroup: onUngroup,
skipTravelSegments: skipTravelSegments,
),
),
// Legacy: Route stats section removed (Length, Elev. gain, Est. time, Activity)
// Legacy: Elevation chart removed
const SizedBox(height: 8),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
child: Align(
alignment: Alignment.center,
child: ConstrainedBox(
constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
child: SizedBox(
width: double.infinity,
child: FilledButton.icon(
onPressed: busy ? null : onSave,
icon: busy
? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
: const Icon(Icons.check_circle),
label: const Text('Build & Save'),
),
),
),
),
),
const SizedBox(height: 12),
],
);

return Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -8))],
),
child: ListView(controller: controller, padding: EdgeInsets.zero, children: [panelContent]),
);
},
);

String _formatDuration(int seconds) {
final h = seconds ~/ 3600;
final m = (seconds % 3600) ~/ 60;
if (h > 0) return '${h}h ${m}m';
return '${m}m';
}
}

class _DesktopSidebar extends StatelessWidget {
final List<RouteWaypoint> poiWaypoints;
final bool busy;
final VoidCallback onAddWaypoint; final void Function(RouteWaypoint) onEditWaypoint;
final VoidCallback? onPreview; final VoidCallback? onSave;
final void Function(int oldIndex, int newIndex) onReorder;
final VoidCallback onCancel;
final ActivityCategory? activityCategory;
final DayPlanOrderManager? routeOrderManager;
final void Function(String) onMoveUp;
final void Function(String) onMoveDown;
final bool Function(String) canMoveUp;
final bool Function(String) canMoveDown;
final VoidCallback onInitializeOrdering;
final TextEditingController sidebarSearchController;
final FocusNode sidebarSearchFocusNode;
final bool sidebarSearching;
final List<PlaceSuggestion> sidebarSearchResults;
final ValueChanged<String> onSidebarSearchChanged;
final VoidCallback onSidebarSearchClear;
final ValueChanged<PlaceSuggestion> onSidebarSearchSelect;
final Future<void> Function(RouteWaypoint waypoint, String newMode) onTravelModeChanged;
final Future<void> Function(RouteWaypoint waypoint) onAddAlternative;
final void Function(RouteWaypoint updatedWaypoint)? onWaypointUpdated;
final void Function(List<RouteWaypoint> updatedWaypoints)? onBulkWaypointUpdate;
final VoidCallback? onOrderChanged;
final void Function(String choiceGroupId)? onUngroup;
final bool skipTravelSegments; // Skip travel segments for GPX routes with supported activities

const _DesktopSidebar({
required this.poiWaypoints,
required this.busy,
required this.onAddWaypoint,
required this.onEditWaypoint,
required this.onPreview,
required this.onSave,
required this.onReorder,
required this.onCancel,
this.activityCategory,
required this.routeOrderManager,
required this.onMoveUp,
required this.onMoveDown,
required this.canMoveUp,
required this.canMoveDown,
required this.onInitializeOrdering,
required this.sidebarSearchController,
required this.sidebarSearchFocusNode,
required this.sidebarSearching,
required this.sidebarSearchResults,
required this.onSidebarSearchChanged,
required this.onSidebarSearchClear,
required this.onSidebarSearchSelect,
required this.onTravelModeChanged,
required this.onAddAlternative,
this.onWaypointUpdated,
this.onBulkWaypointUpdate,
this.onOrderChanged,
this.onUngroup,
this.skipTravelSegments = false,
});

@override
Widget build(BuildContext context) => Container(
decoration: BoxDecoration(
color: Colors.white,
border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(2, 0))],
),
child: SafeArea(
bottom: false,
child: Column(children: [
// Header
Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
child: Row(children: [
IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: onCancel,
tooltip: 'Go back',
),
]),
),
Expanded(
child: ListView(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
children: [
// Legacy: Stats section removed (Length, Elev. gain, Est. time, Activity)
// Legacy: Elevation chart removed
const SizedBox(height: 16),
// Waypoints section
Container(
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
padding: const EdgeInsets.symmetric(vertical: 8),
child: Row(children: [
Text('Waypoints', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
child: Text('${poiWaypoints.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
),
const Spacer(),
IconButton(
onPressed: onAddWaypoint,
style: IconButton.styleFrom(backgroundColor: context.colors.primary.withValues(alpha: 0.1)),
icon: Icon(Icons.add, color: context.colors.primary),
tooltip: 'Add waypoint',
),
]),
),
if (poiWaypoints.isEmpty) ...[
const SizedBox(height: 16),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(children: [
const Icon(Icons.info_outline, size: 16),
const SizedBox(width: 8),
const Expanded(child: Text('Click to place points or hold Shift to draw')),
]),
),
] else ...[
const SizedBox(height: 8),
_SidebarWaypointOrderedList(
waypoints: poiWaypoints,
onEdit: onEditWaypoint,
onMoveUp: onMoveUp,
onMoveDown: onMoveDown,
canMoveUp: canMoveUp,
canMoveDown: canMoveDown,
orderManager: routeOrderManager,
onInitializeOrdering: onInitializeOrdering,
onTravelModeChanged: onTravelModeChanged,
onAddAlternative: onAddAlternative,
onWaypointUpdated: onWaypointUpdated,
onBulkWaypointUpdate: onBulkWaypointUpdate,
onOrderChanged: onOrderChanged,
onUngroup: onUngroup,
skipTravelSegments: skipTravelSegments,
),
],
],
),
),
// Footer
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
child: Row(children: [
TextButton(onPressed: onCancel, child: const Text('Cancel')),
const Spacer(),
Expanded(
child: FilledButton.icon(
onPressed: busy ? null : onSave,
icon: busy
? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
: const Icon(Icons.check_circle),
label: const Text('Build & Save'),
),
),
]),
),
]),
),
);
}

// Legacy: _StatsRow widget removed (Length, Elev. gain, Est. time, Activity)

String _fmtDuration(int seconds) {
final h = seconds ~/ 3600;
final m = (seconds % 3600) ~/ 60;
if (h > 0) return '${h}h ${m}m';
return '${m}m';
}

/// Get color for travel mode (for route polyline rendering)
Color _getTravelModeColor(String mode) {
  switch (mode) {
    case 'walking':
      return const Color(0xFF4CAF50); // Green
    case 'transit':
      return const Color(0xFF2196F3); // Blue
    case 'driving':
      return Colors.grey.shade700; // Grey
    case 'bicycling':
      return const Color(0xFFFF9800); // Orange
default:
      return const Color(0xFF4CAF50); // Default to green
}
}

/// Returns the appropriate activity label based on activity category (static helper)
// Legacy: _getActivityLabelStatic removed

class _SidebarWaypointTile extends StatelessWidget {
  final RouteWaypoint waypoint; 
  final VoidCallback onEdit; 
  final VoidCallback? onMoveUp; 
  final VoidCallback? onMoveDown;
  final VoidCallback? onAddAlternative;
  final int? waypointNumber; // Number badge for this waypoint
  final bool showConnectingLine; // Whether to show connecting line below
  final bool isLastInGroup; // Whether this is the last waypoint in its order group

  const _SidebarWaypointTile({
    super.key, 
    required this.waypoint, 
    required this.onEdit, 
    this.onMoveUp, 
    this.onMoveDown,
    this.onAddAlternative,
    this.waypointNumber,
    this.showConnectingLine = false,
    this.isLastInGroup = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final waypointColor = getWaypointColor(waypoint.type);
    
    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            // Number badge and icon container
            Stack(
              alignment: Alignment.center,
              children: [
                // Connecting line (vertical line on the left)
                if (waypointNumber != null)
                  Positioned(
                    left: 14,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
                // Number badge circle
                if (waypointNumber != null)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: waypointColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$waypointNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  // Fallback: icon without number
                  Container(
                    width: 28, 
                    height: 28, 
                    decoration: BoxDecoration(
                      color: waypointColor, 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Icon(getWaypointIcon(waypoint.type), color: Colors.white, size: 16)
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    waypoint.name, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontWeight: FontWeight.w600)
                  ),
                  Text(
                    getWaypointLabel(waypoint.type), 
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
                  ),
                ]
              )
            ),
            // Reorder controls for individual waypoints
            if (onMoveUp != null || onMoveDown != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ReorderControlsVertical(
                  canMoveUp: onMoveUp != null,
                  canMoveDown: onMoveDown != null,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'add_alternative' && onAddAlternative != null) {
                  onAddAlternative?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                if (onAddAlternative != null)
                  const PopupMenuItem(
                    value: 'add_alternative',
                    child: Row(children: [
                      Icon(Icons.alt_route, size: 18),
                      SizedBox(width: 8),
                      Text('Add OR alternative'),
                    ]),
                  ),
              ],
            ),
          ]),
        ),
        // Connecting line below waypoint (if not last in group or if showConnectingLine is true)
        if (showConnectingLine && (waypointNumber != null || !isLastInGroup))
          Container(
            width: 2,
            height: 8,
            margin: const EdgeInsets.only(left: 14),
            color: Colors.grey.shade300,
          ),
      ],
    );
  }
}

/// Sidebar waypoint list using the same ordering system as builder page
/// Uses OrderableItem and DayPlanOrderManager for consistent reordering
class _SidebarWaypointOrderedList extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final void Function(RouteWaypoint) onEdit;
  final void Function(String itemId) onMoveUp;
  final void Function(String itemId) onMoveDown;
  final bool Function(String itemId) canMoveUp;
  final bool Function(String itemId) canMoveDown;
  final DayPlanOrderManager? orderManager;
  final VoidCallback onInitializeOrdering;
  final Future<void> Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;
  final Future<void> Function(RouteWaypoint waypoint)? onAddAlternative;
  // New callbacks for sequential ordering (by order number, not itemId)
  final void Function(RouteWaypoint updatedWaypoint)? onWaypointUpdated;
  final void Function(List<RouteWaypoint> updatedWaypoints)? onBulkWaypointUpdate;
  final VoidCallback? onOrderChanged;
  final void Function(String choiceGroupId)? onUngroup;
  final bool skipTravelSegments; // Skip travel segments for GPX routes with supported activities
  
  const _SidebarWaypointOrderedList({
    required this.waypoints,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canMoveUp,
    required this.canMoveDown,
    this.orderManager,
    required this.onInitializeOrdering,
    this.onTravelModeChanged,
    this.onAddAlternative,
    this.onWaypointUpdated,
    this.onBulkWaypointUpdate,
    this.onOrderChanged,
    this.onUngroup,
    this.skipTravelSegments = false,
  });

  @override
  State<_SidebarWaypointOrderedList> createState() => _SidebarWaypointOrderedListState();
}

class _SidebarWaypointOrderedListState extends State<_SidebarWaypointOrderedList> {
  DayPlanOrderManager? _localOrderManager;
  Map<String, List<RouteWaypoint>>? _waypointsBySectionId;
  Map<String, RouteWaypoint>? _waypointsById;

  @override
  void initState() {
    super.initState();
    _updateOrdering();
  }

  @override
  void didUpdateWidget(_SidebarWaypointOrderedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always recalculate maps when waypoints or orderManager change
    // Use length and IDs to detect changes even if list reference is the same
    final waypointsChanged = oldWidget.waypoints.length != widget.waypoints.length ||
        oldWidget.waypoints.map((w) => w.id).join(',') != widget.waypoints.map((w) => w.id).join(',');
    
    if (waypointsChanged || oldWidget.orderManager != widget.orderManager) {
      _updateOrdering();
    }
  }

  void _updateOrdering() {
    if (widget.orderManager != null) {
      _localOrderManager = widget.orderManager;
    } else {
      widget.onInitializeOrdering();
      // Will be updated on next build
      return;
    }
    
    // Always recalculate maps to ensure they're up to date
    _waypointsBySectionId = _getWaypointsBySectionId();
    _waypointsById = _getWaypointsById();
  }

  Map<String, List<RouteWaypoint>> _getWaypointsBySectionId() {
    // Initialize map explicitly to avoid JavaScript compilation issues
    final map = Map<String, List<RouteWaypoint>>();
    
    // Handle empty waypoints
    if (widget.waypoints.isEmpty) {
      return map;
    }
    
    for (final wp in widget.waypoints) {
      String? sectionId;
      switch (wp.type) {
        case WaypointType.restaurant:
          sectionId = 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
          break;
        case WaypointType.bar:
          sectionId = 'barSection_${wp.mealTime?.name ?? "dinner"}';
          break;
        case WaypointType.activity:
        case WaypointType.attraction:
          sectionId = 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
          break;
        case WaypointType.accommodation:
          sectionId = 'accommodationSection';
          break;
        case WaypointType.servicePoint:
        case WaypointType.service:
        case WaypointType.viewingPoint:
        case WaypointType.routePoint:
          // These are individual items, not sections - they should appear as individual waypoints
          break;
        default:
          break;
      }
      if (sectionId != null) {
        map.putIfAbsent(sectionId, () => <RouteWaypoint>[]).add(wp);
      }
    }
    return map;
  }

  Map<String, RouteWaypoint> _getWaypointsById() {
    // Initialize map explicitly to avoid JavaScript compilation issues
    final map = Map<String, RouteWaypoint>();
    for (final wp in widget.waypoints) {
      map[wp.id] = wp;
    }
    return map;
  }

  /// Get all distinct order values, sorted ascending.
  List<int> _getDistinctOrders() {
    final orders = widget.waypoints.map((w) => w.order).toSet().toList()..sort();
    return orders;
  }

  /// Check if a waypoint (or its entire choice group) can move up.
  bool _canMoveUp(RouteWaypoint waypoint) {
    final orders = _getDistinctOrders();
    final currentOrderIndex = orders.indexOf(waypoint.order);
    return currentOrderIndex > 0;
  }

  /// Check if a waypoint (or its entire choice group) can move down.
  bool _canMoveDown(RouteWaypoint waypoint) {
    final orders = _getDistinctOrders();
    final currentOrderIndex = orders.indexOf(waypoint.order);
    return currentOrderIndex < orders.length - 1;
  }

  /// Move a waypoint (or its entire choice group) up by swapping orders
  /// with the previous order group.
  void _moveWaypointUp(RouteWaypoint waypoint) {
    final orders = _getDistinctOrders();
    final currentOrderIndex = orders.indexOf(waypoint.order);
    if (currentOrderIndex <= 0) return;

    final currentOrder = orders[currentOrderIndex];
    final previousOrder = orders[currentOrderIndex - 1];

    final currentGroup = widget.waypoints.where((w) => w.order == currentOrder).toList();
    final previousGroup = widget.waypoints.where((w) => w.order == previousOrder).toList();

    Log.i('route_builder', '⬆️ _moveWaypointUp: "${waypoint.name}" (order=$currentOrder → $previousOrder)');
    Log.i('route_builder', '  currentGroup (order=$currentOrder): ${currentGroup.map((w) => "${w.name}(cg=${w.choiceGroupId})").join(", ")}');
    Log.i('route_builder', '  previousGroup (order=$previousOrder): ${previousGroup.map((w) => "${w.name}(cg=${w.choiceGroupId})").join(", ")}');

    // Collect ALL updates — preserve choiceGroupId, only change order
    final updates = <RouteWaypoint>[
      for (final wp in currentGroup) wp.copyWith(order: previousOrder),
      for (final wp in previousGroup) wp.copyWith(order: currentOrder),
    ];

    Log.i('route_builder', '  updates: ${updates.map((w) => "${w.name}→order=${w.order}(cg=${w.choiceGroupId})").join(", ")}');

    if (widget.onBulkWaypointUpdate != null) {
      widget.onBulkWaypointUpdate!(updates);
    } else if (widget.onWaypointUpdated != null) {
      for (final updated in updates) {
        widget.onWaypointUpdated!(updated);
      }
    widget.onOrderChanged?.call();
    }
  }

  /// Move a waypoint (or its entire choice group) down by swapping orders
  /// with the next order group.
  void _moveWaypointDown(RouteWaypoint waypoint) {
    final orders = _getDistinctOrders();
    final currentOrderIndex = orders.indexOf(waypoint.order);
    if (currentOrderIndex >= orders.length - 1) return;

    final currentOrder = orders[currentOrderIndex];
    final nextOrder = orders[currentOrderIndex + 1];

    final currentGroup = widget.waypoints.where((w) => w.order == currentOrder).toList();
    final nextGroup = widget.waypoints.where((w) => w.order == nextOrder).toList();

    Log.i('route_builder', '⬇️ _moveWaypointDown: "${waypoint.name}" (order=$currentOrder → $nextOrder)');
    Log.i('route_builder', '  currentGroup (order=$currentOrder): ${currentGroup.map((w) => "${w.name}(cg=${w.choiceGroupId})").join(", ")}');
    Log.i('route_builder', '  nextGroup (order=$nextOrder): ${nextGroup.map((w) => "${w.name}(cg=${w.choiceGroupId})").join(", ")}');

    final updates = <RouteWaypoint>[
      for (final wp in currentGroup) wp.copyWith(order: nextOrder),
      for (final wp in nextGroup) wp.copyWith(order: currentOrder),
    ];

    Log.i('route_builder', '  updates: ${updates.map((w) => "${w.name}→order=${w.order}(cg=${w.choiceGroupId})").join(", ")}');

    if (widget.onBulkWaypointUpdate != null) {
      widget.onBulkWaypointUpdate!(updates);
    } else if (widget.onWaypointUpdated != null) {
      for (final updated in updates) {
        widget.onWaypointUpdated!(updated);
      }
    widget.onOrderChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simplified sequential ordering: sort by order number (1, 2, 3...)
    final sortedWaypoints = List<RouteWaypoint>.from(widget.waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedWaypoints.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group waypoints by order, handling choice groups
    final groupedWaypoints = <int, List<RouteWaypoint>>{};
    for (final wp in sortedWaypoints) {
      groupedWaypoints.putIfAbsent(wp.order, () => <RouteWaypoint>[]).add(wp);
    }

    Log.i('route_builder', '🏗️ Building sidebar: ${sortedWaypoints.length} waypoints, ${groupedWaypoints.length} order groups');
    for (final entry in groupedWaypoints.entries) {
      final wps = entry.value;
      final isChoice = wps.first.choiceGroupId != null && wps.length > 1;
      Log.i('route_builder', '  order=${entry.key}: ${wps.map((w) => "${w.name}(cg=${w.choiceGroupId})").join(", ")} ${isChoice ? "→ CHOICE GROUP" : ""}');
    }

    final orderedGroups = groupedWaypoints.keys.toList()..sort();

    final widgets = <Widget>[];
    
    // Calculate waypoint numbers based on order groups (not individual waypoints)
    // Each order group gets one number, and choice groups share that number
    int waypointNumber = 1;
    
    for (int i = 0; i < orderedGroups.length; i++) {
      final order = orderedGroups[i];
      final waypointsAtOrder = groupedWaypoints[order]!;
      
      // Check if this is a choice group (multiple waypoints with same order and choiceGroupId)
      final firstWp = waypointsAtOrder.first;
      final isChoiceGroup = firstWp.choiceGroupId != null && waypointsAtOrder.length > 1;
      final isLastGroup = i == orderedGroups.length - 1;
      
      if (isChoiceGroup) {
        // Get previous order group's waypoints (for per-option travel display)
        List<RouteWaypoint>? previousWaypoints;
        if (i > 0) {
          final prevOrder = orderedGroups[i - 1];
          previousWaypoints = groupedWaypoints[prevOrder];
        }
        
        // Display choice group with move arrows on header
        widgets.add(
          _SidebarChoiceGroup(
            key: ValueKey('choice_${firstWp.choiceGroupId}'),
            waypoints: waypointsAtOrder,
            choiceLabel: firstWp.choiceLabel ?? 'Choose an option',
            onEdit: widget.onEdit,
            onMoveUp: _canMoveUp(firstWp) ? () => _moveWaypointUp(firstWp) : null,
            onMoveDown: _canMoveDown(firstWp) ? () => _moveWaypointDown(firstWp) : null,
            previousWaypoints: previousWaypoints,
            onTravelModeChanged: widget.onTravelModeChanged,
            onUngroup: widget.onUngroup != null && firstWp.choiceGroupId != null 
                ? () => widget.onUngroup!(firstWp.choiceGroupId!) 
                : null,
            groupNumber: waypointNumber, // All waypoints in group share this number
            showConnectingLine: !isLastGroup, // Show line if not last group
          ),
        );
        waypointNumber++; // Increment for next group
      } else {
        // Display individual waypoint with move arrows
        for (int j = 0; j < waypointsAtOrder.length; j++) {
          final wp = waypointsAtOrder[j];
          final isLastInOrderGroup = j == waypointsAtOrder.length - 1;
          // Check if there are other waypoints available to group with
          final availableForGrouping = widget.waypoints.where((other) {
            if (other.id == wp.id) return false; // Exclude self
            if (wp.choiceGroupId != null && other.choiceGroupId == wp.choiceGroupId) return false; // Exclude same group
            return true;
          }).isNotEmpty;
          
          widgets.add(
            _SidebarWaypointTile(
              key: ValueKey(wp.id),
              waypoint: wp,
              onEdit: () => widget.onEdit(wp),
              onMoveUp: _canMoveUp(wp) ? () => _moveWaypointUp(wp) : null,
              onMoveDown: _canMoveDown(wp) ? () => _moveWaypointDown(wp) : null,
              onAddAlternative: (widget.onAddAlternative != null && availableForGrouping) 
                  ? () => widget.onAddAlternative!(wp) 
                  : null,
              waypointNumber: waypointNumber, // Individual waypoint gets its own number
              showConnectingLine: !isLastGroup || !isLastInOrderGroup, // Show line if not last
              isLastInGroup: isLastInOrderGroup,
            ),
          );
        }
        waypointNumber++; // Increment for next group
      }
      
      // Travel segments removed - no longer showing duration/distance between waypoints
    }
    
    return Column(children: widgets);
  }

  TimeSlotCategory _getCategoryFromSectionId(String sectionId) {
    // Map section IDs back to TimeSlotCategory
    if (sectionId == 'accommodationSection') {
      return TimeSlotCategory.accommodation;
    }
    if (sectionId.startsWith('restaurantSection_')) {
      final mealTime = sectionId.split('_').last;
      switch (mealTime) {
        case 'breakfast':
          return TimeSlotCategory.breakfast;
        case 'lunch':
          return TimeSlotCategory.lunch;
        case 'dinner':
          return TimeSlotCategory.dinner;
        default:
          return TimeSlotCategory.lunch;
      }
    }
    if (sectionId.startsWith('activitySection_')) {
      final activityTime = sectionId.split('_').last;
      switch (activityTime) {
        case 'morning':
          return TimeSlotCategory.morningActivity;
        case 'afternoon':
          return TimeSlotCategory.afternoonActivity;
        case 'evening':
          return TimeSlotCategory.eveningActivity;
        case 'night':
          return TimeSlotCategory.eveningActivity;
        case 'allDay':
          return TimeSlotCategory.allDayActivity;
        default:
          return TimeSlotCategory.afternoonActivity;
      }
    }
    return TimeSlotCategory.afternoonActivity; // Default fallback
  }
}

/// Sidebar choice group widget (for OR logic - multiple waypoints at same order)
/// Shows per-option travel info when previousWaypoints is provided.
class _SidebarChoiceGroup extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final String choiceLabel;
  final void Function(RouteWaypoint) onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final List<RouteWaypoint>? previousWaypoints;
  final void Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;
  final VoidCallback? onUngroup;
  final int? groupNumber; // Number badge for this choice group
  final bool showConnectingLine; // Whether to show connecting line below

  const _SidebarChoiceGroup({
    super.key,
    required this.waypoints,
    required this.choiceLabel,
    required this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.previousWaypoints,
    this.onTravelModeChanged,
    this.onUngroup,
    this.groupNumber,
    this.showConnectingLine = false,
  });

  String _formatTravelTime(int? seconds) {
    if (seconds == null) return '...';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hours h' : '$hours h $rem min';
  }

  String _getTravelModeLabel(String? mode) {
    switch (mode) {
      case 'walking': return 'walk';
      case 'transit': return 'metro';
      case 'driving': return 'drive';
      case 'bicycling': return 'bike';
      default: return 'walk';
    }
  }

  IconData _getTravelIcon(String? mode) {
    switch (mode) {
      case 'walking': return Icons.directions_walk;
      case 'transit': return Icons.directions_transit;
      case 'driving': return Icons.directions_car;
      case 'bicycling': return Icons.directions_bike;
      default: return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the first waypoint's color for the group number badge
    final groupColor = waypoints.isNotEmpty 
        ? getWaypointColor(waypoints.first.type)
        : Colors.blue;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connecting line above group (if groupNumber is set)
              if (groupNumber != null)
                Container(
                  width: 2,
                  height: 8,
                  margin: const EdgeInsets.only(left: 14),
                  color: Colors.grey.shade300,
                ),
              // Choice group header with move arrows
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    // Number badge for the group
                    if (groupNumber != null)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vertical line
                          Positioned(
                            left: 14,
                            top: -8,
                            bottom: -8,
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          // Number badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: groupColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '$groupNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (groupNumber != null) const SizedBox(width: 10),
                    // Move up arrow
                    if (onMoveUp != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: onMoveUp,
                        tooltip: 'Move group up',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    // Move down arrow
                    if (onMoveDown != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: onMoveDown,
                        tooltip: 'Move group down',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        choiceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                Text(
                  '(${waypoints.length} options)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onUngroup != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      Log.i('route_builder', '🔴 Ungroup button clicked');
                      onUngroup?.call();
                    },
                    tooltip: 'Ungroup waypoints',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: Colors.blue.shade700,
                  ),
              ],
            ),
          ),
          // Choice options with per-option travel info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final wp in waypoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Waypoints in choice group don't show individual numbers - they share the group number
                        Row(
                          children: [
                            // Indent for grouped waypoints
                            SizedBox(
                              width: groupNumber != null ? 38 : 0, // Space for number badge
                            ),
                            Icon(Icons.radio_button_unchecked, size: 16, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SidebarWaypointTile(
                                waypoint: wp,
                                onEdit: () => onEdit(wp),
                                onMoveUp: null,
                                onMoveDown: null,
                                waypointNumber: null, // No individual number in choice group
                                showConnectingLine: false,
                                isLastInGroup: wp == waypoints.last,
                              ),
                            ),
                          ],
                        ),
                        // Travel info removed - no longer showing duration/distance
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
      // Connecting line below group (if showConnectingLine is true)
      if (showConnectingLine && groupNumber != null)
        Container(
          width: 2,
          height: 8,
          margin: const EdgeInsets.only(left: 14),
          color: Colors.grey.shade300,
        ),
    ],
    );
  }
}

/// Sidebar travel segment widget (shows distance/time between waypoints)
class _SidebarTravelSegment extends StatelessWidget {
  final RouteWaypoint fromWaypoint;
  final RouteWaypoint toWaypoint;
  final void Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;

  const _SidebarTravelSegment({
    super.key,
    required this.fromWaypoint,
    required this.toWaypoint,
    this.onTravelModeChanged,
  });

  IconData _getTravelIcon(String? mode) {
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_transit;
      case 'driving':
        return Icons.directions_car;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.directions_walk;
    }
  }

  String _getTravelModeLabel(String? mode) {
    switch (mode) {
      case 'walking':
        return 'walk';
      case 'transit':
        return 'metro';
      case 'driving':
        return 'drive';
      case 'bicycling':
        return 'bike';
      default:
        return 'walk';
    }
  }

  String _formatTravelTime(int? seconds) {
    if (seconds == null) return 'calculating...';
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    final hasTravelInfo = toWaypoint.travelTime != null && 
                          toWaypoint.travelMode != null && 
                          toWaypoint.travelDistance != null;
    
    // Detect straight-line route: travelTime is 0 and geometry has exactly 2 points
    final isStraightLine = hasTravelInfo && 
                          toWaypoint.travelTime == 0 &&
                          toWaypoint.travelRouteGeometry != null &&
                          toWaypoint.travelRouteGeometry!.length == 2;
    
    final distanceKm = hasTravelInfo 
        ? (toWaypoint.travelDistance! / 1000.0).toStringAsFixed(1)
        : null;
    final timeStr = hasTravelInfo && !isStraightLine 
        ? _formatTravelTime(toWaypoint.travelTime!) 
        : null;
    final mode = toWaypoint.travelMode ?? 'walking';
    final modeLabel = _getTravelModeLabel(mode);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isStraightLine ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isStraightLine ? Colors.grey.shade300 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getTravelIcon(mode),
                size: 16,
                color: isStraightLine ? Colors.grey.shade700 : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    if (hasTravelInfo) ...[
                      if (isStraightLine) ...[
                        Text(
                          '↓ $modeLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (timeStr != null) ...[
                        Text(
                          '↓ $timeStr $modeLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (distanceKm != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          isStraightLine ? '(~$distanceKm km straight line)' : '($distanceKm km)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isStraightLine ? Colors.grey.shade600 : Colors.green.shade700,
                            fontStyle: isStraightLine ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        'Calculating travel time...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isStraightLine) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'No road route — straight line shown',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Travel mode picker
          if (onTravelModeChanged != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.swap_horiz, 
                    size: 16, 
                    color: isStraightLine ? Colors.grey.shade700 : Colors.green.shade700,
                  ),
                  tooltip: 'Change travel mode',
                  onSelected: (newMode) => onTravelModeChanged!(toWaypoint, newMode),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'walking',
                      child: Row(
                        children: [
                          Icon(Icons.directions_walk, size: 16),
                          const SizedBox(width: 8),
                          const Text('Walk'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'transit',
                      child: Row(
                        children: [
                          Icon(Icons.directions_transit, size: 16),
                          const SizedBox(width: 8),
                          const Text('Transit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'driving',
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, size: 16),
                          const SizedBox(width: 8),
                          const Text('Drive'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'bicycling',
                      child: Row(
                        children: [
                          Icon(Icons.directions_bike, size: 16),
                          const SizedBox(width: 8),
                          const Text('Bike'),
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
}

/// Travel segment with a "from" label — used when the origin is a choice group.
/// Shows "from [option name]: 7 min walk (0.49 km)" for each origin option.
class _SidebarTravelSegmentWithLabel extends StatelessWidget {
  final RouteWaypoint fromWaypoint;
  final RouteWaypoint toWaypoint;
  final String label;
  final void Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;

  const _SidebarTravelSegmentWithLabel({
    super.key,
    required this.fromWaypoint,
    required this.toWaypoint,
    required this.label,
    this.onTravelModeChanged,
  });

  IconData _getTravelIcon(String? mode) {
    switch (mode) {
      case 'walking': return Icons.directions_walk;
      case 'transit': return Icons.directions_transit;
      case 'driving': return Icons.directions_car;
      case 'bicycling': return Icons.directions_bike;
      default: return Icons.directions_walk;
    }
  }

  String _getTravelModeLabel(String? mode) {
    switch (mode) {
      case 'walking': return 'walk';
      case 'transit': return 'metro';
      case 'driving': return 'drive';
      case 'bicycling': return 'bike';
      default: return 'walk';
    }
  }

  String _formatTravelTime(int? seconds) {
    if (seconds == null) return '...';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hours h' : '$hours h $rem min';
  }

  @override
  Widget build(BuildContext context) {
    final hasTravelInfo = toWaypoint.travelTime != null &&
                          toWaypoint.travelMode != null &&
                          toWaypoint.travelDistance != null;

    final distanceKm = hasTravelInfo
        ? (toWaypoint.travelDistance! / 1000.0).toStringAsFixed(1)
        : null;
    final mode = toWaypoint.travelMode ?? 'walking';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(_getTravelIcon(mode), size: 14, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (hasTravelInfo)
                  Row(
                    children: [
                      Text(
                        '↓ ${_formatTravelTime(toWaypoint.travelTime)} ${_getTravelModeLabel(mode)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($distanceKm km)',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    'Calculating...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (onTravelModeChanged != null)
            SizedBox(
              width: 24,
              height: 24,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.swap_horiz, size: 14, color: Colors.green.shade700),
                tooltip: 'Change travel mode',
                padding: EdgeInsets.zero,
                onSelected: (newMode) => onTravelModeChanged!(toWaypoint, newMode),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'walking', child: Row(children: [Icon(Icons.directions_walk, size: 16), const SizedBox(width: 8), const Text('Walk')])),
                  PopupMenuItem(value: 'transit', child: Row(children: [Icon(Icons.directions_transit, size: 16), const SizedBox(width: 8), const Text('Transit')])),
                  PopupMenuItem(value: 'driving', child: Row(children: [Icon(Icons.directions_car, size: 16), const SizedBox(width: 8), const Text('Drive')])),
                  PopupMenuItem(value: 'bicycling', child: Row(children: [Icon(Icons.directions_bike, size: 16), const SizedBox(width: 8), const Text('Bike')])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sidebar category group widget (for activities/restaurants)
class _SidebarCategoryGroup extends StatefulWidget {
final TimeSlotCategory category;
final List<RouteWaypoint> waypoints;
final void Function(RouteWaypoint) onEdit;
final String itemId;
final bool canMoveUp;
final bool canMoveDown;
final VoidCallback? onMoveUp;
final VoidCallback? onMoveDown;

const _SidebarCategoryGroup({
super.key,
required this.category,
required this.waypoints,
required this.onEdit,
required this.itemId,
required this.canMoveUp,
required this.canMoveDown,
this.onMoveUp,
this.onMoveDown,
});

@override
State<_SidebarCategoryGroup> createState() => _SidebarCategoryGroupState();
}

class _SidebarCategoryGroupState extends State<_SidebarCategoryGroup> {
bool _isExpanded = true;

@override
Widget build(BuildContext context) {
final icon = getTimeSlotIcon(widget.category);
final label = getTimeSlotLabel(widget.category);
final color = getTimeSlotColor(widget.category);

return Container(
margin: const EdgeInsets.only(bottom: 8),
decoration: BoxDecoration(
border: Border.all(color: Colors.grey.shade200),
borderRadius: BorderRadius.circular(8),
color: Colors.white,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// Category header
InkWell(
onTap: () => setState(() => _isExpanded = !_isExpanded),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
),
child: Row(
children: [
const SizedBox(width: 8),
Container(
width: 24,
height: 24,
decoration: BoxDecoration(
color: color.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(6),
),
child: Icon(icon, size: 14, color: color),
),
const SizedBox(width: 8),
Expanded(
child: Text(
label,
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w700,
color: Colors.black87,
),
),
),
if (widget.waypoints.isNotEmpty)
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(10),
),
child: Text(
'${widget.waypoints.length}',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w700,
color: color,
),
),
),
const Spacer(),
// Reorder controls for categories
ReorderControls(
canMoveUp: widget.canMoveUp,
canMoveDown: widget.canMoveDown,
onMoveUp: widget.onMoveUp,
onMoveDown: widget.onMoveDown,
isCompact: true,
),
const SizedBox(width: 8),
Icon(
_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
size: 18,
color: Colors.grey.shade600,
),
],
),
),
),
// Waypoints in category
if (_isExpanded && widget.waypoints.isNotEmpty)
Padding(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
child: Column(
children: [
for (int i = 0; i < widget.waypoints.length; i++)
Padding(
padding: const EdgeInsets.only(bottom: 4),
child: _SidebarWaypointTile(
waypoint: widget.waypoints[i],
onEdit: () => widget.onEdit(widget.waypoints[i]),
// Only allow reordering for logistics and viewing points
// Restaurant, accommodation, and activity waypoints are not individually draggable
onMoveUp: null,
onMoveDown: null,
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

class _WaypointList extends StatelessWidget {
final List<RouteWaypoint> items; final void Function(RouteWaypoint) onEdit; final void Function(int,int) onReorder;
const _WaypointList({required this.items, required this.onEdit, required this.onReorder});
@override
Widget build(BuildContext context) => Column(
children: [
for (int i = 0; i < items.length; i++)
_WaypointTile(
key: ValueKey(items[i].id ?? '${items[i].name}-$i'),
waypoint: items[i],
onEdit: () => onEdit(items[i]),
// Up/Down quick reorder for now
onMoveUp: i == 0 ? null : () => onReorder(i, i - 1),
onMoveDown: i == items.length - 1 ? null : () => onReorder(i, i + 2),
),
],
);
}

class _WaypointTile extends StatelessWidget {
final RouteWaypoint waypoint; final VoidCallback onEdit; final VoidCallback? onMoveUp; final VoidCallback? onMoveDown;
const _WaypointTile({super.key, required this.waypoint, required this.onEdit, this.onMoveUp, this.onMoveDown});
@override
Widget build(BuildContext context) => Container(
padding: const EdgeInsets.symmetric(vertical: 8),
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
child: Row(children: [
const SizedBox(width: 8),
Container(
width: 32,
height: 32,
decoration: BoxDecoration(color: getWaypointColor(waypoint.type), borderRadius: BorderRadius.circular(8)),
child: Icon(getWaypointIcon(waypoint.type), color: Colors.white, size: 18),
),
const SizedBox(width: 10),
Expanded(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(waypoint.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 2),
Row(
children: [
Text(getWaypointLabel(waypoint.type), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
if (waypoint.mealTime != null) ...[
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: getWaypointColor(waypoint.type).withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(4),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getMealTimeIcon(waypoint.mealTime!), size: 10, color: getWaypointColor(waypoint.type)),
const SizedBox(width: 3),
Text(
getMealTimeLabel(waypoint.mealTime!),
style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: getWaypointColor(waypoint.type)),
),
],
),
),
],
if (waypoint.activityTime != null) ...[
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: getWaypointColor(waypoint.type).withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(4),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getActivityTimeIcon(waypoint.activityTime!), size: 10, color: getWaypointColor(waypoint.type)),
const SizedBox(width: 3),
Text(
getActivityTimeLabel(waypoint.activityTime!),
style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: getWaypointColor(waypoint.type)),
),
],
),
),
],
],
),
],
),
),
if (onMoveUp != null)
IconButton(onPressed: onMoveUp, icon: const Icon(Icons.arrow_upward, size: 18)),
if (onMoveDown != null)
IconButton(onPressed: onMoveDown, icon: const Icon(Icons.arrow_downward, size: 18)),
PopupMenuButton<String>(
icon: const Icon(Icons.more_vert),
onSelected: (value) {
if (value == 'edit') onEdit();
},
itemBuilder: (context) => [
const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
],
),
]),
);
}

/// Dialog for selecting an existing waypoint to group with another waypoint
class _SelectWaypointForGroupDialog extends StatelessWidget {
  final List<RouteWaypoint> availableWaypoints;
  final RouteWaypoint sourceWaypoint;

  const _SelectWaypointForGroupDialog({
    required this.availableWaypoints,
    required this.sourceWaypoint,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollBlockingDialog(
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group as Choice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a waypoint to group with "${sourceWaypoint.name}"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Waypoint list
            Expanded(
              child: ScrollBlockingScrollView(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: availableWaypoints.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final waypoint = availableWaypoints[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(waypoint),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: getWaypointColor(waypoint.type),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                getWaypointIcon(waypoint.type),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    waypoint.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    getWaypointLabel(waypoint.type),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action tile for map tap picker
class _ActionTile extends StatelessWidget {
final IconData icon;
final Color color;
final String label;
final VoidCallback onTap;

const _ActionTile({
required this.icon,
required this.color,
required this.label,
required this.onTap,
});

@override
Widget build(BuildContext context) => InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(12),
child: Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
border: Border.all(color: Colors.grey.shade300),
borderRadius: BorderRadius.circular(12),
),
child: Row(
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: Icon(icon, color: color, size: 24),
),
const SizedBox(width: 16),
Text(
label,
style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
),
],
),
),
);
}

/// Route point tile for the sidebar
class _RoutePointTile extends StatelessWidget {
final int index;
final ll.LatLng point;
final bool isStart;
final bool isEnd;
final VoidCallback onDelete;
final VoidCallback? onMoveUp;
final VoidCallback? onMoveDown;

const _RoutePointTile({
required this.index,
required this.point,
required this.isStart,
required this.isEnd,
required this.onDelete,
this.onMoveUp,
this.onMoveDown,
});

@override
Widget build(BuildContext context) => Container(
height: 56,
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
child: Row(children: [
Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: isStart ? const Color(0xFF4CAF50) : (isEnd ? const Color(0xFFF44336) : const Color(0xFFFF9800)),
borderRadius: BorderRadius.circular(8),
),
child: Icon(
isStart ? Icons.play_arrow : (isEnd ? Icons.flag : Icons.circle),
color: Colors.white,
size: isStart || isEnd ? 16 : 12,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
isStart ? 'Start Point' : (isEnd ? 'End Point' : 'Point ${index + 1}'),
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(fontWeight: FontWeight.w600),
),
Text(
'${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
),
],
),
),
if (onMoveUp != null) IconButton(onPressed: onMoveUp, icon: const Icon(Icons.arrow_upward, size: 16)),
if (onMoveDown != null) IconButton(onPressed: onMoveDown, icon: const Icon(Icons.arrow_downward, size: 16)),
IconButton(
onPressed: onDelete,
icon: const Icon(Icons.delete, size: 18),
color: Colors.red.shade400,
tooltip: 'Delete point',
),
]),
);
}

/// Dialog for adding route points via search
/// Add waypoint dialog with Mapbox search and URL extraction
class _AddWaypointDialog extends StatefulWidget {
final WaypointType? preselectedType;
final ll.LatLng? proximityBias;
final bool excludeRoutePoint;
final PlaceDetails? preselectedPlace;
final RouteWaypoint? existingWaypoint; // For edit mode

const _AddWaypointDialog({
  this.preselectedType,
  this.proximityBias,
  this.excludeRoutePoint = false,
  this.preselectedPlace,
  this.existingWaypoint,
});

@override
State<_AddWaypointDialog> createState() => _AddWaypointDialogState();
}

/// Simple class to represent a Mapbox search result
class MapboxPlace {
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  ll.LatLng get location => ll.LatLng(latitude, longitude);

  MapboxPlace({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    return MapboxPlace(
      name: json['name'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class _AddWaypointDialogState extends State<_AddWaypointDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _airbnbAddressController = TextEditingController();
  late WaypointType _selectedType;
  POIAccommodationType? _accommodationType;
  MealTime? _mealTime;
  ActivityTime? _activityTime;
  bool _geocoding = false;
  ll.LatLng? _airbnbLocation;
  bool _airbnbAddressConfirmed = false;
  bool _hasSearchedOrExtracted = false; // Track if user has searched or extracted
  ll.LatLng? _extractedLocation; // Location from URL extraction
  Map<String, dynamic>? _extractedAddress; // Address from URL extraction
  PlaceDetails? _selectedPlace; // Place selected from Google Places search within dialog
  List<PlacePrediction> _googlePlacesSearchResults = []; // Google Places search results
  bool _googlePlacesSearching = false; // Google Places search in progress
  final _addressSearchController = TextEditingController(); // Controller for manual address search
  final _priceMinController = TextEditingController(); // Controller for minimum price
  final _priceMaxController = TextEditingController(); // Controller for maximum price
  final _photoUrlController = TextEditingController(); // Controller for photo URL
  final _phoneController = TextEditingController(); // Controller for phone number
  final _ratingController = TextEditingController(); // Controller for rating/review score
  Timer? _addressSearchDebounce; // Debounce for address search
  String? _uploadedImageUrl; // URL of uploaded image from Firebase Storage
  bool _uploadingImage = false; // Track image upload status
  final StorageService _storageService = StorageService(); // Storage service for image uploads
  final GooglePlacesService _googlePlacesService = GooglePlacesService(); // For fetching place photos
  String? _googlePlacePhotoUrl; // Cached photo URL from Google Places
  bool _loadingPhoto = false; // Track photo loading status

  @override
  void initState() {
    super.initState();
    
    // Handle edit mode - load existing waypoint data FIRST
    if (widget.existingWaypoint != null) {
      final wp = widget.existingWaypoint!;
      _selectedType = wp.type;
      _accommodationType = wp.accommodationType;
      _mealTime = wp.mealTime;
      _activityTime = wp.activityTime;
      _nameController.text = wp.name;
      _descController.text = wp.description ?? '';
      _phoneController.text = wp.phoneNumber ?? '';
      _addressSearchController.text = wp.address ?? '';
      _photoUrlController.text = wp.photoUrl ?? '';
      _priceMinController.text = wp.estimatedPriceRange?.min.toString() ?? '';
      _priceMaxController.text = wp.estimatedPriceRange?.max.toString() ?? '';
      _ratingController.text = wp.rating?.toString() ?? '';
      _extractedLocation = wp.position;
      _extractedAddress = wp.address != null ? {'formatted': wp.address} : null;
      _hasSearchedOrExtracted = true;
      if (wp.photoUrl != null) {
        _googlePlacePhotoUrl = wp.photoUrl;
      }
    }
    // Determine waypoint type from preselected place or use default
    else if (widget.preselectedPlace != null) {
      final place = widget.preselectedPlace!;
      // Determine waypoint type from place types
      if (place.types.contains('restaurant') || 
          place.types.contains('food') ||
          place.types.contains('cafe')) {
        _selectedType = WaypointType.restaurant;
      } else if (place.types.contains('lodging') || 
                 place.types.contains('hotel')) {
        _selectedType = WaypointType.accommodation;
      } else if (place.types.contains('tourist_attraction') ||
                 place.types.contains('point_of_interest')) {
        _selectedType = WaypointType.attraction;
      } else {
        _selectedType = widget.preselectedType ?? WaypointType.attraction;
      }
      
      // Pre-populate fields from Google My Business data
      _nameController.text = place.name;
      _descController.text = place.description ?? ''; // Include description from Google My Business
      _phoneController.text = place.phoneNumber ?? '';
      _addressSearchController.text = place.address ?? '';
      _ratingController.text = place.rating?.toString() ?? '';
      
      // Populate price range from Google My Business if available
      if (place.priceLevel != null) {
        // Convert priceLevel (0-4) to approximate price range
        // This is just a guide - users can adjust manually
        switch (place.priceLevel) {
          case 1: // $
            _priceMinController.text = '10';
            _priceMaxController.text = '30';
            break;
          case 2: // $$
            _priceMinController.text = '30';
            _priceMaxController.text = '60';
            break;
          case 3: // $$$
            _priceMinController.text = '60';
            _priceMaxController.text = '120';
            break;
          case 4: // $$$$
            _priceMinController.text = '120';
            _priceMaxController.text = '300';
            break;
          default:
            // Free or unknown - leave empty
            break;
        }
      }
      
      // Set location
      _extractedLocation = place.location;
      _extractedAddress = place.address != null ? {'formatted': place.address} : null;
      _hasSearchedOrExtracted = true;
      
      // Fetch photo if available
      if (place.photoReference != null) {
        _loadGooglePlacePhoto(place.photoReference!);
      }
    } else {
      _selectedType = widget.preselectedType ?? WaypointType.restaurant;
    }
    
    // proximityBias is only used for biasing Google Places search results
    // It should NOT pre-populate the location field
    // Location should only be set when:
    // 1. User selects a place from search (preselectedPlace)
    // 2. User is editing an existing waypoint (existingWaypoint)
    // 3. User explicitly clicks on the map to set location (handled separately)
    // Do NOT auto-populate from proximityBias
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _airbnbAddressController.dispose();
    _addressSearchController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _photoUrlController.dispose();
    _phoneController.dispose();
    _ratingController.dispose();
    _addressSearchDebounce?.cancel();
    super.dispose();
  }

Future<void> _loadGooglePlacePhoto(String photoReference) async {
  // Load photo if we have a preselected place (from map search) or selected place (from dialog search)
  if (widget.preselectedPlace == null && _selectedPlace == null) return;
  
  setState(() => _loadingPhoto = true);
  
  try {
    // Generate a temporary waypoint ID for photo caching
    final tempWaypointId = const Uuid().v4();
    final photoUrl = await _googlePlacesService.getCachedPhotoUrl(photoReference, tempWaypointId);
    
    if (photoUrl != null && mounted) {
      setState(() {
        _googlePlacePhotoUrl = photoUrl;
        _photoUrlController.text = photoUrl;
        _loadingPhoto = false;
      });
    } else {
      if (mounted) {
        setState(() => _loadingPhoto = false);
      }
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to load Google Place photo', e);
    if (mounted) {
      setState(() => _loadingPhoto = false);
    }
  }
}

Future<void> _pickAndUploadImage() async {
  try {
    final result = await _storageService.pickImage();
    if (result == null) return; // User canceled

    setState(() => _uploadingImage = true);

    // Generate a unique path for the waypoint image
    final photoId = const Uuid().v4();
    final path = 'waypoint-photos/$photoId.${result.extension}';
    
    // Upload to Firebase Storage
    final downloadUrl = await _storageService.uploadImage(
      path: path,
      bytes: result.bytes,
      contentType: 'image/${result.extension == 'jpg' ? 'jpeg' : result.extension}',
    );

    if (mounted) {
      setState(() {
        _uploadedImageUrl = downloadUrl;
        _uploadingImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Image uploaded successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to upload image', e);
    if (mounted) {
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// URL extraction method moved to legacy/waypoint_url_extraction.dart
// Now using Google Places API for all waypoint data extraction

// Google Places search methods removed - using Mapbox search and URL extraction instead

/// Unified Mapbox geocoding method - used by all address geocoding operations
/// Returns the first result's coordinates and formatted address, or null if not found
Future<MapboxPlace?> _geocodeAddressWithMapbox(String address) async {
  if (address.trim().isEmpty) {
    return null;
  }

  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('geocodeAddressMapbox');
    final result = await callable.call<Map<String, dynamic>>({
      'query': address.trim(), // Use 'query' parameter (not 'address')
      'proximity': widget.proximityBias != null
          ? {'lng': widget.proximityBias!.longitude, 'lat': widget.proximityBias!.latitude}
          : null,
    });
    final data = result.data as Map<String, dynamic>?;

    if (data != null && data['results'] is List && (data['results'] as List).isNotEmpty) {
      final firstResult = (data['results'] as List).first as Map<String, dynamic>;
      final lat = firstResult['latitude'] as num?;
      final lng = firstResult['longitude'] as num?;
      final name = firstResult['name'] as String? ?? '';
      final formattedAddress = firstResult['formattedAddress'] as String? ?? '';

      if (lat != null && lng != null) {
        return MapboxPlace(
          name: name,
          formattedAddress: formattedAddress,
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
        );
      }
    }
    return null;
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to geocode address with Mapbox', e);
    return null;
  }
}

/// Geocode Airbnb address using unified Mapbox geocoding
Future<void> _geocodeAirbnbAddress() async {
  final address = _airbnbAddressController.text.trim();
  if (address.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter an address first')),
    );
    return;
  }

  setState(() => _geocoding = true);

  try {
    final place = await _geocodeAddressWithMapbox(address);
    if (place != null) {
      setState(() {
        _airbnbLocation = place.location;
        _airbnbAddressConfirmed = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location found! ✓'), backgroundColor: Colors.green),
        );
      }
    } else {
      throw 'No coordinates found for address';
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to geocode Airbnb address', e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not find location: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _geocoding = false);
  }
}

/// Geocode the extracted address from URL metadata using unified Mapbox geocoding
Future<void> _geocodeExtractedAddress() async {
  if (_extractedAddress == null || _extractedAddress!['formatted'] == null) {
    return;
  }

  setState(() => _geocoding = true);

  try {
    final address = _extractedAddress!['formatted'] as String;
    final place = await _geocodeAddressWithMapbox(address);
    
    if (place != null) {
      setState(() {
        _extractedLocation = place.location;
        _extractedAddress = {'formatted': place.formattedAddress};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location found! ✓'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find coordinates for this address.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to geocode extracted address', e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geocoding failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _geocoding = false);
  }
}

/// Perform Google Places search
Future<void> _performGooglePlacesSearch(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty || trimmedQuery.length < 2) {
    if (mounted) {
      setState(() {
        _googlePlacesSearchResults = [];
        _googlePlacesSearching = false;
      });
    }
    return;
  }

  if (mounted) setState(() => _googlePlacesSearching = true);

  try {
    final predictions = await _googlePlacesService.searchPlaces(
      query: trimmedQuery,
      proximity: widget.proximityBias,
    );

    if (mounted) {
      setState(() {
        _googlePlacesSearchResults = predictions;
      });
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to search Google Places', e);
    if (mounted) {
      setState(() => _googlePlacesSearchResults = []);
    }
  } finally {
    if (mounted) setState(() => _googlePlacesSearching = false);
  }
}

/// Handle selection of a Google Places search result
Future<void> _selectGooglePlacesResult(PlacePrediction prediction) async {
  setState(() {
    _googlePlacesSearchResults = [];
    _googlePlacesSearching = true;
  });

  try {
    // Fetch full place details
    final placeDetails = await _googlePlacesService.getPlaceDetails(prediction.placeId);
    
    if (placeDetails == null) {
      if (mounted) {
        setState(() => _googlePlacesSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch place details'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Determine waypoint type from place types
    WaypointType? determinedType;
    if (placeDetails.types.contains('restaurant') || 
        placeDetails.types.contains('food') ||
        placeDetails.types.contains('cafe')) {
      determinedType = WaypointType.restaurant;
    } else if (placeDetails.types.contains('lodging') || 
               placeDetails.types.contains('hotel')) {
      determinedType = WaypointType.accommodation;
    } else if (placeDetails.types.contains('tourist_attraction') ||
               placeDetails.types.contains('point_of_interest')) {
      determinedType = WaypointType.attraction;
    }

    if (determinedType != null) {
      _selectedType = determinedType;
    }
    
    setState(() {
      _nameController.text = placeDetails.name;
      _descController.text = placeDetails.description ?? ''; // Include description from Google My Business
      _phoneController.text = placeDetails.phoneNumber ?? '';
      _addressSearchController.text = placeDetails.address ?? '';
      _ratingController.text = placeDetails.rating?.toString() ?? '';
      
      // Populate price range from Google My Business if available
      if (placeDetails.priceLevel != null) {
        // Convert priceLevel (0-4) to approximate price range
        switch (placeDetails.priceLevel) {
          case 1: // $
            _priceMinController.text = '10';
            _priceMaxController.text = '30';
            break;
          case 2: // $$
            _priceMinController.text = '30';
            _priceMaxController.text = '60';
            break;
          case 3: // $$$
            _priceMinController.text = '60';
            _priceMaxController.text = '120';
            break;
          case 4: // $$$$
            _priceMinController.text = '120';
            _priceMaxController.text = '300';
            break;
          default:
            // Free or unknown - leave empty
            break;
        }
      }
      
      _extractedLocation = placeDetails.location;
      _extractedAddress = placeDetails.address != null ? {'formatted': placeDetails.address} : null;
      _selectedPlace = placeDetails; // Store full place details for later use
      _hasSearchedOrExtracted = true;
      _googlePlacesSearching = false;
    });

    // Fetch photo if available
    if (placeDetails.photoReference != null) {
      _loadGooglePlacePhoto(placeDetails.photoReference!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location selected! ✓'), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to fetch place details', e);
    if (mounted) {
      setState(() => _googlePlacesSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load place details: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

@override
Widget build(BuildContext context) {
  return ScrollBlockingDialog(
            child: Container(
            width: 480,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
// Modern header (fixed at top)
Container(
padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
decoration: BoxDecoration(
border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
),
child: Row(
children: [
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF428A13), Color(0xFF2D5A27)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF428A13).withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 24),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
widget.existingWaypoint != null ? 'Edit Waypoint' : 'Add Waypoint',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w700,
color: Colors.grey.shade900,
letterSpacing: -0.5,
),
),
const SizedBox(height: 2),
Text(
'Search or tap on map to set location',
style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
),
],
),
),
Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
      debugPrint('🔴 [RouteBuilder] Add Waypoint X button tapped - closing dialog');
        Navigator.pop(context);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
    ),
  ),
),
],
),
),

// Scrollable content area (middle)
Expanded(
child: ScrollBlockingScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
mainAxisSize: MainAxisSize.min,
children: [
// Search location section
const SizedBox(height: 20),
  Row(
    children: [
      Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      // Show required indicator if address wasn't extracted
      if (_extractedAddress == null || _extractedAddress!['formatted'] == null) ...[
        const SizedBox(width: 4),
        const Text('*', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
      ],
    ],
  ),
  const SizedBox(height: 12),
  // Show extracted location status if available
  if (_extractedLocation != null && widget.preselectedPlace == null) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.location_on_rounded, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location from URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.blue.shade700)),
              Text('${_extractedLocation!.latitude.toStringAsFixed(6)}, ${_extractedLocation!.longitude.toStringAsFixed(6)}', style: TextStyle(fontSize: 12, color: Colors.blue.shade700.withOpacity(0.8))),
              if (_extractedAddress != null && _extractedAddress!['formatted'] != null)
                Text(_extractedAddress!['formatted'], style: TextStyle(fontSize: 11, color: Colors.blue.shade700.withOpacity(0.7))),
            ],
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 12),
],
// Mapbox search field - always show after URL extraction (user can override extracted address)
// If address wasn't extracted, this field is mandatory
Row(
  children: [
    Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _addressSearchController,
          decoration: InputDecoration(
            hintText: _extractedAddress == null || _extractedAddress!['formatted'] == null
                ? 'Search address or place... *'
                : 'Search address or place... (optional)',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
            ),
            suffixIcon: _addressSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    color: Colors.grey.shade400,
                    onPressed: () {
                      _addressSearchController.clear();
                      setState(() {
                        _googlePlacesSearchResults = [];
                      });
                    },
                  )
                : (_googlePlacesSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            _addressSearchDebounce?.cancel();
            _addressSearchDebounce = Timer(const Duration(milliseconds: 600), () {
              if (mounted) _performGooglePlacesSearch(value);
            });
            setState(() {}); // Update UI to show/hide clear button
          },
        ),
      ),
    ),
  ],
),
if (_googlePlacesSearchResults.isNotEmpty)
  Container(
    constraints: const BoxConstraints(maxHeight: 200),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    margin: const EdgeInsets.only(top: 8),
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: _googlePlacesSearchResults.length,
      itemBuilder: (context, index) {
        final prediction = _googlePlacesSearchResults[index];
        return ListTile(
          leading: Icon(Icons.location_on_rounded, color: Colors.blue.shade600, size: 20),
          title: Text(prediction.text, style: const TextStyle(fontWeight: FontWeight.w500)),
          onTap: () => _selectGooglePlacesResult(prediction),
        );
      },
    ),
  ),
if (widget.preselectedPlace != null && widget.preselectedPlace!.address != null)
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location selected', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green.shade700)),
                Text(widget.preselectedPlace!.address!, style: TextStyle(fontSize: 12, color: Colors.green.shade700.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  // Show message if address is required
  if (_extractedAddress == null || _extractedAddress!['formatted'] == null) ...[
    const SizedBox(height: 8),
    Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Please search and select a location',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  ],
// Only show Type and Sub-type fields after location is selected (when adding via + button)
// Always show them when editing or when preselectedPlace is provided
if (widget.existingWaypoint != null || 
    widget.preselectedPlace != null || 
    _hasSearchedOrExtracted) ...[
const SizedBox(height: 20),
Row(
  children: [
Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.3)),
    const SizedBox(width: 4),
    const Text('*', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
  ],
),
const SizedBox(height: 12),
Wrap(
spacing: 10,
runSpacing: 10,
children: WaypointType.values
.where((type) {
  // Exclude routePoint if excludeRoutePoint is true
  if (widget.excludeRoutePoint && type == WaypointType.routePoint) return false;
  // Exclude deprecated types (activity is duplicate of attraction, servicePoint is duplicate of service)
  if (type == WaypointType.activity || type == WaypointType.servicePoint) return false;
  // Exclude viewingPoint as requested
  if (type == WaypointType.viewingPoint) return false;
  return true;
})
.map((type) => _ModernTypeChip(
type: type,
isSelected: _selectedType == type,
onTap: () {
  setState(() {
    _selectedType = type;
  });
},
)).toList(),
),
if (_selectedType == WaypointType.accommodation) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Accommodation Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
const SizedBox(width: 4),
const Text('*', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
],
),
const SizedBox(height: 12),
Row(
children: [
Expanded(
child: _ModernSubtypeChip(
icon: Icons.apartment_rounded,
label: 'Hotel',
isSelected: _accommodationType == POIAccommodationType.hotel,
onTap: () => setState(() => _accommodationType = POIAccommodationType.hotel),
),
),
const SizedBox(width: 10),
Expanded(
child: _ModernSubtypeChip(
icon: Icons.home_rounded,
label: 'Airbnb',
isSelected: _accommodationType == POIAccommodationType.airbnb,
onTap: () => setState(() => _accommodationType = POIAccommodationType.airbnb),
),
),
],
),
if (_accommodationType == POIAccommodationType.airbnb) ...[
const SizedBox(height: 16),
const Text('Airbnb Property', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _airbnbAddressController,
decoration: InputDecoration(
labelText: 'Address or Location',
hintText: 'e.g., 123 Main St, Oslo, Norway',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
helperText: 'We\'ll use this to place the marker on the map',
),
),
const SizedBox(height: 8),
OutlinedButton.icon(
onPressed: _geocoding ? null : _geocodeAirbnbAddress,
icon: _geocoding
? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
: const Icon(Icons.my_location, size: 18),
label: Text(_geocoding ? 'Finding...' : 'Find Location'),
),
if (_airbnbAddressConfirmed)
Padding(
padding: const EdgeInsets.only(top: 8),
child: Row(
children: [
Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
const SizedBox(width: 4),
Text(
'Location confirmed',
style: TextStyle(color: Colors.green.shade700, fontSize: 12),
),
],
),
),
],
],
if (_selectedType == WaypointType.restaurant) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Meal Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 12),
Wrap(
spacing: 10,
runSpacing: 10,
children: MealTime.values.map((time) => _ModernSubtypeChip(
icon: getMealTimeIcon(time),
label: getMealTimeLabel(time),
isSelected: _mealTime == time,
onTap: () => setState(() => _mealTime = time),
)).toList(),
),
],
if (_selectedType == WaypointType.activity) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Activity Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 12),
Wrap(
spacing: 10,
runSpacing: 10,
children: ActivityTime.values.map((time) => _ModernSubtypeChip(
icon: getActivityTimeIcon(time),
label: getActivityTimeLabel(time),
isSelected: _activityTime == time,
onTap: () => setState(() => _activityTime = time),
)).toList(),
),
],
], // End of conditional Type/Sub-type section
// Show price range indicator if available from Google Places (display only, not input)
Builder(
  builder: (context) {
final priceLevel = widget.preselectedPlace?.priceLevel;
    if (priceLevel != null && widget.preselectedPlace!.priceRangeString != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
          const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
              color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
                Icon(Icons.euro_rounded, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
                  'Price Range: ${widget.preselectedPlace!.priceRangeString!}',
                style: TextStyle(
                  fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                ),
              ),
          ],
        ),
      ),
    ],
      );
    }
    return const SizedBox.shrink();
  },
),
// Show reviews if available (from Google Places or existing waypoint)
Builder(
  builder: (context) {
final reviews = widget.preselectedPlace?.reviews ?? [];
    if (reviews.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
  const SizedBox(height: 20),
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.reviews_rounded, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              'Reviews',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.take(3).map((review) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (review.rating != null) ...[
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(
                          review.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (review.authorName != null)
                    Expanded(
                      child: Text(
                        review.authorName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (review.text != null) ...[
                const SizedBox(height: 4),
                Text(
                  review.text!.length > 150 ? '${review.text!.substring(0, 150)}...' : review.text!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        )).toList(),
      ],
    ),
  ),
],
      );
    }
    return const SizedBox.shrink();
  },
),
// Only show waypoint details fields after search or extraction
if (_hasSearchedOrExtracted) ...[
const SizedBox(height: 20),
Container(height: 1, color: Colors.grey.shade100, margin: const EdgeInsets.only(bottom: 20)),
_ModernTextField(
label: 'Name',
isRequired: true,
controller: _nameController,
hintText: 'e.g., Abisko Mountain Lodge',
prefixIcon: Icons.label_outline_rounded,
),
const SizedBox(height: 16),
_ModernTextField(
label: 'Description',
isRequired: false,
controller: _descController,
hintText: 'Add notes, tips, or details...',
prefixIcon: Icons.notes_rounded,
maxLines: 3,
),
// Estimated Price Range
if (_selectedType == WaypointType.restaurant ||
    _selectedType == WaypointType.accommodation ||
    _selectedType == WaypointType.activity ||
    _selectedType == WaypointType.servicePoint) ...[
const SizedBox(height: 16),
Row(
  children: [
    Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(
      _selectedType == WaypointType.accommodation
          ? 'Estimated Price Range (per night)'
          : 'Estimated Price Range (optional)',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
    ),
  ],
),
const SizedBox(height: 12),
Row(
  children: [
    Expanded(
      child: _ModernTextField(
        label: 'Min €',
        isRequired: false,
        controller: _priceMinController,
        hintText: 'Min',
        prefixIcon: Icons.euro,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _ModernTextField(
        label: 'Max €',
        isRequired: false,
        controller: _priceMaxController,
        hintText: 'Max',
        prefixIcon: Icons.euro,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ),
  ],
),
],
// Photo URL
const SizedBox(height: 16),
_ModernTextField(
  label: 'Photo URL',
  isRequired: false,
  controller: _photoUrlController,
  hintText: 'https://example.com/image.jpg',
  prefixIcon: Icons.image_rounded,
),
// Phone Number
const SizedBox(height: 16),
_ModernTextField(
  label: 'Phone Number',
  isRequired: false,
  controller: _phoneController,
  hintText: '+1 234 567 8900',
  prefixIcon: Icons.phone_rounded,
  keyboardType: TextInputType.phone,
),
// Rating/Review Score
const SizedBox(height: 16),
_ModernTextField(
  label: 'Rating / Review Score',
  isRequired: false,
  controller: _ratingController,
  hintText: 'e.g., 4.5',
  prefixIcon: Icons.star_rounded,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
),
// Image section - show extracted image or allow upload
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 8),
// Show Google Place photo if available
if (_googlePlacePhotoUrl != null && !_loadingPhoto) ...[
Container(
height: 120,
width: double.infinity,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Image.network(
_googlePlacePhotoUrl!,
fit: BoxFit.cover,
errorBuilder: (_, __, ___) => Container(
color: Colors.grey.shade100,
child: Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade400),
const SizedBox(height: 4),
Text('Image unavailable', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
],
),
),
),
loadingBuilder: (context, child, loadingProgress) {
if (loadingProgress == null) return child;
return Container(
color: Colors.grey.shade100,
child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
);
},
),
),
),
const SizedBox(height: 12),
],
// Show uploaded image if available
if (_uploadedImageUrl != null) ...[
Container(
height: 120,
width: double.infinity,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Stack(
children: [
ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Image.network(
_uploadedImageUrl!,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => Container(
color: Colors.grey.shade100,
child: Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade400),
const SizedBox(height: 4),
Text('Image unavailable', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
],
),
),
),
loadingBuilder: (context, child, loadingProgress) {
if (loadingProgress == null) return child;
return Container(
color: Colors.grey.shade100,
child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
);
},
),
),
Positioned(
top: 8,
right: 8,
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: () {
setState(() {
_uploadedImageUrl = null;
});
},
borderRadius: BorderRadius.circular(20),
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.6),
shape: BoxShape.circle,
),
child: const Icon(Icons.close, size: 16, color: Colors.white),
),
),
),
),
],
),
),
const SizedBox(height: 12),
],
// Image upload button
OutlinedButton.icon(
onPressed: _uploadingImage ? null : _pickAndUploadImage,
icon: _uploadingImage
? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
: const Icon(Icons.add_photo_alternate_rounded, size: 18),
label: Text(_uploadingImage ? 'Uploading...' : 'Add Image'),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
side: BorderSide(color: Colors.grey.shade300),
),
),
// Show address, latitude, and longitude if location is set
if (_extractedLocation != null || widget.preselectedPlace != null) ...[
const SizedBox(height: 16),
if (_extractedAddress != null && _extractedAddress!['formatted'] != null) ...[
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(
children: [
Icon(Icons.location_on_rounded, size: 18, color: Colors.grey.shade500),
const SizedBox(width: 10),
Expanded(
child: Text(
_extractedAddress!['formatted'],
style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
),
),
],
),
),
const SizedBox(height: 12),
],
// Duplicate coordinates display removed - coordinates only shown in Advanced: Manual Coordinates section
// if (_extractedLocation != null) ...[
// Row(
// children: [
// Expanded(
// child: Container(
// padding: const EdgeInsets.all(12),
// decoration: BoxDecoration(
// color: Colors.grey.shade50,
// borderRadius: BorderRadius.circular(12),
// border: Border.all(color: Colors.grey.shade200),
// ),
// child: Row(
// children: [
// Icon(Icons.north_rounded, size: 18, color: Colors.grey.shade500),
// const SizedBox(width: 10),
// Expanded(
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text('Latitude', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
// const SizedBox(height: 2),
// Text(
// _extractedLocation!.latitude.toStringAsFixed(6),
// style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
// ),
// ],
// ),
// ),
// ],
// ),
// ),
// ),
// ),
// const SizedBox(width: 12),
// Expanded(
// child: Container(
// padding: const EdgeInsets.all(12),
// decoration: BoxDecoration(
// color: Colors.grey.shade50,
// borderRadius: BorderRadius.circular(12),
// border: Border.all(color: Colors.grey.shade200),
// ),
// child: Row(
// children: [
// Icon(Icons.east_rounded, size: 18, color: Colors.grey.shade500),
// const SizedBox(width: 10),
// Expanded(
// child: Column(
// crossAxisAlignment: CrossAxisAlignment.start,
// children: [
// Text('Longitude', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
// const SizedBox(height: 2),
// Text(
// _extractedLocation!.longitude.toStringAsFixed(6),
// style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
// ),
// ],
// ),
// ),
// ],
// ),
// ),
// ),
// ],
// ),
// ],
// ],
// ],
// Show website URL if available from Google Places
if (widget.preselectedPlace?.website != null) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Website', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(
children: [
Icon(Icons.link_rounded, size: 18, color: Colors.grey.shade500),
const SizedBox(width: 10),
Expanded(
child: Text(
widget.preselectedPlace!.website!,
style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
],
),
),
],
], // Close website section
], // Close _hasSearchedOrExtracted section
], // Close children array
),
),
),
// Footer with buttons (fixed at bottom)
Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
),
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Status indicator (left side) - only show if location is set
    if (widget.preselectedPlace != null || _extractedLocation != null || (_accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed) || _selectedType == WaypointType.routePoint)
      Expanded(
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF428A13)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.preselectedPlace != null || _extractedLocation != null || (_accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed)
                    ? 'Location selected'
                    : 'Location set from map',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
),
],
),
)
else
Expanded(
child: Row(
children: [
Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade600),
const SizedBox(width: 8),
Flexible(
              child: Text(
                'Search or set location first',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                overflow: TextOverflow.ellipsis,
              ),
),
],
),
),
    const SizedBox(width: 12),
    // Action buttons (right side)
    if (widget.existingWaypoint != null)
  TextButton(
    onPressed: () {
      Navigator.of(context).pop(RouteWaypoint(
        id: widget.existingWaypoint!.id,
        type: widget.existingWaypoint!.type,
        position: widget.existingWaypoint!.position,
        name: '', // Empty name signals deletion
        order: widget.existingWaypoint!.order,
      ));
    },
    style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
        child: Text('Delete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red.shade700)),
  ),
    if (widget.existingWaypoint != null) const SizedBox(width: 8),
TextButton(
onPressed: () => Navigator.of(context).pop(widget.existingWaypoint),
style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
      child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
),
    const SizedBox(width: 8),
ElevatedButton(
onPressed: _canSave() ? _save : null,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF428A13),
disabledBackgroundColor: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
elevation: 0,
shadowColor: Colors.transparent,
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
          Icon(Icons.check_rounded, size: 18, color: _canSave() ? Colors.white : Colors.grey.shade400),
const SizedBox(width: 6),
          Text(
            widget.existingWaypoint != null ? 'Save Changes' : 'Add Waypoint',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _canSave() ? Colors.white : Colors.grey.shade400),
          ),
],
),
),
],
),
),
        ],
      ),
    ),
  );
}

bool _canSave() {
// Type is mandatory - should always be set, but validate anyway
// Ensure type is not one of the excluded types
if (_selectedType == WaypointType.activity || 
    _selectedType == WaypointType.servicePoint || 
    _selectedType == WaypointType.viewingPoint) {
  return false;
}

if (_nameController.text.trim().isEmpty) return false;

// Route points don't need Google Place selection - just name and location from proximity bias
if (_selectedType == WaypointType.routePoint) {
return widget.proximityBias != null; // Must have a location set
}

if (_selectedType == WaypointType.accommodation && _accommodationType == null) return false;
if (_accommodationType == POIAccommodationType.airbnb && !_airbnbAddressConfirmed) return false;

// Allow saving if:
// 1. Google Places preselected place
// 2. Location extracted from URL metadata
// 3. Airbnb with confirmed address
// 4. Proximity bias (map tap location)
final hasPreselectedPlace = widget.preselectedPlace != null;
final hasExtractedLocation = _extractedLocation != null;
final hasAirbnbLocation = _accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed;

// For other cases, check if we have any location
if (!hasPreselectedPlace && !hasExtractedLocation && !hasAirbnbLocation && widget.proximityBias == null) return false;

return true;
}

void _save() async {
  if (!_canSave()) return;

  String? photoUrl;
  // Priority: 1. Uploaded image, 2. Photo URL field, 3. Google Place photo
  if (_uploadedImageUrl != null) {
    photoUrl = _uploadedImageUrl;
  } else if (_photoUrlController.text.trim().isNotEmpty) {
    photoUrl = _photoUrlController.text.trim();
  } else if (_googlePlacePhotoUrl != null) {
    photoUrl = _googlePlacePhotoUrl;
  }

  // Calculate price range
  PriceRange? priceRange;
  final minPriceText = _priceMinController.text.trim();
  final maxPriceText = _priceMaxController.text.trim();
  if (minPriceText.isNotEmpty || maxPriceText.isNotEmpty) {
    final minPrice = double.tryParse(minPriceText.replaceAll(',', '.')) ?? 0.0;
    final maxPrice = double.tryParse(maxPriceText.replaceAll(',', '.')) ?? 0.0;
    if (minPrice > 0 || maxPrice > 0) {
      // If only one value is provided, use it for both min and max
      // Ensure min <= max
      final actualMin = minPrice > 0 ? minPrice : (maxPrice > 0 ? maxPrice : 0.0);
      final actualMax = maxPrice > 0 ? maxPrice : (minPrice > 0 ? minPrice : 0.0);
      priceRange = PriceRange(
        min: actualMin <= actualMax ? actualMin : actualMax,
        max: actualMax >= actualMin ? actualMax : actualMin,
        currency: 'EUR',
      );
    }
  }

  ll.LatLng position;
  String? address;
  
  // Priority order for position:
  // 1. Google Places preselected place (from map search)
  // 2. Google Places selected place (from dialog search)
  // 3. Extracted location from URL metadata
  // 4. Airbnb geocoded location
  // 5. Route point proximity bias
  // 6. Proximity bias (map tap location) as fallback
  
  if (widget.preselectedPlace != null) {
    position = widget.preselectedPlace!.location;
    address = widget.preselectedPlace!.address;
  } else if (_selectedPlace != null) {
    // Use location from place selected via dialog search
    position = _selectedPlace!.location;
    address = _selectedPlace!.address;
  } else if (_extractedLocation != null) {
    // Use location extracted from URL metadata
    position = _extractedLocation!;
    address = _extractedAddress?['formatted'] as String?;
  } else if (_selectedType == WaypointType.routePoint && widget.proximityBias != null) {
    // Route points use the proximity bias (map tap location)
    position = widget.proximityBias!;
    address = null;
  } else if (_accommodationType == POIAccommodationType.airbnb && _airbnbLocation != null) {
    position = _airbnbLocation!;
    address = _airbnbAddressController.text.trim().isEmpty ? null : _airbnbAddressController.text.trim();
  } else if (widget.existingWaypoint != null) {
    // Use existing waypoint's position when editing
    position = widget.existingWaypoint!.position;
    address = widget.existingWaypoint!.address;
  } else if (widget.proximityBias != null) {
    // Use proximity bias (map tap location) for extracted metadata waypoints
    position = widget.proximityBias!;
    address = _extractedAddress?['formatted'] as String?;
  } else {
    return;
  }

  // Parse rating from controller
  double? rating;
  final ratingText = _ratingController.text.trim();
  if (ratingText.isNotEmpty) {
    rating = double.tryParse(ratingText.replaceAll(',', '.'));
  }
  // Priority: 1. Manual entry, 2. Preselected place, 3. Selected place, 4. Existing waypoint
  final finalRating = rating ?? widget.preselectedPlace?.rating ?? _selectedPlace?.rating ?? widget.existingWaypoint?.rating;

  final waypoint = RouteWaypoint(
    id: widget.existingWaypoint?.id, // Preserve ID when editing
    type: _selectedType,
    position: position,
    name: _nameController.text.trim(),
    description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    order: widget.existingWaypoint?.order ?? 0, // Preserve order when editing
    googlePlaceId: widget.preselectedPlace?.placeId ?? _selectedPlace?.placeId ?? widget.existingWaypoint?.googlePlaceId,
    address: address ?? widget.existingWaypoint?.address,
    rating: finalRating,
    website: widget.preselectedPlace?.website ?? _selectedPlace?.website ?? widget.existingWaypoint?.website,
    phoneNumber: _phoneController.text.trim().isEmpty 
        ? (widget.preselectedPlace?.phoneNumber ?? _selectedPlace?.phoneNumber ?? widget.existingWaypoint?.phoneNumber)
        : _phoneController.text.trim(),
    photoUrl: photoUrl ?? _googlePlacePhotoUrl ?? widget.existingWaypoint?.photoUrl,
    accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
    mealTime: _selectedType == WaypointType.restaurant ? _mealTime : null,
    activityTime: _selectedType == WaypointType.activity ? _activityTime : null,
    linkUrl: null, // URL extraction moved to legacy
    linkImageUrl: null, // URL extraction moved to legacy
    estimatedPriceRange: priceRange ?? widget.existingWaypoint?.estimatedPriceRange,
    timeSlotCategory: widget.existingWaypoint?.timeSlotCategory, // Preserve timeSlotCategory when editing
  );

  Navigator.of(context).pop(waypoint);
}
}

/// Modern type chip widget
class _ModernTypeChip extends StatelessWidget {
final WaypointType type;
final bool isSelected;
final VoidCallback onTap;

const _ModernTypeChip({
required this.type,
required this.isSelected,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final color = getWaypointColor(type);
return GestureDetector(
onTap: onTap,
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOutCubic,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
decoration: BoxDecoration(
color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
boxShadow: isSelected
? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
: null,
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 200),
width: isSelected ? 20 : 0,
child: isSelected
? Padding(
padding: const EdgeInsets.only(right: 6),
child: Icon(Icons.check_rounded, size: 16, color: color),
)
: const SizedBox.shrink(),
),
Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
borderRadius: BorderRadius.circular(8),
),
child: Icon(getWaypointIcon(type), size: 16, color: isSelected ? color : Colors.grey.shade500),
),
const SizedBox(width: 10),
Text(
getWaypointLabel(type),
style: TextStyle(
fontSize: 14,
fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
color: isSelected ? color : Colors.grey.shade700,
),
),
],
),
),
);
}
}

/// Modern subtype chip widget for accommodation types
class _ModernSubtypeChip extends StatelessWidget {
final IconData icon;
final String label;
final bool isSelected;
final VoidCallback onTap;

const _ModernSubtypeChip({
required this.icon,
required this.label,
required this.isSelected,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
decoration: BoxDecoration(
color: isSelected ? const Color(0xFF9C27B0).withValues(alpha: 0.1) : Colors.white,
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade200,
width: isSelected ? 1.5 : 1,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 18, color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade500),
const SizedBox(width: 8),
Text(
label,
style: TextStyle(
fontSize: 13,
fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade700,
),
),
],
),
),
);
}
}

/// Modern text field widget with focus states
class _ModernTextField extends StatefulWidget {
final String? label;
final bool isRequired;
final TextEditingController controller;
final String hintText;
final IconData? prefixIcon;
final int maxLines;
final TextInputType? keyboardType;

const _ModernTextField({
this.label,
required this.isRequired,
required this.controller,
required this.hintText,
this.prefixIcon,
this.maxLines = 1,
this.keyboardType,
});

@override
State<_ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<_ModernTextField> {
bool _isFocused = false;

@override
Widget build(BuildContext context) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (widget.label != null) ...[
Row(
children: [
Text(
widget.label!,
style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
),
if (widget.isRequired)
const Text(' *', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
],
),
const SizedBox(height: 8),
],
AnimatedContainer(
duration: const Duration(milliseconds: 200),
decoration: BoxDecoration(
color: _isFocused ? Colors.white : Colors.grey.shade50,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: _isFocused ? const Color(0xFF428A13) : Colors.grey.shade200,
width: _isFocused ? 2 : 1,
),
boxShadow: _isFocused
? [BoxShadow(color: const Color(0xFF428A13).withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
: null,
),
child: Focus(
onFocusChange: (focused) => setState(() => _isFocused = focused),
child: TextField(
controller: widget.controller,
maxLines: widget.maxLines,
keyboardType: widget.keyboardType,
style: TextStyle(fontSize: 15, color: Colors.grey.shade900),
decoration: InputDecoration(
hintText: widget.hintText,
hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
prefixIcon: widget.prefixIcon != null
? Container(
padding: const EdgeInsets.all(12),
child: Icon(
widget.prefixIcon,
size: 20,
color: _isFocused ? const Color(0xFF428A13) : Colors.grey.shade400,
),
)
: null,
border: InputBorder.none,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
),
),
),
),
],
);
}
}

// _WaypointEditorDialog removed - now using unified _AddWaypointDialog for both add and edit

