# Waypoint Map Implementation Guide

## Overview
This guide explains how to integrate the Waypoint map system across all screens in your app. The system uses your custom Mapbox style and displays **two types of POIs with distinct visual styles** to create a clear hierarchy.

## 🎨 Visual Design System

### Marker Type Hierarchy

Your map displays **3 types of markers** with distinct visual styles:

| Marker Type | Purpose | Visual Style | Size |
|-------------|---------|--------------|------|
| **Start/End (A/B)** | Route endpoints | Solid circles with letters, bold | 40px |
| **Custom Waypoint POIs** | User's planned stops (CORE FEATURE) | **Bold**: White background, thick colored border, glow effect | 36px |
| **OSM POIs** | Community map data (supplementary) | **Subtle**: Muted colors, thin border, no glow | 24px |

---

### Custom Waypoint POIs (Your Core Product)

**Purpose**: User's personal trip plan - restaurants, accommodations, activities, viewing points, service points

**Visual Characteristics**:
```
┌─────────────────────┐
│   [Bold Circle]     │  ← 36px diameter
│   White background  │  ← Stands out from map
│   Thick colored     │  ← 3.5px border in type color
│   border with glow  │  ← Colored shadow/glow effect
│   Large clear icon  │  ← 20px, colored
└─────────────────────┘
```

**Code Style**:
```dart
Container(
  width: 36,
  height: 36,
  decoration: BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    border: Border.all(color: typeColor, width: 3.5),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
      BoxShadow(color: typeColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
    ],
  ),
  child: Icon(typeIcon, color: typeColor, size: 20),
)
```

**Examples**:
- Restaurant waypoint: White circle, orange border, fork-knife icon
- Accommodation: White circle, blue border, bed icon
- Viewpoint: White circle, gold border, eye icon

---

### OSM POIs (Community Map Data)

**Purpose**: Supplementary information from OpenStreetMap - campsites, huts, water sources, shelters, toilets

**Visual Characteristics**:
```
┌─────────────────┐
│  [Small Dot]    │  ← 24px diameter
│  Muted color    │  ← 70% opacity
│  Thin border    │  ← 1.5px white semi-transparent
│  Small icon     │  ← 14px, white
│  Minimal shadow │  ← Subtle 2px blur
└─────────────────┘
```

**Code Style**:
```dart
Container(
  width: 24,
  height: 24,
  decoration: BoxDecoration(
    color: typeColor.withOpacity(0.7),
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 2),
    ],
  ),
  child: Icon(typeIcon, color: Colors.white, size: 14),
)
```

**Examples**:
- OSM campsite: Small muted green dot, tent icon
- OSM water source: Small muted blue dot, droplet icon
- OSM shelter: Small muted red dot, roof icon

---

### Why This Visual Hierarchy?

**Custom Waypoints (Bold)**:
- ✅ User's personal plan is the **primary focus**
- ✅ White background ensures visibility on any map
- ✅ Larger size + glow = easy to tap on mobile
- ✅ Looks like an interactive button

**OSM POIs (Subtle)**:
- ✅ Provides helpful context without cluttering
- ✅ Blends into map background (minimalistic)
- ✅ Smaller size preserves screen space
- ✅ Muted colors don't compete with user waypoints

**Mental Model for Users**:
- "Big colorful circles = MY stops"
- "Small faded dots = Extra info from map"

---

## 🎯 Component Overview

### 1. Core Map Components
- **`WaypointMapCard`** - Reusable card component for small/embedded map views
- **`FullscreenRouteMap`** - Full-screen editable map for route building

### 2. Key Features
- ✅ Custom Mapbox style (mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf)
- ✅ **Dual POI system with visual differentiation**
- ✅ OSM POI display (automatic, 17 types)
- ✅ Custom waypoint POIs (user-added, prominent)
- ✅ Smart waypoint filtering (show all vs. show selected)
- ✅ Automatic map bounds fitting
- ✅ Route polyline display

---

## 📍 Integration Guide by Screen

### A) Builder Page - Small View

**File**: `lib/presentation/builder/builder_screen.dart`  
**Method**: `_buildDayRouteMap` (line ~2016)

**What's Displayed**:
- Route polyline (if exists)
- Start/End markers (A/B)
- **OSM POIs** (automatic, subtle background markers)
- **NO custom waypoint POIs yet** (user adds them in route builder)

**Replace with**:
```dart
// At top of file:
import 'package:waypoint/components/map/waypoint_map_card.dart';

// Replace _buildDayRouteMap method:
Widget _buildDayRouteMap(DayRoute? route, int dayNum, _VersionFormData vf) {
  final day = DayItinerary(
    title: 'Day $dayNum',
    description: '',
    startLocation: vf.startForDay[dayNum]?.label ?? '',
    endLocation: vf.endForDay[dayNum]?.label ?? '',
    distanceKm: route != null ? route.distance / 1000.0 : 0,
    estimatedTimeMinutes: route != null ? (route.duration / 60).round() : 0,
    startLat: vf.startForDay[dayNum]?.coordinates.latitude,
    startLng: vf.startForDay[dayNum]?.coordinates.longitude,
    endLat: vf.endForDay[dayNum]?.coordinates.latitude,
    endLng: vf.endForDay[dayNum]?.coordinates.longitude,
    route: route,
    photos: [],
  );

  return WaypointMapCard(
    day: day,
    displayMode: MapDisplayMode.all,
    height: 300,
    fetchOSMPOIs: true,  // Show subtle OSM markers
    showControls: false,
    onFullScreen: () {
      final planId = _editingPlan?.id ?? 'new';
      context.push(
        '/builder/route-builder/$planId/$_activeVersionIndex/$dayNum',
        extra: {
          'start': vf.startForDay[dayNum],
          'end': vf.endForDay[dayNum],
          'initial': vf.routeByDay[dayNum],
          'activityCategory': _activityCategory,
        },
      );
    },
  );
}
```

---

### B) Route Builder - Full Screen

**File**: `lib/presentation/builder/route_builder_screen.dart`

**What's Displayed**:
- Route polyline
- Start/End markers
- **OSM POIs** (subtle, tappable to add as custom waypoint)
- **Custom waypoint POIs** (bold, added by user, editable)

**Optional Integration**:
```dart
// Import at top:
import 'package:waypoint/components/map/fullscreen_route_map.dart';

// Use in build method:
FullscreenRouteMap(
  day: dayItinerary,
  onDayUpdated: (updatedDay) {
    // Handle updates
  },
  isEditMode: true,
)
```

**Note**: Current implementation works well. Only replace if you want full POI integration.

---

### C) Plan Details Page - Map Tab

**File**: `lib/presentation/details/plan_details_screen.dart`  
**Section**: Around line 2385-2410

**What's Displayed**:
- Route polyline
- Start/End markers
- **OSM POIs** (subtle background context)
- **Custom waypoint POIs** (bold, user's saved waypoints)

**Both types visible** - Shows user's plan prominently, with OSM context

**Replace with**:
```dart
// Import at top:
import 'package:waypoint/components/map/waypoint_map_card.dart';

// In map tab case (around line 2406):
case DayViewTab.map:
  return WaypointMapCard(
    day: day,
    displayMode: MapDisplayMode.all,  // Show everything
    height: 250,
    fetchOSMPOIs: true,  // Show subtle OSM POIs
    showControls: false,
    onFullScreen: () {
      context.push('/plan/${_planMeta?.id}/day/${dayNumber - 1}/map');
    },
  );
```

---

### D) Trip Details Page - Map Tab

**File**: `lib/presentation/trips/trip_details_screen.dart`  
**Method**: `_buildDayMap` (line ~2169)

**What's Displayed**:
- Route polyline
- Start/End markers
- **OSM POIs** (subtle, all types)
- **Custom waypoint POIs** (bold, filtered by participant selections OR all if owner/no selections)

**Smart Filtering**:
- **Trip Owner**: Sees all custom waypoints + OSM POIs
- **Participant with selections**: Sees only THEIR selected custom waypoints + OSM POIs
- **Participant without selections**: Sees all custom waypoints + OSM POIs

**Replace with**:
```dart
// Import at top:
import 'package:waypoint/components/map/waypoint_map_card.dart';

Widget _buildDayMap(DayItinerary day, int dayNumber) {
  final hasWaypoints = day.route?.poiWaypoints.isNotEmpty ?? false;
  final hasRoute = day.route != null && day.route!.routePoints.isNotEmpty;

  if (!hasRoute && !hasWaypoints) {
    return Center(
      child: Text(
        'No route available',
        style: context.textStyles.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }

  return WaypointMapCard(
    day: day,
    displayMode: MapDisplayMode.selectedOnly,  // Smart filtering
    daySelection: _daySelections[dayNumber - 1],
    isOwner: _isOwner,
    height: 250,
    fetchOSMPOIs: true,  // Show subtle OSM POIs
    showControls: false,
    onFullScreen: () {
      final planId = _planMeta?.id ?? '';
      final tripId = widget.tripId;
      context.push(
        '/itinerary/$planId/day/$tripId/${dayNumber - 1}/map',
        extra: day,
      );
    },
  );
}
```

---

### E) Trip Day Full Screen Map

**File**: `lib/presentation/trips/trip_day_map_fullscreen.dart`  
**Line**: ~191 (TileLayer)

**What's Displayed**:
- Full screen map
- Route polyline
- Start/End markers
- **OSM POIs** (subtle, all types)
- **Custom waypoint POIs** (bold, filtered by selections if applicable)
- Current location marker (if tracking)

**Update to custom style**:
```dart
// Find line 191 and replace TileLayer urlTemplate:
fm.TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/thomascortebeeck93/cmkv0yv7a006401s9akepciwf/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
  userAgentPackageName: 'com.waypoint.app',
),
```

**Optional**: Add OSM POI fetching if not already present.

---

## 🔧 Component Parameters

### WaypointMapCard

| Parameter | Type | Description |
|-----------|------|-------------|
| `day` | `DayItinerary` | Route and waypoint data |
| `displayMode` | `MapDisplayMode` | `.all` or `.selectedOnly` |
| `fetchOSMPOIs` | `bool` | Enable automatic OSM POI loading |
| `height` | `double?` | Map height in pixels (default: 200) |
| `onFullScreen` | `VoidCallback?` | Tap handler for fullscreen navigation |
| `showControls` | `bool` | Show "Edit Route" button |
| `daySelection` | `TripDaySelection?` | Trip selections for filtering |
| `isOwner` | `bool` | Whether user is trip owner |

---

### Display Mode Logic

#### `MapDisplayMode.all`
**Use for**: Builder, Plan details  
**Shows**: All custom waypoints (bold) + All OSM POIs (subtle)  
**Purpose**: Full planning view

#### `MapDisplayMode.selectedOnly`
**Use for**: Trip details  
**Shows**:
- **If owner OR no selections**: All custom waypoints + All OSM POIs
- **If participant with selections**: Only selected custom waypoints + All OSM POIs

**Purpose**: Personalized trip view for participants

---

## 📊 Marker Size Reference

```
Start/End (A/B):        ████████  40px
Custom Waypoint POI:    ██████    36px  ← USER'S PLAN (prominent)
OSM POI:                ███       24px  ← MAP DATA (subtle)
```

**Visual Hierarchy**:
1. Route endpoints (40px) - Largest, most important
2. Custom waypoints (36px) - Core product feature
3. OSM POIs (24px) - Supporting information

---

## 🎨 Map Style Details

- **Mapbox Style**: Custom "Outdoors Waypoint" (thomascortebeeck93/cmkv0yv7a006401s9akepciwf)
- **Route Line**: 4px width, green (#4CAF50), white border
- **Bounds Fitting**: Automatic with 15% padding
- **Coordinate Formats**: Handles both Array and Map formats

---

## ✅ Testing Checklist

After integration, verify:

### Visual Hierarchy
- [ ] Custom waypoint POIs are clearly larger and more prominent
- [ ] OSM POIs are smaller and blend into background
- [ ] White background on custom waypoints stands out from map
- [ ] Both types are easily distinguishable at a glance

### Functionality
- [ ] OSM POIs load automatically when map moves
- [ ] Custom waypoints display after being saved
- [ ] Tapping OSM POI shows details
- [ ] Tapping custom waypoint shows details
- [ ] Start/End markers display correctly
- [ ] Route polyline renders

### Filtering (Trip Views)
- [ ] Trip owner sees all waypoints
- [ ] Participant with selections sees only their choices
- [ ] Participant without selections sees all waypoints
- [ ] OSM POIs always visible (regardless of filtering)

### Performance
- [ ] Map renders smoothly with 20+ markers
- [ ] No lag when panning/zooming
- [ ] Markers update within 500ms after map stops moving

---

## 🐛 Troubleshooting

### OSM POIs not showing?
- ✅ Check Firebase Cloud Function `getOutdoorPOIs` is deployed
- ✅ Verify function region: `europe-west1`
- ✅ Check browser/app console for errors
- ✅ Ensure map bounds are reasonable (<100km²)

### Custom waypoints not showing?
- ✅ Verify `day.route.poiWaypoints` contains data
- ✅ Check waypoint coordinates are valid
- ✅ Ensure `displayMode` is set correctly
- ✅ For trip views, verify selection filtering logic

### Markers look the same?
- ✅ Verify `_buildOSMPOIMarker()` uses 24px, 70% opacity, thin border
- ✅ Verify `_buildCustomWaypointMarker()` uses 36px, white background, thick border
- ✅ Check shadow/glow effects are rendering

### Map shows gray tiles?
- ✅ Verify `mapboxPublicToken` is valid
- ✅ Check internet connection
- ✅ Ensure custom style ID is correct
- ✅ Verify style is published in Mapbox Studio

---

## 📝 Implementation Priority

**Recommended order** (easiest to hardest):

1. **Screen E** (5 min) - Just change TileLayer URL
2. **Screen C** (15 min) - Replace map tab case
3. **Screen D** (15 min) - Replace `_buildDayMap` method
4. **Screen A** (20 min) - Replace `_buildDayRouteMap` method
5. **Screen B** (30 min) - Optional full replacement

---

## 🚀 After Integration

Once all screens are updated:

1. **Deploy Cloud Function** (if not already):
   ```bash
   firebase deploy --only functions:getOutdoorPOIs
   ```

2. **Test on all platforms**:
   - Web (Chrome, Safari)
   - iOS (simulator + device)
   - Android (emulator + device)

3. **Gather user feedback**:
   - Is the visual hierarchy clear?
   - Are custom waypoints easy to identify?
   - Do OSM POIs provide helpful context without cluttering?

4. **Iterate if needed**:
   - Adjust marker sizes
   - Tweak opacity levels
   - Add/remove glow effects
   - Consider adding legend

---

## 💡 Future Enhancements

Consider these improvements:

### 1. Interactive Legend
Show users what marker types mean (first-time help)

### 2. Marker Clustering
Group nearby OSM POIs at low zoom levels to reduce clutter

### 3. POI Type Filtering
Let users toggle OSM POI types on/off (similar to map_screen.dart filter panel)

### 4. Offline POI Caching
Cache fetched OSM POIs for offline viewing

### 5. Custom Waypoint Badges
Add small badge to indicate waypoint ownership ("Mine", "John's", etc.)

### 6. Animated Interactions
Scale markers on tap, pulse selected marker

---

**All components compile successfully and are ready to integrate!** 

Follow the screen-by-screen guide above, test thoroughly, and enjoy your enhanced map system! 🗺️
