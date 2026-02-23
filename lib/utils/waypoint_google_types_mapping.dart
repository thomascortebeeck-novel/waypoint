import 'package:waypoint/models/route_waypoint.dart';

/// Result of mapping Google Place types to waypoint type and subcategories.
/// Used when a place is selected from search to auto-set category and subcategory.
class WaypointTypeSuggestion {
  final WaypointType type;
  final POIAccommodationType? accommodationType;
  final EatCategory? eatCategory;
  final AttractionCategory? attractionCategory;
  final SightCategory? sightCategory;
  final ServiceCategory? serviceCategory;
  /// Display labels for tags (same strings as get*Label); populated in same fromGoogleTypes pass.
  final List<String> subCategoryLabels;

  const WaypointTypeSuggestion({
    required this.type,
    this.accommodationType,
    this.eatCategory,
    this.attractionCategory,
    this.sightCategory,
    this.serviceCategory,
    this.subCategoryLabels = const [],
  });

  /// Maps Google Place types to a single suggested waypoint type and subcategories.
  /// Priority order: Lodging → Sleep; Food/drink → Eat; Transport → Move;
  /// Cultural/monument/scenic → See; else → Do.
  /// When no type matches, returns Do & See (attraction) with all subcategories null.
  static WaypointTypeSuggestion fromGoogleTypes(List<String> types) {
    final lower = types.map((t) => t.toLowerCase()).toList();

    // 1. Lodging → Sleep (accommodation) + POIAccommodationType
    for (final t in lower) {
      if (t.contains('lodging') || t == 'hotel' || t == 'motel' ||
          t.contains('bed_and_breakfast') || t.contains('hostel') ||
          t.contains('campground') || t.contains('camping') ||
          t.contains('vacation_rental') || t.contains('guest_house')) {
        POIAccommodationType? acc = POIAccommodationType.hotel;
        if (t.contains('bed_and_breakfast')) acc = POIAccommodationType.bedAndBreakfast;
        else if (t.contains('hostel')) acc = POIAccommodationType.hostel;
        else if (t.contains('campground') || t.contains('camping')) acc = POIAccommodationType.camping;
        else if (t.contains('vacation_rental') || t.contains('guest_house')) acc = POIAccommodationType.vacationRental;
        else if (t == 'hotel' || t == 'lodging') acc = POIAccommodationType.hotel;
        final label = getPOIAccommodationTypeLabel(acc);
        return WaypointTypeSuggestion(
          type: WaypointType.accommodation,
          accommodationType: acc,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
    }

    // 2. Food/drink → Eat & Drink + EatCategory
    for (final t in lower) {
      if (t.contains('restaurant') && !t.contains('fast')) {
        final label = getEatCategoryLabel(EatCategory.diningRestaurant);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.diningRestaurant,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t == 'cafe' || t.contains('cafe')) {
        final label = getEatCategoryLabel(EatCategory.cafe);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.cafe,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t == 'bar' || t.contains('bar')) {
        final label = getEatCategoryLabel(EatCategory.bar);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.bar,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('fast_food') || t.contains('meal_takeaway')) {
        final label = getEatCategoryLabel(EatCategory.quickBite);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.quickBite,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('bakery')) {
        final label = getEatCategoryLabel(EatCategory.bakery);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.bakery,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t == 'food') {
        final label = getEatCategoryLabel(EatCategory.diningRestaurant);
        return WaypointTypeSuggestion(
          type: WaypointType.restaurant,
          eatCategory: EatCategory.diningRestaurant,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
    }

    // 3. Transport → Move (service) + ServiceCategory
    for (final t in lower) {
      if (t.contains('train_station') || t.contains('rail')) {
        final label = getServiceCategoryLabel(ServiceCategory.trainStation);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.trainStation,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('bus_station') || t == 'bus_station' || t == 'transit_station') {
        final label = getServiceCategoryLabel(ServiceCategory.bus);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.bus,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('airport') || t.contains('airline')) {
        final label = getServiceCategoryLabel(ServiceCategory.plane);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.plane,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('car_rental') || t.contains('parking')) {
        final label = getServiceCategoryLabel(ServiceCategory.carRental);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.carRental,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('bike') || t.contains('bicycle')) {
        final label = getServiceCategoryLabel(ServiceCategory.bike);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.bike,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('subway') || t.contains('ferry')) {
        final label = getServiceCategoryLabel(ServiceCategory.trainStation);
        return WaypointTypeSuggestion(
          type: WaypointType.service,
          serviceCategory: ServiceCategory.trainStation,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
    }

    // 4. Cultural / monument / scenic → See (viewingPoint) + SightCategory
    for (final t in lower) {
      if (t.contains('natural_feature') || t.contains('scenic') || t.contains('viewpoint')) {
        SightCategory? sight = SightCategory.viewpoint;
        if (t.contains('scenic')) sight = SightCategory.scenicSpot;
        final label = getSightCategoryLabel(sight);
        return WaypointTypeSuggestion(
          type: WaypointType.viewingPoint,
          sightCategory: sight,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('monument') || t.contains('memorial')) {
        final label = getSightCategoryLabel(SightCategory.monument);
        return WaypointTypeSuggestion(
          type: WaypointType.viewingPoint,
          sightCategory: SightCategory.monument,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('observation') || t.contains('observation_deck')) {
        final label = getSightCategoryLabel(SightCategory.observationDeck);
        return WaypointTypeSuggestion(
          type: WaypointType.viewingPoint,
          sightCategory: SightCategory.observationDeck,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('landmark') || t.contains('cultural_landmark') || t.contains('historical')) {
        final label = getSightCategoryLabel(SightCategory.landmark);
        return WaypointTypeSuggestion(
          type: WaypointType.viewingPoint,
          sightCategory: SightCategory.landmark,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t == 'tourist_attraction' && (lower.any((x) => x.contains('museum')) || lower.any((x) => x.contains('park')))) {
        // Could be Do; but if we see tourist_attraction with nothing else specific, treat as See
      }
    }
    if (lower.any((t) => t == 'tourist_attraction' || t == 'point_of_interest') &&
        lower.any((t) => t.contains('museum') || t.contains('park') || t.contains('zoo') || t.contains('aquarium'))) {
      // Do
    } else if (lower.any((t) => t == 'tourist_attraction' || t == 'point_of_interest')) {
      final label = getSightCategoryLabel(SightCategory.landmark);
      return WaypointTypeSuggestion(
        type: WaypointType.viewingPoint,
        sightCategory: SightCategory.landmark,
        subCategoryLabels: label.isNotEmpty ? [label] : [],
      );
    }

    // 5. Everything else → Do & See (attraction) + AttractionCategory
    for (final t in lower) {
      if (t.contains('museum') || t.contains('art_gallery')) {
        final label = getAttractionCategoryLabel(AttractionCategory.museumsAndCulture);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.museumsAndCulture,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('park') || t.contains('hiking') || t.contains('natural')) {
        final label = getAttractionCategoryLabel(AttractionCategory.natureAndOutdoors);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.natureAndOutdoors,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('night_club') || t.contains('nightlife')) {
        final label = getAttractionCategoryLabel(AttractionCategory.nightlife);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.nightlife,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('stadium') || t.contains('gym') || t.contains('sport')) {
        final label = getAttractionCategoryLabel(AttractionCategory.sportsAndActivities);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.sportsAndActivities,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('amusement_park') || t.contains('aquarium') || t.contains('zoo')) {
        final label = getAttractionCategoryLabel(AttractionCategory.entertainment);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.entertainment,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t.contains('tour_agency') || t.contains('travel_agency')) {
        final label = getAttractionCategoryLabel(AttractionCategory.toursAndExperiences);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.toursAndExperiences,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
      if (t == 'tourist_attraction' || t == 'point_of_interest') {
        final label = getAttractionCategoryLabel(AttractionCategory.sightsAndLandmarks);
        return WaypointTypeSuggestion(
          type: WaypointType.attraction,
          attractionCategory: AttractionCategory.sightsAndLandmarks,
          subCategoryLabels: label.isNotEmpty ? [label] : [],
        );
      }
    }

    // Fallback: no match
    return const WaypointTypeSuggestion(type: WaypointType.attraction);
  }

  /// Returns the list of allowed subcategory display labels for the given waypoint type (for Tags sheet).
  static List<String> allowedSubCategoryLabels(WaypointType type) {
    switch (type) {
      case WaypointType.accommodation:
        return POIAccommodationType.values
            .map((e) => getPOIAccommodationTypeLabel(e))
            .where((s) => s.isNotEmpty)
            .toList();
      case WaypointType.restaurant:
      case WaypointType.bar:
        return EatCategory.values
            .map((e) => getEatCategoryLabel(e))
            .where((s) => s.isNotEmpty)
            .toList();
      case WaypointType.attraction:
      case WaypointType.activity:
        return AttractionCategory.values
            .map((e) => getAttractionCategoryLabel(e))
            .where((s) => s.isNotEmpty)
            .toList();
      case WaypointType.viewingPoint:
        return SightCategory.values
            .map((e) => getSightCategoryLabel(e))
            .where((s) => s.isNotEmpty)
            .toList();
      case WaypointType.service:
      case WaypointType.servicePoint:
        return ServiceCategory.values
            .map((e) => getServiceCategoryLabel(e))
            .where((s) => s.isNotEmpty)
            .toList();
      default:
        return [];
    }
  }
}
