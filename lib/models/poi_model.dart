import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Types of outdoor Points of Interest
enum POIType {
  campsite,
  hut,
  viewpoint,
  water,
  shelter,
  parking,
  trailhead,
  picnicSite,
  toilets,
  informationBoard,
  peakSummit,
  waterfall,
  cave,
  bench,
  rangerStation,
  emergencyPhone,
  guidepost,
  other;

  String get displayName {
    switch (this) {
      case POIType.campsite:
        return 'Campsite';
      case POIType.hut:
        return 'Hut';
      case POIType.viewpoint:
        return 'Viewpoint';
      case POIType.water:
        return 'Water Source';
      case POIType.shelter:
        return 'Shelter';
      case POIType.parking:
        return 'Parking';
      case POIType.trailhead:
        return 'Trailhead';
      case POIType.picnicSite:
        return 'Picnic Site';
      case POIType.toilets:
        return 'Toilets';
      case POIType.informationBoard:
        return 'Info Board';
      case POIType.peakSummit:
        return 'Peak';
      case POIType.waterfall:
        return 'Waterfall';
      case POIType.cave:
        return 'Cave';
      case POIType.bench:
        return 'Bench';
      case POIType.rangerStation:
        return 'Ranger Station';
      case POIType.emergencyPhone:
        return 'Emergency Phone';
      case POIType.guidepost:
        return 'Guidepost';
      case POIType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case POIType.campsite:
        return Icons.cabin;
      case POIType.hut:
        return Icons.cottage;
      case POIType.viewpoint:
        return Icons.landscape;
      case POIType.water:
        return Icons.water_drop;
      case POIType.shelter:
        return Icons.roofing;
      case POIType.parking:
        return Icons.local_parking;
      case POIType.trailhead:
        return Icons.hiking;
      case POIType.picnicSite:
        return Icons.outdoor_grill;
      case POIType.toilets:
        return Icons.wc;
      case POIType.informationBoard:
        return Icons.info;
      case POIType.peakSummit:
        return Icons.terrain;
      case POIType.waterfall:
        return Icons.water;
      case POIType.cave:
        return Icons.explore;
      case POIType.bench:
        return Icons.event_seat;
      case POIType.rangerStation:
        return Icons.shield;
      case POIType.emergencyPhone:
        return Icons.phone_in_talk;
      case POIType.guidepost:
        return Icons.signpost;
      case POIType.other:
        return Icons.place;
    }
  }

  Color get color {
    switch (this) {
      case POIType.campsite:
        return const Color(0xFF52B788);
      case POIType.hut:
        return const Color(0xFF8D6E63);
      case POIType.viewpoint:
        return const Color(0xFF9C27B0);
      case POIType.water:
        return const Color(0xFF4A90A4);
      case POIType.shelter:
        return const Color(0xFFD62828);
      case POIType.parking:
        return const Color(0xFF757575);
      case POIType.trailhead:
        return const Color(0xFF1B4332);
      case POIType.picnicSite:
        return const Color(0xFF52B788);
      case POIType.toilets:
        return const Color(0xFF2196F3);
      case POIType.informationBoard:
        return const Color(0xFFFFB300);
      case POIType.peakSummit:
        return const Color(0xFF795548);
      case POIType.waterfall:
        return const Color(0xFF4A90A4);
      case POIType.cave:
        return const Color(0xFF607D8B);
      case POIType.bench:
        return const Color(0xFF8BC34A);
      case POIType.rangerStation:
        return const Color(0xFFD62828);
      case POIType.emergencyPhone:
        return const Color(0xFFD62828);
      case POIType.guidepost:
        return const Color(0xFFFFB300);
      case POIType.other:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// Outdoor Point of Interest from OpenStreetMap
class POI {
  final String id;
  final POIType type;
  final String name;
  final String? description;
  final LatLng coordinates;
  final Map<String, dynamic> tags;

  POI({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.coordinates,
    required this.tags,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final properties = json['properties'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List;

    return POI(
      id: properties['id'] as String,
      type: _parseType(properties['type'] as String),
      name: properties['name'] as String? ?? 'Unnamed',
      description: properties['description'] as String?,
      coordinates: LatLng(
        coords[1] as double, // lat
        coords[0] as double, // lng
      ),
      tags: properties['tags'] as Map<String, dynamic>? ?? {},
    );
  }

  static POIType _parseType(String typeStr) {
    try {
      return POIType.values.firstWhere((t) => t.name == typeStr);
    } catch (_) {
      return POIType.other;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [coordinates.longitude, coordinates.latitude],
        },
        'properties': {
          'id': id,
          'type': type.name,
          'name': name,
          'description': description,
          'tags': tags,
        },
      };

  /// Get additional details from OSM tags
  String? get elevation => tags['ele']?.toString();
  String? get capacity => tags['capacity']?.toString();
  String? get fee => tags['fee']?.toString();
  String? get openingHours => tags['opening_hours']?.toString();
  String? get website => tags['website']?.toString() ?? tags['contact:website']?.toString();
  String? get phone => tags['phone']?.toString() ?? tags['contact:phone']?.toString();
}
