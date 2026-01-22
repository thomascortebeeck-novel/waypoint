import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';
import 'package:waypoint/components/components.dart';

/// Screen for trip owner to select waypoints - all days shown on one page
class ItinerarySelectScreen extends StatefulWidget {
  final String planId;
  final String tripId;

  const ItinerarySelectScreen({
    super.key,
    required this.planId,
    required this.tripId,
  });

  @override
  State<ItinerarySelectScreen> createState() => _ItinerarySelectScreenState();
}

class _ItinerarySelectScreenState extends State<ItinerarySelectScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  
  Plan? _plan;
  Trip? _trip;
  PlanVersion? _version;
  List<TripDaySelection> _selections = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      debugPrint('[ItinerarySelect] Loading plan ${widget.planId} and trip ${widget.tripId}');
      
      final plan = await _plans.getPlanById(widget.planId);
      debugPrint('[ItinerarySelect] Plan loaded: ${plan?.name}');
      
      final trip = await _trips.getTripById(widget.tripId);
      debugPrint('[ItinerarySelect] Trip loaded: ${trip?.id}, memberIds: ${trip?.memberIds}');
      
      if (plan == null || trip == null) {
        debugPrint('[ItinerarySelect] Plan or trip is null');
        setState(() => _loading = false);
        return;
      }

      final version = plan.versions.firstWhere(
        (v) => v.id == trip.versionId,
        orElse: () => plan.versions.first,
      );
      debugPrint('[ItinerarySelect] Version selected: ${version.name}, days: ${version.days.length}');

      // Check if selections already exist
      debugPrint('[ItinerarySelect] Getting day selections...');
      var selections = await _trips.getDaySelections(widget.tripId);
      debugPrint('[ItinerarySelect] Got ${selections.length} selections');
      
      // Initialize selections if not exist
      if (selections.isEmpty && version.days.isNotEmpty) {
        debugPrint('[ItinerarySelect] Initializing ${version.days.length} day selections...');
        await _trips.initializeDaySelections(
          tripId: widget.tripId,
          totalDays: version.days.length,
        );
        selections = await _trips.getDaySelections(widget.tripId);
        debugPrint('[ItinerarySelect] After init: ${selections.length} selections');
      }

      setState(() {
        _plan = plan;
        _trip = trip;
        _version = version;
        _selections = selections;
        _loading = false;
      });
      debugPrint('[ItinerarySelect] Load complete');
    } catch (e, stackTrace) {
      debugPrint('[ItinerarySelect] Error loading data: $e');
      debugPrint('[ItinerarySelect] Stack trace: $stackTrace');
      setState(() => _loading = false);
    }
  }

  /// Check if there are any selections made across all days
  bool get _hasAnySelections {
    for (final selection in _selections) {
      if (selection.selectedAccommodation != null ||
          selection.selectedRestaurants.isNotEmpty ||
          selection.selectedActivities.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null || _trip == null || _version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan & Book')),
        body: const Center(child: Text('Failed to load data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.go('/itinerary/${widget.planId}/setup/${widget.tripId}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terrain, color: context.colors.primary, size: 24),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
        title: const Text('Plan & Book Accommodations'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info card
            _HeaderInfoCard(
              plan: _plan!,
              trip: _trip!,
              version: _version!,
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.colors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select the accommodations, restaurants, activities, and service points you want to include in your trip. You can track bookings using the checkboxes.',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // All waypoints organized by day
            ..._version!.days.asMap().entries.map((entry) {
              final dayIndex = entry.key;
              final day = entry.value;
              final selection = dayIndex < _selections.length 
                  ? _selections[dayIndex] 
                  : null;

              return _DaySection(
                day: day,
                selection: selection,
                onSelectAccommodation: (acc) => _selectAccommodation(dayIndex, acc),
                onSelectRestaurant: (rest, mealType) => _selectRestaurant(dayIndex, rest, mealType),
                onToggleActivity: (act) => _toggleActivity(dayIndex, act),
                onToggleServicePoint: (sp) => _toggleServicePoint(dayIndex, sp),
                onToggleBooking: (waypointName, type, isBooked) => 
                    _toggleBookingStatus(dayIndex, waypointName, type, isBooked),
              );
            }),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.go('/itinerary/${widget.planId}/setup/${widget.tripId}'),
        backLabel: 'Back to Overview',
        onNext: _saving ? null : _confirmSelections,
        nextEnabled: !_saving && _hasAnySelections,
        nextLabel: _saving ? 'Saving...' : 'Confirm Selections',
        nextIcon: Icons.check,
      ),
    );
  }

  Future<void> _selectAccommodation(int dayIndex, AccommodationInfo accommodation) async {
    if (dayIndex >= _selections.length) return;
    
    final selected = SelectedWaypoint.fromAccommodation(accommodation);
    await _trips.updateDayAccommodation(
      tripId: widget.tripId,
      dayNum: dayIndex + 1,
      accommodation: selected,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _selectRestaurant(int dayIndex, RestaurantInfo restaurant, MealType mealType) async {
    if (dayIndex >= _selections.length) return;
    
    final selected = SelectedWaypoint.fromRestaurant(restaurant);
    final updatedRestaurants = Map<String, SelectedWaypoint>.from(
      _selections[dayIndex].selectedRestaurants,
    );
    updatedRestaurants[mealType.name] = selected;
    
    await _trips.updateDayRestaurants(
      tripId: widget.tripId,
      dayNum: dayIndex + 1,
      restaurants: updatedRestaurants,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _toggleActivity(int dayIndex, ActivityInfo activity) async {
    if (dayIndex >= _selections.length) return;
    
    final currentActivities = List<SelectedWaypoint>.from(
      _selections[dayIndex].selectedActivities,
    );
    
    final existingIndex = currentActivities.indexWhere((a) => a.name == activity.name);
    if (existingIndex >= 0) {
      currentActivities.removeAt(existingIndex);
    } else {
      currentActivities.add(SelectedWaypoint.fromActivity(activity));
    }
    
    await _trips.updateDayActivities(
      tripId: widget.tripId,
      dayNum: dayIndex + 1,
      activities: currentActivities,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _toggleServicePoint(int dayIndex, Map<String, dynamic> servicePoint) async {
    if (dayIndex >= _selections.length) return;
    
    final currentActivities = List<SelectedWaypoint>.from(
      _selections[dayIndex].selectedActivities,
    );
    
    final spName = servicePoint['name'] as String? ?? 'Service Point';
    final existingIndex = currentActivities.indexWhere((a) => a.name == spName);
    
    if (existingIndex >= 0) {
      currentActivities.removeAt(existingIndex);
    } else {
      // Create a SelectedWaypoint from service point
      currentActivities.add(SelectedWaypoint(
        name: spName,
        type: 'Service Point',
        bookingStatus: WaypointBookingStatus.notNeeded,
      ));
    }
    
    await _trips.updateDayActivities(
      tripId: widget.tripId,
      dayNum: dayIndex + 1,
      activities: currentActivities,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _toggleBookingStatus(int dayIndex, String waypointName, String type, bool isBooked) async {
    if (dayIndex >= _selections.length) return;
    
    final selection = _selections[dayIndex];
    final newStatus = isBooked 
        ? WaypointBookingStatus.booked 
        : WaypointBookingStatus.notBooked;

    // Update the appropriate waypoint
    if (selection.selectedAccommodation?.name == waypointName) {
      final updated = selection.selectedAccommodation!.copyWith(
        bookingStatus: newStatus,
      );
      await _trips.updateDayAccommodation(
        tripId: widget.tripId,
        dayNum: dayIndex + 1,
        accommodation: updated,
      );
    } else if (selection.selectedRestaurants.values.any((r) => r.name == waypointName)) {
      final updatedRestaurants = <String, SelectedWaypoint>{};
      for (final entry in selection.selectedRestaurants.entries) {
        if (entry.value.name == waypointName) {
          updatedRestaurants[entry.key] = entry.value.copyWith(
            bookingStatus: newStatus,
          );
        } else {
          updatedRestaurants[entry.key] = entry.value;
        }
      }
      await _trips.updateDayRestaurants(
        tripId: widget.tripId,
        dayNum: dayIndex + 1,
        restaurants: updatedRestaurants,
      );
    } else {
      // Must be an activity
      final updatedActivities = selection.selectedActivities.map((a) {
        if (a.name == waypointName) {
          return a.copyWith(bookingStatus: newStatus);
        }
        return a;
      }).toList();
      await _trips.updateDayActivities(
        tripId: widget.tripId,
        dayNum: dayIndex + 1,
        activities: updatedActivities,
      );
    }
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _confirmSelections() async {
    if (!_hasAnySelections) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please make at least one selection')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Mark trip as ready
      await _trips.updateCustomizationStatus(
        tripId: widget.tripId,
        status: TripCustomizationStatus.ready,
      );

      if (!mounted) return;

      // Navigate back to setup screen
      context.go('/itinerary/${widget.planId}/setup/${widget.tripId}');
    } catch (e) {
      debugPrint('Error saving selections: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Header info card showing trip details
class _HeaderInfoCard extends StatelessWidget {
  final Plan plan;
  final Trip trip;
  final PlanVersion version;

  const _HeaderInfoCard({
    required this.plan,
    required this.trip,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.1),
            context.colors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.title ?? plan.name,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  version.name,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${version.durationDays} days',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section for a single day showing all waypoints
class _DaySection extends StatelessWidget {
  final DayItinerary day;
  final TripDaySelection? selection;
  final Function(AccommodationInfo) onSelectAccommodation;
  final Function(RestaurantInfo, MealType) onSelectRestaurant;
  final Function(ActivityInfo) onToggleActivity;
  final Function(Map<String, dynamic>) onToggleServicePoint;
  final Function(String waypointName, String type, bool isBooked) onToggleBooking;

  const _DaySection({
    required this.day,
    required this.selection,
    required this.onSelectAccommodation,
    required this.onSelectRestaurant,
    required this.onToggleActivity,
    required this.onToggleServicePoint,
    required this.onToggleBooking,
  });

  @override
  Widget build(BuildContext context) {
    // Get service points from the day's route
    final servicePoints = day.route?.poiWaypoints
        .where((wp) => wp['type'] == 'servicePoint')
        .toList() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${day.dayNum}',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.title,
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${day.distanceKm.toStringAsFixed(1)} km • ${day.estimatedTimeMinutes ~/ 60}h ${day.estimatedTimeMinutes % 60}m',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Accommodations
          if (day.accommodations.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.hotel,
              title: 'Accommodations',
              subtitle: 'Choose where to stay',
            ),
            const SizedBox(height: 12),
            ...day.accommodations.map((acc) => _SelectableWaypointCard(
              name: acc.name,
              type: WaypointType.accommodation,
              photoUrl: acc.linkImageUrl,
              website: acc.bookingLink,
              description: acc.linkDescription,
              typeLabel: acc.type,
              cost: acc.cost,
              isSelected: selection?.selectedAccommodation?.name == acc.name,
              isBooked: selection?.selectedAccommodation?.name == acc.name 
                  ? selection!.selectedAccommodation!.bookingStatus == WaypointBookingStatus.booked
                  : false,
              hasBookingLink: acc.bookingLink != null,
              onSelect: () => onSelectAccommodation(acc),
              onToggleBooking: (isBooked) => onToggleBooking(acc.name, 'accommodation', isBooked),
            )),
            const SizedBox(height: 16),
          ],

          // Restaurants
          if (day.restaurants.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.restaurant,
              title: 'Restaurants',
              subtitle: 'Choose where to eat',
            ),
            const SizedBox(height: 12),
            ..._buildRestaurantsByMeal(context, day.restaurants),
            const SizedBox(height: 16),
          ],

          // Activities
          if (day.activities.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.local_activity,
              title: 'Activities',
              subtitle: 'Select activities to do',
            ),
            const SizedBox(height: 12),
            ...day.activities.map((act) {
              final isSelected = selection?.selectedActivities
                  .any((a) => a.name == act.name) ?? false;
              final selectedActivity = isSelected 
                  ? selection!.selectedActivities.firstWhere((a) => a.name == act.name)
                  : null;
              
              return _SelectableWaypointCard(
                name: act.name,
                type: WaypointType.activity,
                photoUrl: act.linkImageUrl,
                website: act.bookingLink,
                description: act.description,
                cost: act.cost,
                isSelected: isSelected,
                isBooked: selectedActivity?.bookingStatus == WaypointBookingStatus.booked,
                hasBookingLink: act.bookingLink != null,
                onSelect: () => onToggleActivity(act),
                onToggleBooking: (isBooked) => onToggleBooking(act.name, 'activity', isBooked),
                isMultiSelect: true,
              );
            }),
            const SizedBox(height: 16),
          ],

          // Service Points
          if (servicePoints.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.local_gas_station,
              title: 'Service Points',
              subtitle: 'Useful stops along the way',
            ),
            const SizedBox(height: 12),
            ...servicePoints.map((sp) {
              final spName = sp['name'] as String? ?? 'Service Point';
              final isSelected = selection?.selectedActivities
                  .any((a) => a.name == spName) ?? false;
              
              return _SelectableWaypointCard(
                name: spName,
                type: WaypointType.servicePoint,
                description: sp['description'] as String?,
                isSelected: isSelected,
                isBooked: false,
                hasBookingLink: false,
                onSelect: () => onToggleServicePoint(sp),
                onToggleBooking: null,
                isMultiSelect: true,
              );
            }),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRestaurantsByMeal(BuildContext context, List<RestaurantInfo> restaurants) {
    final widgets = <Widget>[];
    
    for (final mealType in MealType.values) {
      final mealRestaurants = restaurants.where((r) => r.mealType == mealType).toList();
      if (mealRestaurants.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _mealTypeLabel(mealType),
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ));

      for (final restaurant in mealRestaurants) {
        final isSelected = selection?.selectedRestaurants[mealType.name]?.name == restaurant.name;
        final selectedRestaurant = isSelected 
            ? selection!.selectedRestaurants[mealType.name]!
            : null;

        widgets.add(_SelectableWaypointCard(
          name: restaurant.name,
          type: WaypointType.restaurant,
          photoUrl: restaurant.linkImageUrl,
          website: restaurant.bookingLink,
          description: restaurant.linkDescription,
          cost: restaurant.cost,
          isSelected: isSelected,
          isBooked: selectedRestaurant?.bookingStatus == WaypointBookingStatus.booked,
          hasBookingLink: restaurant.bookingLink != null,
          onSelect: () => onSelectRestaurant(restaurant, mealType),
          onToggleBooking: (isBooked) => onToggleBooking(restaurant.name, 'restaurant', isBooked),
          mealTime: _convertMealTypeToMealTime(mealType),
        ));
      }

      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  MealTime _convertMealTypeToMealTime(MealType type) {
    switch (type) {
      case MealType.breakfast: return MealTime.breakfast;
      case MealType.lunch: return MealTime.lunch;
      case MealType.dinner: return MealTime.dinner;
    }
  }

  String _mealTypeLabel(MealType type) {
    switch (type) {
      case MealType.breakfast: return '☀️ Breakfast';
      case MealType.lunch: return '🌤️ Lunch';
      case MealType.dinner: return '🌙 Dinner';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: context.colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selectable waypoint card with booking checkbox
class _SelectableWaypointCard extends StatelessWidget {
  final String name;
  final WaypointType type;
  final String? photoUrl;
  final String? website;
  final String? description;
  final String? typeLabel;
  final MealTime? mealTime;
  final double? cost;
  final bool isSelected;
  final bool isBooked;
  final bool hasBookingLink;
  final VoidCallback onSelect;
  final Function(bool)? onToggleBooking;
  final bool isMultiSelect;

  const _SelectableWaypointCard({
    required this.name,
    required this.type,
    required this.isSelected,
    required this.isBooked,
    required this.hasBookingLink,
    required this.onSelect,
    required this.onToggleBooking,
    this.photoUrl,
    this.website,
    this.description,
    this.typeLabel,
    this.mealTime,
    this.cost,
    this.isMultiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert to RouteWaypoint for unified display
    final waypoint = RouteWaypoint(
      type: type,
      position: const ll.LatLng(0, 0),
      name: name,
      description: description,
      order: 0,
      photoUrl: photoUrl,
      website: website,
      mealTime: mealTime,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          UnifiedWaypointCard(
            waypoint: waypoint,
            isSelectable: true,
            isSelected: isSelected,
            onSelect: onSelect,
            isCompact: true,
          ),
          // Booking checkbox overlay (only if selected and has booking link)
          if (isSelected && hasBookingLink && onToggleBooking != null)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => onToggleBooking!(!isBooked),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBooked ? Colors.green : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBooked ? Colors.green.shade700 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBooked ? Icons.check_circle : Icons.circle_outlined,
                        size: 14,
                        color: isBooked ? Colors.white : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBooked ? 'Booked' : 'Book',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isBooked ? Colors.white : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
