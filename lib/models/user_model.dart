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
  final String? shortBio; // Short creator bio (max ~150 chars)
  final String? location; // Display location (e.g. city, region)
  final List<String> followingIds; // Creators this user follows
  final List<String> followerIds; // Users following this creator
  final Map<String, String>? socialLinks; // Instagram, YouTube, blog URLs
  final bool canCreatePublicPlans; // Whether user can create public plans (influencer status)
  /// Whether user has influencer status; can access Builder page. Firestore: is_influencer.
  final bool isInfluencer;
  /// Stripe Connect account id (acct_...) for payouts. Firestore: stripe_account_id.
  final String? stripeAccountId;
  /// Cached from Stripe Connect account.updated; used by createPaymentIntent. Firestore: charges_enabled.
  final bool? chargesEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Number of trips the user has completed (owner or member). Firestore: completed_trip_count.
  final int completedTripCount;
  /// Total plans sold across all plans by this user (creators). Denormalized. Firestore: total_plans_sold.
  final int totalPlansSold;

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
    this.shortBio,
    this.location,
    this.followingIds = const [],
    this.followerIds = const [],
    this.socialLinks,
    this.canCreatePublicPlans = false,
    this.isInfluencer = false,
    this.stripeAccountId,
    this.chargesEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.completedTripCount = 0,
    this.totalPlansSold = 0,
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
      shortBio: json['short_bio'] as String?,
      location: json['location'] as String?,
      followingIds: List<String>.from(json['following_ids'] ?? []),
      followerIds: List<String>.from(json['follower_ids'] ?? []),
      socialLinks: json['social_links'] != null
          ? Map<String, String>.from(json['social_links'] as Map)
          : null,
      canCreatePublicPlans: json['can_create_public_plans'] as bool? ?? false,
      isInfluencer: json['is_influencer'] as bool? ?? false,
      stripeAccountId: json['stripe_account_id'] as String?,
      chargesEnabled: json['charges_enabled'] as bool?,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
      completedTripCount: (json['completed_trip_count'] as int?) ?? 0,
      totalPlansSold: (json['total_plans_sold'] as int?) ?? 0,
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
      if (shortBio != null) 'short_bio': shortBio,
      if (location != null) 'location': location,
      'following_ids': followingIds,
      'follower_ids': followerIds,
      if (socialLinks != null) 'social_links': socialLinks,
      'can_create_public_plans': canCreatePublicPlans,
      'is_influencer': isInfluencer,
      if (stripeAccountId != null) 'stripe_account_id': stripeAccountId,
      if (chargesEnabled != null) 'charges_enabled': chargesEnabled,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'completed_trip_count': completedTripCount,
      'total_plans_sold': totalPlansSold,
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
    String? shortBio,
    String? location,
    List<String>? followingIds,
    List<String>? followerIds,
    Map<String, String>? socialLinks,
    bool? canCreatePublicPlans,
    bool? isInfluencer,
    String? stripeAccountId,
    bool? chargesEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? completedTripCount,
    int? totalPlansSold,
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
      shortBio: shortBio ?? this.shortBio,
      location: location ?? this.location,
      followingIds: followingIds ?? this.followingIds,
      followerIds: followerIds ?? this.followerIds,
      socialLinks: socialLinks ?? this.socialLinks,
      canCreatePublicPlans: canCreatePublicPlans ?? this.canCreatePublicPlans,
      isInfluencer: isInfluencer ?? this.isInfluencer,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      chargesEnabled: chargesEnabled ?? this.chargesEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedTripCount: completedTripCount ?? this.completedTripCount,
      totalPlansSold: totalPlansSold ?? this.totalPlansSold,
    );
  }
}
