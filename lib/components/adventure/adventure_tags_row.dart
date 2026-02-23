import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/state/adventure_form_state.dart';

/// Adventure tags row component
/// 
/// Displays horizontal wrap of pill-shaped tag chips:
/// - Activity type (green)
/// - Accommodation type (orange)
/// - Best season (blue)
/// - Location (gray)

class AdventureTagsRow extends StatelessWidget {
  final AdventureFormState? formState;
  final ActivityCategory? activityCategory;
  final AccommodationType? accommodationType;
  final List<SeasonRange>? bestSeasons;
  final bool? isEntireYear;
  final String? location;
  
  const AdventureTagsRow({
    super.key,
    this.formState,
    this.activityCategory,
    this.accommodationType,
    this.bestSeasons,
    this.isEntireYear,
    this.location,
  });
  
  // Get values from formState if provided, otherwise use direct parameters
  ActivityCategory? get _activityCategory => 
      formState?.activityCategory ?? activityCategory;
  AccommodationType? get _accommodationType => 
      formState?.accommodationType ?? accommodationType;
  List<SeasonRange> get _bestSeasons => 
      formState?.bestSeasons ?? bestSeasons ?? [];
  bool get _isEntireYear => 
      formState?.isEntireYear ?? isEntireYear ?? false;
  String get _location => 
      formState?.locationCtrl.text ?? location ?? '';
  
  String get _locationDisplay {
    // Prefer locations list if available (multi-location support)
    if (formState != null && formState!.locations.isNotEmpty) {
      return formState!.locations.map((loc) => loc.shortName).join(' · ');
    }
    // Fallback to single location string
    return _location;
  }
  
  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    
    // Activity type tag
    if (_activityCategory != null) {
      tags.add(_buildTag(
        emoji: _getActivityEmoji(_activityCategory!),
        label: _getActivityLabel(_activityCategory!),
        color: WaypointColors.catStay,
        backgroundColor: WaypointColors.catStaySurface,
        borderColor: WaypointColors.catStayBorder,
      ));
    }
    
    // Accommodation type tag
    if (_accommodationType != null) {
      tags.add(_buildTag(
        emoji: _accommodationType == AccommodationType.comfort ? '🏨' : '⛺',
        label: _accommodationType == AccommodationType.comfort ? 'Comfort' : 'Adventure',
        color: const Color(0xFFE65100), // Orange tint
        backgroundColor: WaypointColors.catEatSurface,
        borderColor: WaypointColors.catEatBorder,
      ));
    }
    
    // Best season tag
    final seasonText = _getBestSeasonDisplay();
    if (seasonText.isNotEmpty) {
      tags.add(_buildTag(
        emoji: '📅',
        label: seasonText,
        color: const Color(0xFF1565C0), // Blue tint
        backgroundColor: WaypointColors.catDoSurface,
        borderColor: WaypointColors.catDoBorder,
      ));
    }
    
    // Location tag(s) - shows multiple locations joined by " · "
    final locationText = _locationDisplay;
    if (locationText.isNotEmpty) {
      tags.add(_buildTag(
        emoji: '📍',
        label: locationText,
        color: WaypointColors.textSecondary,
        backgroundColor: WaypointColors.surface,
        borderColor: WaypointColors.border,
      ));
    }
    
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: tags,
    );
  }
  
  Widget _buildTag({
    required String emoji,
    required String label,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 14.0),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: WaypointTypography.chipLabel.copyWith(
              color: color,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getActivityEmoji(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return '🥾';
      case ActivityCategory.cycling:
        return '🚴';
      case ActivityCategory.skis:
        return '⛷️';
      case ActivityCategory.climbing:
        return '🧗';
      case ActivityCategory.cityTrips:
        return '🏙️';
      case ActivityCategory.tours:
        return '🌏';
      case ActivityCategory.roadTripping:
        return '🚗';
    }
  }
  
  String _getActivityLabel(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trips';
      case ActivityCategory.tours:
        return 'Tours';
      case ActivityCategory.roadTripping:
        return 'Road Tripping';
    }
  }
  
  String _getBestSeasonDisplay() {
    if (_isEntireYear) {
      return 'Year-round';
    }
    if (_bestSeasons.isEmpty) {
      return '';
    }
    
    return _bestSeasons.map((range) {
      final startMonth = _monthAbbrev(range.startMonth);
      final endMonth = _monthAbbrev(range.endMonth);
      return '$startMonth – $endMonth';
    }).join(', ');
  }
  
  String _monthAbbrev(int monthNum) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[monthNum - 1];
  }
}

