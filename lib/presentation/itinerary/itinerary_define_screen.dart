import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';
import 'package:waypoint/components/inputs/waypoint_text_field.dart';

/// Step 1 — Define itinerary: name, version selection, start date, and visual schedule
class ItineraryDefineScreen extends StatefulWidget {
  final String planId;
  const ItineraryDefineScreen({super.key, required this.planId});

  @override
  State<ItineraryDefineScreen> createState() => _ItineraryDefineScreenState();
}

class _ItineraryDefineScreenState extends State<ItineraryDefineScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  bool _loading = true;
  String? _selectedVersionId;
  final _nameController = TextEditingController();
  DateTime? _startDate;
  bool _saving = false;

  PlanVersion? get _selectedVersion {
    if (_plan == null || _selectedVersionId == null) return null;
    return _plan!.versions.where((v) => v.id == _selectedVersionId).firstOrNull;
  }

  DateTime? get _endDate {
    if (_startDate == null || _selectedVersion == null) return null;
    return _startDate!.add(Duration(days: _selectedVersion!.durationDays - 1));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plan = await _plans.getPlanById(widget.planId);
      setState(() {
        _plan = plan;
        _selectedVersionId = plan?.versions.firstOrNull?.id;
        _nameController.text = plan == null ? '' : 'Trip for ${plan.name}';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load plan for itinerary define: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/itinerary/${widget.planId}')),
          title: const Text('New Itinerary'),
        ),
        body: const Center(child: Text('Could not load plan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/itinerary/${widget.planId}')),
        title: const Text('New Itinerary'),
        centerTitle: false,
      ),
      body: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          // Header section with gradient icon
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(colors: [context.colors.primary, context.colors.secondary]),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Create your itinerary', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Set up your trip details', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),

          // Name
          Text('Itinerary name', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          WaypointTextField(controller: _nameController, hint: 'e.g., Summer Adventure 2026'),
          const SizedBox(height: 24),

          // Version selection FIRST
          Text('Pick a version', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._plan!.versions.map((v) => _VersionCard(
                version: v,
                isSelected: _selectedVersionId == v.id,
                onTap: () => setState(() => _selectedVersionId = v.id),
              )),

          const SizedBox(height: 24),

          // Start date only
          Text('When do you start?', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickStartDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
                color: context.colors.surface,
              ),
              child: Row(children: [
                Icon(Icons.calendar_today, color: context.colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _startDate == null ? 'Select start date' : DateFormat('MMMM d, yyyy').format(_startDate!),
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: _startDate == null ? context.colors.onSurfaceVariant : context.colors.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: context.colors.onSurfaceVariant),
              ]),
            ),
          ),

          // Visual schedule preview
          if (_selectedVersion != null && _startDate != null) ...[
            const SizedBox(height: 24),
            _SchedulePreview(
              startDate: _startDate!,
              durationDays: _selectedVersion!.durationDays,
              versionName: _selectedVersion!.name,
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.go('/itinerary/${widget.planId}'),
        backLabel: 'Back',
        onNext: _saving || _selectedVersionId == null ? null : _onCreate,
        nextEnabled: !_saving && _selectedVersionId != null && _nameController.text.trim().isNotEmpty,
        nextLabel: _saving ? 'Creating…' : 'Create and Continue',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      initialDate: _startDate ?? now,
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _onCreate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to create an itinerary')));
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await _trips.createTrip(planId: widget.planId, ownerId: uid, title: name);
      await _trips.setTripVersionAndDates(tripId: id, versionId: _selectedVersionId!, start: _startDate, end: _endDate);
      if (!mounted) return;
      context.push('/itinerary/${widget.planId}/pack/$id');
    } catch (e) {
      debugPrint('Create itinerary failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create itinerary')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Version selection card
class _VersionCard extends StatelessWidget {
  final PlanVersion version;
  final bool isSelected;
  final VoidCallback onTap;

  const _VersionCard({required this.version, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? context.colors.primary : context.colors.outline, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? context.colors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? context.colors.primary : context.colors.outline, width: 2),
                color: isSelected ? context.colors.primary : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(version.name, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule, size: 16, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${version.durationDays} days', style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  if (version.difficulty != Difficulty.none) ...[
                    const SizedBox(width: 12),
                    _chip(context, version.difficulty.name.toUpperCase()),
                  ],
                  if (version.comfortType != ComfortType.none) ...[
                    const SizedBox(width: 8),
                    _chip(context, version.comfortType.name.toUpperCase()),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: context.colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: context.textStyles.labelSmall),
      );
}

/// Visual schedule/agenda preview
class _SchedulePreview extends StatelessWidget {
  final DateTime startDate;
  final int durationDays;
  final String versionName;

  const _SchedulePreview({required this.startDate, required this.durationDays, required this.versionName});

  @override
  Widget build(BuildContext context) {
    final endDate = startDate.add(Duration(days: durationDays - 1));
    final dateFormat = DateFormat('MMM d');
    final dayFormat = DateFormat('EEE');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header with date range
        Row(children: [
          Icon(Icons.date_range, color: context.colors.primary),
          const SizedBox(width: 8),
          Text('Your Trip Schedule', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text(
          '${dateFormat.format(startDate)} – ${dateFormat.format(endDate)}, ${endDate.year}',
          style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Days timeline
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: durationDays,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = startDate.add(Duration(days: index));
              final isFirst = index == 0;
              final isLast = index == durationDays - 1;

              return Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: (isFirst || isLast) ? context.colors.primary.withValues(alpha: 0.1) : context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isFirst || isLast) ? context.colors.primary : context.colors.outlineVariant,
                    width: (isFirst || isLast) ? 2 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    'Day ${index + 1}',
                    style: context.textStyles.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: (isFirst || isLast) ? context.colors.primary : context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayFormat.format(date),
                    style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    dateFormat.format(date),
                    style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ]),
              );
            },
          ),
        ),

        const SizedBox(height: 12),
        // Summary row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.hiking, size: 20, color: context.colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurface),
                  children: [
                    TextSpan(text: '$durationDays days ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: 'of adventure with '),
                    TextSpan(text: versionName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
