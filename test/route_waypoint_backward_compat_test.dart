import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Backward-compatibility tests per plan B.4.1.
/// Ensures existing JSON and enum values still parse after adding
/// eatCategory, attractionCategory, sightCategory and expanding enums.
void main() {
  group('RouteWaypoint backward compatibility', () {
    test('deserializes without new subcategory fields (eatCategory, attractionCategory, sightCategory)', () {
      final json = {
        'id': 'wp1',
        'type': 'restaurant',
        'position': {'lat': 59.9, 'lng': 10.7},
        'name': 'Test Restaurant',
        'order': 1,
      };
      final wp = RouteWaypoint.fromJson(json);
      expect(wp.eatCategory, isNull);
      expect(wp.attractionCategory, isNull);
      expect(wp.sightCategory, isNull);
      expect(wp.name, 'Test Restaurant');
    });

    test('accommodationType hotel still parses after POIAccommodationType expansion', () {
      final json = {
        'id': 'wp2',
        'type': 'accommodation',
        'position': {'lat': 59.9, 'lng': 10.7},
        'name': 'Test Hotel',
        'order': 1,
        'accommodationType': 'hotel',
      };
      final wp = RouteWaypoint.fromJson(json);
      expect(wp.accommodationType, POIAccommodationType.hotel);
    });

    test('serviceCategory trainStation parses and maps to Train label', () {
      final json = {
        'id': 'wp3',
        'type': 'service',
        'position': {'lat': 59.9, 'lng': 10.7},
        'name': 'Station',
        'order': 1,
        'serviceCategory': 'trainStation',
      };
      final wp = RouteWaypoint.fromJson(json);
      expect(wp.serviceCategory, ServiceCategory.trainStation);
      expect(getServiceCategoryLabel(wp.serviceCategory), 'Train');
    });

    test('serviceCategory carRental parses and maps to Car label', () {
      final json = {
        'id': 'wp4',
        'type': 'service',
        'position': {'lat': 59.9, 'lng': 10.7},
        'name': 'Rental',
        'order': 1,
        'serviceCategory': 'carRental',
      };
      final wp = RouteWaypoint.fromJson(json);
      expect(wp.serviceCategory, ServiceCategory.carRental);
      expect(getServiceCategoryLabel(wp.serviceCategory), 'Car');
    });

    test('serviceCategory bus parses and maps to Bus label', () {
      final json = {
        'id': 'wp5',
        'type': 'service',
        'position': {'lat': 59.9, 'lng': 10.7},
        'name': 'Bus Stop',
        'order': 1,
        'serviceCategory': 'bus',
      };
      final wp = RouteWaypoint.fromJson(json);
      expect(wp.serviceCategory, ServiceCategory.bus);
      expect(getServiceCategoryLabel(wp.serviceCategory), 'Bus');
    });
  });
}
