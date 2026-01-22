import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

/// Screen to review all day selections before marking trip as ready
class ItineraryReviewScreen extends StatefulWidget {
  final String planId;
  final String tripId;

  const ItineraryReviewScreen({
    super.key,
    required this.planId,
    required this.tripId,
  });

  @override
  State<ItineraryReviewScreen> createState() => _ItineraryReviewScreenState();
}

class _ItineraryReviewScreenState extends State<ItineraryReviewScreen> {
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
      final plan = await _plans.getPlanById(widget.planId);
      final trip = await _trips.getTripById(widget.tripId);
      
      if (plan == null || trip == null) {
        setState(() => _loading = false);
        return;
      }

      final version = plan.versions.firstWhere(
        (v) => v.id == trip.versionId,
        orElse: () => plan.versions.first,
      );

      final selections = await _trips.getDaySelections(widget.tripId);

      setState(() {
        _plan = plan;
        _trip = trip;
        _version = version;
        _selections = selections;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  double get _totalCost {
    double total = 0;
    for (final selection in _selections) {
      total += selection.totalCost;
    }
    return total;
  }

  int get _totalPendingBookings {
    int count = 0;
    for (final selection in _selections) {
      count += selection.pendingBookingsCount;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null || _trip == null || _version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Selections')),
        body: const Center(child: Text('Failed to load data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.terrain),
          onPressed: () => context.go('/itinerary/${widget.planId}/setup/${widget.tripId}'),
        ),
        title: const Text('Review Your Trip'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip summary card
            _TripSummaryCard(
              trip: _trip!,
              plan: _plan!,
              totalCost: _totalCost,
              pendingBookings: _totalPendingBookings,
              totalDays: _version!.days.length,
            ),
            const SizedBox(height: 24),

            // Day-by-day breakdown
            Text(
              'Day-by-Day Plan',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            ..._selections.asMap().entries.map((entry) {
              final index = entry.key;
              final selection = entry.value;
              final day = index < _version!.days.length
                  ? _version!.days[index]
                  : null;

              return _DayReviewCard(
                dayNum: index + 1,
                dayTitle: day?.title ?? 'Day ${index + 1}',
                selection: selection,
                onEdit: () => _editDay(index),
              );
            }),

            const SizedBox(height: 24),

            // Ready to invite info
            _ReadyToInviteCard(
              pendingBookings: _totalPendingBookings,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.go('/itinerary/${widget.planId}/select/${widget.tripId}'),
        backLabel: 'Edit Selections',
        onNext: _saving ? null : _confirmAndContinue,
        nextEnabled: !_saving,
        nextLabel: _saving ? 'Saving...' : 'Confirm Selections',
        nextIcon: Icons.check,
      ),
    );
  }

  void _editDay(int dayIndex) {
    // Navigate back to select screen at specific day
    context.go('/itinerary/${widget.planId}/select/${widget.tripId}');
  }

  Future<void> _confirmAndContinue() async {
    setState(() => _saving = true);

    try {
      // Mark trip as ready for invites
      await _trips.updateCustomizationStatus(
        tripId: widget.tripId,
        status: TripCustomizationStatus.ready,
      );

      if (!mounted) return;

      // Navigate to setup screen (main trip dashboard)
      context.go('/itinerary/${widget.planId}/setup/${widget.tripId}');
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TripSummaryCard extends StatelessWidget {
  final Trip trip;
  final Plan plan;
  final double totalCost;
  final int pendingBookings;
  final int totalDays;

  const _TripSummaryCard({
    required this.trip,
    required this.plan,
    required this.totalCost,
    required this.pendingBookings,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.1),
            context.colors.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hiking, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title ?? plan.name,
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      plan.location,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: context.colors.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.calendar_today,
                  label: 'Duration',
                  value: '$totalDays days',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.euro,
                  label: 'Est. Cost',
                  value: '€${totalCost.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.book_online,
                  label: 'Bookings',
                  value: pendingBookings > 0 ? '$pendingBookings pending' : 'All done',
                  valueColor: pendingBookings > 0 ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: context.colors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.textStyles.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DayReviewCard extends StatelessWidget {
  final int dayNum;
  final String dayTitle;
  final TripDaySelection selection;
  final VoidCallback onEdit;

  const _DayReviewCard({
    required this.dayNum,
    required this.dayTitle,
    required this.selection,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelections = selection.selectedAccommodation != null ||
        selection.selectedRestaurants.isNotEmpty ||
        selection.selectedActivities.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasSelections
                    ? context.colors.primary
                    : context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '$dayNum',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasSelections ? Colors.white : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            title: Text(
              dayTitle,
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              hasSelections
                  ? _getSelectionSummary()
                  : 'No selections made',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            children: [
              if (selection.selectedAccommodation != null)
                _SelectionItem(
                  icon: Icons.hotel,
                  label: 'Stay',
                  value: selection.selectedAccommodation!.name,
                  cost: selection.selectedAccommodation!.cost,
                  bookingStatus: selection.selectedAccommodation!.bookingStatus,
                ),
              ...selection.selectedRestaurants.entries.map((e) => _SelectionItem(
                icon: Icons.restaurant,
                label: _mealLabel(e.key),
                value: e.value.name,
                cost: e.value.cost,
                bookingStatus: e.value.bookingStatus,
              )),
              ...selection.selectedActivities.map((a) => _SelectionItem(
                icon: Icons.local_activity,
                label: 'Activity',
                value: a.name,
                cost: a.cost,
                bookingStatus: a.bookingStatus,
              )),
              if (selection.totalCost > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Day total: ',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '€${selection.totalCost.toStringAsFixed(0)}',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSelectionSummary() {
    final parts = <String>[];
    if (selection.selectedAccommodation != null) parts.add('Stay');
    if (selection.selectedRestaurants.isNotEmpty) {
      parts.add('${selection.selectedRestaurants.length} meal${selection.selectedRestaurants.length > 1 ? 's' : ''}');
    }
    if (selection.selectedActivities.isNotEmpty) {
      parts.add('${selection.selectedActivities.length} activit${selection.selectedActivities.length > 1 ? 'ies' : 'y'}');
    }
    return parts.join(' • ');
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast': return 'Breakfast';
      case 'lunch': return 'Lunch';
      case 'dinner': return 'Dinner';
      default: return mealType;
    }
  }
}

class _SelectionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? cost;
  final WaypointBookingStatus bookingStatus;

  const _SelectionItem({
    required this.icon,
    required this.label,
    required this.value,
    this.cost,
    required this.bookingStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textStyles.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (bookingStatus == WaypointBookingStatus.notBooked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Book',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontSize: 10,
                ),
              ),
            ),
          if (bookingStatus == WaypointBookingStatus.booked)
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          if (cost != null) ...[
            const SizedBox(width: 8),
            Text(
              '€${cost!.toStringAsFixed(0)}',
              style: context.textStyles.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadyToInviteCard extends StatelessWidget {
  final int pendingBookings;

  const _ReadyToInviteCard({required this.pendingBookings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.group_add, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to invite friends!',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pendingBookings > 0
                      ? 'You can still make bookings later. Your trip is ready to share with friends.'
                      : 'Your trip plan is complete. Share it with friends to travel together!',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
