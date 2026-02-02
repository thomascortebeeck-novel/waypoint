import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Activity Categories Carousel
class ActivityCategoriesCarousel extends StatelessWidget {
  const ActivityCategoriesCarousel({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final circleSize = isDesktop ? 240.0 : 80.0;
    final containerWidth = isDesktop ? 280.0 : 90.0;
    final carouselHeight = isDesktop ? 320.0 : 120.0;
    
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
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
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: carouselHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _isHovered ? 0.2 : 0.1),
                        blurRadius: _isHovered ? 16 : 12,
                        offset: Offset(0, _isHovered ? 6 : 4),
                      ),
                    ],
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
              Text(
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
            ],
          ),
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

  Widget _buildUpgradePromo(BuildContext context, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.primaryLight, BrandColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (isDesktop)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final parentWidth = MediaQuery.of(context).size.width - 32;
                    final imageWidth = parentWidth * 0.7;
                    return SizedBox(
                      width: imageWidth,
                      child: CachedNetworkImage(
                        imageUrl: 'https://images.unsplash.com/photo-1464207687429-7505649dae38?w=800',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: EdgeInsets.all(isDesktop ? 48 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨',
                    style: TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upgrade Your\nAdventure',
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: isDesktop ? 400 : double.infinity,
                    child: Text(
                      'Premium routes, offline maps, and exclusive features await',
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
                      foregroundColor: BrandColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Learn More',
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

  Widget _buildGiftPromo(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: removeMargin ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.onSurface.withValues(alpha: 0.1),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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

/// Testimonials Section
class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final testimonials = [
      TestimonialData(
        quote: "Waypoint made planning our Iceland trek so easy! The offline maps were a lifesaver when we lost signal. Highly recommend!",
        name: "Sarah Johnson",
        location: "Portland, OR",
        rating: 5.0,
        avatarUrl: "https://i.pravatar.cc/150?img=1",
      ),
      TestimonialData(
        quote: "As a solo traveler, Waypoint gave me the confidence to explore safely. The detailed maps and community notes were invaluable.",
        name: "Marco Rossi",
        location: "Milan, Italy",
        rating: 5.0,
        avatarUrl: "https://i.pravatar.cc/150?img=12",
      ),
      TestimonialData(
        quote: "Downloaded everything offline for our Patagonia trip. No connectivity issues, just pure adventure!",
        name: "Emma & Jake",
        location: "Sydney, Australia",
        rating: 5.0,
        avatarUrl: "https://i.pravatar.cc/150?img=5",
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 64 : 48,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          Text(
            'What Adventurers Say',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Real experiences from our community',
            style: context.textStyles.bodyLarge?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isDesktop)
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: testimonials
                  .map((t) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 80) / 3,
                        child: TestimonialCard(testimonial: t),
                      ))
                  .toList(),
            )
          else
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: testimonials.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: TestimonialCard(testimonial: testimonials[index]),
                ),
              ),
            ),
        ],
      ),
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
          color: context.colors.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating stars
          Row(
            children: List.generate(
              5,
              (index) => const Icon(
                Icons.star,
                size: 16,
                color: Color(0xFFFCD34D),
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
