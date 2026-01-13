import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';

/// Legacy PlanCard - now wraps AdventureCard for backwards compatibility
/// Use AdventureCard directly for new code
class PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback? onTap;

  const PlanCard({super.key, required this.plan, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AdventureCard(
      plan: plan,
      variant: AdventureCardVariant.standard,
      showFavoriteButton: !plan.isFeatured,
      onTap: onTap ?? () => context.push('/details/${plan.id}'),
    );
  }
}
