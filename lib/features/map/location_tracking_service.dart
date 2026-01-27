import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/utils/logger.dart';

/// Real-time GPS tracking service for outdoor navigation
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<UserLocation>.broadcast();
  final _trackingStateController = StreamController<TrackingState>.broadcast();
  
  UserLocation? _lastLocation;
  TrackingState _state = TrackingState.idle;
  List<LatLng>? _activeRoute;
  
  Stream<UserLocation> get locationStream => _locationController.stream;
  Stream<TrackingState> get stateStream => _trackingStateController.stream;
  TrackingState get state => _state;
  UserLocation? get lastLocation => _lastLocation;

  /// Check and request location permissions
  Future<LocationPermissionResult> checkPermissions() async {
    if (kIsWeb) {
      return LocationPermissionResult.granted;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }

    return LocationPermissionResult.granted;
  }

  /// Start real-time location tracking
  Future<bool> startTracking({
    List<LatLng>? route,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) async {
    final permissionResult = await checkPermissions();
    if (permissionResult != LocationPermissionResult.granted) {
      Log.w('location', '⚠️ Location permission not granted: $permissionResult');
      _updateState(TrackingState.permissionDenied);
      return false;
    }

    _activeRoute = route;
    _updateState(TrackingState.starting);

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      );
      _processPosition(initialPosition);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      ).listen(
        _processPosition,
        onError: (error) {
          Log.e('location', 'Location stream error', error);
          _updateState(TrackingState.error);
        },
      );

      _updateState(TrackingState.tracking);
      Log.i('location', '📍 Location tracking started');
      return true;
    } catch (e) {
      Log.e('location', 'Failed to start tracking', e);
      _updateState(TrackingState.error);
      return false;
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeRoute = null;
    _updateState(TrackingState.idle);
    Log.i('location', '📍 Location tracking stopped');
  }

  void updateRoute(List<LatLng> route) {
    _activeRoute = route;
    if (_lastLocation != null) {
      _processLocation(_lastLocation!.position, _lastLocation!.heading);
    }
  }

  void _processPosition(Position position) {
    _processLocation(
      LatLng(position.latitude, position.longitude),
      position.heading,
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
    );
  }

  void _processLocation(
    LatLng position,
    double heading, {
    double? accuracy,
    double? speed,
    double? altitude,
  }) {
    RouteProgress? progress;
    
    if (_activeRoute != null && _activeRoute!.length >= 2) {
      progress = _calculateRouteProgress(position, _activeRoute!);
    }

    final location = UserLocation(
      position: position,
      heading: heading,
      accuracy: accuracy ?? 0,
      speed: speed ?? 0,
      altitude: altitude,
      timestamp: DateTime.now(),
      routeProgress: progress,
    );

    _lastLocation = location;
    _locationController.add(location);
  }

  void _updateState(TrackingState newState) {
    if (_state != newState) {
      _state = newState;
      _trackingStateController.add(newState);
    }
  }

  RouteProgress _calculateRouteProgress(LatLng userPos, List<LatLng> route) {
    double minDistance = double.infinity;
    int nearestSegmentIndex = 0;
    LatLng nearestPoint = route.first;
    double distanceAlongRoute = 0;
    double totalRouteDistance = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final segmentStart = route[i];
      final segmentEnd = route[i + 1];
      final segmentLength = _haversineDistance(segmentStart, segmentEnd);
      
      final projection = _projectPointOnSegment(userPos, segmentStart, segmentEnd);
      final distanceToSegment = _haversineDistance(userPos, projection.point);

      if (distanceToSegment < minDistance) {
        minDistance = distanceToSegment;
        nearestSegmentIndex = i;
        nearestPoint = projection.point;
      }

      totalRouteDistance += segmentLength;
    }

    for (int i = 0; i < nearestSegmentIndex; i++) {
      distanceAlongRoute += _haversineDistance(route[i], route[i + 1]);
    }
    distanceAlongRoute += _haversineDistance(route[nearestSegmentIndex], nearestPoint);

    final isOffRoute = minDistance > 50;
    final remainingDistance = totalRouteDistance - distanceAlongRoute;
    final progressPercent = totalRouteDistance > 0 
        ? (distanceAlongRoute / totalRouteDistance * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;

    return RouteProgress(
      distanceTraveled: distanceAlongRoute,
      distanceRemaining: remainingDistance,
      totalDistance: totalRouteDistance,
      progressPercent: progressPercent,
      nearestPointOnRoute: nearestPoint,
      distanceFromRoute: minDistance,
      isOffRoute: isOffRoute,
      currentSegmentIndex: nearestSegmentIndex,
    );
  }

  _ProjectionResult _projectPointOnSegment(LatLng point, LatLng segStart, LatLng segEnd) {
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;
    
    if (dx == 0 && dy == 0) {
      return _ProjectionResult(segStart, 0);
    }

    final t = ((point.longitude - segStart.longitude) * dx + 
               (point.latitude - segStart.latitude) * dy) / 
              (dx * dx + dy * dy);

    final clampedT = t.clamp(0.0, 1.0);

    return _ProjectionResult(
      LatLng(
        segStart.latitude + clampedT * dy,
        segStart.longitude + clampedT * dx,
      ),
      clampedT,
    );
  }

  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;

    final aVal = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return R * c;
  }

  void dispose() {
    stopTracking();
    _locationController.close();
    _trackingStateController.close();
  }
}

class _ProjectionResult {
  final LatLng point;
  final double t;
  _ProjectionResult(this.point, this.t);
}

class UserLocation {
  final LatLng position;
  final double heading;
  final double accuracy;
  final double speed;
  final double? altitude;
  final DateTime timestamp;
  final RouteProgress? routeProgress;

  const UserLocation({
    required this.position,
    required this.heading,
    required this.accuracy,
    required this.speed,
    this.altitude,
    required this.timestamp,
    this.routeProgress,
  });

  double get speedKmh => speed * 3.6;
  bool get hasHeading => heading >= 0 && heading <= 360;
}

class RouteProgress {
  final double distanceTraveled;
  final double distanceRemaining;
  final double totalDistance;
  final double progressPercent;
  final LatLng nearestPointOnRoute;
  final double distanceFromRoute;
  final bool isOffRoute;
  final int currentSegmentIndex;

  const RouteProgress({
    required this.distanceTraveled,
    required this.distanceRemaining,
    required this.totalDistance,
    required this.progressPercent,
    required this.nearestPointOnRoute,
    required this.distanceFromRoute,
    required this.isOffRoute,
    required this.currentSegmentIndex,
  });

  double get distanceTraveledKm => distanceTraveled / 1000;
  double get distanceRemainingKm => distanceRemaining / 1000;
}

enum LocationPermissionResult {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

enum TrackingState {
  idle,
  starting,
  tracking,
  paused,
  permissionDenied,
  error,
}
