# Waypoint App Architecture

## Overview
Waypoint is a premium multi-day trekking and travel navigation app built with Flutter and Firebase. It provides offline-first navigation with curated premium plans and user-generated content.

## Tech Stack
- **Framework**: Flutter (cross-platform: iOS, Android, Web)
- **Backend**: Firebase (Authentication, Firestore)
- **Routing**: go_router
- **State Management**: Provider
- **Maps**: Mapbox WebGL (web) / Mapbox Native SDK (mobile) with flutter_map fallback

## Project Structure

### Data Layer
- **Models** (`lib/models/`)
  - `user_model.dart`: User profile with purchased/created plans
  - `plan_model.dart`: Plans, versions, itineraries, and stays
  
- **Services** (`lib/services/`)
  - `user_service.dart`: User CRUD operations and Firebase queries
  - `plan_service.dart`: Plan CRUD operations, filtering by featured/creator/purchased
  
- **Data** (`lib/data/`)
  - `mock_data.dart`: Sample plans for development/testing

### Authentication Layer (`lib/auth/`)
- `auth_manager.dart`: Abstract auth interface with mixins for different auth methods
- `firebase_auth_manager.dart`: Firebase implementation with email/password auth

### Presentation Layer (`lib/presentation/`)
- **Marketplace** (`marketplace/`): Browse and discover plans
- **My Trips** (`mytrips/`): User's purchased and created plans
- **Builder** (`builder/`): Create new custom plans
- **Profile** (`profile/`): User settings and account management
- **Details** (`details/`): Plan details with versions and itinerary
- **Map** (`map/`): Offline-capable navigation view
- **Widgets** (`widgets/`): Shared components like `plan_card.dart`

### Core Files
- `main.dart`: App initialization, Firebase setup
- `nav.dart`: go_router configuration with bottom tabs
- `theme.dart`: Premium design system (Montserrat + Inter, Deep Slate palette)

## Firebase Integration

### Collections
1. **users**
   - User profiles
   - Purchased plan IDs
   - Created plan IDs
   - Security: Private (owner-only access)

2. **plans**
   - All trek plans with versions and itineraries
   - Featured flag for curated content
   - Published flag for visibility control
   - Security: Public read for published, creator-only write

### Security Rules
- Users can only read/write their own profile
- Anyone can read published plans
- Only creators can modify their own plans
- Must be authenticated to create plans

### Indexes
- `plans`: `is_published + created_at` (descending)
- `plans`: `is_published + is_featured + created_at` (descending)
- `plans`: `creator_id + created_at` (descending)

## Key Features
1. **Plan Marketplace**: Browse featured and all plans
2. **Offline-First**: Download plans for offline use
3. **Custom Plans**: Users create and publish their own routes
4. **Premium Content**: Admin-curated €2 plans
5. **Detailed Itineraries**: Day-by-day breakdown with stays, distances, photos

## Navigation Flow
- Bottom tabs: Marketplace → My Trips → Builder → Profile
- Deep navigation: Marketplace → Plan Details → Map View
- Context actions: Empty state buttons navigate to relevant tabs

## Design System
- **Fonts**: Montserrat (headings), Inter (body)
- **Colors**: Deep Slate, Muted Terra Cotta, Clean Whites
- **Style**: Premium/Adventure aesthetic with generous whitespace
- **Components**: Material 3 with custom elevation and rounded corners

## Map System Architecture

### Overview
The Waypoint app uses a unified, adaptive map system that automatically selects the optimal rendering engine based on platform and configuration. All map implementations follow DRY principles with reusable components and consistent styling.

### Core Components

#### 1. AdaptiveMapWidget (`lib/features/map/adaptive_map_widget.dart`)
**Purpose**: Unified map widget that abstracts engine selection and provides consistent API across platforms.

**Engine Selection**:
- **Web**: Mapbox GL JS (WebGL) for vector rendering
- **iOS/Android**: Mapbox Native SDK for vector rendering with 3D terrain support
- **Fallback**: flutter_map with raster tiles (if Mapbox fails or for legacy compatibility)

**Key Features**:
- Automatic platform detection
- Graceful fallback to flutter_map
- Unified annotation and polyline rendering
- Consistent styling across all engines
- Performance optimized with lazy loading

**Usage Pattern**:
```dart
AdaptiveMapWidget(
  initialCenter: LatLng(lat, lng),
  configuration: MapConfiguration.mainMap(),
  annotations: [MapAnnotation.fromWaypoint(waypoint)],
  polylines: [MapPolyline(id: 'route', points: routePoints)],
  onMapCreated: (controller) {
    // Use controller for map operations
  },
)
```

#### 2. MapConfiguration (`lib/features/map/map_configuration.dart`)
**Purpose**: Declarative configuration factory for different map use cases.

**Available Configurations**:
- `MapConfiguration.mainMap()`: Full-featured map with 3D terrain (mobile) or WebGL (web)
- `MapConfiguration.preview()`: Lightweight preview map for cards and summaries
- `MapConfiguration.routeBuilder()`: Interactive map for route editing

**Benefits**:
- DRY: Single source of truth for map settings
- Type-safe: Compile-time validation
- Consistent: Same configuration produces same results across pages

#### 3. WaypointMapController (`lib/features/map/waypoint_map_controller.dart`)
**Purpose**: Unified API for map operations across all engines.

**Key Methods**:
- `animateCamera(center, zoom)`: Smooth camera transitions
- `addMarker(id, position, icon, color)`: Add custom markers
- `addRoutePolyline(points, color, width)`: Add route lines
- `fitBounds(points)`: Auto-fit to show all points

**Benefits**:
- Platform-agnostic: Same API works on web and mobile
- Engine-agnostic: Works with Mapbox and flutter_map
- Type-safe: Compile-time method validation

#### 4. MapAnnotation & MapPolyline (`lib/features/map/adaptive_map_widget.dart`)
**Purpose**: Unified data models for map features.

**MapAnnotation**:
- Represents markers (waypoints, POIs, route points)
- Factory methods: `fromWaypoint()`, `fromPOI()`
- Supports text labels (for A/B markers)
- Consistent styling across all engines

**MapPolyline**:
- Represents route lines
- Supports color, width, and border styling
- Automatic coordinate conversion

### Map Pages & Implementation

#### 1. Builder Page Preview Map
**File**: `lib/presentation/builder/builder_screen.dart`
**Method**: `_buildDayRouteMap()`
**Configuration**: `MapConfiguration.mainMap()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Shows all waypoints for a day
- Displays route polyline
- Auto-fits bounds to show all content
- Non-interactive preview

**Implementation Pattern**:
```dart
AdaptiveMapWidget(
  initialCenter: calculatedCenter,
  configuration: MapConfiguration.mainMap(
    styleUri: mapboxStyleUri,
    rasterTileUrl: defaultRasterTileUrl,
    enable3DTerrain: false, // Flat for preview
    initialZoom: 12.0,
  ),
  annotations: waypoints.map((wp) => MapAnnotation.fromWaypoint(wp)).toList(),
  polylines: [MapPolyline(id: 'route', points: routeCoordinates)],
  onMapCreated: (controller) {
    // Fit bounds after map is ready
    controller.animateCamera(boundsCenter, calculatedZoom);
  },
)
```

#### 2. Builder Page Route Builder
**File**: `lib/presentation/builder/route_builder_screen.dart`
**Method**: `_buildMapboxEditor()`
**Configuration**: `MapConfiguration.routeBuilder()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Interactive map for route editing
- Tap to add waypoints
- Drag markers to reposition
- OSM POI loading
- Custom waypoint markers
- Route preview polyline

**Implementation Pattern**:
```dart
AdaptiveMapWidget(
  initialCenter: cameraCenter,
  configuration: MapConfiguration.routeBuilder(),
  annotations: [
    // Route points (A/B)
    ...routePoints.map((p) => MapAnnotation(...)),
    // OSM POIs
    ...osmPOIs.map((poi) => MapAnnotation.fromPOI(poi)),
    // Custom waypoints
    ...customWaypoints.map((wp) => MapAnnotation.fromWaypoint(wp)),
  ],
  polylines: [MapPolyline(id: 'preview', points: previewRoute)],
  onTap: (position) => _handleMapTap(position),
  onMapCreated: (controller) => _mapController = controller,
)
```

#### 3. Plan Details Page Preview Map
**File**: `lib/presentation/details/plan_details_screen.dart`
**Widget**: `_DayMapWidget`
**Configuration**: `MapConfiguration.preview()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Shows all waypoints for a day
- Displays route polyline
- Start/End markers (A/B)
- Map controls (fit bounds, zoom in/out)
- Preserved with `AutomaticKeepAliveClientMixin`

**Implementation Pattern**:
```dart
AdaptiveMapWidget(
  initialCenter: initialCenter,
  configuration: MapConfiguration.preview(
    rasterTileUrl: defaultRasterTileUrl,
    initialZoom: initialZoom,
  ),
  annotations: [
    // Start marker (A)
    MapAnnotation(id: 'start', position: startPoint, icon: Icons.text_fields, label: 'A'),
    // End marker (B)
    MapAnnotation(id: 'end', position: endPoint, icon: Icons.text_fields, label: 'B'),
    // Waypoints
    ...waypoints.map((wp) => MapAnnotation.fromWaypoint(wp)),
  ],
  polylines: [MapPolyline(id: 'route', points: routeCoordinates)],
  onMapCreated: (controller) {
    _mapController = controller;
    _fitBounds(); // Fit to show all waypoints
  },
)
```

#### 4. Trip Details Page Preview Map
**File**: `lib/presentation/trips/trip_details_screen.dart`
**Widget**: `_TripDayMapWidget`
**Configuration**: `MapConfiguration.mainMap()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Conditional waypoint display:
  - All waypoints if owner OR no selections
  - Only selected waypoints if participant with selections
- Route polyline
- Start/End markers (A/B)
- Map controls (fit bounds, zoom in/out, fullscreen)
- Preserved with `AutomaticKeepAliveClientMixin`

**Implementation Pattern**:
```dart
AdaptiveMapWidget(
  initialCenter: initialCenter,
  configuration: MapConfiguration.mainMap(
    styleUri: mapboxStyleUri,
    rasterTileUrl: defaultRasterTileUrl,
    enable3DTerrain: false,
    initialZoom: initialZoom,
  ),
  annotations: _buildAnnotations(), // Filters waypoints based on selections
  polylines: [MapPolyline(id: 'route', points: routeCoordinates)],
  onMapCreated: (controller) {
    _mapController = controller;
    _fitBounds();
  },
)
```

#### 5. Fullscreen Trip Map Per Day
**File**: `lib/presentation/trips/trip_day_map_fullscreen.dart`
**Configuration**: `MapConfiguration.mainMap()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Full-screen map view
- All waypoints for the day
- Route polyline
- Interactive navigation
- Map controls

#### 6. Itinerary Day Screen Preview
**File**: `lib/presentation/itinerary/itinerary_day_screen.dart`
**Method**: `_buildStaticMapPreview()`
**Configuration**: `MapConfiguration.preview()`
**Engine**: Mapbox WebGL (web) / Mapbox Native (mobile)
**Features**:
- Static preview (non-interactive)
- Start/End markers (A/B)
- Route polyline
- Auto-fits bounds

### DRY Principles & Reusability

#### Shared Components

1. **MapAnnotation.fromWaypoint()**: Standardized waypoint marker creation
   - Consistent icon selection (`getWaypointIcon()`)
   - Consistent color scheme (`getWaypointColor()`)
   - Reusable across all map pages

2. **MapAnnotation.fromPOI()**: Standardized POI marker creation
   - Consistent OSM POI styling
   - Reusable for background context markers

3. **MapConfiguration Factories**: Single source of truth for map settings
   - `.mainMap()`: Full-featured maps
   - `.preview()`: Lightweight previews
   - `.routeBuilder()`: Interactive editing

4. **WaypointMapController**: Unified map operations
   - Same API across all pages
   - Platform-agnostic methods
   - Consistent behavior

#### Responsive Design

All map widgets are responsive and adapt to:
- **Screen size**: Desktop sidebar vs mobile bottom panel
- **Platform**: Web vs mobile rendering engines
- **Context**: Preview vs interactive vs fullscreen

**Example - Responsive Layout**:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isDesktop = constraints.maxWidth >= 1280;
    return isDesktop
      ? Row(children: [Sidebar(), Map()])  // Desktop layout
      : Column(children: [Map(), BottomPanel()]);  // Mobile layout
  },
)
```

### Performance Optimizations

1. **Lazy Loading**: Maps only initialize when visible
2. **Keep-Alive**: Preview maps use `AutomaticKeepAliveClientMixin` to preserve state
3. **Debounced Updates**: POI loading and camera updates are debounced
4. **Marker Clustering**: (Future enhancement) For large waypoint sets
5. **Tile Caching**: Offline tile support via `OfflineTilesManager`

### Styling Consistency

All custom markers follow the same visual style:
- **Size**: 22px diameter
- **Background**: White circle
- **Border**: 2px colored border
- **Icon**: 12px colored icon
- **Shadow**: Subtle drop shadow for depth

This ensures visual consistency between:
- Custom waypoints
- OSM POIs
- Mapbox native POIs (where possible)

### Error Handling

1. **Container Not Found**: Retry mechanism with exponential backoff
2. **Style Loading Failure**: Automatic fallback to standard Mapbox style
3. **Mapbox Initialization Failure**: Graceful fallback to flutter_map
4. **Network Issues**: Offline tile support for cached maps

### Migration Status

✅ **Completed Migrations**:
- Builder page preview map
- Route builder (via `_buildMapboxEditor()`)
- Plan details page (`_DayMapWidget`)
- Trip details page (`_TripDayMapWidget`)
- Itinerary day screen preview
- Fullscreen route map
- Trip day fullscreen map

✅ **All maps now use AdaptiveMapWidget** with Mapbox WebGL (web) and Mapbox Native (mobile)

### Future Enhancements

1. **Marker Clustering**: For maps with many waypoints
2. **Custom Map Styles**: User-selectable map themes
3. **3D Terrain Toggle**: User control for 3D terrain on mobile
4. **Offline Map Downloads**: Full offline map support
5. **Route Elevation Profile**: Integrated elevation visualization

## Next Steps for Firebase Integration
1. **Deploy Rules & Indexes**: User must deploy via Firebase panel
2. **Enable Authentication**: User must enable Email/Password auth in Firebase Console
3. **Replace Mock Data**: Update screens to use PlanService instead of mockPlans
4. **Add Auth UI**: Create login/signup screens with FirebaseAuthManager
5. **User State**: Add Provider for auth state management across app
