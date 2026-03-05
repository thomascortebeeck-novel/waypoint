import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/components/badges/waypoint_badge.dart';
import 'package:waypoint/utils/activity_icons.dart';


enum AdventureCardVariant {
  standard,
  fullWidth,
  builder,
  /// Smaller card for "More by creator" carousel; avoids overflow, same component.
  compact,
  /// Image-only card for "About the creator" / "More by" carousel: just image + price badge, no text.
  imageOnly,
}

enum AdventureCardTheme {
  light,
  dark,
}

/// Modern cabin-style adventure card with portrait 4:5 aspect ratio
/// Inspired by premium booking platforms with dramatic gradient and social proof
class AdventureCard extends StatefulWidget {
  final Plan plan;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final AdventureCardVariant variant;
  final bool showFavoriteButton;
  final String? statusLabel; // For My Trips: "Upcoming", "Completed", etc.
  final AdventureCardTheme? theme;
  final bool isDeleting; // Whether this card is currently being deleted

  const AdventureCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onDelete,
    this.variant = AdventureCardVariant.standard,
    this.showFavoriteButton = false,
    this.statusLabel,
    this.theme,
    this.isDeleting = false,
  });

  @override
  State<AdventureCard> createState() => _AdventureCardState();
}

class _AdventureCardState extends State<AdventureCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imageScaleAnimation;
  bool _isHovered = false;

  bool get _isCompact => widget.variant == AdventureCardVariant.compact;
  bool get _isImageOnly => widget.variant == AdventureCardVariant.imageOnly;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _imageScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect theme automatically unless manually overridden
    final bool isDark = widget.theme == null
        ? Theme.of(context).brightness == Brightness.dark
        : widget.theme == AdventureCardTheme.dark;
    
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isDeleting ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _isHovered ? _scaleAnimation.value : 1.0,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(_isCompact || _isImageOnly ? 16 : 24),
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark
                      ? (_isHovered ? 0.35 : 0.3)
                      : (_isHovered ? 0.16 : 0.12)),
                  blurRadius: isDark
                      ? (_isHovered ? 20 : 16)
                      : (_isHovered ? 32 : 24),
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_isCompact || _isImageOnly ? 16 : 24),
              child: Stack(
                children: [
                  _isImageOnly
                      ? _buildImageSection(context, isDark)
                      : Column(
                          children: [
                            Expanded(
                              flex: 60,
                              child: _buildImageSection(context, isDark),
                            ),
                            Expanded(
                              flex: 40,
                              child: _buildBottomSection(context, isDark),
                            ),
                          ],
                        ),
                  if (widget.isDeleting) _buildDeletingOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, bool isDark) {
    final hasValidImageUrl = widget.plan.heroImageUrl.trim().isNotEmpty;
    final placeholder = Container(
      color: context.colors.surfaceContainerHighest,
      child: Icon(Icons.terrain, size: 48, color: context.colors.onSurface.withValues(alpha: 0.3)),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _imageScaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _isHovered ? _imageScaleAnimation.value : 1.0,
            child: child,
          ),
          child: hasValidImageUrl
              ? CachedNetworkImage(
                  imageUrl: widget.plan.heroImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.colors.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => placeholder,
                )
              : placeholder,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.6),
                      const Color(0xFF1F2937).withValues(alpha: 0.85),
                      const Color(0xFF1F2937).withValues(alpha: 0.98),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
          ),
        ),
        _buildPriceBadge(context),
        if (widget.variant == AdventureCardVariant.builder) _buildStatusBadge(context),
        if (widget.variant == AdventureCardVariant.builder && widget.onDelete != null) _buildDeleteButton(context),
        if (!_isImageOnly)
          Positioned(
          left: _isCompact ? 12 : 20,
          right: _isCompact ? 12 : 20,
          bottom: _isCompact ? 12 : 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.plan.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _isCompact ? 16 : 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: _isCompact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: _isCompact ? 4 : 8),
              if (widget.plan.location.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.locationDot,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: _isCompact ? 10 : 12,
                    ),
                    SizedBox(width: _isCompact ? 4 : 6),
                    Expanded(
                      child: Text(
                        widget.plan.location,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: _isCompact ? 11 : 14,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              // Season badge below location (skip in compact to save space)
              if (!_isCompact && _hasSeason(widget.plan)) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatSeasons(widget.plan),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Format season range as "Feb - Apr" or "Year-round" or "Feb - Apr, Sep - Nov"
  String _formatSeasonRange(int startMonth, int endMonth) {
    const monthAbbreviations = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    
    if (startMonth >= 1 && startMonth <= 12 && endMonth >= 1 && endMonth <= 12) {
      final start = monthAbbreviations[startMonth - 1];
      final end = monthAbbreviations[endMonth - 1];
      return '$start - $end';
    }
    return '';
  }

  /// Format seasons for display (handles multiple seasons and entire year)
  String _formatSeasons(Plan plan) {
    if (plan.isEntireYear) {
      return 'Year-round';
    }
    
    if (plan.bestSeasons.isNotEmpty) {
      return plan.bestSeasons.map((s) => _formatSeasonRange(s.startMonth, s.endMonth)).join(', ');
    }
    
    // Backward compatibility with old format
    if (plan.bestSeasonStartMonth != null && plan.bestSeasonEndMonth != null) {
      return _formatSeasonRange(plan.bestSeasonStartMonth!, plan.bestSeasonEndMonth!);
    }
    
    return '';
  }

  /// Check if plan has season information
  bool _hasSeason(Plan plan) {
    return plan.isEntireYear || 
           plan.bestSeasons.isNotEmpty ||
           (plan.bestSeasonStartMonth != null && plan.bestSeasonEndMonth != null);
  }

  // Label helpers (icons from activity_icons.dart)
  String _getActivityLabel(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.roadTripping:
        return 'Road Tripping';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trips';
      case ActivityCategory.tours:
        return 'Tours';
    }
  }
  
  String _getAccommodationLabel(AccommodationType type) {
    return type == AccommodationType.comfort ? 'Comfort' : 'Adventure';
  }

  Widget _buildPriceBadge(BuildContext context) {
    final isFree = widget.plan.minPrice == 0;
    
    // If showPrices is enabled, we could show estimated cost here, but for now keep plan price
    // The estimated cost is shown on detail pages in stats bar
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), // Matches WaypointBadge radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isFree 
          ? WaypointBadge.free()
          : WaypointBadge.price('€${widget.plan.minPrice.toStringAsFixed(0)}'),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isPublished = widget.plan.isPublished;
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), // Matches WaypointBadge radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: WaypointBadge.status(
          isPublished ? 'Published' : 'Draft',
          isDraft: !isPublished,
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Positioned(
      top: 16,
      right: 72,
      child: GestureDetector(
        onTap: widget.isDeleting ? null : widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: widget.isDeleting ? 0.5 : 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDeletingOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Deleting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, bool isDark) {
    final hPad = _isCompact ? 12.0 : 20.0;
    final vPad = _isCompact ? 6.0 : 10.0;
    final descLines = _isCompact ? 1 : 2;
    final descHeight = _isCompact ? 18.0 : 42.0;
    final descSize = _isCompact ? 12.0 : 14.0;
    // Option A: compact "More by" card omits description and rating to fit 160×220
    final showDescription = !_isCompact && widget.plan.description.isNotEmpty;
    final showRating = !_isCompact;
    return Container(
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.plan.activityCategory != null || widget.plan.accommodationType != null) ...[
            _buildBadgeRow(context, isDark),
            SizedBox(height: _isCompact ? 4 : 8),
          ],
          if (showDescription) ...[
            SizedBox(
              height: descHeight,
              child: Text(
                widget.plan.description,
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF374151),
                  fontSize: descSize,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                maxLines: descLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: _isCompact ? 4 : 6),
          ],
          if (showRating) _buildRatingRow(context, isDark),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(BuildContext context, bool isDark) {
    final activity = widget.plan.activityCategory;
    final accom = widget.plan.accommodationType;
    final hasSeason = _hasSeason(widget.plan);
    final spacing = _isCompact ? 4.0 : 8.0;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        if (activity != null)
          _buildInfoBadge(
            iconData: getActivityIconData(activity),
            label: _getActivityLabel(activity),
            isDark: isDark,
          ),
        if (accom != null)
          _buildInfoBadge(
            iconData: getAccommodationIconData(accom),
            label: _getAccommodationLabel(accom),
            isDark: isDark,
          ),
        if (hasSeason)
          _buildInfoBadge(
            iconData: seasonChipIcon,
            label: _formatSeasons(widget.plan),
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildInfoBadge({required IconData iconData, required String label, required bool isDark}) {
    final tagColor = ActivityTagColors.getActivityColor(label);
    final tagBgColor = isDark
        ? tagColor.withValues(alpha: 0.3)
        : ActivityTagColors.getActivityBgColor(label);
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : tagColor;
    final padH = _isCompact ? 8.0 : 12.0;
    final padV = _isCompact ? 4.0 : 6.0;
    final iconSize = _isCompact ? 12.0 : 14.0;
    final fontSize = _isCompact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: tagBgColor,
        borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: iconSize, color: textColor),
          SizedBox(width: _isCompact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(BuildContext context, bool isDark) {
    final rating = 4.5;
    final reviewCount = widget.plan.salesCount > 0 ? widget.plan.salesCount : 12;
    final fontSize = _isCompact ? 12.0 : 16.0;
    final countSize = _isCompact ? 11.0 : 13.0;

    return Row(
      children: [
        _buildStarRating(rating),
        SizedBox(width: _isCompact ? 4 : 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount)',
          style: TextStyle(
            fontSize: countSize,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;
    final starSize = _isCompact ? 12.0 : 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, size: starSize, color: const Color(0xFFFCD34D));
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, size: starSize, color: const Color(0xFFFCD34D));
        } else {
          return Icon(Icons.star_border, size: starSize, color: const Color(0xFFE5E7EB));
        }
      }),
    );
  }
}

/// Section header component for swimming lanes
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'See All',
              style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      ],
    );
  }
}

/// Empty state component for consistent empty views
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.explore, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton card for loading states with shimmer animation
/// Matches the new cabin-style 4:5 portrait card structure
class SkeletonAdventureCard extends StatefulWidget {
  const SkeletonAdventureCard({super.key});

  @override
  State<SkeletonAdventureCard> createState() => _SkeletonAdventureCardState();
}

class _SkeletonAdventureCardState extends State<SkeletonAdventureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
              blurRadius: isDark ? 16 : 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Expanded(
                flex: 60,
                child: Container(
                  color: context.colors.surfaceContainerHighest.withValues(alpha: _animation.value),
                ),
              ),
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer.withValues(alpha: _animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer.withValues(alpha: _animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 150,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer.withValues(alpha: _animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 18,
                        width: 120,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer.withValues(alpha: _animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
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
