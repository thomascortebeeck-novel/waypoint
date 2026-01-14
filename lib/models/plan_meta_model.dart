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
  /// FAQ items shared across all versions
  final List<FAQItem> faqItems;

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
  );

  /// Convert legacy Plan to PlanMeta (for migration)
  factory PlanMeta.fromPlan(Plan plan) {
    // Collect FAQ items from all versions (for backward compatibility)
    // In the new architecture, FAQ is plan-level
    final faqItems = plan.versions.isNotEmpty && plan.versions.first.faqItems.isNotEmpty
        ? plan.versions.first.faqItems
        : const <FAQItem>[];
    
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
      faqItems: faqItems,
    );
  }
}
