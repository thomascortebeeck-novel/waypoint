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
  /// - https://waypoint.app/join/{code}
  /// - https://waypoint.page.link/join?code={code}
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
      
      // https://waypoint.app/join/{code}
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
        return uri.pathSegments[1];
      }
      
      // https://waypoint.page.link/join?code={code}
      if (uri.queryParameters.containsKey('code')) {
        return uri.queryParameters['code'];
      }
    } catch (_) {}
    
    return null;
  }

  /// Get trip by invite code
  Future<Trip?> getTripByInviteCode(String inviteCode) async {
    try {
      final snap = await _firestore
          .collection(_tripsCollection)
          .where('invite_code', isEqualTo: inviteCode)
          .limit(1)
          .get();
      
      if (snap.docs.isEmpty) return null;
      return Trip.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('Error getting trip by invite code: $e');
      return null;
    }
  }

  /// Validate an invite code for a specific user
  Future<InviteValidationResult> validateInvite(String inviteCode, String userId) async {
    try {
      // Get trip by invite code
      final trip = await getTripByInviteCode(inviteCode);
      if (trip == null) {
        return InviteValidationResult(
          status: InviteStatus.invalid,
          errorMessage: 'Invalid invite code',
        );
      }

      // Check if invites are enabled
      if (!trip.inviteEnabled) {
        return InviteValidationResult(
          status: InviteStatus.invalid,
          trip: trip,
          errorMessage: 'Invites are disabled for this trip',
        );
      }

      // Check if trip is active
      if (!trip.isActive || trip.status == 'cancelled') {
        return InviteValidationResult(
          status: InviteStatus.tripCancelled,
          trip: trip,
          errorMessage: 'This trip is no longer active',
        );
      }

      // Get plan details
      final plan = await _planService.getPlanById(trip.planId);
      if (plan == null) {
        return InviteValidationResult(
          status: InviteStatus.invalid,
          trip: trip,
          errorMessage: 'Plan not found',
        );
      }

      // Check if user is already a member
      if (trip.isMember(userId)) {
        return InviteValidationResult(
          status: InviteStatus.alreadyMember,
          trip: trip,
          plan: plan,
          errorMessage: 'You are already a member of this trip',
        );
      }

      // Check if user owns the plan
      final user = await _userService.getUserById(userId);
      if (user == null || !user.purchasedPlanIds.contains(trip.planId)) {
        return InviteValidationResult(
          status: InviteStatus.planNotOwned,
          trip: trip,
          plan: plan,
          errorMessage: 'You need to purchase this plan to join the trip',
        );
      }

      // Check group size limit
      if (!trip.canAddMembers(plan)) {
        return InviteValidationResult(
          status: InviteStatus.groupFull,
          trip: trip,
          plan: plan,
          errorMessage: 'This trip has reached its maximum number of members',
        );
      }

      return InviteValidationResult(
        status: InviteStatus.valid,
        trip: trip,
        plan: plan,
      );
    } catch (e) {
      debugPrint('Error validating invite: $e');
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
