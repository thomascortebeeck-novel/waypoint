import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waypoint/theme.dart';

/// Animated like/favorite button with optimistic updates
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onTap;
  final bool showCount;
  final double size;
  final Color? backgroundColor;

  const LikeButton({
    super.key,
    required this.isLiked,
    this.likeCount = 0,
    this.onTap,
    this.showCount = false,
    this.size = 20,
    this.backgroundColor,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (_isAnimating) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() => _isAnimating = true);
    _animationController.forward(from: 0.0);
    
    // Call the onTap callback
    widget.onTap?.call();
    
    await _animationController.forward();
    if (mounted) {
      setState(() => _isAnimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Colors.black.withValues(alpha: 0.5);
    
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.all(widget.size * 0.4),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Main heart icon
                  Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: widget.isLiked ? const Color(0xFFFF4B6E) : Colors.white,
                    size: widget.size,
                  ),
                  // Burst effect when liked
                  if (widget.isLiked && _isAnimating)
                    ...List.generate(6, (index) {
                      final angle = (index * 60) * 3.14159 / 180;
                      return Transform.translate(
                        offset: Offset(
                          _bounceAnimation.value * 12 * (index.isEven ? 1 : -1) * (angle.abs() > 1.5 ? -1 : 1),
                          _bounceAnimation.value * 12 * (index < 3 ? -1 : 1),
                        ),
                        child: Opacity(
                          opacity: 1 - _bounceAnimation.value,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4B6E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Like button with count badge for display in lists
class LikeButtonWithCount extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onTap;

  const LikeButtonWithCount({
    super.key,
    required this.isLiked,
    required this.likeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LikeButton(
          isLiked: isLiked,
          likeCount: likeCount,
          onTap: onTap,
          size: 24,
        ),
        if (likeCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(likeCount),
            style: context.textStyles.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
