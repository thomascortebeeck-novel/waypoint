import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/review_model.dart';

enum Difficulty { none, easy, moderate, hard, extreme }
enum ComfortType { none, comfort, extreme }
enum TransportationType { car, flying, boat, foot, bike, train, bus, taxi }

// Activity categorization enums
enum ActivityCategory {
  hiking,       // 🥾 Hiking
  cycling,      // 🚴 Cycling
  skis,         // ⛷️ Skiing
  climbing,     // 🧗 Climbing
  cityTrips,    // 🏙️ City Trips
  tours,        // 🌏 Tours
  roadTripping  // 🚗 Road Tripping
}

enum AccommodationType {
  comfort,  // Stay at local accommodations (hotels, hostels, huts, lodges)
  adventure // Bring your own shelter (tent, campervan, bivouac)
}

enum ExperienceLevel {
  beginner,     // 🟢 First-time adventurers, easy pace
  intermediate, // 🟡 Some experience needed, moderate challenge
  expert        // 🔴 Advanced skills required, high difficulty
}

/// Maps ActivityCategory to Mapbox routing profile
String getMapboxProfile(ActivityCategory? category) {
  switch (category) {
    case ActivityCategory.cycling:
      return 'cycling';
    case ActivityCategory.roadTripping:
      return 'driving';
    case ActivityCategory.hiking:
    case ActivityCategory.cityTrips:
    case ActivityCategory.tours:
    case ActivityCategory.skis:
    case ActivityCategory.climbing:
    default:
      // Walking profile for hiking, city trips, tours (skiing/climbing use walking time as base)
      return 'walking';
  }
}

/// Represents a trekking/travel plan
class Plan {
  final String id;
  final String name;
  final String description;
  final String heroImageUrl;
  final String location;
  final double basePrice;
  final String creatorId;
  final String creatorName;
  final List<PlanVersion> versions;
  final bool isFeatured;
  final bool isDiscover; // curated by admin for Discover rail
  final bool isPublished;
  final int favoriteCount;
  final int salesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ActivityCategory? activityCategory;
  final AccommodationType? accommodationType;
  /// Optional maximum group size for trips using this plan (null = unlimited)
  final int? maxGroupSize;
  /// FAQ items shared across all versions (plan-level)
  final List<FAQItem> faqItems;
  /// Review statistics for this plan
  final ReviewStats? reviewStats;
  /// Best season start month (1-12, where 1 = January)
  final int? bestSeasonStartMonth;
  /// Best season end month (1-12, where 1 = January)
  final int? bestSeasonEndMonth;
  /// Whether to show price estimates from waypoints on detail pages
  final bool showPrices;

  Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.heroImageUrl,
    required this.location,
    required this.basePrice,
    required this.creatorId,
    required this.creatorName,
    required this.versions,
    this.isFeatured = false,
    this.isDiscover = false,
    this.isPublished = true,
    this.favoriteCount = 0,
    this.salesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.activityCategory,
    this.accommodationType,
    this.maxGroupSize,
    this.faqItems = const [],
    this.reviewStats,
    this.bestSeasonStartMonth,
    this.bestSeasonEndMonth,
    this.showPrices = false,
  });

  double get minPrice => versions.isEmpty 
      ? basePrice 
      : versions.map((v) => v.price).reduce((a, b) => a < b ? a : b);
      
  String get difficultyRange {
    if (versions.isEmpty) return 'Moderate';
    // Filter out "none" difficulties
    final difficulties = versions
        .where((v) => v.difficulty != Difficulty.none)
        .map((v) => v.difficulty.name)
        .toSet()
        .toList();
    if (difficulties.isEmpty) return ''; // All are "none"
    if (difficulties.length == 1) return difficulties.first.toUpperCase();
    return 'VARIOUS';
  }

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      heroImageUrl: json['hero_image_url'] as String,
      location: json['location'] as String,
      basePrice: (json['base_price'] as num).toDouble(),
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      versions: (json['versions'] as List<dynamic>?)
          ?.map((v) => PlanVersion.fromJson(v as Map<String, dynamic>))
          .toList() ?? [],
      isFeatured: json['is_featured'] as bool? ?? false,
      isDiscover: json['is_discover'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
      activityCategory: json['activity_category'] != null
          ? ActivityCategory.values.firstWhere(
              (e) => e.name == json['activity_category'],
              orElse: () => ActivityCategory.hiking,
            )
          : null,
      accommodationType: json['accommodation_type'] != null
          ? AccommodationType.values.firstWhere(
              (e) => e.name == json['accommodation_type'],
              orElse: () => AccommodationType.comfort,
            )
          : null,
      maxGroupSize: json['max_group_size'] as int?,
      faqItems: (json['faq_items'] as List<dynamic>?)
          ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
      reviewStats: json['review_stats'] != null
          ? ReviewStats.fromJson(json['review_stats'] as Map<String, dynamic>)
          : null,
      bestSeasonStartMonth: json['best_season_start_month'] as int?,
      bestSeasonEndMonth: json['best_season_end_month'] as int?,
      showPrices: json['show_prices'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'hero_image_url': heroImageUrl,
      'location': location,
      'base_price': basePrice,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'versions': versions.map((v) => v.toJson()).toList(),
      'is_featured': isFeatured,
      'is_discover': isDiscover,
      'is_published': isPublished,
      'favorite_count': favoriteCount,
      'sales_count': salesCount,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'activity_category': activityCategory?.name,
      'accommodation_type': accommodationType?.name,
      if (maxGroupSize != null) 'max_group_size': maxGroupSize,
      'faq_items': faqItems.map((f) => f.toJson()).toList(),
      if (reviewStats != null) 'review_stats': reviewStats!.toJson(),
      if (bestSeasonStartMonth != null) 'best_season_start_month': bestSeasonStartMonth,
      if (bestSeasonEndMonth != null) 'best_season_end_month': bestSeasonEndMonth,
      'show_prices': showPrices,
    };
  }

  Plan copyWith({
    String? id,
    String? name,
    String? description,
    String? heroImageUrl,
    String? location,
    double? basePrice,
    String? creatorId,
    String? creatorName,
    List<PlanVersion>? versions,
    bool? isFeatured,
    bool? isDiscover,
    bool? isPublished,
    int? favoriteCount,
    int? salesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    ActivityCategory? activityCategory,
    AccommodationType? accommodationType,
    int? maxGroupSize,
    List<FAQItem>? faqItems,
    ReviewStats? reviewStats,
    int? bestSeasonStartMonth,
    int? bestSeasonEndMonth,
    bool? showPrices,
  }) {
    return Plan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      location: location ?? this.location,
      basePrice: basePrice ?? this.basePrice,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      versions: versions ?? this.versions,
      isFeatured: isFeatured ?? this.isFeatured,
      isDiscover: isDiscover ?? this.isDiscover,
      isPublished: isPublished ?? this.isPublished,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      salesCount: salesCount ?? this.salesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activityCategory: activityCategory ?? this.activityCategory,
      accommodationType: accommodationType ?? this.accommodationType,
      maxGroupSize: maxGroupSize ?? this.maxGroupSize,
      faqItems: faqItems ?? this.faqItems,
      reviewStats: reviewStats ?? this.reviewStats,
      bestSeasonStartMonth: bestSeasonStartMonth ?? this.bestSeasonStartMonth,
      bestSeasonEndMonth: bestSeasonEndMonth ?? this.bestSeasonEndMonth,
      showPrices: showPrices ?? this.showPrices,
    );
  }
}

class TransportationOption {
  final String title;
  final String description;
  final List<TransportationType> types;

  TransportationOption({
    required this.title,
    required this.description,
    required this.types,
  });

  factory TransportationOption.fromJson(Map<String, dynamic> json) {
    return TransportationOption(
      title: json['title'] as String,
      description: json['description'] as String,
      types: (json['types'] as List<dynamic>?)
          ?.map((t) => TransportationType.values.firstWhere(
                (type) => type.name == t,
                orElse: () => TransportationType.car,
              ))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'types': types.map((t) => t.name).toList(),
    };
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

class PackingItem {
  final String id;
  final String name;
  final String? description; // Optional markdown description with links

  PackingItem({
    required this.id,
    required this.name,
    this.description,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json) {
    return PackingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  };
}

class PackingCategory {
  final String name;
  final List<PackingItem> items;
  final String? description; // Optional markdown description with links

  PackingCategory({
    required this.name,
    this.items = const [],
    this.description,
  });

  factory PackingCategory.fromJson(Map<String, dynamic> json) {
    List<PackingItem> items = [];
    
    // Handle backwards compatibility
    if (json['items'] is List) {
      final itemsJson = json['items'] as List;
      if (itemsJson.isNotEmpty) {
        if (itemsJson.first is String) {
          // Old format: List<String> - migrate to PackingItem
          items = itemsJson.asMap().entries.map((entry) {
            return PackingItem(
              id: 'legacy_${entry.key}',
              name: entry.value as String,
            );
          }).toList();
        } else {
          // New format: List<PackingItem>
          items = itemsJson.map((item) => PackingItem.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    }
    
    return PackingCategory(
      name: json['name'] as String,
      items: items,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      if (description != null) 'description': description,
    };
  }
}

class PlanVersion {
  final String id;
  final String name;
  final int durationDays;
  final Difficulty difficulty;
  final ComfortType comfortType;
  final double price;
  final List<DayItinerary> days;
  // Packing categories with optional descriptions
  final List<PackingCategory> packingCategories;
  // How to get there options
  final List<TransportationOption> transportationOptions;
  // Frequently asked questions
  final List<FAQItem> faqItems;
  final ExperienceLevel? experienceLevel;

  PlanVersion({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.difficulty,
    required this.comfortType,
    required this.price,
    required this.days,
    this.packingCategories = const [],
    this.transportationOptions = const [],
    this.faqItems = const [],
    this.experienceLevel,
  });

  factory PlanVersion.fromJson(Map<String, dynamic> json) {
    // Handle backwards compatibility for old packing_list format
    List<PackingCategory> packingCategories = [];
    if (json['packing_categories'] != null) {
      // New format: array of PackingCategory objects
      packingCategories = (json['packing_categories'] as List<dynamic>)
          .map((c) => PackingCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    } else if (json['packing_list'] != null) {
      // Old format: flat array of strings - migrate to single "General" category
      final oldList = List<String>.from(json['packing_list']);
      if (oldList.isNotEmpty) {
        packingCategories = [
          PackingCategory(
            name: 'General',
            items: oldList.asMap().entries.map((entry) => PackingItem(
              id: 'legacy_${entry.key}',
              name: entry.value,
            )).toList(),
          )
        ];
      }
    }
    
    return PlanVersion(
      id: json['id'] as String,
      name: json['name'] as String,
      durationDays: json['duration_days'] as int,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => Difficulty.moderate,
      ),
      comfortType: ComfortType.values.firstWhere(
        (c) => c.name == json['comfort_type'],
        orElse: () => ComfortType.comfort,
      ),
      price: (json['price'] as num).toDouble(),
      days: (json['days'] as List<dynamic>?)
          ?.map((d) => DayItinerary.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
      packingCategories: packingCategories,
      transportationOptions: (json['transportation_options'] as List<dynamic>?)
          ?.map((t) => TransportationOption.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      faqItems: (json['faq_items'] as List<dynamic>?)
          ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
      experienceLevel: json['experience_level'] != null
          ? ExperienceLevel.values.firstWhere(
              (e) => e.name == json['experience_level'],
              orElse: () => ExperienceLevel.beginner,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration_days': durationDays,
      'difficulty': difficulty.name,
      'comfort_type': comfortType.name,
      'price': price,
      'days': days.map((d) => d.toJson()).toList(),
      'packing_categories': packingCategories.map((c) => c.toJson()).toList(),
      'transportation_options': transportationOptions.map((t) => t.toJson()).toList(),
      'faq_items': faqItems.map((f) => f.toJson()).toList(),
      'experience_level': experienceLevel?.name,
    };
  }
}

class DayItinerary {
  final int dayNum;
  final String title;
  final String description;
  final double distanceKm;
  final int estimatedTimeMinutes;
  final StayInfo? stay;
  final List<AccommodationInfo> accommodations; // Multiple accommodations
  final List<RestaurantInfo> restaurants; // Breakfast, lunch, dinner
  final List<ActivityInfo> activities; // Activities for the day
  final List<String> photos;
  // Optional start/end coordinates for the day
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  // Optional route polyline and metrics for the day
  final DayRoute? route;

  DayItinerary({
    required this.dayNum,
    required this.title,
    required this.description,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    this.stay,
    this.accommodations = const [],
    this.restaurants = const [],
    this.activities = const [],
    this.photos = const [],
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.route,
  });

  Duration get estimatedTime => Duration(minutes: estimatedTimeMinutes);

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      dayNum: json['day_num'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      estimatedTimeMinutes: json['estimated_time_minutes'] as int,
      stay: json['stay'] != null 
          ? StayInfo.fromJson(json['stay'] as Map<String, dynamic>)
          : null,
      accommodations: (json['accommodations'] as List<dynamic>?)
          ?.map((a) => AccommodationInfo.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      restaurants: (json['restaurants'] as List<dynamic>?)
          ?.map((r) => RestaurantInfo.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
      activities: (json['activities'] as List<dynamic>?)
          ?.map((a) => ActivityInfo.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      photos: List<String>.from(json['photos'] ?? []),
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      endLat: (json['end_lat'] as num?)?.toDouble(),
      endLng: (json['end_lng'] as num?)?.toDouble(),
      route: json['route'] != null ? DayRoute.fromJson(json['route'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_num': dayNum,
      'title': title,
      'description': description,
      'distance_km': distanceKm,
      'estimated_time_minutes': estimatedTimeMinutes,
      'stay': stay?.toJson(),
      'accommodations': accommodations.map((a) => a.toJson()).toList(),
      'restaurants': restaurants.map((r) => r.toJson()).toList(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'photos': photos,
      if (startLat != null) 'start_lat': startLat,
      if (startLng != null) 'start_lng': startLng,
      if (endLat != null) 'end_lat': endLat,
      if (endLng != null) 'end_lng': endLng,
      if (route != null) 'route': route!.toJson(),
    };
  }
}

/// A single elevation point with distance and elevation
class ElevationPoint {
  final double distance; // meters from start
  final double elevation; // meters

  const ElevationPoint(this.distance, this.elevation);

  factory ElevationPoint.fromJson(Map<String, dynamic> json) => ElevationPoint(
    (json['d'] as num).toDouble(),
    (json['e'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'d': distance, 'e': elevation};

  /// Create from legacy [distance, elevation] array format
  factory ElevationPoint.fromList(List<double> list) => ElevationPoint(
    list[0],
    list[1],
  );

  /// Convert to legacy [distance, elevation] array format for backwards compatibility
  List<double> toList() => [distance, elevation];
}

/// Route polyline + metrics stored for a given day
class DayRoute {
  final Map<String, dynamic> geometry; // GeoJSON LineString
  final double distance; // meters
  final int duration; // seconds
  final List<Map<String, double>> routePoints; // lat/lng points for the route path
  final List<ElevationPoint>? elevationProfile; // elevation points along route
  final double? ascent; // meters
  final double? descent; // meters
  final List<Map<String, dynamic>> poiWaypoints; // Points of interest waypoints

  const DayRoute({
    required this.geometry,
    required this.distance,
    required this.duration,
    required this.routePoints,
    this.elevationProfile,
    this.ascent,
    this.descent,
    this.poiWaypoints = const [],
  });

  // Backwards compatibility getter
  List<Map<String, double>> get waypoints => routePoints;

  /// Get elevation profile as list of [distance, elevation] arrays (legacy format)
  List<List<double>>? get elevationProfileAsLists =>
      elevationProfile?.map((p) => p.toList()).toList();

  factory DayRoute.fromJson(Map<String, dynamic> json) {
    // Parse elevation profile - support both old nested array format and new map format
    List<ElevationPoint>? elevationProfile;
    final rawElevation = json['elevationProfile'] as List?;
    if (rawElevation != null && rawElevation.isNotEmpty) {
      if (rawElevation.first is List) {
        // Legacy format: [[distance, elevation], ...]
        elevationProfile = rawElevation
            .map((p) => ElevationPoint.fromList(
                  (p as List).map((n) => (n as num).toDouble()).toList(),
                ))
            .toList();
      } else if (rawElevation.first is Map) {
        // New format: [{d: distance, e: elevation}, ...]
        elevationProfile = rawElevation
            .map((p) => ElevationPoint.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    }

    // Normalize geometry: support Firestore-safe representation where coordinates
    // can be a list of maps instead of nested arrays.
    Map<String, dynamic> normalizedGeometry = const {};
    try {
      final raw = json['geometry'];
      if (raw is Map) {
        final g = Map<String, dynamic>.from(raw);
        final coords = g['coordinates'];
        if (coords is List && coords.isNotEmpty) {
          normalizedGeometry = {
            'type': g['type'] ?? 'LineString',
            'coordinates': List.from(coords),
          };
        } else {
          normalizedGeometry = {'type': g['type'] ?? 'LineString', 'coordinates': const []};
        }
      }
    } catch (_) {
      normalizedGeometry = const {};
    }

    return DayRoute(
      geometry: normalizedGeometry,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      // Support both old 'waypoints' and new 'routePoints' field names
      routePoints: ((json['routePoints'] ?? json['waypoints']) as List? ?? const [])
          .map((e) => {
            'lat': (e['lat'] as num).toDouble(),
            'lng': (e['lng'] as num).toDouble(),
          })
          .toList(),
      elevationProfile: elevationProfile,
      ascent: (json['ascent'] as num?)?.toDouble(),
      descent: (json['descent'] as num?)?.toDouble(),
      poiWaypoints: ((json['poiWaypoints'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    // Ensure Firestore-safe geometry (no nested arrays)
    // IMPORTANT: Always preserve the actual geometry coordinates (snapped trail path)
    // DO NOT replace with routePoints, which only contains user-placed waypoints
    'geometry': {
      'type': geometry['type'] ?? 'LineString',
      'coordinates': (() {
        final coords = geometry['coordinates'];
        if (coords is List && coords.isNotEmpty) {
          if (coords.first is List && (coords.first as List).length >= 2) {
            // Convert [[lng,lat], ...] -> [{lng,lat}, ...]
            return coords
                .map((c) => {
                      'lng': (c[0] as num).toDouble(),
                      'lat': (c[1] as num).toDouble(),
                    })
                .toList();
          } else if (coords.first is Map) {
            // Already Firestore-safe
            return coords
                .map((c) => {
                      'lng': ((c as Map)['lng'] as num).toDouble(),
                      'lat': ((c)['lat'] as num).toDouble(),
                    })
                .toList();
          }
        }
        // Fallback to routePoints only if geometry has no coordinates
        if (routePoints.isNotEmpty) {
          return routePoints
              .map((p) => {'lng': p['lng'], 'lat': p['lat']})
              .toList();
        }
        return const <Map<String, double>>[];
      })(),
    },
    'distance': distance,
    'duration': duration,
    'routePoints': routePoints.map((w) => {'lat': w['lat'], 'lng': w['lng']}).toList(),
    // Also write as 'waypoints' for backwards compatibility
    'waypoints': routePoints.map((w) => {'lat': w['lat'], 'lng': w['lng']}).toList(),
    // Store elevation profile as list of maps (Firestore-compatible, no nested arrays)
    if (elevationProfile != null) 'elevationProfile': elevationProfile!.map((p) => p.toJson()).toList(),
    if (ascent != null) 'ascent': ascent,
    if (descent != null) 'descent': descent,
    if (poiWaypoints.isNotEmpty) 'poiWaypoints': poiWaypoints,
  };

  DayRoute copyWith({
    Map<String, dynamic>? geometry,
    double? distance,
    int? duration,
    List<Map<String, double>>? routePoints,
    List<ElevationPoint>? elevationProfile,
    double? ascent,
    double? descent,
    List<Map<String, dynamic>>? poiWaypoints,
  }) => DayRoute(
    geometry: geometry ?? this.geometry,
    distance: distance ?? this.distance,
    duration: duration ?? this.duration,
    routePoints: routePoints ?? this.routePoints,
    elevationProfile: elevationProfile ?? this.elevationProfile,
    ascent: ascent ?? this.ascent,
    descent: descent ?? this.descent,
    poiWaypoints: poiWaypoints ?? this.poiWaypoints,
  );
}

class StayInfo {
  final String name;
  final String type;
  final String? bookingLink;
  final double? cost;
  // Optional rich link preview fields (generated from the bookingLink)
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkSiteName;

  StayInfo({
    required this.name,
    required this.type,
    this.bookingLink,
    this.cost,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkSiteName,
  });

  factory StayInfo.fromJson(Map<String, dynamic> json) {
    return StayInfo(
      name: json['name'] as String,
      type: json['type'] as String,
      bookingLink: json['booking_link'] as String?,
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      linkTitle: json['link_title'] as String?,
      linkDescription: json['link_description'] as String?,
      linkImageUrl: json['link_image_url'] as String?,
      linkSiteName: json['link_site_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'booking_link': bookingLink,
      'cost': cost,
      if (linkTitle != null) 'link_title': linkTitle,
      if (linkDescription != null) 'link_description': linkDescription,
      if (linkImageUrl != null) 'link_image_url': linkImageUrl,
      if (linkSiteName != null) 'link_site_name': linkSiteName,
    };
  }
}

/// Accommodation information for a day
class AccommodationInfo {
  final String name;
  final String type; // Hotel, Hostel, Camping, Lodge, etc.
  final String? bookingLink;
  final double? cost;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkSiteName;

  AccommodationInfo({
    required this.name,
    required this.type,
    this.bookingLink,
    this.cost,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkSiteName,
  });

  factory AccommodationInfo.fromJson(Map<String, dynamic> json) => AccommodationInfo(
    name: json['name'] as String,
    type: json['type'] as String,
    bookingLink: json['booking_link'] as String?,
    cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
    linkTitle: json['link_title'] as String?,
    linkDescription: json['link_description'] as String?,
    linkImageUrl: json['link_image_url'] as String?,
    linkSiteName: json['link_site_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    if (bookingLink != null) 'booking_link': bookingLink,
    if (cost != null) 'cost': cost,
    if (linkTitle != null) 'link_title': linkTitle,
    if (linkDescription != null) 'link_description': linkDescription,
    if (linkImageUrl != null) 'link_image_url': linkImageUrl,
    if (linkSiteName != null) 'link_site_name': linkSiteName,
  };
}

enum MealType { breakfast, lunch, dinner }

/// Restaurant information for a meal
class RestaurantInfo {
  final String name;
  final MealType mealType;
  final String? bookingLink;
  final double? cost;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkSiteName;

  RestaurantInfo({
    required this.name,
    required this.mealType,
    this.bookingLink,
    this.cost,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkSiteName,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) => RestaurantInfo(
    name: json['name'] as String,
    mealType: MealType.values.firstWhere(
      (m) => m.name == json['meal_type'],
      orElse: () => MealType.lunch,
    ),
    bookingLink: json['booking_link'] as String?,
    cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
    linkTitle: json['link_title'] as String?,
    linkDescription: json['link_description'] as String?,
    linkImageUrl: json['link_image_url'] as String?,
    linkSiteName: json['link_site_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'meal_type': mealType.name,
    if (bookingLink != null) 'booking_link': bookingLink,
    if (cost != null) 'cost': cost,
    if (linkTitle != null) 'link_title': linkTitle,
    if (linkDescription != null) 'link_description': linkDescription,
    if (linkImageUrl != null) 'link_image_url': linkImageUrl,
    if (linkSiteName != null) 'link_site_name': linkSiteName,
  };
}

/// Activity information for a day
class ActivityInfo {
  final String name;
  final String description;
  final String? bookingLink;
  final double? cost;
  final int? durationMinutes;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkSiteName;

  ActivityInfo({
    required this.name,
    required this.description,
    this.bookingLink,
    this.cost,
    this.durationMinutes,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkSiteName,
  });

  factory ActivityInfo.fromJson(Map<String, dynamic> json) => ActivityInfo(
    name: json['name'] as String,
    description: json['description'] as String,
    bookingLink: json['booking_link'] as String?,
    cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
    durationMinutes: json['duration_minutes'] as int?,
    linkTitle: json['link_title'] as String?,
    linkDescription: json['link_description'] as String?,
    linkImageUrl: json['link_image_url'] as String?,
    linkSiteName: json['link_site_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    if (bookingLink != null) 'booking_link': bookingLink,
    if (cost != null) 'cost': cost,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (linkTitle != null) 'link_title': linkTitle,
    if (linkDescription != null) 'link_description': linkDescription,
    if (linkImageUrl != null) 'link_image_url': linkImageUrl,
    if (linkSiteName != null) 'link_site_name': linkSiteName,
  };
}
