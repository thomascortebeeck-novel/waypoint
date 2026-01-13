import 'package:flutter/material.dart';
import 'package:waypoint/theme.dart';

/// Step indicator with labels, used across Setup, Pack, Travel
class StepIndicator extends StatelessWidget {
  final int currentStep; // 1-indexed
  final int totalSteps;
  final List<String> labels;

  const StepIndicator({super.key, required this.currentStep, required this.totalSteps, required this.labels})
      : assert(currentStep >= 1),
        assert(totalSteps >= 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps * 2 - 1, (i) {
            if (i.isOdd) {
              // connector
              final leftIndex = (i - 1) ~/ 2 + 1; // 1-indexed
              final completed = leftIndex < currentStep;
              return Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: completed ? context.colors.primary : context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }
            final stepIndex = i ~/ 2 + 1; // 1-indexed
            final active = stepIndex == currentStep;
            final completed = stepIndex < currentStep;
            return _StepCircle(index: stepIndex, active: active, completed: completed);
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(totalSteps, (i) {
            final active = i + 1 == currentStep;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: active ? context.colors.primary : context.colors.onSurfaceVariant,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final bool active;
  final bool completed;
  const _StepCircle({required this.index, required this.active, required this.completed});

  @override
  Widget build(BuildContext context) {
    final bg = active || completed ? context.colors.primary : context.colors.surface;
    final fg = active || completed ? context.colors.onPrimary : context.colors.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? context.colors.primary : context.colors.outlineVariant, width: active ? 2 : 1),
      ),
      child: Center(
        child: Icon(
          completed ? Icons.check : Icons.circle,
          size: completed ? 18 : 6,
          color: completed ? fg : context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
