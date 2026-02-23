import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';

/// Stat bar component
/// 
/// Displays distance, elevation, duration, and difficulty stats.
/// Desktop: 4 items in a row with 1px dividers
/// Mobile: 2×2 grid (items 1-2 top row with bottom border, items 3-4 bottom row)
/// Editable on tap in builder mode.

class StatBar extends StatelessWidget {
  final double? distance; // in km
  final int? elevation; // in meters
  final String? duration; // formatted string like "6h 30m"
  final String? difficulty; // "easy", "moderate", "hard", "none"
  final bool isEditable;
  final VoidCallback? onDistanceTap;
  final VoidCallback? onElevationTap;
  final VoidCallback? onDurationTap;
  final VoidCallback? onDifficultyTap;
  
  const StatBar({
    super.key,
    this.distance,
    this.elevation,
    this.duration,
    this.difficulty,
    this.isEditable = false,
    this.onDistanceTap,
    this.onElevationTap,
    this.onDurationTap,
    this.onDifficultyTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    final isTablet = WaypointBreakpoints.isTablet(screenWidth);
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 16.0 : 18.0,
        horizontal: isMobile ? WaypointSpacing.pagePaddingMobile : 0,
      ),
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border.all(color: WaypointColors.border, width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Distance', _formatDistance(distance), onDistanceTap)),
        _buildDivider(),
        Expanded(child: _buildStatItem('Elevation', _formatElevation(elevation), onElevationTap)),
        _buildDivider(),
        Expanded(child: _buildStatItem('Duration', duration ?? '—', onDurationTap)),
        _buildDivider(),
        Expanded(child: _buildStatItem('Difficulty', _formatDifficulty(difficulty), onDifficultyTap)),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Top row
        Row(
          children: [
            Expanded(child: _buildStatItem('Distance', _formatDistance(distance), onDistanceTap)),
            _buildDivider(),
            Expanded(child: _buildStatItem('Elevation', _formatElevation(elevation), onElevationTap)),
          ],
        ),
        // Divider between rows
        Container(
          height: 1.0,
          color: WaypointColors.borderLight,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        // Bottom row
        Row(
          children: [
            Expanded(child: _buildStatItem('Duration', duration ?? '—', onDurationTap)),
            _buildDivider(),
            Expanded(child: _buildStatItem('Difficulty', _formatDifficulty(difficulty), onDifficultyTap)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatItem(String label, String value, VoidCallback? onTap) {
    final child = Column(
      children: [
        Text(
          value,
          style: WaypointTypography.statValue,
        ),
        const SizedBox(height: 4.0),
        Text(
          label.toUpperCase(),
          style: WaypointTypography.statLabel,
        ),
      ],
    );
    
    if (isEditable && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0),
            color: Colors.transparent,
          ),
          child: child,
        ),
      );
    }
    
    return child;
  }
  
  Widget _buildDivider() {
    return Container(
      width: 1.0,
      height: 32.0,
      color: WaypointColors.borderLight,
      margin: const EdgeInsets.symmetric(horizontal: WaypointSpacing.gapSm),
    );
  }
  
  String _formatDistance(double? distance) {
    if (distance == null) return '—';
    return '${distance.toStringAsFixed(1)} km';
  }
  
  String _formatElevation(int? elevation) {
    if (elevation == null) return '—';
    return '$elevation m';
  }
  
  String _formatDifficulty(String? difficulty) {
    if (difficulty == null || difficulty == 'none') return '—';
    
    final difficultyText = difficulty[0].toUpperCase() + difficulty.substring(1);
    return '● $difficultyText';
  }
}

