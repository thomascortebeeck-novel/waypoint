import 'package:cloud_firestore/cloud_firestore.dart';

/// One option in a vote slot (snapshot from plan version).
class VoteOption {
  final String id;
  final String label;

  const VoteOption({required this.id, required this.label});

  factory VoteOption.fromJson(Map<String, dynamic> json) => VoteOption(
        id: json['id'] as String,
        label: json['label'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

/// One vote slot doc: trips/{tripId}/waypoint_votes/{slot_key}.
/// Options are snapshot at vote open; votes map userId -> optionId; resolved when closed.
class WaypointVoteDoc {
  final String slotKey;
  final List<VoteOption> options;
  final Map<String, String> votes;
  final String? resolvedOptionId;
  final DateTime? closedAt;

  const WaypointVoteDoc({
    required this.slotKey,
    required this.options,
    this.votes = const {},
    this.resolvedOptionId,
    this.closedAt,
  });

  bool get isClosed => closedAt != null;

  factory WaypointVoteDoc.fromJson(String slotKey, Map<String, dynamic> json) =>
      WaypointVoteDoc(
        slotKey: slotKey,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => VoteOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        votes: (json['votes'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as String),
            ) ??
            {},
        resolvedOptionId: json['resolved_option_id'] as String?,
        closedAt: (json['closed_at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toJson() => {
        'slot_key': slotKey,
        'options': options.map((o) => o.toJson()).toList(),
        'votes': votes,
        if (resolvedOptionId != null) 'resolved_option_id': resolvedOptionId,
        if (closedAt != null) 'closed_at': Timestamp.fromDate(closedAt!),
      };
}
