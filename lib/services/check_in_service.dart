import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:waypoint/models/check_in_model.dart';
import 'package:waypoint/services/location_service.dart';

/// Check-ins subcollection: trips/{tripId}/check_ins.
/// Doc id: day_{dayNum}_{waypointId}_{userId} for idempotency.
class CheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  static const double _checkInRadiusM = 200;

  CollectionReference<Map<String, dynamic>> _checkInsRef(String tripId) =>
      _firestore.collection('trips').doc(tripId).collection('check_ins');

  /// Returns true if [date] is the same calendar day as [tripStartDate] + (dayNum - 1).
  bool _isTripDay(DateTime? tripStartDate, int dayNum, DateTime date) {
    if (tripStartDate == null) return false;
    final tripDay = tripStartDate.add(Duration(days: dayNum - 1));
    return date.year == tripDay.year &&
        date.month == tripDay.month &&
        date.day == tripDay.day;
  }

  /// Perform check-in. Day guard: only allow if today is the trip day for [dayNum].
  /// [tripStartDate] from Trip.startDate.
  /// If [useLocation] is true, attempts GPS and enforces radius; otherwise manual.
  /// Returns [CheckInResult] with rank and total count; [success] false if day guard or location fails.
  Future<CheckInResult> checkIn({
    required String tripId,
    required int dayNum,
    required String waypointId,
    required String userId,
    required DateTime? tripStartDate,
    required ll.LatLng? waypointLatLng,
    bool useLocation = false,
    String? note,
  }) async {
    final now = DateTime.now();
    if (!_isTripDay(tripStartDate, dayNum, now)) {
      return CheckInResult(
        success: false,
        rank: 0,
        totalCount: 0,
        method: 'manual',
      );
    }

    String method = 'manual';
    double? distanceM;
    double? accuracyM;

    if (useLocation && waypointLatLng != null) {
      final locResult = await _locationService.getCurrentLocation();
      if (!locResult.hasPosition || locResult.position == null) {
        return CheckInResult(
          success: false,
          rank: 0,
          totalCount: 0,
          method: 'location',
        );
      }
      final current = ll.LatLng(
        locResult.position!.latitude,
        locResult.position!.longitude,
      );
      if (!LocationService.isWithinRadius(current, waypointLatLng!,
          radiusM: _checkInRadiusM)) {
        distanceM = LocationService.distanceTo(current, waypointLatLng);
        return CheckInResult(
          success: false,
          rank: 0,
          totalCount: 0,
          method: 'location',
          distanceM: distanceM,
        );
      }
      method = 'location';
      distanceM = LocationService.distanceTo(current, waypointLatLng);
      accuracyM = locResult.position!.accuracy;
    }

    final docId =
        'day_${dayNum}_${waypointId}_$userId'.replaceAll(RegExp(r'[\/]'), '_');
    final ref = _checkInsRef(tripId).doc(docId);
    final checkIn = CheckIn(
      id: docId,
      tripId: tripId,
      dayNum: dayNum,
      waypointId: waypointId,
      userId: userId,
      createdAt: now,
      method: method,
      accuracyM: accuracyM,
      distanceM: distanceM,
      note: note,
    );
    await ref.set(checkIn.toJson(), SetOptions(merge: true));

    final rankResult = await getCheckInRank(tripId, waypointId, userId);
    final total = await _countCheckInsForWaypoint(tripId, waypointId);
    return CheckInResult(
      success: true,
      rank: rankResult,
      totalCount: total,
      method: method,
      distanceM: distanceM,
    );
  }

  Future<int> _countCheckInsForWaypoint(String tripId, String waypointId) async {
    final snap = await _checkInsRef(tripId)
        .where('waypoint_id', isEqualTo: waypointId)
        .get();
    return snap.docs.length;
  }

  /// 1-based rank of this user's check-in for this waypoint (by created_at).
  Future<int> getCheckInRank(String tripId, String waypointId, String userId) async {
    final all = await _checkInsRef(tripId)
        .where('waypoint_id', isEqualTo: waypointId)
        .orderBy('created_at', descending: false)
        .get();
    int rank = 1;
    for (final doc in all.docs) {
      final data = doc.data();
      if (data['user_id'] == userId) return rank;
      rank++;
    }
    return 0;
  }

  Stream<List<CheckIn>> streamCheckInsForWaypoint(
    String tripId,
    String waypointId,
  ) {
    return _checkInsRef(tripId)
        .where('waypoint_id', isEqualTo: waypointId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CheckIn.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<CheckIn>> streamTripCheckIns(String tripId) {
    return _checkInsRef(tripId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CheckIn.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) {
        final dayC = a.dayNum.compareTo(b.dayNum);
        if (dayC != 0) return dayC;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    });
  }

  /// Whether the current day (from trip start) is [dayNum].
  static bool isTodayTripDay(DateTime? tripStartDate, int dayNum) {
    if (tripStartDate == null) return false;
    final tripDay = tripStartDate.add(Duration(days: dayNum - 1));
    final now = DateTime.now();
    return now.year == tripDay.year &&
        now.month == tripDay.month &&
        now.day == tripDay.day;
  }
}
