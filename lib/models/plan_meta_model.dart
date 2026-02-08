import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';

/// Lightweight version summary for dropdown display
/// Only contains essential data needed for version selection UI
class VersionSummary {
  final String id;
  final String name;
  final int durationDays;
  final Difficulty difficulty;
  /// Pre-calculated stats for display without loading full version
  final double? totalDistanceKm;
  final double? totalElevationM;
  final int? waypointCount;

  const VersionSummary({
    required this.id,
    required this.name,
    required this.durationDays,
    this.difficulty = Difficulty.none,
    this.totalDistanceKm,
    this.totalElevationM,
    this.waypointCount,
  });

  factory VersionSummary.fromJson(Map<String, dynamic> json) => VersionSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    durationDays: json['duration_days'] as int,
    difficulty: json['difficulty'] != null 
        ? Difficulty.values.firstWhere(
            (d) => d.name == json['difficulty'],
            orElse: () => Difficulty.none,
          )
        : Difficulty.none,
    totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
    totalElevationM: (json['total_elevation_m'] as num?)?.toDouble(),
    waypointCount: json['waypoint_count'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'duration_days': durationDays,
    'difficulty': difficulty.name,
    if (totalDistanceKm != null) 'total_distance_km': totalDistanceKm,
    if (totalElevationM != null) 'total_elevation_m': totalElevationM,
    if (waypointCount != null) 'waypoint_count': waypointCount,
  };

  /// Create from PlanVersion (calculates stats)
  factory VersionSummary.fromPlanVersion(PlanVersion version) {
    double totalDistance = 0;
    double totalElevation = 0;
    int waypointCount = 0;
    
    for (final day in version.days) {
      totalDistance += day.route?.distance ?? 0;
      totalElevation += day.route?.ascent ?? 0;
      waypointCount += day.route?.poiWaypoints.length ?? 0;
      // Add legacy waypoints
      waypointCount += day.accommodations.length;
      waypointCount += day.restaurants.length;
      waypointCount += day.activities.length;
    }
    
    return VersionSummary(
      id: version.id,
      name: version.name,
      durationDays: version.durationDays,
      difficulty: version.difficulty,
      totalDistanceKm: totalDistance / 1000,
      totalElevationM: totalElevation,
      waypointCount: waypointCount,
    );
  }
}

/// Lightweight plan metadata for marketplace listings
/// Stored in: plans/{planId}
class PlanMeta {
  final String id;
  final String name;
  final String description;
  final String heroImageUrl;
  final String location;
  final double basePrice;
  final String creatorId;
  final String creatorName;
  final bool isFeatured;
  final bool isDiscover;
  final bool isPublished;
  final int favoriteCount;
  final int salesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// FAQ items shared across all versions
  final List<FAQItem> faqItems;
  /// Activity category (optional)
  final ActivityCategory? activityCategory;
  /// Accommodation type (optional, auto-set to comfort for city/regional tours)
  final AccommodationType? accommodationType;
  /// Lightweight version summaries for dropdown display (loaded without full version data)
  final List<VersionSummary> versionSummaries;
  /// Best season start month (1-12, where 1 = January)
  final int? bestSeasonStartMonth;
  /// Best season end month (1-12, where 1 = January)
  final int? bestSeasonEndMonth;
  /// Whether to show price estimates from waypoints on detail pages
  final bool showPrices;

  PlanMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.heroImageUrl,
    required this.location,
    required this.basePrice,
    required this.creatorId,
    required this.creatorName,
    this.isFeatured = false,
    this.isDiscover = false,
    this.isPublished = true,
    this.favoriteCount = 0,
    this.salesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.faqItems = const [],
    this.activityCategory,
    this.accommodationType,
    this.versionSummaries = const [],
    this.bestSeasonStartMonth,
    this.bestSeasonEndMonth,
    this.showPrices = false,
  });

  factory PlanMeta.fromJson(Map<String, dynamic> json) => PlanMeta(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    heroImageUrl: json['hero_image_url'] as String,
    location: json['location'] as String,
    basePrice: (json['base_price'] as num).toDouble(),
    creatorId: json['creator_id'] as String,
    creatorName: json['creator_name'] as String,
    isFeatured: json['is_featured'] as bool? ?? false,
    isDiscover: json['is_discover'] as bool? ?? false,
    isPublished: json['is_published'] as bool? ?? true,
    favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
    salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
    faqItems: (json['faq_items'] as List<dynamic>?)
        ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
        .toList() ?? [],
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
    versionSummaries: (json['version_summaries'] as List<dynamic>?)
        ?.map((v) => VersionSummary.fromJson(v as Map<String, dynamic>))
        .toList() ?? [],
    bestSeasonStartMonth: json['best_season_start_month'] as int?,
    bestSeasonEndMonth: json['best_season_end_month'] as int?,
    showPrices: json['show_prices'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'hero_image_url': heroImageUrl,
    'location': location,
    'base_price': basePrice,
    'creator_id': creatorId,
    'creator_name': creatorName,
    'is_featured': isFeatured,
    'is_discover': isDiscover,
    'is_published': isPublished,
    'favorite_count': favoriteCount,
    'sales_count': salesCount,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    'faq_items': faqItems.map((f) => f.toJson()).toList(),
    'activity_category': activityCategory?.name,
    'accommodation_type': accommodationType?.name,
    'version_summaries': versionSummaries.map((v) => v.toJson()).toList(),
    if (bestSeasonStartMonth != null) 'best_season_start_month': bestSeasonStartMonth,
    if (bestSeasonEndMonth != null) 'best_season_end_month': bestSeasonEndMonth,
    'show_prices': showPrices,
  };

  PlanMeta copyWith({
    String? id,
    String? name,
    String? description,
    String? heroImageUrl,
    String? location,
    double? basePrice,
    String? creatorId,
    String? creatorName,
    bool? isFeatured,
    bool? isDiscover,
    bool? isPublished,
    int? favoriteCount,
    int? salesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<FAQItem>? faqItems,
    ActivityCategory? activityCategory,
    AccommodationType? accommodationType,
    List<VersionSummary>? versionSummaries,
    int? bestSeasonStartMonth,
    int? bestSeasonEndMonth,
    bool? showPrices,
  }) => PlanMeta(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    heroImageUrl: heroImageUrl ?? this.heroImageUrl,
    location: location ?? this.location,
    basePrice: basePrice ?? this.basePrice,
    creatorId: creatorId ?? this.creatorId,
    creatorName: creatorName ?? this.creatorName,
    isFeatured: isFeatured ?? this.isFeatured,
    isDiscover: isDiscover ?? this.isDiscover,
    isPublished: isPublished ?? this.isPublished,
    favoriteCount: favoriteCount ?? this.favoriteCount,
    salesCount: salesCount ?? this.salesCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    faqItems: faqItems ?? this.faqItems,
    activityCategory: activityCategory ?? this.activityCategory,
    accommodationType: accommodationType ?? this.accommodationType,
    versionSummaries: versionSummaries ?? this.versionSummaries,
    bestSeasonStartMonth: bestSeasonStartMonth ?? this.bestSeasonStartMonth,
    bestSeasonEndMonth: bestSeasonEndMonth ?? this.bestSeasonEndMonth,
    showPrices: showPrices ?? this.showPrices,
  );

  /// Convert legacy Plan to PlanMeta (for migration)
  factory PlanMeta.fromPlan(Plan plan) {
    return PlanMeta(
      id: plan.id,
      name: plan.name,
      description: plan.description,
      heroImageUrl: plan.heroImageUrl,
      location: plan.location,
      basePrice: plan.basePrice,
      creatorId: plan.creatorId,
      creatorName: plan.creatorName,
      isFeatured: plan.isFeatured,
      isDiscover: plan.isDiscover,
      isPublished: plan.isPublished,
      favoriteCount: plan.favoriteCount,
      salesCount: plan.salesCount,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
      faqItems: plan.faqItems,
      activityCategory: plan.activityCategory,
      accommodationType: plan.accommodationType,
      versionSummaries: plan.versions
          .map((v) => VersionSummary.fromPlanVersion(v))
          .toList(),
      bestSeasonStartMonth: plan.bestSeasonStartMonth,
      bestSeasonEndMonth: plan.bestSeasonEndMonth,
      showPrices: plan.showPrices,
    );
  }
}
