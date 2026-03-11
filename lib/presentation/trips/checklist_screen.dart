import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';

/// Checklist (packing) screen using shared components.
/// Uses [WaypointPackingProgressCard], [WaypointCreamChip], [WaypointPackingCategoryPanel],
/// [WaypointPackingListItem], [WaypointFAB] and theme colors via [BuildContext] extension.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _plans = PlanService();
  final _trips = TripService();

  Trip? _trip;
  Plan? _plan;
  PlanVersion? _version;
  MemberPacking? _packing;
  bool _loading = true;
  String? _userId;
  final Map<String, bool> _expandedCategories = {};
  final Map<String, bool> _expandedItems = {};

  static const _quickAddCategories = ['Vaccines', 'Electronics', 'Toiletries', 'Diversions', 'Documents'];

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
      var packing = await _trips.getMemberPacking(widget.tripId, _userId!);
      if (packing == null && version != null) {
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
      if (mounted) {
        setState(() {
          _trip = trip;
          _plan = plan;
          _version = version;
          _packing = packing;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading checklist: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _packedCount {
    if (_packing == null || _version == null) return 0;
    int n = 0;
    for (final cat in _version!.packingCategories) {
      for (final item in cat.items) {
        if (_packing!.items[item.id] == true) n++;
      }
    }
    return n;
  }

  int get _totalCount {
    if (_version == null) return 0;
    return _version!.packingCategories.fold<int>(0, (s, c) => s + c.items.length);
  }

  bool _isExpandedCategory(int index) => _expandedCategories['$index'] ?? (index == 0);

  void _toggleCategory(int index) {
    setState(() {
      _expandedCategories['$index'] = !(_expandedCategories['$index'] ?? (index == 0));
    });
  }

  bool _isExpandedItem(String itemId) => _expandedItems[itemId] ?? false;

  void _toggleItemExpanded(String itemId) {
    setState(() {
      _expandedItems[itemId] = !(_expandedItems[itemId] ?? false);
    });
  }

  Future<void> _toggleItem(String itemId, bool checked) async {
    if (_userId == null || _packing == null) return;
    final updated = Map<String, bool>.from(_packing!.items)..[itemId] = checked;
    setState(() {
      _packing = _packing!.copyWith(items: updated);
    });
    try {
      await _trips.toggleMemberPackingItem(
        tripId: widget.tripId,
        memberId: _userId!,
        itemId: itemId,
        checked: checked,
      );
      final updatedPacking = await _trips.getMemberPacking(widget.tripId, _userId!);
      if (mounted && updatedPacking != null) {
        setState(() => _packing = updatedPacking);
      }
    } catch (e) {
      if (mounted) _load();
    }
  }

  static IconData _iconForCategoryName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('drink')) return Icons.restaurant_rounded;
    if (lower.contains('cloth')) return Icons.checkroom_rounded;
    if (lower.contains('technical') || lower.contains('gear')) return Icons.hiking_rounded;
    if (lower.contains('document')) return Icons.article_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checklist')),
        body: const Center(child: Text('Please sign in')),
      );
    }
    if (_trip == null || _plan == null || _version == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/mytrips'),
          ),
          title: const Text('Checklist'),
        ),
        body: const Center(child: Text('Failed to load trip')),
      );
    }

    final trip = _trip!;
    final plan = _plan!;
    final version = _version!;
    final categories = version.packingCategories;
    final creatorName = 'Creator'; // TODO: resolve from plan.creatorId

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAppBar(trip, plan, creatorName)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: WaypointPackingProgressCard(
              packedCount: _packedCount,
              totalCount: _totalCount,
              title: 'Packing Progress',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildQuickAdd()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (categories.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No packing categories yet. Add one below.')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WaypointPackingCategoryPanel(
                    title: categories[index].name,
                    icon: _iconForCategoryName(categories[index].name),
                    isExpanded: _isExpandedCategory(index),
                    onToggle: () => _toggleCategory(index),
                    onDelete: () {},
                    children: categories[index].items.map((item) {
                      final isChecked = _packing?.items[item.id] == true;
                      final qty = item.quantity ?? 1;
                      return WaypointPackingListItem(
                        name: item.name,
                        qty: qty,
                        isChecked: isChecked,
                        onToggle: () => _toggleItem(item.id, !isChecked),
                        isEssential: false,
                        isExpanded: _isExpandedItem(item.id),
                        onTap: () => _toggleItemExpanded(item.id),
                        onDelete: () {},
                        expandedChild: (item.note != null || item.link != null || item.price != null)
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.colors.outline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (item.note != null) Text(item.note!, style: const TextStyle(fontSize: 13)),
                                    if (item.link != null) const SizedBox(height: 8),
                                    if (item.link != null) Text('Link: ${item.link}', style: const TextStyle(fontSize: 12)),
                                    if (item.price != null) const SizedBox(height: 8),
                                    if (item.price != null) Text('Price: ${item.price}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                    footer: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.add, size: 16, color: context.colors.primary),
                              label: Text('Add Item', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: context.colors.outline),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: context.colors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: context.colors.onSurface.withValues(alpha: 0.7)),
                            label: Text('Show More', style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                childCount: categories.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: WaypointFAB(
        heroTag: 'checklist_new_category_fab',
        icon: Icons.add,
        label: 'New Category',
        onPressed: () {},
      ),
    );
  }

  Widget _buildAppBar(Trip trip, Plan plan, String creatorName) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.colors.onSurface),
                  onPressed: () => context.go('/mytrips'),
                ),
                const Spacer(),
                IconButton(icon: Icon(Icons.ios_share_outlined, color: context.colors.onSurface), onPressed: () {}),
                IconButton(icon: Icon(Icons.more_vert, color: context.colors.onSurface), onPressed: () {}),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title?.isNotEmpty == true ? trip.title! : plan.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.location,
                    style: TextStyle(fontSize: 13, color: context.colors.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          creatorName.isNotEmpty ? creatorName.substring(0, 1).toUpperCase() : '?',
                          style: TextStyle(color: context.colors.onPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Created by', style: TextStyle(fontSize: 11, color: context.colors.onSurface.withValues(alpha: 0.6))),
                          Text('Creator', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.onSurface)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAdd() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'Quick Add Categories',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.colors.onSurface),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAddCategories.map((label) => WaypointCreamChip(
              label: label,
              selected: false,
              onTap: () {},
            )).toList(),
          ),
        ),
      ],
    );
  }
}
