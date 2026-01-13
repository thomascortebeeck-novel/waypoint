import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// A shimmer skeleton loader for placeholder content.
class WaypointSkeleton extends StatefulWidget {
  const WaypointSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  /// Rectangle skeleton
  factory WaypointSkeleton.rectangle({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) => WaypointSkeleton(
    width: width,
    height: height,
    borderRadius: borderRadius ?? WaypointRadius.borderSm,
  );

  /// Circle skeleton (avatar)
  factory WaypointSkeleton.circle({required double size}) => WaypointSkeleton(
    width: size,
    height: size,
    isCircle: true,
  );

  /// Text line skeleton
  factory WaypointSkeleton.text({double? width}) => WaypointSkeleton(
    width: width,
    height: 14,
    borderRadius: WaypointRadius.borderXs,
  );

  @override
  State<WaypointSkeleton> createState() => _WaypointSkeletonState();
}

class _WaypointSkeletonState extends State<WaypointSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
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
    final baseColor = isDark ? NeutralColors.neutral700 : NeutralColors.neutral200;
    final highlightColor = isDark ? NeutralColors.neutral600 : NeutralColors.neutral100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Card skeleton for adventure cards
class WaypointCardSkeleton extends StatelessWidget {
  const WaypointCardSkeleton({
    super.key,
    this.aspectRatio = 16 / 10,
  });

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: WaypointRadius.borderLg,
          color: Theme.of(context).brightness == Brightness.dark
              ? NeutralColors.neutral700
              : NeutralColors.neutral200,
        ),
        child: Stack(
          children: [
            // Background shimmer
            Positioned.fill(
              child: ClipRRect(
                borderRadius: WaypointRadius.borderLg,
                child: WaypointSkeleton(
                  borderRadius: WaypointRadius.borderLg,
                ),
              ),
            ),
            // Content placeholders
            Positioned(
              left: WaypointSpacing.md,
              right: WaypointSpacing.md,
              bottom: WaypointSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  WaypointSkeleton.text(width: 80),
                  const SizedBox(height: WaypointSpacing.sm),
                  WaypointSkeleton.text(width: 160),
                  const SizedBox(height: WaypointSpacing.sm),
                  Row(
                    children: [
                      WaypointSkeleton.rectangle(width: 60, height: 20),
                      const Spacer(),
                      WaypointSkeleton.rectangle(width: 50, height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List item skeleton
class WaypointListItemSkeleton extends StatelessWidget {
  const WaypointListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: WaypointSpacing.paddingMd,
      child: Row(
        children: [
          WaypointSkeleton.circle(size: 48),
          const SizedBox(width: WaypointSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WaypointSkeleton.text(width: 120),
                const SizedBox(height: WaypointSpacing.sm),
                WaypointSkeleton.text(width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
