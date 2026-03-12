import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/models/waypoint_vote_model.dart';
import 'package:waypoint/services/trip_service.dart';

/// Waypoint voting: subcollection trips/{tripId}/waypoint_votes/{slot_key}.
/// Slot keys: day_{n}_accommodation, day_{n}_restaurant_{meal}, day_{n}_activity_{index}.
class WaypointVoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripService _tripService = TripService();

  static const String _votesCollection = 'waypoint_votes';

  CollectionReference<Map<String, dynamic>> _votesRef(String tripId) =>
      _firestore.collection('trips').doc(tripId).collection(_votesCollection);

  /// Build slot keys and options from the locked plan version (snapshot for ballot).
  List<({String slotKey, List<VoteOption> options})> buildSlotsFromVersion(
    PlanVersion version,
  ) {
    final slots = <({String slotKey, List<VoteOption> options})>[];
    for (var i = 0; i < version.days.length; i++) {
      final day = version.days[i];
      final dayNum = i + 1;
      if (day.accommodations.isNotEmpty) {
        slots.add((
          slotKey: 'day_${dayNum}_accommodation',
          options: day.accommodations
              .map((a) => VoteOption(id: a.name, label: a.name))
              .toList(),
        ));
      }
      final restaurantsByMeal = <String, List<RestaurantInfo>>{};
      for (final rest in day.restaurants) {
        restaurantsByMeal.putIfAbsent(rest.mealType.name, () => []).add(rest);
      }
      for (final entry in restaurantsByMeal.entries) {
        if (entry.value.isEmpty) continue;
        slots.add((
          slotKey: 'day_${dayNum}_restaurant_${entry.key}',
          options: entry.value.map((r) => VoteOption(id: r.name, label: r.name)).toList(),
        ));
      }
      for (var j = 0; j < day.activities.length; j++) {
        final act = day.activities[j];
        slots.add((
          slotKey: 'day_${dayNum}_activity_$j',
          options: [VoteOption(id: act.name, label: act.name)],
        ));
      }
    }
    return slots;
  }

  /// Create vote docs from version snapshot. Call when owner first sets "Members vote".
  Future<void> createVoteState({
    required String tripId,
    required PlanVersion version,
  }) async {
    final slots = buildSlotsFromVersion(version);
    final batch = _firestore.batch();
    for (final slot in slots) {
      final ref = _votesRef(tripId).doc(slot.slotKey);
      batch.set(ref, {
        'slot_key': slot.slotKey,
        'options': slot.options.map((o) => o.toJson()).toList(),
        'votes': <String, String>{},
      });
    }
    await batch.commit();
  }

  /// Check if vote state already exists for this trip.
  Future<bool> hasVoteState(String tripId) async {
    final snap = await _votesRef(tripId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Submit or update vote for a slot (overwrites previous vote).
  Future<void> submitVote({
    required String tripId,
    required String slotKey,
    required String userId,
    required String optionId,
  }) async {
    await _votesRef(tripId).doc(slotKey).update({
      'votes.$userId': optionId,
    });
  }

  Stream<WaypointVoteDoc?> streamVoteDoc(String tripId, String slotKey) {
    return _votesRef(tripId)
        .doc(slotKey)
        .snapshots()
        .map((d) => d.exists
            ? WaypointVoteDoc.fromJson(slotKey, d.data()!)
            : null);
  }

  Stream<List<WaypointVoteDoc>> streamAllVoteDocs(String tripId) {
    return _votesRef(tripId).snapshots().map((snap) {
      return snap.docs
          .map((d) => WaypointVoteDoc.fromJson(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.slotKey.compareTo(b.slotKey));
    });
  }

  /// Close voting: resolve each slot (max votes, tie = random), write to TripDaySelection.
  Future<void> closeVoting({
    required String tripId,
    required Plan plan,
    required PlanVersion version,
  }) async {
    final snap = await _votesRef(tripId).get();
    final now = DateTime.now();
    final batch = _firestore.batch();
    final rnd = Random();
    final resolved = <String, String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final slotKey = data['slot_key'] as String? ?? doc.id;
      final votes = (data['votes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {};
      String? winner;
      if (votes.isNotEmpty) {
        final counts = <String, int>{};
        for (final optionId in votes.values) {
          counts[optionId] = (counts[optionId] ?? 0) + 1;
        }
        final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
        final tied = counts.entries.where((e) => e.value == maxCount).toList();
        winner = tied.isEmpty ? null : tied[rnd.nextInt(tied.length)].key;
      }
      if (winner != null) resolved[slotKey] = winner;
      batch.update(doc.reference, {
        'resolved_option_id': winner,
        'closed_at': Timestamp.fromDate(now),
      });
    }
    await batch.commit();

    // Ensure day selections exist (owner may not have opened itinerary select yet).
    var selections = await _tripService.getDaySelections(tripId);
    if (selections.isEmpty && version.days.isNotEmpty) {
      await _tripService.initializeDaySelections(
        tripId: tripId,
        totalDays: version.days.length,
      );
      selections = await _tripService.getDaySelections(tripId);
    }

    // Write resolved options to TripDaySelection
    for (final entry in resolved.entries) {
      final slotKey = entry.key;
      final resolvedId = entry.value;

      final parts = slotKey.split('_');
      if (parts.length < 3) continue;
      final dayNum = int.tryParse(parts[1]) ?? 0;
      if (dayNum < 1 || dayNum > version.days.length) continue;
      final day = version.days[dayNum - 1];

      if (slotKey.contains('_accommodation')) {
        AccommodationInfo? acc;
        for (final a in day.accommodations) {
          if (a.name == resolvedId) {
            acc = a;
            break;
          }
        }
        if (acc != null) {
          await _tripService.updateDayAccommodation(
            tripId: tripId,
            dayNum: dayNum,
            accommodation: SelectedWaypoint.fromAccommodation(acc),
          );
        }
      } else if (slotKey.contains('_restaurant_')) {
        final mealName = slotKey.split('_').last;
        RestaurantInfo? rest;
        for (final r in day.restaurants) {
          if (r.mealType.name == mealName && r.name == resolvedId) {
            rest = r;
            break;
          }
        }
        if (rest != null) {
          var selections = await _tripService.getDaySelections(tripId);
          final daySelection = dayNum <= selections.length ? selections[dayNum - 1] : null;
          final updated = Map<String, SelectedWaypoint>.from(daySelection?.selectedRestaurants ?? {});
          updated[rest.mealType.name] = SelectedWaypoint.fromRestaurant(rest);
          await _tripService.updateDayRestaurants(
            tripId: tripId,
            dayNum: dayNum,
            restaurants: updated,
          );
        }
      } else if (slotKey.contains('_activity_')) {
        final idx = int.tryParse(slotKey.split('_').last) ?? -1;
        if (idx >= 0 && idx < day.activities.length && day.activities[idx].name == resolvedId) {
          var selections = await _tripService.getDaySelections(tripId);
          final daySelection = dayNum <= selections.length ? selections[dayNum - 1] : null;
          final current = List<SelectedWaypoint>.from(daySelection?.selectedActivities ?? []);
          final existingIdx = current.indexWhere((a) => a.name == resolvedId);
          if (existingIdx < 0) {
            current.add(SelectedWaypoint.fromActivity(day.activities[idx]));
            await _tripService.updateDayActivities(
              tripId: tripId,
              dayNum: dayNum,
              activities: current,
            );
          }
        }
      }
    }
  }

  /// Whether any vote doc is still open (no closed_at).
  Future<bool> isVotingOpen(String tripId) async {
    final snap = await _votesRef(tripId).get();
    for (final doc in snap.docs) {
      if (doc.data()['closed_at'] == null) return true;
    }
    return false;
  }
}
