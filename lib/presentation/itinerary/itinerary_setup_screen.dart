import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

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
  String? _selectedVersionId;
  DateTime? _start;
  DateTime? _end;
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
      setState(() {
        _plan = plan;
        _trip = trip;
        _selectedVersionId = trip?.versionId ?? plan?.versions.firstOrNull?.id;
        _start = trip?.startDate;
        _end = trip?.endDate;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedVersionId == null) return;
    setState(() => _saving = true);
    await _trips.setTripVersionAndDates(
      tripId: _trip!.id,
      versionId: _selectedVersionId!,
      start: _start,
      end: _end,
    );
    if (mounted) {
      context.push('/itinerary/${_plan!.id}/pack/${_trip!.id}');
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_plan == null || _trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary Setup')),
        body: const Center(child: Text('Failed to load itinerary')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/itinerary/${widget.planId}'),
        ),
        title: Text('Plan your trip', style: context.textStyles.titleLarge),
      ),
      body: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          // Version selection
          Text(
            'Choose a version',
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the adventure version that suits you best',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._plan!.versions.map((v) => VersionSelectionCard(
                version: v,
                isSelected: _selectedVersionId == v.id,
                onTap: () => setState(() => _selectedVersionId = v.id),
              )),
          const SizedBox(height: 32),
          // Date selection
          Text(
            'Select dates',
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When are you planning to go? (optional)',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DatePickerCard(
                  label: 'Start date',
                  date: _start,
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365 * 3)),
                      initialDate: _start ?? now,
                    );
                    if (date != null) setState(() => _start = date);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DatePickerCard(
                  label: 'End date',
                  date: _end,
                  onTap: () async {
                    final base = _start ?? DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      firstDate: base,
                      lastDate: base.add(const Duration(days: 365 * 3)),
                      initialDate: _end ?? base,
                    );
                    if (date != null) setState(() => _end = date);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 100), // Extra space for bottom bar
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/itinerary/${widget.planId}'),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: context.colors.onSurfaceVariant,
                ),
              ),
              ElevatedButton(
                onPressed: (_selectedVersionId == null || _saving) ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: context.colors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(120, 48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VersionSelectionCard extends StatelessWidget {
  final PlanVersion version;
  final bool isSelected;
  final VoidCallback onTap;

  const VersionSelectionCard({
    super.key,
    required this.version,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primaryContainer : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? context.colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${version.name} • ${version.durationDays} days',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? context.colors.primary : context.colors.onSurface,
                      ),
                    ),
                    if (version.difficulty != Difficulty.none || version.comfortType != ComfortType.none) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (version.difficulty != Difficulty.none)
                            _buildChip(context, version.difficulty.name.toUpperCase()),
                          if (version.comfortType != ComfortType.none)
                            _buildChip(context, version.comfortType.name.toUpperCase()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: context.textStyles.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class DatePickerCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const DatePickerCard({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              date == null ? Icons.event : Icons.event_available,
              color: date == null ? context.colors.outline : context.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date == null ? label : _formatDate(date!),
                style: context.textStyles.bodyMedium?.copyWith(
                  color: date == null ? context.colors.outline : context.colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
