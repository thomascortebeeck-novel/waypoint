import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/mood_vote_model.dart';

/// Service for daily mood votes and trip mood settings. Firestore: trips/{tripId}/mood_votes/{userId}, trips/{tripId}/settings, trips/{tripId}/mood_opt_out/{userId}
class MoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tripsCollection = 'trips';
  static const String _moodVotesSubcollection = 'mood_votes';
  static const String _settingsDoc = 'settings';
  static const String _moodOptOutSubcollection = 'mood_opt_out';

  static String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<TripSettings> getTripSettings(String tripId) async {
    final snap = await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_settingsDoc)
        .doc('mood')
        .get();
    if (!snap.exists || snap.data() == null) return const TripSettings();
    return TripSettings.fromJson(snap.data());
  }

  /// Record mood for today. Idempotent (overwrites same day).
  Future<void> recordMood({
    required String tripId,
    required String userId,
    required String mood,
  }) async {
    final dateKey = _dateKey(DateTime.now());
    final ref = _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodVotesSubcollection)
        .doc(userId);
    final snap = await ref.get();
    final Map<String, String> votes = {};
    if (snap.exists && snap.data() != null) {
      final v = snap.data()!['votes'];
      if (v is Map) {
        for (final e in v.entries) {
          if (e.key is String && e.value is String) {
            votes[e.key as String] = e.value as String;
          }
        }
      }
    }
    votes[dateKey] = mood;
    await ref.set({
      'votes': votes,
      'updated_at': Timestamp.now(),
    });
  }

  /// Whether the user has already voted today for this trip.
  Future<bool> hasVotedToday(String tripId, String userId) async {
    final dateKey = _dateKey(DateTime.now());
    final snap = await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodVotesSubcollection)
        .doc(userId)
        .get();
    if (!snap.exists || snap.data() == null) return false;
    final v = snap.data()!['votes'];
    if (v is! Map) return false;
    return v[dateKey] != null;
  }

  Stream<List<MoodVoteDoc>> streamMoodVotes(String tripId) {
    return _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodVotesSubcollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MoodVoteDoc.fromJson(d.data(), d.id, tripId))
            .toList());
  }

  Future<List<MoodVoteDoc>> getMoodVotes(String tripId) async {
    final snap = await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodVotesSubcollection)
        .get();
    return snap.docs
        .map((d) => MoodVoteDoc.fromJson(d.data(), d.id, tripId))
        .toList();
  }

  Future<bool> isMoodOptedOut(String tripId, String userId) async {
    final snap = await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodOptOutSubcollection)
        .doc(userId)
        .get();
    return snap.exists && (snap.data()?['opted_out'] == true);
  }

  Future<void> setMoodOptOut(String tripId, String userId, {required bool optedOut}) async {
    await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_moodOptOutSubcollection)
        .doc(userId)
        .set({'opted_out': optedOut});
  }
}
