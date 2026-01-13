import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// Loading indicator type
enum WaypointLoadingType {
  /// Circular spinner
  spinner,
  /// Large circular spinner
  spinnerLarge,
  /// Linear progress bar
  progress,
  /// Dot animation
  dots,
}

/// A styled loading indicator following the Waypoint design system.
class WaypointLoading extends StatelessWidget {
  const WaypointLoading({
    super.key,
    this.type = WaypointLoadingType.spinner,
    this.color,
    this.size,
    this.progress,
  });

  final WaypointLoadingType type;
  final Color? color;
  final double? size;
  final double? progress; // 0.0 to 1.0 for progress type

  /// Centered spinner for page loading
  factory WaypointLoading.page() => const WaypointLoading(
    type: WaypointLoadingType.spinnerLarge,
  );

  /// Small inline spinner
  factory WaypointLoading.inline({Color? color}) => WaypointLoading(
    type: WaypointLoadingType.spinner,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    switch (type) {
      case WaypointLoadingType.spinner:
        return SizedBox(
          width: size ?? 24,
          height: size ?? 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(effectiveColor),
          ),
        );
      case WaypointLoadingType.spinnerLarge:
        return SizedBox(
          width: size ?? 48,
          height: size ?? 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(effectiveColor),
          ),
        );
      case WaypointLoadingType.progress:
        return ClipRRect(
          borderRadius: WaypointRadius.borderXs,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.outline,
            valueColor: AlwaysStoppedAnimation(effectiveColor),
            minHeight: size ?? 4,
          ),
        );
      case WaypointLoadingType.dots:
        return _DotsLoading(color: effectiveColor, size: size ?? 8);
    }
  }
}

/// Animated dots loading indicator
class _DotsLoading extends StatefulWidget {
  const _DotsLoading({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  State<_DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<_DotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay) % 1.0;
            final scale = progress < 0.5 
                ? 1.0 + (progress * 0.4) 
                : 1.0 + ((1.0 - progress) * 0.4);
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.6 + (scale - 1.0)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Full page loading overlay
class WaypointLoadingOverlay extends StatelessWidget {
  const WaypointLoadingOverlay({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: colorScheme.surface.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WaypointLoading(type: WaypointLoadingType.spinnerLarge),
            if (message != null) ...[
              const SizedBox(height: WaypointSpacing.md),
              Text(
                message!,
                style: WaypointTypography.body.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
