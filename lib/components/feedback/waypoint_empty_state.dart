import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';
import 'package:waypoint/components/buttons/waypoint_button.dart';

/// A styled empty state component following the Waypoint design system.
class WaypointEmptyState extends StatelessWidget {
  const WaypointEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackgroundColor,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  /// Factory for no trips
  factory WaypointEmptyState.noTrips({VoidCallback? onAction}) => WaypointEmptyState(
    icon: Icons.map_outlined,
    title: 'No trips yet',
    description: 'Start exploring and plan your first adventure!',
    actionLabel: 'Explore Plans',
    onAction: onAction,
  );

  /// Factory for no results
  factory WaypointEmptyState.noResults({VoidCallback? onAction}) => WaypointEmptyState(
    icon: Icons.search_off_rounded,
    title: 'No results found',
    description: 'Try adjusting your search or filters.',
    actionLabel: 'Clear filters',
    onAction: onAction,
  );

  /// Factory for no plans (builder)
  factory WaypointEmptyState.noPlans({VoidCallback? onAction}) => WaypointEmptyState(
    icon: Icons.edit_road_rounded,
    title: 'No plans created',
    description: 'Start building your first adventure plan!',
    actionLabel: 'Create Plan',
    onAction: onAction,
  );

  /// Factory for error state
  factory WaypointEmptyState.error({
    String? message,
    VoidCallback? onRetry,
  }) => WaypointEmptyState(
    icon: Icons.error_outline_rounded,
    title: 'Something went wrong',
    description: message ?? 'Please try again later.',
    actionLabel: 'Retry',
    onAction: onRetry,
    iconColor: SemanticColors.error,
    iconBackgroundColor: SemanticColors.errorLight,
  );

  /// Factory for offline state
  factory WaypointEmptyState.offline({VoidCallback? onRetry}) => WaypointEmptyState(
    icon: Icons.cloud_off_rounded,
    title: 'You\'re offline',
    description: 'Check your connection and try again.',
    actionLabel: 'Retry',
    onAction: onRetry,
    iconColor: SemanticColors.warning,
    iconBackgroundColor: SemanticColors.warningLight,
  );

  /// Factory for sign in required
  factory WaypointEmptyState.signInRequired({VoidCallback? onSignIn}) => WaypointEmptyState(
    icon: Icons.person_outline_rounded,
    title: 'Sign in required',
    description: 'Sign in to access this feature.',
    actionLabel: 'Sign In',
    onAction: onSignIn,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectiveBgColor = iconBackgroundColor ?? colorScheme.primaryContainer;

    return Center(
      child: Padding(
        padding: WaypointSpacing.paddingXl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon in colored circle
              Container(
                width: WaypointIconSizes.illustration,
                height: WaypointIconSizes.illustration,
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(height: WaypointSpacing.lg),
              // Title
              Text(
                title,
                style: WaypointTypography.title.copyWith(
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              // Description
              if (description != null) ...[
                const SizedBox(height: WaypointSpacing.sm),
                Text(
                  description!,
                  style: WaypointTypography.body.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DarkModeColors.onSurfaceSecondary
                        : LightModeColors.onSurfaceSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              // Action button
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: WaypointSpacing.lg),
                WaypointButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: WaypointButtonVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
