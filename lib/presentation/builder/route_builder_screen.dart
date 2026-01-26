import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

/// Full-page route builder screen
class RouteBuilderScreen extends StatefulWidget {
final String planId;
final String versionIndex;
final String dayNum;
final ll.LatLng? start;
final ll.LatLng? end;
final DayRoute? initial;
final ActivityCategory? activityCategory;

const RouteBuilderScreen({
super.key,
required this.planId,
required this.versionIndex,
required this.dayNum,
this.start,
this.end,
this.initial,
this.activityCategory,
});

@override
State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
final fm.MapController _map = fm.MapController();
final _svc = MapboxService();
final _searchController = TextEditingController();
final _searchFocusNode = FocusNode();
Timer? _searchDebounce;
bool _snapToTrail = true;
bool _busy = false;
bool _searching = false;
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
bool _addingWaypointViaMap = false; // True when waiting for user to tap map to add waypoint

// OSM POIs
List<POI> _osmPOIs = [];
bool _loadingPOIs = false;

@override
void initState() {
super.initState();
Log.i('route_builder', 'RouteBuilderScreen init');
WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) {
_loadPOIs();
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
_poiWaypoints.addAll(
widget.initial!.poiWaypoints.map((w) {
final waypoint = RouteWaypoint.fromJson(w);
// Auto-assign time slot category if not set
if (waypoint.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(waypoint);
return waypoint.copyWith(timeSlotCategory: autoCategory);
}
return waypoint;
}).toList(),
);
}
}
} catch (e, stack) {
Log.e('route_builder', 'init failed', e, stack);
}
}

@override
void dispose() {
_searchDebounce?.cancel();
_searchController.dispose();
_searchFocusNode.dispose();
super.dispose();
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
// Use first waypoint position if available, otherwise first route point, otherwise default
// Default to Norway coordinates if no points exist
final center = _poiWaypoints.isNotEmpty
? _poiWaypoints.first.position
: (_points.isNotEmpty ? _points.first : const ll.LatLng(61.0, 8.5));
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
),
),
Expanded(
child: Stack(children: [
Positioned.fill(
child: fm.FlutterMap(
mapController: _map,
options: fm.MapOptions(
initialCenter: center,
initialZoom: 11,
onTap: (tapPos, latLng) async {
if (_searchResults.isNotEmpty) {
setState(() => _searchResults = []);
return;
}
Log.i('route_builder', 'Map tapped: ${latLng.latitude},${latLng.longitude}');
await _showMapTapActionPicker(context, latLng);
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
// OSM POI markers (subtle, background)
if (_osmPOIs.isNotEmpty)
fm.MarkerLayer(
markers: _osmPOIs
.map((poi) => fm.Marker(
point: poi.coordinates,
width: 24,
height: 24,
child: GestureDetector(
onTap: () => _showOSMPOIDetails(poi),
child: Container(
width: 24,
height: 24,
decoration: BoxDecoration(
color: poi.type.color.withValues(alpha: 0.7),
shape: BoxShape.circle,
border: Border.all(
color: Colors.white.withValues(alpha: 0.8),
width: 1.5,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.15),
blurRadius: 2,
offset: const Offset(0, 1),
),
],
),
child: Icon(
poi.type.icon,
color: Colors.white,
size: 14,
),
),
),
))
.toList(),
),
// Custom POI waypoints (bold, prominent)
if (_poiWaypoints.isNotEmpty)
fm.MarkerLayer(
markers: _poiWaypoints
.map((wp) => fm.Marker(
point: wp.position,
width: 36,
height: 36,
child: GestureDetector(
onTap: () => _editWaypoint(wp),
child: Container(
decoration: BoxDecoration(
color: Colors.white,
shape: BoxShape.circle,
border: Border.all(color: getWaypointColor(wp.type), width: 3.5),
boxShadow: [
BoxShadow(
color: getWaypointColor(wp.type).withValues(alpha: 0.3),
blurRadius: 8,
spreadRadius: 2,
),
BoxShadow(
color: Colors.black.withValues(alpha: 0.2),
blurRadius: 4,
offset: const Offset(0, 2),
),
],
),
child: Center(child: Icon(getWaypointIcon(wp.type), color: getWaypointColor(wp.type), size: 18)),
),
),
))
.toList(),
),
],
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
onZoomIn: () => _map.move(_map.camera.center, _map.camera.zoom + 1),
onZoomOut: () => _map.move(_map.camera.center, _map.camera.zoom - 1),
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
child: fm.FlutterMap(
mapController: _map,
options: fm.MapOptions(
initialCenter: center,
initialZoom: 11,
onTap: (tapPos, latLng) async {
if (_searchResults.isNotEmpty) {
setState(() => _searchResults = []);
return;
}
Log.i('route_builder', 'Map tapped: ${latLng.latitude},${latLng.longitude}');
await _showMapTapActionPicker(context, latLng);
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
// OSM POI markers (subtle, background)
if (_osmPOIs.isNotEmpty)
fm.MarkerLayer(
markers: _osmPOIs
.map((poi) => fm.Marker(
point: poi.coordinates,
width: 24,
height: 24,
child: GestureDetector(
onTap: () => _showOSMPOIDetails(poi),
child: Container(
width: 24,
height: 24,
decoration: BoxDecoration(
color: poi.type.color.withValues(alpha: 0.7),
shape: BoxShape.circle,
border: Border.all(
color: Colors.white.withValues(alpha: 0.8),
width: 1.5,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.15),
blurRadius: 2,
offset: const Offset(0, 1),
),
],
),
child: Icon(
poi.type.icon,
color: Colors.white,
size: 14,
),
),
),
))
.toList(),
),
// Custom POI waypoints (bold, prominent)
if (_poiWaypoints.isNotEmpty)
fm.MarkerLayer(
markers: _poiWaypoints
.map((wp) => fm.Marker(
point: wp.position,
width: 36,
height: 36,
child: GestureDetector(
onTap: () => _editWaypoint(wp),
child: Container(
decoration: BoxDecoration(
color: Colors.white,
shape: BoxShape.circle,
border: Border.all(color: getWaypointColor(wp.type), width: 3.5),
boxShadow: [
BoxShadow(
color: getWaypointColor(wp.type).withValues(alpha: 0.3),
blurRadius: 8,
spreadRadius: 2,
),
BoxShadow(
color: Colors.black.withValues(alpha: 0.2),
blurRadius: 4,
offset: const Offset(0, 2),
),
],
),
child: Center(child: Icon(getWaypointIcon(wp.type), color: getWaypointColor(wp.type), size: 18)),
),
),
))
.toList(),
),
],
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
onZoomIn: () => _map.move(_map.camera.center, _map.camera.zoom + 1),
onZoomOut: () => _map.move(_map.camera.center, _map.camera.zoom - 1),
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
),
],
);
}),
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
Log.i('route_builder', '🔍 Starting search for: "$query"');
final center = _map.camera.center;
final results = await _svc.searchPlaces(
query,
proximityLat: center.latitude,
proximityLng: center.longitude,
);

Log.i('route_builder', '✅ Search returned ${results.length} results');

if (mounted) {
setState(() {
_searchResults = results;
_searching = false;
});
}
} catch (e, stack) {
Log.e('route_builder', '❌ Search failed', e, stack);
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

void _selectPlace(PlaceSuggestion place) {
Log.i('route_builder', 'Place selected: ${place.text} at ${place.latitude}, ${place.longitude}');
final latLng = ll.LatLng(place.latitude, place.longitude);
_map.move(latLng, 14);
_searchFocusNode.unfocus();
setState(() {
_searchResults = [];
_searchController.clear();
});
}

Future<void> _loadPOIs() async {
if (_loadingPOIs) return;

setState(() => _loadingPOIs = true);
Log.i('route_builder', '🔍 Starting to load OSM POIs...');

try {
final bounds = _map.camera.visibleBounds;
Log.i('route_builder', '📍 Map bounds: S=${bounds.south.toStringAsFixed(2)}, W=${bounds.west.toStringAsFixed(2)}, N=${bounds.north.toStringAsFixed(2)}, E=${bounds.east.toStringAsFixed(2)}');

// Load main outdoor POI types
final pois = await POIService.fetchPOIs(
southWest: ll.LatLng(bounds.south, bounds.west),
northEast: ll.LatLng(bounds.north, bounds.east),
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
maxResults: 100,
);

if (mounted) {
setState(() {
_osmPOIs = pois;
_loadingPOIs = false;
});
Log.i('route_builder', '✅ Loaded ${pois.length} OSM POIs successfully');
}
} catch (e, stack) {
Log.e('route_builder', '❌ Failed to load POIs', e, stack);
if (mounted) {
setState(() => _loadingPOIs = false);
}
}
}

void _showOSMPOIDetails(POI poi) {
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
);
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
// If we're in waypoint-adding mode, show the waypoint dialog directly
if (_addingWaypointViaMap) {
setState(() => _addingWaypointViaMap = false);
await _showWaypointDialogAtLocation(latLng);
return;
}

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
'What to add?',
style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
textAlign: TextAlign.center,
),
const SizedBox(height: 24),
_ActionTile(
icon: Icons.navigation,
color: const Color(0xFF4CAF50),
label: 'Route Point',
onTap: () => Navigator.of(context).pop('route'),
),
const SizedBox(height: 12),
_ActionTile(
icon: Icons.restaurant,
color: const Color(0xFFFF9800),
label: 'Restaurant',
onTap: () => Navigator.of(context).pop('restaurant'),
),
const SizedBox(height: 12),
_ActionTile(
icon: Icons.hotel,
color: const Color(0xFF2196F3),
label: 'Accommodation',
onTap: () => Navigator.of(context).pop('accommodation'),
),
const SizedBox(height: 12),
_ActionTile(
icon: Icons.local_activity,
color: const Color(0xFF9C27B0),
label: 'Activity',
onTap: () => Navigator.of(context).pop('activity'),
),
const SizedBox(height: 12),
_ActionTile(
icon: Icons.visibility,
color: const Color(0xFFFFC107),
label: 'Viewing Point',
onTap: () => Navigator.of(context).pop('viewingPoint'),
),
],
),
),
),
);

if (!mounted || action == null) return;

if (action == 'route') {
setState(() {
_points.add(latLng);
_hintDismissed = true; // auto-hide hint once a point is added
});
await _updatePreview();
} else {
final type = WaypointType.values.firstWhere((t) => t.name == action);
await _addWaypointAtLocation(type, latLng);
}
}

/// Show waypoint dialog at a specific location (when adding via map tap from + button)
Future<void> _showWaypointDialogAtLocation(ll.LatLng latLng) async {
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: latLng,
),
);

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
_map.move(result.position, _map.camera.zoom);
});
}
}
}

Future<void> _addWaypointAtLocation(WaypointType type, ll.LatLng position) async {
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
preselectedType: type,
proximityBias: position,
),
);

if (result != null && mounted) {
setState(() {
// Auto-assign time slot category if not set
if (result.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(result);
_poiWaypoints.add(result.copyWith(timeSlotCategory: autoCategory));
} else {
_poiWaypoints.add(result);
}
});
}
}

Future<void> _editWaypoint(RouteWaypoint waypoint) async {
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _WaypointEditorDialog(
existingWaypoint: waypoint,
type: waypoint.type,
position: waypoint.position,
),
);

if (!mounted) return;

if (result == null) {
setState(() {
_poiWaypoints.removeWhere((w) => w.id == waypoint.id);
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

if (confirmed == true && mounted) {
setState(() {
_poiWaypoints.removeWhere((w) => w.id == waypoint.id);
});
}
}

Future<void> _showAddRoutePointDialog() async {
// Show the waypoint dialog with routePoint preselected
final center = _map.camera.center;
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
preselectedType: WaypointType.routePoint,
proximityBias: center,
),
);

if (result != null && mounted) {
setState(() {
_points.add(result.position);
_hintDismissed = true;
});
await _updatePreview();
}
}

Future<void> _showRoutePointOptions(int index) async {
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

if (!mounted || action == null) return;

if (action == 'delete') {
setState(() {
_points.removeAt(index);
});
await _updatePreview();
}
}

Widget _buildWaypointsSection() {
// Group waypoints by time slot category
final Map<TimeSlotCategory, List<RouteWaypoint>> grouped = {};

// Initialize all categories
for (final category in TimeSlotCategory.values) {
grouped[category] = [];
}

// Group existing waypoints
for (final waypoint in _poiWaypoints) {
if (waypoint.timeSlotCategory != null) {
grouped[waypoint.timeSlotCategory]!.add(waypoint);
} else {
// Auto-assign if not set
final autoCategory = autoAssignTimeSlotCategory(waypoint);
if (autoCategory != null) {
grouped[autoCategory]!.add(waypoint);
}
}
}

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
'Day Timeline (${_poiWaypoints.length} waypoints)',
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

// Timeline sections
if (_waypointsExpanded)
Container(
constraints: const BoxConstraints(maxHeight: 500),
child: _poiWaypoints.isEmpty
? Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [
Icon(Icons.schedule, size: 48, color: Colors.grey.shade400),
const SizedBox(height: 12),
Text(
'No waypoints added yet',
style: TextStyle(
color: Colors.grey.shade700,
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
Text(
'Tap the + button or click on the map to add waypoints',
style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
textAlign: TextAlign.center,
),
],
),
)
: ListView(
shrinkWrap: true,
padding: const EdgeInsets.all(16),
children: [
// Only show categories that have waypoints or are main categories
_buildTimelineCategory(TimeSlotCategory.breakfast, grouped[TimeSlotCategory.breakfast]!),
_buildTimelineCategory(TimeSlotCategory.morningActivity, grouped[TimeSlotCategory.morningActivity]!),
_buildTimelineCategory(TimeSlotCategory.lunch, grouped[TimeSlotCategory.lunch]!),
_buildTimelineCategory(TimeSlotCategory.afternoonActivity, grouped[TimeSlotCategory.afternoonActivity]!),
_buildTimelineCategory(TimeSlotCategory.dinner, grouped[TimeSlotCategory.dinner]!),
_buildTimelineCategory(TimeSlotCategory.eveningActivity, grouped[TimeSlotCategory.eveningActivity]!),
_buildTimelineCategory(TimeSlotCategory.accommodation, grouped[TimeSlotCategory.accommodation]!),
if (grouped[TimeSlotCategory.servicePoint]!.isNotEmpty)
_buildTimelineCategory(TimeSlotCategory.servicePoint, grouped[TimeSlotCategory.servicePoint]!),
if (grouped[TimeSlotCategory.viewingPoint]!.isNotEmpty)
_buildTimelineCategory(TimeSlotCategory.viewingPoint, grouped[TimeSlotCategory.viewingPoint]!),
],
),
),
],
),
);
}

Widget _buildTimelineCategory(TimeSlotCategory category, List<RouteWaypoint> waypoints) {
final icon = getTimeSlotIcon(category);
final label = getTimeSlotLabel(category);
final defaultTime = getDefaultSuggestedTime(category);

return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
border: Border.all(color: context.colors.outline.withValues(alpha: 0.2)),
borderRadius: BorderRadius.circular(12),
color: Colors.white,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// Category header
Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
),
child: Row(
children: [
Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(8),
),
child: Icon(icon, size: 16, color: Colors.grey.shade700),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text(
label,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
color: Colors.black87,
),
),
if (waypoints.isNotEmpty) ...[
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: context.colors.primary.withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(10),
),
child: Text(
'${waypoints.length}',
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.w700,
color: context.colors.primary,
),
),
),
],
],
),
if (defaultTime != null) ...[
const SizedBox(height: 4),
Row(
children: [
Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
const SizedBox(width: 4),
Text(
'Suggested: $defaultTime',
style: TextStyle(
fontSize: 11,
color: Colors.grey.shade600,
),
),
],
),
],
],
),
),
],
),
),

// Waypoints or empty state
if (waypoints.isEmpty)
Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
Icon(icon, size: 28, color: Colors.grey.shade300),
const SizedBox(height: 8),
Text(
'No ${label.toLowerCase()} added',
style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
),
const SizedBox(height: 8),
OutlinedButton.icon(
onPressed: () => _showAddWaypointDialogForCategory(category),
icon: const Icon(Icons.add, size: 16),
label: Text('Add $label', style: const TextStyle(fontSize: 12)),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
minimumSize: Size.zero,
tapTargetSize: MaterialTapTargetSize.shrinkWrap,
),
),
],
),
)
else
Padding(
padding: const EdgeInsets.all(12),
child: Column(
children: [
...waypoints.map((waypoint) => Padding(
padding: const EdgeInsets.only(bottom: 8),
child: UnifiedWaypointCard(
waypoint: waypoint,
showActions: true,
onEdit: () => _editWaypoint(waypoint),
onDelete: () => _deleteWaypoint(waypoint),
showDragHandle: false,
),
)),
const SizedBox(height: 4),
OutlinedButton.icon(
onPressed: () => _showAddWaypointDialogForCategory(category),
icon: const Icon(Icons.add, size: 16),
label: Text('Add to $label', style: const TextStyle(fontSize: 12)),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
minimumSize: Size.zero,
tapTargetSize: MaterialTapTargetSize.shrinkWrap,
side: BorderSide(color: context.colors.outline),
),
),
],
),
),
],
),
);
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
case TimeSlotCategory.servicePoint:
preselectedType = WaypointType.servicePoint;
break;
case TimeSlotCategory.viewingPoint:
preselectedType = WaypointType.viewingPoint;
break;
}

final center = _map.camera.center;
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: center,
excludeRoutePoint: true,
preselectedType: preselectedType,
),
);

if (result != null && mounted) {
setState(() {
// Auto-assign category if not already set
if (result.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(result);
_poiWaypoints.add(result.copyWith(
timeSlotCategory: autoCategory ?? category,
));
} else {
_poiWaypoints.add(result);
}
_map.move(result.position, _map.camera.zoom);
});
}
}

Future<void> _showAddWaypointDialog() async {
// Show the waypoint dialog directly (using user's current map center as proximity bias)
// Exclude routePoint type since this is for POI waypoints only
final center = _map.camera.center;
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointDialog(
proximityBias: center,
excludeRoutePoint: true,
),
);

if (result != null && mounted) {
setState(() {
// Auto-assign time slot category if not set
if (result.timeSlotCategory == null) {
final autoCategory = autoAssignTimeSlotCategory(result);
_poiWaypoints.add(result.copyWith(timeSlotCategory: autoCategory));
} else {
_poiWaypoints.add(result);
}
_map.move(result.position, _map.camera.zoom);
});
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
final VoidCallback onZoomIn; final VoidCallback onZoomOut;
const _ZoomControls({required this.onZoomIn, required this.onZoomOut});
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
child: _WaypointList(
items: poiWaypoints,
onEdit: onEditWaypoint,
onReorder: onReorder,
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
Column(children: [
for (int i = 0; i < poiWaypoints.length; i++)
_SidebarWaypointTile(
waypoint: poiWaypoints[i],
onEdit: () => onEditWaypoint(poiWaypoints[i]),
onMoveUp: i == 0 ? null : () => onReorder(i, i - 1),
onMoveDown: i == poiWaypoints.length - 1 ? null : () => onReorder(i, i + 2),
),
]),
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
const _SidebarWaypointTile({required this.waypoint, required this.onEdit, this.onMoveUp, this.onMoveDown});
@override
Widget build(BuildContext context) => Container(
height: 56,
decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
child: Row(children: [
Icon(Icons.drag_indicator, size: 18, color: Colors.grey.shade400),
const SizedBox(width: 6),
Container(width: 28, height: 28, decoration: BoxDecoration(color: getWaypointColor(waypoint.type), borderRadius: BorderRadius.circular(8)),
child: Icon(getWaypointIcon(waypoint.type), color: Colors.white, size: 16)),
const SizedBox(width: 10),
Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(waypoint.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
Text(getWaypointLabel(waypoint.type), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
])),
if (onMoveUp != null) IconButton(onPressed: onMoveUp, icon: const Icon(Icons.arrow_upward, size: 16)),
if (onMoveDown != null) IconButton(onPressed: onMoveDown, icon: const Icon(Icons.arrow_downward, size: 16)),
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
Icon(Icons.drag_indicator, size: 20, color: Colors.grey.shade400),
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
Icon(Icons.drag_indicator, size: 18, color: Colors.grey.shade400),
const SizedBox(width: 6),
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
/// Add waypoint dialog with Google Places search
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

class _AddWaypointDialogState extends State<_AddWaypointDialog> {
final _searchController = TextEditingController();
final _nameController = TextEditingController();
final _descController = TextEditingController();
final _airbnbAddressController = TextEditingController();
final _urlController = TextEditingController();
final _placesService = GooglePlacesService();
late WaypointType _selectedType;
POIAccommodationType? _accommodationType;
MealTime? _mealTime;
ActivityTime? _activityTime;
List<PlacePrediction> _searchResults = [];
PlaceDetails? _selectedPlace;
bool _searching = false;
bool _geocoding = false;
bool _extractingMetadata = false;
ll.LatLng? _airbnbLocation;
bool _airbnbAddressConfirmed = false;
Timer? _searchDebounce;
String _lastSearchedQuery = ''; // Track last successful search to prevent duplicates
Map<String, dynamic>? _extractedMetadata; // Stores extracted URL metadata
bool _hasSearchedOrExtracted = false; // Track if user has searched or extracted

@override
void initState() {
super.initState();
_selectedType = widget.preselectedType ?? WaypointType.restaurant;
_searchController.addListener(_onSearchChanged);
}

@override
void dispose() {
_searchController.dispose();
_nameController.dispose();
_descController.dispose();
_airbnbAddressController.dispose();
_urlController.dispose();
_searchDebounce?.cancel();
super.dispose();
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

Log.i('waypoint_dialog', 'Extracted - title: "$title", description: "$description", image: "$image", siteName: "$siteName"');

// Always set _hasSearchedOrExtracted to true and store metadata
setState(() {
_extractedMetadata = metadataWithUrl;
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

void _onSearchChanged() {
final query = _searchController.text.trim();

// Check if user pasted a Google Maps link
if (GoogleLinkParser.isGoogleMapsUrl(query)) {
// ✅ ADD DEBOUNCE: Wait 500ms before processing
_searchDebounce?.cancel();
_searchDebounce = Timer(const Duration(milliseconds: 500), () {
if (mounted && _searchController.text.trim() == query) {
_handleGoogleLink(query);
}
});
return;
}

// Don't search if query is same as last successful search
if (query == _lastSearchedQuery) {
return;
}

if (query.length < 3) {
setState(() {
_searchResults = [];
_searching = false;
});
_lastSearchedQuery = ''; // Reset last searched query
return;
}

_searchDebounce?.cancel();
// Optimized: 600ms debounce reduces API calls by 90% while maintaining responsiveness
_searchDebounce = Timer(const Duration(milliseconds: 600), () {
_performSearch(query);
});
}

/// Handle Google Maps link paste
Future<void> _handleGoogleLink(String url) async {
// Show immediate feedback
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars();
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Row(
children: [
SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
),
SizedBox(width: 12),
Text('Processing Google Maps link...'),
],
),
duration: Duration(seconds: 30), // Long duration
),
);
}

setState(() => _searching = true);

try {
// Try to extract place ID from URL
String? placeId = GoogleLinkParser.extractPlaceId(url);

// If not found, try expanding short URL
if (placeId == null && (url.contains('goo.gl') || url.contains('share.google'))) {
Log.i('waypoint_dialog', 'Expanding short URL...');
placeId = await GoogleLinkParser.expandShortUrl(url);
}

if (placeId != null) {
Log.i('waypoint_dialog', 'Place ID extracted: $placeId');

// Fetch place details directly
final details = await _placesService.getPlaceDetails(placeId);

if (details != null && mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
_nameController.text = details.name;
_descController.text = details.address ?? '';
_searchController.text = details.name;
setState(() {
_selectedPlace = details;
_searching = false;
_hasSearchedOrExtracted = true;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('✓ Place loaded from Google link!'),
backgroundColor: Colors.green,
duration: Duration(seconds: 2),
),
);
return;
}
}

// Failed to extract place - CRITICAL FIX: Clear the search field!
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
setState(() {
_searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
_searching = false;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Could not extract place from this link. Try searching instead.'),
backgroundColor: Colors.orange,
duration: Duration(seconds: 3),
),
);
}
} catch (e) {
Log.e('waypoint_dialog', 'Failed to process Google link', e);

// CRITICAL FIX: Clear the search field on any error!
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
setState(() {
_searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
_searching = false;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error processing link: ${e.toString()}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
}
}

Future<void> _performSearch(String query) async {
setState(() => _searching = true);

try {
List<String>? typeFilters;
switch (_selectedType) {
case WaypointType.restaurant:
typeFilters = ['restaurant', 'cafe', 'bar'];
break;
case WaypointType.accommodation:
typeFilters = ['lodging', 'hotel'];
break;
case WaypointType.activity:
typeFilters = ['tourist_attraction'];
break;
case WaypointType.viewingPoint:
typeFilters = ['tourist_attraction'];
break;
case WaypointType.servicePoint:
case WaypointType.routePoint:
// Don't filter by type for service points and route points to avoid API errors
// Let the search query determine the results
typeFilters = null;
break;
}

final results = await _placesService.searchPlaces(
query: query,
proximity: widget.proximityBias,
types: typeFilters,
);

if (mounted) {
setState(() {
_searchResults = results;
_searching = false;
_lastSearchedQuery = query; // Remember successful search to prevent duplicates
});
}
} catch (e) {
Log.e('waypoint_dialog', 'Search failed', e);
if (mounted) {
setState(() => _searching = false);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
);
}
}
}

Future<void> _selectPlace(PlacePrediction prediction) async {
final details = await _placesService.getPlaceDetails(prediction.placeId);

if (details != null && mounted) {
_nameController.text = details.name;
_descController.text = details.address ?? '';
_searchController.text = details.name;
setState(() {
_selectedPlace = details;
_searchResults = [];
_hasSearchedOrExtracted = true;
});
}
}

Future<void> _geocodeAirbnbAddress() async {
final address = _airbnbAddressController.text.trim();
if (address.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter an address first')),
);
return;
}

setState(() => _geocoding = true);

final location = await _placesService.geocodeAddress(address);

setState(() => _geocoding = false);

if (location != null) {
setState(() {
_airbnbLocation = location;
_airbnbAddressConfirmed = true;
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
content: Text('Could not find location. Please check the address.'),
backgroundColor: Colors.orange,
),
);
}
}
}

@override
Widget build(BuildContext context) => Dialog(
backgroundColor: Colors.transparent,
elevation: 0,
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
Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: () => Navigator.pop(context),
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

Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// Modern search section
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
controller: _searchController,
decoration: InputDecoration(
hintText: 'Search for a place or paste Google Maps link',
hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
prefixIcon: Container(
padding: const EdgeInsets.all(12),
child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
),
suffixIcon: _searchController.text.isNotEmpty
? IconButton(
icon: const Icon(Icons.clear_rounded, size: 20),
color: Colors.grey.shade400,
onPressed: () {
_searchController.clear();
setState(() => _searchResults = []);
},
)
: (_searching
? const Padding(
padding: EdgeInsets.all(12),
child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
)
: null),
border: InputBorder.none,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
),
),
),
const SizedBox(height: 8),
Row(
children: [
Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.grey.shade400),
const SizedBox(width: 6),
Text('Tip: Paste Google Maps share links directly', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
const SizedBox(width: 4),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
child: const Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32), letterSpacing: 0.5)),
),
],
),
const SizedBox(height: 12),
if (_searchResults.isNotEmpty) ...[
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
child: ClipRRect(
borderRadius: BorderRadius.circular(14),
child: ListView.separated(
shrinkWrap: true,
padding: const EdgeInsets.symmetric(vertical: 8),
itemCount: _searchResults.length,
separatorBuilder: (_, __) => Divider(height: 1, indent: 56, endIndent: 16, color: Colors.grey.shade200),
itemBuilder: (_, i) {
final result = _searchResults[i];
return Material(
color: Colors.transparent,
child: InkWell(
onTap: () => _selectPlace(result),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: const Color(0xFFF5F5F5),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.place_rounded, size: 20, color: Color(0xFF428A13)),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
result.text,
style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Text(
result.placeId,
style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
),
),
Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
],
),
),
),
);
},
),
),
),
const SizedBox(height: 8),
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Image.network(
'https://developers.google.com/static/maps/images/powered-by-google-on-white.png',
height: 16,
errorBuilder: (_, __, ___) => Text('Powered by Google', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
),
],
),
],
if (_selectedPlace != null) ...[
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.green.shade50,
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
Text(
_selectedPlace!.name,
style: const TextStyle(fontWeight: FontWeight.w600),
),
if (_selectedPlace!.rating != null)
Text(
'⭐ ${_selectedPlace!.rating!.toStringAsFixed(1)}',
style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
),
],
),
),
IconButton(
icon: const Icon(Icons.close, size: 18),
onPressed: () {
_searchController.clear();
_nameController.clear();
_descController.clear();
setState(() {
_selectedPlace = null;
// Only reset if no metadata is extracted either
if (_extractedMetadata == null) {
_hasSearchedOrExtracted = false;
}
});
},
),
],
),
),
const SizedBox(height: 4),
// ✅ "Powered by Google" Attribution
Text(
'Powered by Google Places',
style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
),
],
// URL/Link metadata extraction section
if (_extractedMetadata == null) ...[
const SizedBox(height: 20),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Or extract from URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
],
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
if (_selectedPlace == null) {
_hasSearchedOrExtracted = false;
}
});
},
),
],
),
),
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
_searchResults = [];
if (_searchController.text.isNotEmpty) {
_performSearch(_searchController.text);
}
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
// Show Image preview if available from extraction
if (_extractedMetadata != null && _extractedMetadata!['image'] != null && _extractedMetadata!['image'].toString().isNotEmpty) ...[
const SizedBox(height: 16),
Row(
children: [
Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
const SizedBox(width: 8),
Text('Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
],
),
const SizedBox(height: 8),
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
if (_selectedPlace != null)
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
const Flexible(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Place selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
Text('Ready to add', style: TextStyle(fontSize: 11, color: Colors.grey)),
],
),
),
],
),
)
else if (_extractedMetadata != null && widget.proximityBias != null)
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
);

bool _canSave() {
if (_nameController.text.trim().isEmpty) return false;

// Route points don't need Google Place selection - just name and location from proximity bias
if (_selectedType == WaypointType.routePoint) {
return widget.proximityBias != null; // Must have a location set
}

if (_selectedType == WaypointType.accommodation && _accommodationType == null) return false;
if (_accommodationType == POIAccommodationType.airbnb && !_airbnbAddressConfirmed) return false;

// Allow saving if:
// 1. Place is selected from Google (has location)
// 2. Metadata is extracted AND we have a proximity bias (map location)
// 3. Airbnb with confirmed address
final hasPlace = _selectedPlace != null;
final hasMetadataWithLocation = _extractedMetadata != null && widget.proximityBias != null;
final hasAirbnbLocation = _accommodationType == POIAccommodationType.airbnb && _airbnbAddressConfirmed;

if (!hasPlace && !hasMetadataWithLocation && !hasAirbnbLocation) return false;

return true;
}

void _save() async {
if (!_canSave()) return;

String? photoUrl;
if (_selectedPlace?.photoReference != null) {
final waypointId = const Uuid().v4();

// Show loading indicator
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Row(
children: [
SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
SizedBox(width: 12),
Text('Caching photo...'),
],
),
duration: Duration(seconds: 2),
),
);
}

// Use cached photo method
photoUrl = await _placesService.getCachedPhotoUrl(
_selectedPlace!.photoReference!,
waypointId,
);
}

ll.LatLng position;
if (_selectedType == WaypointType.routePoint && widget.proximityBias != null) {
// Route points use the proximity bias (map tap location) or selected place if searched
position = _selectedPlace?.location ?? widget.proximityBias!;
} else if (_accommodationType == POIAccommodationType.airbnb && _airbnbLocation != null) {
position = _airbnbLocation!;
} else if (_selectedPlace != null) {
position = _selectedPlace!.location;
} else if (widget.proximityBias != null) {
// Use proximity bias (map tap location) for extracted metadata waypoints
position = widget.proximityBias!;
} else {
return;
}

final waypoint = RouteWaypoint(
type: _selectedType,
position: position,
name: _nameController.text.trim(),
description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
order: 0,
googlePlaceId: _selectedPlace?.placeId,
address: _accommodationType == POIAccommodationType.airbnb
? _airbnbAddressController.text.trim()
: _selectedPlace?.address,
rating: _selectedPlace?.rating,
website: _selectedPlace?.website,
phoneNumber: _selectedPlace?.phoneNumber,
photoUrl: photoUrl,
accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
mealTime: _selectedType == WaypointType.restaurant ? _mealTime : null,
activityTime: _selectedType == WaypointType.activity ? _activityTime : null,
linkUrl: _extractedMetadata != null ? _urlController.text.trim() : null,
linkImageUrl: _extractedMetadata != null ? (_extractedMetadata!['image'] as String?) : null,
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

double? _rating;
List<String> _amenities = [];
POIAccommodationType? _accommodationType;
MealTime? _mealTime;
ActivityTime? _activityTime;
final List<String> _availableAmenities = [
'WiFi',
'Parking',
'Pool',
'Gym',
'Spa',
'Restaurant',
'Bar',
'Room Service',
'Air Conditioning',
'Pet Friendly'
];

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
// Round rating to nearest 0.5 to match dropdown items
_rating = wp?.rating != null ? (wp!.rating! * 2).round() / 2 : null;
_amenities = List.from(wp?.amenities ?? []);
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
Widget build(BuildContext context) => Dialog(
child: Container(
constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: getWaypointColor(_selectedType).withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(8),
),
child: Icon(getWaypointIcon(_selectedType), color: getWaypointColor(_selectedType)),
),
const SizedBox(width: 12),
Text(
widget.existingWaypoint == null ? 'Add Waypoint' : 'Edit Waypoint',
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
),
const Spacer(),
IconButton(
icon: const Icon(Icons.close),
onPressed: () => Navigator.of(context).pop(),
),
],
),
),
const Divider(height: 1),
Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.all(16),
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
const Divider(height: 1),
Padding(
padding: const EdgeInsets.all(16),
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
);

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
const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
DropdownButtonFormField<double>(
value: _rating,
decoration: InputDecoration(
hintText: 'Select rating',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
.map((r) => DropdownMenuItem(
value: r,
child: Row(
children: List.generate(
5,
(i) => Icon(
i < r.floor() ? Icons.star : (i < r ? Icons.star_half : Icons.star_border),
color: Colors.amber,
size: 20,
)),
),
))
.toList(),
onChanged: (value) => setState(() => _rating = value),
),
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
const SizedBox(height: 16),
const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
DropdownButtonFormField<double>(
value: _rating,
decoration: InputDecoration(
hintText: 'Select rating',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
.map((r) => DropdownMenuItem(
value: r,
child: Row(
children: List.generate(
5,
(i) => Icon(
i < r.floor() ? Icons.star : (i < r ? Icons.star_half : Icons.star_border),
color: Colors.amber,
size: 20,
)),
),
))
.toList(),
onChanged: (value) => setState(() => _rating = value),
),
const SizedBox(height: 16),
const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: _availableAmenities.map((amenity) {
final isSelected = _amenities.contains(amenity);
return FilterChip(
label: Text(amenity),
selected: isSelected,
onSelected: (selected) {
setState(() {
if (selected) {
_amenities.add(amenity);
} else {
_amenities.remove(amenity);
}
});
},
);
}).toList(),
),
const SizedBox(height: 16),
const Text('Estimated Price Range (per night)', style: TextStyle(fontWeight: FontWeight.w600)),
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
const SizedBox(height: 16),
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
final minPrice = double.tryParse(_priceMinController.text.trim());
final maxPrice = double.tryParse(_priceMaxController.text.trim());
if (minPrice != null && maxPrice != null && minPrice > 0 && maxPrice > 0) {
priceRange = PriceRange(min: minPrice, max: maxPrice);
}

final waypoint = RouteWaypoint(
id: widget.existingWaypoint?.id,
type: _selectedType,
position: widget.position,
name: _nameController.text.trim(),
description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
order: widget.existingWaypoint?.order ?? 0,
photoUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
rating: _rating,
website: websiteUrl.isEmpty ? null : websiteUrl,
phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
hotelChain: _hotelChainController.text.trim().isEmpty ? null : _hotelChainController.text.trim(),
amenities: _amenities.isEmpty ? null : _amenities,
estimatedPriceRange: priceRange,
bookingComUrl: bookingUrl.isEmpty ? null : bookingUrl,
airbnbPropertyUrl: airbnbUrl.isEmpty ? null : airbnbUrl,
mealTime: _selectedType == WaypointType.restaurant ? _mealTime : null,
activityTime: _selectedType == WaypointType.activity ? _activityTime : null,
);
Navigator.of(context).pop(waypoint);
}
}
