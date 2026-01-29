# Mapbox Everywhere - Migration Guide

## 🎯 Goal

Enable **Mapbox for all screens** (like AllTrails) while preserving `flutter_map` as a tested fallback. This provides:

- **Consistent visual experience** across all map screens
- **Vector tiles and 3D terrain** throughout the app
- **Custom Mapbox styling** everywhere
- **Graceful fallback** if Mapbox has issues

---

## 📊 Current Architecture Status

### ✅ Hybrid Architecture (Default - Proven Stable)

| Screen Type | Web | iOS/Android | Status |
|-------------|-----|-------------|---------|
| **Route Builder** | `flutter_map` raster | `flutter_map` raster | ✅ Stable |
| **Preview Cards** | `flutter_map` raster | `flutter_map` raster | ✅ Stable |
| **Main Map** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |
| **Trip Day Maps** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |
| **Tracking** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |

### 🚀 Mapbox Everywhere (Feature Flag Enabled)

| Screen Type | Web | iOS/Android | Status |
|-------------|-----|-------------|---------|
| **Route Builder** | Mapbox GL JS → fallback | Mapbox Native → fallback | 🧪 Testing |
| **Preview Cards** | `flutter_map` raster | `flutter_map` raster | ✅ (unchanged) |
| **Main Map** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |
| **Trip Day Maps** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |
| **Tracking** | Mapbox GL JS → fallback | Mapbox Native → fallback | ✅ Stable |

---

## 🚀 How to Enable "Mapbox Everywhere"

### Development

```bash
# Enable Mapbox for Route Builder
flutter run --dart-define=USE_MAPBOX_EVERYWHERE=true

# Disable marker dragging (if needed)
flutter run --dart-define=ENABLE_MAPBOX_MARKER_DRAG=false

# Disable fallback (testing only - not recommended)
flutter run --dart-define=ALLOW_MAPBOX_FALLBACK=false
```

### Production Build

```bash
# Web
flutter build web --dart-define=USE_MAPBOX_EVERYWHERE=true

# Android
flutter build apk --dart-define=USE_MAPBOX_EVERYWHERE=true

# iOS
flutter build ios --dart-define=USE_MAPBOX_EVERYWHERE=true
```

### Verify Feature Flags

Add this to any screen to check current state:

```dart
import 'package:waypoint/features/map/map_feature_flags.dart';

debugPrint('Mapbox Everywhere: ${MapFeatureFlags.useMapboxEverywhere}');
debugPrint('Marker Drag: ${MapFeatureFlags.enableMapboxMarkerDrag}');
debugPrint('Fallback: ${MapFeatureFlags.allowMapboxFallback}');
```

---

## 📝 Feature Flags Reference

### `USE_MAPBOX_EVERYWHERE` (default: `false`)

**When `false`** (Hybrid - Current Stable):
- Route Builder uses `flutter_map` with raster tiles
- Viewing screens use Mapbox with fallback
- **Recommended for production**

**When `true`** (Mapbox Everywhere):
- Route Builder uses Mapbox (GL JS on web, Native on mobile)
- 3D terrain disabled in Route Builder for editing clarity
- Interactive markers enabled for route editing
- Fallback to `flutter_map` if Mapbox fails to load

### `ENABLE_MAPBOX_MARKER_DRAG` (default: `true`)

**When `true`**:
- Markers in Route Builder are draggable when using Mapbox
- Allows interactive route editing with Mapbox

**When `false`**:
- Markers are view-only even when using Mapbox
- Use if drag performance is poor

### `ALLOW_MAPBOX_FALLBACK` (default: `true`)

**When `true`**:
- If Mapbox fails to load, gracefully falls back to `flutter_map`
- **Recommended for production**

**When `false`**:
- No fallback - app will show error if Mapbox fails
- **Use only for testing Mapbox-specific features**

---

## 🧪 Testing Strategy

### Phase 1: Development Testing (Week 1)

**Checklist:**

- [ ] **Web Testing**
  - [ ] Route Builder: Markers draggable
  - [ ] Route Builder: Route updates on drag
  - [ ] Route Builder: Tap to add points works
  - [ ] Route Builder: Zoom/pan smooth
  - [ ] Fallback works if Mapbox fails
  
- [ ] **Mobile Testing (iOS/Android)**
  - [ ] Route Builder: Markers draggable
  - [ ] 3D terrain disabled in builder
  - [ ] Route updates on marker drag
  - [ ] Performance acceptable
  - [ ] Fallback works if Mapbox fails

- [ ] **Comparison Test**
  - [ ] Test Route Builder in default mode
  - [ ] Rebuild with `USE_MAPBOX_EVERYWHERE=true`
  - [ ] Compare interaction quality
  - [ ] Document differences

### Phase 2: Beta Testing (Week 2)

**Process:**
1. Enable for select beta users (10-20 people)
2. Gather feedback on:
   - Performance vs flutter_map
   - Interaction quality
   - Visual quality
   - Any bugs or issues
3. Monitor crash reports

### Phase 3: Gradual Rollout (Week 3-4)

**Timeline:**
- **Week 3**: 10% of users
- **Week 4**: 50% of users (if no major issues)
- **Week 5+**: 100% of users

**Metrics to Monitor:**
- Crash rate (should be < 0.1%)
- Map load time (should be < 3s on 4G)
- User complaints about map performance
- Route editing success rate

### Phase 4: Make Default (Week 6+)

**Criteria for Success:**
- [ ] 100% rollout for 2+ weeks
- [ ] Crash rate acceptable
- [ ] No significant user complaints
- [ ] Performance metrics good

**Actions:**
- Change `USE_MAPBOX_EVERYWHERE` default to `true`
- Move flutter_map implementations to `legacy/` folder
- Update documentation
- **Keep legacy code in git history**

---

## 🔧 Implementation Details

### MapConfiguration Changes

The `MapConfiguration.routeBuilder()` factory now respects the feature flag:

```dart
// Current implementation
MapConfiguration.routeBuilder(
  rasterTileUrl: defaultRasterTileUrl,
  styleUri: mapboxStyleUri,
  initialZoom: 11.0,
)

// Behavior depends on feature flag:
// - USE_MAPBOX_EVERYWHERE=false → flutter_map (stable)
// - USE_MAPBOX_EVERYWHERE=true  → Mapbox with fallback
```

### Marker Dragging

When using Mapbox in Route Builder:

```dart
// Markers are automatically draggable
config.enableInteractiveMarkers == true

// Listen to drag events
controller.onMarkerDrag.listen((event) {
  if (event.state == MarkerDragState.dragEnd) {
    // Update route when drag completes
    updateRoutePoint(event.markerId, event.position);
  }
});
```

### Fallback Behavior

If Mapbox fails to load:

```dart
// AdaptiveMapWidget automatically falls back to flutter_map
// if config.allowFallback == true
// 
// User sees:
// 1. Brief loading indicator
// 2. "Loading map..." message
// 3. Automatic switch to flutter_map
// 4. No error - seamless experience
```

---

## ⚠️ Safety Rules

### CRITICAL: Never Delete Code Until Proven

1. **DO NOT** delete flutter_map implementations
2. **DO NOT** remove fallback logic
3. **ALWAYS** keep feature flags toggleable
4. **ALWAYS** monitor crash reports during rollout

### Rollback Plan

If issues occur at any rollout phase:

```bash
# Immediate rollback (same day)
# 1. Change environment variable
USE_MAPBOX_EVERYWHERE=false

# 2. Redeploy
flutter build web --dart-define=USE_MAPBOX_EVERYWHERE=false

# 3. Verify rollback successful
# 4. Investigate issue
# 5. Fix and restart rollout
```

---

## 📚 Related Files

- `lib/features/map/map_feature_flags.dart` - Feature flag definitions
- `lib/features/map/map_configuration.dart` - Map engine selection logic
- `lib/features/map/waypoint_map_controller.dart` - Unified controller interface
- `lib/features/map/vector_map_controller.dart` - Mapbox Native implementation
- `lib/features/map/web/web_map_controller.dart` - Mapbox GL JS implementation
- `lib/features/map/legacy/` - Reference flutter_map implementations
- `lib/presentation/builder/route_builder_screen.dart` - Main editing screen

---

## 🎯 Benefits of Mapbox Everywhere

### User Experience
✅ Consistent visual style across all screens  
✅ Beautiful vector tiles and smooth zooming  
✅ 3D terrain in viewing mode  
✅ Custom branded map style  

### Development
✅ Single map technology to maintain  
✅ Fewer edge cases between screens  
✅ Better code reuse  

### Performance
✅ Offline support with Mapbox  
✅ Faster tile loading (vector vs raster)  
✅ Smoother interactions  

### Reliability
✅ Proven fallback to flutter_map  
✅ Gradual rollout minimizes risk  
✅ Feature flags allow instant rollback  

---

**Last Updated:** 2026-01-28  
**Status:** Feature implemented, ready for testing  
**Default Mode:** Hybrid (flutter_map for editing, Mapbox for viewing)
