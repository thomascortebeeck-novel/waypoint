import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/presentation/trips/invite_share_sheet.dart';

class ItinerarySetupScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  const ItinerarySetupScreen({super.key, required this.planId, required this.tripId});

  @override
  State<ItinerarySetupScreen> createState() => _ItinerarySetupScreenState();
}

class _ItinerarySetupScreenState extends State<ItinerarySetupScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  Trip? _trip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plan = await _plans.getPlanById(widget.planId);
      final trip = await _trips.getTripById(widget.tripId);
      setState(() {
        _plan = plan;
        _trip = trip;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_plan == null || _trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Dashboard')),
        body: const Center(child: Text('Failed to load trip')),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = _trip!.isOwner(currentUserId ?? '');
    final memberCount = _trip!.memberIds.length;
    final isReady = _trip!.customizationStatus == TripCustomizationStatus.ready;
    final version = _plan!.versions.firstWhere(
      (v) => v.id == _trip!.versionId,
      orElse: () => _plan!.versions.first,
    );

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.go('/mytrips'),
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
        title: Text(_trip!.title ?? _plan!.name, style: context.textStyles.titleLarge),
        actions: [
          // Share button (owner can always share/invite)
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => InviteShareSheet(trip: _trip!),
              ),
              tooltip: 'Invite Members',
            ),
          // Members button
          if (memberCount > 1)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => context.push('/trip/${_trip!.id}/members'),
              tooltip: 'View Members',
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          // Trip info header card
          _TripInfoCard(
            trip: _trip!,
            plan: _plan!,
            version: version,
          ),
          const SizedBox(height: 20),
          
          // Customization status card (for owner when not ready)
          if (isOwner && !isReady) ...[
            _CustomizationStatusCard(
              trip: _trip!,
              planId: widget.planId,
            ),
            const SizedBox(height: 20),
          ],
          
          // Member count banner (if group trip)
          if (memberCount > 1) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.group, color: context.colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$memberCount people are going on this trip',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/trip/${_trip!.id}/members'),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Quick actions section
          Text(
            'Quick Actions',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Quick action grid
          _QuickActionsGrid(
            trip: _trip!,
            plan: _plan!,
            isOwner: isOwner,
            isReady: isReady,
          ),
          
          const SizedBox(height: 24),
          
          // Read-only banner for non-owners
          if (!isOwner) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only the trip owner can edit trip settings and selections',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Trip info header card showing trip details
class _TripInfoCard extends StatelessWidget {
  final Trip trip;
  final Plan plan;
  final PlanVersion version;

  const _TripInfoCard({
    required this.trip,
    required this.plan,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version and duration
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
          const SizedBox(height: 12),
          // Dates if set
          if (trip.startDate != null) ...[
            Row(
              children: [
                Icon(Icons.event, size: 16, color: context.colors.primary),
                const SizedBox(width: 8),
                Text(
                  trip.endDate != null
                      ? '${DateFormat('MMM d').format(trip.startDate!)} - ${DateFormat('MMM d, yyyy').format(trip.endDate!)}'
                      : 'Starting ${DateFormat('MMM d, yyyy').format(trip.startDate!)}',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Status badge
          Row(
            children: [
              Icon(
                trip.customizationStatus == TripCustomizationStatus.ready
                    ? Icons.check_circle
                    : Icons.pending,
                size: 16,
                color: trip.customizationStatus == TripCustomizationStatus.ready
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                trip.customizationStatus == TripCustomizationStatus.ready
                    ? 'Ready to travel'
                    : trip.customizationStatus == TripCustomizationStatus.customizing
                        ? 'Customization in progress'
                        : 'Setup required',
                style: context.textStyles.bodySmall?.copyWith(
                  color: trip.customizationStatus == TripCustomizationStatus.ready
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quick actions grid for trip dashboard
class _QuickActionsGrid extends StatelessWidget {
  final Trip trip;
  final Plan plan;
  final bool isOwner;
  final bool isReady;

  const _QuickActionsGrid({
    required this.trip,
    required this.plan,
    required this.isOwner,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.backpack,
                label: 'My Packing',
                description: 'Track your items',
                color: context.colors.primary,
                onTap: () => context.push('/trip/${trip.id}/packing'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.map,
                label: 'View Itinerary',
                description: 'Day by day',
                color: Colors.blue,
                onTap: isReady ? () => context.push('/itinerary/${plan.id}/day/${trip.id}/1') : null,
                disabled: !isReady,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.directions_car,
                label: 'Travel Info',
                description: 'How to get there',
                color: Colors.teal,
                onTap: () => context.push('/itinerary/${plan.id}/travel/${trip.id}'),
              ),
            ),
            const SizedBox(width: 12),
            if (isOwner)
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.edit,
                  label: 'Plan & Book Accommodations',
                  description: 'Customize your trip',
                  color: Colors.purple,
                  onTap: () => context.push('/itinerary/${plan.id}/select/${trip.id}'),
                ),
              )
            else
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.people,
                  label: 'Trip Members',
                  description: '${trip.memberIds.length} going',
                  color: Colors.orange,
                  onTap: () => context.push('/trip/${trip.id}/members'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card showing customization status for trip owner
class _CustomizationStatusCard extends StatelessWidget {
  final Trip trip;
  final String planId;

  const _CustomizationStatusCard({
    required this.trip,
    required this.planId,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    IconData icon;
    String title;
    String description;
    String? actionLabel;
    VoidCallback? onAction;

    switch (trip.customizationStatus) {
      case TripCustomizationStatus.draft:
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        icon = Icons.edit_note;
        title = 'Complete Your Trip Setup';
        description = 'Select accommodations, restaurants, and activities.';
        actionLabel = 'Start Planning';
        onAction = () => context.push('/itinerary/$planId/select/${trip.id}');
        break;
      case TripCustomizationStatus.customizing:
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        icon = Icons.tune;
        title = 'Continue Customizing';
        description = 'Finish selecting accommodations and activities.';
        actionLabel = 'Continue Planning';
        onAction = () => context.push('/itinerary/$planId/select/${trip.id}');
        break;
      case TripCustomizationStatus.ready:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        icon = Icons.check_circle;
        title = 'Trip Ready!';
        description = 'Your trip is set up and ready to share with friends.';
        actionLabel = 'Plan & Book Accommodations';
        onAction = () => context.push('/itinerary/$planId/select/${trip.id}');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: bgColor == Colors.green.shade50 ? Colors.green.shade700 : (bgColor == Colors.blue.shade50 ? Colors.blue.shade700 : Colors.orange.shade700)),
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
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card for members to access their personal packing list
class _MemberPackingCard extends StatelessWidget {
  final String tripId;

  const _MemberPackingCard({required this.tripId});

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
            child: const Icon(Icons.backpack, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Packing List',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track what you need to pack for this trip',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/trip/$tripId/packing'),
            icon: Icon(Icons.arrow_forward, color: context.colors.primary),
          ),
        ],
      ),
    );
  }
}
