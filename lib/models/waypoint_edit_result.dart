import 'package:waypoint/models/plan_model.dart';

/// Result of the waypoint add/edit full-page flow.
/// Caller uses [context.push<WaypointEditResult>] and switches on the subtype.
sealed class WaypointEditResult {}

/// User saved the waypoint (add or update). Apply [route] to the day's route.
class WaypointSaved extends WaypointEditResult {
  final DayRoute route;
  WaypointSaved(this.route);
}

/// User deleted the waypoint (edit mode only). Remove waypoint [waypointId] from the day's poiWaypoints.
class WaypointDeleted extends WaypointEditResult {
  final String waypointId;
  WaypointDeleted(this.waypointId);
}
