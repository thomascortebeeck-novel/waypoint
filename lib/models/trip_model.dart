import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';

/// Customization status for trip waypoint selection
enum TripCustomizationStatus {
  draft,        // Trip just created, no selections made
  customizing,  // Owner is selecting waypoints
  ready,        // Customization complete, ready for invites
}

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
  // Optional custom cover images stored in Firebase Storage
  final Map<String, dynamic>? customImages; // {original, large, medium, thumbnail}
  // If true, fall back to plan image instead of customImages
  final bool usePlanImage;
  // Status: upcoming | in_progress | completed | cancelled
  final String? status;
  final bool isActive;
  // Invite fields for group travel
  final String inviteCode;
  final bool inviteEnabled;
  // Customization status for waypoint selection flow
  final TripCustomizationStatus customizationStatus;
  final DateTime? customizationCompletedAt;
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
    this.customImages,
    this.usePlanImage = true,
    this.status,
    this.isActive = true,
    String? inviteCode,
    this.inviteEnabled = true,
    this.customizationStatus = TripCustomizationStatus.draft,
    this.customizationCompletedAt,
    required this.createdAt,
    required this.updatedAt,
  }) : inviteCode = inviteCode ?? generateInviteCode();

  /// Check if the trip is ready for invites (customization complete)
  bool get isReadyForInvites => customizationStatus == TripCustomizationStatus.ready;

  /// Generate a unique short invite code
  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing chars
    final random = Random.secure();
    final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'TREK-$code';
  }

  /// Get the full shareable invite link
  String get shareLink => 'https://waypoint.app/join/$inviteCode';

  /// Get the Firebase Dynamic Link for sharing
  String get dynamicLink => 'https://waypoint.page.link/join?code=$inviteCode';

  /// Check if a user is the trip owner
  bool isOwner(String userId) => ownerId == userId;

  /// Check if a user is a member of the trip
  bool isMember(String userId) => memberIds.contains(userId);

  /// Check if more members can be added based on plan's max group size
  bool canAddMembers(Plan? plan) {
    if (plan == null || plan.maxGroupSize == null) return true;
    return memberIds.length < plan.maxGroupSize!;
  }

  /// Get remaining spots for the trip
  int? getRemainingSpots(Plan? plan) {
    if (plan == null || plan.maxGroupSize == null) return null;
    return plan.maxGroupSize! - memberIds.length;
  }

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
        customImages: json['customImages'] as Map<String, dynamic>?,
        usePlanImage: json['usePlanImage'] as bool? ?? true,
        status: json['status'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        inviteCode: json['invite_code'] as String? ?? generateInviteCode(),
        inviteEnabled: json['invite_enabled'] as bool? ?? true,
        customizationStatus: TripCustomizationStatus.values.firstWhere(
          (e) => e.name == json['customization_status'],
          orElse: () => TripCustomizationStatus.draft,
        ),
        customizationCompletedAt: (json['customization_completed_at'] as Timestamp?)?.toDate(),
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
        if (customImages != null) 'customImages': customImages,
        'usePlanImage': usePlanImage,
        if (status != null) 'status': status,
        'is_active': isActive,
        'invite_code': inviteCode,
        'invite_enabled': inviteEnabled,
        'customization_status': customizationStatus.name,
        if (customizationCompletedAt != null) 'customization_completed_at': Timestamp.fromDate(customizationCompletedAt!),
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
    Map<String, dynamic>? customImages,
    bool? usePlanImage,
    String? status,
    bool? isActive,
    String? inviteCode,
    bool? inviteEnabled,
    TripCustomizationStatus? customizationStatus,
    DateTime? customizationCompletedAt,
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
        customImages: customImages ?? this.customImages,
        usePlanImage: usePlanImage ?? this.usePlanImage,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        inviteCode: inviteCode ?? this.inviteCode,
        inviteEnabled: inviteEnabled ?? this.inviteEnabled,
        customizationStatus: customizationStatus ?? this.customizationStatus,
        customizationCompletedAt: customizationCompletedAt ?? this.customizationCompletedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
