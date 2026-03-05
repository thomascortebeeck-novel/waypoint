/// Statistics for a creator
/// Computed from user's created plans and follower data
class CreatorStats {
  final int adventuresCreated;
  final int followersCount;
  final double totalDistanceKm;
  /// When set, profile UI shows "Trips" | "Plans Built" | "Followers" instead of Adventures/Distance.
  final int? tripsCount;

  CreatorStats({
    required this.adventuresCreated,
    required this.followersCount,
    required this.totalDistanceKm,
    this.tripsCount,
  });

  /// Format followers count for display (e.g., 1200 -> "1.2k")
  String get formattedFollowersCount {
    if (followersCount < 1000) {
      return followersCount.toString();
    } else if (followersCount < 1000000) {
      return '${(followersCount / 1000).toStringAsFixed(1)}k';
    } else {
      return '${(followersCount / 1000000).toStringAsFixed(1)}M';
    }
  }

  /// Format distance for display
  String get formattedDistance {
    if (totalDistanceKm < 1) {
      return '${(totalDistanceKm * 1000).toStringAsFixed(0)} m';
    } else if (totalDistanceKm < 1000) {
      return '${totalDistanceKm.toStringAsFixed(0)} km';
    } else {
      return '${(totalDistanceKm / 1000).toStringAsFixed(1)}k km';
    }
  }

  CreatorStats copyWith({
    int? adventuresCreated,
    int? followersCount,
    double? totalDistanceKm,
    int? tripsCount,
  }) {
    return CreatorStats(
      adventuresCreated: adventuresCreated ?? this.adventuresCreated,
      followersCount: followersCount ?? this.followersCount,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      tripsCount: tripsCount ?? this.tripsCount,
    );
  }
}

