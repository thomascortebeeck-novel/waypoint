# Waypoint Vector Map System

## Overview

Waypoint's adaptive map system provides **AllTrails/Komoot-quality vector tiles with 3D terrain** on all platforms, with seamless fallback to offline raster tiles. The system automatically switches between online and offline modes while preserving map state.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│          AdaptiveMapWidget (Auto-switching)         │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Online Mode              Offline Mode              │
│  ├─ Google Maps           ├─ flutter_map           │
│  ├─ Native/Web            ├─ Raster tiles          │
│  ├─ 3D terrain (1.5x)     ├─ Cached tiles          │
│  ├─ Sky layer             ├─ 2D flat map           │
│  └─ Smooth animations     └─ Basic animations      │
│                                                     │
│  WaypointMapController (Unified API)               │
│  ├─ VectorMapController                            │
│  └─ RasterMapController                            │
└─────────────────────────────────────────────────────┘
```

## Key Features

### 🗺️ **Online Mode (Vector)**
- **3D Terrain**: 1.5x exaggeration for dramatic mountain visualization
- **Vector Rendering**: Crisp labels at all zoom levels
- **Dynamic Hillshading**: Real-time lighting based on camera angle
- **Sky Layer**: Atmospheric horizon effect
- **Smooth Animations**: FlyTo camera movements
- **Pitch Control**: 0-60° tilt for 3D perspective
- **Bearing/Rotation**: Full 360° rotation

### 📴 **Offline Mode (Raster)**
- **Pre-cached Tiles**: Downloaded regions work without connectivity
- **Automatic Fallback**: Seamless switch when connection lost
- **Region Management**: Download by bounds or along routes
- **Storage Efficient**: User controls what to cache
- **Same API**: Identical controller interface

### 🔄 **Seamless Switching**
- Preserves camera position during mode transitions
- Maintains markers and routes
- Subtle "Offline Mode" indicator
- No user intervention required

## Usage

### Basic Implementation

```dart
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';

class MyMapScreen extends StatefulWidget {
  @override
  State<MyMapScreen> createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen> {
  WaypointMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdaptiveMapWidget(
        initialCenter: LatLng(61.0, 8.5), // Norway
        initialZoom: 12.0,
        initialTilt: 30.0, // 3D perspective
        onMapCreated: (controller) {
          _controller = controller;
          _setupMap();
        },
      ),
    );
  }

  void _setupMap() async {
    // Add route
    await _controller?.addRoutePolyline([
      LatLng(61.0, 8.5),
      LatLng(61.1, 8.6),
      LatLng(61.2, 8.7),
    ]);

    // Add markers
    await _controller?.addMarker('start', LatLng(61.0, 8.5));
    await _controller?.addMarker('end', LatLng(61.2, 8.7));

    // Listen to events
    _controller?.onMapTap.listen((position) {
      print('Tapped: $position');
    });
  }
}
```

### With Overlays and Controls

```dart
AdaptiveMapWidget(
  initialCenter: LatLng(61.0, 8.5),
  initialZoom: 12.0,
  onMapCreated: (controller) => _controller = controller,
  overlays: [
    // Back button
    Positioned(
      top: 50,
      left: 16,
      child: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.arrow_back),
      ),
    ),
    
    // Zoom controls
    Positioned(
      right: 16,
      top: 100,
      child: Column(
        children: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _zoomIn,
          ),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: _zoomOut,
          ),
        ],
      ),
    ),
  ],
)
```

## Controller API

### Camera Control

```dart
// Set camera instantly
await controller.setCamera(
  LatLng(61.0, 8.5),
  zoom: 14.0,
  bearing: 45.0,  // Rotation
  tilt: 60.0,     // 3D pitch (online only)
);

// Animate camera smoothly
await controller.animateCamera(
  LatLng(61.0, 8.5),
  zoom: 14.0,
  duration: Duration(seconds: 1),
);
```

### Route Management

```dart
// Add route
await controller.addRoutePolyline(
  [LatLng(61.0, 8.5), LatLng(61.1, 8.6)],
  color: Colors.blue,
  width: 5.0,
);

// Remove route
await controller.removeRoutePolyline();
```

### Marker Management

```dart
// Add marker
await controller.addMarker(
  'my_marker',
  LatLng(61.0, 8.5),
  customWidget: Icon(Icons.place, size: 40),
);

// Remove marker
await controller.removeMarker('my_marker');

// User location
await controller.setUserLocation(LatLng(61.0, 8.5), heading: 45.0);
```

### Event Streams

```dart
// Map tap events
controller.onMapTap.listen((position) {
  print('Tapped: ${position.latitude}, ${position.longitude}');
});

// Camera movements
controller.onCameraMove.listen((cameraPosition) {
  print('Zoom: ${cameraPosition.zoom}');
  print('Tilt: ${cameraPosition.tilt}');
  print('Bearing: ${cameraPosition.bearing}');
});
```

## Offline Region Management

### Download Region by Bounds

```dart
import 'package:waypoint/features/map/offline_region_manager.dart';

final manager = OfflineRegionManager();

// Estimate size first
final sizeMB = await manager.estimateRegionSize(
  southWest: LatLng(60.5, 8.0),
  northEast: LatLng(61.5, 9.0),
  minZoom: 8,
  maxZoom: 14,
);

print('Region will use approximately $sizeMB MB');

// Download region
await manager.downloadRegion(
  regionName: 'Jotunheimen National Park',
  southWest: LatLng(60.5, 8.0),
  northEast: LatLng(61.5, 9.0),
  minZoom: 8,
  maxZoom: 14,
  onProgress: (progress) {
    print('Download: ${(progress * 100).toStringAsFixed(0)}%');
  },
);
```

### Download Along Route

```dart
// Download 500m buffer along route
await manager.downloadRouteRegion(
  routeName: 'Besseggen Ridge',
  routePoints: routeCoordinates,
  bufferMeters: 500,
  minZoom: 10,
  maxZoom: 14,
  onProgress: (progress) {
    setState(() => _downloadProgress = progress);
  },
);
```

## Configuration

### Map engine

The app uses **Google Maps** for all map rendering (see `MapConfiguration` in `map_configuration.dart`; `engineType: MapEngineType.googleMaps`). Raster fallback tiles may still be sourced from `lib/integrations/mapbox_config.dart` for offline/flutter_map fallback.

### Connectivity Monitoring

Connectivity is automatically monitored via `connectivity_plus`. You can also manually check:

```dart
import 'package:waypoint/features/map/connectivity_service.dart';

final service = ConnectivityService();
await service.initialize();

// Current status
bool isOnline = service.isOnline;

// Listen to changes
service.connectivityStream.listen((isOnline) {
  print('Connection: ${isOnline ? "online" : "offline"}');
});
```

## Platform Support

| Platform | Vector Tiles | 3D Terrain | Offline Mode |
|----------|--------------|------------|--------------|
| iOS      | ✅ Yes       | ✅ Yes     | ✅ Yes       |
| Android  | ✅ Yes       | ✅ Yes     | ✅ Yes       |
| Web      | 🔄 Pending*  | 🔄 Pending | ✅ Yes       |

*Web uses Google Maps via google_maps_flutter_web.

## Performance Optimization

### Vector Tile Caching
- 7-day TTL
- 100MB max cache
- Automatic cleanup

### Raster Tile Strategy
- User-controlled regions only
- Efficient storage in IndexedDB (web) / SQLite (mobile)
- Lazy loading outside viewport

### Camera Debouncing
- Rapid movements are debounced
- Reduces unnecessary tile requests
- Improves battery life

## Troubleshooting

### "Map not rendering"
- Ensure Google Maps API key is configured for your platform (see project setup).
- For raster fallback, check tile URL configuration if used.

### "Offline mode not working"
- Verify tiles were downloaded successfully
- Check storage permissions on mobile
- Confirm tiles are within min/max zoom range

### "3D terrain not visible"
- Ensure you're in online mode (vector tiles)
- Set initial tilt: `initialTilt: 30.0`
- Zoom to level 10+ for best terrain visibility

## Examples

See `lib/presentation/map/map_screen.dart` and `lib/presentation/builder/route_builder_screen.dart` for examples with online/offline switching, route visualization, marker management, and map controls.

## Migration Guide

### From flutter_map

```dart
// Old (flutter_map only)
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(61.0, 8.5),
    initialZoom: 12.0,
  ),
  children: [
    TileLayer(urlTemplate: '...'),
    PolylineLayer(polylines: [...]),
    MarkerLayer(markers: [...]),
  ],
)

// New (adaptive with vector+offline)
AdaptiveMapWidget(
  initialCenter: LatLng(61.0, 8.5),
  initialZoom: 12.0,
  onMapCreated: (controller) {
    controller.addRoutePolyline([...]);
    controller.addMarker('id', LatLng(...));
  },
)
```

## License

Part of the Waypoint app. See main LICENSE file.
