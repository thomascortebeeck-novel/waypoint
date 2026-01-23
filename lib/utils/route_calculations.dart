import 'package:waypoint/models/day_itinerary_model.dart';
import 'package:waypoint/models/plan_model.dart';

/// Utility functions for calculating route distance and duration consistently across the app
class RouteCalculations {
  /// Converts route distance from meters to kilometers with 1 decimal place
  static String formatDistanceKm(double? distanceInMeters) {
    if (distanceInMeters == null) return '0.0';
    return (distanceInMeters / 1000).toStringAsFixed(1);
  }

  /// Converts route duration from seconds to minutes
  static int convertSecondsToMinutes(int? durationInSeconds) {
    if (durationInSeconds == null) return 0;
    return (durationInSeconds / 60).round();
  }

  /// Formats duration in minutes to human-readable string (e.g., "2.5h" or "45min")
  static String formatDuration(int durationMinutes) {
    if (durationMinutes == 0) return '0min';
    
    final hours = durationMinutes / 60;
    if (hours >= 1.0) {
      return '${hours.toStringAsFixed(1)}h';
    }
    return '${durationMinutes}min';
  }

  /// Gets the estimated time in minutes for a day (works with both DayItinerary and DayItineraryDoc)
  static int getDayDurationMinutes(dynamic day) {
    // If route has duration data, use it (converting from seconds)
    if (day.route?.duration != null) {
      return convertSecondsToMinutes(day.route!.duration);
    }
    // Otherwise fall back to estimatedTimeMinutes
    return day.estimatedTimeMinutes as int;
  }

  /// Gets the distance in meters for a day (works with both DayItinerary and DayItineraryDoc)
  static double getDayDistanceMeters(dynamic day) {
    return day.route?.distance ?? 0.0;
  }

  /// Formats a day's distance in km with 1 decimal place (works with both DayItinerary and DayItineraryDoc)
  static String formatDayDistanceKm(dynamic day) {
    return formatDistanceKm(getDayDistanceMeters(day));
  }

  /// Formats a day's duration as human-readable string (works with both DayItinerary and DayItineraryDoc)
  static String formatDayDuration(dynamic day) {
    return formatDuration(getDayDurationMinutes(day));
  }
}
