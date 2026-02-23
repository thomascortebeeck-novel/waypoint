import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/adventure_context_model.dart';

/// Full version data stored in subcollection
/// Stored in: plans/{planId}/versions/{versionId}
/// 
/// Note: The following fields are stored at the PLAN level, not version level:
/// - price (plan.base_price)
/// - faq_items (plan.faq_items)
/// 
/// The following fields are DEPRECATED and removed:
/// - difficulty
/// - comfort_type
/// - experience_level
class PlanVersionDoc {
  final String id;
  final String planId;
  final String name;
  final int durationDays;
  final List<PackingCategory> packingCategories;
  final List<TransportationOption> transportationOptions;
  /// AI-generated travel preparation information (per-version)
  final Prepare? prepare;
  /// AI-generated local tips and cultural information (per-version)
  final LocalTips? localTips;
  /// Timestamp when AI info was last generated
  final DateTime? aiGeneratedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanVersionDoc({
    required this.id,
    required this.planId,
    required this.name,
    required this.durationDays,
    this.packingCategories = const [],
    this.transportationOptions = const [],
    this.prepare,
    this.localTips,
    this.aiGeneratedAt,
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
      packingCategories: packingCategories,
      transportationOptions: (json['transportation_options'] as List<dynamic>?)
          ?.map((t) => TransportationOption.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      prepare: json['prepare'] != null
          ? Prepare.fromJson(json['prepare'] as Map<String, dynamic>)
          : null,
      localTips: json['local_tips'] != null
          ? LocalTips.fromJson(json['local_tips'] as Map<String, dynamic>)
          : null,
      aiGeneratedAt: json['ai_generated_at'] != null
          ? (json['ai_generated_at'] as Timestamp).toDate()
          : null,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'name': name,
    'duration_days': durationDays,
    'packing_categories': packingCategories.map((c) => c.toJson()).toList(),
    'transportation_options': transportationOptions.map((t) => t.toJson()).toList(),
    if (prepare != null) 'prepare': prepare!.toJson(),
    if (localTips != null) 'local_tips': localTips!.toJson(),
    if (aiGeneratedAt != null) 'ai_generated_at': Timestamp.fromDate(aiGeneratedAt!),
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  PlanVersionDoc copyWith({
    String? id,
    String? planId,
    String? name,
    int? durationDays,
    List<PackingCategory>? packingCategories,
    List<TransportationOption>? transportationOptions,
    Prepare? prepare,
    LocalTips? localTips,
    DateTime? aiGeneratedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlanVersionDoc(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    name: name ?? this.name,
    durationDays: durationDays ?? this.durationDays,
    packingCategories: packingCategories ?? this.packingCategories,
    transportationOptions: transportationOptions ?? this.transportationOptions,
    prepare: prepare ?? this.prepare,
    localTips: localTips ?? this.localTips,
    aiGeneratedAt: aiGeneratedAt ?? this.aiGeneratedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Convert from legacy PlanVersion (for migration)
  /// NOTE: Deprecated fields (difficulty, comfortType, price, faqItems, experienceLevel)
  /// are NOT copied - they belong at plan level or are removed
  factory PlanVersionDoc.fromPlanVersion(PlanVersion version, String planId) => PlanVersionDoc(
    id: version.id,
    planId: planId,
    name: version.name,
    durationDays: version.durationDays,
    packingCategories: version.packingCategories,
    transportationOptions: version.transportationOptions,
    prepare: version.prepare,
    localTips: version.localTips,
    aiGeneratedAt: version.aiGeneratedAt,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// Convert to legacy PlanVersion (for backwards compatibility)
  /// Note: deprecated fields will use default values
  PlanVersion toPlanVersion(List<DayItinerary> days) => PlanVersion(
    id: id,
    name: name,
    durationDays: durationDays,
    difficulty: Difficulty.none, // Deprecated - use default
    comfortType: ComfortType.none, // Deprecated - use default
    price: 0, // Price is now at plan level
    days: days,
    packingCategories: packingCategories,
    transportationOptions: transportationOptions,
    faqItems: const [], // FAQ is now at plan level
    prepare: prepare,
    localTips: localTips,
    aiGeneratedAt: aiGeneratedAt,
  );
}
