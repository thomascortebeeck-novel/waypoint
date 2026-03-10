/// Shared UI components for Home, My Trips, Checklist, and Explore.
/// Single DRY library — use [package:waypoint/theme/waypoint_colors.dart] for colors.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/waypoint/waypoint_cream_chip.dart';

export 'package:waypoint/components/waypoint/waypoint_cream_chip.dart';

// =============================================================================
// WaypointPageHeader
// =============================================================================

/// Gradient title + subtitle; used on Home, My Trips, Explore.
class WaypointPageHeader extends StatelessWidget {
  const WaypointPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.gradientColors,
    this.padding,
  });

  final String title;
  final String subtitle;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry? padding;

  /// Solid surface color to match bottom nav bar (no green tint).
  static List<Color> _surfaceGradient(BuildContext context) => [
    context.colors.surface,
    context.colors.surface,
  ];

  @override
  Widget build(BuildContext context) {
    final gradientColorsResolved = gradientColors ??
        (Theme.of(context).brightness == Brightness.dark
            ? [context.colors.primaryContainer, context.colors.surface]
            : _surfaceGradient(context));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColorsResolved,
        ),
      ),
      padding: padding ?? const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.onSurface,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WaypointSearchBar
// =============================================================================

/// Cream bg, green icon, placeholder; optional filter toggle, clear, focus, onSubmitted.
/// When [transparentBackground] is true, uses transparent fill and no border (for use inside a styled wrapper).
class WaypointSearchBar extends StatefulWidget {
  const WaypointSearchBar({
    super.key,
    this.placeholder = 'Where to next …',
    this.showFilterIcon = false,
    this.onTap,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onClear,
    this.margin,
    this.height,
    this.transparentBackground = false,
  });

  final String placeholder;
  final bool showFilterIcon;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry? margin;
  /// When set, overrides the default height (52). Use for hero search bar (e.g. 56 or 64).
  final double? height;
  /// When true, background is transparent and border is none (wrapper provides pill/surface).
  final bool transparentBackground;

  @override
  State<WaypointSearchBar> createState() => _WaypointSearchBarState();
}

class _WaypointSearchBarState extends State<WaypointSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant WaypointSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      widget.controller?.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = (widget.controller?.text.length ?? 0) > 0;
    final height = widget.height ?? 52.0;
    final decoration = BoxDecoration(
      color: widget.transparentBackground ? Colors.transparent : context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(widget.transparentBackground ? 999 : 14),
      border: widget.transparentBackground ? null : Border.all(color: context.colors.outline, width: 1.2),
    );
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: height,
        margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16),
        decoration: decoration,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.colors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: widget.controller != null
                  ? TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      onSubmitted: widget.onSubmitted,
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.6), fontSize: 15),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    )
                  : Text(
                      widget.placeholder,
                      style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.6), fontSize: 15),
                    ),
            ),
            if (hasText && widget.onClear != null)
              IconButton(
                icon: Icon(Icons.clear, color: context.colors.onSurface.withValues(alpha: 0.6), size: 20),
                onPressed: widget.onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (widget.showFilterIcon)
              Icon(Icons.tune_rounded, color: context.colors.onSurface.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WaypointCreamCard
// =============================================================================

/// Cream surface container (surface token, border, radius 16).
class WaypointCreamCard extends StatelessWidget {
  const WaypointCreamCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline),
      ),
      child: child,
    );
  }
}

// =============================================================================
// WaypointFAB
// =============================================================================

/// Green extended FAB; same style on My Trips ("New Itinerary") + Checklist ("New Category").
class WaypointFAB extends StatelessWidget {
  const WaypointFAB({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: BrandingLightTokens.appBarGreen,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

// =============================================================================
// WaypointUserAvatarGroup
// =============================================================================

/// Overlapping initials avatars with consistent brand colors.
class WaypointUserAvatarGroup extends StatelessWidget {
  const WaypointUserAvatarGroup({
    super.key,
    required this.initials,
    this.size = 26,
    this.overlap = 16,
    this.colors,
  });

  final List<String> initials;
  final double size;
  final double overlap;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    if (initials.isEmpty) return const SizedBox.shrink();
    final palette = colors ?? [
      context.colors.primary,
      context.colors.tertiary,
      context.colors.secondary,
      context.colors.primaryContainer,
    ];
    return SizedBox(
      height: size,
      width: size + (initials.length - 1) * overlap,
      child: Stack(
        children: List.generate(initials.length, (i) {
          return Positioned(
            left: i * overlap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: palette[i % palette.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                initials[i].length > 2 ? initials[i].substring(0, 2).toUpperCase() : initials[i].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// WaypointStatsRow
// =============================================================================

/// Divider-separated stats (e.g. 12.4k Routes | 850+ Adventures | 4.9/5).
class WaypointStatsRow extends StatelessWidget {
  const WaypointStatsRow({
    super.key,
    required this.items,
  });

  /// Pairs of (value, label), e.g. [('12.4k', 'Routes'), ('850+', 'Adventures')].
  final List<(String value, String label)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  color: context.colors.outline.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items[i].$1,
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: context.colors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$2,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WaypointTripCard
// =============================================================================

/// Image-left card with date, avatars, status chip; My Trips + Home "Your Recent Plans".
class WaypointTripCard extends StatelessWidget {
  const WaypointTripCard({
    super.key,
    required this.title,
    required this.dateRange,
    required this.initials,
    required this.status,
    this.imageWidget,
    this.onTap,
    this.onMenuTap,
  });

  final String title;
  final String dateRange;
  final List<String> initials;
  final String status;
  final Widget? imageWidget;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = status.toLowerCase() == 'upcoming';
    final isActive = status.toLowerCase() == 'active';
    final statusBg = isUpcoming
        ? context.colors.primaryContainer
        : isActive
            ? context.colors.tertiaryContainer
            : context.colors.surfaceContainerHighest;
    final statusFg = isUpcoming
        ? context.colors.onPrimaryContainer
        : isActive
            ? context.colors.onTertiaryContainer
            : context.colors.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: imageWidget ??
                    Container(
                      color: context.colors.surfaceContainerHighest,
                      child: Icon(Icons.landscape_outlined, size: 36, color: context.colors.onSurface.withValues(alpha: 0.5)),
                    ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: context.colors.onSurface,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (onMenuTap != null)
                            IconButton(
                              icon: Icon(Icons.more_vert, size: 18, color: context.colors.onSurface.withValues(alpha: 0.6)),
                              onPressed: onMenuTap,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: context.colors.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dateRange,
                              style: TextStyle(fontSize: 12, color: context.colors.onSurface.withValues(alpha: 0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          WaypointUserAvatarGroup(initials: initials),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusFg,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// WaypointLocationTag
// =============================================================================

/// Pill with map pin + text (e.g. "Cascade Mountains,…").
class WaypointLocationTag extends StatelessWidget {
  const WaypointLocationTag({
    super.key,
    required this.text,
    this.maxWidth = 120,
  });

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WaypointAdventureGridCard
// =============================================================================

/// Explore grid card; use with [WaypointLocationTag] for overlay pill.
class WaypointAdventureGridCard extends StatelessWidget {
  const WaypointAdventureGridCard({
    super.key,
    required this.title,
    required this.author,
    required this.rating,
    this.reviewCount,
    this.price,
    this.location,
    this.isFree = false,
    this.imageWidget,
    this.onTap,
  });

  final String title;
  final String author;
  final double rating;
  final int? reviewCount;
  final double? price;
  final String? location;
  final bool isFree;
  final Widget? imageWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.05,
                    child: imageWidget ??
                        Container(
                          color: context.colors.surfaceContainerHighest,
                          child: Icon(Icons.landscape_outlined, color: context.colors.onSurface.withValues(alpha: 0.5), size: 36),
                        ),
                  ),
                  if (location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: WaypointLocationTag(text: location!, maxWidth: 120),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: context.colors.onSurface,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        CircleAvatar(radius: 8, backgroundColor: context.colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            author,
                            style: TextStyle(fontSize: 11, color: context.colors.onSurface.withValues(alpha: 0.7)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 13, color: context.colors.primary),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  reviewCount != null ? '$rating ($reviewCount)' : '$rating',
                                  style: TextStyle(fontSize: 10, color: context.colors.onSurface.withValues(alpha: 0.7)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFree ? 'Free' : (price != null ? '\$${price!.toStringAsFixed(0)}' : '—'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
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
}

// =============================================================================
// WaypointFeaturedPlanCard (swimming lane: cream body, creator next to avatar)
// =============================================================================

/// Shared plan card for Explore and Home (marketplace): image with location overlay,
/// cream body with tags, title, price, and one row with avatar + creator name + rating.
/// Use this component for consistent plan cards across Explore and Home.
class WaypointFeaturedPlanCard extends StatelessWidget {
  const WaypointFeaturedPlanCard({
    super.key,
    required this.title,
    required this.creatorName,
    required this.rating,
    this.reviewCount,
    this.price,
    this.location,
    this.isFree = false,
    this.imageWidget,
    this.initials = const [],
    this.tagLabels = const [],
    this.onTap,
  });

  final String title;
  final String creatorName;
  final double rating;
  final int? reviewCount;
  final double? price;
  final String? location;
  final bool isFree;
  final Widget? imageWidget;
  final List<String> initials;
  final List<String> tagLabels;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.05,
                    child: imageWidget ??
                        Container(
                          color: context.colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.landscape_outlined,
                            color: context.colors.onSurface.withValues(alpha: 0.5),
                            size: 36,
                          ),
                        ),
                  ),
                  if (location != null && location!.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  location!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tagLabels.isNotEmpty) ...[
                      Row(
                        children: tagLabels.take(2).map((label) => Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.colors.outline),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.onSurface.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: context.colors.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFree ? 'Free' : (price != null ? '\$${price!.toStringAsFixed(0)}' : '—'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        WaypointUserAvatarGroup(initials: initials.isEmpty ? ['?'] : initials),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            creatorName,
                            style: TextStyle(fontSize: 10, color: context.colors.onSurface.withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.star_rounded, size: 11, color: context.colors.primary),
                        const SizedBox(width: 1),
                        Flexible(
                          child: Text(
                            reviewCount != null ? '$rating ($reviewCount)' : '$rating',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
}

// =============================================================================
// WaypointPackingProgressCard (CustomPainter)
// =============================================================================

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress, this.trackColor, this.progressColor);
  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (math.min(size.width, size.height) - 7) / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.trackColor != trackColor || old.progressColor != progressColor;
}

/// Circular progress with CustomPainter; "X of Y items packed".
class WaypointPackingProgressCard extends StatelessWidget {
  const WaypointPackingProgressCard({
    super.key,
    required this.packedCount,
    required this.totalCount,
    this.title = 'Packing Progress',
  });

  final int packedCount;
  final int totalCount;
  final String title;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? packedCount / totalCount : 0.0;
    return WaypointCreamCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$packedCount of $totalCount items packed',
                  style: TextStyle(fontSize: 13, color: context.colors.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress,
                context.colors.outline,
                context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WaypointPackingCategoryPanel + WaypointPackingListItem
// =============================================================================

/// Expandable cream panel: header (icon, name, delete, chevron), body = list of items.
class WaypointPackingCategoryPanel extends StatelessWidget {
  const WaypointPackingCategoryPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.isExpanded,
    required this.onToggle,
    this.onDelete,
    this.footer,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: context.colors.onSurface.withValues(alpha: 0.6)),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: context.colors.outline),
            ...children,
            if (footer != null) footer!,
          ],
        ],
      ),
    );
  }
}

/// Essential badge colors (light orange).
const _essentialBg = Color(0xFFFFF0E6);
const _essentialBorder = Color(0xFFF0C8A0);
const _essentialText = Color(0xFFCC6820);

/// Checkbox (animated), name, qty, Essential badge, delete; expandable inline edit fields.
class WaypointPackingListItem extends StatelessWidget {
  const WaypointPackingListItem({
    super.key,
    required this.name,
    required this.qty,
    required this.isChecked,
    required this.onToggle,
    this.isEssential = false,
    this.isExpanded = false,
    this.onTap,
    this.onDelete,
    this.expandedChild,
  });

  final String name;
  final int qty;
  final bool isChecked;
  final VoidCallback onToggle;
  final bool isEssential;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: isChecked ? context.colors.primary : context.colors.surface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isChecked ? context.colors.primary : context.colors.outline,
                        width: 1.5,
                      ),
                    ),
                    child: isChecked
                        ? Icon(Icons.check, size: 14, color: context.colors.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.colors.onSurface,
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                decorationColor: context.colors.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          if (isEssential) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _essentialBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _essentialBorder),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 10, color: _essentialText),
                                  SizedBox(width: 3),
                                  Text(
                                    'Essential',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _essentialText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Qty: $qty',
                        style: TextStyle(fontSize: 12, color: context.colors.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (onDelete != null)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: 17, color: context.colors.onSurface.withValues(alpha: 0.6)),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded && expandedChild != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: expandedChild,
          ),
        Divider(height: 1, indent: 16, endIndent: 16, color: context.colors.outline),
      ],
    );
  }
}
