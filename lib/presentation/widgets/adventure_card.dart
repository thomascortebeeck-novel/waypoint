import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/components/badges/waypoint_badge.dart';


enum AdventureCardVariant {
  standard,
  fullWidth,
  builder,
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

  const AdventureCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onDelete,
    this.variant = AdventureCardVariant.standard,
    this.showFavoriteButton = false,
    this.statusLabel,
    this.theme,
  });

  @override
  State<AdventureCard> createState() => _AdventureCardState();
}

class _AdventureCardState extends State<AdventureCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imageScaleAnimation;
  bool _isHovered = false;

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
        onTap: widget.onTap,
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
              borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(24),
              child: Column(
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _imageScaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _isHovered ? _imageScaleAnimation.value : 1.0,
            child: child,
          ),
          child: CachedNetworkImage(
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
            errorWidget: (context, url, error) => Container(
              color: context.colors.surfaceContainerHighest,
              child: Icon(Icons.terrain, size: 48, color: context.colors.onSurface.withValues(alpha: 0.3)),
            ),
          ),
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
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.plan.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (widget.plan.location.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.locationDot,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.plan.location,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
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
          ),
        ),
      ],
    );
  }

  // Mapping helpers kept intact
  String _getActivityIcon(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return '🥾';
      case ActivityCategory.cycling:
        return '🚴';
      case ActivityCategory.roadTripping:
        return '🚗';
      case ActivityCategory.skis:
        return '⛷️';
      case ActivityCategory.climbing:
        return '🧗';
      case ActivityCategory.cityTrips:
        return '🏙️';
      case ActivityCategory.tours:
        return '🌏';
    }
  }
  
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
  
  String _getAccommodationIcon(AccommodationType type) {
    return type == AccommodationType.comfort ? '💰' : '⛺';
  }
  
  String _getAccommodationLabel(AccommodationType type) {
    return type == AccommodationType.comfort ? 'Comfort' : 'Adventure';
  }

  Widget _buildPriceBadge(BuildContext context) {
    final isFree = widget.plan.minPrice == 0;
    
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
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
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

  Widget _buildBottomSection(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge Row (NEW position)
          if (widget.plan.activityCategory != null || widget.plan.accommodationType != null) ...[
            _buildBadgeRow(context, isDark),
            const SizedBox(height: 10),
          ],
          if (widget.plan.description.isNotEmpty) ...[
            Flexible(
              child: Text(
                widget.plan.description,
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
          ],
          _buildRatingRow(context, isDark),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(BuildContext context, bool isDark) {
    final activity = widget.plan.activityCategory;
    final accom = widget.plan.accommodationType;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (activity != null)
          _buildInfoBadge(
            icon: _getActivityIcon(activity),
            label: _getActivityLabel(activity),
            isDark: isDark,
          ),
        if (accom != null)
          _buildInfoBadge(
            icon: _getAccommodationIcon(accom),
            label: _getAccommodationLabel(accom),
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildInfoBadge({required String icon, required String label, required bool isDark}) {
    final tagColor = ActivityTagColors.getActivityColor(label);
    final tagBgColor = ActivityTagColors.getActivityBgColor(label);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tagBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14, height: 1)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tagColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(BuildContext context, bool isDark) {
    // Using fake data for now since Plan model doesn't have rating fields yet
    final rating = 4.5;
    final reviewCount = widget.plan.salesCount > 0 ? widget.plan.salesCount : 12;
    
    return Row(
      children: [
        _buildStarRating(rating),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount)',
          style: TextStyle(
            fontSize: 13,
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
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(
            Icons.star,
            size: 14,
            color: Color(0xFFFCD34D),
          );
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(
            Icons.star_half,
            size: 14,
            color: Color(0xFFFCD34D),
          );
        } else {
          return const Icon(
            Icons.star_border,
            size: 14,
            color: Color(0xFFE5E7EB),
          );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
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
      ),
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
