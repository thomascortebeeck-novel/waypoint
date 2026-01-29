# Route Builder - Mapbox Migration Status

## ⚠️ Current Limitation
The Route Builder screen is **not yet migrated** to use Mapbox GL JS/Native. It continues using `flutter_map` with raster tiles even when `MapFeatureFlags.useMapboxEverywhere = true`.

**Why?** The Route Builder needs advanced editing features (custom layers, tap handlers, marker dragging) that aren't yet supported by `AdaptiveMapWidget`.

## Current State
The current Route Builder implementation uses `flutter_map` directly with:
- **Two map instances**: Desktop sidebar layout + Mobile/Tablet bottom panel layout
- **Interactive markers**: Route points (A, B, intermediates) that can be tapped for options
- **Multiple marker layers**:
  1. Route preview polyline (green line from geometry)
  2. Route points (A/B/intermediate markers)
  3. OSM POI markers (background, subtle)
  4. Custom POI waypoints (prominent, colorful)
- **Map interactions**:
  - `onTap`: Show action picker (add route point, restaurant, accommodation, etc.)
  - `onPositionChanged`: Debounced POI reload
  - Marker tap: Show options/edit dialogs
- **Raster tiles**: Using `defaultRasterTileUrl` from mapbox_config

## Migration Strategy

### Phase 1: ✅ Preserve flutter_map Implementation
- Created this documentation file to explain the current setup
- Backup location: `lib/features/map/ROUTE_BUILDER_MIGRATION.md`
- The git history also preserves the flutter_map implementation

### Phase 2: Replace flutter_map with AdaptiveMapWidget
**Key Changes:**
1. Replace both `fm.FlutterMap` widgets with `AdaptiveMapWidget`
2. Use `MapConfiguration.routeBuilder()` for config
3. Keep all map layers and interactions as-is initially
4. The `AdaptiveMapWidget` will handle:
   - Engine selection (Mapbox GL JS for web, Mapbox Native for mobile)
   - Fallback to flutter_map if Mapbox fails
   - All based on `MapFeatureFlags.useMapboxEverywhere`

**Important Considerations:**
- `AdaptiveMapWidget` renders `fm.FlutterMap` internally when using raster mode
- All flutter_map layers (TileLayer, PolylineLayer, MarkerLayer) work the same way
- Interactive markers work the same in both engines
- The migration is mostly a wrapper change, not a logic rewrite

### Phase 3: Test Mapbox Marker Dragging (Future Enhancement)
- When `MapFeatureFlags.enableMapboxMarkerDrag` is true
- Enable draggable markers in Mapbox native/GL mode
- This is a future enhancement, not part of initial migration

## What to Preserve
✅ Keep all business logic:
- Route preview calculation
- Elevation profile fetching
- POI loading and filtering
- Waypoint management
- Search functionality
- All dialogs and UI components

✅ Keep all map interactions:
- Tap to add points
- Marker tap for options
- Pan/zoom handling
- POI debouncing

✅ Keep all layouts:
- Desktop sidebar (>=1280px)
- Mobile/tablet bottom panel
- Floating search bar
- Zoom controls

## Rollback Plan
If migration causes issues:
1. Git revert to commit before migration
2. Set `MapFeatureFlags.useMapboxEverywhere = false` in map_feature_flags.dart
3. This will make `MapConfiguration.routeBuilder()` return flutter_map config

## Migration Date
Initiated: 2026-01-29

## Migration Status
- ⏸️ Paused: Requires AdaptiveMapWidget enhancement

## Technical Blocker
The Route Builder cannot be migrated to `AdaptiveMapWidget` yet because:

1. **Missing Layer Support**: `AdaptiveMapWidget` doesn't expose a way to add custom layers (polylines, markers) to the map
2. **Missing Event Handlers**: No support for `onTap`, `onPositionChanged`, etc.
3. **Different Architecture**: `AdaptiveMapWidget` is designed for viewing (overlays on top) not editing (layers inside map)

## Next Steps
To enable Mapbox for Route Builder, we need to:

1. **Extend AdaptiveMapWidget** to accept:
   - `children` parameter for custom flutter_map layers
   - `onTap`, `onPositionChanged` callbacks
   - OR create a separate `EditableMapWidget` class

2. **OR Keep flutter_map for editing** and accept that Route Builder uses raster tiles even when `useMapboxEverywhere = true`

## Current Behavior
- ✅ Route Builder: Uses `flutter_map` with **raster tiles** (stable, proven)
- ✅ All Viewer Screens: Use `AdaptiveMapWidget` with **Mapbox GL JS/Native** (beautiful vector tiles + 3D terrain)
  - Enhanced Map Screen
  - Fullscreen Route Map
  - Tracking Screen
  - Trip Day Map
  - Preview Cards (optional - currently using raster for performance)

## Recommended Path Forward

### Option 1: Accept Current Hybrid Approach (Recommended for Now)
- Keep Route Builder using raster tiles for stability
- All viewing experiences use Mapbox for beautiful visuals
- Users edit on raster, view on vector (like some pro mapping tools)
- **Pros**: Stable, no migration risk, proven editing UX
- **Cons**: Inconsistent visual style between editing and viewing

### Option 2: Full Mapbox Editing Migration (Future Enhancement)
Requires building advanced features into `AdaptiveMapWidget`:

1. **Add Custom Layer Support**
   ```dart
   AdaptiveMapWidget(
     children: [
       // Custom polylines, markers, etc.
     ],
   )
   ```

2. **Add Event Handlers**
   ```dart
   AdaptiveMapWidget(
     onTap: (LatLng position) { },
     onPositionChanged: (MapCamera camera) { },
   )
   ```

3. **Add Marker Dragging**
   ```dart
   AdaptiveMapWidget(
     enableMarkerDrag: true,
     onMarkerDrag: (String markerId, LatLng newPosition) { },
   )
   ```

**Effort**: 2-3 days of development + testing
**Risk**: Medium (requires careful testing of editing workflows)
**Benefit**: Consistent Mapbox experience across all screens

## Recommendation
Keep the current hybrid approach until editing features are fully proven on Mapbox. The Route Builder is a critical workflow - stability matters more than visual consistency here.
