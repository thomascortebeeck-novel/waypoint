import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';

/// Day hero image component
/// 
/// Displays day hero image with gradient overlay showing "Day X of N" and day title.
/// 300px desktop / 220px mobile, full-bleed on mobile.
/// Location badge bottom-left, status badge top-left (builder only).
/// Hover shows camera icon for image change (builder only).

class DayHeroImage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String dayTitle;
  final int dayNumber;
  final int totalDays;
  final String? location;
  final String? statusBadge; // "Draft" or "Published" (builder only)
  final bool isBuilder;
  final VoidCallback? onImageTap; // For builder mode image picker
  
  const DayHeroImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
    required this.dayTitle,
    required this.dayNumber,
    required this.totalDays,
    this.location,
    this.statusBadge,
    this.isBuilder = false,
    this.onImageTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    final isTablet = WaypointBreakpoints.isTablet(screenWidth);
    
    // Responsive heights: mobile 220px, tablet 260px, desktop 300px
    final height = isMobile ? 220.0 : (isTablet ? 260.0 : 300.0);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty || imageBytes != null;
    
    return Container(
      height: height,
      width: double.infinity,
      margin: EdgeInsets.only(
        left: isMobile ? -WaypointSpacing.pagePaddingMobile : 0,
        right: isMobile ? -WaypointSpacing.pagePaddingMobile : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: isMobile 
            ? BorderRadius.zero 
            : BorderRadius.circular(WaypointSpacing.cardRadiusLg),
        image: hasImage
            ? DecorationImage(
                image: imageBytes != null
                    ? MemoryImage(imageBytes!)
                    : NetworkImage(imageUrl!) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
        color: hasImage ? null : WaypointColors.borderLight,
      ),
      child: Stack(
        children: [
          // Hover overlay with camera icon (builder only)
          if (isBuilder && onImageTap != null)
            Positioned.fill(
              child: _DayHeroImageHoverOverlay(
                onTap: onImageTap!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Hover overlay for day hero image (builder mode)
class _DayHeroImageHoverOverlay extends StatefulWidget {
  final VoidCallback onTap;
  
  const _DayHeroImageHoverOverlay({required this.onTap});
  
  @override
  State<_DayHeroImageHoverOverlay> createState() => _DayHeroImageHoverOverlayState();
}

class _DayHeroImageHoverOverlayState extends State<_DayHeroImageHoverOverlay> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _isHovering ? Colors.black.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(WaypointSpacing.cardRadiusLg),
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: _isHovering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

