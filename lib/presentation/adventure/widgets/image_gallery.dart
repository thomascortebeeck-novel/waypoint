import 'package:flutter/material.dart';

/// Image gallery widget for adventure detail screens
/// Supports desktop grid layout and mobile carousel
class AdventureImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final bool isDesktop;
  final VoidCallback? onAddImage;

  const AdventureImageGallery({
    super.key,
    required this.imageUrls,
    required this.isDesktop,
    this.onAddImage,
  });

  @override
  State<AdventureImageGallery> createState() => _AdventureImageGalleryState();
}

class _AdventureImageGalleryState extends State<AdventureImageGallery> {
  late PageController _carouselController;
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _buildPlaceholderGallery(context, widget.isDesktop);
    }

    return widget.isDesktop
        ? _buildDesktopGallery(context, widget.imageUrls)
        : _buildMobileCarousel(context, widget.imageUrls);
  }

  // ---- Desktop: AllTrails 2/3 + 1/3 grid ----
  Widget _buildDesktopGallery(BuildContext context, List<String> images) {
    final primary = images[0];
    final secondary = images.length > 1 ? images[1] : null;
    final tertiary = images.length > 2 ? images[2] : null;

    return SizedBox(
      height: 420,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary image — 2/3 width
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _openGallery(context, images, 0),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Image.network(
                  primary,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Right column — 1/3 width, two stacked images
          if (secondary != null || tertiary != null)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  // Top-right image
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openGallery(context, images, 1),
                      child: ClipRRect(
                        borderRadius: tertiary == null
                            ? const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              )
                            : const BorderRadius.only(
                                topRight: Radius.circular(12),
                              ),
                        child: secondary != null
                            ? Image.network(
                                secondary,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                      ),
                    ),
                  ),

                  if (tertiary != null) ...[
                    const SizedBox(height: 4),

                    // Bottom-right image — with "N photos" overlay
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openGallery(context, images, 2),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(12),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                tertiary,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                              ),
                              // "See all photos" overlay if more than 3
                              if (images.length > 3)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.photo_library_outlined,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${images.length} photos',
                                          style: const TextStyle(
                                            fontFamily: 'DMSans',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- Mobile: swipeable PageView carousel ----
  Widget _buildMobileCarousel(BuildContext context, List<String> images) {
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            controller: _carouselController,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemCount: images.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _openGallery(context, images, index),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _imagePlaceholder(),
              ),
            ),
          ),

          // Dot indicators
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _carouselIndex ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _carouselIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),

          // Image counter chip (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_carouselIndex + 1} / ${images.length}',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Placeholder when no images ----
  Widget _buildPlaceholderGallery(BuildContext context, bool isDesktop) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isDesktop ? 12 : 0),
      child: AspectRatio(
        aspectRatio: isDesktop ? 21 / 9 : 16 / 9,
        child: Container(
          color: const Color(0xFFE9ECEF),
          child: const Center(
            child: Icon(Icons.landscape_outlined, size: 64, color: Color(0xFFADB5BD)),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: const Color(0xFFE9ECEF),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFADB5BD)),
        ),
      );

  // ---- Full-screen gallery viewer ----
  void _openGallery(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullscreenGallery(images: images, initialIndex: initialIndex),
    );
  }
}

/// Full-screen gallery viewer dialog
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullscreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.images.length,
          itemBuilder: (_, i) => InteractiveViewer(
            child: Image.network(
              widget.images[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
            ),
          ),
        ),

        // Close button
        Positioned(
          top: 48,
          right: 16,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Counter
        Positioned(
          top: 56,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '${_current + 1} / ${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Prev/Next arrows (desktop)
        if (MediaQuery.of(context).size.width >= 1024) ...[
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: _navArrow(Icons.chevron_left, () {
                if (_current > 0) {
                  _ctrl.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                }
              }),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: _navArrow(Icons.chevron_right, () {
                if (_current < widget.images.length - 1) {
                  _ctrl.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                }
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}

