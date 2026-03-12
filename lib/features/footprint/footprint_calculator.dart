import 'package:flutter/material.dart';
import 'package:waypoint/features/footprint/footprint_input.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';

/// CO2 emission factors and calculator for trip footprint.
class FootprintCalculator {

  // Transport: kg CO2 per km per person (already in FootprintTransportMode).

  // Accommodation: kg CO2 per night
  static const double _accCampingHostel = 8.0;
  static const double _accBudgetHotel = 20.0;
  static const double _accMidRangeHotel = 31.0;
  static const double _accLuxuryHotel = 55.0;
  static const double _accAirbnb = 18.0;
  static const double _accDefault = 25.0;

  // Restaurant: kg CO2 per meal
  static const double _restFastFood = 2.8;
  static const double _restCasual = 4.5;
  static const double _restFineDining = 7.0;
  static const double _restVegetarian = 1.5;
  static const double _restDefault = 3.5;

  // Activity: kg CO2 per visit
  static const double _actOutdoor = 0.5;
  static const double _actMuseum = 1.2;
  static const double _actThemePark = 8.0;
  static const double _actCityTour = 3.0;
  static const double _actDefault = 1.0;

  double _accFactor(String type) {
    final t = type.toLowerCase();
    if (t.contains('camp') || t.contains('hostel') || t.contains('hut')) return _accCampingHostel;
    if (t.contains('budget') || t.contains('guesthouse')) return _accBudgetHotel;
    if (t.contains('luxury') || t.contains('resort') || t.contains('5')) return _accLuxuryHotel;
    if (t.contains('airbnb') || t.contains('apartment') || t.contains('rental')) return _accAirbnb;
    if (t.contains('hotel') || t.contains('lodge') || t.contains('inn')) return _accMidRangeHotel;
    return _accDefault;
  }

  double _restFactor(String type) {
    final t = type.toLowerCase();
    if (t.contains('fast') || t.contains('quick')) return _restFastFood;
    if (t.contains('fine') || t.contains('gourmet')) return _restFineDining;
    if (t.contains('vegetarian') || t.contains('vegan')) return _restVegetarian;
    return _restCasual;
  }

  double _actFactor(String type) {
    final t = type.toLowerCase();
    if (t.contains('outdoor') || t.contains('nature') || t.contains('hike') || t.contains('park')) return _actOutdoor;
    if (t.contains('museum') || t.contains('cultural') || t.contains('gallery')) return _actMuseum;
    if (t.contains('theme') || t.contains('attraction') || t.contains('venue')) return _actThemePark;
    if (t.contains('tour') || t.contains('motorized')) return _actCityTour;
    return _actDefault;
  }

  FootprintResult calculate(FootprintInput input) {
    double transportCO2 = 0.0;
    final legs = <FootprintLeg>[];

    for (final leg in input.transportLegs) {
      final kg = leg.distanceKm * leg.mode.kgCo2PerKm;
      transportCO2 += kg;
      legs.add(FootprintLeg(
        fromWaypoint: leg.fromName,
        toWaypoint: leg.toName,
        mode: leg.mode,
        distanceKm: leg.distanceKm,
        kgCO2: kg,
        dayNum: leg.dayNum,
      ));
    }

    double accommodationCO2 = 0.0;
    for (final acc in input.accommodations) {
      accommodationCO2 += _accFactor(acc.type) * acc.nights;
    }

    double restaurantCO2 = 0.0;
    for (final rest in input.restaurants) {
      restaurantCO2 += _restFactor(rest.type);
    }

    double activityCO2 = 0.0;
    for (final act in input.activities) {
      activityCO2 += _actFactor(act.type);
    }

    final totalCO2 = transportCO2 + accommodationCO2 + restaurantCO2 + activityCO2;
    final equivalents = _generateEquivalents(totalCO2);

    return FootprintResult(
      totalKgCO2: totalCO2,
      transportKgCO2: transportCO2,
      accommodationKgCO2: accommodationCO2,
      restaurantKgCO2: restaurantCO2,
      activityKgCO2: activityCO2,
      transportLegs: legs,
      equivalents: equivalents,
      personCount: input.personCount,
    );
  }

  List<FootprintEquivalent> _generateEquivalents(double kgCO2) {
    return [
      FootprintEquivalent(
        icon: Icons.water_drop_outlined,
        value: (kgCO2 / 0.267).round().clamp(0, 999999),
        label: 'Bottles of water',
      ),
      FootprintEquivalent(
        icon: Icons.checkroom_outlined,
        value: (kgCO2 / 6.0).round().clamp(0, 999999),
        label: 'T-Shirts',
      ),
      FootprintEquivalent(
        icon: Icons.eco,
        value: (kgCO2 / 0.51).round().clamp(0, 999999),
        label: 'Vegetarian meals',
      ),
      FootprintEquivalent(
        icon: Icons.directions_car_outlined,
        value: (kgCO2 / 0.171).round().clamp(0, 999999),
        label: 'Km by car',
      ),
    ];
  }

  /// Generate 2–3 eco tips based on the biggest CO2 contributor.
  List<String> generateTips(FootprintResult result) {
    final tips = <String>[];
    if (result.totalKgCO2 <= 0) return tips;

    final shareTransport = result.transportShare;
    final shareAcc = result.accommodationShare;
    final shareRest = result.restaurantShare;

    if (shareTransport >= 0.5 && result.transportKgCO2 > 0) {
      tips.add('Transport is your biggest impact. Consider train over flight for shorter distances.');
    }
    if (shareTransport >= 0.3 && result.transportLegs.any((l) => l.mode == FootprintTransportMode.flight)) {
      tips.add('Flying has high emissions. One fewer short-haul flight can save hundreds of kg CO2.');
    }
    if (shareAcc >= 0.3) {
      tips.add('Staying in eco-friendly or smaller accommodations can reduce your footprint.');
    }
    if (shareRest >= 0.2) {
      tips.add('Choosing vegetarian or local meals often lowers your trip\'s carbon impact.');
    }
    if (tips.length < 2 && result.transportKgCO2 > 0) {
      tips.add('Combine errands and prefer walking or cycling when possible.');
    }
    return tips.take(3).toList();
  }
}
