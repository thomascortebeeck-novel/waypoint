import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/inputs/waypoint_text_field.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';
import 'package:waypoint/services/plan_service.dart';

/// Step 2: Trip name input
class OnboardingNameScreen extends StatefulWidget {
  final String planId;
  const OnboardingNameScreen({super.key, required this.planId});

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  final _nameController = TextEditingController();
  final _plans = PlanService();
  bool _loading = true;
  int _versionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await _plans.getPlanById(widget.planId);
      setState(() {
        _versionCount = plan?.versions.length ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      // Skip version selection if only 1 version
      if (_versionCount == 1) {
        context.push('/mytrips/onboarding/${widget.planId}/date', extra: {
          'tripName': name,
          'versionId': '', // Will be auto-selected in date screen
        });
      } else {
        context.push('/mytrips/onboarding/${widget.planId}/version', extra: name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final questionNumber = _versionCount == 1 ? 2 : 2;
    final totalQuestions = _versionCount == 1 ? 4 : 5;

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
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'What would you like to call your trip?',
                style: context.textStyles.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              // Name input
              WaypointTextField(
                controller: _nameController,
                hint: 'Give your trip an original name',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.pop(),
        backLabel: 'Back',
        onNext: _nameController.text.trim().isEmpty ? null : _continue,
        nextEnabled: _nameController.text.trim().isNotEmpty,
        nextLabel: 'Continue',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }
}
