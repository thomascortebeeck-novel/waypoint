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
import 'package:waypoint/models/orderable_item.dart';
import 'package:waypoint/components/reorder_controls.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/components/builder/sequential_waypoint_list.dart';
import 'package:waypoint/services/waypoint_grouping_service.dart';
import 'package:waypoint/services/travel_calculator_service.dart';
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
Timer? _searchDebounce;
bool _snapToTrail = true;
bool _busy = false;
bool _searching = false;
bool _isProgrammaticCameraMove = false; // Track programmatic camera moves to prevent map tap pop-up
bool _dialogOrBottomSheetOpen = false; // Track when dialogs/bottom sheets are open to prevent map taps
final _points = <ll.LatLng>[];
Map<String, dynamic>? _previewGeometry;
double? _previewDistance;
int? _previewDuration;
List<ElevationPoint> _previewElevation = const [];
double? _previewAscent;
double? _previewDescent;
List<PlaceSuggestion> _searchResults = [];

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
final hasWaypoints = _poiWaypoints.isNotEmpty || _points.isNotEmpty || widget.initial != null;

if (hasWaypoints) {
  // Fit map to show all waypoints when editing existing route
  _fitToWaypoints();
  // Load POIs after fitting
  _loadPOIs();
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
if (widget.start != null) _points.add(widget.start!);
if (widget.end != null) _points.add(widget.end!);
if (widget.initial != null) {
_previewGeometry = widget.initial!.geometry;
_previewDistance = widget.initial!.distance;
_previewDuration = widget.initial!.duration;
// Only load route points if there's no preview geometry
// If geometry exists, it was already snapped and we don't want to lose that
if (widget.initial!.waypoints.isNotEmpty && _points.isEmpty && _previewGeometry == null) {
_points.addAll(widget.initial!.waypoints.map((w) => ll.LatLng(w['lat']!, w['lng']!)));
} else if (widget.initial!.routePoints.isNotEmpty && _points.isEmpty) {
// Load routePoints for editing
_points.addAll(widget.initial!.routePoints.map((w) => ll.LatLng(w['lat']!, w['lng']!)));
}
// Load existing POI waypoints and auto-assign categories if missing
if (widget.initial!.poiWaypoints.isNotEmpty) {
final loadedWaypoints = widget.initial!.poiWaypoints.map((w) {
final waypoint = RouteWaypoint.fromJson(w);
// Auto-assign time slot category if not set
if (waypoint.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(waypoint);
return waypoint.copyWith(timeSlotCategory: autoCategory);
}
return waypoint;
}).toList();
// Sort by order field to preserve the order from builder screen
loadedWaypoints.sort((a, b) => a.order.compareTo(b.order));
_poiWaypoints.addAll(loadedWaypoints);
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
_poiDebounce?.cancel();
_searchController.dispose();
_searchFocusNode.dispose();
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
         _points.firstOrNull ?? 
         widget.start ?? 
         const ll.LatLng(61.0, 8.5);
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

/// Fit map to show all waypoints and route points
void _fitToWaypoints() {
  final allPoints = <ll.LatLng>[];
  
  // Add route points
  if (_points.isNotEmpty) {
    allPoints.addAll(_points);
  }
  
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

/// Returns the appropriate activity label based on activity category
String _getActivityLabel() {
return _getActivityLabelStatic(widget.activityCategory);
}

/// Handle back button press - return current route state to keep waypoint order in sync
void _handleBackPress() {
// If we have waypoints or route data, return the current state
if (_poiWaypoints.isNotEmpty || _points.isNotEmpty || _previewGeometry != null) {
// CRITICAL: Always preserve preview geometry (contains snapped route)
Map<String, dynamic> geometry;
if (_previewGeometry != null) {
geometry = _previewGeometry!;
} else if (_points.isNotEmpty) {
// Create geometry from route points if no preview exists
geometry = {
'type': 'LineString',
'coordinates': _points.map((p) => [p.longitude, p.latitude]).toList(),
};
} else if (_poiWaypoints.isNotEmpty) {
// Create empty geometry centered on first waypoint as last resort
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
distance: _previewDistance ?? 0,
duration: _previewDuration ?? 0,
routePoints: _points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
elevationProfile: _previewElevation.isNotEmpty ? _previewElevation : null,
ascent: _previewAscent,
descent: _previewDescent,
poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList(),
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
    : (_points.isNotEmpty ? _points.first : widget.start ?? const ll.LatLng(61.0, 8.5)));
return Scaffold(
backgroundColor: context.colors.surface,
appBar: AppBar(
backgroundColor: context.colors.surface.withValues(alpha: 0.9),
scrolledUnderElevation: 0,
elevation: 0,
toolbarHeight: 56,
leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBackPress),
title: Text('Build Route', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
actions: [
Padding(
padding: const EdgeInsets.symmetric(horizontal: 8),
child: Row(children: [
Text('Snap to trail', style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.7))),
const SizedBox(width: 8),
Switch(value: _snapToTrail, onChanged: (v) => setState(() => _snapToTrail = v)),
const SizedBox(width: 8),
]),
),
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
snapToTrail: _snapToTrail,
onToggleSnap: (v) => setState(() => _snapToTrail = v),
poiWaypoints: _poiWaypoints,
routePoints: _points,
previewDistance: _previewDistance,
previewDuration: _previewDuration,
elevation: _previewElevation,
ascent: _previewAscent,
descent: _previewDescent,
busy: _busy,
onAddWaypoint: _showAddWaypointDialog,
onEditWaypoint: _editWaypoint,
onAddRoutePoint: _showAddRoutePointDialog,
onDeleteRoutePoint: (index) {
setState(() {
_points.removeAt(index);
});
_updatePreview();
},
onReorderRoutePoints: (oldIndex, newIndex) {
setState(() {
if (newIndex > oldIndex) newIndex -= 1;
final item = _points.removeAt(oldIndex);
_points.insert(newIndex, item);
});
_updatePreview();
},
onPreview: _points.length < 2 ? null : _updatePreview,
onSave: (_points.length < 2 && _poiWaypoints.isEmpty) ? null : _buildAndSave,
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
// CRITICAL: Transparent overlay shield that blocks ALL events from reaching the Mapbox Platform View
// This is necessary because Flutter's AbsorbPointer doesn't stop Platform View (HtmlElementView) events
// The shield must be opaque to hit tests to block browser-level DOM events
if (_dialogOrBottomSheetOpen)
  Positioned.fill(
    child: MouseRegion(
      cursor: SystemMouseCursors.basic, // Force standard cursor instead of map's grabbing hand
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // CRITICAL: This blocks clicks at the Flutter layer
        onTap: () {}, // Consumes tap events
        onScaleUpdate: (_) {}, // Consumes pinch/zoom/pan gestures (scale is a superset of pan)
        child: Container(
          color: Colors.transparent, // Invisible but still hits tests - blocks events to Mapbox canvas
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
onSelect: (s) => _selectPlace(s),
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
onFitWaypoints: (_poiWaypoints.isNotEmpty || _points.length >= 2) ? _fitToWaypoints : null,
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
// CRITICAL: Transparent overlay shield that blocks ALL events from reaching the Mapbox Platform View
// This is necessary because Flutter's AbsorbPointer doesn't stop Platform View (HtmlElementView) events
// The shield must be opaque to hit tests to block browser-level DOM events
if (_dialogOrBottomSheetOpen)
  Positioned.fill(
    child: MouseRegion(
      cursor: SystemMouseCursors.basic, // Force standard cursor instead of map's grabbing hand
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // CRITICAL: This blocks clicks at the Flutter layer
        onTap: () {}, // Consumes tap events
        onScaleUpdate: (_) {}, // Consumes pinch/zoom/pan gestures (scale is a superset of pan)
        child: Container(
          color: Colors.transparent, // Invisible but still hits tests - blocks events to Mapbox canvas
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
onSelect: (s) => _selectPlace(s),
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
onFitWaypoints: (_poiWaypoints.isNotEmpty || _points.length >= 2) ? _fitToWaypoints : null,
),
),
),
),
Positioned(
right: 12,
bottom: 12 + 180, // keep above bottom sheet when collapsed
child: Column(children: [
if (_points.isNotEmpty)
_SmallControlButton(
icon: Icons.undo,
label: 'Undo',
onTap: () async {
setState(() => _points.removeLast());
await _updatePreview();
},
),
if (_points.isNotEmpty) const SizedBox(height: 8),
if (_points.isNotEmpty)
_SmallControlButton(
icon: Icons.clear_all,
label: 'Clear',
onTap: () {
setState(() {
_points.clear();
_previewGeometry = null;
_previewDistance = null;
_previewDuration = null;
_previewElevation = [];
_previewAscent = null;
_previewDescent = null;
});
},
),
]),
),

// Bottom draggable panel
_BottomPanel(
poiWaypoints: _poiWaypoints,
routePoints: _points,
previewDistance: _previewDistance,
previewDuration: _previewDuration,
elevation: _previewElevation,
ascent: _previewAscent,
descent: _previewDescent,
busy: _busy,
onAddWaypoint: _showAddWaypointDialog,
onEditWaypoint: _editWaypoint,
onAddRoutePoint: _showAddRoutePointDialog,
onDeleteRoutePoint: (index) {
setState(() {
_points.removeAt(index);
});
_updatePreview();
},
onReorderRoutePoints: (oldIndex, newIndex) {
setState(() {
if (newIndex > oldIndex) newIndex -= 1;
final item = _points.removeAt(oldIndex);
_points.insert(newIndex, item);
});
_updatePreview();
},
onPreview: _points.length < 2 ? null : _updatePreview,
onSave: (_points.length < 2 && _poiWaypoints.isEmpty) ? null : _buildAndSave,
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
routeOrderManager: _routeOrderManager,
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

/// NEW: Mapbox-powered editor using AdaptiveMapWidget
Widget _buildMapboxEditor(ll.LatLng center) {
  // Convert preview geometry to polyline
  final polylines = <MapPolyline>[];
  if (_previewGeometry != null && _coordsToLatLng(_previewGeometry!['coordinates']).isNotEmpty) {
    polylines.add(MapPolyline(
      id: 'route',
      points: _coordsToLatLng(_previewGeometry!['coordinates']),
      color: const Color(0xFF4CAF50),
      width: 5,
      borderColor: Colors.white,
      borderWidth: 2,
    ));
  }
  
  // Convert route points to annotations
  final annotations = <MapAnnotation>[];
  for (int i = 0; i < _points.length; i++) {
    final isStart = i == 0;
    final isEnd = i == _points.length - 1;
    annotations.add(MapAnnotation(
      id: 'route_point_$i',
      position: _points[i],
      icon: isStart ? Icons.circle : (isEnd ? Icons.circle : Icons.circle),
      color: isStart ? const Color(0xFF52B788) : (isEnd ? const Color(0xFFD62828) : const Color(0xFFFF9800)),
      label: isStart ? 'A' : (isEnd ? 'B' : ''),
      draggable: false,
      onTap: () => _showRoutePointOptions(i),
    ));
  }
  
  // Convert OSM POIs to annotations (with deduplication)
  // Skip OSM POIs that are very close to custom waypoints (within ~50m)
  // Also filter out OSM viewpoints - Mapbox shows viewpoints natively, so we don't need OSM duplicates
  // This prevents duplicate markers when Mapbox style shows POIs and we also have OSM POIs
  int poiDeduplicated = 0;
  int viewpointsFiltered = 0;
  
  // First pass: Filter out viewpoints (Mapbox handles these natively)
  final nonViewpointPOIs = _osmPOIs.where((poi) {
    if (poi.type == POIType.viewpoint) {
      viewpointsFiltered++;
      Log.i('route_builder', 'Skipping OSM viewpoint ${poi.name} - Mapbox shows viewpoints natively');
      return false;
    }
    return true;
  }).toList();
  
  // Second pass: Deduplicate OSM POIs that match custom waypoints
  // NEW: Track OSM POIs to remove (match custom waypoints)
  final osmPoisToRemove = <String>{}; // Track OSM POI IDs to remove
  
  for (final poi in nonViewpointPOIs) {
    // Check if this OSM POI matches any custom waypoint
    for (final wp in _poiWaypoints) {
      final distance = _calculateDistance(poi.coordinates, wp.position);
      
      // Check both distance AND name similarity
      final nameSimilar = _areNamesSimilar(poi.name.toLowerCase(), wp.name.toLowerCase());
      
      if (distance < 0.05 || (distance < 0.1 && nameSimilar)) { 
        // 50m threshold OR 100m with similar name
        osmPoisToRemove.add(poi.id);
        poiDeduplicated++;
        Log.i('route_builder', '🗑️ Removing OSM POI ${poi.name} - matches custom waypoint ${wp.name} (${(distance * 1000).toStringAsFixed(1)}m, nameSimilar: $nameSimilar)');
        break;
      }
    }
  }
  
  // Filter out OSM POIs that match custom waypoints
  final deduplicatedOSMPOIs = nonViewpointPOIs.where((poi) => !osmPoisToRemove.contains(poi.id)).toList();
  
  // Third pass: Check proximity to route points and other OSM POIs
  for (final poi in deduplicatedOSMPOIs) {
    bool isDuplicate = false;
    
    // Also check against route points
    if (!isDuplicate) {
      for (final point in _points) {
        final distance = _calculateDistance(poi.coordinates, point);
        if (distance < 0.05) { // 50 meters threshold
          isDuplicate = true;
          poiDeduplicated++;
          Log.i('route_builder', 'Skipping OSM POI ${poi.name} - too close to route point (${(distance * 1000).toStringAsFixed(1)}m)');
          break;
        }
      }
    }
    
    // Also check if this OSM POI is very close to another OSM POI of the same type (within 50m)
    // This helps reduce duplicates when Mapbox also shows the same POI
    if (!isDuplicate) {
      for (final otherPoi in deduplicatedOSMPOIs) {
        if (otherPoi.id != poi.id && otherPoi.type == poi.type) {
          final distance = _calculateDistance(poi.coordinates, otherPoi.coordinates);
          if (distance < 0.05) { // 50 meters threshold
            // If they're the same type and very close, prefer the one with a better name or skip both
            // For now, skip the second one found (simple heuristic)
            isDuplicate = true;
            poiDeduplicated++;
            Log.i('route_builder', 'Skipping OSM POI ${poi.name} - too close to another ${poi.type.name} POI (${(distance * 1000).toStringAsFixed(1)}m)');
            break;
          }
        }
      }
    }
    
    if (!isDuplicate) {
      annotations.add(MapAnnotation.fromPOI(
        poi,
        onTap: () => _showOSMPOIDetails(poi),
      ));
    }
  }
  
  if (viewpointsFiltered > 0) {
    Log.i('route_builder', '📍 Filtered $viewpointsFiltered OSM viewpoints (Mapbox shows viewpoints natively)');
  }
  if (poiDeduplicated > 0) {
    Log.i('route_builder', '📍 Deduplication summary: ${osmPoisToRemove.length} OSM POIs removed (match custom waypoints), ${poiDeduplicated - osmPoisToRemove.length} additional duplicates (too close to route points/other POIs)');
  }
  Log.i('route_builder', '📍 Converting ${_osmPOIs.length} OSM POIs to ${annotations.length} annotations (${_osmPOIs.length - annotations.length} filtered: $viewpointsFiltered viewpoints + $poiDeduplicated duplicates)');
  
  // Convert custom waypoints to annotations
  for (final wp in _poiWaypoints) {
    annotations.add(MapAnnotation.fromWaypoint(
      wp,
      draggable: false,
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
      
      // Load POIs after map is ready (if not already loading)
      // Small delay to ensure map is fully initialized
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_loadingPOIs && _osmPOIs.isEmpty) {
          final currentZoom = _getCameraZoom();
          if (currentZoom >= 12.0) {
            Log.i('route_builder', '🗺️ Map ready, loading POIs...');
            _loadPOIs();
          }
        }
      });
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
      
      // Always refresh POIs on zoom changes (best practice: refresh on any zoom change)
      // Also refresh if camera moved significantly (>2km)
      final positionChanged = _lastPOICenter != null && 
          _calculateDistance(_lastPOICenter!, newCenter) > 2.0; // 2km threshold
      final zoomChanged = _lastPOIZoom != null && 
          (newZoom - _lastPOIZoom!).abs() > 0.01; // Reload on ANY zoom change (was 0.5)
      
      // Reload if camera moved significantly, zoom changed, or no POIs loaded yet
      final shouldReload = _lastPOICenter == null ||
          positionChanged ||
          zoomChanged ||
          _osmPOIs.isEmpty;
      
      if (shouldReload) {
        // DON'T clear POIs immediately - this causes markers to disappear and reappear
        // Instead, let the new POIs merge with existing ones through the annotation update
        // Only clear if zooming out below threshold
        if (zoomChanged && newZoom < 12.0 && _lastPOIZoom != null && _lastPOIZoom! >= 12.0) {
          // Only clear when zooming out below the POI threshold
          setState(() {
            _osmPOIs = [];
          });
          Log.i('route_builder', '📍 Zoomed out below POI threshold, clearing POIs');
        }
        
        // Debounce to avoid too many API calls
        _poiDebounce?.cancel();
        _poiDebounce = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            _loadPOIs();
          }
        });
      }
    },
    annotations: annotations,
    polylines: polylines,
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
      if (_previewGeometry != null && _coordsToLatLng(_previewGeometry!['coordinates']).isNotEmpty)
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
      if (_points.isNotEmpty)
        fm.MarkerLayer(
          markers: [
            for (int i = 0; i < _points.length; i++)
              fm.Marker(
                point: _points[i],
                width: i == 0 || i == _points.length - 1 ? 48 : 32,
                height: i == 0 || i == _points.length - 1 ? 48 : 32,
                child: GestureDetector(
                  onTap: () => _showRoutePointOptions(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFF52B788)
                          : (i == _points.length - 1 ? const Color(0xFFD62828) : const Color(0xFFFF9800)),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: i == 0 || i == _points.length - 1 ? 3.5 : 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: i == 0 || i == _points.length - 1 ? 0.35 : 0.25),
                          blurRadius: i == 0 || i == _points.length - 1 ? 8 : 5,
                          offset: Offset(0, i == 0 || i == _points.length - 1 ? 3 : 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: i == 0
                          ? const Text('A', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                          : i == _points.length - 1
                              ? const Text('B', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                              : const Icon(Icons.circle, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      // OSM POI markers (match Mapbox native style: colored background, white icon)
      if (_osmPOIs.isNotEmpty)
        fm.MarkerLayer(
          markers: _osmPOIs
              .map((poi) => fm.Marker(
                    point: poi.coordinates,
                    width: 22,
                    height: 22,
                    child: GestureDetector(
                      onTap: () => _showOSMPOIDetails(poi),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: poi.type.color, // FILL with POI category color
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white, // WHITE border
                            width: 2,
                          ),
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
                              poi.type.icon,
                              color: Colors.white, // WHITE icon for visibility
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
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

Future<void> _selectPlace(PlaceSuggestion place) async {
Log.i('route_builder', 'Place selected: ${place.text}');
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

  // Move camera to selected location
  _moveCamera(placeDetails.location, 14);
  
  // Show waypoint editor dialog with pre-filled location data
  if (mounted) {
    setState(() => _searching = false);
    await _showWaypointEditorFromPlace(placeDetails);
  }

// Trigger POI refresh after camera moves to new location
setState(() {
    _osmPOIs = [];
    _lastPOICenter = null;
    _lastPOIZoom = null;
  });

  // Load POIs after search
_poiDebounce?.cancel();
_poiDebounce = Timer(const Duration(milliseconds: 1000), () {
  if (mounted) {
    Log.i('route_builder', '📍 Loading POIs after location search...');
    _loadPOIs();
  }
});
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
if (_previewGeometry != null || _points.length >= 2) {
  // Get route points from preview geometry (preferred) or _points
  List<ll.LatLng> routePoints;
  if (_previewGeometry != null) {
    routePoints = _coordsToLatLng(_previewGeometry!['coordinates']);
  } else {
    routePoints = _points;
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

void _showOSMPOIDetails(POI poi) {
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
Log.i('route_builder', '_updatePreview called: ${_points.length} points');
if (_points.length < 2) {
setState(() {
_previewGeometry = null;
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
final profile = getMapboxProfile(widget.activityCategory);
Map<String, dynamic>? match;
try {
match = await _svc.matchRoute(points: _points, snapToTrail: _snapToTrail, profile: profile);
} catch (e) {
Log.w('route_builder', 'Cloud Function failed, using direct API');
}

if (match == null && _snapToTrail) {
match = await _directionsApiFallback(_points, profile);
}

if (match == null) {
match = {
'geometry': {'type': 'LineString', 'coordinates': _points.map((p) => [p.longitude, p.latitude]).toList()},
'distance': _calculateStraightDistance(_points),
'duration': (_calculateStraightDistance(_points) / 1.2).toInt(),
};
}

if (mounted && match != null) {
setState(() {
_previewGeometry = Map<String, dynamic>.from(match!['geometry'] as Map);
_previewDistance = (match['distance'] as num?)?.toDouble();
_previewDuration = (match['duration'] as num?)?.toInt();
});

try {
final coords = (_previewGeometry!['coordinates'] as List)
.map((e) => (e as List).map((n) => (n as num).toDouble()).toList())
.cast<List<double>>()
.toList();
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
if (mounted) setState(() => _busy = false);
}
}

Future<void> _buildAndSave() async {
// If we have route points but no preview yet, generate it
if (_points.length >= 2 && _previewGeometry == null) {
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
// CRITICAL: Always use preview geometry if it exists (it contains the snapped route)
// Only create fallback geometry if there's no preview at all
Map<String, dynamic> geometry;
if (_previewGeometry != null) {
geometry = _previewGeometry!;
} else if (_points.isNotEmpty) {
// Create geometry from route points if no preview exists
geometry = {
'type': 'LineString',
'coordinates': _points.map((p) => [p.longitude, p.latitude]).toList(),
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
distance: _previewDistance ?? 0,
duration: _previewDuration ?? 0,
routePoints: _points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
elevationProfile: _previewElevation.isNotEmpty ? _previewElevation : null,
ascent: _previewAscent,
descent: _previewDescent,
poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList(),
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
// Check if it's a route point - if so, add to _points, otherwise to _poiWaypoints
if (result.type == WaypointType.routePoint) {
setState(() {
_points.add(result.position);
_hintDismissed = true;
});
await _updatePreview();
} else {
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
// Fit map to show all waypoints after adding
_fitToWaypoints();
}
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
// Fit map to show all waypoints after adding
_fitToWaypoints();
}
}

/// Show waypoint editor dialog from a Google Places selection
Future<void> _showWaypointEditorFromPlace(PlaceDetails placeDetails) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

// Determine waypoint type from place types
WaypointType defaultType = WaypointType.attraction;
if (placeDetails.types.contains('restaurant') || 
    placeDetails.types.contains('food') ||
    placeDetails.types.contains('cafe')) {
  defaultType = WaypointType.restaurant;
} else if (placeDetails.types.contains('lodging') || 
           placeDetails.types.contains('hotel')) {
  defaultType = WaypointType.accommodation;
} else if (placeDetails.types.contains('tourist_attraction') ||
           placeDetails.types.contains('point_of_interest')) {
  defaultType = WaypointType.attraction;
}

// Create a temporary waypoint with place details to pre-fill the dialog
final tempWaypoint = RouteWaypoint(
  type: defaultType,
  position: placeDetails.location,
  name: placeDetails.name,
  address: placeDetails.address,
  googlePlaceId: placeDetails.placeId,
  website: placeDetails.website,
  phoneNumber: placeDetails.phoneNumber,
  rating: placeDetails.rating,
  order: _poiWaypoints.length,
);

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _WaypointEditorDialog(
existingWaypoint: tempWaypoint, // Pre-filled with place data
type: defaultType,
position: placeDetails.location,
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
    
    // Calculate travel time/distance from previous waypoint
    _calculateTravelTimes();
  });
  // Fit map to show all waypoints after adding
  _fitToWaypoints();
}
}

Future<void> _editWaypoint(RouteWaypoint waypoint) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _WaypointEditorDialog(
existingWaypoint: waypoint,
type: waypoint.type,
position: waypoint.position,
),
);

// Clear flag when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  // Re-enable map scroll zoom when dialog closes
  _mapboxController?.enableInteractions();
}

if (!mounted) return;

if (result == null) {
setState(() {
_poiWaypoints.removeWhere((w) => w.id == waypoint.id);
_initializeRouteOrdering(); // Reinitialize ordering after removing waypoint
});
} else {
setState(() {
final index = _poiWaypoints.indexWhere((w) => w.id == waypoint.id);
if (index >= 0) {
_poiWaypoints[index] = result;
}
});
}
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

Future<void> _showAddRoutePointDialog() async {
// Show the waypoint dialog with routePoint preselected
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);

final center = _getCameraCenter(); // Use helper method
// Set flag and disable map scroll zoom when dialog opens
setState(() => _dialogOrBottomSheetOpen = true);
_mapboxController?.disableInteractions();

final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
preselectedType: WaypointType.routePoint,
proximityBias: center,
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
_points.add(result.position);
_hintDismissed = true;
});
await _updatePreview();
}
}

Future<void> _showRoutePointOptions(int index) async {
// Set flag to prevent map taps while dialog is open
setState(() => _dialogOrBottomSheetOpen = true);
// Disable map scroll zoom when dialog opens
_mapboxController?.disableInteractions();

final action = await showDialog<String>(
context: context,
builder: (context) => Dialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Text(
'Route Point ${index + 1}',
style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
textAlign: TextAlign.center,
),
const SizedBox(height: 8),
Text(
'${_points[index].latitude.toStringAsFixed(4)}, ${_points[index].longitude.toStringAsFixed(4)}',
style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600),
textAlign: TextAlign.center,
),
const SizedBox(height: 24),
_ActionTile(
icon: Icons.delete,
color: Colors.red,
label: 'Delete Point',
onTap: () => Navigator.of(context).pop('delete'),
),
],
),
),
),
);

// Re-enable map scroll zoom when dialog closes
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
  _mapboxController?.enableInteractions();
}

// Clear flag when dialog closes (immediately, no delay)
if (mounted) {
  setState(() => _dialogOrBottomSheetOpen = false);
}

if (!mounted || action == null) {
  // Ensure flag is cleared even if action is null
  if (mounted) {
    setState(() => _dialogOrBottomSheetOpen = false);
  }
  return;
}

if (action == 'delete') {
setState(() {
_points.removeAt(index);
});
await _updatePreview();
}
}


/// Initialize ordering for route waypoints
void _initializeRouteOrdering() {
  _routeOrderManager = DayPlanOrderBuilder.buildFromWaypoints(1, _poiWaypoints);
}

/// Get waypoints by section ID
Map<String, List<RouteWaypoint>> _getRouteWaypointsBySectionId() {
  final map = <String, List<RouteWaypoint>>{};
  
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
      map.putIfAbsent(sectionId, () => []).add(wp);
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
  // Sort by current order first
  _poiWaypoints.sort((a, b) {
    final orderCompare = a.order.compareTo(b.order);
    if (orderCompare != 0) return orderCompare;
    // If same order, maintain stable sort (for choice groups)
    return a.id.compareTo(b.id);
  });
  
  // Assign sequential order numbers, keeping choice groups together
  int order = 1;
  String? lastChoiceGroupId;
  int? lastAssignedOrder;
  
  for (final wp in _poiWaypoints) {
    // If this waypoint is in a choice group
    if (wp.choiceGroupId != null) {
      // If this is a new choice group, increment order
      if (wp.choiceGroupId != lastChoiceGroupId) {
        order++;
        lastChoiceGroupId = wp.choiceGroupId;
        lastAssignedOrder = order;
      }
      // Assign the same order as other waypoints in this choice group
      final index = _poiWaypoints.indexWhere((w) => w.id == wp.id);
      if (index >= 0) {
        _poiWaypoints[index] = _poiWaypoints[index].copyWith(order: lastAssignedOrder!);
      }
    } else {
      // Individual waypoint - increment order if not already at this position
      if (lastAssignedOrder == null || wp.order != lastAssignedOrder) {
        order++;
      }
      final index = _poiWaypoints.indexWhere((w) => w.id == wp.id);
      if (index >= 0) {
        _poiWaypoints[index] = _poiWaypoints[index].copyWith(order: order);
      }
      lastAssignedOrder = order;
      lastChoiceGroupId = null;
    }
  }
}

/// Calculate travel times and distances between consecutive waypoints
/// Handles OR conditions by calculating distances from all previous waypoint options
Future<void> _calculateTravelTimes() async {
  if (_poiWaypoints.length < 2) return;

  final sortedWaypoints = List<RouteWaypoint>.from(_poiWaypoints)
    ..sort((a, b) => a.order.compareTo(b.order));

  final travelService = TravelCalculatorService();

  // Calculate travel for each waypoint from its previous waypoint(s)
  for (int i = 1; i < sortedWaypoints.length; i++) {
    final toWaypoint = sortedWaypoints[i];
    final currentOrder = toWaypoint.order;
    
    // Find all previous waypoints at the highest order before this one
    final previousWaypoints = sortedWaypoints
        .where((w) => w.order < currentOrder)
        .toList()
      ..sort((a, b) => b.order.compareTo(a.order));
    
    if (previousWaypoints.isEmpty) continue;
    
    // Get the most recent waypoint group (could be OR conditions)
    final maxOrder = previousWaypoints.first.order;
    final previousGroup = previousWaypoints
        .where((w) => w.order == maxOrder)
        .toList();
    
    // Calculate distance from each option in the previous group
    // For OR conditions, we need to calculate from all options
    // For now, calculate from the first one (user can change mode later)
    final fromWaypoint = previousGroup.first;
    
    // Use existing travel mode if set, otherwise let service choose
    final travelMode = toWaypoint.travelMode != null
        ? TravelMode.values.firstWhere(
            (tm) => tm.name == toWaypoint.travelMode,
            orElse: () => TravelMode.walking,
          )
        : null;
    
    final travelInfo = await travelService.calculateTravel(
      from: fromWaypoint.position,
      to: toWaypoint.position,
      travelMode: travelMode,
    );
    
    if (travelInfo != null && mounted) {
                        setState(() {
        final index = _poiWaypoints.indexWhere((w) => w.id == toWaypoint.id);
        if (index >= 0) {
          _poiWaypoints[index] = _poiWaypoints[index].copyWith(
            travelMode: travelMode?.name ?? travelInfo.travelMode.name,
            travelTime: travelInfo.durationSeconds,
            travelDistance: travelInfo.distanceMeters.toDouble(),
          );
        }
      });
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
  );
  
  if (travelInfo != null && mounted) {
    setState(() {
      final index = _poiWaypoints.indexWhere((w) => w.id == waypoint.id);
      if (index >= 0) {
        _poiWaypoints[index] = _poiWaypoints[index].copyWith(
          travelMode: newMode,
          travelTime: travelInfo.durationSeconds,
          travelDistance: travelInfo.distanceMeters.toDouble(),
        );
      }
    });
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

  // Add waypoint
  if (mounted) {
    setState(() {
      _poiWaypoints.add(waypointWithOrder);
      _renumberWaypoints(); // Ensure sequential ordering
    });
    
    // Fit map to show all waypoints after adding
    _fitToWaypoints();
    
    // Calculate travel times after adding waypoint
    _calculateTravelTimes();
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

Future<void> _showAddWaypointDialog() async {
// Show the waypoint dialog directly (using user's current map center as proximity bias)
// Exclude routePoint type since this is for POI waypoints only
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
bool get _shouldShowHint => !_hintDismissed && _points.isEmpty;
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
return Positioned(
top: isMobile ? kToolbarHeight + 12 : 12,
left: leftOffset,
width: barWidth,
child: Column(mainAxisSize: MainAxisSize.min, children: [
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
]),
);
}
}

class _BottomPanel extends StatelessWidget {
final List<RouteWaypoint> poiWaypoints;
final List<ll.LatLng> routePoints;
final double? previewDistance; final int? previewDuration;
final List<ElevationPoint> elevation; final double? ascent; final double? descent;
final bool busy;
final VoidCallback onAddWaypoint; final void Function(RouteWaypoint) onEditWaypoint;
final VoidCallback onAddRoutePoint; final void Function(int) onDeleteRoutePoint;
final void Function(int oldIndex, int newIndex) onReorderRoutePoints;
final VoidCallback? onPreview; final VoidCallback? onSave;
final void Function(int oldIndex, int newIndex) onReorder;
final DayPlanOrderManager? routeOrderManager;
final void Function(String) onMoveUp;
final void Function(String) onMoveDown;
final bool Function(String) canMoveUp;
final bool Function(String) canMoveDown;
final VoidCallback onInitializeOrdering;

const _BottomPanel({
required this.poiWaypoints,
required this.routePoints,
required this.previewDistance,
required this.previewDuration,
required this.elevation,
required this.ascent,
required this.descent,
required this.busy,
required this.onAddWaypoint,
required this.onEditWaypoint,
required this.onAddRoutePoint,
required this.onDeleteRoutePoint,
required this.onReorderRoutePoints,
required this.onPreview,
required this.onSave,
required this.onReorder,
required this.routeOrderManager,
required this.onMoveUp,
required this.onMoveDown,
required this.canMoveUp,
required this.canMoveDown,
required this.onInitializeOrdering,
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
// Route Points Section
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
child: Align(
alignment: Alignment.center,
child: ConstrainedBox(
constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
child: Row(children: [
Text('Route Points', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
child: Text('${routePoints.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
),
const Spacer(),
IconButton(
onPressed: onAddRoutePoint,
style: IconButton.styleFrom(backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1)),
icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
tooltip: 'Add route point',
),
]),
),
),
),
if (routePoints.isNotEmpty)
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16),
child: Column(children: [
for (int i = 0; i < routePoints.length; i++)
_RoutePointTile(
index: i,
point: routePoints[i],
isStart: i == 0,
isEnd: i == routePoints.length - 1,
onDelete: () => onDeleteRoutePoint(i),
onMoveUp: i == 0 ? null : () => onReorderRoutePoints(i, i - 1),
onMoveDown: i == routePoints.length - 1 ? null : () => onReorderRoutePoints(i, i + 2),
),
]),
),
const SizedBox(height: 16),
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
),
),
if (previewDistance != null || elevation.isNotEmpty) ...[
const SizedBox(height: 8),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
if (previewDistance != null)
Row(children: [
Icon(Icons.straighten, size: 18, color: context.colors.primary),
const SizedBox(width: 8),
Text('${(previewDistance! / 1000).toStringAsFixed(2)} km', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
const SizedBox(width: 20),
Icon(Icons.schedule, size: 18, color: context.colors.primary),
const SizedBox(width: 8),
Text(_formatDuration(previewDuration ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
]),
if (elevation.isNotEmpty) ...[
const SizedBox(height: 10),
SizedBox(height: 120, child: ElevationChart(data: elevation)),
const SizedBox(height: 6),
Row(children: [
if (ascent != null) ...[
Icon(Icons.trending_up, size: 16, color: Colors.green.shade700),
const SizedBox(width: 4),
Text('+${ascent!.toStringAsFixed(0)} m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
const SizedBox(width: 16),
],
if (descent != null) ...[
Icon(Icons.trending_down, size: 16, color: Colors.red.shade700),
const SizedBox(width: 4),
Text('-${descent!.toStringAsFixed(0)} m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
],
]),
],
]),
),
],
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
final bool snapToTrail; final ValueChanged<bool> onToggleSnap;
final List<RouteWaypoint> poiWaypoints;
final List<ll.LatLng> routePoints;
final double? previewDistance; final int? previewDuration;
final List<ElevationPoint> elevation; final double? ascent; final double? descent;
final bool busy;
final VoidCallback onAddWaypoint; final void Function(RouteWaypoint) onEditWaypoint;
final VoidCallback onAddRoutePoint; final void Function(int) onDeleteRoutePoint;
final void Function(int oldIndex, int newIndex) onReorderRoutePoints;
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

const _DesktopSidebar({
required this.snapToTrail,
required this.onToggleSnap,
required this.poiWaypoints,
required this.routePoints,
required this.previewDistance,
required this.previewDuration,
required this.elevation,
required this.ascent,
required this.descent,
required this.busy,
required this.onAddWaypoint,
required this.onEditWaypoint,
required this.onAddRoutePoint,
required this.onDeleteRoutePoint,
required this.onReorderRoutePoints,
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
Text('Build Route', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
const Spacer(),
Text('Snap', style: context.textStyles.labelSmall?.copyWith(color: Colors.grey.shade600)),
const SizedBox(width: 6),
Switch(value: snapToTrail, onChanged: onToggleSnap),
]),
),
Expanded(
child: ListView(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
children: [
// Stats section
if (previewDistance != null || ascent != null || previewDuration != null)
_StatsRow(
distanceMeters: previewDistance,
durationSeconds: previewDuration,
ascentMeters: ascent,
activityCategory: activityCategory,
),
if (elevation.isNotEmpty) ...[
const SizedBox(height: 12),
Container(
height: 80,
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
child: ElevationChart(data: elevation),
),
],
const SizedBox(height: 16),
// Route Points section
Container(
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
padding: const EdgeInsets.symmetric(vertical: 8),
child: Row(children: [
Text('Route Points', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
child: Text('${routePoints.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
),
const Spacer(),
IconButton(
onPressed: onAddRoutePoint,
style: IconButton.styleFrom(backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1)),
icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
tooltip: 'Add route point',
),
]),
),
if (routePoints.isEmpty) ...[
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
const Expanded(child: Text('Add points to define your route path')),
]),
),
] else ...[
const SizedBox(height: 8),
Column(children: [
for (int i = 0; i < routePoints.length; i++)
_RoutePointTile(
index: i,
point: routePoints[i],
isStart: i == 0,
isEnd: i == routePoints.length - 1,
onDelete: () => onDeleteRoutePoint(i),
onMoveUp: i == 0 ? null : () => onReorderRoutePoints(i, i - 1),
onMoveDown: i == routePoints.length - 1 ? null : () => onReorderRoutePoints(i, i + 2),
),
]),
],
const SizedBox(height: 16),
// Waypoints section
Container(
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
padding: const EdgeInsets.symmetric(vertical: 8),
child: Row(children: [
Text('POI Waypoints', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
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

class _StatsRow extends StatelessWidget {
final double? distanceMeters; final int? durationSeconds; final double? ascentMeters;
final ActivityCategory? activityCategory;
const _StatsRow({this.distanceMeters, this.durationSeconds, this.ascentMeters, this.activityCategory});
@override
Widget build(BuildContext context) {
String dist = distanceMeters == null ? '-' : '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
String dur = durationSeconds == null ? '-' : _fmtDuration(durationSeconds!);
String asc = ascentMeters == null ? '-' : '+${ascentMeters!.toStringAsFixed(0)} m';
TextStyle label = TextStyle(fontSize: 11, color: Colors.grey.shade600);
TextStyle value = const TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
return Row(children: [
_statTile(context, Icons.straighten, 'Length', dist, label, value),
_divider(),
_statTile(context, Icons.trending_up, 'Elev. gain', asc, label, value),
_divider(),
_statTile(context, Icons.schedule, 'Est. time', dur, label, value),
_divider(),
_statTile(context, Icons.directions_walk, 'Activity', _getActivityLabelStatic(activityCategory), label, value),
]);
}

Widget _divider() => Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.grey.shade200);
Widget _statTile(BuildContext context, IconData icon, String label, String value, TextStyle l, TextStyle v) => Expanded(
child: Row(children: [
Icon(icon, size: 16, color: context.colors.primary),
const SizedBox(width: 6),
Flexible(
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(label, style: l, overflow: TextOverflow.ellipsis),
Text(value, style: v, overflow: TextOverflow.ellipsis),
]),
),
]),
);
}

String _fmtDuration(int seconds) {
final h = seconds ~/ 3600;
final m = (seconds % 3600) ~/ 60;
if (h > 0) return '${h}h ${m}m';
return '${m}m';
}

/// Returns the appropriate activity label based on activity category (static helper)
String _getActivityLabelStatic(ActivityCategory? activityCategory) {
switch (activityCategory) {
case ActivityCategory.cycling:
return 'Cycling';
case ActivityCategory.roadTripping:
return 'Driving';
case ActivityCategory.skis:
return 'Skiing';
case ActivityCategory.climbing:
return 'Climbing';
case ActivityCategory.cityTrips:
return 'Walking';
case ActivityCategory.tours:
return 'Touring';
case ActivityCategory.hiking:
default:
return 'Hiking';
}
}

class _SidebarWaypointTile extends StatelessWidget {
final RouteWaypoint waypoint; final VoidCallback onEdit; final VoidCallback? onMoveUp; final VoidCallback? onMoveDown;
const _SidebarWaypointTile({super.key, required this.waypoint, required this.onEdit, this.onMoveUp, this.onMoveDown});
@override
Widget build(BuildContext context) => Container(
height: 56,
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
child: Row(children: [
Container(width: 28, height: 28, decoration: BoxDecoration(color: getWaypointColor(waypoint.type), borderRadius: BorderRadius.circular(8)),
child: Icon(getWaypointIcon(waypoint.type), color: Colors.white, size: 16)),
const SizedBox(width: 10),
Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(waypoint.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
Text(getWaypointLabel(waypoint.type), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
])),
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
if (value == 'edit') onEdit();
},
itemBuilder: (context) => [
const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
],
),
]),
);
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
  
  const _SidebarWaypointOrderedList({
    required this.waypoints,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canMoveUp,
    required this.canMoveDown,
    this.orderManager,
    required this.onInitializeOrdering,
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
    if (oldWidget.waypoints != widget.waypoints || oldWidget.orderManager != widget.orderManager) {
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
    
    _waypointsBySectionId = _getWaypointsBySectionId();
    _waypointsById = _getWaypointsById();
  }

  Map<String, List<RouteWaypoint>> _getWaypointsBySectionId() {
    final map = <String, List<RouteWaypoint>>{};
    for (final wp in widget.waypoints) {
      String? sectionId;
      switch (wp.type) {
        case WaypointType.restaurant:
          sectionId = 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
          break;
        case WaypointType.activity:
          sectionId = 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
          break;
        case WaypointType.accommodation:
          sectionId = 'accommodationSection';
          break;
        default:
          break;
      }
      if (sectionId != null) {
        map.putIfAbsent(sectionId, () => []).add(wp);
      }
    }
    return map;
  }

  Map<String, RouteWaypoint> _getWaypointsById() {
    return { for (final wp in widget.waypoints) wp.id: wp };
  }

  @override
  Widget build(BuildContext context) {
    final orderManager = widget.orderManager ?? _localOrderManager;
    if (orderManager == null) {
      widget.onInitializeOrdering();
      return const SizedBox.shrink();
    }

    final orderedItems = orderManager.sortedItems;
    final waypointsBySectionId = _waypointsBySectionId ?? _getWaypointsBySectionId();
    final waypointsById = _waypointsById ?? _getWaypointsById();

    return Column(
      children: orderedItems.map<Widget>((item) {
        if (item.isSection) {
          final sectionWaypoints = waypointsBySectionId[item.id] ?? [];
          return _SidebarCategoryGroup(
            key: ValueKey(item.id),
            category: _getCategoryFromSectionId(item.id),
            waypoints: sectionWaypoints,
            onEdit: widget.onEdit,
            itemId: item.id,
            canMoveUp: widget.canMoveUp(item.id),
            canMoveDown: widget.canMoveDown(item.id),
            onMoveUp: () => widget.onMoveUp(item.id),
            onMoveDown: () => widget.onMoveDown(item.id),
          );
        } else if (item.isIndividualWaypoint && item.waypointId != null) {
          final waypoint = waypointsById[item.waypointId!];
          if (waypoint == null) return const SizedBox.shrink();
          return _SidebarWaypointTile(
            key: ValueKey(item.id),
            waypoint: waypoint,
            onEdit: () => widget.onEdit(waypoint),
            onMoveUp: widget.canMoveUp(item.id) ? () => widget.onMoveUp(item.id) : null,
            onMoveDown: widget.canMoveDown(item.id) ? () => widget.onMoveDown(item.id) : null,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
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

const _AddWaypointDialog({
  this.preselectedType,
  this.proximityBias,
  this.excludeRoutePoint = false,
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
  final _urlController = TextEditingController();
  late WaypointType _selectedType;
  POIAccommodationType? _accommodationType;
  MealTime? _mealTime;
  ActivityTime? _activityTime;
  bool _geocoding = false;
  bool _extractingMetadata = false;
  ll.LatLng? _airbnbLocation;
  bool _airbnbAddressConfirmed = false;
  Map<String, dynamic>? _extractedMetadata; // Stores extracted URL metadata
  bool _hasSearchedOrExtracted = false; // Track if user has searched or extracted
  ll.LatLng? _extractedLocation; // Location from URL extraction
  Map<String, dynamic>? _extractedAddress; // Address from URL extraction
  List<Map<String, dynamic>> _mapboxSearchResults = []; // Mapbox geocoding results
  bool _mapboxSearching = false; // Mapbox search in progress
  final _addressSearchController = TextEditingController(); // Controller for manual address search
  final _latitudeController = TextEditingController(); // Controller for manual latitude input
  final _longitudeController = TextEditingController(); // Controller for manual longitude input
  final _priceMinController = TextEditingController(); // Controller for minimum price
  final _priceMaxController = TextEditingController(); // Controller for maximum price
  final _photoUrlController = TextEditingController(); // Controller for photo URL
  final _phoneController = TextEditingController(); // Controller for phone number
  Timer? _addressSearchDebounce; // Debounce for address search
  MapboxPlace? _selectedMapboxPlace; // Selected Mapbox search result
  String? _uploadedImageUrl; // URL of uploaded image from Firebase Storage
  bool _uploadingImage = false; // Track image upload status
  final StorageService _storageService = StorageService(); // Storage service for image uploads
  bool _showCoordinates = false; // Track whether to show manual coordinate input fields

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType ?? WaypointType.restaurant;
    
    // Auto-populate coordinates if proximityBias is provided (from map click)
    if (widget.proximityBias != null) {
      _latitudeController.text = widget.proximityBias!.latitude.toStringAsFixed(6);
      _longitudeController.text = widget.proximityBias!.longitude.toStringAsFixed(6);
      _showCoordinates = true; // Show coordinates section
      _hasSearchedOrExtracted = true; // Show waypoint details fields
    }
    
    // Add listeners to lat/lng controllers to clear selected place when manually entering coordinates
    _latitudeController.addListener(() {
      if (_latitudeController.text.isNotEmpty && _selectedMapboxPlace != null) {
        setState(() {
          _selectedMapboxPlace = null;
          _extractedLocation = null;
        });
      }
    });
    _longitudeController.addListener(() {
      if (_longitudeController.text.isNotEmpty && _selectedMapboxPlace != null) {
        setState(() {
          _selectedMapboxPlace = null;
          _extractedLocation = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _airbnbAddressController.dispose();
    _urlController.dispose();
    _addressSearchController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _photoUrlController.dispose();
    _phoneController.dispose();
    _addressSearchDebounce?.cancel();
    super.dispose();
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

Future<void> _extractUrlMetadata() async {
final url = _urlController.text.trim();
if (url.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter a URL'), backgroundColor: Colors.orange),
);
return;
}

setState(() => _extractingMetadata = true);

try {
Log.i('waypoint_dialog', 'Calling fetchMeta for URL: $url');
final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
final callable = functions.httpsCallable('fetchMeta');
final result = await callable.call<Map<String, dynamic>>({'url': url});
final data = result.data as Map<String, dynamic>?;

Log.i('waypoint_dialog', 'fetchMeta response received: $data');

if (data != null && mounted) {
// Store the metadata including the original URL
final metadataWithUrl = Map<String, dynamic>.from(data);
metadataWithUrl['url'] = url; // Store the original URL
  
// Extract values first
final title = data['title']?.toString() ?? '';
final description = data['description']?.toString() ?? '';
final image = data['image']?.toString() ?? '';
final siteName = data['siteName']?.toString() ?? '';

// Extract location data
final latitude = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
final longitude = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;
final address = data['address'] as Map<String, dynamic>?;

Log.i('waypoint_dialog', 'Extracted - title: "$title", description: "$description", image: "$image", siteName: "$siteName"');
if (latitude != null && longitude != null) {
  Log.i('waypoint_dialog', 'Extracted location: $latitude, $longitude');
}
if (address != null) {
  Log.i('waypoint_dialog', 'Extracted address: ${address['formatted'] ?? address}');
}

// Always set _hasSearchedOrExtracted to true and store metadata
setState(() {
_extractedMetadata = metadataWithUrl;
_extractedLocation = (latitude != null && longitude != null) ? ll.LatLng(latitude, longitude) : null;
_extractedAddress = address;
_hasSearchedOrExtracted = true;
});

// Update controllers AFTER setState to trigger rebuild
if (title.isNotEmpty) {
_nameController.text = title;
Log.i('waypoint_dialog', 'Name field updated with: $title');
}
if (description.isNotEmpty) {
_descController.text = description;
Log.i('waypoint_dialog', 'Description field updated with: $description');
}

if (title.isEmpty && description.isEmpty && image.isEmpty) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('⚠ No metadata found for this URL'),
backgroundColor: Colors.orange,
duration: Duration(seconds: 3),
),
);
}
} else {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('✓ Metadata extracted successfully'),
backgroundColor: Colors.green,
duration: Duration(seconds: 2),
),
);
}
}
} else {
Log.w('waypoint_dialog', 'fetchMeta returned null data');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('No metadata could be extracted'),
backgroundColor: Colors.orange,
duration: Duration(seconds: 3),
),
);
}
}
} catch (e) {
Log.e('waypoint_dialog', 'Failed to extract metadata', e);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Failed to extract metadata: $e'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
} finally {
if (mounted) setState(() => _extractingMetadata = false);
}
}

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

/// Perform Mapbox address search (unified method for all waypoint types)
Future<void> _performMapboxSearch(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty || trimmedQuery.length < 3) {
    if (mounted) {
      setState(() {
        _mapboxSearchResults = [];
        _mapboxSearching = false;
      });
    }
    return;
  }

  if (mounted) setState(() => _mapboxSearching = true);

  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('geocodeAddressMapbox');
    final result = await callable.call<Map<String, dynamic>>({
      'query': trimmedQuery,
      'proximity': widget.proximityBias != null
          ? {'lng': widget.proximityBias!.longitude, 'lat': widget.proximityBias!.latitude}
          : null,
    });

    final data = result.data as Map<String, dynamic>?;
    if (mounted) {
      if (data != null && data['results'] != null && (data['results'] as List).isNotEmpty) {
        setState(() {
          _mapboxSearchResults = (data['results'] as List).cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _mapboxSearchResults = []);
      }
    }
  } catch (e) {
    Log.e('waypoint_dialog', 'Failed to search Mapbox', e);
    if (mounted) {
      setState(() => _mapboxSearchResults = []);
    }
  } finally {
    if (mounted) setState(() => _mapboxSearching = false);
  }
}

/// Handle selection of a Mapbox search result
void _selectMapboxResult(Map<String, dynamic> result) {
  final lat = result['latitude'] as num?;
  final lng = result['longitude'] as num?;
  final name = result['name'] as String? ?? '';
  final formattedAddress = result['formattedAddress'] as String? ?? '';

  if (lat != null && lng != null) {
    final place = MapboxPlace(
      name: name,
      formattedAddress: formattedAddress,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
    
    setState(() {
      _selectedMapboxPlace = place;
      _extractedLocation = place.location;
      _extractedAddress = {'formatted': formattedAddress};
      _mapboxSearchResults = [];
      _addressSearchController.text = formattedAddress; // Keep the address in the search field
      _hasSearchedOrExtracted = true;
      
      // Populate lat/lng fields
      _latitudeController.text = place.latitude.toStringAsFixed(6);
      _longitudeController.text = place.longitude.toStringAsFixed(6);
      
      // Auto-fill name if empty
      if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
        _nameController.text = name;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location selected! ✓'), backgroundColor: Colors.green),
      );
    }
  }
}

@override
Widget build(BuildContext context) {
  return ScrollBlockingDialog(
    child: MouseRegion(
      // Force standard cursor (arrow) to override Mapbox's grabbing hand cursor
      // This ensures form fields and buttons show the correct cursor
      cursor: SystemMouseCursors.basic,
      child: Listener(
        // CRITICAL: Only intercept scroll events to prevent map zoom
        // Do NOT block pointer down/up events - they need to reach child widgets (like the X button)
        // The ScrollBlockingDialog barrier and CSS pointer-events handle blocking background clicks
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Event is consumed by this handler, preventing it from reaching the map
          }
        },
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
        mainAxisSize: MainAxisSize.min,
        children: [
// Modern header
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
'Add Waypoint',
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
GestureDetector(
  behavior: HitTestBehavior.opaque, // Ensure button receives all events
  onTap: () {
    debugPrint('🔴 [RouteBuilder] Add Waypoint X button tapped - closing dialog');
    Navigator.pop(context);
  },
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        debugPrint('🔴 [RouteBuilder] Add Waypoint InkWell tapped - closing dialog');
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
),
],
),
),

Expanded(
child: ScrollBlockingScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// Google Maps search section removed - using Mapbox search and URL extraction instead
// URL/Link metadata extraction section - always show, even after extraction
const SizedBox(height: 20),
Row(
  children: [
    Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text('Add URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
    if (_extractedMetadata != null) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text('Metadata extracted', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
      ),
    ],
  ],
),
const SizedBox(height: 12),
Container(
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
controller: _urlController,
decoration: InputDecoration(
hintText: 'Paste URL or link...',
hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
prefixIcon: Container(
padding: const EdgeInsets.all(12),
child: Icon(Icons.link_rounded, color: Colors.grey.shade400, size: 22),
),
suffixIcon: _urlController.text.isNotEmpty
? IconButton(
icon: const Icon(Icons.clear_rounded, size: 20),
color: Colors.grey.shade400,
onPressed: () {
_urlController.clear();
setState(() => _extractedMetadata = null);
},
)
: null,
border: InputBorder.none,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
),
onChanged: (value) => setState(() {}),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: ElevatedButton.icon(
onPressed: _extractingMetadata || _urlController.text.isEmpty ? null : _extractUrlMetadata,
icon: _extractingMetadata
? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
: const Icon(Icons.auto_awesome, size: 20),
label: Text(_extractingMetadata ? 'Extracting...' : 'Extract Metadata'),
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF428A13),
disabledBackgroundColor: Colors.grey.shade200,
foregroundColor: Colors.white,
disabledForegroundColor: Colors.grey.shade400,
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),
if (_extractedMetadata != null) ...[
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: const Color(0xFFE8F5E9),
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.green.shade200),
),
child: Row(
children: [
Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (_extractedMetadata!['title'] != null && _extractedMetadata!['title'].toString().isNotEmpty)
Text(
_extractedMetadata!['title'],
style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
if (_extractedMetadata!['siteName'] != null && _extractedMetadata!['siteName'].toString().isNotEmpty)
Text(
_extractedMetadata!['siteName'],
style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
),
],
),
),
IconButton(
icon: const Icon(Icons.close, size: 18),
onPressed: () {
_urlController.clear();
_nameController.clear();
_descController.clear();
setState(() {
  _extractedMetadata = null;
  // Only reset if no place is selected either
  if (_selectedMapboxPlace == null) {
    _hasSearchedOrExtracted = false;
  }
});
},
),
],
),
),
],
// Location section - only show after URL extraction
if (_extractedMetadata != null) ...[
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
  if (_extractedLocation != null && _selectedMapboxPlace == null) ...[
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
                        _mapboxSearchResults = [];
                      });
                    },
                  )
                : (_mapboxSearching
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
              if (mounted) _performMapboxSearch(value);
            });
            setState(() {}); // Update UI to show/hide clear button
          },
        ),
      ),
    ),
  ],
),
if (_mapboxSearchResults.isNotEmpty)
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
      itemCount: _mapboxSearchResults.length,
      itemBuilder: (context, index) {
        final result = _mapboxSearchResults[index];
        final name = result['name'] as String? ?? '';
        final formattedAddress = result['formattedAddress'] as String? ?? '';
        return ListTile(
          leading: Icon(Icons.location_on_rounded, color: Colors.blue.shade600, size: 20),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(formattedAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          onTap: () => _selectMapboxResult(result),
        );
      },
    ),
  ),
if (_selectedMapboxPlace != null)
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
                Text(_selectedMapboxPlace!.formattedAddress, style: TextStyle(fontSize: 12, color: Colors.green.shade700.withOpacity(0.8))),
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
],
// Manual latitude/longitude input fields - collapsible section
if (_extractedMetadata != null || widget.proximityBias != null) ...[
  const SizedBox(height: 12),
  InkWell(
    onTap: () {
      setState(() {
        _showCoordinates = !_showCoordinates;
      });
    },
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _showCoordinates ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            'Advanced: Manual Coordinates',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    ),
  ),
  if (_showCoordinates) ...[
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _ModernTextField(
            label: 'Latitude',
            isRequired: false,
            controller: _latitudeController,
            hintText: 'e.g., 68.3496',
            prefixIcon: Icons.north_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModernTextField(
            label: 'Longitude',
            isRequired: false,
            controller: _longitudeController,
            hintText: 'e.g., 18.8300',
            prefixIcon: Icons.east_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    ),
    if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Manual coordinates will override search results',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
  ],
],
const SizedBox(height: 20),
Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.3)),
const SizedBox(height: 12),
Wrap(
spacing: 10,
runSpacing: 10,
children: WaypointType.values
.where((type) => !widget.excludeRoutePoint || type != WaypointType.routePoint)
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
Row(
  children: [
    Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text('Photo URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
  ],
),
const SizedBox(height: 12),
_ModernTextField(
  label: 'Photo URL',
  isRequired: false,
  controller: _photoUrlController,
  hintText: 'https://example.com/image.jpg',
  prefixIcon: Icons.image_rounded,
),
// Phone Number
const SizedBox(height: 16),
Row(
  children: [
    Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
  ],
),
const SizedBox(height: 12),
_ModernTextField(
  label: 'Phone Number',
  isRequired: false,
  controller: _phoneController,
  hintText: '+1 234 567 8900',
  prefixIcon: Icons.phone_rounded,
  keyboardType: TextInputType.phone,
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
// Show extracted image if available
if (_extractedMetadata != null && _extractedMetadata!['image'] != null && _extractedMetadata!['image'].toString().isNotEmpty) ...[
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
_extractedMetadata!['image'],
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
// Show address, latitude, and longitude below image if metadata is extracted
if (_extractedMetadata != null) ...[
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
if (_extractedLocation != null) ...[
Row(
children: [
Expanded(
child: Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(
children: [
Icon(Icons.north_rounded, size: 18, color: Colors.grey.shade500),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Latitude', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
const SizedBox(height: 2),
Text(
_extractedLocation!.latitude.toStringAsFixed(6),
style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
),
],
),
),
],
),
),
),
const SizedBox(width: 12),
Expanded(
child: Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(
children: [
Icon(Icons.east_rounded, size: 18, color: Colors.grey.shade500),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Longitude', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
const SizedBox(height: 2),
Text(
_extractedLocation!.longitude.toStringAsFixed(6),
style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
),
],
),
),
],
),
),
),
],
),
],
],
],
// Show URL if available from extraction
if (_extractedMetadata != null && _extractedMetadata!['url'] != null && _extractedMetadata!['url'].toString().isNotEmpty) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
_extractedMetadata!['url'],
style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
],
),
),
],
],
),
),
),
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
border: Border(top: BorderSide(color: Colors.grey.shade100)),
),
child: Row(
  children: [
    if (_selectedMapboxPlace != null)
      Expanded(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF428A13)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                  Text('Ready to add', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      )
    else if (_extractedLocation != null || (_extractedMetadata != null && widget.proximityBias != null))
Expanded(
child: Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: const Color(0xFFE8F5E9),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF428A13)),
),
const SizedBox(width: 10),
const Flexible(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('URL metadata extracted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
Text('Ready to add', style: TextStyle(fontSize: 11, color: Colors.grey)),
],
),
),
],
),
)
else if (_accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed)
Expanded(
child: Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: const Color(0xFFE8F5E9),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF428A13)),
),
const SizedBox(width: 10),
const Flexible(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Location set', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
],
),
),
],
),
)
else if (_selectedType == WaypointType.routePoint)
Expanded(
child: Row(
children: [
Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
const SizedBox(width: 8),
Flexible(
child: Text('Location set from map', style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
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
child: Text('Search or set location first', style: TextStyle(fontSize: 13, color: Colors.orange.shade600)),
),
],
),
),
const SizedBox(width: 16),
TextButton(
onPressed: () => Navigator.of(context).pop(),
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
child: Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
),
const SizedBox(width: 10),
ElevatedButton(
onPressed: _canSave() ? _save : null,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF428A13),
disabledBackgroundColor: Colors.grey.shade200,
padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
elevation: 0,
shadowColor: Colors.transparent,
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.add_rounded, size: 18, color: _canSave() ? Colors.white : Colors.grey.shade400),
const SizedBox(width: 6),
Text('Add Waypoint', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _canSave() ? Colors.white : Colors.grey.shade400)),
],
),
),
],
),
),
        ],
          ),
        ),
      ),
    ),
  );
}

bool _canSave() {
if (_nameController.text.trim().isEmpty) return false;

// Route points don't need Google Place selection - just name and location from proximity bias
if (_selectedType == WaypointType.routePoint) {
return widget.proximityBias != null; // Must have a location set
}

if (_selectedType == WaypointType.accommodation && _accommodationType == null) return false;
if (_accommodationType == POIAccommodationType.airbnb && !_airbnbAddressConfirmed) return false;

// Check for manual latitude/longitude input
final latText = _latitudeController.text.trim();
final lngText = _longitudeController.text.trim();
bool hasManualCoordinates = false;
if (latText.isNotEmpty && lngText.isNotEmpty) {
  try {
    final lat = double.parse(latText);
    final lng = double.parse(lngText);
    if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      hasManualCoordinates = true;
    }
  } catch (_) {
    // Invalid coordinates
  }
}

// Allow saving if:
// 1. Manual coordinates entered (highest priority)
// 2. Mapbox place is selected (has location)
// 3. Location extracted from URL metadata (with coordinates)
// 4. Metadata is extracted AND we have a proximity bias (map location)
// 5. Airbnb with confirmed address
// 6. Address extracted from URL (even without coordinates, if user selects a place)
final hasMapboxPlace = _selectedMapboxPlace != null;
final hasExtractedLocation = _extractedLocation != null;
final hasMetadataWithLocation = _extractedMetadata != null && widget.proximityBias != null;
final hasAirbnbLocation = _accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed;
// If metadata was extracted but no address found, require location selection
final hasExtractedAddress = _extractedAddress != null && _extractedAddress!['formatted'] != null;

// If metadata was extracted but no address was found, location is mandatory
if (_extractedMetadata != null && !hasExtractedAddress && !hasManualCoordinates && !hasMapboxPlace && !hasExtractedLocation && !hasMetadataWithLocation && !hasAirbnbLocation) {
  return false;
}

// For other cases, check if we have any location
if (!hasManualCoordinates && !hasMapboxPlace && !hasExtractedLocation && !hasMetadataWithLocation && !hasAirbnbLocation) return false;

return true;
}

void _save() async {
  if (!_canSave()) return;

  String? photoUrl;
  // Priority: 1. Uploaded image, 2. Photo URL field, 3. Extracted metadata image
  if (_uploadedImageUrl != null) {
    photoUrl = _uploadedImageUrl;
  } else if (_photoUrlController.text.trim().isNotEmpty) {
    photoUrl = _photoUrlController.text.trim();
  } else if (_extractedMetadata != null && _extractedMetadata!['image'] != null) {
    photoUrl = _extractedMetadata!['image'] as String?;
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
  // 1. Manual latitude/longitude input (highest priority - user override)
  // 2. Selected Mapbox place (from search)
  // 3. Extracted location from URL metadata
  // 4. Airbnb geocoded location
  // 5. Route point proximity bias
  // 6. Proximity bias (map tap location) as fallback
  
  // Check for manual coordinates first
  final latText = _latitudeController.text.trim();
  final lngText = _longitudeController.text.trim();
  if (latText.isNotEmpty && lngText.isNotEmpty) {
    try {
      final lat = double.parse(latText);
      final lng = double.parse(lngText);
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        position = ll.LatLng(lat, lng);
        address = _addressSearchController.text.trim().isEmpty ? null : _addressSearchController.text.trim();
      } else {
        throw 'Coordinates out of range';
      }
    } catch (e) {
      // Invalid coordinates, fall through to other options
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid coordinates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
  } else if (_selectedMapboxPlace != null) {
    position = _selectedMapboxPlace!.location;
    address = _selectedMapboxPlace!.formattedAddress;
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
  } else if (widget.proximityBias != null) {
    // Use proximity bias (map tap location) for extracted metadata waypoints
    position = widget.proximityBias!;
    address = _extractedAddress?['formatted'] as String?;
  } else {
    return;
  }

  final waypoint = RouteWaypoint(
    type: _selectedType,
    position: position,
    name: _nameController.text.trim(),
    description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    order: 0,
    googlePlaceId: null, // No longer using Google Places
    address: address,
    rating: null, // No longer using Google Places rating
    website: null, // No longer using Google Places website
    phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    photoUrl: photoUrl,
    accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
    mealTime: _selectedType == WaypointType.restaurant ? _mealTime : null,
    activityTime: _selectedType == WaypointType.activity ? _activityTime : null,
    linkUrl: _extractedMetadata != null ? _urlController.text.trim() : null,
    linkImageUrl: _extractedMetadata != null ? (_extractedMetadata!['image'] as String?) : null,
    estimatedPriceRange: priceRange,
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

/// Enhanced waypoint editor dialog
class _WaypointEditorDialog extends StatefulWidget {
final RouteWaypoint? existingWaypoint;
final WaypointType type;
final ll.LatLng position;

const _WaypointEditorDialog({
this.existingWaypoint,
required this.type,
required this.position,
});

@override
State<_WaypointEditorDialog> createState() => _WaypointEditorDialogState();
}

class _WaypointEditorDialogState extends State<_WaypointEditorDialog> {
late WaypointType _selectedType;
late final TextEditingController _nameController;
late final TextEditingController _descriptionController;
late final TextEditingController _photoUrlController;
late final TextEditingController _websiteController;
late final TextEditingController _phoneController;
late final TextEditingController _addressController;
late final TextEditingController _hotelChainController;
late final TextEditingController _bookingUrlController;
late final TextEditingController _airbnbUrlController;
late final TextEditingController _priceMinController;
late final TextEditingController _priceMaxController;

POIAccommodationType? _accommodationType;
MealTime? _mealTime;
ActivityTime? _activityTime;

@override
void initState() {
super.initState();
final wp = widget.existingWaypoint;
_selectedType = wp?.type ?? widget.type;
_accommodationType = wp?.accommodationType;
_mealTime = wp?.mealTime;
_activityTime = wp?.activityTime;
_nameController = TextEditingController(text: wp?.name ?? '');
_descriptionController = TextEditingController(text: wp?.description ?? '');
_photoUrlController = TextEditingController(text: wp?.photoUrl ?? '');
_websiteController = TextEditingController(text: wp?.website ?? '');
_phoneController = TextEditingController(text: wp?.phoneNumber ?? '');
_addressController = TextEditingController(text: wp?.address ?? '');
_hotelChainController = TextEditingController(text: wp?.hotelChain ?? '');
_bookingUrlController = TextEditingController(text: wp?.bookingComUrl ?? '');
_airbnbUrlController = TextEditingController(text: wp?.airbnbPropertyUrl ?? '');
_priceMinController = TextEditingController(text: wp?.estimatedPriceRange?.min.toString() ?? '');
_priceMaxController = TextEditingController(text: wp?.estimatedPriceRange?.max.toString() ?? '');
}

@override
void dispose() {
_nameController.dispose();
_descriptionController.dispose();
_photoUrlController.dispose();
_websiteController.dispose();
_phoneController.dispose();
_addressController.dispose();
_hotelChainController.dispose();
_bookingUrlController.dispose();
_airbnbUrlController.dispose();
_priceMinController.dispose();
_priceMaxController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
  return ScrollBlockingDialog(
    child: MouseRegion(
      // Force standard cursor (arrow) to override Mapbox's grabbing hand cursor
      cursor: SystemMouseCursors.basic,
      child: Listener(
        // CRITICAL: Only intercept scroll events to prevent map zoom
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Event is consumed by this handler, preventing it from reaching the map
          }
        },
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern header
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
                      child: Icon(getWaypointIcon(_selectedType), color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingWaypoint == null ? 'Add Waypoint' : 'Edit Waypoint',
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque, // Ensure button receives all events
                      onTap: () {
                        debugPrint('🔴 [RouteBuilder] Edit Waypoint X button tapped - closing dialog');
                        Navigator.of(context).pop();
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            debugPrint('🔴 [RouteBuilder] Edit Waypoint InkWell tapped - closing dialog');
                            Navigator.of(context).pop();
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
                    ),
                  ],
                ),
              ),
Expanded(
child: ScrollBlockingScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_buildCommonFields(),
const SizedBox(height: 16),
if (_selectedType != WaypointType.accommodation) _buildPoiFields(),
if (_selectedType == WaypointType.accommodation) _buildAccommodationFields(),
],
),
),
),
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
border: Border(top: BorderSide(color: Colors.grey.shade100)),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
if (widget.existingWaypoint != null)
TextButton(
onPressed: () => Navigator.of(context).pop(),
style: TextButton.styleFrom(foregroundColor: Colors.red),
child: const Text('Delete'),
)
else
const SizedBox.shrink(),
Row(
children: [
TextButton(
onPressed: () => Navigator.of(context).pop(widget.existingWaypoint),
child: const Text('Cancel'),
),
const SizedBox(width: 8),
FilledButton(
onPressed: _saveWaypoint,
child: const Text('Save'),
),
],
),
],
),
),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildCommonFields() => Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
DropdownButtonFormField<WaypointType>(
value: _selectedType,
decoration: InputDecoration(
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
items: WaypointType.values
.map((type) => DropdownMenuItem(
value: type,
child: Row(
children: [
Icon(getWaypointIcon(type), color: getWaypointColor(type), size: 20),
const SizedBox(width: 8),
Text(getWaypointLabel(type)),
],
),
))
.toList(),
onChanged: (value) {
if (value != null) setState(() => _selectedType = value);
},
),
if (_selectedType == WaypointType.accommodation) ...[
const SizedBox(height: 16),
const Text('Accommodation Type *', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: ChoiceChip(
label: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.hotel, size: 16),
SizedBox(width: 4),
Text('Hotel'),
],
),
selected: _accommodationType == POIAccommodationType.hotel,
onSelected: (selected) {
if (selected) setState(() => _accommodationType = POIAccommodationType.hotel);
},
),
),
const SizedBox(width: 8),
Expanded(
child: ChoiceChip(
label: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.home, size: 16),
SizedBox(width: 4),
Text('Airbnb'),
],
),
selected: _accommodationType == POIAccommodationType.airbnb,
onSelected: (selected) {
if (selected) setState(() => _accommodationType = POIAccommodationType.airbnb);
},
),
),
],
),
],
if (_selectedType == WaypointType.restaurant) ...[
const SizedBox(height: 16),
const Text('Meal Time', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: MealTime.values.map((time) => ChoiceChip(
label: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getMealTimeIcon(time), size: 16),
const SizedBox(width: 4),
Text(getMealTimeLabel(time)),
],
),
selected: _mealTime == time,
onSelected: (selected) {
setState(() => _mealTime = selected ? time : null);
},
)).toList(),
),
],
if (_selectedType == WaypointType.activity) ...[
const SizedBox(height: 16),
const Text('Activity Time', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: ActivityTime.values.map((time) => ChoiceChip(
label: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getActivityTimeIcon(time), size: 16),
const SizedBox(width: 4),
Text(getActivityTimeLabel(time)),
],
),
selected: _activityTime == time,
onSelected: (selected) {
setState(() => _activityTime = selected ? time : null);
},
)).toList(),
),
],
const SizedBox(height: 16),
const Text('Name *', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _nameController,
decoration: InputDecoration(
hintText: 'e.g., Mountain View Café',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
const SizedBox(height: 16),
const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _descriptionController,
maxLines: 3,
decoration: InputDecoration(
hintText: 'Add details...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
// Price estimation for restaurant, accommodation, activity, and servicePoint (exclude viewingPoint)
if (_selectedType == WaypointType.restaurant ||
    _selectedType == WaypointType.accommodation ||
    _selectedType == WaypointType.activity ||
    _selectedType == WaypointType.servicePoint) ...[
const SizedBox(height: 16),
Text(
_selectedType == WaypointType.accommodation
    ? 'Estimated Price Range (per night)'
    : 'Estimated Price Range (optional)',
style: const TextStyle(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: TextField(
controller: _priceMinController,
keyboardType: TextInputType.number,
decoration: InputDecoration(
labelText: 'Min €',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
),
const SizedBox(width: 12),
Expanded(
child: TextField(
controller: _priceMaxController,
keyboardType: TextInputType.number,
decoration: InputDecoration(
labelText: 'Max €',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
),
],
),
],
const SizedBox(height: 16),
const Text('Photo URL', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _photoUrlController,
decoration: InputDecoration(
hintText: 'https://example.com/image.jpg',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
],
);

Widget _buildPoiFields() => Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Divider(),
const SizedBox(height: 16),
const Text('POI Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
const SizedBox(height: 16),
const Text('Address', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _addressController,
decoration: InputDecoration(
hintText: 'Enter address',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
const SizedBox(height: 16),
const Text('Website', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _websiteController,
decoration: InputDecoration(
hintText: 'https://example.com',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
const SizedBox(height: 16),
const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _phoneController,
decoration: InputDecoration(
hintText: '+1 234 567 8900',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
],
);

Widget _buildAccommodationFields() => Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Divider(),
const SizedBox(height: 16),
const Text('Accommodation Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
const SizedBox(height: 16),
if (_accommodationType == POIAccommodationType.hotel) ...[
const Text('Hotel Chain', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _hotelChainController,
decoration: InputDecoration(
hintText: 'e.g., Marriott, Hilton',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
const SizedBox(height: 16),
],
const Text('Address', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _addressController,
decoration: InputDecoration(
hintText: 'Enter address',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
if (_accommodationType == POIAccommodationType.hotel) ...[
const Text('Booking.com URL', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _bookingUrlController,
decoration: InputDecoration(
hintText: 'https://booking.com/...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
],
if (_accommodationType == POIAccommodationType.airbnb) ...[
const Text('Airbnb Property URL *', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _airbnbUrlController,
decoration: InputDecoration(
hintText: 'https://airbnb.com/rooms/...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
),
),
],
],
);

void _saveWaypoint() {
if (_nameController.text.trim().isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter a name')),
);
return;
}

if (_selectedType == WaypointType.accommodation && _accommodationType == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please select accommodation type')),
);
return;
}

if (_accommodationType == POIAccommodationType.airbnb && _airbnbUrlController.text.trim().isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter Airbnb URL')),
);
return;
}

// Basic URL validation
final bookingUrl = _bookingUrlController.text.trim();
final airbnbUrl = _airbnbUrlController.text.trim();
final websiteUrl = _websiteController.text.trim();

if (bookingUrl.isNotEmpty && !bookingUrl.startsWith('http')) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Booking URL must start with http:// or https://')),
);
return;
}

if (airbnbUrl.isNotEmpty && !airbnbUrl.startsWith('http')) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Airbnb URL must start with http:// or https://')),
);
return;
}

if (websiteUrl.isNotEmpty && !websiteUrl.startsWith('http')) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Website URL must start with http:// or https://')),
);
return;
}

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

final waypoint = RouteWaypoint(
id: widget.existingWaypoint?.id,
type: _selectedType,
position: widget.position,
name: _nameController.text.trim(),
description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
order: widget.existingWaypoint?.order ?? 0,
photoUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
rating: null, // No longer using rating
website: websiteUrl.isEmpty ? null : websiteUrl,
phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
hotelChain: _hotelChainController.text.trim().isEmpty ? null : _hotelChainController.text.trim(),
amenities: null, // No longer using amenities
estimatedPriceRange: priceRange,
bookingComUrl: bookingUrl.isEmpty ? null : bookingUrl,
airbnbPropertyUrl: airbnbUrl.isEmpty ? null : airbnbUrl,
mealTime: _selectedType == WaypointType.restaurant ? _mealTime : null,
activityTime: _selectedType == WaypointType.activity ? _activityTime : null,
);
Navigator.of(context).pop(waypoint);
}
}

