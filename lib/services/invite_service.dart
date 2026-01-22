import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';

/// Status of an invite code validation
enum InviteStatus {
  valid,           // Ready to join
  invalid,         // Code doesn't exist or invites disabled
  alreadyMember,   // User is already in the trip
  planNotOwned,    // User doesn't own the required plan
  groupFull,       // Trip has reached max members
  tripCancelled,   // Trip is no longer active
}

/// Result of invite validation with details
class InviteValidationResult {
  final InviteStatus status;
  final Trip? trip;
  final Plan? plan;
  final String? errorMessage;

  InviteValidationResult({
    required this.status,
    this.trip,
    this.plan,
    this.errorMessage,
  });

  bool get isValid => status == InviteStatus.valid;
  bool get needsPurchase => status == InviteStatus.planNotOwned;
}

/// Service for handling trip invites and group membership
class InviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripService _tripService = TripService();
  final PlanService _planService = PlanService();
  final UserService _userService = UserService();
  static const String _tripsCollection = 'trips';

  /// Parse invite code from various URL formats
  /// Supports: 
  /// - https://waypoint.eu.com/join/{code}
  /// - https://waypoint.app/join/{code} (legacy)
  /// - https://waypoint.page.link/join?code={code}
  /// - https://*.dreamflow.app/#/join/{code} (test environment)
  /// - Direct code (e.g., TREK-X7K9M2)
  String? parseInviteCode(String input) {
    final trimmed = input.trim();
    
    // Direct code format (TREK-XXXXXX)
    if (RegExp(r'^TREK-[A-Z0-9]{6}$').hasMatch(trimmed)) {
      return trimmed;
    }
    
    // Parse URL formats
    try {
      final uri = Uri.parse(trimmed);
      
      // Production URLs: https://waypoint.eu.com/join/{code} or https://waypoint.app/join/{code}
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
        return uri.pathSegments[1];
      }
      
      // Test environment (Dreamflow): https://*.dreamflow.app/#/join/{code}
      // The fragment contains the route after #
      if (uri.fragment.isNotEmpty) {
        final fragmentUri = Uri.parse(uri.fragment);
        if (fragmentUri.pathSegments.length >= 2 && fragmentUri.pathSegments[0] == 'join') {
          return fragmentUri.pathSegments[1];
        }
      }
      
      // Firebase Dynamic Links: https://waypoint.page.link/join?code={code}
      if (uri.queryParameters.containsKey('code')) {
        return uri.queryParameters['code'];
      }
    } catch (_) {}
    
    return null;
  }

  /// Get trip by invite code
  Future<Trip?> getTripByInviteCode(String inviteCode) async {
    try {
      debugPrint('InviteService: Looking up trip with invite_code: $inviteCode');
      final snap = await _firestore
          .collection(_tripsCollection)
          .where('invite_code', isEqualTo: inviteCode)
          .limit(1)
          .get();
      
      if (snap.docs.isEmpty) {
        debugPrint('InviteService: No trip found with invite_code: $inviteCode');
        return null;
      }
      debugPrint('InviteService: Found trip: ${snap.docs.first.id}');
      return Trip.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('InviteService: Error getting trip by invite code: $e');
      return null;
    }
  }

  /// Validate an invite code for a specific user
  Future<InviteValidationResult> validateInvite(String inviteCode, String userId) async {
    try {
      debugPrint('InviteService: Validating invite code: $inviteCode for user: $userId');
      
      // Get trip by invite code
      final trip = await getTripByInviteCode(inviteCode);
      if (trip == null) {
        debugPrint('InviteService: Trip not found for invite code: $inviteCode');
        return InviteValidationResult(
          status: InviteStatus.invalid,
          errorMessage: 'Invalid invite code',
        );
      }
      debugPrint('InviteService: Found trip ${trip.id}, planId: ${trip.planId}');

      // Check if invites are enabled
      if (!trip.inviteEnabled) {
        debugPrint('InviteService: Invites disabled for trip ${trip.id}');
        return InviteValidationResult(
          status: InviteStatus.invalid,
          trip: trip,
          errorMessage: 'Invites are disabled for this trip',
        );
      }

      // Check if trip is active
      if (!trip.isActive || trip.status == 'cancelled') {
        debugPrint('InviteService: Trip ${trip.id} is not active or cancelled');
        return InviteValidationResult(
          status: InviteStatus.tripCancelled,
          trip: trip,
          errorMessage: 'This trip is no longer active',
        );
      }

      // Get plan details
      final plan = await _planService.getPlanById(trip.planId);
      if (plan == null) {
        debugPrint('InviteService: Plan ${trip.planId} not found');
        return InviteValidationResult(
          status: InviteStatus.invalid,
          trip: trip,
          errorMessage: 'Plan not found',
        );
      }
      debugPrint('InviteService: Found plan ${plan.id}: ${plan.name}');

      // Check if user is already a member
      if (trip.isMember(userId)) {
        debugPrint('InviteService: User $userId is already a member of trip ${trip.id}');
        return InviteValidationResult(
          status: InviteStatus.alreadyMember,
          trip: trip,
          plan: plan,
          errorMessage: 'You are already a member of this trip',
        );
      }

      // Check if user owns the plan - fetch fresh data from Firestore
      final user = await _userService.getUserById(userId);
      debugPrint('InviteService: User ${user?.id}, purchasedPlanIds: ${user?.purchasedPlanIds}');
      if (user == null || !user.purchasedPlanIds.contains(trip.planId)) {
        debugPrint('InviteService: User does not own plan ${trip.planId}');
        return InviteValidationResult(
          status: InviteStatus.planNotOwned,
          trip: trip,
          plan: plan,
          errorMessage: 'You need to purchase this plan to join the trip',
        );
      }

      // Check group size limit
      if (!trip.canAddMembers(plan)) {
        debugPrint('InviteService: Trip ${trip.id} is full');
        return InviteValidationResult(
          status: InviteStatus.groupFull,
          trip: trip,
          plan: plan,
          errorMessage: 'This trip has reached its maximum number of members',
        );
      }

      debugPrint('InviteService: Invite validation successful, user can join');
      return InviteValidationResult(
        status: InviteStatus.valid,
        trip: trip,
        plan: plan,
      );
    } catch (e) {
      debugPrint('InviteService: Error validating invite: $e');
      return InviteValidationResult(
        status: InviteStatus.invalid,
        errorMessage: 'Failed to validate invite',
      );
    }
  }

  /// Process invite and join trip (full flow with validations)
  Future<bool> processInvite(String inviteCode, String userId) async {
    final validation = await validateInvite(inviteCode, userId);
    
    if (!validation.isValid) {
      throw Exception(validation.errorMessage ?? 'Invalid invite');
    }

    try {
      await _tripService.addMember(
        tripId: validation.trip!.id,
        userId: userId,
        planId: validation.trip!.planId,
      );
      return true;
    } catch (e) {
      debugPrint('Error processing invite: $e');
      rethrow;
    }
  }

  /// Get invite status for display
  Future<InviteStatus> getInviteStatus(String inviteCode, String userId) async {
    final result = await validateInvite(inviteCode, userId);
    return result.status;
  }

  /// Get member details for a trip
  Future<List<UserModel>> getMembersDetails(String tripId) async {
    try {
      final trip = await _tripService.getTripById(tripId);
      if (trip == null) return [];

      final members = <UserModel>[];
      for (final memberId in trip.memberIds) {
        final user = await _userService.getUserById(memberId);
        if (user != null) {
          members.add(user);
        }
      }
      return members;
    } catch (e) {
      debugPrint('Error getting member details: $e');
      return [];
    }
  }
}
