import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

/// Step 3: Version selection
class OnboardingVersionScreen extends StatefulWidget {
  final String planId;
  final String tripName;
  const OnboardingVersionScreen({super.key, required this.planId, required this.tripName});

  @override
  State<OnboardingVersionScreen> createState() => _OnboardingVersionScreenState();
}

class _OnboardingVersionScreenState extends State<OnboardingVersionScreen> {
  final _plans = PlanService();
  Plan? _plan;
  bool _loading = true;
  String? _selectedVersionId;

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
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load plan: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Version Selection')),
        body: const Center(child: Text('Could not load plan')),
      );
    }

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
              'Question 3 of 4',
              style: context.textStyles.labelMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Question
            Text(
              'Which version suits you best?',
              style: context.textStyles.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            // Version cards
            ..._plan!.versions.map((v) => _VersionCard(
                  version: v,
                  isSelected: _selectedVersionId == v.id,
                  onTap: () => setState(() => _selectedVersionId = v.id),
                )),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.pop(),
        backLabel: 'Back',
        onNext: _selectedVersionId == null
            ? null
            : () => context.push('/mytrips/onboarding/${widget.planId}/date', extra: {
                  'tripName': widget.tripName,
                  'versionId': _selectedVersionId!,
                }),
        nextEnabled: _selectedVersionId != null,
        nextLabel: 'Continue',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final PlanVersion version;
  final bool isSelected;
  final VoidCallback onTap;

  const _VersionCard({required this.version, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? context.colors.primary : context.colors.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? context.colors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.outline,
                    width: 2,
                  ),
                  color: isSelected ? context.colors.primary : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.name,
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: context.colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${version.durationDays} days',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        if (version.difficulty != Difficulty.none) ...[
                          const SizedBox(width: 12),
                          _chip(context, version.difficulty.name.toUpperCase()),
                        ],
                        if (version.comfortType != ComfortType.none) ...[
                          const SizedBox(width: 8),
                          _chip(context, version.comfortType.name.toUpperCase()),
                        ],
                      ],
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

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: context.textStyles.labelSmall),
      );
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
