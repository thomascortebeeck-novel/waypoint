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

/// Screen for trip owner to select waypoints for each day
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
  int _currentDayIndex = 0;

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

  DayItinerary? get _currentDay {
    if (_version == null || _currentDayIndex >= _version!.days.length) return null;
    return _version!.days[_currentDayIndex];
  }

  TripDaySelection? get _currentSelection {
    if (_selections.isEmpty || _currentDayIndex >= _selections.length) return null;
    return _selections[_currentDayIndex];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null || _trip == null || _version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Waypoints')),
        body: const Center(child: Text('Failed to load data')),
      );
    }

    final totalDays = _version!.days.length;
    final day = _currentDay;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/itinerary/${widget.planId}/pack/${widget.tripId}'),
        ),
        title: Text('Day ${_currentDayIndex + 1} of $totalDays'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _skipDay,
            child: Text(
              'Skip Day',
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
      body: day == null
          ? const Center(child: Text('No day data'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  _DayHeader(day: day),
                  const SizedBox(height: 24),

                  // Accommodation section
                  if (day.accommodations.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.hotel,
                      title: 'Where to Stay',
                      subtitle: 'Select your accommodation',
                    ),
                    const SizedBox(height: 12),
                    ...day.accommodations.map((acc) => _SelectableWaypointCard(
                      name: acc.name,
                      type: WaypointType.accommodation,
                      photoUrl: acc.linkImageUrl,
                      website: acc.bookingLink,
                      description: acc.linkDescription,
                      typeLabel: acc.type,
                      isSelected: _currentSelection?.selectedAccommodation?.name == acc.name,
                      onSelect: () => _selectAccommodation(acc),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Restaurant section
                  if (day.restaurants.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.restaurant,
                      title: 'Where to Eat',
                      subtitle: 'Select restaurants for your meals',
                    ),
                    const SizedBox(height: 12),
                    ..._buildRestaurantsByMeal(day.restaurants),
                    const SizedBox(height: 24),
                  ],

                  // Activities section
                  if (day.activities.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.local_activity,
                      title: 'Activities',
                      subtitle: 'Select activities for the day',
                    ),
                    const SizedBox(height: 12),
                    ...day.activities.map((act) => _SelectableWaypointCard(
                      name: act.name,
                      type: WaypointType.activity,
                      photoUrl: act.linkImageUrl,
                      website: act.bookingLink,
                      description: act.description,
                      isSelected: _currentSelection?.selectedActivities
                          .any((a) => a.name == act.name) ?? false,
                      onSelect: () => _toggleActivity(act),
                      isMultiSelect: true,
                    )),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: _currentDayIndex > 0 ? _previousDay : null,
        backLabel: _currentDayIndex > 0 ? 'Previous Day' : 'Back',
        onNext: _saving ? null : _nextDay,
        nextEnabled: !_saving,
        nextLabel: _saving
            ? 'Saving...'
            : (_currentDayIndex < totalDays - 1 ? 'Next Day' : 'Review Selections'),
        nextIcon: Icons.arrow_forward,
      ),
    );
  }

  List<Widget> _buildRestaurantsByMeal(List<RestaurantInfo> restaurants) {
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
        widgets.add(_SelectableWaypointCard(
          name: restaurant.name,
          type: WaypointType.restaurant,
          photoUrl: restaurant.linkImageUrl,
          website: restaurant.bookingLink,
          description: restaurant.linkDescription,
          isSelected: _currentSelection?.selectedRestaurants[mealType.name]?.name == restaurant.name,
          onSelect: () => _selectRestaurant(restaurant, mealType),
          mealTime: _convertMealTypeToMealTime(mealType),
        ));
      }

      widgets.add(const SizedBox(height: 16));
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

  Future<void> _selectAccommodation(AccommodationInfo accommodation) async {
    if (_currentSelection == null) return;
    
    final selected = SelectedWaypoint.fromAccommodation(accommodation);
    await _trips.updateDayAccommodation(
      tripId: widget.tripId,
      dayNum: _currentDayIndex + 1,
      accommodation: selected,
    );
    
    // Refresh selections
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _selectRestaurant(RestaurantInfo restaurant, MealType mealType) async {
    if (_currentSelection == null) return;
    
    final selected = SelectedWaypoint.fromRestaurant(restaurant);
    final updatedRestaurants = Map<String, SelectedWaypoint>.from(
      _currentSelection!.selectedRestaurants,
    );
    updatedRestaurants[mealType.name] = selected;
    
    await _trips.updateDayRestaurants(
      tripId: widget.tripId,
      dayNum: _currentDayIndex + 1,
      restaurants: updatedRestaurants,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  Future<void> _toggleActivity(ActivityInfo activity) async {
    if (_currentSelection == null) return;
    
    final currentActivities = List<SelectedWaypoint>.from(
      _currentSelection!.selectedActivities,
    );
    
    final existingIndex = currentActivities.indexWhere((a) => a.name == activity.name);
    if (existingIndex >= 0) {
      currentActivities.removeAt(existingIndex);
    } else {
      currentActivities.add(SelectedWaypoint.fromActivity(activity));
    }
    
    await _trips.updateDayActivities(
      tripId: widget.tripId,
      dayNum: _currentDayIndex + 1,
      activities: currentActivities,
    );
    
    final selections = await _trips.getDaySelections(widget.tripId);
    setState(() => _selections = selections);
  }

  void _previousDay() {
    if (_currentDayIndex > 0) {
      setState(() => _currentDayIndex--);
    }
  }

  void _nextDay() {
    final totalDays = _version?.days.length ?? 0;
    if (_currentDayIndex < totalDays - 1) {
      setState(() => _currentDayIndex++);
    } else {
      // Go to review screen
      context.go('/itinerary/${widget.planId}/review/${widget.tripId}');
    }
  }

  void _skipDay() {
    _nextDay();
  }
}

class _DayHeader extends StatelessWidget {
  final DayItinerary day;

  const _DayHeader({required this.day});

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
            day.title,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day.description,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 14, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${day.distanceKm.toStringAsFixed(1)} km',
                      style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${day.estimatedTimeMinutes ~/ 60}h ${day.estimatedTimeMinutes % 60}m',
                      style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: context.colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(
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

/// Selectable waypoint card for itinerary selection
class _SelectableWaypointCard extends StatelessWidget {
  final String name;
  final WaypointType type;
  final String? photoUrl;
  final String? website;
  final String? description;
  final String? typeLabel;
  final MealTime? mealTime;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool isMultiSelect;

  const _SelectableWaypointCard({
    required this.name,
    required this.type,
    required this.isSelected,
    required this.onSelect,
    this.photoUrl,
    this.website,
    this.description,
    this.typeLabel,
    this.mealTime,
    this.isMultiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert to RouteWaypoint for unified display
    final waypoint = RouteWaypoint(
      type: type,
      position: const ll.LatLng(0, 0), // Position not needed for selection
      name: name,
      description: description,
      order: 0,
      photoUrl: photoUrl,
      website: website,
      mealTime: mealTime,
    );

    return UnifiedWaypointCard(
      waypoint: waypoint,
      isSelectable: true,
      isSelected: isSelected,
      onSelect: onSelect,
      isCompact: true,
    );
  }
}

