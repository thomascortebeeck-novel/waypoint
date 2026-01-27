import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/location_tracking_service.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';

class TrackingOverlayWidget extends StatefulWidget {
  final WaypointMapController? mapController;
  final List<LatLng>? route;
  final VoidCallback? onCenterOnUser;

  const TrackingOverlayWidget({
    super.key,
    this.mapController,
    this.route,
    this.onCenterOnUser,
  });

  @override
  State<TrackingOverlayWidget> createState() => _TrackingOverlayWidgetState();
}

class _TrackingOverlayWidgetState extends State<TrackingOverlayWidget> {
  final _trackingService = LocationTrackingService();
  StreamSubscription<UserLocation>? _locationSub;
  StreamSubscription<TrackingState>? _stateSub;
  
  UserLocation? _currentLocation;
  TrackingState _trackingState = TrackingState.idle;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void didUpdateWidget(TrackingOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != oldWidget.route && widget.route != null) {
      _trackingService.updateRoute(widget.route!);
    }
  }

  void _setupListeners() {
    _locationSub = _trackingService.locationStream.listen((location) {
      setState(() => _currentLocation = location);
      _updateMapMarker(location);
      
      if (_followUser && widget.mapController != null) {
        widget.mapController!.animateCamera(
          location.position,
          widget.mapController!.currentPosition?.zoom ?? 15,
        );
      }
    });

    _stateSub = _trackingService.stateStream.listen((state) {
      setState(() => _trackingState = state);
    });
  }

  void _updateMapMarker(UserLocation location) {
    widget.mapController?.setUserLocation(
      location.position,
      heading: location.hasHeading ? location.heading : null,
    );
  }

  Future<void> _toggleTracking() async {
    if (_trackingState == TrackingState.tracking) {
      _trackingService.stopTracking();
    } else {
      await _trackingService.startTracking(route: widget.route);
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Off-route warning (top)
        if (_currentLocation?.routeProgress?.isOffRoute == true)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: _OffRouteWarning(
              distanceFromRoute: _currentLocation!.routeProgress!.distanceFromRoute,
            ),
          ),

        // Progress info card
        if (_trackingState == TrackingState.tracking && _currentLocation?.routeProgress != null)
          Positioned(
            top: _currentLocation?.routeProgress?.isOffRoute == true ? 130 : 100,
            left: 16,
            right: 16,
            child: _ProgressCard(
              progress: _currentLocation!.routeProgress!,
              speed: _currentLocation!.speedKmh,
              accuracy: _currentLocation!.accuracy,
            ),
          ),

        // Tracking controls (bottom-left)
        Positioned(
          left: 16,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackingButton(
                isTracking: _trackingState == TrackingState.tracking,
                isLoading: _trackingState == TrackingState.starting,
                onPressed: _toggleTracking,
              ),
              const SizedBox(height: 8),
              if (_trackingState == TrackingState.tracking)
                _ControlButton(
                  icon: _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                  onPressed: () {
                    setState(() => _followUser = !_followUser);
                    if (_followUser && _currentLocation != null) {
                      widget.mapController?.animateCamera(
                        _currentLocation!.position,
                        widget.mapController!.currentPosition?.zoom ?? 15,
                      );
                    }
                  },
                  isActive: _followUser,
                  tooltip: _followUser ? 'Following' : 'Tap to follow',
                ),
            ],
          ),
        ),

        // Permission denied message
        if (_trackingState == TrackingState.permissionDenied)
          Positioned(
            bottom: 180,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_off, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Location permission required for tracking',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TrackingButton extends StatelessWidget {
  final bool isTracking;
  final bool isLoading;
  final VoidCallback onPressed;

  const _TrackingButton({
    required this.isTracking,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isTracking ? Colors.red : const Color(0xFF4CAF50),
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(
                  isTracking ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              const SizedBox(width: 8),
              Text(
                isLoading ? 'Starting...' : (isTracking ? 'Stop' : 'Start Tracking'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isActive ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade700,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final RouteProgress progress;
  final double speed;
  final double accuracy;

  const _ProgressCard({
    required this.progress,
    required this.speed,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.progressPercent / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${progress.progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.check_circle_outline,
                value: '${progress.distanceTraveledKm.toStringAsFixed(1)} km',
                label: 'Done',
                color: const Color(0xFF4CAF50),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _StatItem(
                icon: Icons.flag_outlined,
                value: '${progress.distanceRemainingKm.toStringAsFixed(1)} km',
                label: 'Left',
                color: Colors.blue,
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _StatItem(
                icon: Icons.speed,
                value: speed.toStringAsFixed(1),
                label: 'km/h',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // GPS accuracy
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accuracy < 10 ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    accuracy < 10 ? Icons.gps_fixed : Icons.gps_not_fixed,
                    size: 14,
                    color: accuracy < 10 ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPS ±${accuracy.toStringAsFixed(0)}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: accuracy < 10 ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _OffRouteWarning extends StatelessWidget {
  final double distanceFromRoute;

  const _OffRouteWarning({required this.distanceFromRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are off the route',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${distanceFromRoute.toStringAsFixed(0)}m away from trail',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
