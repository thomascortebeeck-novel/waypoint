import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Waypoint user
class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final List<String> purchasedPlanIds;
  final List<String> createdPlanIds;
  final List<String> invitedPlanIds;
  final bool isAdmin;
  final bool agreedToTerms;
  final bool marketingOptIn;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.purchasedPlanIds = const [],
    this.createdPlanIds = const [],
    this.invitedPlanIds = const [],
    this.isAdmin = false,
    this.agreedToTerms = false,
    this.marketingOptIn = false,
    this.emailVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      purchasedPlanIds: List<String>.from(json['purchased_plan_ids'] ?? []),
      createdPlanIds: List<String>.from(json['created_plan_ids'] ?? []),
      invitedPlanIds: List<String>.from(json['invited_plan_ids'] ?? []),
      isAdmin: json['is_admin'] as bool? ?? false,
      agreedToTerms: json['agreed_to_terms'] as bool? ?? false,
      marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      emailVerified: json['email_verified'] as bool? ?? false,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'photo_url': photoUrl,
      'purchased_plan_ids': purchasedPlanIds,
      'created_plan_ids': createdPlanIds,
      'invited_plan_ids': invitedPlanIds,
      'is_admin': isAdmin,
      'agreed_to_terms': agreedToTerms,
      'marketing_opt_in': marketingOptIn,
      'email_verified': emailVerified,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoUrl,
    List<String>? purchasedPlanIds,
    List<String>? createdPlanIds,
    List<String>? invitedPlanIds,
    bool? isAdmin,
    bool? agreedToTerms,
    bool? marketingOptIn,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      purchasedPlanIds: purchasedPlanIds ?? this.purchasedPlanIds,
      createdPlanIds: createdPlanIds ?? this.createdPlanIds,
      invitedPlanIds: invitedPlanIds ?? this.invitedPlanIds,
      isAdmin: isAdmin ?? this.isAdmin,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
