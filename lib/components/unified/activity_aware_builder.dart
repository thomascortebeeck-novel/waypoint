import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';

/// Reusable widget that shows/hides children based on activity category
/// Used to conditionally display outdoor-specific features (GPX, distance, elevation)
/// vs city trip features
class ActivityAwareBuilder extends StatelessWidget {
  final ActivityCategory? activityCategory;
  final Set<ActivityCategory> showFor;
  final Widget child;
  
  const ActivityAwareBuilder({
    super.key,
    required this.activityCategory,
    required this.showFor,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    // Show all if activity category is not set yet (during initial editing)
    if (activityCategory == null) return child;
    
    // Show if activity is in the allowed set
    if (showFor.contains(activityCategory)) return child;
    
    // Hide otherwise
    return const SizedBox.shrink();
  }
}

