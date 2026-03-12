import 'package:waypoint/features/footprint/footprint_input.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';

/// Builds FootprintInput from plan/trip data.
class FootprintInputBuilder {
  /// Build from plan version only (viewer/builder: use all waypoints from version days).
  static FootprintInput fromPlanVersion(
    PlanVersion version, {
    int personCount = 1,
  }) {
    final transportLegs = <FootprintLegInput>[];
    final accommodations = <FootprintAccommodationInput>[];
    final restaurants = <FootprintRestaurantInput>[];
    final activities = <FootprintActivityInput>[];

    final defaultMode = _defaultTransportMode(version);

    for (final day in version.days) {
      if (day.distanceKm > 0) {
        transportLegs.add(FootprintLegInput(
          fromName: 'Day ${day.dayNum} start',
          toName: 'Day ${day.dayNum} end',
          mode: defaultMode,
          distanceKm: day.distanceKm,
          dayNum: day.dayNum,
        ));
      }

      for (final acc in day.accommodations) {
        accommodations.add(FootprintAccommodationInput(
          type: acc.type,
          nights: 1,
        ));
      }
      if (day.stay != null) {
        accommodations.add(FootprintAccommodationInput(
          type: day.stay!.type,
          nights: 1,
        ));
      }

      for (final rest in day.restaurants) {
        restaurants.add(FootprintRestaurantInput(
          type: rest.mealType.name,
        ));
      }

      for (final act in day.activities) {
        activities.add(FootprintActivityInput(type: act.description));
      }
    }

    return FootprintInput(
      transportLegs: transportLegs,
      accommodations: accommodations,
      restaurants: restaurants,
      activities: activities,
      personCount: personCount,
    );
  }

  /// Build from trip: only voted/selected waypoints.
  static FootprintInput fromTrip(
    PlanVersion version,
    Map<int, TripDaySelection> daySelections, {
    int personCount = 1,
  }) {
    final transportLegs = <FootprintLegInput>[];
    final accommodations = <FootprintAccommodationInput>[];
    final restaurants = <FootprintRestaurantInput>[];
    final activities = <FootprintActivityInput>[];

    final defaultMode = _defaultTransportMode(version);

    for (final day in version.days) {
      final selection = daySelections[day.dayNum];
      if (day.distanceKm > 0) {
        transportLegs.add(FootprintLegInput(
          fromName: 'Day ${day.dayNum} start',
          toName: 'Day ${day.dayNum} end',
          mode: defaultMode,
          distanceKm: day.distanceKm,
          dayNum: day.dayNum,
        ));
      }

      if (selection?.selectedAccommodation != null) {
        accommodations.add(FootprintAccommodationInput(
          type: selection!.selectedAccommodation!.type,
          nights: 1,
        ));
      }

      for (final rest in selection?.selectedRestaurants.values ?? []) {
        restaurants.add(FootprintRestaurantInput(type: rest.type));
      }

      for (final act in selection?.selectedActivities ?? []) {
        activities.add(FootprintActivityInput(type: act.type));
      }
    }

    return FootprintInput(
      transportLegs: transportLegs,
      accommodations: accommodations,
      restaurants: restaurants,
      activities: activities,
      personCount: personCount,
    );
  }

  static FootprintTransportMode _defaultTransportMode(PlanVersion version) {
    if (version.transportationOptions.isEmpty) {
      return FootprintTransportMode.car;
    }
    final first = version.transportationOptions.first.types;
    if (first.isEmpty) return FootprintTransportMode.car;
    return footprintTransportFromPlan(first.first);
  }
}
