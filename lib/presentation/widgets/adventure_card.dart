import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';

enum AdventureCardVariant {
  standard,
  fullWidth,
  builder,
}

/// Modern adventure card component with multiple variants
/// Used across Home (carousel), My Trips (grid), and Builder (with actions)
class AdventureCard extends StatefulWidget {
  final Plan plan;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final AdventureCardVariant variant;
  final bool showFavoriteButton;

  const AdventureCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onDelete,
    this.variant = AdventureCardVariant.standard,
    this.showFavoriteButton = false,
  });

  @override
  State<AdventureCard> createState() => _AdventureCardState();
}

class _AdventureCardState extends State<AdventureCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imageScaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _imageScaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
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

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  double get _aspectRatio {
    switch (widget.variant) {
      case AdventureCardVariant.fullWidth:
        return 16 / 9;
      case AdventureCardVariant.builder:
        return 4 / 5;
      case AdventureCardVariant.standard:
      default:
        return 16 / 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed ? 0.98 : (_isHovered ? _scaleAnimation.value : 1.0),
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.08),
                  blurRadius: _isHovered ? 24 : 16,
                  offset: Offset(0, _isHovered ? 8 : 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: _aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(context),
                    _buildGradientOverlay(context),
                    _buildContent(context),
                    if (widget.plan.isFeatured && widget.variant != AdventureCardVariant.builder)
                      _buildFeaturedBadge(context),
                    if (widget.variant == AdventureCardVariant.builder)
                      _buildStatusBadge(context),
                    if (widget.showFavoriteButton && !widget.plan.isFeatured)
                      _buildFavoriteButton(context),
                    if (widget.variant == AdventureCardVariant.builder && widget.onDelete != null)
                      _buildDeleteButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return AnimatedBuilder(
      animation: _imageScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isHovered ? _imageScaleAnimation.value : 1.0,
          child: child,
        );
      },
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
          child: Icon(
            Icons.terrain,
            size: 48,
            color: context.colors.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.35, 0.65, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLocation(context),
            const SizedBox(height: 6),
            _buildTitle(context),
            const SizedBox(height: 10),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLocation(BuildContext context) {
    final location = widget.plan.location.isNotEmpty
        ? widget.plan.location.toUpperCase()
        : 'NO LOCATION SET';

    return Row(
      children: [
        Icon(
          FontAwesomeIcons.locationDot,
          color: Colors.white.withValues(alpha: 0.85),
          size: 11,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            location,
            style: context.textStyles.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      widget.plan.name,
      style: context.textStyles.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _buildDifficultyBadge(context)),
        const SizedBox(width: 8),
        _buildPriceTag(context),
      ],
    );
  }

  Widget _buildDifficultyBadge(BuildContext context) {
    if (widget.plan.difficultyRange.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        widget.plan.difficultyRange,
        style: context.textStyles.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPriceTag(BuildContext context) {
    final isFree = widget.plan.minPrice == 0;
    final bgColor = isFree ? context.colors.primary : context.colors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        isFree ? 'FREE' : '€${widget.plan.minPrice.toStringAsFixed(0)}',
        style: context.textStyles.titleSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildFeaturedBadge(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'FEATURED',
              style: context.textStyles.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isPublished = widget.plan.isPublished;

    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isPublished
              ? context.colors.primary.withValues(alpha: 0.9)
              : Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          isPublished ? 'Published' : 'Draft',
          style: context.textStyles.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          FontAwesomeIcons.heart,
          size: 16,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.delete_outline,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
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
class SkeletonAdventureCard extends StatefulWidget {
  final AdventureCardVariant variant;

  const SkeletonAdventureCard({
    super.key,
    this.variant = AdventureCardVariant.standard,
  });

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

  double get _aspectRatio {
    switch (widget.variant) {
      case AdventureCardVariant.fullWidth:
        return 16 / 9;
      case AdventureCardVariant.builder:
        return 4 / 5;
      case AdventureCardVariant.standard:
      default:
        return 16 / 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: context.colors.surfaceContainerHighest.withValues(alpha: _animation.value),
          ),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 20,
                    width: 140,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 50,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
