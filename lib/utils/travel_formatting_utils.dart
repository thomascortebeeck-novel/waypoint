import 'package:flutter/material.dart';

/// Utility class for formatting travel-related information consistently across the app
class TravelFormattingUtils {
  /// Get Material icon for travel mode
  static IconData getTravelIcon(String? mode) {
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_transit;
      case 'driving':
        return Icons.directions_car;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.directions_walk;
    }
  }

  /// Get short label for travel mode (e.g., 'walk', 'metro', 'drive', 'bike')
  static String getTravelModeLabel(String? mode) {
    switch (mode) {
      case 'walking':
        return 'walk';
      case 'transit':
        return 'metro';
      case 'driving':
        return 'drive';
      case 'bicycling':
        return 'bike';
      default:
        return 'walk';
    }
  }

  /// Format travel time in seconds to human-readable string
  /// Returns formats like: "45 min", "2 h", "2 h 30 min", or "calculating..." if null
  static String formatTravelTime(int? seconds, {String nullPlaceholder = 'calculating...'}) {
    if (seconds == null) return nullPlaceholder;
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }

  /// Format distance in meters to kilometers with 1 decimal place
  static String formatDistanceKm(double? distanceMeters) {
    if (distanceMeters == null) return '0.0';
    return (distanceMeters / 1000.0).toStringAsFixed(1);
  }
}

