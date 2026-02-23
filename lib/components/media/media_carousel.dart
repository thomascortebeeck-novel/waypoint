import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Media carousel widget for displaying images and videos
/// Supports up to 10 items (images + videos)
/// Videos use video_player for playback
class MediaCarousel extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final bool isEditable; // If true, shows add/remove buttons
  final VoidCallback? onAddMedia; // Called when user wants to add media
  final Function(MediaItem)? onRemoveMedia; // Called when user wants to remove media
  final double? height; // Optional fixed height
  final double? aspectRatio; // Optional aspect ratio (16:9 or 9:16)

  const MediaCarousel({
    super.key,
    required this.mediaItems,
    this.isEditable = false,
    this.onAddMedia,
    this.onRemoveMedia,
    this.height,
    this.aspectRatio,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeVideoControllers();
  }

  @override
  void didUpdateWidget(MediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItems != widget.mediaItems) {
      _disposeVideoControllers();
      _initializeVideoControllers();
    }
  }

  void _initializeVideoControllers() {
    for (int i = 0; i < widget.mediaItems.length; i++) {
      final item = widget.mediaItems[i];
      if (item.type == 'video') {
        _videoControllers[i] = VideoPlayerController.networkUrl(
          Uri.parse(item.url),
        )..initialize().then((_) {
            if (mounted) setState(() {});
          });
      }
    }
  }

  void _disposeVideoControllers() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      if (widget.isEditable) {
        return _buildEmptyState();
      }
      return const SizedBox.shrink();
    }

    final aspectRatio = widget.aspectRatio ?? _calculateAspectRatio();
    final height = widget.height ?? MediaQuery.of(context).size.width / aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: widget.mediaItems.length,
                itemBuilder: (context, index) {
                  final item = widget.mediaItems[index];
                  return _buildMediaItem(item, index, height);
                },
              ),
              // Page indicators
              if (widget.mediaItems.length > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.mediaItems.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              // Remove button (if editable)
              if (widget.isEditable && widget.onRemoveMedia != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () {
                      widget.onRemoveMedia?.call(widget.mediaItems[_currentIndex]);
                    },
                  ),
                ),
            ],
          ),
        ),
        // Add media button (if editable and not at max)
        if (widget.isEditable && widget.mediaItems.length < 10 && widget.onAddMedia != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onAddMedia,
            icon: const Icon(Icons.add),
            label: const Text('Add Media'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaItem(MediaItem item, int index, double height) {
    if (item.type == 'video') {
      return _buildVideoItem(item, index, height);
    } else {
      return _buildImageItem(item, height);
    }
  }

  Widget _buildImageItem(MediaItem item, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      child: CachedNetworkImage(
        imageUrl: item.url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: WaypointColors.borderLight,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: WaypointColors.borderLight,
          child: const Icon(Icons.error, size: 48),
        ),
      ),
    );
  }

  Widget _buildVideoItem(MediaItem item, int index, double height) {
    final controller = _videoControllers[index];
    
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: height,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        // Play/pause overlay
        Center(
          child: IconButton(
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 64,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: WaypointColors.borderLight,
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        border: Border.all(color: WaypointColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_photo_alternate, size: 48, color: WaypointColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              'Add Media',
              style: TextStyle(color: WaypointColors.textTertiary),
            ),
            if (widget.onAddMedia != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onAddMedia,
                child: const Text('Upload Images/Videos'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateAspectRatio() {
    if (widget.mediaItems.isEmpty) return 16 / 9;
    
    // Use the aspect ratio of the first item
    final firstItem = widget.mediaItems[0];
    if (firstItem.aspectRatio == '16:9') {
      return 16 / 9;
    } else if (firstItem.aspectRatio == '9:16') {
      return 9 / 16;
    }
    
    // Default to 16:9
    return 16 / 9;
  }
}

