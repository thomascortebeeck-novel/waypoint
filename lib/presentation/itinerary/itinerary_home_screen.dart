import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_card.dart';

/// Itinerary home for a specific plan. Users can create and manage multiple itineraries.
class ItineraryHomeScreen extends StatelessWidget {
  final String planId;
  const ItineraryHomeScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Please sign in to manage itineraries'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/profile'), child: const Text('Go to profile')),
          ]),
        ),
      );
    }

    final trips = TripService();
    final plans = PlanService();

    return FutureBuilder<Plan?>(
      future: plans.getPlanById(planId),
      builder: (context, planSnap) {
        final plan = planSnap.data;
        return Scaffold(
          body: plan == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<Trip>>(
                  stream: trips.streamTripsForUserPlan(uid, planId),
                  builder: (context, snapshot) {
                    final hasError = snapshot.hasError;
                    final list = snapshot.data ?? [];
                    return CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 200,
                          pinned: true,
                          leading: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            ),
                            onPressed: () => context.go('/details/$planId'),
                          ),
                          flexibleSpace: FlexibleSpaceBar(
                            titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                            title: Text(plan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            background: Stack(fit: StackFit.expand, children: [
                              Image.network(plan.heroImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: context.colors.surfaceContainer)),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                                    stops: const [0.5, 1],
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: AppSpacing.paddingMd,
                            child: Text('Manage your trip itineraries', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                          ),
                        ),
                        if (hasError)
                          SliverToBoxAdapter(child: _ErrorOrEmpty(planId: planId, message: 'Could not load itineraries'))
                        else if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
                        else if (list.isEmpty)
                          SliverToBoxAdapter(child: _EmptyCreate(planId: planId))
                        else
                          SliverList.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (c, i) {
                              final t = list[i];
                              // Version lookup
                              PlanVersion? version;
                              if (plan.versions.isNotEmpty) {
                                try {
                                  version = plan.versions.firstWhere((v) => v.id == t.versionId);
                                } catch (_) {
                                  version = plan.versions.first;
                                }
                              }
                              final days = version?.durationDays;
                              final dr = _formatDateRange(t.startDate, t.endDate);
                              final status = _computeStatus(t.startDate, t.endDate);
                              return Padding(
                                padding: AppSpacing.paddingMd.copyWith(top: 0, bottom: 0),
                                child: ItineraryCard(
                                  title: t.title ?? 'Itinerary',
                                  dateRange: dr,
                                  days: days,
                                  versionName: version?.name,
                                  status: status,
                                  onTap: () => context.push('/itinerary/$planId/setup/${t.id}'),
                                  menuItems: const [
                                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                  onMenuSelected: (value) async {
                                    switch (value) {
                                      case 'rename':
                                        final name = await _promptName(context, t.title);
                                        if (name == null) return;
                                        try {
                                          await TripService().updateTripTitle(tripId: t.id, title: name);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary renamed')));
                                        } catch (e) {
                                          debugPrint('Rename itinerary error: $e');
                                        }
                                        break;
                                      case 'delete':
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete itinerary?'),
                                            content: const Text('This action cannot be undone.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await TripService().deleteTrip(t.id);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary deleted')));
                                          } catch (e) {
                                            debugPrint('Delete itinerary error: $e');
                                          }
                                        }
                                        break;
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/itinerary/$planId/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Itinerary'),
          ),
        );
      },
    );
  }
}

class _EmptyCreate extends StatelessWidget {
  final String planId;
  const _EmptyCreate({required this.planId});
  @override
  Widget build(BuildContext context) {
    // Creation is handled via the orange FAB only
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: context.colors.primaryContainer.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: Icon(Icons.route, color: context.colors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('No itineraries yet', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Tap the orange “New Itinerary” to get started.', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

class _ErrorOrEmpty extends StatelessWidget {
  final String planId;
  final String message;
  const _ErrorOrEmpty({required this.planId, required this.message});
  @override
  Widget build(BuildContext context) {
    // Creation via FAB only; this state shows feedback
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline, color: context.colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: context.textStyles.bodyMedium),
        ]),
      ),
    );
  }
}

/// Inline helper to prompt for a new itinerary name
Future<String?> _promptName(BuildContext context, String? planName) async {
  final controller = TextEditingController(text: planName == null ? null : 'Trip for $planName');
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Name your itinerary'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Summer Adventure'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(controller.text.trim().isEmpty ? null : controller.text.trim()), child: const Text('Save')),
        ],
      );
    },
  );
}

class _ItineraryMenu extends StatelessWidget {
  final Trip trip;
  const _ItineraryMenu({required this.trip});
  @override
  Widget build(BuildContext context) {
    final service = TripService();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'rename':
            final name = await _promptName(context, trip.title);
            if (name == null) return;
            try {
              await service.updateTripTitle(tripId: trip.id, title: name);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary renamed')));
            } catch (e) {
              debugPrint('Rename itinerary error: $e');
            }
            break;
          case 'delete':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete itinerary?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirm != true) return;
            try {
              await service.deleteTrip(trip.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary deleted')));
            } catch (e) {
              debugPrint('Delete itinerary error: $e');
            }
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

String? _formatDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return null;
  if (start != null && end != null) {
    return '${_fmt(start)} – ${_fmt(end)}';
  }
  if (start != null) return 'Starts ${_fmt(start)}';
  if (end != null) return 'Ends ${_fmt(end)}';
  return null;
}

String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

ItineraryStatus _computeStatus(DateTime? start, DateTime? end) {
  final now = DateTime.now();
  if (start == null || end == null) return ItineraryStatus.upcoming;
  if (now.isBefore(start)) return ItineraryStatus.upcoming;
  if (now.isAfter(end)) return ItineraryStatus.completed;
  return ItineraryStatus.inProgress;
}
