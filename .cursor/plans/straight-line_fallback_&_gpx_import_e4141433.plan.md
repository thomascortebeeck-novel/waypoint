---
name: Straight-Line Fallback & GPX Import
overview: Implement straight-line fallback routes when Google Directions API fails, and add GPX file upload/import with waypoint snapping for outdoor activities. This enables trail route visualization and accurate waypoint positioning along imported GPX tracks.
todos:
  - id: update-travel-info-model
    content: Add routeType enum and field to TravelInfo class in travel_calculator_service.dart
    status: completed
  - id: create-haversine-utils
    content: Create haversine_utils.dart with geodesic distance calculation functions
    status: completed
  - id: implement-straight-line-fallback
    content: Add straight-line fallback logic to calculateTravel() in TravelCalculatorService
    status: completed
    dependencies:
      - update-travel-info-model
      - create-haversine-utils
  - id: extend-mappolyline-dash
    content: Add isDashed, dashPattern, and opacity properties to MapPolyline class
    status: completed
  - id: render-straight-line-routes
    content: Update map rendering to show dashed straight-line routes with muted colors
    status: completed
    dependencies:
      - extend-mappolyline-dash
      - implement-straight-line-fallback
  - id: add-straight-line-indicators
    content: Add visual indicators (chips/labels) showing straight-line distance and unknown duration
    status: completed
    dependencies:
      - render-straight-line-routes
  - id: update-dayroute-model
    content: Add routeType field to DayRoute model for persistence
    status: completed
    dependencies:
      - update-travel-info-model
  - id: create-gpx-route-model
    content: Create GpxRoute model class with all required fields and serialization
    status: completed
  - id: create-gpx-parser-service
    content: Create GpxParserService using gpx package to parse files and calculate metrics
    status: completed
    dependencies:
      - create-gpx-route-model
  - id: create-waypoint-snapper
    content: Create GpxWaypointSnapper service with snapToRoute and estimateTravelTime methods
    status: completed
    dependencies:
      - create-gpx-route-model
  - id: update-routewaypoint-snap
    content: Add waypointSnapInfo field to RouteWaypoint model
    status: completed
    dependencies:
      - create-waypoint-snapper
  - id: add-gpx-upload-ui
    content: Add GPX file upload button and remove route button to RouteInfoSection
    status: in_progress
    dependencies:
      - create-gpx-parser-service
  - id: update-dayitinerary-gpx
    content: Add gpxRoute field to DayItineraryDoc model with Firestore serialization
    status: completed
    dependencies:
      - create-gpx-route-model
  - id: render-gpx-route-map
    content: Render GPX route polyline on maps with trail-green styling
    status: completed
    dependencies:
      - update-dayitinerary-gpx
  - id: render-snap-lines
    content: Draw dashed lines from waypoints to their snap points on GPX route
    status: completed
    dependencies:
      - render-gpx-route-map
      - update-routewaypoint-snap
  - id: integrate-gpx-travel-calc
    content: Update TravelCalculatorService to use GPX-based calculations when route exists
    status: completed
    dependencies:
      - create-waypoint-snapper
      - update-dayitinerary-gpx
  - id: add-order-validation
    content: Add waypoint order validation against GPX route direction
    status: completed
    dependencies:
      - create-waypoint-snapper
  - id: implement-route-priority
    content: "Implement route display priority: GPX > Directions > Straight-line"
    status: completed
    dependencies:
      - render-gpx-route-map
      - render-straight-line-routes
  - id: handle-gpx-removal
    content: Implement GPX route removal with fallback to Directions/straight-line
    status: completed
    dependencies:
      - integrate-gpx-travel-calc
  - id: update-route-info-display
    content: Update RouteInfoSection to show GPX route stats and snap distances
    status: completed
    dependencies:
      - add-gpx-upload-ui
      - render-snap-lines
---

# Straight-

Line Fallback Routes & GPX Route Import with Waypoint Snapping

## Overview

This plan implements two major route improvements:

1. **Straight-line fallback**: When Google Directions API fails, draw dashed straight lines between waypoints
2. **GPX import**: Allow users to upload GPX files for outdoor activities, with automatic waypoint snapping to the imported route

## Part 1: Straight-Line Fallback Routes

### 1.1 Update TravelInfo Model

**File**: `lib/services/travel_calculator_service.dart`

- Add `routeType` enum field to `TravelInfo` class:
  ```dart
            enum RouteType { directions, straightLine, gpx }
  ```




- Add `routeType` field (default: `RouteType.directions`)
- Add `isFallback` getter for convenience
- Update constructor and any serialization if needed

### 1.2 Implement Haversine Distance Calculation

**File**: `lib/utils/haversine_utils.dart` (new file)

- Create utility functions for geodesic distance calculation
- Use `latlong2` package's `Distance` class (already available)
- Function: `double calculateHaversineDistance(LatLng from, LatLng to)` returns km

### 1.3 Add Straight-Line Fallback to TravelCalculatorService

**File**: `lib/services/travel_calculator_service.dart`

- Modify `calculateTravel()` method:
- After Directions API returns `null` or fails
- After Distance Matrix fallback also fails
- Calculate straight-line distance using Haversine
- Return `TravelInfo` with:
    - `routeType: RouteType.straightLine`
    - `distanceMeters`: calculated straight-line distance
    - `durationSeconds`: 0 or null (unknown duration)
    - `routeGeometry`: 2-point polyline `[from, to]`
- Update `_getDistanceMatrix()` error handling to properly detect failures

### 1.4 Update Map Rendering for Straight-Line Routes

**Files**:

- `lib/features/map/adaptive_map_widget.dart`
- `lib/features/map/google_map_widget_web.dart`
- `lib/features/map/google_map_widget_mobile.dart`
- `lib/presentation/builder/route_builder_screen.dart`
- Extend `MapPolyline` class to support:
- `isDashed: bool` flag
- `dashPattern: List<int>?` (e.g., `[10, 8]` for 10px dash, 8px gap)
- `opacity: double` (default 1.0)
- When rendering polylines:
- Check `TravelInfo.routeType` or `DayRoute` metadata
- If `RouteType.straightLine`:
    - Apply dashed pattern (10px dash, 8px gap)
    - Use muted color (e.g., `Colors.grey.shade600` or `Colors.orange.shade300`)
    - Set opacity to 0.6
    - Width: 4px (slightly thinner than normal routes)
- For Google Maps widgets: Use `PatternItem.dash()` and `PatternItem.gap()`
- For flutter_map: Use `dashArray` property on `Polyline`

### 1.5 Add Visual Indicators

**Files**: Map rendering locations

- Add info chip/label near straight-line segments:
- Small badge/chip showing "No road route — straight line"
- Or tooltip on hover/tap
- Display distance: "~12.4 km (straight line)"
- Show "Duration unknown" or leave blank

### 1.6 Update DayRoute Model

**File**: `lib/models/plan_model.dart`

- Add optional `routeType` field to `DayRoute` class
- Store route type metadata for persistence
- Update `fromJson`/`toJson` methods

## Part 2: GPX File Upload & Route Import

### 2.1 Create GPX Route Model

**File**: `lib/models/gpx_route_model.dart` (new file)

- Create `GpxRoute` class with:
- `name: String?`
- `trackPoints: List<LatLng>` (full resolution)
- `simplifiedPoints: List<LatLng>` (downsampled for rendering)
- `totalDistanceKm: double`
- `totalElevationGainM: double?`
- `estimatedDuration: Duration?`
- `bounds: LatLngBounds` (min/max lat/lng)
- `importedAt: DateTime`
- `fileName: String`
- Add `fromJson`/`toJson` for Firestore persistence
- Add `copyWith` method

### 2.2 Create GPX Parser Service

**File**: `lib/services/gpx_parser_service.dart` (new file)

- Use existing `gpx: ^2.0.0` package
- Parse GPX file (File or Uint8List):
- Extract `<trk><trkseg><trkpt>` (tracks) - primary format
- Extract `<rte><rtept>` (routes) - fallback format
- Extract `<name>` tag for route name
- Extract elevation from `<ele>` tags
- Extract timestamps from `<time>` tags if available
- Calculate total distance: sum distances between consecutive track points
- Calculate elevation gain: sum positive elevation changes
- Calculate estimated duration from time data if available
- Simplify/downsample polyline:
- If > 500 points, reduce to ~200-300 points
- Use simple nth-point sampling (every Nth point) or Ramer-Douglas-Peucker
- Preserve start/end points
- Store both full and simplified arrays
- Return `GpxRoute` object

### 2.3 Create Waypoint Snapper Service

**File**: `lib/services/gpx_waypoint_snapper.dart` (new file)

- Create `SnapResult` class:
- `snapPoint: LatLng` (closest point on route)
- `distanceFromRoute: double` (meters)
- `distanceAlongRoute: double` (km, cumulative from start)
- `segmentIndex: int` (which GPX segment)
- Create `GpxWaypointSnapper` class:
- `snapToRoute(LatLng waypoint, List<LatLng> routePoints) -> SnapResult`:
    - Iterate through consecutive route point pairs (line segments)
    - For each segment, calculate perpendicular distance from waypoint
    - Find minimum distance segment
    - Calculate projection point on that segment
    - Return snap result
- `snapAllWaypoints(List<RouteWaypoint> waypoints, GpxRoute route) -> List<SnapResult>`
- `estimateTravelTime(double distanceKm, ActivityCategory activityType, double? elevationGainM) -> Duration`:
    - Use activity-specific speeds:
    - Hiking: 4 km/h (flat), adjust for elevation
    - Cycling: 15 km/h
    - Climbing: 2 km/h
    - Skiing: 10 km/h
    - If GPX has time data, interpolate between timestamps
- Calculate cumulative distance along route for each waypoint

### 2.4 Update RouteWaypoint Model

**File**: `lib/models/route_waypoint.dart`

- Add optional `waypointSnapInfo` field:
  ```dart
            class WaypointSnapInfo {
              final LatLng snapPoint;
              final double distanceFromRouteM;
              final double distanceAlongRouteKm;
              final int segmentIndex;
            }
  ```




- Update `fromJson`/`toJson` methods
- Add `copyWith` support

### 2.5 Add GPX Upload UI to RouteInfoSection

**File**: `lib/components/builder/route_info_section.dart`

- Add GPX upload button (only for manual-entry activity types):
- Icon: `Icons.upload_file` or `Icons.route`
- Label: "Import GPX Route"
- Place in manual entry form, after difficulty dropdown
- On tap:
- Use `file_picker` package to pick `.gpx` files
- Show loading indicator while parsing
- Call `GpxParserService.parseGpxFile()`
- On success:
    - Show success message: "Route imported (X.X km, Y waypoints)"
    - Display "Remove Route" button
    - Trigger waypoint snapping via `GpxWaypointSnapper`
    - Save to Firestore
- On error: Show error message
- Add "Remove Route" button when GPX is imported
- Store GPX route reference in component state

### 2.6 Update DayItineraryDoc Model

**File**: `lib/models/day_itinerary_model.dart`

- Add `gpxRoute: GpxRoute?` field
- Update `fromJson`/`toJson` methods
- Ensure Firestore structure matches:
  ```dart
            gpxRoute: {
              name: string | null,
              trackPoints: [{ lat: number, lng: number, ele: number | null }], // Simplified only
              totalDistanceKm: number,
              totalElevationGainM: number | null,
              estimatedDuration: string | null, // "6h 30m"
              importedAt: timestamp,
              fileName: string
            }
  ```




### 2.7 Render GPX Route on Map

**Files**: Map rendering locations (route_builder_screen.dart, waypoint_map_card.dart, etc.)

- When `DayRoute.gpxRoute` exists:
- Render GPX polyline using `simplifiedPoints`
- Style: solid line, color `#2E7D32` (trail green), width 4px, opacity 0.8
- Render underneath waypoint markers (z-order)
- Auto-fit camera to `gpxRoute.bounds` when first loaded
- When waypoints have `waypointSnapInfo`:
- Draw dashed line from waypoint marker to `snapPoint` if `distanceFromRouteM > 50`
- Style: dashed, grey, thin (2px), opacity 0.5
- Label showing distance off-trail (e.g., "200m off-trail")

### 2.8 Integrate GPX-Based Travel Calculations

**File**: `lib/services/travel_calculator_service.dart`

- When GPX route exists for a day:
- Override `calculateTravel()` behavior:
    - Use `GpxWaypointSnapper` to get snap points
    - Calculate distance along route between consecutive waypoint snap points
    - Use `estimateTravelTime()` for duration
    - Return `TravelInfo` with `routeType: RouteType.gpx`
    - Use GPX route geometry instead of Directions API

### 2.9 Waypoint Order Validation

**File**: `lib/services/gpx_waypoint_snapper.dart` or builder screen

- After snapping waypoints:
- Check if waypoint order matches their `distanceAlongRoute` order
- If not, show warning: "Waypoint order doesn't match route direction. Reorder?"
- Optionally auto-reorder waypoints by distance along route

### 2.10 Update Builder Screen for GPX Integration

**File**: `lib/presentation/builder/builder_screen.dart`

- Pass GPX route to `RouteInfoSection` if available
- Trigger waypoint snapping when:
- GPX file is uploaded
- Waypoints are added/removed/reordered
- Day is loaded with existing GPX route
- Save GPX route to Firestore in `_composeDays()`
- Load GPX route when editing existing plan

## Part 3: Integration & Route Priority

### 3.1 Route Display Priority Logic

**Files**: Map rendering locations

- Implement priority system:

1. **GPX route exists?** → Render GPX polyline + snap waypoints + show distances along trail
2. **No GPX, Directions succeeds?** → Render Directions API polyline (current behavior)
3. **No GPX, Directions fails?** → Render dashed straight line between waypoints

- Update route calculation to respect this priority

### 3.2 Handle GPX Route Removal

**Files**: RouteInfoSection, builder_screen.dart

- When "Remove Route" is clicked:
- Clear `gpxRoute` from day document
- Remove waypoint snap info from all waypoints
- Recalculate routes using Directions API
- Fall back to straight-line where Directions fails
- Update UI to remove GPX-specific displays

### 3.3 Update Route Info Display

**File**: `lib/components/builder/route_info_section.dart`

- When GPX route is imported:
- Show GPX route stats (distance, elevation, duration) in auto-calculated card style
- Display "GPX Route" badge instead of "Auto-calculated"
- Show waypoint snap distances if waypoints are off-trail

## Dependencies

- ✅ `gpx: ^2.0.0` - Already in pubspec.yaml
- ✅ `file_picker: ^8.1.2` - Already in pubspec.yaml  
- ✅ `firebase_storage: ^13.0.0` - Already in pubspec.yaml (optional, for storing original GPX files)
- ✅ `latlong2: 0.9.1` - Already available for distance calculations

## Testing Considerations

- Test straight-line fallback with remote locations (no roads)
- Test GPX parsing with various GPX file formats
- Test waypoint snapping with waypoints at various distances from route
- Test route priority logic (GPX > Directions > Straight-line)
- Test GPX route removal and fallback behavior
- Test performance with large GPX files (>1000 points)

## Files to Create

1. `lib/utils/haversine_utils.dart`
2. `lib/models/gpx_route_model.dart`
3. `lib/services/gpx_parser_service.dart`
4. `lib/services/gpx_waypoint_snapper.dart`

## Files to Modify

1. `lib/services/travel_calculator_service.dart` - Add straight-line fallback, GPX support
2. `lib/models/plan_model.dart` - Add routeType to DayRoute
3. `lib/models/route_waypoint.dart` - Add waypointSnapInfo
4. `lib/models/day_itinerary_model.dart` - Add gpxRoute field
5. `lib/features/map/adaptive_map_widget.dart` - Add dash pattern support to MapPolyline
6. `lib/features/map/google_map_widget_web.dart` - Render dashed polylines