import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';

/// Full version data stored in subcollection
/// Stored in: plans/{planId}/versions/{versionId}
class PlanVersionDoc {
  final String id;
  final String planId;
  final String name;
  final int durationDays;
  final Difficulty difficulty;
  final ComfortType comfortType;
  final double price;
  final List<PackingCategory> packingCategories;
  final List<TransportationOption> transportationOptions;
  final List<FAQItem> faqItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanVersionDoc({
    required this.id,
    required this.planId,
    required this.name,
    required this.durationDays,
    required this.difficulty,
    required this.comfortType,
    required this.price,
    this.packingCategories = const [],
    this.transportationOptions = const [],
    this.faqItems = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanVersionDoc.fromJson(Map<String, dynamic> json) {
    List<PackingCategory> packingCategories = [];
    if (json['packing_categories'] != null) {
      packingCategories = (json['packing_categories'] as List<dynamic>)
          .map((c) => PackingCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    } else if (json['packing_list'] != null) {
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

    return PlanVersionDoc(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
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
      packingCategories: packingCategories,
      transportationOptions: (json['transportation_options'] as List<dynamic>?)
          ?.map((t) => TransportationOption.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      faqItems: (json['faq_items'] as List<dynamic>?)
          ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'name': name,
    'duration_days': durationDays,
    'difficulty': difficulty.name,
    'comfort_type': comfortType.name,
    'price': price,
    'packing_categories': packingCategories.map((c) => c.toJson()).toList(),
    'transportation_options': transportationOptions.map((t) => t.toJson()).toList(),
    'faq_items': faqItems.map((f) => f.toJson()).toList(),
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  PlanVersionDoc copyWith({
    String? id,
    String? planId,
    String? name,
    int? durationDays,
    Difficulty? difficulty,
    ComfortType? comfortType,
    double? price,
    List<PackingCategory>? packingCategories,
    List<TransportationOption>? transportationOptions,
    List<FAQItem>? faqItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlanVersionDoc(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    name: name ?? this.name,
    durationDays: durationDays ?? this.durationDays,
    difficulty: difficulty ?? this.difficulty,
    comfortType: comfortType ?? this.comfortType,
    price: price ?? this.price,
    packingCategories: packingCategories ?? this.packingCategories,
    transportationOptions: transportationOptions ?? this.transportationOptions,
    faqItems: faqItems ?? this.faqItems,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Convert from legacy PlanVersion (for migration)
  /// NOTE: FAQ items are NOT copied - they should be stored at plan level
  factory PlanVersionDoc.fromPlanVersion(PlanVersion version, String planId) => PlanVersionDoc(
    id: version.id,
    planId: planId,
    name: version.name,
    durationDays: version.durationDays,
    difficulty: version.difficulty,
    comfortType: version.comfortType,
    price: version.price,
    packingCategories: version.packingCategories,
    transportationOptions: version.transportationOptions,
    faqItems: const [], // FAQ moved to plan level in new architecture
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// Convert to legacy PlanVersion (for backwards compatibility)
  PlanVersion toPlanVersion(List<DayItinerary> days) => PlanVersion(
    id: id,
    name: name,
    durationDays: durationDays,
    difficulty: difficulty,
    comfortType: comfortType,
    price: price,
    days: days,
    packingCategories: packingCategories,
    transportationOptions: transportationOptions,
    faqItems: faqItems,
  );
}
