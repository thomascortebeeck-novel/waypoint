import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

/// Screen for individual member to track their packing checklist
class MemberPackingScreen extends StatefulWidget {
  final String tripId;

  const MemberPackingScreen({super.key, required this.tripId});

  @override
  State<MemberPackingScreen> createState() => _MemberPackingScreenState();
}

class _MemberPackingScreenState extends State<MemberPackingScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  
  Trip? _trip;
  Plan? _plan;
  PlanVersion? _version;
  MemberPacking? _packing;
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    if (_userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final trip = await _trips.getTripById(widget.tripId);
      if (trip == null) {
        setState(() => _loading = false);
        return;
      }

      final plan = await _plans.getPlanById(trip.planId);
      final version = plan?.versions.firstWhere(
        (v) => v.id == trip.versionId,
        orElse: () => plan!.versions.first,
      );

      // Get or create member packing
      var packing = await _trips.getMemberPacking(widget.tripId, _userId!);
      
      if (packing == null && version != null) {
        // Initialize packing list for this member
        final allItems = <String>[];
        for (final category in version.packingCategories) {
          for (final item in category.items) {
            allItems.add(item.id);
          }
        }
        
        if (allItems.isNotEmpty) {
          await _trips.initializeMemberPacking(
            tripId: widget.tripId,
            memberId: _userId!,
            itemIds: allItems,
          );
          packing = await _trips.getMemberPacking(widget.tripId, _userId!);
        }
      }

      setState(() {
        _trip = trip;
        _plan = plan;
        _version = version;
        _packing = packing;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading packing: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Packing List')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    if (_trip == null || _plan == null || _version == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/mytrips'),
          ),
          title: const Text('My Packing List'),
        ),
        body: const Center(child: Text('Failed to load trip')),
      );
    }

    final categories = _version!.packingCategories;
    final checkedCount = _packing?.checkedCount ?? 0;
    final totalCount = _packing?.totalCount ?? 0;
    final progress = _packing?.progress ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.terrain),
          onPressed: () => context.go('/itinerary/${_trip!.planId}/setup/${_trip!.id}'),
        ),
        title: const Text('My Packing List'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: context.colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: progress >= 1 ? Colors.green : context.colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        progress >= 1 ? Icons.check : Icons.backpack,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress >= 1 ? 'All packed!' : 'Pack for ${_trip!.title ?? _plan!.name}',
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$checkedCount of $totalCount items',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: progress >= 1 ? Colors.green : context.colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: context.colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1 ? Colors.green : context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categories list
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.backpack_outlined, size: 64, color: context.colors.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No packing list available',
                          style: context.textStyles.bodyLarge?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _PackingCategoryCard(
                        category: category,
                        packing: _packing,
                        onToggleItem: _toggleItem,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleItem(String itemId, bool checked) async {
    if (_userId == null) return;
    
    try {
      await _trips.toggleMemberPackingItem(
        tripId: widget.tripId,
        memberId: _userId!,
        itemId: itemId,
        checked: checked,
      );

      // Refresh packing
      final packing = await _trips.getMemberPacking(widget.tripId, _userId!);
      setState(() => _packing = packing);
    } catch (e) {
      debugPrint('Error toggling item: $e');
    }
  }
}

class _PackingCategoryCard extends StatelessWidget {
  final PackingCategory category;
  final MemberPacking? packing;
  final Function(String itemId, bool checked) onToggleItem;

  const _PackingCategoryCard({
    required this.category,
    required this.packing,
    required this.onToggleItem,
  });

  int get _checkedCount {
    if (packing == null) return 0;
    int count = 0;
    for (final item in category.items) {
      if (packing!.items[item.id] == true) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = _checkedCount == category.items.length && category.items.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: allChecked
                ? Colors.green.withValues(alpha: 0.5)
                : context.colors.outline,
          ),
          borderRadius: BorderRadius.circular(16),
          color: allChecked ? Colors.green.withValues(alpha: 0.05) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (allChecked)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        size: 16,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$_checkedCount/${category.items.length}',
                    style: context.textStyles.labelMedium?.copyWith(
                      color: allChecked ? Colors.green : context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Items
            ...category.items.map((item) {
              final isChecked = packing?.items[item.id] == true;
              return InkWell(
                onTap: () => onToggleItem(item.id, !isChecked),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (v) => onToggleItem(item.id, v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        activeColor: Colors.green,
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: context.textStyles.bodyMedium?.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? context.colors.onSurfaceVariant
                                : context.colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
