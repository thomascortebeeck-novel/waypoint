import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';

class PlanCard extends StatefulWidget {
  final Plan plan;
  final VoidCallback? onTap;

  const PlanCard({super.key, required this.plan, this.onTap});

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () {
        context.push('/details/${widget.plan.id}');
      },
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.plan.heroImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.colors.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: context.colors.surface,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              
              // Gradient Overlay - More sophisticated
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.locationDot,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.plan.location.toUpperCase(),
                              style: context.textStyles.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Title
                      Text(
                        widget.plan.name,
                        style: context.textStyles.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Footer Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Difficulty Chip - Modern glassmorphism (only show if not empty)
                          if (widget.plan.difficultyRange.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                widget.plan.difficultyRange,
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          
                          // Price - More prominent
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.colors.secondary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.secondary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.plan.minPrice == 0 ? "FREE" : "€${widget.plan.minPrice.toStringAsFixed(0)}",
                              style: context.textStyles.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Featured Badge - More professional
              if (widget.plan.isFeatured)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(20),
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
                        Icon(
                          Icons.star,
                          size: 14,
                          color: context.colors.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "FEATURED",
                          style: context.textStyles.labelSmall?.copyWith(
                            color: context.colors.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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
      ),
    );
  }
}
