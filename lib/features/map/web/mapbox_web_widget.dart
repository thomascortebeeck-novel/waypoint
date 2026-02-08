import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/web/web_map_controller.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/utils/coordinate_extensions.dart';

/// Mapbox GL JS widget for web platform
/// Uses the same custom Mapbox style as mobile for visual consistency
class MapboxWebWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final void Function(WaypointMapController)? onMapCreated;
  final Function(LatLng)? onTap; // Added: map tap callback
  final List<MapAnnotation> annotations;
  final List<MapPolyline> polylines;

  const MapboxWebWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.onMapCreated,
    this.onTap, // Added: map tap callback
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
  final Map<String, js.JsObject> _markers = {};
  final Map<String, bool> _markerDraggableState = {};
  final Map<String, html.Element> _markerElements = {}; // Track HTML elements for proper cleanup
  final Map<String, StreamSubscription<html.MouseEvent>> _markerClickSubscriptions = {}; // Track event listeners
  
  /// CRITICAL: Track when interactions are disabled to block ALL events including clicks
  /// This prevents map clicks from triggering popups when dialogs are open
  bool _interactionsDisabled = false;
  
  /// Map IconData codePoints to Material Icons names for CDN usage
  String _getMaterialIconName(IconData icon) {
    // Map common Material Icons to their names for CDN usage
    // These are the most common icons used in waypoints and POIs
    const iconNames = {
      0xe53f: 'hotel',                    // Icons.hotel (accommodation)
      0xe56c: 'restaurant',               // Icons.restaurant
      0xe549: 'local_dining',             // Icons.local_dining
      0xe88a: 'local_activity',          // Icons.local_activity
      0xe8f4: 'visibility',              // Icons.visibility (viewing point)
      0xe55f: 'place',                    // Icons.place
      0xe567: 'local_convenience_store',  // Icons.local_convenience_store
      0xe55e: 'navigation',               // Icons.navigation
      0xe1db: 'cabin',                    // Icons.cabin
      0xe587: 'cottage',                  // Icons.cottage
      0xe577: 'landscape',                // Icons.landscape
      0xe598: 'water_drop',               // Icons.water_drop
      0xe1fe: 'roofing',                  // Icons.roofing
      0xe54c: 'local_parking',            // Icons.local_parking
      0xe52a: 'hiking',                   // Icons.hiking
      0xe556: 'outdoor_grill',            // Icons.outdoor_grill
      0xe63e: 'wc',                       // Icons.wc
      0xe88e: 'info',                     // Icons.info
      0xe565: 'terrain',                  // Icons.terrain
      0xe56d: 'water',                    // Icons.water
      0xe87a: 'explore',                  // Icons.explore
      0xe616: 'event_seat',               // Icons.event_seat
      0xe86d: 'shield',                   // Icons.shield
      0xe0cd: 'phone_in_talk',            // Icons.phone_in_talk
      0xe569: 'signpost',                 // Icons.signpost
    };
    
    return iconNames[icon.codePoint] ?? 'place'; // Default to 'place' if not found
  }
  
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
      // Still ensure Material Icons font is loaded
      await _ensureMaterialIconsLoaded();
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
    
    // CRITICAL: Inject and WAIT for Material Icons font
    await _ensureMaterialIconsLoaded();
  }

  /// Ensure Material Icons font is loaded and ready
  Future<void> _ensureMaterialIconsLoaded() async {
    if (html.document.getElementById('material-icons-font') == null) {
      final fontLink = html.LinkElement()
        ..id = 'material-icons-font'
        ..rel = 'stylesheet'
        ..href = 'https://fonts.googleapis.com/icon?family=Material+Icons';
      html.document.head!.append(fontLink);
      debugPrint('📝 [MapboxWeb] Material Icons stylesheet injected');
    }
    
    // Wait for the font to actually load using the document.fonts API
    try {
      // Use JavaScript interop to access document.fonts.ready
      final fontsReady = js.context['document']['fonts']['ready'];
      if (fontsReady != null) {
        await js.context.callMethod('eval', ['''
          new Promise((resolve) => {
            document.fonts.ready.then(() => {
              // Double-check Material Icons is loaded
              if (document.fonts.check('12px "Material Icons"')) {
                console.log('✅ Material Icons font loaded');
                resolve(true);
              } else {
                // Font might still be loading, wait a bit more
                setTimeout(() => {
                  console.log('⏳ Material Icons font check after delay');
                  resolve(true);
                }, 500);
              }
            });
          })
        ''']);
        debugPrint('✅ [MapboxWeb] Material Icons font ready');
      }
    } catch (e) {
      // Fallback: just wait a fixed time for font to load
      debugPrint('⚠️ [MapboxWeb] Font ready API not available, using fallback delay: $e');
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void _createMap(html.DivElement container, {String? styleOverride}) {
    final styleToUse = styleOverride ?? mapboxStyleUri;
    
    debugPrint('🗺️ [MapboxWeb] _createMap called for container: $_viewId');
    
    // Wait for container to be in DOM with retry mechanism
    _waitForContainerInDOM(attempt: 1, maxAttempts: 10, styleToUse: styleToUse);
  }

  void _waitForContainerInDOM({required int attempt, required int maxAttempts, required String styleToUse}) {
    if (attempt > maxAttempts) {
      debugPrint('🗺️ [MapboxWeb] Container not found after $maxAttempts attempts');
      setState(() => _errorMessage = 'Failed to create map: Container not found in DOM');
      return;
    }

    // Check if container exists in DOM
    final containerElement = html.document.getElementById(_viewId);
    
    if (containerElement == null) {
      // Container not in DOM yet, retry after delay
      final delay = Duration(milliseconds: 50 * attempt); // Exponential backoff
      debugPrint('🗺️ [MapboxWeb] Container $_viewId not found in DOM (attempt $attempt/$maxAttempts), retrying in ${delay.inMilliseconds}ms...');
      Future.delayed(delay, () {
        if (mounted) {
          _waitForContainerInDOM(attempt: attempt + 1, maxAttempts: maxAttempts, styleToUse: styleToUse);
        }
      });
      return;
    }

    // Container found, proceed with map creation
    debugPrint('🗺️ [MapboxWeb] Container $_viewId found in DOM, creating map...');
    
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
      
      // CRITICAL: Initialize interaction flag in JS context for click handler access
      // This ensures the click handler can always read the current flag value
      js.context['_interactionsDisabled_$_viewId'] = false;
      
      // Set up a timeout to detect style loading failures
      // Increased timeout to 15 seconds to account for slow connections
      _loadTimeout?.cancel();
      _loadTimeout = Timer(const Duration(seconds: 15), () {
        if (!_isMapReady && mounted) {
          debugPrint('⏱️ [MapboxWeb] Map load timeout after 15 seconds');
          if (!_usedFallbackStyle) {
            debugPrint('🔄 [MapboxWeb] Retrying with fallback style...');
            _usedFallbackStyle = true;
            final containerElement = html.document.getElementById(_viewId);
            if (containerElement != null && containerElement is html.DivElement) {
              _recreateMapWithFallback(containerElement);
            } else {
              debugPrint('🗺️ [MapboxWeb] Container not found for timeout fallback');
              _waitForContainerInDOM(attempt: 1, maxAttempts: 5, styleToUse: _fallbackStyleUri);
            }
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
              final containerEl = html.document.getElementById(_viewId);
              if (containerEl != null && containerEl is html.DivElement) {
                _recreateMapWithFallback(containerEl);
              } else {
                debugPrint('🗺️ [MapboxWeb] Container not found for error fallback');
                _waitForContainerInDOM(attempt: 1, maxAttempts: 5, styleToUse: _fallbackStyleUri);
              }
            }
          });
        }
      })]);

      // CRITICAL: Create a closure that captures the flag reference correctly
      // Store the flag in a way that the JS interop can access it
      js.context['_interactionsDisabled_$_viewId'] = false;
      
      map.callMethod('on', ['click', js.allowInterop((e) {
        // CRITICAL: Block ALL click events when interactions are disabled
        // This prevents map taps from triggering popups when dialogs are open
        // Check this FIRST before any other logic
        // Access flag from JS context to ensure we get the current value
        final isDisabled = js.context['_interactionsDisabled_$_viewId'] as bool? ?? false;
        if (isDisabled) {
          debugPrint('🚫 [MapboxWeb] Click BLOCKED - interactions are disabled (dialog open)');
          return;
        }
        
        // CRITICAL: Ignore clicks on map controls (zoom buttons, etc.)
        // Check if the click target is a control element
        // Safely access originalEvent - it might be a JsObject or null
        try {
          final originalEvent = e['originalEvent'];
          if (originalEvent != null && originalEvent is js.JsObject) {
            final target = originalEvent['target'];
            if (target != null && target is js.JsObject) {
              final className = (target['className'] as js.JsObject?)?.toString() ?? '';
              final tagName = (target['tagName'] as js.JsObject?)?.toString() ?? '';
              final id = (target['id'] as js.JsObject?)?.toString() ?? '';
              
              // Ignore clicks on mapbox control elements
              if (className.contains('mapboxgl-ctrl') || 
                  className.contains('mapboxgl-control') ||
                  tagName == 'BUTTON' ||
                  id.contains('zoom') ||
                  id.contains('control')) {
                debugPrint('📍 [MapboxWeb] Ignoring click on map control element');
                return; // Don't trigger map tap
              }
            }
          }
        } catch (err) {
          // If we can't check the target, proceed with the click
          // This is safer than blocking all clicks
          debugPrint('⚠️ [MapboxWeb] Could not check click target: $err');
        }
        
        final lngLat = e['lngLat'];
        final lat = (lngLat['lat'] as num?)?.toDouble();
        final lng = (lngLat['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final position = LatLng(lat, lng);
          // Forward to controller stream (for internal use)
          _controller?.onMapTapped(lat, lng);
          // Forward to widget callback (for AdaptiveMapWidget)
          widget.onTap?.call(position);
          debugPrint('📍 [MapboxWeb] Map tapped at: $lat, $lng');
        }
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
        final containerEl = html.document.getElementById(_viewId);
        if (containerEl != null && containerEl is html.DivElement) {
          _recreateMapWithFallback(containerEl);
        } else {
          debugPrint('🗺️ [MapboxWeb] Container element not found or not a DivElement, retrying...');
          _waitForContainerInDOM(attempt: 1, maxAttempts: 5, styleToUse: _fallbackStyleUri);
        }
      } else {
        setState(() => _errorMessage = 'Failed to create map: $e');
      }
    }
  }
  
  void _recreateMapWithFallback(html.Element container) {
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
      if (container is html.DivElement) {
        container.innerHtml = '';
      }
    } catch (_) {}
    
    // Small delay to allow DOM cleanup before recreating
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      debugPrint('🗺️ [MapboxWeb] Creating map with fallback style: $_fallbackStyleUri');
      // Find container in DOM again
      final containerElement = html.document.getElementById(_viewId);
      if (containerElement != null && containerElement is html.DivElement) {
        _createMap(containerElement, styleOverride: _fallbackStyleUri);
      } else {
        debugPrint('🗺️ [MapboxWeb] Container not found for fallback, retrying...');
        _waitForContainerInDOM(attempt: 1, maxAttempts: 5, styleToUse: _fallbackStyleUri);
      }
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
    
    // Hide Mapbox native POI labels to prevent duplicates with our custom markers
    _hideNativePOILabels(map);
    
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
      setScrollZoomEnabled: (enabled) {
        try {
          // Disable/enable scroll zoom on Mapbox GL JS
          // scrollZoom is a property, not a method - access it first, then call enable/disable
          final scrollZoom = map['scrollZoom'];
          if (scrollZoom != null && scrollZoom is js.JsObject) {
            if (enabled) {
              scrollZoom.callMethod('enable', []);
            } else {
              scrollZoom.callMethod('disable', []);
            }
          }
        } catch (e) {
          debugPrint('⚠️ [MapboxWeb] Failed to ${enabled ? "enable" : "disable"} scroll zoom: $e');
        }
      },
      disableInteractions: () {
        // CRITICAL: Set flag FIRST in both Dart and JS context to immediately block click events
        // This ensures clicks are blocked even before CSS/JS handlers are disabled
        _interactionsDisabled = true;
        js.context['_interactionsDisabled_$_viewId'] = true;
        debugPrint('🚫 [MapboxWeb] Interactions DISABLED - blocking all map events');
        
        try {
          // Disable ALL map interactions via JavaScript interop
          // This prevents scroll zoom, drag pan, click, keyboard, etc.
          // Use the same pattern as setScrollZoomEnabled which we know works
          final handlers = [
            'scrollZoom',
            'dragPan',
            'dragRotate',
            'doubleClickZoom',
            'touchZoomRotate',
            'touchPitch',
            'keyboard',
            'boxZoom',
          ];
          
          for (final handler in handlers) {
            try {
              // Mapbox GL JS handlers are properties, not methods
              // Access the handler property first, then call disable() on it
              // Use bracket notation to access property
              final handlerObj = map[handler];
              if (handlerObj != null && handlerObj is js.JsObject) {
                handlerObj.callMethod('disable', []);
              }
            } catch (e) {
              // Some handlers might not exist in all Mapbox versions, continue
              debugPrint('⚠️ [MapboxWeb] Handler $handler not available: $e');
            }
          }
          
          // Set CSS pointer-events to none on ALL Mapbox containers as backup
          // This ensures click/tap events can't reach the map even if JS handlers fail
          final selectors = [
            '.mapboxgl-map',
            '.mapboxgl-canvas-container',
            '.mapboxgl-canvas',
          ];
          
          // Try to find containers within our specific viewId first
          final containerElement = html.document.getElementById(_viewId);
          if (containerElement != null) {
            for (final selector in selectors) {
              final elements = containerElement.querySelectorAll(selector);
              for (final element in elements) {
                if (element is html.HtmlElement) {
                  element.style.pointerEvents = 'none';
                }
              }
            }
          }
          
          // Fallback: set on all Mapbox containers globally
          for (final selector in selectors) {
            final elements = html.document.querySelectorAll(selector);
            for (final element in elements) {
              if (element is html.HtmlElement) {
                element.style.pointerEvents = 'none';
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [MapboxWeb] Failed to disable interactions: $e');
        }
      },
      enableInteractions: () {
        // CRITICAL: Clear flag in both Dart and JS context to allow click events again
        _interactionsDisabled = false;
        js.context['_interactionsDisabled_$_viewId'] = false;
        debugPrint('✅ [MapboxWeb] Interactions ENABLED - allowing all map events');
        
        try {
          // Re-enable ALL map interactions via JavaScript interop
          final handlers = [
            'scrollZoom',
            'dragPan',
            'dragRotate',
            'doubleClickZoom',
            'touchZoomRotate',
            'touchPitch',
            'keyboard',
            'boxZoom',
          ];
          
          for (final handler in handlers) {
            try {
              // Mapbox GL JS handlers are properties, not methods
              // Access the handler property first, then call enable() on it
              final handlerObj = map[handler];
              if (handlerObj != null && handlerObj is js.JsObject) {
                handlerObj.callMethod('enable', []);
              }
            } catch (e) {
              // Some handlers might not exist in all Mapbox versions, continue
              debugPrint('⚠️ [MapboxWeb] Handler $handler not available: $e');
            }
          }
          
          // Re-enable CSS pointer-events on ALL Mapbox containers
          final selectors = [
            '.mapboxgl-map',
            '.mapboxgl-canvas-container',
            '.mapboxgl-canvas',
          ];
          
          // Try to find containers within our specific viewId first
          final containerElement = html.document.getElementById(_viewId);
          if (containerElement != null) {
            for (final selector in selectors) {
              final elements = containerElement.querySelectorAll(selector);
              for (final element in elements) {
                if (element is html.HtmlElement) {
                  element.style.pointerEvents = 'auto';
                }
              }
            }
          }
          
          // Fallback: re-enable on all Mapbox containers globally
          for (final selector in selectors) {
            final elements = html.document.querySelectorAll(selector);
            for (final element in elements) {
              if (element is html.HtmlElement) {
                element.style.pointerEvents = 'auto';
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [MapboxWeb] Failed to enable interactions: $e');
        }
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

  /// Hide Mapbox's native POI labels to prevent duplicates with custom waypoints
  void _hideNativePOILabels(js.JsObject map) {
    try {
      // Get all layers in the style
      final style = map.callMethod('getStyle', []);
      if (style == null) return;
      
      final layers = style['layers'] as List?;
      if (layers == null) return;
      
      // Hide layers that contain POI labels
      // Common Mapbox POI layer patterns: poi-label, poi_label, transit-label (for places)
      final poiLayerPatterns = ['poi-label', 'poi_label', 'transit-label'];
      
      for (final layer in layers) {
        final layerId = layer['id']?.toString() ?? '';
        
        // Check if this is a POI-related layer
        for (final pattern in poiLayerPatterns) {
          if (layerId.contains(pattern)) {
            try {
              map.callMethod('setLayoutProperty', [layerId, 'visibility', 'none']);
              debugPrint('🙈 [MapboxWeb] Hidden native POI layer: $layerId');
            } catch (e) {
              // Layer might not exist or not support visibility
            }
            break;
          }
        }
      }
      
      debugPrint('✅ [MapboxWeb] Native POI labels hidden');
    } catch (e) {
      debugPrint('⚠️ [MapboxWeb] Could not hide native POI labels: $e');
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
        ..callMethod('setLngLat', [js.JsObject.jsify(LatLng(lat, lng).toLngLat())]) // Use extension
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
        final position = LatLng(lat, lng);
        // Validate coordinates before updating
        if (!position.isValid) {
          debugPrint('❌ [MapboxWeb] Invalid coordinates for marker $id: lat=$lat, lng=$lng');
          return;
        }
        
        // Get current marker position to check if update is actually needed
        try {
          final currentLngLat = marker.callMethod('getLngLat', []);
          final currentLng = (currentLngLat['lng'] as num?)?.toDouble();
          final currentLat = (currentLngLat['lat'] as num?)?.toDouble();
          
          // Only update if position actually changed (more than 1 meter)
          if (currentLat != null && currentLng != null) {
            final distance = _calculateDistance(
              LatLng(currentLat, currentLng),
              position,
            );
            if (distance <= 0.001) { // Less than 1 meter - no update needed
              debugPrint('📍 [MapboxWeb] Marker $id position unchanged (${distance * 1000}m), skipping update');
              return;
            }
          }
        } catch (e) {
          // If we can't get current position, proceed with update
          debugPrint('⚠️ [MapboxWeb] Could not get current position for $id, updating anyway: $e');
        }
        
        // CRITICAL: Mapbox uses [lng, lat] format (GeoJSON standard)
        // Update marker in place (don't recreate) to prevent visual glitches
        // Use extension method for consistency
        marker.callMethod('setLngLat', [js.JsObject.jsify(position.toLngLat())]);
        debugPrint('✅ [MapboxWeb] Updated marker $id position to: $lat, $lng');
      } catch (e, stack) {
        debugPrint('❌ [MapboxWeb] Failed to update marker position for $id: $e');
        debugPrint('Stack: $stack');
      }
    } else {
      debugPrint('⚠️ [MapboxWeb] Marker $id not found for position update');
    }
  }

  void _removeMarkerFromMap(String id) {
    final marker = _markers[id];
    if (marker != null) {
      // CRITICAL: Cleanup order matters - do this in the correct sequence:
      
      // 1. Cancel subscription first to prevent any pending events
      final subscription = _markerClickSubscriptions[id];
      if (subscription != null) {
        subscription.cancel();
        _markerClickSubscriptions.remove(id);
      }
      
      // 2. Remove JS marker from map
      try {
        marker.callMethod('remove', []);
      } catch (e) {
        debugPrint('⚠️ [MapboxWeb] Error removing marker $id from map: $e');
      }
      
      // 3. Remove HTML element from DOM
      final element = _markerElements[id];
      if (element != null) {
        try {
          element.remove(); // Remove from DOM
        } catch (e) {
          debugPrint('⚠️ [MapboxWeb] Error removing element for marker $id: $e');
        }
        _markerElements.remove(id);
      }
      
      // 4. Clear state maps
      _markers.remove(id);
      _markerDraggableState.remove(id);
      
      debugPrint('🗑️ [MapboxWeb] Fully removed marker: $id');
    }
  }
  
  /// Update annotations on the map (called when annotations change)
  void _updateAnnotations(js.JsObject map) {
    if (!_isMapReady || map == null) {
      debugPrint('⚠️ [MapboxWeb] Cannot update annotations: map not ready or null');
      return;
    }
    
    debugPrint('📍 [MapboxWeb] Updating annotations: ${widget.annotations.length} total');
    
    // Remove markers that are no longer in the annotations list (except user location)
    final annotationIds = widget.annotations.map((a) => a.id).toSet();
    final toRemove = _markers.keys.where((id) => !annotationIds.contains(id) && id != 'user_location').toList();
    for (final id in toRemove) {
      _removeMarkerFromMap(id);
      debugPrint('🗑️ [MapboxWeb] Removed marker: $id');
    }
    
    // Add or update annotations
    int added = 0;
    int updated = 0;
    int skipped = 0;
    for (final annotation in widget.annotations) {
      // Validate annotation has valid position using extension
      if (!annotation.position.isValid) {
        debugPrint('⚠️ [MapboxWeb] Skipping annotation ${annotation.id} with invalid coordinates: lat=${annotation.position.latitude}, lng=${annotation.position.longitude}');
        skipped++;
        continue;
      }
      
      // Convert icon to a simple colored circle for now
      // TODO: Support custom icons via icon images
      final colorHex = '#${(annotation.color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      
      // Check if marker already exists - UPDATE IN PLACE to prevent visual glitches
      if (_markers.containsKey(annotation.id)) {
        // Check if position actually changed before updating (avoid unnecessary updates)
        final existingMarker = _markers[annotation.id];
        if (existingMarker != null) {
          try {
            // Get current marker position from Mapbox
            final currentLngLat = existingMarker.callMethod('getLngLat', []);
            final currentLng = (currentLngLat['lng'] as num?)?.toDouble();
            final currentLat = (currentLngLat['lat'] as num?)?.toDouble();
            
            // Only update if position changed significantly (> 1 meter)
            // This prevents markers from jumping around on zoom changes
            if (currentLat != null && currentLng != null) {
              final distance = _calculateDistance(
                LatLng(currentLat, currentLng),
                annotation.position,
              );
              if (distance > 0.001) { // 1 meter threshold
                // Position changed - update it
                _updateMarkerPosition(annotation.id, annotation.position.latitude, annotation.position.longitude);
                updated++;
              } else {
                // Position hasn't changed, skip update (marker stays at fixed lat/lng)
                skipped++;
              }
            } else {
              // Can't get current position, update anyway (shouldn't happen normally)
              _updateMarkerPosition(annotation.id, annotation.position.latitude, annotation.position.longitude);
              updated++;
            }
          } catch (e) {
            // If we can't get current position, update anyway (fallback)
            _updateMarkerPosition(annotation.id, annotation.position.latitude, annotation.position.longitude);
            updated++;
          }
        }
      } else {
        // Create new marker
        _addAnnotationMarker(map, annotation, colorHex);
        added++;
      }
    }
    
    debugPrint('✅ [MapboxWeb] Annotations updated: $added added, $updated updated, $skipped skipped');
  }
  
  /// Calculate distance between two points in kilometers
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371; // km
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
  
  /// Add an annotation as a marker on the map
  void _addAnnotationMarker(js.JsObject map, MapAnnotation annotation, String colorHex) {
    try {
      final mapboxgl = js.context['mapboxgl'];
      if (mapboxgl == null) {
        debugPrint('❌ [MapboxWeb] mapboxgl not available');
        return;
      }
      
      // Check if this is a start/end marker (single character label like "A" or "B")
      final isStartEndMarker = annotation.label != null && 
          annotation.label!.length == 1 && 
          (annotation.label == 'A' || annotation.label == 'B');
      
      // Create custom marker element with icon support
      // Use annotation size: start/end = 40px, waypoints = 28px, POIs = 22px
      // Note: position is NOT set on the outer element - Mapbox handles marker positioning internally
      // Setting position: 'relative' can interfere with Mapbox's positioning system
      final markerSize = isStartEndMarker 
          ? 40.0 
          : (annotation.markerSize ?? 22.0);
      final iconSize = isStartEndMarker 
          ? 18.0 
          : (annotation.iconSize ?? 12.0);
      final borderWidth = isStartEndMarker 
          ? 3.0 
          : (markerSize == 28.0 ? 2.5 : 2.0); // Thicker border for waypoints
      
      final el = html.DivElement()
        ..className = 'waypoint-annotation-marker'
        ..style.width = '${markerSize}px'
        ..style.height = '${markerSize}px'
        ..style.cursor = 'pointer'
        ..style.pointerEvents = 'auto'; // Marker can receive clicks (for onTap)
      
      // Custom waypoints (markerSize == 28) should appear above Mapbox native POIs
      if (markerSize == 28.0) {
        el.style.zIndex = '1000';
        el.style.position = 'relative'; // Required for z-index to work
      }
      
      // Create inner container for icon and label (allows label positioning without interfering with Mapbox)
      // Match Mapbox native POI style: colored background with white icon and white border
      final innerContainer = html.DivElement()
        ..style.position = 'relative' // Position relative for label absolute positioning
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '50%'
        ..style.backgroundColor = colorHex // Colored background like Mapbox native POIs
        ..style.border = '${borderWidth}px solid white' // White border (2px for POIs, 2.5px for waypoints)
        ..style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)' // Subtle shadow like Mapbox
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center';
      
      if (isStartEndMarker) {
        // For start/end markers: show text inside circle (larger, white text on colored background)
        innerContainer.style.backgroundColor = colorHex; // Colored background for start/end
        innerContainer.style.border = '${borderWidth}px solid white'; // White border
        innerContainer.style.width = '${markerSize}px'; // Larger for start/end markers
        innerContainer.style.height = '${markerSize}px';
        innerContainer.style.fontSize = '18px'; // Larger text
        innerContainer.style.fontWeight = 'bold';
        innerContainer.style.color = 'white'; // White text
        innerContainer.style.fontFamily = 'sans-serif';
        innerContainer.innerText = annotation.label!;
      } else {
        // For regular waypoints/POIs: show icon using Material Icons CDN as SVG image
        // This is more reliable than font-based rendering which wasn't working
        final iconName = _getMaterialIconName(annotation.icon);
        final iconUrl = 'https://fonts.gstatic.com/s/i/short-term/release/materialsymbolsoutlined/$iconName/default/24px.svg';
        
        final img = html.ImageElement()
          ..src = iconUrl
          ..style.width = '${iconSize}px'
          ..style.height = '${iconSize}px'
          ..style.filter = 'brightness(0) invert(1)' // Convert to white
          ..style.objectFit = 'contain'
          ..style.display = 'block'
          ..style.margin = 'auto';
        
        // Handle image load errors with fallback
        img.onError.listen((e) {
          debugPrint('⚠️ [MapboxWeb] Failed to load icon image for ${annotation.id}: $iconName');
          // Fallback: try font-based rendering
          innerContainer.style.fontFamily = '"Material Icons"'; // REQUIRED - quotes needed for font names with spaces!
          innerContainer.style.fontSize = '${iconSize}px';
          innerContainer.style.color = 'white';
          innerContainer.innerText = String.fromCharCode(annotation.icon.codePoint);
        });
        
        innerContainer.append(img);
        
        debugPrint('🎨 [MapboxWeb] Icon for ${annotation.id}: loading SVG from CDN ($iconName, codepoint=0x${annotation.icon.codePoint.toRadixString(16)})');
        
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
          innerContainer.append(labelEl);
        }
      }
      
      // Append inner container to outer element
      el.append(innerContainer);
      
      // Validate coordinates before creating marker
      final lng = annotation.position.longitude;
      final lat = annotation.position.latitude;
      
      // Validate coordinate ranges (prevent invalid coordinates)
      if (!annotation.position.isValid) {
        debugPrint('❌ [MapboxWeb] Invalid coordinates for ${annotation.id}: lat=$lat, lng=$lng');
        return;
      }
      
      final marker = js.JsObject(mapboxgl['Marker'], [js.JsObject.jsify({
        'element': el,
        'anchor': 'center',
      })])
        // CRITICAL: Mapbox uses [lng, lat] format (GeoJSON standard)
        // Use extension method for consistency
        ..callMethod('setLngLat', [js.JsObject.jsify(annotation.position.toLngLat())])
        ..callMethod('addTo', [map]);
      
      // CRITICAL: Store element reference BEFORE adding listener
      // This ensures we can clean it up properly later
      _markerElements[annotation.id] = el;
      
      // Add click handler - stop propagation to prevent map click, but allow marker click
      // Store the subscription so we can cancel it when the marker is removed
      final subscription = el.onClick.listen((e) {
        // CRITICAL: Block marker clicks when interactions are disabled
        // This prevents marker clicks from triggering actions when dialogs are open
        // Check both Dart flag and JS context flag to ensure we catch the current state
        final isDisabled = js.context['_interactionsDisabled_$_viewId'] as bool? ?? _interactionsDisabled;
        if (isDisabled) {
          debugPrint('🚫 [MapboxWeb] Marker click BLOCKED - interactions are disabled (dialog open)');
          e.stopPropagation();
          e.stopImmediatePropagation();
          e.preventDefault();
          return;
        }
        
        e.stopPropagation(); // Prevent click from reaching map
        e.stopImmediatePropagation(); // Prevent other handlers
        annotation.onTap?.call();
        debugPrint('📍 [MapboxWeb] Marker ${annotation.id} clicked at: $lat, $lng');
      });
      
      // Store subscription for proper cleanup
      _markerClickSubscriptions[annotation.id] = subscription;
      
      // Store marker and state
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
        // Use extension method for consistent coordinate format
        final coordinates = polyline.points.map((p) => p.toLngLat()).toList();
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
        widget.annotations.any((newAnnotation) => 
          !oldWidget.annotations.any((old) => old.id == newAnnotation.id)) ||
        widget.annotations.any((newAnnotation) {
          final oldAnnotation = oldWidget.annotations.firstWhere(
            (o) => o.id == newAnnotation.id, 
            orElse: () => newAnnotation,
          );
          // Compare actual positions (check if they're different annotations or positions changed)
          return oldAnnotation.id != newAnnotation.id || 
                 oldAnnotation.position.latitude != newAnnotation.position.latitude ||
                 oldAnnotation.position.longitude != newAnnotation.position.longitude;
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
    
    // Clean up all markers with proper disposal
    // Create a copy of keys to avoid modification during iteration
    final markerIds = _markers.keys.toList();
    for (final id in markerIds) {
      _removeMarkerFromMap(id);
    }
    
    // Ensure all subscriptions are cancelled (safety net)
    for (final subscription in _markerClickSubscriptions.values) {
      subscription.cancel();
    }
    _markerClickSubscriptions.clear();
    
    // Ensure all elements are removed (safety net)
    for (final element in _markerElements.values) {
      try {
        element.remove();
      } catch (_) {}
    }
    _markerElements.clear();

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
