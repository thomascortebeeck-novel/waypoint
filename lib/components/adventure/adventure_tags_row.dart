import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/utils/activity_icons.dart';

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
  /// When false, location is not shown as a chip (e.g. when location is in header).
  final bool showLocationChip;

  const AdventureTagsRow({
    super.key,
    this.formState,
    this.activityCategory,
    this.accommodationType,
    this.bestSeasons,
    this.isEntireYear,
    this.location,
    this.showLocationChip = true,
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
    
    final colorScheme = Theme.of(context).colorScheme;
    // Activity type tag
    if (_activityCategory != null) {
      tags.add(_buildTag(
        context: context,
        iconData: getActivityIconData(_activityCategory!),
        label: _getActivityLabel(_activityCategory!),
        color: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderColor: colorScheme.outlineVariant,
      ));
    }
    
    // Accommodation type tag
    if (_accommodationType != null) {
      tags.add(_buildTag(
        context: context,
        iconData: getAccommodationIconData(_accommodationType!),
        label: _accommodationType == AccommodationType.comfort ? 'Comfort' : 'Adventure',
        color: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        borderColor: colorScheme.outlineVariant,
      ));
    }
    
    // Best season tag (Icons.calendar_month; label carries range e.g. "Feb – Mar")
    final seasonText = _getBestSeasonDisplay();
    if (seasonText.isNotEmpty) {
      tags.add(_buildTag(
        context: context,
        iconData: seasonChipIcon,
        label: seasonText,
        color: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderColor: colorScheme.outlineVariant,
      ));
    }
    
    // Location tag(s) - shows multiple locations joined by " · " (omit when in header)
    final locationText = showLocationChip ? _locationDisplay : '';
    if (locationText.isNotEmpty) {
      tags.add(_buildTag(
        context: context,
        iconData: locationChipIcon,
        label: locationText,
        color: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHighest,
        borderColor: colorScheme.outlineVariant,
      ));
    }
    
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: WaypointSpacing.gapSm,
      runSpacing: WaypointSpacing.gapSm,
      children: tags,
    );
  }
  
  Widget _buildTag({
    required BuildContext context,
    required IconData iconData,
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
          Icon(iconData, size: 14.0, color: color),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontSize: 12.0,
            ) ?? WaypointTypography.chipLabel.copyWith(
              color: color,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
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

