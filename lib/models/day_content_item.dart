import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Base class for day content items (order-based system for waypoints and media)
abstract class DayContentItem {
  final int order; // Sequential order (0, 1, 2, 3...)
  final String type; // Type discriminator: "waypoint" or "media"
  
  DayContentItem({required this.order, required this.type});
  
  // Serialization requires type discriminator for Firestore
  Map<String, dynamic> toJson();
  
  factory DayContentItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'waypoint':
        return WaypointContentItem.fromJson(json);
      case 'media':
        return MediaContentItem.fromJson(json);
      default:
        throw Exception('Unknown DayContentItem type: $type');
    }
  }
}

/// Waypoint content item
class WaypointContentItem extends DayContentItem {
  final RouteWaypoint waypoint;
  
  WaypointContentItem({required this.waypoint, required super.order})
      : super(type: 'waypoint');
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'waypoint',
    'order': order,
    'waypoint': waypoint.toJson(),
  };
  
  factory WaypointContentItem.fromJson(Map<String, dynamic> json) =>
      WaypointContentItem(
        waypoint: RouteWaypoint.fromJson(json['waypoint'] as Map<String, dynamic>),
        order: json['order'] as int,
      );
}

/// Media content item (image or video between waypoints)
class MediaContentItem extends DayContentItem {
  final MediaItem media; // image or video
  
  MediaContentItem({required this.media, required super.order})
      : super(type: 'media');
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'media',
    'order': order,
    'media': media.toJson(),
  };
  
  factory MediaContentItem.fromJson(Map<String, dynamic> json) =>
      MediaContentItem(
        media: MediaItem.fromJson(json['media'] as Map<String, dynamic>),
        order: json['order'] as int,
      );
}

