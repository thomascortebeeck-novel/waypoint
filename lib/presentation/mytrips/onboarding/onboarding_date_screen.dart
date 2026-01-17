import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

/// Step 3/4: Start date selection (day, month, year)
class OnboardingDateScreen extends StatefulWidget {
  final String planId;
  final String tripName;
  final String versionId;
  const OnboardingDateScreen({
    super.key,
    required this.planId,
    required this.tripName,
    required this.versionId,
  });

  @override
  State<OnboardingDateScreen> createState() => _OnboardingDateScreenState();
}

class _OnboardingDateScreenState extends State<OnboardingDateScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  bool _loading = true;
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  bool _creating = false;

  PlanVersion? get _selectedVersion {
    if (_plan == null) return null;
    // Auto-select first version if versionId is empty (skipped version step)
    if (widget.versionId.isEmpty && _plan!.versions.isNotEmpty) {
      return _plan!.versions.first;
    }
    return _plan!.versions.where((v) => v.id == widget.versionId).firstOrNull;
  }

  DateTime? get _startDate {
    if (_selectedDay == null || _selectedMonth == null || _selectedYear == null) return null;
    return DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
  }

  DateTime? get _endDate {
    if (_startDate == null || _selectedVersion == null) return null;
    return _startDate!.add(Duration(days: _selectedVersion!.durationDays - 1));
  }

  List<DateTime> get _allTripDates {
    if (_startDate == null || _selectedVersion == null) return [];
    final dates = <DateTime>[];
    for (int i = 0; i < _selectedVersion!.durationDays; i++) {
      dates.add(_startDate!.add(Duration(days: i)));
    }
    return dates;
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
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load plan: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _continue() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a trip')),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a complete date')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      // Create trip
      final versionId = widget.versionId.isEmpty ? _selectedVersion!.id : widget.versionId;
      final id = await _trips.createTrip(
        planId: widget.planId,
        ownerId: uid,
        title: widget.tripName,
      );
      
      // Set version and dates
      await _trips.setTripVersionAndDates(
        tripId: id,
        versionId: versionId,
        start: _startDate,
        end: _endDate,
      );

      if (!mounted) return;
      // Navigate to image upload screen
      context.push('/mytrips/onboarding/${widget.planId}/image', extra: {
        'tripId': id,
      });
    } catch (e) {
      debugPrint('Create trip failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create trip: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_plan == null || _selectedVersion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Date Selection')),
        body: const Center(child: Text('Could not load plan')),
      );
    }

    final questionNumber = _plan!.versions.length == 1 ? 3 : 4;
    final totalQuestions = _plan!.versions.length == 1 ? 4 : 5;

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
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.paddingLg,
          children: [
            const SizedBox(height: 40),
            // Question number
            Text(
              'Question $questionNumber of $totalQuestions',
              style: context.textStyles.labelMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Question
            Text(
              'When does your adventure begin?',
              style: context.textStyles.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            // Date pickers
            Row(
              children: [
                Expanded(
                  child: _DatePickerColumn(
                    label: 'Day',
                    selectedValue: _selectedDay,
                    values: List.generate(31, (i) => i + 1),
                    onChanged: (value) => setState(() => _selectedDay = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _DatePickerColumn(
                    label: 'Month',
                    selectedValue: _selectedMonth,
                    values: List.generate(12, (i) => i + 1),
                    formatter: (value) => DateFormat.MMMM().format(DateTime(2024, value)),
                    onChanged: (value) => setState(() => _selectedMonth = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerColumn(
                    label: 'Year',
                    selectedValue: _selectedYear,
                    values: List.generate(3, (i) => DateTime.now().year + i),
                    onChanged: (value) => setState(() => _selectedYear = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Show all trip dates
            if (_allTripDates.isNotEmpty) ...[
              Text(
                'Your ${_selectedVersion!.durationDays}-day adventure',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _allTripDates.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < _allTripDates.length - 1 ? 8 : 0),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: context.textStyles.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE, MMMM d, y').format(_allTripDates[i]),
                              style: context.textStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.pop(),
        backLabel: 'Back',
        onNext: _creating || _startDate == null ? null : _continue,
        nextEnabled: !_creating && _startDate != null,
        nextLabel: _creating ? 'Creating…' : 'Continue',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }
}

class _DatePickerColumn extends StatelessWidget {
  final String label;
  final int? selectedValue;
  final List<int> values;
  final String Function(int)? formatter;
  final ValueChanged<int> onChanged;

  const _DatePickerColumn({
    required this.label,
    required this.selectedValue,
    required this.values,
    this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: context.colors.surface,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedValue,
              isExpanded: true,
              hint: Text(
                label,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              items: values.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(
                    formatter != null ? formatter!(value) : value.toString(),
                    style: context.textStyles.bodyMedium,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
