# Mapbox GL JS vs flutter_map vs Mapbox Native SDK: Technical Analysis

## Executive Summary

You're experiencing two critical issues with Mapbox GL JS on web:
1. **POI positioning shifts when zooming** - Markers appear to move to different locations
2. **Map tap events not working** - Cannot add custom waypoints by clicking the map

This document explains why these issues occur, how they differ from flutter_map, and what to expect on iOS/Android.

---

## Issue 1: POI Positioning Problems

### Root Cause

**Mapbox GL JS uses a different marker system than flutter_map:**

1. **flutter_map**: Markers are Flutter widgets positioned using screen-to-lat/lng conversion. The Flutter framework handles coordinate transformations automatically.

2. **Mapbox GL JS**: Markers are DOM elements positioned using `setLngLat([lng, lat])`. The coordinates must be in **longitude-first format** (GeoJSON standard), and markers are positioned in **screen space** by Mapbox's internal projection system.

### Why POIs Move on Zoom

The issue likely stems from one of these:

1. **Coordinate Order Mismatch**: If coordinates are stored as `[lat, lng]` but passed as `[lng, lat]`, markers will appear in wrong locations that shift with zoom.

2. **Marker Recreation**: If markers are being removed and recreated on every zoom update instead of being updated in place, there can be a brief moment where old markers are visible at wrong positions.

3. **Projection Issues**: Mapbox GL JS uses Web Mercator projection. If coordinates aren't properly transformed, they'll drift at different zoom levels.

### Current Implementation Status

✅ **Correct**: Line 703 in `mapbox_web_widget.dart` uses `[lng, lat]` format:
```dart
..callMethod('setLngLat', [js.JsObject.jsify([annotation.position.longitude, annotation.position.latitude])])
```

⚠️ **Potential Issue**: Markers might be recreated instead of updated. Check `_updateAnnotations` logic.

---

## Issue 2: Map Tap Events Not Working

### Root Cause

**Mapbox GL JS markers block map click events:**

1. **flutter_map**: Flutter widgets can have `pointer-events: none` or use `GestureDetector` with proper hit testing. Map taps work even when markers are present.

2. **Mapbox GL JS**: Markers are DOM elements with click handlers that call `e.stopPropagation()`. This prevents clicks from reaching the map's click handler.

### Current Implementation Status

❌ **Missing**: `MapboxWebWidget` doesn't accept or forward an `onTap` callback to `AdaptiveMapWidget`.

✅ **Present**: Map click handler exists (line 240-243) but only goes to `WebMapController` stream, not to widget callback.

---

## Platform Comparison

### Web (Mapbox GL JS)

**Pros:**
- High performance (WebGL rendering)
- Vector tiles (smaller data, smoother zooming)
- 3D terrain support
- Custom styling via Mapbox Studio

**Cons:**
- **DOM-based markers** - Can block events, require manual coordinate management
- **JavaScript interop complexity** - Dart ↔ JS communication overhead
- **Event handling quirks** - Need careful `stopPropagation` management
- **Coordinate system** - Must use `[lng, lat]` format consistently

**Common Issues:**
- Markers blocking map clicks (requires `pointer-events` CSS)
- Coordinate order mistakes (`[lat, lng]` vs `[lng, lat]`)
- Marker recreation causing visual glitches

### iOS/Android (Mapbox Native SDK)

**Pros:**
- **Native rendering** - No DOM, no JavaScript interop
- **Proper event handling** - Native touch events work correctly
- **Better performance** - Direct GPU access, optimized for mobile
- **Offline support** - Built-in TileStore for offline maps

**Cons:**
- Platform-specific code (Swift/Kotlin)
- Larger app size (native libraries)
- More complex setup (requires platform-specific configuration)

**How It Works:**
- Uses **PointAnnotation** API - Native objects, not DOM elements
- Coordinates are **always** in `[lng, lat]` format (GeoJSON standard)
- **Event handling is native** - Tap events work correctly out of the box
- **No coordinate drift** - Native SDK handles all projections internally

**Will You Have These Issues on Mobile?**

**NO** - The native SDK handles:
- ✅ Proper coordinate transformations
- ✅ Event propagation (markers don't block map taps)
- ✅ Marker updates (native objects update in place)
- ✅ Zoom-level positioning (projection handled automatically)

---

## Why flutter_map Didn't Have These Issues

1. **Flutter Widget System**: Markers are Flutter widgets, so coordinate transformations are handled by the framework.

2. **Gesture System**: Flutter's gesture system properly handles hit testing, so map taps work even with markers present.

3. **State Management**: Flutter widgets update in place, so no visual glitches when zooming.

4. **Simpler Architecture**: No JavaScript interop, no DOM manipulation, everything is Flutter-native.

**Trade-off**: flutter_map uses raster tiles (PNG images), which are:
- Larger file sizes
- Less smooth zooming
- No 3D terrain
- Limited styling options

---

## Recommended Solutions

### Fix 1: Map Tap Events

1. Add `onTap` callback to `MapboxWebWidget`
2. Forward map click events to the callback
3. Ensure marker click handlers don't block map clicks (use `pointer-events: auto` only on marker element, not container)

### Fix 2: POI Positioning

1. Verify markers are **updated in place** using `setLngLat()`, not recreated
2. Add debug logging to verify coordinates are correct before setting
3. Ensure coordinate order is consistent: **always `[lng, lat]`**

### Fix 3: Marker Event Handling

1. Use CSS `pointer-events: auto` on marker element only
2. Ensure map container has `pointer-events: auto` to receive clicks
3. Consider using Mapbox's `queryRenderedFeatures` for better hit testing

---

## Decision Matrix

### Should You Continue with Mapbox GL JS?

**YES, if:**
- You need 3D terrain, custom styling, or vector tiles
- Performance is critical (WebGL rendering)
- You're willing to handle JavaScript interop complexity

**Consider flutter_map if:**
- You need simpler event handling
- You don't need 3D or advanced styling
- You want to avoid JavaScript interop issues

### Mobile Strategy

**Use Mapbox Native SDK** - It solves all the web issues:
- Native event handling
- Proper coordinate management
- Better performance
- Offline support

---

## Next Steps

1. **Immediate**: Fix map tap events and POI positioning in current implementation
2. **Short-term**: Add comprehensive logging to debug coordinate issues
3. **Long-term**: Consider using Mapbox's native clustering API for better POI management

