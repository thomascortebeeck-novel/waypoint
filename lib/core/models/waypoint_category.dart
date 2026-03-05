import 'package:waypoint/models/route_waypoint.dart';

/// Single source of truth for the 4 main waypoint category labels used across the app.
/// Use these labels everywhere: category pills, itinerary cards, type labels, dropdowns.
class WaypointCategoryLabels {
  WaypointCategoryLabels._();

  static const String eat = 'Eat & Drink';
  static const String sleep = 'Sleep';
  static const String move = 'Move';
  static const String doAndSee = 'Do & See';

  static String fromType(WaypointType type) {
    switch (type) {
      case WaypointType.restaurant:
      case WaypointType.bar:
        return eat;
      case WaypointType.accommodation:
        return sleep;
      case WaypointType.service:
        return move;
      case WaypointType.attraction:
      case WaypointType.viewingPoint:
        return doAndSee;
      default:
        return 'place';
    }
  }
}
