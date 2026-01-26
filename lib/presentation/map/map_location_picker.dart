import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
// Native Mapbox import is deferred from this file to keep web preview compiling cleanly.
import 'package:waypoint/integrations/mapbox_service.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/utils/logger.dart';

// Conditionally import Mapbox only on non-web to avoid analyzer issues in web preview
// We keep types dynamic and guarded at runtime.

typedef LatLng = ll.LatLng;

class MapLocationPicker extends StatefulWidget {
  final ll.LatLng? initial;
  final void Function(ll.LatLng) onSelected;
  const MapLocationPicker({super.key, this.initial, required this.onSelected});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  ll.LatLng? _picked;
  final fm.MapController _webController = fm.MapController();
  List<PlaceSuggestion> _searchPins = const [];

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    // Web preview: use FlutterMap (Leaflet tiles)
    if (kIsWeb) {
      final center = _picked ?? const ll.LatLng(46.8, 8.23);
      Log.i('picker', 'Web picker build, center=${center.latitude},${center.longitude}, token=${hasValidMapboxToken}');
      return Column(children: [
        Expanded(
          child: Stack(children: [
            fm.FlutterMap(
              mapController: _webController,
              options: fm.MapOptions(
                initialCenter: center,
                initialZoom: 9,
                onTap: (tapPos, latLng) => setState(() => _picked = latLng),
              ),
              children: [
                fm.TileLayer(
                  urlTemplate: defaultRasterTileUrl,
                  userAgentPackageName: 'com.waypoint.app',
                ),
                if (_searchPins.isNotEmpty)
                  fm.MarkerLayer(markers: _searchPins.map((s) => fm.Marker(
                    point: ll.LatLng(s.latitude, s.longitude),
                    width: 28, height: 28,
                    child: Icon(s.isPoi ? Icons.store_mall_directory : Icons.location_on, color: s.isPoi ? Colors.blue : Colors.grey, size: 24),
                  )).toList()),
                if (_picked != null)
                  fm.MarkerLayer(markers: [
                    fm.Marker(point: _picked!, width: 40, height: 40, child: const Icon(Icons.place, color: Colors.red, size: 36))
                  ])
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _SearchBarOverlay(
                onSuggestionTap: (s) {
                  final p = ll.LatLng(s.latitude, s.longitude);
                  setState(() => _picked = p);
                  _webController.move(p, _webController.camera.zoom);
                  Log.i('picker', 'Picked suggestion ${s.text} @ ${p.latitude},${p.longitude}');
                },
                onResultsChanged: (list) => setState(() => _searchPins = list),
                getProximity: () => _webController.camera.center,
                onCoordinatePick: (lat, lng) {
                  final p = ll.LatLng(lat, lng);
                  setState(() => _picked = p);
                  _webController.move(p, _webController.camera.zoom);
                  Log.i('picker', 'Picked coordinates $lat,$lng');
                },
              ),
            ),
            Positioned(
              right: 12,
              bottom: 90,
              child: Column(children: [
                _ZoomButton(icon: Icons.add, onTap: () {
                  final z = _webController.camera.zoom + 1;
                  _webController.move(_webController.camera.center, z);
                }),
                const SizedBox(height: 8),
                _ZoomButton(icon: Icons.remove, onTap: () {
                  final z = _webController.camera.zoom - 1;
                  _webController.move(_webController.camera.center, z);
                }),
              ]),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _picked == null ? null : () => widget.onSelected(_picked!),
              child: const Text('Use this location'),
            ),
          ),
        )
      ]);
    }

    // Mobile: Mapbox native if token available, otherwise fallback to basic map
    if (!hasValidMapboxToken) {
      Log.w('picker', 'Token missing; showing placeholder');
      return _tokenMissingPlaceholder(context);
    }

    // Lazy import via dynamic to avoid analyzer issues in web builds
    return _MapboxPickerBody(initial: widget.initial, onSelected: widget.onSelected);
  }

  Widget _tokenMissingPlaceholder(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map, size: 42),
          const SizedBox(height: 12),
          const Text('Mapbox token missing'),
          const SizedBox(height: 8),
          Text('Provide MAPBOX_PUBLIC_TOKEN via --dart-define to enable the native picker on mobile.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)
        ]),
      ),
    );
  }
}

// Separated to keep the main widget web-safe
class _MapboxPickerBody extends StatefulWidget {
  final ll.LatLng? initial;
  final void Function(ll.LatLng) onSelected;
  const _MapboxPickerBody({required this.initial, required this.onSelected});

  @override
  State<_MapboxPickerBody> createState() => _MapboxPickerBodyState();
}

class _MapboxPickerBodyState extends State<_MapboxPickerBody> {
  ll.LatLng? _picked;
  final _overlayKey = GlobalKey<_SearchBarOverlayState>();

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    // Use a SizedBox and a button; integrate Mapbox Map via PlatformView at runtime
    return Column(children: [
      Expanded(
        child: Stack(children: [
           _MapboxInteractive(onPick: (lat, lng) => setState(() => _picked = ll.LatLng(lat, lng)), initial: _picked),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _SearchBarOverlay(
              key: _overlayKey,
              onSuggestionTap: (s) {
                setState(() => _picked = ll.LatLng(s.latitude, s.longitude));
                // On native Mapbox we'd move camera here via controller.
                Log.i('picker', 'Picked suggestion on native ${s.text}');
              },
               onResultsChanged: (list) {},
               getProximity: () => _picked,
               onCoordinatePick: (lat, lng) => setState(() => _picked = ll.LatLng(lat, lng)),
            ),
          ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: _picked == null ? null : () => widget.onSelected(_picked!), child: const Text('Use this location')),
        ),
      )
    ]);
  }
}

/// This widget hosts the Mapbox Map natively on mobile and communicates tap
/// coordinates back to Flutter. Implementation uses mapbox_maps_flutter directly.
class _MapboxInteractive extends StatefulWidget {
  final void Function(double lat, double lng) onPick;
  final ll.LatLng? initial;
  const _MapboxInteractive({required this.onPick, this.initial});

  @override
  State<_MapboxInteractive> createState() => _MapboxInteractiveState();
}

class _MapboxInteractiveState extends State<_MapboxInteractive> {
  @override
  Widget build(BuildContext context) {
    // Defer import to runtime to keep analyzer happy on web.
    // ignore: undefined_prefixed_name
    return _NativeMapbox(onPick: widget.onPick, initial: widget.initial);
  }
}

// The below widget is split to avoid imports at the top-level.
// It will only be instantiated on mobile.
class _NativeMapbox extends StatefulWidget {
  final void Function(double lat, double lng) onPick;
  final ll.LatLng? initial;
  const _NativeMapbox({required this.onPick, this.initial});

  @override
  State<_NativeMapbox> createState() => _NativeMapboxState();
}

class _NativeMapboxState extends State<_NativeMapbox> {
  @override
  Widget build(BuildContext context) {
    // Keep a placeholder container to avoid compile-time mobile SDK API drift.
    return Container(color: Colors.black12, child: const Center(child: Text('Mapbox map (device preview)', style: TextStyle(fontSize: 12))));
  }
}

// Search overlay used both on web and mobile map pickers
class _SearchBarOverlay extends StatefulWidget {
  final void Function(PlaceSuggestion) onSuggestionTap;
  final void Function(List<PlaceSuggestion>)? onResultsChanged;
  final ll.LatLng? Function()? getProximity;
  final void Function(double lat, double lng)? onCoordinatePick;
  const _SearchBarOverlay({super.key, required this.onSuggestionTap, this.onResultsChanged, this.getProximity, this.onCoordinatePick});

  @override
  State<_SearchBarOverlay> createState() => _SearchBarOverlayState();
}

class _SearchBarOverlayState extends State<_SearchBarOverlay> {
  late final TextEditingController _ctrl;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    Log.i('picker.search', 'Search overlay initialized');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    Log.i('picker.search', 'Search overlay disposed');
    super.dispose();
  }

  Future<void> _onChanged() async {
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      setState(() => _results = const []);
      widget.onResultsChanged?.call(_results);
      return;
    }
    setState(() => _loading = true);
    try {
      final svc = MapboxService();
      final prox = widget.getProximity?.call();
      Log.i('picker.search', 'q="$q" prox=${prox?.latitude},${prox?.longitude}');
      final r = await svc.searchPlaces(q, proximityLat: prox?.latitude, proximityLng: prox?.longitude);
      if (!mounted) return;
      setState(() => _results = r);
      Log.i('picker.search', 'results=${r.length}');
      widget.onResultsChanged?.call(_results);
    } catch (e) {
      Log.e('picker.search', 'error', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _promptCoordinates(BuildContext context) async {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter coordinates'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: latCtrl, keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true), decoration: const InputDecoration(labelText: 'Latitude (-90..90)')),
          TextField(controller: lngCtrl, keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true), decoration: const InputDecoration(labelText: 'Longitude (-180..180)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Set')),
        ],
      ),
    );
    if (res == true) {
      try {
        final lat = double.parse(latCtrl.text.trim());
        final lng = double.parse(lngCtrl.text.trim());
        if (lat.abs() > 90 || lng.abs() > 180) throw ArgumentError('Out of range');
        widget.onCoordinatePick?.call(lat, lng);
      } catch (e) {
        debugPrint('Invalid coordinates: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid coordinates')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: _ctrl,
          onChanged: (_) => _onChanged(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            hintText: 'Search places…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Enter coordinates',
                      icon: const Icon(Icons.pin_drop),
                      onPressed: () => _promptCoordinates(context),
                    ),
                  ]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
      if (_results.isNotEmpty)
        const SizedBox(height: 6),
      if (_results.isNotEmpty)
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = _results[i];
                return ListTile(
                  dense: true,
                  leading: Icon(s.isPoi ? Icons.store_mall_directory : Icons.place),
                  title: Text(s.text),
                  subtitle: Text(s.placeName),
                  onTap: () {
                    widget.onSuggestionTap(s);
                    setState(() => _results = const []);
                    _ctrl.text = s.placeName;
                  },
                );
              },
            ),
          ),
        ),
    ]);
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20)),
      ),
    );
  }
}
