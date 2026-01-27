import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/web/web_map_controller.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';

/// Mapbox GL JS widget for web platform
/// Uses the same custom Mapbox style as mobile for visual consistency
class MapboxWebWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final void Function(WaypointMapController)? onMapCreated;

  const MapboxWebWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.onMapCreated,
  });

  @override
  State<MapboxWebWidget> createState() => _MapboxWebWidgetState();
}

class _MapboxWebWidgetState extends State<MapboxWebWidget> {
  late final String _viewId;
  WebMapController? _controller;
  bool _isMapReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewId = 'mapbox-map-${DateTime.now().millisecondsSinceEpoch}';
    _initializeMap();
  }

  void _initializeMap() {
    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _createMapContainer(),
    );
  }

  html.DivElement _createMapContainer() {
    final container = html.DivElement()
      ..id = _viewId
      ..style.width = '100%'
      ..style.height = '100%';

    // Inject Mapbox GL JS if not already present
    _injectMapboxScripts().then((_) {
      _createMap(container);
    }).catchError((e) {
      setState(() => _errorMessage = 'Failed to load Mapbox: $e');
    });

    return container;
  }

  Future<void> _injectMapboxScripts() async {
    // Check if Mapbox GL JS is already loaded
    if (js.context.hasProperty('mapboxgl')) {
      return;
    }

    // Add Mapbox GL CSS
    final cssLink = html.LinkElement()
      ..rel = 'stylesheet'
      ..href = 'https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.css';
    html.document.head!.append(cssLink);

    // Add Mapbox GL JS
    final scriptCompleter = Completer<void>();
    final script = html.ScriptElement()
      ..src = 'https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.js'
      ..onLoad.listen((_) => scriptCompleter.complete())
      ..onError.listen((e) => scriptCompleter.completeError('Script load failed'));
    html.document.head!.append(script);

    await scriptCompleter.future;

    // Set the access token
    js.context['mapboxgl']['accessToken'] = mapboxPublicToken;
  }

  void _createMap(html.DivElement container) {
    // Wait for container to be in DOM
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        final mapOptions = js.JsObject.jsify({
          'container': _viewId,
          // Use the SAME custom Mapbox style as mobile!
          'style': mapboxStyleUri,
          'center': [widget.initialCenter.longitude, widget.initialCenter.latitude],
          'zoom': widget.initialZoom,
          'pitch': widget.initialTilt,
          'bearing': widget.initialBearing,
          'attributionControl': true,
          'maxPitch': 85,
          // Enable 3D terrain
          'projection': 'globe',
        });

        // Create map
        final mapboxgl = js.context['mapboxgl'];
        final map = js.JsObject(mapboxgl['Map'], [mapOptions]);

        // Store map reference for later use
        js.context['waypointMap_$_viewId'] = map;

        // Set up event listeners
        map.callMethod('on', ['load', js.allowInterop(() {
          _onMapLoaded(map);
        })]);

        map.callMethod('on', ['error', js.allowInterop((e) {
          print('Mapbox error: ${e['error']?['message'] ?? e}');
        })]);

        map.callMethod('on', ['click', js.allowInterop((e) {
          final lngLat = e['lngLat'];
          _controller?.onMapTapped(lngLat['lat'], lngLat['lng']);
        })]);

        map.callMethod('on', ['move', js.allowInterop(() {
          _updateCameraState(map);
        })]);

        map.callMethod('on', ['moveend', js.allowInterop(() {
          _updateCameraState(map);
        })]);
      } catch (e) {
        setState(() => _errorMessage = 'Failed to create map: $e');
      }
    });
  }

  void _updateCameraState(js.JsObject map) {
    try {
      final center = map.callMethod('getCenter', []);
      final zoom = map.callMethod('getZoom', []);
      final bearing = map.callMethod('getBearing', []);
      final pitch = map.callMethod('getPitch', []);
      
      _controller?.onCameraChanged(
        (center['lat'] as num).toDouble(),
        (center['lng'] as num).toDouble(),
        (zoom as num).toDouble(),
        (bearing as num).toDouble(),
        (pitch as num).toDouble(),
      );
    } catch (e) {
      // Ignore camera update errors
    }
  }

  void _onMapLoaded(js.JsObject map) {
    setState(() => _isMapReady = true);

    // Enable 3D terrain (Mapbox terrain is included in Standard style)
    _enable3DTerrain(map);

    // Initialize controller with JS interop functions
    _controller = WebMapController();
    _controller!.initialize(
      setCamera: (lat, lng, zoom) {
        map.callMethod('jumpTo', [js.JsObject.jsify({
          'center': [lng, lat],
          'zoom': zoom,
        })]);
      },
      flyTo: (lat, lng, zoom, durationMs) {
        map.callMethod('flyTo', [js.JsObject.jsify({
          'center': [lng, lat],
          'zoom': zoom,
          'duration': durationMs,
          'essential': true,
        })]);
      },
      addRoute: (coordinates, color, width) {
        _addRouteToMap(map, coordinates, color, width);
      },
      removeRoute: () {
        _removeRouteFromMap(map);
      },
      addMarker: (id, lat, lng) {
        _addMarkerToMap(map, id, lat, lng);
      },
      removeMarker: (id) {
        _removeMarkerFromMap(id);
      },
      initialPosition: CameraPosition(
        center: widget.initialCenter,
        zoom: widget.initialZoom,
        bearing: widget.initialBearing,
        tilt: widget.initialTilt,
      ),
    );

    widget.onMapCreated?.call(_controller!);
  }

  void _enable3DTerrain(js.JsObject map) {
    try {
      // Mapbox Standard style already includes terrain configuration
      // We just need to ensure it's enabled
      
      // Check if terrain source exists, if not add it
      final style = map.callMethod('getStyle', []);
      if (style != null) {
        // Add terrain exaggeration for better 3D effect
        map.callMethod('setTerrain', [js.JsObject.jsify({
          'source': 'mapbox-dem',
          'exaggeration': 1.5,
        })]);
      }
    } catch (e) {
      // Terrain might already be configured in the style
      print('Terrain setup note: $e');
    }
  }

  void _addRouteToMap(js.JsObject map, List<List<double>> coordinates, int color, double width) {
    // Remove existing route first
    _removeRouteFromMap(map);

    // Convert color to hex (handle alpha channel)
    final hexColor = '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final alpha = ((color >> 24) & 0xFF) / 255.0;

    try {
      // Add source
      map.callMethod('addSource', ['waypoint-route', js.JsObject.jsify({
        'type': 'geojson',
        'data': {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
        },
      })]);

      // Add casing (outline) layer first
      map.callMethod('addLayer', [js.JsObject.jsify({
        'id': 'waypoint-route-casing',
        'type': 'line',
        'source': 'waypoint-route',
        'layout': {
          'line-join': 'round',
          'line-cap': 'round',
        },
        'paint': {
          'line-color': '#ffffff',
          'line-width': width + 3,
          'line-opacity': 0.8,
        },
      })]);

      // Add main route layer
      map.callMethod('addLayer', [js.JsObject.jsify({
        'id': 'waypoint-route-line',
        'type': 'line',
        'source': 'waypoint-route',
        'layout': {
          'line-join': 'round',
          'line-cap': 'round',
        },
        'paint': {
          'line-color': hexColor,
          'line-width': width,
          'line-opacity': alpha > 0 ? alpha : 0.9,
        },
      })]);
    } catch (e) {
      print('Failed to add route: $e');
    }
  }

  void _removeRouteFromMap(js.JsObject map) {
    try {
      // Check and remove layers
      final layers = ['waypoint-route-line', 'waypoint-route-casing'];
      for (final layerId in layers) {
        try {
          final layer = map.callMethod('getLayer', [layerId]);
          if (layer != null) {
            map.callMethod('removeLayer', [layerId]);
          }
        } catch (_) {}
      }
      
      // Remove source
      try {
        final source = map.callMethod('getSource', ['waypoint-route']);
        if (source != null) {
          map.callMethod('removeSource', ['waypoint-route']);
        }
      } catch (_) {}
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  final Map<String, js.JsObject> _markers = {};

  void _addMarkerToMap(js.JsObject map, String id, double lat, double lng) {
    // Remove existing marker with same ID
    _removeMarkerFromMap(id);

    try {
      final mapboxgl = js.context['mapboxgl'];
      
      // Create custom marker element
      final el = html.DivElement()
        ..className = 'waypoint-marker'
        ..style.width = '24px'
        ..style.height = '24px'
        ..style.borderRadius = '50%'
        ..style.border = '3px solid white'
        ..style.boxShadow = '0 2px 8px rgba(0,0,0,0.3)'
        ..style.cursor = 'pointer';

      if (id == 'user_location') {
        // Blue pulsing marker for user location
        el.style.backgroundColor = '#4285F4';
        el.style.animation = 'waypoint-pulse 2s infinite';
        el.style.width = '18px';
        el.style.height = '18px';
      } else {
        // Orange marker for other points
        el.style.backgroundColor = '#FF5722';
      }

      final marker = js.JsObject(mapboxgl['Marker'], [js.JsObject.jsify({
        'element': el,
        'anchor': 'center',
      })])
        ..callMethod('setLngLat', [js.JsObject.jsify([lng, lat])])
        ..callMethod('addTo', [map]);

      _markers[id] = marker;
    } catch (e) {
      print('Failed to add marker: $e');
    }
  }

  void _removeMarkerFromMap(String id) {
    final marker = _markers[id];
    if (marker != null) {
      try {
        marker.callMethod('remove', []);
      } catch (_) {}
      _markers.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: Colors.red.shade50,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  'Map Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        HtmlElementView(viewType: _viewId),
        
        // Loading overlay
        if (!_isMapReady)
          Container(
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading map...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up markers
    for (final marker in _markers.values) {
      try {
        marker.callMethod('remove', []);
      } catch (_) {}
    }
    _markers.clear();

    // Clean up map
    try {
      final map = js.context['waypointMap_$_viewId'];
      if (map != null) {
        map.callMethod('remove', []);
        js.context.deleteProperty('waypointMap_$_viewId');
      }
    } catch (_) {}

    _controller?.dispose();
    super.dispose();
  }
}
