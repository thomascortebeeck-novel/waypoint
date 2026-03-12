import 'package:waypoint/features/footprint/footprint_result.dart';

/// One transport leg for input (before CO2 calculation).
class FootprintLegInput {
  final String fromName;
  final String toName;
  final FootprintTransportMode mode;
  final double distanceKm;
  final int dayNum;

  const FootprintLegInput({
    required this.fromName,
    required this.toName,
    required this.mode,
    required this.distanceKm,
    this.dayNum = 1,
  });
}

/// Accommodation stay for input.
class FootprintAccommodationInput {
  final String type; // e.g. Hotel, Hostel, Camping
  final int nights;

  const FootprintAccommodationInput({
    required this.type,
    this.nights = 1,
  });
}

/// Restaurant meal for input.
class FootprintRestaurantInput {
  final String type; // e.g. breakfast, lunch, dinner, fine dining

  const FootprintRestaurantInput({required this.type});
}

/// Activity visit for input.
class FootprintActivityInput {
  final String type; // e.g. museum, outdoor, theme park

  const FootprintActivityInput({required this.type});
}

/// Aggregated input for the footprint calculator.
class FootprintInput {
  final List<FootprintLegInput> transportLegs;
  final List<FootprintAccommodationInput> accommodations;
  final List<FootprintRestaurantInput> restaurants;
  final List<FootprintActivityInput> activities;
  final int personCount;

  const FootprintInput({
    this.transportLegs = const [],
    this.accommodations = const [],
    this.restaurants = const [],
    this.activities = const [],
    this.personCount = 1,
  });
}
