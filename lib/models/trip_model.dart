import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String planId;
  final String ownerId;
  final List<String> memberIds; // must all own the plan
  final String? title;
  // Version of the plan selected for this trip
  final String? versionId;
  // Trip schedule
  final DateTime? startDate;
  final DateTime? endDate;
  // Packing checklist progress: item -> checked
  final Map<String, bool>? packingChecklist;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.planId,
    required this.ownerId,
    required this.memberIds,
    this.title,
    this.versionId,
    this.startDate,
    this.endDate,
    this.packingChecklist,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        planId: json['plan_id'] as String,
        ownerId: json['owner_id'] as String,
        memberIds: List<String>.from(json['member_ids'] ?? []),
        title: json['title'] as String?,
        versionId: json['version_id'] as String?,
        startDate: (json['start_date'] as Timestamp?)?.toDate(),
        endDate: (json['end_date'] as Timestamp?)?.toDate(),
        packingChecklist: (json['packing_checklist'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as bool)),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: (json['created_at'] as Timestamp).toDate(),
        updatedAt: (json['updated_at'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan_id': planId,
        'owner_id': ownerId,
        'member_ids': memberIds,
        'title': title,
        'version_id': versionId,
        if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
        if (endDate != null) 'end_date': Timestamp.fromDate(endDate!),
        if (packingChecklist != null) 'packing_checklist': packingChecklist,
        'is_active': isActive,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  Trip copyWith({
    String? id,
    String? planId,
    String? ownerId,
    List<String>? memberIds,
    String? title,
    String? versionId,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, bool>? packingChecklist,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Trip(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        ownerId: ownerId ?? this.ownerId,
        memberIds: memberIds ?? this.memberIds,
        title: title ?? this.title,
        versionId: versionId ?? this.versionId,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        packingChecklist: packingChecklist ?? this.packingChecklist,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
