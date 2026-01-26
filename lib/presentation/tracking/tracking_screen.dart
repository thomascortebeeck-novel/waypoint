import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:waypoint/integrations/offline_tile_provider.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/theme.dart';

class TrackingScreen extends StatefulWidget {
  final DayItinerary day;
  const TrackingScreen({super.key, required this.day});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  StreamSubscription<Position>? _sub;
  Position? _position;
  double _offRouteMeters = 0;
  late final List<ll.LatLng> _routeLine;
  final _distCalc = const ll.Distance();
  double _routeLengthMeters = 0;

  // Enhanced stats
  final List<_Sample> _samples = [];
  double? _speedKmh; // smoothed
  Duration? _eta;
  double? _gradePercent;
  double? _vertMPerHr;
  double _progressMeters = 0;
  

  @override
  void initState() {
    super.initState();
    _routeLine = _extractRoute(widget.day);
    _routeLengthMeters = _computeRouteLength(_routeLine);
    if (_routeLengthMeters == 0 && widget.day.route?.distance != null) {
      _routeLengthMeters = widget.day.route!.distance;
    }
    _start();
  }

  List<ll.LatLng> _extractRoute(DayItinerary d) {
    final coords = (d.route?.geometry['coordinates'] as List?) ?? const [];
    return coords.map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
  }

  Future<void> _start() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      _sub?.cancel();
      _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((pos) {
        final user = ll.LatLng(pos.latitude, pos.longitude);
        final proj = _projectProgress(user, _routeLine);
        final off = _distCalc(user, proj.point);
        // Update samples for speed smoothing
        _samples.add(_Sample(DateTime.now(), user, pos.altitude));
        if (_samples.length > 10) _samples.removeAt(0);
        final sp = _computeSpeedKmh();
        final grade = _computeGradePercent(proj.alongMeters);
        final vRate = (sp != null && grade != null) ? (sp * 1000 / 3600) * (grade / 100) * 3600 : null; // m/h
        final remaining = (_routeLengthMeters - proj.alongMeters).clamp(0, double.infinity);
        final eta = (sp != null && sp > 0.2) ? Duration(seconds: (remaining / (sp * 1000 / 3600)).round()) : null;
        setState(() {
          _position = pos;
          _offRouteMeters = off;
          _speedKmh = sp;
          _eta = eta;
          _gradePercent = grade;
          _vertMPerHr = vRate;
          _progressMeters = proj.alongMeters;
        });
      });
      final cur = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (mounted) setState(() => _position = cur);
    } catch (e) {
      debugPrint('tracking start error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _routeLine.isNotEmpty ? _routeLine.first : const ll.LatLng(46.8, 8.23);

    return Scaffold(
      body: Stack(children: [
        fm.FlutterMap(
          options: fm.MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            fm.TileLayer(
              urlTemplate: defaultRasterTileUrl,
              userAgentPackageName: 'com.waypoint.app',
              tileProvider: kIsWeb ? fm.NetworkTileProvider() : tileProviderOrNetwork(),
            ),
            if (_routeLine.isNotEmpty)
              fm.PolylineLayer(polylines: [fm.Polyline(points: _routeLine, color: Colors.blue, strokeWidth: 4)]),
            fm.MarkerLayer(markers: [
              if (_position != null) fm.Marker(point: ll.LatLng(_position!.latitude, _position!.longitude), width: 26, height: 26, child: _puck()),
            ])
          ],
        ),

        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk),
                  const SizedBox(width: 8),
                  Text('Off route: ${_offRouteMeters.toStringAsFixed(0)} m'),
                  const Spacer(),
                  if (_speedKmh != null) Padding(padding: const EdgeInsets.only(right: 10), child: Row(children: [const Icon(Icons.speed, size: 16), const SizedBox(width: 4), Text('${_speedKmh!.toStringAsFixed(1)} km/h')]),),
                  if (_eta != null) Padding(padding: const EdgeInsets.only(right: 10), child: Row(children: [const Icon(Icons.schedule, size: 16), const SizedBox(width: 4), Text(_formatEta(_eta!))])),
                  if (_gradePercent != null) Padding(padding: const EdgeInsets.only(right: 10), child: Row(children: [const Icon(Icons.landscape, size: 16), const SizedBox(width: 4), Text('${_gradePercent!.toStringAsFixed(0)}%')])),
                  if (_vertMPerHr != null) Row(children: [const Icon(Icons.trending_up, size: 16), const SizedBox(width: 4), Text('${_vertMPerHr!.round()} m/h')]),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Progress', style: context.textStyles.labelSmall),
                  Text(_routeLengthMeters > 0 ? '${(_progressMeters / _routeLengthMeters * 100).toStringAsFixed(0)}%' : '0%'),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _routeLengthMeters > 0 ? (_progressMeters / _routeLengthMeters).clamp(0.0, 1.0) : 0,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _puck() => Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)));

  ll.LatLng _nearestPointOnRoute(ll.LatLng p, List<ll.LatLng> line) {
    if (line.isEmpty) return p;
    ll.LatLng best = line.first;
    double bestDist = _distCalc(p, best);
    for (int i = 0; i < line.length - 1; i++) {
      final proj = _projectOnSegment(p, line[i], line[i + 1]);
      final d = _distCalc(p, proj);
      if (d < bestDist) {
        best = proj;
        bestDist = d;
      }
    }
    return best;
  }

  ll.LatLng _projectOnSegment(ll.LatLng p, ll.LatLng a, ll.LatLng b) {
    // Simple equirectangular approximation for short segments
    final x1 = a.longitude, y1 = a.latitude;
    final x2 = b.longitude, y2 = b.latitude;
    final x3 = p.longitude, y3 = p.latitude;
    final dx = x2 - x1, dy = y2 - y1;
    if (dx == 0 && dy == 0) return a;
    final t = ((x3 - x1) * dx + (y3 - y1) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return ll.LatLng(y1 + clamped * dy, x1 + clamped * dx);
  }

  double _computeRouteLength(List<ll.LatLng> line) {
    double sum = 0;
    for (int i = 0; i < line.length - 1; i++) {
      sum += _distCalc(line[i], line[i + 1]);
    }
    return sum;
  }

  _Projection _projectProgress(ll.LatLng p, List<ll.LatLng> line) {
    if (line.isEmpty) return _Projection(p, 0);
    double bestAlong = 0;
    ll.LatLng bestPoint = line.first;
    double traveled = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < line.length - 1; i++) {
      final a = line[i];
      final b = line[i + 1];
      final proj = _projectOnSegment(p, a, b);
      // Check if proj is on segment a-b by comparing distances
      final dToProj = _distCalc(p, proj);
      if (dToProj < bestDist) {
        bestDist = dToProj;
        bestPoint = proj;
        bestAlong = traveled + _distCalc(a, proj);
      }
      traveled += _distCalc(a, b);
    }
    return _Projection(bestPoint, bestAlong);
  }

  double? _computeSpeedKmh() {
    if (_samples.length < 2) return null;
    // Use the last few samples to smooth
    final recent = _samples.takeLast(5);
    double dist = 0;
    int dtMs = 0;
    for (int i = 0; i < recent.length - 1; i++) {
      dist += _distCalc(recent[i].pos, recent[i + 1].pos);
      dtMs += recent[i + 1].t.difference(recent[i].t).inMilliseconds;
    }
    if (dtMs <= 0) return null;
    final mps = dist / (dtMs / 1000);
    return mps * 3.6;
  }

  double? _computeGradePercent(double alongMeters) {
    final profile = widget.day.route?.elevationProfile;
    if (profile == null || profile.length < 2) return null;
    // Find two points around current progress
    double? e1;
    double? e2;
    double? d1;
    double? d2;
    for (int i = 0; i < profile.length - 1; i++) {
      final a = profile[i];
      final b = profile[i + 1];
      if (a.distance <= alongMeters && alongMeters <= b.distance) {
        d1 = a.distance;
        d2 = b.distance;
        e1 = a.elevation;
        e2 = b.elevation;
        break;
      }
    }
    if (e1 == null || e2 == null || d1 == null || d2 == null) return null;
    final dd = (d2 - d1).abs();
    if (dd < 1) return 0; // flat
    final de = (e2 - e1);
    return (de / dd) * 100.0;
  }

  String _formatEta(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _Sample {
  final DateTime t;
  final ll.LatLng pos;
  final double altitude;
  _Sample(this.t, this.pos, this.altitude);
}

class _Projection {
  final ll.LatLng point;
  final double alongMeters;
  _Projection(this.point, this.alongMeters);
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) => skip(length > n ? length - n : 0).toList();
}
