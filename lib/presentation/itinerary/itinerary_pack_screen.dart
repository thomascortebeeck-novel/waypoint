import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/step_indicator.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

class ItineraryPackScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  const ItineraryPackScreen({super.key, required this.planId, required this.tripId});

  @override
  State<ItineraryPackScreen> createState() => _ItineraryPackScreenState();
}

class _ItineraryPackScreenState extends State<ItineraryPackScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  Trip? _trip;
  PlanVersion? _version;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await _plans.getPlanById(widget.planId);
    final trip = await _trips.getTripById(widget.tripId);
    final version = plan?.versions.firstWhere(
      (v) => v.id == trip?.versionId,
      orElse: () => plan!.versions.first,
    );

    // Auto-initialize packing checklist if not already done
    if (trip != null && version != null) {
      final hasExistingChecklist = trip.packingChecklist != null && trip.packingChecklist!.isNotEmpty;
      final flatItems = version.packingCategories.expand((c) => c.items.map((i) => i.name)).toList();
      
      if (!hasExistingChecklist && flatItems.isNotEmpty) {
        await _trips.initializePackingChecklist(tripId: trip.id, items: flatItems);
        final updatedTrip = await _trips.getTripById(trip.id);
        setState(() {
          _plan = plan;
          _trip = updatedTrip;
          _version = version;
          _loading = false;
        });
        return;
      }
    }

    setState(() {
      _plan = plan;
      _trip = trip;
      _version = version;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_trip == null || _plan == null || _version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('What to pack')),
        body: const Center(child: Text('Failed to load')),
      );
    }

    final checklist = _trip!.packingChecklist ?? {};
    final categories = _version!.packingCategories;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/itinerary/${widget.planId}/setup/${widget.tripId}'),
        ),
        title: const Text('What to pack'),
      ),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.backpack_outlined, size: 64, color: context.colors.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No packing list available',
                    style: context.textStyles.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This version doesn\'t have a packing list defined',
                    style: context.textStyles.bodyMedium?.copyWith(color: context.colors.outline),
                  ),
                ],
              ),
            )
          : ListView(
              padding: AppSpacing.paddingLg,
              children: [
                StepIndicator(currentStep: 2, totalSteps: 3, labels: const ['Setup', 'Pack', 'Travel']),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('What to pack?', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: context.colors.onSurface)),
                      const SizedBox(height: 6),
                      Text('Check off items as you pack them for your trip', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                    ]),
                  ),
                  _OverallChecklistProgress(checklist: checklist, categories: categories),
                ]),
                const SizedBox(height: 16),
                // Categories list - all expanded by default
                ...categories.map((cat) => PackingCategoryCard(
                      category: cat,
                      checklist: checklist,
                      onItemToggled: (itemName, checked) async {
                        await _trips.togglePackingItem(
                          tripId: _trip!.id,
                          item: itemName,
                          checked: checked,
                        );
                        final updatedTrip = await _trips.getTripById(_trip!.id);
                        if (mounted) setState(() => _trip = updatedTrip);
                      },
                    )),
              ],
            ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.go('/itinerary/${widget.planId}/setup/${widget.tripId}'),
        backLabel: 'Back',
        onNext: () => context.push('/itinerary/${_plan!.id}/travel/${_trip!.id}'),
        nextLabel: 'Next',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }
}

class PackingCategoryCard extends StatefulWidget {
  final PackingCategory category;
  final Map<String, bool> checklist;
  final Future<void> Function(String itemName, bool checked) onItemToggled;

  const PackingCategoryCard({
    super.key,
    required this.category,
    required this.checklist,
    required this.onItemToggled,
  });

  @override
  State<PackingCategoryCard> createState() => _PackingCategoryCardState();
}

class _PackingCategoryCardState extends State<PackingCategoryCard> {
  bool _isExpanded = true; // Expanded by default

  @override
  Widget build(BuildContext context) {
    final checkedCount = widget.category.items
        .where((item) => widget.checklist[item.name] == true)
        .length;
    final totalCount = widget.category.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
        children: [
          // Category header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppRadius.md),
              bottom: _isExpanded ? Radius.zero : const Radius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getCategoryIcon(widget.category.name),
                      color: context.colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.name,
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$checkedCount of $totalCount items packed',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator
                  if (totalCount > 0) ...[
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: checkedCount / totalCount,
                            backgroundColor: context.colors.surfaceContainerHighest,
                            color: context.colors.primary,
                            strokeWidth: 3,
                          ),
                          Center(
                            child: Text(
                              '${((checkedCount / totalCount) * 100).round()}%',
                              style: context.textStyles.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Items list
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md),
                ),
              ),
              child: Column(
                children: widget.category.items.map((item) {
                  final isChecked = widget.checklist[item.name] ?? false;
                  return InkWell(
                    onTap: () => widget.onItemToggled(item.name, !isChecked),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Custom checkbox
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isChecked ? context.colors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isChecked ? context.colors.primary : context.colors.outline,
                                width: 2,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: context.textStyles.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    decoration: isChecked ? TextDecoration.lineThrough : null,
                                    color: isChecked
                                        ? context.colors.onSurfaceVariant
                                        : context.colors.onSurface,
                                  ),
                                ),
                                if (item.description != null && item.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.description!,
                                      style: context.textStyles.bodySmall?.copyWith(
                                        color: context.colors.outline,
                                        decoration: isChecked ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('cloth') || name.contains('wear')) return Icons.checkroom;
    if (name.contains('tech') || name.contains('electronic')) return Icons.devices;
    if (name.contains('document') || name.contains('paper')) return Icons.description;
    if (name.contains('health') || name.contains('medic') || name.contains('first aid')) return Icons.medical_services;
    if (name.contains('toiletr') || name.contains('hygiene')) return Icons.wash;
    if (name.contains('gear') || name.contains('equipment')) return Icons.hiking;
    if (name.contains('food') || name.contains('snack')) return Icons.restaurant;
    if (name.contains('safety') || name.contains('emergency')) return Icons.health_and_safety;
    if (name.contains('camping') || name.contains('outdoor')) return Icons.park;
    if (name.contains('general') || name.contains('essential')) return Icons.backpack;
    return Icons.inventory_2;
  }
}

class _OverallChecklistProgress extends StatelessWidget {
  final Map<String, bool> checklist;
  final List<PackingCategory> categories;
  const _OverallChecklistProgress({required this.checklist, required this.categories});

  @override
  Widget build(BuildContext context) {
    final allItems = categories.expand((c) => c.items.map((i) => i.name)).toList();
    final total = allItems.length;
    final done = allItems.where((n) => checklist[n] == true).length;
    final progress = total == 0 ? 0.0 : done / total;
    final pct = ((progress) * 100).round();
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(value: progress, strokeWidth: 6, backgroundColor: context.colors.surfaceContainerHighest, color: context.colors.primary),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$pct%', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colors.primary)),
            Text('packed', style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}
