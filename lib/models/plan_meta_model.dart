import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';

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
  /// Lightweight version summaries for display (no heavy data)
  final List<VersionSummary> versionSummaries;

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
    this.versionSummaries = const [],
  });

  double get minPrice => versionSummaries.isEmpty
      ? basePrice
      : versionSummaries.map((v) => v.price).reduce((a, b) => a < b ? a : b);

  String get difficultyRange {
    if (versionSummaries.isEmpty) return 'Moderate';
    final difficulties = versionSummaries
        .where((v) => v.difficulty != Difficulty.none)
        .map((v) => v.difficulty.name)
        .toSet()
        .toList();
    if (difficulties.isEmpty) return '';
    if (difficulties.length == 1) return difficulties.first.toUpperCase();
    return 'VARIOUS';
  }

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
    versionSummaries: (json['version_summaries'] as List<dynamic>?)
        ?.map((v) => VersionSummary.fromJson(v as Map<String, dynamic>))
        .toList() ?? [],
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
    'version_summaries': versionSummaries.map((v) => v.toJson()).toList(),
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
    List<VersionSummary>? versionSummaries,
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
    versionSummaries: versionSummaries ?? this.versionSummaries,
  );

  /// Convert legacy Plan to PlanMeta (for migration)
  factory PlanMeta.fromPlan(Plan plan) => PlanMeta(
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
    versionSummaries: plan.versions.map((v) => VersionSummary.fromPlanVersion(v)).toList(),
  );
}

/// Lightweight version summary for plan listings
class VersionSummary {
  final String id;
  final String name;
  final int durationDays;
  final Difficulty difficulty;
  final ComfortType comfortType;
  final double price;
  /// Lightweight day summaries
  final List<DaySummary> daySummaries;

  VersionSummary({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.difficulty,
    required this.comfortType,
    required this.price,
    this.daySummaries = const [],
  });

  factory VersionSummary.fromJson(Map<String, dynamic> json) => VersionSummary(
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
    daySummaries: (json['day_summaries'] as List<dynamic>?)
        ?.map((d) => DaySummary.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'duration_days': durationDays,
    'difficulty': difficulty.name,
    'comfort_type': comfortType.name,
    'price': price,
    'day_summaries': daySummaries.map((d) => d.toJson()).toList(),
  };

  /// Convert from PlanVersion (for migration)
  factory VersionSummary.fromPlanVersion(PlanVersion version) => VersionSummary(
    id: version.id,
    name: version.name,
    durationDays: version.durationDays,
    difficulty: version.difficulty,
    comfortType: version.comfortType,
    price: version.price,
    daySummaries: version.days.map((d) => DaySummary.fromDayItinerary(d)).toList(),
  );
}

/// Lightweight day summary for version listings
class DaySummary {
  final int dayNum;
  final String title;
  final double distanceKm;
  final int estimatedTimeMinutes;

  DaySummary({
    required this.dayNum,
    required this.title,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
  });

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
    dayNum: json['day_num'] as int,
    title: json['title'] as String,
    distanceKm: (json['distance_km'] as num).toDouble(),
    estimatedTimeMinutes: json['estimated_time_minutes'] as int,
  );

  Map<String, dynamic> toJson() => {
    'day_num': dayNum,
    'title': title,
    'distance_km': distanceKm,
    'estimated_time_minutes': estimatedTimeMinutes,
  };

  /// Convert from DayItinerary (for migration)
  factory DaySummary.fromDayItinerary(DayItinerary day) => DaySummary(
    dayNum: day.dayNum,
    title: day.title,
    distanceKm: day.distanceKm,
    estimatedTimeMinutes: day.estimatedTimeMinutes,
  );
}
