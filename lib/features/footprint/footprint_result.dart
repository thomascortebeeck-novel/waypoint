import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';

/// Transport mode for footprint calculation with CO2 factor (kg per km per person).
enum FootprintTransportMode {
  foot(0.0),
  bike(0.0),
  eScooter(0.022),
  publicTransport(0.089),
  car(0.171),
  taxi(0.211),
  train(0.041),
  flight(0.255),
  boat(0.120);

  const FootprintTransportMode(this.kgCo2PerKm);
  final double kgCo2PerKm;
}

/// Maps plan TransportationType and Google travelMode string to FootprintTransportMode.
FootprintTransportMode footprintTransportFromPlan(TransportationType type) {
  switch (type) {
    case TransportationType.foot:
      return FootprintTransportMode.foot;
    case TransportationType.bike:
      return FootprintTransportMode.bike;
    case TransportationType.train:
      return FootprintTransportMode.train;
    case TransportationType.bus:
      return FootprintTransportMode.publicTransport;
    case TransportationType.taxi:
      return FootprintTransportMode.taxi;
    case TransportationType.car:
      return FootprintTransportMode.car;
    case TransportationType.flying:
      return FootprintTransportMode.flight;
    case TransportationType.boat:
      return FootprintTransportMode.boat;
  }
}

FootprintTransportMode footprintTransportFromString(String? mode) {
  if (mode == null || mode.isEmpty) return FootprintTransportMode.car;
  final m = mode.toLowerCase();
  if (m == 'walking' || m == 'foot') return FootprintTransportMode.foot;
  if (m == 'bicycling' || m == 'bike') return FootprintTransportMode.bike;
  if (m == 'transit' || m == 'bus') return FootprintTransportMode.publicTransport;
  if (m == 'driving' || m == 'car') return FootprintTransportMode.car;
  if (m == 'train') return FootprintTransportMode.train;
  if (m == 'taxi') return FootprintTransportMode.taxi;
  if (m == 'flight' || m == 'flying') return FootprintTransportMode.flight;
  if (m == 'boat' || m == 'ferry') return FootprintTransportMode.boat;
  return FootprintTransportMode.car;
}

/// Suggested transport mode from plan version (first option). Used to compare with chosen mode for Footprinter points.
FootprintTransportMode suggestedTransportModeForVersion(PlanVersion version) {
  if (version.transportationOptions.isEmpty) return FootprintTransportMode.car;
  final first = version.transportationOptions.first.types;
  if (first.isEmpty) return FootprintTransportMode.car;
  return footprintTransportFromPlan(first.first);
}

/// One transport leg between two waypoints.
class FootprintLeg {
  final String fromWaypoint;
  final String toWaypoint;
  final FootprintTransportMode mode;
  final double distanceKm;
  final double kgCO2;
  final int dayNum;

  const FootprintLeg({
    required this.fromWaypoint,
    required this.toWaypoint,
    required this.mode,
    required this.distanceKm,
    required this.kgCO2,
    this.dayNum = 1,
  });
}

/// Fun equivalent for displaying CO2 (e.g. bottles of water).
class FootprintEquivalent {
  final IconData icon;
  final int value;
  final String label;

  const FootprintEquivalent({
    required this.icon,
    required this.value,
    required this.label,
  });
}

/// Full result of footprint calculation.
class FootprintResult {
  final double totalKgCO2;
  final double transportKgCO2;
  final double accommodationKgCO2;
  final double restaurantKgCO2;
  final double activityKgCO2;
  final List<FootprintLeg> transportLegs;
  final List<FootprintEquivalent> equivalents;
  final int personCount;

  const FootprintResult({
    required this.totalKgCO2,
    required this.transportKgCO2,
    required this.accommodationKgCO2,
    required this.restaurantKgCO2,
    required this.activityKgCO2,
    required this.transportLegs,
    required this.equivalents,
    this.personCount = 1,
  });

  double get perPersonKgCO2 =>
      personCount > 0 ? totalKgCO2 / personCount : totalKgCO2;

  double get transportShare =>
      totalKgCO2 > 0 ? transportKgCO2 / totalKgCO2 : 0.0;
  double get accommodationShare =>
      totalKgCO2 > 0 ? accommodationKgCO2 / totalKgCO2 : 0.0;
  double get restaurantShare =>
      totalKgCO2 > 0 ? restaurantKgCO2 / totalKgCO2 : 0.0;
  double get activityShare =>
      totalKgCO2 > 0 ? activityKgCO2 / totalKgCO2 : 0.0;
}
