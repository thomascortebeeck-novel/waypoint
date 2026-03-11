import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_badge.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_geometry.dart';
import 'package:waypoint/core/constants/breakpoints.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/app_review_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/app_review_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/theme/waypoint_colors.dart';

/// Activity Categories Carousel
class ActivityCategoriesCarousel extends StatelessWidget {
  const ActivityCategoriesCarousel({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final circleSize = isDesktop ? 260.0 : 100.0;
    final containerWidth = isDesktop ? 300.0 : 115.0;
    final carouselHeight = isDesktop ? 360.0 : 155.0;
    
    final activities = [
      ActivityItem(ActivityCategory.hiking, 'Hiking', 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=200'),
      ActivityItem(ActivityCategory.cycling, 'Cycling', 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=200'),
      ActivityItem(ActivityCategory.skis, 'Skiing', 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=200'),
      ActivityItem(ActivityCategory.climbing, 'Climbing', 'https://images.unsplash.com/photo-1522163182402-834f871fd851?w=200'),
      ActivityItem(ActivityCategory.cityTrips, 'City Trips', 'https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=200'),
      ActivityItem(ActivityCategory.tours, 'Tours', 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore by Activity',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Popular activities from our community',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: carouselHeight,
          child: ListView.separated(
            padding: EdgeInsets.zero, // Padding handled by parent _CenteredSection
            scrollDirection: Axis.horizontal,
            itemCount: activities.length,
            separatorBuilder: (_, __) => SizedBox(width: isDesktop ? 20 : 16),
            itemBuilder: (context, index) => ActivityCircle(
              activity: activities[index],
              circleSize: circleSize,
              containerWidth: containerWidth,
              onTap: () {
                // TODO: Filter by activity category
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ActivityItem {
  final ActivityCategory category;
  final String label;
  final String imageUrl;

  ActivityItem(this.category, this.label, this.imageUrl);
}

class ActivityCircle extends StatefulWidget {
  const ActivityCircle({
    super.key,
    required this.activity,
    required this.onTap,
    this.circleSize = 80.0,
    this.containerWidth = 90.0,
  });

  final ActivityItem activity;
  final VoidCallback onTap;
  final double circleSize;
  final double containerWidth;

  @override
  State<ActivityCircle> createState() => _ActivityCircleState();
}

class _ActivityCircleState extends State<ActivityCircle> {
  bool _isHovered = false;

  static IconData _iconForCategory(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return Icons.hiking;
      case ActivityCategory.cycling:
        return Icons.directions_bike;
      case ActivityCategory.skis:
        return Icons.downhill_skiing;
      case ActivityCategory.climbing:
        return Icons.terrain;
      case ActivityCategory.cityTrips:
        return Icons.location_city;
      case ActivityCategory.tours:
        return Icons.tour;
      case ActivityCategory.roadTripping:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.containerWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.circleSize,
                  height: widget.circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: const [],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.activity.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: context.colors.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: context.colors.primaryContainer,
                        child: Icon(
                          Icons.terrain,
                          color: context.colors.primary,
                          size: widget.circleSize * 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.circleSize > 90 ? 10 : 8),
              // Icon and label in one row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForCategory(widget.activity.category),
                    size: widget.circleSize > 90 ? 22 : 18,
                    color: context.colors.primary,
                  ),
                  SizedBox(width: widget.circleSize > 90 ? 8 : 6),
                  Flexible(
                    child: Text(
                      widget.activity.label,
                      style: (widget.circleSize > 90
                          ? context.textStyles.labelLarge
                          : context.textStyles.labelMedium)?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded rect activity card for Explore by Activity: cream background, image, icon, label.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.cardWidth = 100.0,
    this.cardHeight = 140.0,
  });

  final ActivityItem activity;
  final VoidCallback onTap;
  final double cardWidth;
  final double cardHeight;

  static IconData _iconForCategory(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return Icons.hiking;
      case ActivityCategory.cycling:
        return Icons.directions_bike;
      case ActivityCategory.skis:
        return Icons.downhill_skiing;
      case ActivityCategory.climbing:
        return Icons.terrain;
      case ActivityCategory.cityTrips:
        return Icons.location_city;
      case ActivityCategory.tours:
        return Icons.tour;
      case ActivityCategory.roadTripping:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.outline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  width: cardWidth,
                  child: CachedNetworkImage(
                    imageUrl: activity.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: context.colors.surfaceContainerHighest),
                    errorWidget: (context, url, error) => Container(
                      color: context.colors.surfaceContainerHighest,
                      child: Icon(Icons.terrain, color: context.colors.onSurface.withValues(alpha: 0.6), size: 28),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForCategory(activity.category),
                    size: 18,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      activity.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// Promotional Card variants
enum PromoVariant { upgrade, gift, community }

class PromoCard extends StatelessWidget {
  const PromoCard({super.key, required this.variant, this.removeMargin = false});

  final PromoVariant variant;
  final bool removeMargin;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    switch (variant) {
      case PromoVariant.upgrade:
        return _buildUpgradePromo(context, isDesktop);
      case PromoVariant.gift:
        return _buildGiftPromo(context, isDesktop);
      case PromoVariant.community:
        return _buildCommunityPromo(context, isDesktop);
    }
  }

  static const String _kUpgradePromoImageUrl =
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800';

  /// AllTrails-style "Upgrade your adventures": image above text on mobile, image beside text on desktop.
  Widget _buildUpgradePromo(BuildContext context, bool isDesktop) {
    const radius = 20.0;
    final content = _buildUpgradePromoContent(context, isDesktop);

    if (isDesktop) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(32),
                  child: content,
                ),
              ),
              SizedBox(
                width: 320,
                child: CachedNetworkImage(
                  imageUrl: _kUpgradePromoImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.colors.surfaceContainerHighest,
                    child: Icon(Icons.image, size: 48, color: context.colors.outline),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: context.colors.surfaceContainerHighest,
                    child: Icon(Icons.terrain, size: 48, color: context.colors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: image above text (AllTrails-style)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: CachedNetworkImage(
              imageUrl: _kUpgradePromoImageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: context.colors.surfaceContainerHighest,
                child: Icon(Icons.image, size: 48, color: context.colors.outline),
              ),
              errorWidget: (context, url, error) => Container(
                color: context.colors.surfaceContainerHighest,
                child: Icon(Icons.terrain, size: 48, color: context.colors.primary),
              ),
            ),
          ),
          Container(
            color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePromoContent(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome,
          size: 24,
          color: context.colors.primary,
        ),
        SizedBox(height: isDesktop ? 16 : 12),
        Text(
          'Upgrade your\nadventures',
          style: context.textStyles.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
            height: 1.2,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : 10),
        Text(
          'Whether you want to explore offline or create your own route, choose the membership that helps you make the most of every minute outdoors.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.8),
            height: 1.45,
          ),
        ),
        SizedBox(height: isDesktop ? 24 : 20),
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary.withValues(alpha: 0.2),
            foregroundColor: context.colors.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Compare plans',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGiftPromo(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: removeMargin ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.outline,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎁',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'The Natural Gift',
              style: TextStyle(
                fontSize: isDesktop ? 32 : 28,
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Give the gift of adventure with Waypoint gift cards',
              style: TextStyle(
                fontSize: 15,
                color: context.colors.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Shop Gift Cards',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPromo(BuildContext context, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=1200',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: context.colors.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => Container(
                color: context.colors.surfaceContainerHighest,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isDesktop ? 48 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '👥',
                    style: TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Join 500,000+\nAdventurers',
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: isDesktop ? 450 : double.infinity,
                    child: Text(
                      'Share your routes, get inspiration, connect with fellow explorers',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Free Account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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

/// 3-step USP section: numbered icons, dotted connectors, staggered animation
class UspStepsSection extends StatefulWidget {
  const UspStepsSection({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  State<UspStepsSection> createState() => _UspStepsSectionState();
}

class _UspStepsSectionState extends State<UspStepsSection>
    with TickerProviderStateMixin {
  static const _steps = [
    (
      title: 'Buy a plan from your favorite travel expert',
      body: 'Browse tours created by real travel creators and filter by location, activity, or budget. Find the right expert for your next adventure.',
    ),
    (
      title: 'Prepare together and personalise your trip',
      body: 'Invite your crew and let everyone prep their own checklist. Book activities, restaurants and stays to your own taste.',
    ),
    (
      title: 'Your guide in your pocket',
      body: 'Follow your daily itinerary and navigate with local tips. Everything you need, right in one app. No guide needed.',
    ),
  ];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _opacities;
  late final List<Animation<Offset>> _offsets;

  @override
  void initState() {
    super.initState();
    const duration = Duration(milliseconds: 500);
    const stagger = Duration(milliseconds: 150);
    _controllers = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: duration),
    );
    _opacities = List.generate(
      3,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controllers[i],
          curve: Curves.easeOut,
        ),
      ),
    );
    _offsets = List.generate(
      3,
      (i) => Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controllers[i],
        curve: Curves.easeOutCubic,
      )),
    );
    for (int i = 0; i < 3; i++) {
      Future.delayed(stagger * i, () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) return _buildDesktopWithPath(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: WaypointBreakpoints.contentMaxWidth),
          child: _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildDesktopWithPath(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sw = MediaQuery.sizeOf(context).width;
      final maxW = WaypointBreakpoints.contentMaxWidth.toDouble();

      final availW = constraints.maxWidth;
      final contentW = availW.clamp(0.0, maxW);

      final leftBleed = (sw - contentW) / 2.0; // use SCREEN width, not LayoutBuilder width

      const hPad = 24.0;
      const painterAbove = 55.0;
      const painterH = 240.0;

      // Pin badge circle center is at roughly half the badge width horizontally
      final badgeCenterX = WaypointPinGeometry.badgeWidth / 2;
      // Pin circle is ~28% down from badge top (teardrop shape)
      final badgeCenterY = WaypointPinGeometry.badgeHeight * 0.28;

      final innerW = contentW - hPad * 2;
      final colW = innerW / 3.0;

      final p1x = leftBleed + hPad + badgeCenterX;
      final p2x = leftBleed + hPad + colW + badgeCenterX;
      final p3x = leftBleed + hPad + colW * 2 + badgeCenterX;
      final pinY = painterAbove + badgeCenterY;  // threads through the numbered circle

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -leftBleed,
              width: sw + leftBleed,   // left edge at screen-left, right edge at screen-right
              top: -painterAbove,
              height: painterH,
              child: CustomPaint(
                painter: _TrailPathPainter(
                  color: const Color(0xFFFCBF49),
                  p1x: p1x,
                  p2x: p2x,
                  p3x: p3x,
                  pinY: pinY,
                  totalWidth: sw,
                  totalHeight: painterH,
                ),
              ),
            ),
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxW),
                padding: const EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _steps.length; i++)
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _controllers[i],
                          builder: (context, child) => Opacity(
                            opacity: _opacities[i].value,
                            child: Transform.translate(
                              offset: _offsets[i].value * 24,
                              child: child,
                            ),
                          ),
                          child: _UspStepCard(
                            stepNumber: i + 1,
                            title: _steps[i].title,
                            body: _steps[i].body,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMobileLayout(BuildContext context) {
    const pinColWidth = 48.0;
    const connectorH = 52.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, child) => Opacity(
              opacity: _opacities[i].value,
              child: Transform.translate(
                offset: _offsets[i].value * 24,
                child: child,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: pinColWidth,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: WaypointPinBadge(
                      orderIndex: i + 1,
                      color: context.colors.primary,
                      width: WaypointPinGeometry.badgeWidth,
                      height: WaypointPinGeometry.badgeHeight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i].title,
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _steps[i].body,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            SizedBox(
              height: connectorH,
              child: Row(
                children: [
                  SizedBox(
                    width: pinColWidth,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(6, connectorH),
                        painter: const _VerticalDotLinePainter(
                          color: Color(0xFFFCBF49),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Full-screen-width trail path:
/// Trail path that passes exactly through each waypoint pin.
/// Pin 1→2: dramatic deep swoop into text area.
/// Pin 2→3: energetic multi-wave path.
/// Extends edge-to-edge across full screen width.
class _TrailPathPainter extends CustomPainter {
  const _TrailPathPainter({
    required this.color,
    required this.p1x,
    required this.p2x,
    required this.p3x,
    required this.pinY,
    required this.totalWidth,
    required this.totalHeight,
  });

  final Color color;
  final double p1x, p2x, p3x, pinY, totalWidth, totalHeight;

  static const double _dotRadius = 2.8;
  static const double _dotStep = 10.5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final py = pinY;
    final path = Path();

    // ── Enter from LEFT edge of screen, angled toward pin 1 ─────────────
    path.moveTo(-10, py + 2); // start off-screen left

    // Curve directly INTO pin 1 — no weird pre-loop
    path.cubicTo(
      p1x * 0.40, py + 20,   // drop then rise
      p1x * 0.75, py - 10,
      p1x,        py,         // ● land exactly on Pin 1
    );

    // ── Pin 1 → Pin 2: same energetic 3-wave style as Pin 2→3 ───────────────
    final seg1W = p2x - p1x;
    // Wave 1: dip down then bounce up
    path.cubicTo(
      p1x + seg1W * 0.10, py + 50,
      p1x + seg1W * 0.22, py + 54,
      p1x + seg1W * 0.32, py + 8,
    );
    // Wave 2: spike up then back down
    path.cubicTo(
      p1x + seg1W * 0.40, py - 45,
      p1x + seg1W * 0.52, py - 48,
      p1x + seg1W * 0.61, py + 6,
    );
    // Wave 3: gentle dip then rise to pin 2
    path.cubicTo(
      p1x + seg1W * 0.70, py + 30,
      p1x + seg1W * 0.85, py + 18,
      p2x,                py,         // ● land exactly on Pin 2
    );

    // ── Pin 2 → Pin 3: energetic 3-wave path ────────────────────────────
    final seg2W = p3x - p2x;
    // Wave 1: sharp spike up
    path.cubicTo(
      p2x + seg2W * 0.10, py - 48,
      p2x + seg2W * 0.22, py - 44,
      p2x + seg2W * 0.32, py + 8,
    );
    // Wave 2: dip below then bounce
    path.cubicTo(
      p2x + seg2W * 0.40, py + 52,
      p2x + seg2W * 0.52, py + 56,
      p2x + seg2W * 0.61, py + 10,
    );
    // Wave 3: rise to pin 3
    path.cubicTo(
      p2x + seg2W * 0.70, py - 28,
      p2x + seg2W * 0.85, py - 22,
      p3x,                py,         // ● land exactly on Pin 3
    );

    // ── Exit to RIGHT edge of screen ─────────────────────────────────────
    final tailW = w - p3x;
    path.cubicTo(
      p3x + tailW * 0.20, py + 22,
      p3x + tailW * 0.55, py - 16,
      p3x + tailW * 0.78, py + 8,
    );
    path.cubicTo(
      p3x + tailW * 0.88, py + 18,
      w + 5,              py - 2,
      w + 20,             py + 4,   // off RIGHT edge of screen
    );

    _dotPath(canvas, path, paint);
  }

  void _dotPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double d = 0;
      while (d <= metric.length) {
        final t = metric.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, _dotRadius, paint);
        d += _dotStep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPathPainter old) =>
      old.color != color ||
      old.p1x != p1x ||
      old.p2x != p2x ||
      old.p3x != p3x ||
      old.pinY != pinY;
}

/// Vertical dotted line between steps (mobile stepper).
class _VerticalDotLinePainter extends CustomPainter {
  const _VerticalDotLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const radius = 2.5;
    const step = 8.0;
    double y = radius;
    while (y < size.height - radius) {
      canvas.drawCircle(Offset(size.width / 2, y), radius, paint);
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDotLinePainter old) =>
      old.color != color;
}

class _UspStepCard extends StatelessWidget {
  const _UspStepCard({
    required this.stepNumber,
    required this.title,
    required this.body,
  });

  final int stepNumber;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Same waypoint pin as itinerary page: teardrop with number in white circle
        SizedBox(
          width: WaypointPinGeometry.badgeWidth + 8,
          height: WaypointPinGeometry.badgeHeight + 4,
          child: Center(
            child: WaypointPinBadge(
              orderIndex: stepNumber,
              color: context.colors.primary,
              width: WaypointPinGeometry.badgeWidth,
              height: WaypointPinGeometry.badgeHeight,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Our latest reviews: app reviews (rating 4–5, with description, allowShowOnWebsite).
/// Shows reviewer profile image, name, location and comment.
class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final appReviewService = AppReviewService();
    final userService = UserService();

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 64 : 48,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: WaypointBreakpoints.contentMaxWidth),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24),
          child: Column(
            children: [
              Text(
                'Our latest reviews',
                style: context.textStyles.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Latest reviews for the Waypoint app',
                style: context.textStyles.bodyLarge?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: isDesktop ? 320 : 280,
                child: StreamBuilder<List<AppReview>>(
                  stream: appReviewService.streamLatestReviewsForWebsite(limit: 20),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reviews = snapshot.data ?? [];
                    if (reviews.isEmpty) {
                      return Center(
                        child: Text(
                          'No reviews yet. Be the first to share your experience!',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Scrollbar(
                      thumbVisibility: isDesktop,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) => SizedBox(width: isDesktop ? 24 : 16),
                        itemBuilder: (context, index) => SizedBox(
                          width: isDesktop
                              ? 380
                              : MediaQuery.of(context).size.width * 0.85,
                          child: _AppReviewCard(
                            review: reviews[index],
                            userService: userService,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single app review card with reviewer avatar, name, location and comment.
class _AppReviewCard extends StatelessWidget {
  const _AppReviewCard({required this.review, required this.userService});

  final AppReview review;
  final UserService userService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: userService.getUserById(review.userId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final name = user?.displayName ?? 'Anonymous';
        final location = user?.location ?? '';
        final avatarUrl = user?.photoUrl;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.outline,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    size: 16,
                    color: i < review.rating
                        ? context.colors.primary
                        : context.colors.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  review.comment,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: context.colors.primaryContainer,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: context.textStyles.titleMedium?.copyWith(
                              color: context.colors.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: context.textStyles.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: context.textStyles.labelSmall?.copyWith(
                              color: context.colors.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class TestimonialData {
  final String quote;
  final String name;
  final String location;
  final double rating;
  final String avatarUrl;

  TestimonialData({
    required this.quote,
    required this.name,
    required this.location,
    required this.rating,
    required this.avatarUrl,
  });
}

class TestimonialCard extends StatelessWidget {
  const TestimonialCard({super.key, required this.testimonial});

  final TestimonialData testimonial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.outline,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating stars
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 16,
                color: context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quote
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              testimonial.quote,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.7),
                height: 1.6,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.colors.primaryContainer,
                backgroundImage: CachedNetworkImageProvider(testimonial.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimonial.name,
                      style: context.textStyles.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      testimonial.location,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
