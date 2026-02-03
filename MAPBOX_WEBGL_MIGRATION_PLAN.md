# Mapbox WebGL Migration Plan - Complete Transition

## 🎯 Objective
Transition all map implementations from `flutter_map` (legacy) to Mapbox WebGL (web) and Mapbox Native SDK (iOS/Android) across all 5 pages.

## 📋 Current State Analysis

### ✅ Already Using Mapbox (No Changes Needed)
1. **Builder Page Preview Map** (`builder_screen.dart` line 2098)
   - ✅ Uses `AdaptiveMapWidget` with `MapConfiguration.mainMap()`
   - ✅ Web: Mapbox WebGL | Mobile: Mapbox Native

2. **Route Builder** (`route_builder_screen.dart` line 880)
   - ✅ Uses `AdaptiveMapWidget` via `_buildMapboxEditor()`
   - ✅ Controlled by feature flags (`MapFeatureFlags.useMapboxEverywhere`)
   - ✅ Web: Mapbox WebGL | Mobile: Mapbox Native

3. **Fullscreen Route Map** (`fullscreen_route_map.dart`)
   - ✅ Uses `AdaptiveMapWidget` with `MapConfiguration.mainMap()`
   - ✅ Web: Mapbox WebGL | Mobile: Mapbox Native

4. **Trip Day Fullscreen Map** (`trip_day_map_fullscreen.dart`)
   - ✅ Uses `AdaptiveMapWidget` with `MapConfiguration.mainMap()`
   - ✅ Web: Mapbox WebGL | Mobile: Mapbox Native

### ❌ Still Using flutter_map (Needs Migration)
1. **WaypointMapCard Component** (`waypoint_map_card.dart` line 312)
   - ❌ Uses `FlutterMap` directly
   - Used by: Plan details, Trip details (preview maps)
   - **Action**: Replace with `AdaptiveMapWidget`

2. **Plan Details Page Map** (`plan_details_screen.dart` line 3383)
   - ❌ Uses `_DayMapWidget` which uses `FlutterMap` directly
   - **Action**: Replace `_DayMapWidget` with `AdaptiveMapWidget`

3. **Trip Details Page Map** (`trip_details_screen.dart` line 3169)
   - ❌ Uses `_TripDayMapWidget` which uses `FlutterMap` directly
   - **Action**: Replace `_TripDayMapWidget` with `AdaptiveMapWidget`

## 🗺️ Target Pages (5 Total)

### 1. Builder Page Preview Map
- **File**: `lib/presentation/builder/builder_screen.dart`
- **Method**: `_buildDayRouteMap()` (line 2021)
- **Status**: ✅ **ALREADY MIGRATED**
- **Implementation**: Uses `AdaptiveMapWidget` with `MapConfiguration.mainMap()`

### 2. Builder Page Route Builder
- **File**: `lib/presentation/builder/route_builder_screen.dart`
- **Method**: `_buildMapboxEditor()` (line 762)
- **Status**: ✅ **ALREADY MIGRATED**
- **Implementation**: Uses `AdaptiveMapWidget` with `MapConfiguration.routeBuilder()`
- **Note**: Controlled by `MapFeatureFlags.useMapboxEverywhere`

### 3. Plan Details Page Preview Map
- **File**: `lib/presentation/details/plan_details_screen.dart`
- **Method**: `_buildDayMap()` → `_DayMapWidget` (line 2587 → 3287)
- **Status**: ❌ **NEEDS MIGRATION**
- **Current**: Uses `FlutterMap` with raster tiles
- **Target**: Replace `_DayMapWidget` with `AdaptiveMapWidget`
- **Requirements**:
  - Show all waypoints
  - Show route polyline
  - Show start/end markers (A/B)
  - Map controls (fit bounds, zoom)

### 4. Trip Details Page Preview Map
- **File**: `lib/presentation/trips/trip_details_screen.dart`
- **Method**: `_buildDayMap()` → `_TripDayMapWidget` (line 2169 → 3079)
- **Status**: ❌ **NEEDS MIGRATION**
- **Current**: Uses `FlutterMap` with raster tiles
- **Target**: Replace `_TripDayMapWidget` with `AdaptiveMapWidget`
- **Requirements**:
  - Show all waypoints if owner OR no selections
  - Show only selected waypoints if participant with selections
  - Show route polyline
  - Show start/end markers (A/B)
  - Map controls (fit bounds, zoom)
  - Fullscreen navigation button

### 5. Fullscreen Trip Map Per Day
- **File**: `lib/presentation/trips/trip_day_map_fullscreen.dart`
- **Status**: ✅ **ALREADY MIGRATED**
- **Implementation**: Uses `AdaptiveMapWidget` with `MapConfiguration.mainMap()`

## 🔧 Implementation Strategy

### Phase 1: Migrate WaypointMapCard Component
**File**: `lib/components/map/waypoint_map_card.dart`

**Changes**:
1. Replace `FlutterMap` with `AdaptiveMapWidget`
2. Convert `fm.Marker` to `MapAnnotation`
3. Convert `fm.Polyline` to `MapPolyline`
4. Use `WaypointMapController` for fit bounds
5. Maintain all existing functionality:
   - OSM POI loading
   - Waypoint filtering (all vs selected)
   - Start/End markers
   - Route polyline
   - Edit Route button
   - Fullscreen navigation

**Configuration**:
```dart
MapConfiguration.mainMap(
  styleUri: mapboxStyleUri,
  rasterTileUrl: defaultRasterTileUrl,
  enable3DTerrain: false, // Flat for preview cards
  initialZoom: 12.0,
)
```

### Phase 2: Migrate Plan Details Map Widget
**File**: `lib/presentation/details/plan_details_screen.dart`

**Changes**:
1. Replace `_DayMapWidget` class with `AdaptiveMapWidget` usage
2. Convert `Marker` to `MapAnnotation`
3. Convert `Polyline` to `MapPolyline`
4. Use `WaypointMapController` for map controls
5. Maintain all existing functionality:
   - Route polyline
   - Start/End markers (A/B)
   - Waypoint markers
   - Map controls (fit bounds, zoom in/out)

**Configuration**:
```dart
MapConfiguration.mainMap(
  styleUri: mapboxStyleUri,
  rasterTileUrl: defaultRasterTileUrl,
  enable3DTerrain: false, // Flat for preview
  initialZoom: calculatedZoom,
)
```

### Phase 3: Migrate Trip Details Map Widget
**File**: `lib/presentation/trips/trip_details_screen.dart`

**Changes**:
1. Replace `_TripDayMapWidget` class with `AdaptiveMapWidget` usage
2. Convert `Marker` to `MapAnnotation`
3. Convert `Polyline` to `MapPolyline`
4. Use `WaypointMapController` for map controls
5. Maintain all existing functionality:
   - Route polyline
   - Start/End markers (A/B)
   - Waypoint markers (filtered by selections)
   - Map controls (fit bounds, zoom in/out)
   - Fullscreen navigation button

**Configuration**:
```dart
MapConfiguration.mainMap(
  styleUri: mapboxStyleUri,
  rasterTileUrl: defaultRasterTileUrl,
  enable3DTerrain: false, // Flat for preview
  initialZoom: calculatedZoom,
)
```

## 📐 Architecture Details

### AdaptiveMapWidget Features
- **Web**: Automatically uses Mapbox GL JS (WebGL)
- **iOS/Android**: Automatically uses Mapbox Native SDK
- **Fallback**: Falls back to flutter_map if Mapbox fails
- **Annotations**: Supports `MapAnnotation` for markers
- **Polylines**: Supports `MapPolyline` for routes
- **Controller**: Unified `WaypointMapController` API

### MapAnnotation Conversion
```dart
// Old (flutter_map)
Marker(
  point: waypoint.position,
  width: 36,
  height: 36,
  child: Container(...),
)

// New (AdaptiveMapWidget)
MapAnnotation.fromWaypoint(waypoint)
```

### MapPolyline Conversion
```dart
// Old (flutter_map)
Polyline(
  points: coordinates,
  strokeWidth: 4.0,
  color: Colors.green,
)

// New (AdaptiveMapWidget)
MapPolyline(
  id: 'route_1',
  points: coordinates,
  color: Colors.green,
  width: 4.0,
)
```

### WaypointMapController API
```dart
// Fit bounds
await controller.animateCamera(center, zoom);

// Add route
await controller.addRoutePolyline(points, color: Colors.green, width: 4.0);

// Add markers
await controller.addMarker('id', position);

// Get current position
final pos = controller.currentPosition;
```

## ✅ Success Criteria

1. **All 5 pages use Mapbox WebGL on web**
2. **All 5 pages use Mapbox Native SDK on iOS/Android**
3. **No flutter_map usage remains (except as fallback)**
4. **All existing functionality preserved**:
   - Waypoint display
   - Route polylines
   - Start/End markers
   - Map controls
   - OSM POI loading (where applicable)
   - Waypoint filtering (trip details)
5. **Consistent styling** across all maps
6. **Performance**: Smooth rendering on all platforms

## 🧪 Testing Checklist

### Web Testing
- [ ] Builder preview map loads with Mapbox WebGL
- [ ] Route builder loads with Mapbox WebGL
- [ ] Plan details map loads with Mapbox WebGL
- [ ] Trip details map loads with Mapbox WebGL
- [ ] Fullscreen maps load with Mapbox WebGL
- [ ] All markers render correctly
- [ ] All polylines render correctly
- [ ] Map controls work (zoom, fit bounds)
- [ ] OSM POIs load and display (where applicable)

### Mobile Testing (iOS/Android)
- [ ] All maps use Mapbox Native SDK
- [ ] 3D terrain works (where enabled)
- [ ] All markers render correctly
- [ ] All polylines render correctly
- [ ] Map controls work
- [ ] Performance is smooth

### Functionality Testing
- [ ] Waypoint filtering works (trip details)
- [ ] Fullscreen navigation works
- [ ] Edit Route button works (where applicable)
- [ ] Map bounds calculation is correct
- [ ] Zoom levels are appropriate

## 📝 Implementation Order

1. **Migrate WaypointMapCard** (affects multiple pages)
2. **Migrate Plan Details Map Widget**
3. **Migrate Trip Details Map Widget**
4. **Test all pages**
5. **Remove legacy flutter_map code** (optional cleanup)

## 🔄 Rollback Plan

If issues arise:
1. Set `MapFeatureFlags.useMapboxEverywhere = false` in `map_feature_flags.dart`
2. This will revert to flutter_map raster tiles
3. All functionality will continue to work

## 📅 Timeline

- **Phase 1**: WaypointMapCard migration (~1 hour)
- **Phase 2**: Plan Details migration (~1 hour)
- **Phase 3**: Trip Details migration (~1 hour)
- **Testing**: All platforms (~1 hour)
- **Total**: ~4 hours

---

*Plan created: 2026-02-03*
*Status: Ready for Implementation*

