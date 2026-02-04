import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Badge variants
enum WaypointBadgeVariant {
  /// Featured content - primary filled
  featured,
  /// New items - orange
  newItem,
  /// Free content - green
  free,
  /// Price badge - orange filled
  price,
  /// Difficulty badge - semi-transparent black
  difficulty,
  /// Status badge - varies
  status,
  /// Admin badge - light primary
  admin,
  /// Custom badge
  custom,
}

/// Badge size
enum WaypointBadgeSize {
  /// 20px height
  small,
  /// 24px height
  medium,
  /// 28px height
  large,
}

/// A styled badge component following the Waypoint design system.
class WaypointBadge extends StatelessWidget {
  const WaypointBadge({
    super.key,
    required this.label,
    this.variant = WaypointBadgeVariant.custom,
    this.size = WaypointBadgeSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final WaypointBadgeVariant variant;
  final WaypointBadgeSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? backgroundColor;
  final Color? textColor;

  /// Factory constructor for featured badge
  factory WaypointBadge.featured() => const WaypointBadge(
    label: 'Featured',
    variant: WaypointBadgeVariant.featured,
    leadingIcon: Icons.star_rounded,
  );

  /// Factory constructor for new badge
  factory WaypointBadge.newItem() => const WaypointBadge(
    label: 'New',
    variant: WaypointBadgeVariant.newItem,
  );

  /// Factory constructor for free badge
  factory WaypointBadge.free() => const WaypointBadge(
    label: 'Free',
    variant: WaypointBadgeVariant.free,
  );

  /// Factory constructor for price badge
  factory WaypointBadge.price(String price) => WaypointBadge(
    label: price,
    variant: WaypointBadgeVariant.price,
  );

  /// Factory constructor for difficulty badge
  factory WaypointBadge.difficulty(String difficulty) => WaypointBadge(
    label: difficulty,
    variant: WaypointBadgeVariant.difficulty,
    leadingIcon: Icons.signal_cellular_alt_rounded,
  );

  /// Factory constructor for status badge
  factory WaypointBadge.status(String status, {bool isDraft = false, bool isCompleted = false}) {
    // Determine colors based on status
    Color bgColor;
    Color textColor;
    
    if (isCompleted) {
      bgColor = StatusColors.completed;
      textColor = Colors.white;
    } else if (isDraft || status.toLowerCase() == 'draft') {
      bgColor = StatusColors.draft;
      textColor = NeutralColors.textPrimary;
    } else {
      // Upcoming, Published, Customizing, In Progress → Primary Green
      bgColor = StatusColors.published;
      textColor = Colors.white;
    }
    
    return WaypointBadge(
      label: status,
      variant: WaypointBadgeVariant.status,
      backgroundColor: bgColor,
      textColor: textColor,
    );
  }

  /// Factory constructor for admin badge
  factory WaypointBadge.admin() => const WaypointBadge(
    label: 'Admin',
    variant: WaypointBadgeVariant.admin,
    leadingIcon: Icons.shield_rounded,
  );

  double get _height {
    switch (size) {
      case WaypointBadgeSize.small:
        return 20;
      case WaypointBadgeSize.medium:
        return 24;
      case WaypointBadgeSize.large:
        return 28;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case WaypointBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case WaypointBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      case WaypointBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
  }

  double get _iconSize {
    switch (size) {
      case WaypointBadgeSize.small:
        return 10;
      case WaypointBadgeSize.medium:
        return 12;
      case WaypointBadgeSize.large:
        return 14;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case WaypointBadgeSize.small:
        return WaypointTypography.tiny;
      case WaypointBadgeSize.medium:
        return WaypointTypography.small;
      case WaypointBadgeSize.large:
        return WaypointTypography.caption;
    }
  }

  Color _getBackgroundColor() {
    if (backgroundColor != null) return backgroundColor!;
    
    switch (variant) {
      case WaypointBadgeVariant.featured:
        return BrandColors.primary;
      case WaypointBadgeVariant.newItem:
        return AccentColors.orange;
      case WaypointBadgeVariant.free:
        return BrandColors.primary;
      case WaypointBadgeVariant.price:
        return AccentColors.orange;
      case WaypointBadgeVariant.difficulty:
        return Colors.black.withValues(alpha: 0.6);
      case WaypointBadgeVariant.status:
        return SemanticColors.successLight;
      case WaypointBadgeVariant.admin:
        return BrandColors.primaryLight;
      case WaypointBadgeVariant.custom:
        return NeutralColors.neutral200;
    }
  }

  Color _getTextColor() {
    if (textColor != null) return textColor!;
    
    switch (variant) {
      case WaypointBadgeVariant.featured:
      case WaypointBadgeVariant.newItem:
      case WaypointBadgeVariant.free:
      case WaypointBadgeVariant.price:
      case WaypointBadgeVariant.difficulty:
        return NeutralColors.neutral0;
      case WaypointBadgeVariant.status:
        return SemanticColors.success;
      case WaypointBadgeVariant.admin:
        return BrandColors.primary;
      case WaypointBadgeVariant.custom:
        return NeutralColors.neutral700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final fgColor = _getTextColor();

    return Container(
      height: _height,
      padding: _padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: WaypointRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: _iconSize,
              color: fgColor,
            ),
            SizedBox(width: size == WaypointBadgeSize.small ? 4 : 6),
          ],
          Text(
            label,
            style: _textStyle.copyWith(color: fgColor),
          ),
          if (trailingIcon != null) ...[
            SizedBox(width: size == WaypointBadgeSize.small ? 4 : 6),
            Icon(
              trailingIcon,
              size: _iconSize,
              color: fgColor,
            ),
          ],
        ],
      ),
    );
  }
}
