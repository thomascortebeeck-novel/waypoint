import 'package:cloud_firestore/cloud_firestore.dart';

/// Daily mood vote. Stored in trips/{tripId}/mood_votes (doc id = userId, one doc per user with map of date -> mood).
/// Alternative: one doc per vote with id = '${userId}_$date'. We use one doc per user: { date1: mood1, date2: mood2, ... }.
class MoodVoteDoc {
  final String userId;
  final String tripId;
  /// Date string (YYYY-MM-DD) -> mood value (e.g. 'great', 'good', 'ok', 'low', 'bad').
  final Map<String, String> votes;
  final DateTime updatedAt;

  const MoodVoteDoc({
    required this.userId,
    required this.tripId,
    required this.votes,
    required this.updatedAt,
  });

  factory MoodVoteDoc.fromJson(Map<String, dynamic> json, String docId, String tripId) {
    final updatedAt = json['updated_at'];
    final votes = json['votes'];
    Map<String, String> voteMap = {};
    if (votes is Map) {
      for (final e in votes.entries) {
        if (e.key is String && e.value is String) {
          voteMap[e.key as String] = e.value as String;
        }
      }
    }
    return MoodVoteDoc(
      userId: docId,
      tripId: tripId,
      votes: voteMap,
      updatedAt: updatedAt is Timestamp
          ? (updatedAt as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'votes': votes,
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Trip settings (e.g. mood popup). Stored in trips/{tripId}/settings (single doc).
class TripSettings {
  final bool moodPopupEnabled;
  /// Hour (0-23) after which mood popup can show (e.g. 19 = 7pm).
  final int moodPopupHour;

  const TripSettings({
    this.moodPopupEnabled = true,
    this.moodPopupHour = 19,
  });

  factory TripSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripSettings();
    return TripSettings(
      moodPopupEnabled: json['mood_popup_enabled'] as bool? ?? true,
      moodPopupHour: (json['mood_popup_hour'] as int?) ?? 19,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mood_popup_enabled': moodPopupEnabled,
      'mood_popup_hour': moodPopupHour,
    };
  }
}
