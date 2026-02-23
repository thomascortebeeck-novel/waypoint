import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/presentation/widgets/link_preview_card.dart';
import 'package:waypoint/state/sub_form_states.dart';
import 'package:waypoint/services/link_preview_service.dart';
import 'dart:typed_data';

/// Form state for a single day
/// All controllers exist regardless of activity type — UI handles visibility
class DayFormState extends ChangeNotifier {
  final int dayNum;
  
  // --- Common fields (all activity types) ---
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController timeCtrl;        // Estimated time
  final TextEditingController stayUrlCtrl;
  final TextEditingController stayCostCtrl;
  
  // --- Outdoor-specific fields (hidden for city trips) ---
  final TextEditingController distanceCtrl;    // Distance in km
  final TextEditingController elevationCtrl;   // Elevation gain in m
  final TextEditingController komootLinkCtrl;
  final TextEditingController allTrailsLinkCtrl;
  
  // --- Coordinates ---
  ll.LatLng? start;
  ll.LatLng? end;
  
  // --- Route data (outdoor: polyline + GPX; city: markers only) ---
  DayRoute? route;
  RouteInfo? routeInfo;        // Surface type, difficulty — outdoor only
  GpxRoute? gpxRoute;          // GPX data — outdoor only
  
  // --- POIs (all activity types) - for backward compatibility with legacy data
  // Note: New waypoints use RouteWaypoint system
  final List<AccommodationFormState> accommodations;
  final List<RestaurantFormState> restaurants;
  final List<ActivityFormState> activities;
  
  // --- Images (multiple support) ---
  List<Uint8List> newImageBytes = [];
  List<String> newImageExtensions = [];
  List<String> existingImageUrls = [];
  
  // --- Link previews ---
  LinkPreviewData? stayMeta;
  
  DayFormState({required this.dayNum})
    : titleCtrl = TextEditingController(),
      descCtrl = TextEditingController(),
      distanceCtrl = TextEditingController(),
      elevationCtrl = TextEditingController(),
      timeCtrl = TextEditingController(),
      stayUrlCtrl = TextEditingController(),
      stayCostCtrl = TextEditingController(),
      komootLinkCtrl = TextEditingController(),
      allTrailsLinkCtrl = TextEditingController(),
      accommodations = [],
      restaurants = [],
      activities = [];
  
  /// Get ordered waypoints from route
  /// Uses RouteWaypoint.order for ordering
  List<RouteWaypoint> getOrderedWaypoints() {
    if (route == null) return const [];
    final waypoints = route!.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return waypoints;
  }
  
  /// Move a waypoint up in order
  DayRoute? moveWaypointUp(String waypointId) {
    if (route == null) return null;
    final waypoints = getOrderedWaypoints();
    final index = waypoints.indexWhere((w) => w.id == waypointId);
    if (index <= 0) return null;
    final current = waypoints[index];
    final previous = waypoints[index - 1];
    final tempOrder = current.order;
    waypoints[index] = current.copyWith(order: previous.order);
    waypoints[index - 1] = previous.copyWith(order: tempOrder);
    route = route!.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    notifyListeners();
    return route;
  }
  
  /// Move a waypoint down in order
  DayRoute? moveWaypointDown(String waypointId) {
    if (route == null) return null;
    final waypoints = getOrderedWaypoints();
    final index = waypoints.indexWhere((w) => w.id == waypointId);
    if (index < 0 || index >= waypoints.length - 1) return null;
    final current = waypoints[index];
    final next = waypoints[index + 1];
    final tempOrder = current.order;
    waypoints[index] = current.copyWith(order: next.order);
    waypoints[index + 1] = next.copyWith(order: tempOrder);
    route = route!.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    notifyListeners();
    return route;
  }
  
  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    distanceCtrl.dispose();
    elevationCtrl.dispose();
    timeCtrl.dispose();
    stayUrlCtrl.dispose();
    stayCostCtrl.dispose();
    komootLinkCtrl.dispose();
    allTrailsLinkCtrl.dispose();
    for (final a in accommodations) { a.dispose(); }
    for (final r in restaurants) { r.dispose(); }
    for (final act in activities) { act.dispose(); }
    super.dispose();
  }
}

