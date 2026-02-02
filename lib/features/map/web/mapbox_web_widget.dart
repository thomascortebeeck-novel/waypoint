import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/web/web_map_controller.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';

/// Mapbox GL JS widget for web platform
/// Uses the same custom Mapbox style as mobile for visual consistency
class MapboxWebWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final void Function(WaypointMapController)? onMapCreated;
  final List<MapAnnotation> annotations;
  final List<MapPolyline> polylines;

  const MapboxWebWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.onMapCreated,
    this.annotations = const [],
    this.polylines = const [],
  });

  @override
  State<MapboxWebWidget> createState() => _MapboxWebWidgetState();
}

class _MapboxWebWidgetState extends State<MapboxWebWidget> {
  late final String _viewId;
  WebMapController? _controller;
  bool _isMapReady = false;
  String? _errorMessage;
  Timer? _loadTimeout;
  bool _usedFallbackStyle = false;
  js.JsObject? _mapInstance;
  
  // Fallback to Mapbox standard outdoors style if custom style fails
  static const _fallbackStyleUri = 'mapbox://styles/mapbox/outdoors-v12';

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
    debugPrint('🗺️ [MapboxWeb] Creating map container with ID: $_viewId');
    final container = html.DivElement()
      ..id = _viewId
      ..style.width = '100%'
      ..style.height = '100%';

    // Inject Mapbox GL JS if not already present
    _injectMapboxScripts().then((_) {
      debugPrint('🗺️ [MapboxWeb] Mapbox scripts loaded successfully');
      _createMap(container);
    }).catchError((e) {
      debugPrint('🗺️ [MapboxWeb] ERROR loading Mapbox scripts: $e');
      setState(() => _errorMessage = 'Failed to load Mapbox: $e');
    });

    return container;
  }

  Future<void> _injectMapboxScripts() async {
    // Check if Mapbox GL JS is already loaded
    if (js.context.hasProperty('mapboxgl')) {
      debugPrint('🗺️ [MapboxWeb] Mapbox GL JS already loaded, skipping injection');
      return;
    }
    
    debugPrint('🗺️ [MapboxWeb] Injecting Mapbox GL JS scripts...');

    // Add Mapbox GL CSS
    final cssLink = html.LinkElement()
      ..rel = 'stylesheet'
      ..href = 'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.css';
    html.document.head!.append(cssLink);

    // Add Mapbox GL JS
    final scriptCompleter = Completer<void>();
    final script = html.ScriptElement()
      ..src = 'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.js'
      ..onLoad.listen((_) => scriptCompleter.complete())
      ..onError.listen((e) => scriptCompleter.completeError('Script load failed'));
    html.document.head!.append(script);

    await scriptCompleter.future;

    // Set the access token
    js.context['mapboxgl']['accessToken'] = mapboxPublicToken;
  }

  void _createMap(html.DivElement container, {String? styleOverride}) {
    final styleToUse = styleOverride ?? mapboxStyleUri;
    
    debugPrint('🗺️ [MapboxWeb] _createMap called for container: $_viewId');
    
    // Wait for container to be in DOM
    Future.delayed(const Duration(milliseconds: 100), () {
      debugPrint('🗺️ [MapboxWeb] Starting map initialization after delay...');
      try {
        // DEBUG: Get device pixel ratio
        final devicePixelRatio = html.window.devicePixelRatio ?? 1;
        
        debugPrint('🗺️ Mapbox Web Debug Info:');
        debugPrint('  Style URI: $styleToUse');
        debugPrint('  Device Pixel Ratio: $devicePixelRatio');
        debugPrint('  Initial Zoom: ${widget.initialZoom}');
        debugPrint('  Container ID: $_viewId');
        
        // Cap pixelRatio at 2 to prevent zoom level mismatch on very high-DPI displays
        final cappedPixelRatio = devicePixelRatio > 2 ? 2 : devicePixelRatio;
        if (devicePixelRatio > 2) {
          debugPrint('  ⚠️ Pixel ratio capped from $devicePixelRatio to 2');
        }
        
        final mapOptions = js.JsObject.jsify({
          'container': _viewId,
          'style': styleToUse,
          'center': [widget.initialCenter.longitude, widget.initialCenter.latitude],
          'zoom': widget.initialZoom,
          'pitch': widget.initialTilt,
          'bearing': widget.initialBearing,
          'attributionControl': true,
          'maxPitch': 85,
          // Note: 'globe' projection removed - it can cause slow loading
          // and compatibility issues on some devices
          'pixelRatio': cappedPixelRatio,
        });

        // Create map
        final mapboxgl = js.context['mapboxgl'];
        final map = js.JsObject(mapboxgl['Map'], [mapOptions]);

        // Store map reference for later use
        js.context['waypointMap_$_viewId'] = map;
        _mapInstance = map;
        
        // Set up a timeout to detect style loading failures
        // Increased timeout to 15 seconds to account for slow connections
        _loadTimeout?.cancel();
        _loadTimeout = Timer(const Duration(seconds: 15), () {
          if (!_isMapReady && mounted) {
            debugPrint('⏱️ [MapboxWeb] Map load timeout after 15 seconds');
            if (!_usedFallbackStyle) {
              debugPrint('🔄 [MapboxWeb] Retrying with fallback style...');
              _usedFallbackStyle = true;
              _recreateMapWithFallback(container);
            } else {
              // Don't show error immediately - try to force refresh
              debugPrint('⚠️ [MapboxWeb] Fallback also timed out - map may still be loading');
              // Give it one more chance with a longer timeout
              _loadTimeout = Timer(const Duration(seconds: 10), () {
                if (!_isMapReady && mounted) {
                  setState(() => _errorMessage = 'Map failed to load. Please refresh the page.');
                }
              });
            }
          }
        });

        // Set up event listeners - both 'load' and 'style.load' for reliability
        // Note: Even though 'load' and 'idle' don't typically pass parameters,
        // we accept (e) to be safe - Mapbox may pass event objects in some contexts
        map.callMethod('on', ['load', js.allowInterop((e) {
          debugPrint('✅ [MapboxWeb] Map "load" event fired');
          _loadTimeout?.cancel();
          _onMapLoaded(map);
        })]);
        
        // Also listen to 'style.load' as a backup
        map.callMethod('on', ['style.load', js.allowInterop((e) {
          debugPrint('✅ [MapboxWeb] Style "style.load" event fired');
          if (!_isMapReady) {
            _loadTimeout?.cancel();
            _onMapLoaded(map);
          }
        })]);
        
        // Listen to 'idle' event as another confirmation
        map.callMethod('once', ['idle', js.allowInterop((e) {
          debugPrint('✅ [MapboxWeb] Map "idle" event fired');
          if (!_isMapReady) {
            _loadTimeout?.cancel();
            _onMapLoaded(map);
          }
        })]);

        // Handle style.error event for more specific error info
        map.callMethod('on', ['error', js.allowInterop((e) {
          final errorObj = e['error'];
          final errorMsg = errorObj?['message']?.toString() ?? e.toString();
          final errorType = errorObj?['type']?.toString() ?? 'unknown';
          
          debugPrint('Mapbox error [$errorType]: $errorMsg');
          
          // Check if this is a style-related error and we haven't tried fallback yet
          if (!_isMapReady && !_usedFallbackStyle && 
              (errorType == 'style' || 
               errorMsg.contains('style') || 
               errorMsg.contains('Bare objects') || 
               errorMsg.contains('image variant') ||
               errorMsg.contains('literal'))) {
            debugPrint('🔄 [MapboxWeb] Style error detected, switching to fallback...');
            debugPrint('   Custom style failed: $styleToUse');
            debugPrint('   Error details: $errorMsg');
            debugPrint('   💡 Fix your style in Mapbox Studio - see CUSTOM_STYLE_FIX_GUIDE.md');
            _loadTimeout?.cancel();
            _usedFallbackStyle = true;
            // Small delay to let current map cleanup
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isMapReady) {
                _recreateMapWithFallback(container);
              }
            });
          }
        })]);

        map.callMethod('on', ['click', js.allowInterop((e) {
          final lngLat = e['lngLat'];
          _controller?.onMapTapped(lngLat['lat'], lngLat['lng']);
        })]);

        map.callMethod('on', ['move', js.allowInterop((e) {
          if (_isMapReady) _updateCameraState(map);
        })]);

        map.callMethod('on', ['moveend', js.allowInterop((e) {
          if (_isMapReady) _updateCameraState(map);
        })]);
      } catch (e) {
        debugPrint('🗺️ [MapboxWeb] Exception creating map: $e');
        if (!_usedFallbackStyle) {
          _usedFallbackStyle = true;
          _recreateMapWithFallback(container);
        } else {
          setState(() => _errorMessage = 'Failed to create map: $e');
        }
      }
    });
  }
  
  void _recreateMapWithFallback(html.DivElement container) {
    debugPrint('🔄 [MapboxWeb] Starting fallback recreation...');
    
    // Clean up existing map thoroughly
    try {
      final existingMap = js.context['waypointMap_$_viewId'];
      if (existingMap != null) {
        debugPrint('🧹 [MapboxWeb] Removing existing map instance');
        existingMap.callMethod('remove', []);
        js.context.deleteProperty('waypointMap_$_viewId');
      }
    } catch (e) {
      debugPrint('⚠️ [MapboxWeb] Error removing existing map: $e');
    }
    
    // Clear the container's inner HTML to ensure clean state
    try {
      container.innerHtml = '';
    } catch (_) {}
    
    // Small delay to allow DOM cleanup before recreating
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      debugPrint('🗺️ [MapboxWeb] Creating map with fallback style: $_fallbackStyleUri');
      _createMap(container, styleOverride: _fallbackStyleUri);
    });
  }

  void _updateCameraState(js.JsObject map) {
    // Don't process camera updates until map is fully ready and controller exists
    if (!_isMapReady || _controller == null) return;
    
    try {
      final center = map.callMethod('getCenter', []);
      final zoom = map.callMethod('getZoom', []);
      final bearing = map.callMethod('getBearing', []);
      final pitch = map.callMethod('getPitch', []);
      
      // Safely extract values with null checks
      final lat = center?['lat'];
      final lng = center?['lng'];
      if (lat == null || lng == null || zoom == null) return;
      
      _controller?.onCameraChanged(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
        (zoom as num).toDouble(),
        (bearing as num?)?.toDouble() ?? 0.0,
        (pitch as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      // Ignore camera update errors - these can happen during rapid updates
    }
  }

  void _onMapLoaded(js.JsObject map) {
    setState(() => _isMapReady = true);

    // DEBUG: Log final zoom level after map loads
    final loadedZoom = map.callMethod('getZoom', []);
    final styleInfo = _usedFallbackStyle ? '(using fallback style)' : '(using custom style)';
    debugPrint('✅ Map loaded successfully at zoom: $loadedZoom $styleInfo');
    debugPrint('📍 [MapboxWeb] Map loaded with ${widget.annotations.length} annotations, ${widget.polylines.length} polylines');

    // Enable 3D terrain (Mapbox terrain is included in Standard style)
    _enable3DTerrain(map);
    
    // Add annotations and polylines after map is ready
    // Note: If annotations are empty now, they'll be added via didUpdateWidget when they arrive
    _updateAnnotations(map);
    _updatePolylines(map);
    
    // Also set up a listener to check for annotations that arrive later
    // This is a fallback in case didUpdateWidget doesn't fire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isMapReady && _mapInstance != null) {
        // Re-check annotations after a frame to catch any that were added
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _isMapReady && _mapInstance != null) {
            final currentCount = _markers.length;
            final expectedCount = widget.annotations.length;
            if (expectedCount > currentCount) {
              debugPrint('🔄 [MapboxWeb] Detected missing annotations: $currentCount markers vs $expectedCount expected');
              _updateAnnotations(_mapInstance!);
            }
          }
        });
      }
    });

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
      addMarker: (id, lat, lng, draggable) {
        _addMarkerToMap(map, id, lat, lng, draggable: draggable);
      },
      removeMarker: (id) {
        _removeMarkerFromMap(id);
      },
      setMarkerDraggable: (id, draggable) {
        _setMarkerDraggable(id, draggable);
      },
      updateMarkerPosition: (id, lat, lng) {
        _updateMarkerPosition(id, lat, lng);
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
      // Check if mapbox-dem source exists before enabling terrain
      final existingSource = map.callMethod('getSource', ['mapbox-dem']);
      
      if (existingSource == null) {
        // Add terrain source if not present in the style
        map.callMethod('addSource', ['mapbox-dem', js.JsObject.jsify({
          'type': 'raster-dem',
          'url': 'mapbox://mapbox.mapbox-terrain-dem-v1',
          'tileSize': 512,
          'maxzoom': 14,
        })]);
      }
      
      // Enable terrain with exaggeration
      map.callMethod('setTerrain', [js.JsObject.jsify({
        'source': 'mapbox-dem',
        'exaggeration': 1.5,
      })]);
      
      debugPrint('✅ 3D terrain enabled');
    } catch (e) {
      // Terrain setup failed - this is non-critical, map still works
      debugPrint('⚠️ Terrain setup skipped: $e');
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
      debugPrint('Failed to add route: $e');
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
  final Map<String, bool> _markerDraggableState = {};

  void _addMarkerToMap(js.JsObject map, String id, double lat, double lng, {bool draggable = false}) {
    // Remove existing marker with same ID
    _removeMarkerFromMap(id);

    try {
      final mapboxgl = js.context['mapboxgl'];
      
      // Create custom marker element
      final el = html.DivElement()
        ..className = 'waypoint-marker ${draggable ? 'draggable' : ''}'
        ..style.width = '24px'
        ..style.height = '24px'
        ..style.borderRadius = '50%'
        ..style.border = '3px solid white'
        ..style.boxShadow = '0 2px 8px rgba(0,0,0,0.3)'
        ..style.cursor = draggable ? 'move' : 'pointer';

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
        'draggable': draggable,
      })])
        ..callMethod('setLngLat', [js.JsObject.jsify([lng, lat])])
        ..callMethod('addTo', [map]);
      
      // Setup drag event listeners if draggable
      if (draggable) {
        marker.callMethod('on', ['dragstart', js.allowInterop((e) {
          _controller?.onMarkerDragStart(id, lat, lng);
        })]);
        
        marker.callMethod('on', ['drag', js.allowInterop((e) {
          final lngLat = marker.callMethod('getLngLat', []);
          _controller?.onMarkerDragging(id, lngLat['lat'], lngLat['lng']);
        })]);
        
        marker.callMethod('on', ['dragend', js.allowInterop((e) {
          final lngLat = marker.callMethod('getLngLat', []);
          _controller?.onMarkerDragEnd(id, lngLat['lat'], lngLat['lng']);
        })]);
      }

      _markers[id] = marker;
      _markerDraggableState[id] = draggable;
    } catch (e) {
      debugPrint('Failed to add marker: $e');
    }
  }
  
  void _setMarkerDraggable(String id, bool draggable) {
    final marker = _markers[id];
    if (marker != null) {
      try {
        marker.callMethod('setDraggable', [draggable]);
        _markerDraggableState[id] = draggable;
      } catch (e) {
        debugPrint('Failed to set marker draggable: $e');
      }
    }
  }
  
  void _updateMarkerPosition(String id, double lat, double lng) {
    final marker = _markers[id];
    if (marker != null) {
      try {
        marker.callMethod('setLngLat', [js.JsObject.jsify([lng, lat])]);
      } catch (e) {
        debugPrint('Failed to update marker position: $e');
      }
    }
  }

  void _removeMarkerFromMap(String id) {
    final marker = _markers[id];
    if (marker != null) {
      try {
        marker.callMethod('remove', []);
      } catch (_) {}
      _markers.remove(id);
      _markerDraggableState.remove(id);
    }
  }
  
  /// Update annotations on the map (called when annotations change)
  void _updateAnnotations(js.JsObject map) {
    if (!_isMapReady || map == null) {
      debugPrint('⚠️ [MapboxWeb] Cannot update annotations: map not ready or null');
      return;
    }
    
    debugPrint('📍 [MapboxWeb] Updating annotations: ${widget.annotations.length} total');
    
    // Remove all existing annotation markers (except user location)
    final annotationIds = widget.annotations.map((a) => a.id).toSet();
    final toRemove = _markers.keys.where((id) => !annotationIds.contains(id) && id != 'user_location').toList();
    for (final id in toRemove) {
      _removeMarkerFromMap(id);
    }
    
    // Add or update annotations
    int added = 0;
    int updated = 0;
    for (final annotation in widget.annotations) {
      // Convert icon to a simple colored circle for now
      // TODO: Support custom icons via icon images
      final colorHex = '#${(annotation.color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      
      // Check if marker already exists
      if (_markers.containsKey(annotation.id)) {
        _updateMarkerPosition(annotation.id, annotation.position.latitude, annotation.position.longitude);
        updated++;
      } else {
        _addAnnotationMarker(map, annotation, colorHex);
        added++;
      }
    }
    
    debugPrint('✅ [MapboxWeb] Annotations updated: $added added, $updated updated');
  }
  
  /// Add an annotation as a marker on the map
  void _addAnnotationMarker(js.JsObject map, MapAnnotation annotation, String colorHex) {
    try {
      final mapboxgl = js.context['mapboxgl'];
      if (mapboxgl == null) {
        debugPrint('❌ [MapboxWeb] mapboxgl not available');
        return;
      }
      
      // Create custom marker element with icon support
      // Align styling with Mapbox POI markers: use same size and style as Mapbox native POIs
      final el = html.DivElement()
        ..className = 'waypoint-annotation-marker'
        ..style.width = '28px' // Match Mapbox POI marker size
        ..style.height = '28px'
        ..style.borderRadius = '50%'
        ..style.backgroundColor = colorHex // Use POI type color (already aligned with Mapbox)
        ..style.border = '2px solid white' // Match Mapbox POI border style
        ..style.boxShadow = '0 2px 6px rgba(0,0,0,0.3)' // Match Mapbox POI shadow
        ..style.cursor = 'pointer'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.position = 'relative';
      
      // Add Material Icons font to display icon
      el.style.fontFamily = 'Material Icons';
      el.style.fontSize = '16px';
      el.style.color = 'white';
      el.style.fontWeight = 'normal';
      
      // Get icon codepoint from IconData
      final iconCodePoint = annotation.icon.codePoint;
      el.innerText = String.fromCharCode(iconCodePoint);
      
      // Add label text below icon if available (for waypoints, not POIs)
      if (annotation.label != null && annotation.label!.isNotEmpty && annotation.label != 'Unnamed') {
        // For waypoints with labels, show both icon and label
        // For POIs, we'll show just the icon (name appears on hover/tap)
        final labelEl = html.SpanElement()
          ..style.position = 'absolute'
          ..style.bottom = '-18px'
          ..style.left = '50%'
          ..style.transform = 'translateX(-50%)'
          ..style.fontSize = '10px'
          ..style.color = 'white'
          ..style.fontWeight = 'bold'
          ..style.textShadow = '0 1px 2px rgba(0,0,0,0.8)'
          ..style.whiteSpace = 'nowrap'
          ..style.fontFamily = 'sans-serif'
          ..innerText = annotation.label!;
        el.append(labelEl);
      }
      
      final marker = js.JsObject(mapboxgl['Marker'], [js.JsObject.jsify({
        'element': el,
        'anchor': 'center',
      })])
        ..callMethod('setLngLat', [js.JsObject.jsify([annotation.position.longitude, annotation.position.latitude])])
        ..callMethod('addTo', [map]);
      
      // Add click handler
      el.onClick.listen((e) {
        e.stopPropagation();
        annotation.onTap?.call();
      });
      
      _markers[annotation.id] = marker;
      _markerDraggableState[annotation.id] = false;
      debugPrint('✅ [MapboxWeb] Added marker: ${annotation.id} at ${annotation.position.latitude},${annotation.position.longitude}');
    } catch (e, stack) {
      debugPrint('❌ [MapboxWeb] Failed to add annotation marker ${annotation.id}: $e');
      debugPrint('Stack: $stack');
    }
  }
  
  /// Update polylines on the map
  void _updatePolylines(js.JsObject map) {
    if (!_isMapReady || map == null) return;
    
    // Remove existing route first (if any)
    _removeRouteFromMap(map);
    
    // Add new polylines (for now, only add the first one - can be extended for multiple)
    if (widget.polylines.isNotEmpty) {
      final polyline = widget.polylines.first;
      if (polyline.points.length >= 2) {
        // Convert LatLng points to [lng, lat] coordinates
        final coordinates = polyline.points.map((p) => [p.longitude, p.latitude]).toList();
        _addRouteToMap(map, coordinates, polyline.color.value, polyline.width);
      }
    }
  }
  
  @override
  void didUpdateWidget(MapboxWebWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    debugPrint('🔄 [MapboxWeb] didUpdateWidget called: annotations ${oldWidget.annotations.length} → ${widget.annotations.length}, polylines ${oldWidget.polylines.length} → ${widget.polylines.length}');
    
    // Update annotations if they changed (check by length and IDs to catch content changes)
    final annotationsChanged = widget.annotations.length != oldWidget.annotations.length ||
        widget.annotations.any((a) => !oldWidget.annotations.any((old) => old.id == a.id)) ||
        oldWidget.annotations.any((a) {
          final old = oldWidget.annotations.firstWhere((o) => o.id == a.id, orElse: () => a);
          return old.id != a.id || old.position != a.position;
        });
    
    if (annotationsChanged && _isMapReady && _mapInstance != null) {
      debugPrint('🔄 [MapboxWeb] Annotations changed: ${oldWidget.annotations.length} → ${widget.annotations.length}');
      _updateAnnotations(_mapInstance!);
    } else if (widget.annotations.length > 0 && _isMapReady && _mapInstance != null) {
      // Even if comparison says unchanged, if we have annotations and map is ready, ensure they're displayed
      final currentMarkerCount = _markers.length - (_markers.containsKey('user_location') ? 1 : 0);
      if (currentMarkerCount != widget.annotations.length) {
        debugPrint('🔄 [MapboxWeb] Marker count mismatch: $currentMarkerCount markers vs ${widget.annotations.length} annotations - syncing');
        _updateAnnotations(_mapInstance!);
      }
    }
    
    // Update polylines if they changed
    final polylinesChanged = widget.polylines.length != oldWidget.polylines.length ||
        widget.polylines.any((p) => !oldWidget.polylines.any((old) => old.id == p.id));
    
    if (polylinesChanged && _isMapReady && _mapInstance != null) {
      debugPrint('🔄 [MapboxWeb] Polylines changed: ${oldWidget.polylines.length} → ${widget.polylines.length}');
      _updatePolylines(_mapInstance!);
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
    // Cancel timeout timer
    _loadTimeout?.cancel();
    
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
