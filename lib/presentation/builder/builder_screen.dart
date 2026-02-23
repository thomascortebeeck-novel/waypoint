import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/components/waypoint/unified_waypoint_card.dart';
import 'package:waypoint/components/builder/day_timeline_section.dart';
import 'package:waypoint/components/day_content_builder.dart';
import 'package:waypoint/models/orderable_item.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/integrations/mapbox_service.dart'; // For PlaceSuggestion class
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/services/link_preview_service.dart';
import 'package:waypoint/presentation/widgets/link_preview_card.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/utils/google_link_parser.dart';
import 'package:waypoint/services/storage_service.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' show pi, pow, sin, cos, asin, sqrt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:waypoint/components/map/waypoint_map_card.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/components/reorder_controls.dart';
import 'package:waypoint/services/travel_calculator_service.dart';
import 'package:waypoint/services/waypoint_grouping_service.dart';
import 'package:waypoint/components/widgets/scroll_blocking_dialog.dart';
import 'package:waypoint/integrations/google_directions_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/components/builder/route_info_section.dart';
import 'package:waypoint/services/route_info_calculator_service.dart';
import 'package:waypoint/services/adventure_context_service.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/services/gpx_waypoint_snapper.dart';
import 'package:waypoint/utils/activity_utils.dart';
import 'package:waypoint/utils/travel_formatting_utils.dart';
import 'package:waypoint/components/builder/sidebar_waypoint_tile.dart';
import 'package:waypoint/models/waypoint_edit_result.dart';
// Phase 1: Add new state classes and services
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/state/day_form_state.dart';
import 'package:waypoint/state/sub_form_states.dart';
import 'package:waypoint/state/location_search_state.dart';
import 'package:waypoint/services/adventure_save_service.dart';
import 'package:waypoint/utils/activity_config.dart';
import 'package:waypoint/components/builder/breadcrumb_widget.dart';
import 'package:waypoint/components/builder/location_search_dialog.dart';

/// @deprecated This screen is deprecated. Use [AdventureDetailScreen] with [AdventureMode.builder] instead.
/// This file is kept for reference but should not be used in new code.
/// Migration: Replace `BuilderScreen(editPlanId: planId)` with `AdventureDetailScreen(mode: AdventureMode.builder, planId: planId)`
@Deprecated('Use AdventureDetailScreen with AdventureMode.builder instead')
class BuilderScreen extends StatefulWidget {
final String? editPlanId;
const BuilderScreen({super.key, this.editPlanId});

@override
State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> with SingleTickerProviderStateMixin {
  // Step constants
  static const int stepActivityType = 0;
  static const int stepLocations = 1;
  static const int stepGeneralInfo = 2;
  static const int stepVersions = 3;
  static const int stepPrepare = 4;
  static const int stepLocalTips = 5;
  static const int stepDays = 6;
  static const int stepOverview = 7;
  
  static const List<String> stepLabels = [
    'Activity Type',
    'Locations',
    'General Info',
    'Versions',
    'Prepare',
    'Local Tips',
    'Days',
    'Overview',
  ];
  
final PageController _pageController = PageController();
int _currentStep = 0;
// Phase 5: _isSaving removed - now using formState.isSaving
bool _isLoadingExisting = false;
bool _isInitializing = true;

// Phase 8: Track previous activity type for change detection
ActivityCategory? _previousActivityCategory;

// Phase 5: Old state variables removed - now using formState

final _auth = FirebaseAuthManager();
final _planService = PlanService();
final _userService = UserService();
final _storageService = StorageService();

// Phase 1: New state classes
AdventureFormState? formState; // Nullable because _loadExistingPlan() is async
late final AdventureSaveService saveService;
  
  // Current day being edited in Step 5
  int _currentDayIndex = 0;
  
  // Day plan ordering (per day)
  Map<int, DayPlanOrderManager> _dayOrderManagers = {};

/// Returns the appropriate time label based on activity category
String _getActivityTimeLabel() {
  final category = formState?.activityCategory;
  switch (category) {
    case ActivityCategory.cycling:
      return 'Cycling Time (h)';
    case ActivityCategory.roadTripping:
      return 'Driving Time (h)';
    case ActivityCategory.skis:
      return 'Skiing Time (h)';
    case ActivityCategory.climbing:
      return 'Climbing Time (h)';
    case ActivityCategory.cityTrips:
    case ActivityCategory.tours:
      return 'Duration (h)';
    case ActivityCategory.hiking:
    default:
      return 'Hiking Time (h)';
  }
}

/// Returns the short activity label for route builder
String _getActivityLabel() {
  final category = formState?.activityCategory;
  switch (category) {
    case ActivityCategory.cycling:
      return 'Cycling';
    case ActivityCategory.roadTripping:
      return 'Driving';
    case ActivityCategory.skis:
      return 'Skiing';
    case ActivityCategory.climbing:
      return 'Climbing';
    case ActivityCategory.cityTrips:
      return 'Walking';
    case ActivityCategory.tours:
      return 'Touring';
    case ActivityCategory.hiking:
    default:
      return 'Hiking';
  }
}

/// Returns the month name for a given month number (1-12)
String _getMonthName(int monthNum) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (monthNum >= 1 && monthNum <= 12) {
    return months[monthNum - 1];
  }
  return 'Unknown';
}

@override
void dispose() {
// Phase 5: Old state disposal removed - formState handles its own disposal
_pageController.removeListener(_onPageChanged);
_pageController.dispose();
formState?.dispose(); // Dispose new state
super.dispose();
}

@override
void initState() {
  super.initState();
  // Add PageController listener to keep _currentStep in sync
  _pageController.addListener(_onPageChanged);

  // Phase 1: Initialize new save service
  saveService = AdventureSaveService(
    planService: _planService,
    storageService: _storageService,
    userService: _userService,
  );

  if (widget.editPlanId != null) {
    _loadExistingPlan(widget.editPlanId!);
    // formState will be set in _loadExistingPlan (async)
  } else {
    // Phase 5: Initialize new state for new plans (old state removed)
    formState = AdventureFormState.initial();
    // Phase 8: Track initial activity category
    _previousActivityCategory = formState!.activityCategory;
    
    // Delay to allow validation to run after first build
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isInitializing = false);
    });
  }
  // Phase 5: Old listeners removed - formState handles its own updates via ChangeNotifier
}

// Phase 5: _addVersionListeners removed - new state classes handle their own updates via ChangeNotifier

// Removed _addFaqListeners - FAQ items now use ChangeNotifier pattern via FAQFormState

void _onPageChanged() {
final page = _pageController.page?.round() ?? 0;
if (page != _currentStep) {
debugPrint('[builder] Page changed: page=$page, currentStep=$_currentStep');
setState(() => _currentStep = page);
}
}

Future<void> _loadExistingPlan(String planId) async {
setState(() => _isLoadingExisting = true);
try {
// Use loadFullPlan to properly load data from subcollections (versions, days, FAQ items)
final plan = await _planService.loadFullPlan(planId);
if (plan != null) {
// Phase 5: Create new state from plan (old state removed)
formState = AdventureFormState.fromPlan(plan);
// Phase 8: Track initial activity category
_previousActivityCategory = formState!.activityCategory;

// Geocode location for new state (if needed)
if (plan.location.isNotEmpty) {
  try {
    final placesService = GooglePlacesService();
    final location = await placesService.geocodeAddress(plan.location);
    if (location != null && mounted) {
      formState!.locationSearch.selectedLocation = location;
      formState!.locationSearch.selectedLocationName = plan.location;
      formState!.locationSearch.notifyListeners();
    }
  } catch (e) {
    Log.w('builder', 'Failed to geocode location for new state: $e');
  }
}

// Trigger rebuild now that formState is set
if (mounted) setState(() {});
}
} catch (e) {
debugPrint('Failed to load plan for edit: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load plan')));
context.pop();
}
} finally {
if (mounted) {
setState(() {
_isLoadingExisting = false;
_isInitializing = false;
});
}
}
}

// Phase 5: Updated to use new state
/// Validate if current step has all required fields filled
bool _canProceedFromCurrentStep() {
if (formState == null) return false;
  
switch (_currentStep) {
case stepActivityType: // Step 0: Activity Type
  return formState!.activityCategory != null;
case stepLocations: // Step 1: Locations
  return formState!.isLocationStepValid;
case stepGeneralInfo: // Step 2: General Info
final priceValid = (double.tryParse(formState!.priceCtrl.text.replaceAll(',', '.')) ?? -1) >= 0;
return formState!.nameCtrl.text.trim().isNotEmpty &&
formState!.descriptionCtrl.text.trim().isNotEmpty &&
priceValid;
// Cover image is now optional
case stepVersions: // Step 3: Versions
if (formState!.versions.isEmpty) return false;
// Check if at least one version has valid duration
for (final v in formState!.versions) {
final duration = v.daysCount;
if (duration > 0) return true;
}
return false;
case stepPrepare: // Step 4: Prepare (includes packing + transportation)
  return true; // Optional, can skip
case stepLocalTips: // Step 5: Local Tips
  return true; // Optional, can skip
case stepDays: // Step 6: Days
return true; // No strict validation
case stepOverview: // Step 7: Overview
return true; // Can always proceed from overview (validation happens on publish)
default:
return false;
}
}

@override
Widget build(BuildContext context) {
// Phase 2: Guard against null formState during async load
if (formState == null && _isLoadingExisting) {
  return Scaffold(
    backgroundColor: const Color(0xFFFAFBFA),
    body: const Center(
      child: CircularProgressIndicator(),
    ),
  );
}

return Scaffold(
backgroundColor: const Color(0xFFFAFBFA),
appBar: AppBar(
backgroundColor: Colors.white,
elevation: 0,
scrolledUnderElevation: 0,
toolbarHeight: 64,
leading: GestureDetector(
onTap: () => context.go('/'),
child: Padding(
padding: const EdgeInsets.all(12),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(FontAwesomeIcons.mountainSun, size: 18, color: const Color(0xFF428A13)),
],
),
),
),
leadingWidth: 56,
title: Text(
widget.editPlanId == null ? "Create Adventure" : 'Edit Adventure',
style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
),
actions: [
Padding(
padding: const EdgeInsets.only(right: 16),
child: _buildAutoSaveIndicator(),
),
],
),
body: _isLoadingExisting
? const Center(child: CircularProgressIndicator())
: Column(
children: [
// Breadcrumb navigation
if (formState != null)
  BuilderBreadcrumb(
    currentStep: _currentStep,
    activityCategory: formState!.activityCategory,
    locations: formState!.locations,
    onStepTap: (step) {
      if (step >= 0 && step < 8) {
        _pageController.jumpToPage(step);
        setState(() => _currentStep = step);
      }
    },
    isMobile: MediaQuery.of(context).size.width < 768,
  ),
// Step Progress Indicator (centered, modern)
_buildStepProgressIndicator(),
// Content
Expanded(
child: PageView(
controller: _pageController,
physics: const NeverScrollableScrollPhysics(),
children: [
_buildStep0ActivityType(),
_buildStep1Locations(),
_buildStep2GeneralInfo(),
_buildStep3Versions(),
_buildStep4Prepare(),
_buildStep5LocalTips(),
_buildStep6Days(),
_buildStep7Overview(),
],
),
),
],
),
bottomNavigationBar: Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 20,
offset: const Offset(0, -4),
),
],
),
child: SafeArea(
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
if (_currentStep > stepActivityType)
TextButton.icon(
onPressed: () {
_pageController.previousPage(
duration: const Duration(milliseconds: 300),
curve: Curves.easeInOut,
);
setState(() => _currentStep--);
},
icon: const Icon(Icons.arrow_back, size: 20),
label: const Text("Back"),
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
foregroundColor: context.colors.onSurfaceVariant,
),
)
else
const SizedBox(width: 100),

        ElevatedButton(
onPressed: (_isInitializing || (formState?.isSaving ?? false) || (_currentStep < stepOverview && !_canProceedFromCurrentStep()))
? null
: () async {
            if (_currentStep < stepOverview) {
if (!_canProceedFromCurrentStep()) {
String message = '';
switch (_currentStep) {
case stepActivityType:
message = 'Please select an activity type';
break;
case stepLocations:
message = 'Please add at least one location';
break;
case stepGeneralInfo:
if (formState?.nameCtrl.text.trim().isEmpty ?? true) {
message = 'Please enter an adventure name';
} else if (formState?.descriptionCtrl.text.trim().isEmpty ?? true) {
message = 'Please enter a description';
}
break;
case stepVersions:
message = 'Please add at least one version with valid duration and price';
break;
}
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
return;
}

              // Save before navigating to the next step (only in edit mode)
              if (widget.editPlanId != null) {
                final success = await _saveCurrentStep();
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to save. Please try again.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }

              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentStep++);
} else {
if (widget.editPlanId != null) {
await _saveChanges(context);
} else {
await _publishPlan(context);
}
}
},
style: ElevatedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
backgroundColor: context.colors.primary,
foregroundColor: Colors.white,
elevation: 2,
shadowColor: context.colors.primary.withValues(alpha: 0.3),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
minimumSize: const Size(120, 48),
),
child: (formState?.isSaving ?? false)
? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
_currentStep == stepOverview ? (widget.editPlanId != null ? 'Save Changes' : "Publish Adventure") : "Next",
style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
),
const SizedBox(width: 8),
Icon(_currentStep == stepOverview ? Icons.check : Icons.arrow_forward, size: 18),
],
),
),
],
),
),
),
);
}

Widget _buildStepProgressIndicator() {
final steps = stepLabels;

return Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
color: Colors.white,
child: SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Row(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: List.generate(steps.length * 2 - 1, (index) {
if (index.isEven) {
// Step indicator
final stepIndex = index ~/ 2;
return _buildModernStepIndicator(stepIndex, steps[stepIndex]);
} else {
// Connection line
final lineIndex = index ~/ 2;
return Container(
width: 40,
height: 2,
color: _currentStep > lineIndex ? BrandColors.primary : const Color(0xFFE5EBE5),
);
}
}),
),
),
);
}

Widget _buildModernStepIndicator(int stepIndex, String label) {
final isActive = _currentStep == stepIndex;
final isCompleted = _currentStep > stepIndex;
return GestureDetector(
onTap: () async {
// Save data before navigating
if (stepIndex != _currentStep) {
await _saveCurrentStep();
}
// Navigate to the tapped step
_pageController.animateToPage(
stepIndex,
duration: const Duration(milliseconds: 300),
curve: Curves.easeInOut,
);
setState(() => _currentStep = stepIndex);
},
child: MouseRegion(
cursor: SystemMouseCursors.click,
child: SizedBox(
width: 80,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 300),
curve: Curves.easeInOut,
width: 40,
height: 40,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: isCompleted
? BrandColors.primary  // #2D6A4F - Primary green
: Colors.white,
border: Border.all(
color: isCompleted || isActive
? BrandColors.primary  // #2D6A4F - Primary green
: const Color(0xFFE5EBE5),
width: 2,
),
boxShadow: isActive ? [
BoxShadow(
color: BrandColors.primary.withValues(alpha: 0.15),  // #2D6A4F with opacity
blurRadius: 12,
spreadRadius: 4,
),
] : null,
),
child: Center(
child: isCompleted
? const Icon(Icons.check, size: 20, color: Colors.white)
: Text(
'${stepIndex + 1}',
style: TextStyle(
color: isActive ? BrandColors.primary : const Color(0xFF8A8A8A),  // #2D6A4F for active
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
),
),
const SizedBox(height: 8),
Text(
label,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 12,
fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
color: isActive || isCompleted ? const Color(0xFF1A1C19) : const Color(0xFF8A8A8A),
),
overflow: TextOverflow.ellipsis,
),
],
),
),
),
);
}

// Phase 8: Haversine distance calculation (in meters)
double _haversineDistance(ll.LatLng a, ll.LatLng b) {
  const R = 6371000.0; // Earth radius in meters
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLon = (b.longitude - a.longitude) * pi / 180;
  final lat1 = a.latitude * pi / 180;
  final lat2 = b.latitude * pi / 180;
  final a2 = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
  return 2 * R * asin(sqrt(a2));
}

// Phase 8: Confirm activity type change with waypoint checking
Future<bool> _confirmActivityTypeChange(ActivityCategory newType) async {
  if (formState == null) return true;
  
  final oldConfig = getActivityConfig(_previousActivityCategory);
  final newConfig = getActivityConfig(newType);
  
  // Check if constraints changed significantly
  if (oldConfig?.maxLocations != newConfig?.maxLocations ||
      oldConfig?.locationOrderMatters != newConfig?.locationOrderMatters) {
    
    // Check for waypoints in locations that will be deleted
    var locationsToDelete = <LocationInfo>[];
    final waypointsInDeletedLocations = <RouteWaypoint>[];
    
    if (newConfig?.maxLocations == 1 && formState!.locations.length > 1) {
      // Will delete all but first location
      locationsToDelete = formState!.locations.skip(1).toList();
      
      // Check all versions and days for waypoints in deleted locations
      for (final version in formState!.versions) {
        for (int dayNum = 1; dayNum <= version.daysCount; dayNum++) {
          final dayState = version.getDayState(dayNum);
          final route = dayState.route;
          if (route != null) {
            final waypoints = dayState.getOrderedWaypoints();
            
            for (final waypoint in waypoints) {
              // Check if waypoint is in any deleted location
              for (final deletedLoc in locationsToDelete) {
                if (deletedLoc.latitude != null && deletedLoc.longitude != null) {
                  final distance = _haversineDistance(
                    waypoint.position,
                    ll.LatLng(deletedLoc.latitude!, deletedLoc.longitude!),
                  );
                  // If waypoint is within 50km of deleted location, consider it associated
                  if (distance < 50000) {
                    waypointsInDeletedLocations.add(waypoint);
                    break; // Only count once per waypoint
                  }
                }
              }
            }
          }
        }
      }
    }
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Activity Type?'),
        content: Text(
          _getActivityChangeMessage(
            oldConfig,
            newConfig,
            formState!.locations.length,
            locationsToDelete.length,
            waypointsInDeletedLocations.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    ) ?? false;
  }
  return true;
}

// Phase 8: Generate activity change warning message
String _getActivityChangeMessage(
  ActivityConfig? old,
  ActivityConfig? new_,
  int currentLocations,
  int locationsToDelete,
  int waypointsToAffect,
) {
  if (new_?.maxLocations == 1 && currentLocations > 1) {
    final locationMsg = locationsToDelete > 0
        ? 'Changing to ${new_!.locationLabel} will delete $locationsToDelete location${locationsToDelete != 1 ? 's' : ''}'
        : 'Changing to ${new_!.locationLabel} will limit you to one location';
    
    final waypointMsg = waypointsToAffect > 0
        ? ' and their associated $waypointsToAffect waypoint${waypointsToAffect != 1 ? 's' : ''}'
        : '';
    
    return '$locationMsg$waypointMsg. Only the first location will be kept. Proceed?';
  }
  if (old?.maxLocations == 1 && new_?.maxLocations != 1) {
    return 'Changing activity type will allow multiple locations. '
           'You can add more locations in the next step. Proceed?';
  }
  return 'Changing activity type may affect location requirements. Proceed?';
}

// Phase 8: Handle activity type change
void _handleActivityTypeChange(ActivityCategory newType) {
  if (formState == null) return;
  if (newType == formState!.activityCategory) return;
  
  final oldConfig = getActivityConfig(formState!.activityCategory);
  final newConfig = getActivityConfig(newType);
  
  // Update activity category
  formState!.activityCategory = newType;
  
  // Handle location constraints
  if (newConfig?.maxLocations == 1 && formState!.locations.length > 1) {
    // Keep only first location
    formState!.setLocations([formState!.locations.first]);
  }
  
  // Update previous activity category for next change
  _previousActivityCategory = newType;
}

Widget _buildStep0ActivityType() {
  return SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Activity Type", style: context.textStyles.headlineMedium),
              const SizedBox(height: 8),
              Text("Choose the type of adventure you're planning.", style: context.textStyles.bodyMedium),
              const SizedBox(height: 24),
              
              // Activity type selection grid
              ListenableBuilder(
                listenable: formState!,
                builder: (context, _) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ActivityCategory.values.map((category) {
                      final config = getActivityConfig(category);
                      final isSelected = formState!.activityCategory == category;
                      
                      return GestureDetector(
                        onTap: () async {
                          // Phase 8: Check for activity type change and confirm if needed
                          if (formState!.activityCategory != category) {
                            final confirmed = await _confirmActivityTypeChange(category);
                            if (!confirmed) return;
                            
                            setState(() {
                              _handleActivityTypeChange(category);
                            });
                          }
                        },
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? BrandColors.primary.withValues(alpha: 0.1) : Colors.white,
                            border: Border.all(
                              color: isSelected ? BrandColors.primary : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                config?.icon ?? '🏔️',
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                config?.displayName ?? category.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? BrandColors.primary : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildStep1Locations() {
  return SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Locations", style: context.textStyles.headlineMedium),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: formState!,
                builder: (context, _) {
                  final config = getActivityConfig(formState!.activityCategory);
                  return Text(
                    config?.locationLabel ?? "Add locations for your adventure",
                    style: context.textStyles.bodyMedium,
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Location list
              ListenableBuilder(
                listenable: formState!,
                builder: (context, _) {
                  if (formState!.locations.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.place, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            "No locations added yet",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final config = getActivityConfig(formState!.activityCategory);
                  final canReorder = config?.locationOrderMatters ?? false;
                  
                  if (canReorder) {
                    // Use ReorderableListView for activities that require ordering
                    return ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        formState!.reorderLocations(oldIndex, newIndex);
                      },
                      children: formState!.locations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final location = entry.value;
                        
                        return Container(
                          key: ValueKey('location_$index'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_handle, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF428A13),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location.shortName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (location.fullAddress != location.shortName)
                                      Text(
                                        location.fullAddress,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  formState!.removeLocation(index);
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  } else {
                    // Regular list for activities that don't require ordering
                    return Column(
                      children: formState!.locations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final location = entry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location.shortName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (location.fullAddress != location.shortName)
                                      Text(
                                        location.fullAddress,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  formState!.removeLocation(index);
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Add location button
              ListenableBuilder(
                listenable: formState!,
                builder: (context, _) {
                  final config = getActivityConfig(formState!.activityCategory);
                  final canAddMore = config == null || 
                      config.maxLocations == null || 
                      formState!.locations.length < config.maxLocations!;
                  
                  if (!canAddMore) {
                    return const SizedBox.shrink();
                  }
                  
                  return OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<LocationInfo>(
                        context: context,
                        builder: (context) => const LocationSearchDialog(),
                      );
                      if (result != null && mounted) {
                        formState!.addLocation(result);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Location'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildStep2GeneralInfo() {
return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 800),
child: Padding(
padding: AppSpacing.paddingMd,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text("General Info", style: context.textStyles.headlineMedium),
const SizedBox(height: 8),
Text("Tell travelers what this adventure is about.", style: context.textStyles.bodyMedium),
const SizedBox(height: 24),

// Phase 3.1: Simple text fields - use new state (no ListenableBuilder needed for TextField)
_buildTextField("Adventure Name", "e.g., The Arctic Trail", controller: formState!.nameCtrl, required: true),
const SizedBox(height: 16),
// Location summary (read-only, from Step 1)
ListenableBuilder(
  listenable: formState!,
  builder: (context, _) {
    if (formState!.locations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Please add locations in Step 1",
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                "Locations",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formState!.locations.map((location) {
              return Chip(
                label: Text(location.shortName),
                avatar: const Icon(Icons.place, size: 16),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            "To edit locations, go back to Step 1",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  },
),
const SizedBox(height: 16),
// Phase 3.1: Simple text fields - use new state
_buildTextField("Description", "Describe the experience...", controller: formState!.descriptionCtrl, maxLines: 8, required: true),
const SizedBox(height: 24),

Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text("Cover Image", style: context.textStyles.titleMedium),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.red.shade50,
borderRadius: BorderRadius.circular(4),
),
child: Text(
'Required',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w600,
color: Colors.red.shade700,
),
),
),
],
),
const SizedBox(height: 8),
GestureDetector(
// Phase 3.1: Use new state
onTap: formState!.uploadingCoverImage ? null : _pickCoverImage,
child: Container(
height: 200,
decoration: BoxDecoration(
// Phase 3.1: Use new state
color: (formState!.coverImageBytes != null || formState!.heroImageUrlCtrl.text.trim().isNotEmpty)
? Colors.black
: context.colors.surfaceContainerHighest,
borderRadius: BorderRadius.circular(AppRadius.md),
border: Border.all(color: context.colors.outline, style: BorderStyle.solid),
// Phase 3.1: Use new state
image: formState!.coverImageBytes != null
? DecorationImage(
image: MemoryImage(formState!.coverImageBytes!),
fit: BoxFit.cover,
)
: formState!.heroImageUrlCtrl.text.trim().isNotEmpty
? DecorationImage(
image: NetworkImage(formState!.heroImageUrlCtrl.text.trim()),
fit: BoxFit.cover,
)
: null,
),
// Phase 3.1: Use new state
child: formState!.uploadingCoverImage
? const Center(child: CircularProgressIndicator())
: (formState!.coverImageBytes == null && formState!.heroImageUrlCtrl.text.trim().isEmpty)
? Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.add_photo_alternate, size: 40, color: context.colors.secondary),
const SizedBox(height: 8),
Text("Tap to Upload Cover Image", style: context.textStyles.labelLarge),
],
),
)
: Stack(
children: [
Positioned(
top: 8,
right: 8,
child: CircleAvatar(
backgroundColor: Colors.black54,
child: IconButton(
icon: const Icon(Icons.close, color: Colors.white, size: 20),
// Phase 3.1: Use new state
onPressed: () => setState(() {
formState!.coverImageBytes = null;
formState!.coverImageExtension = null;
formState!.heroImageUrlCtrl.clear();
}),
),
),
),
Positioned(
bottom: 8,
right: 8,
child: FilledButton.icon(
onPressed: _pickCoverImage,
icon: const Icon(Icons.edit, size: 16),
label: const Text('Change'),
style: FilledButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
),
),
],
),
),
),
const SizedBox(height: 12),
// Phase 3.1: Simple text fields - use new state
_buildTextField("Or paste Image URL", "https://...", controller: formState!.heroImageUrlCtrl, required: false),
const SizedBox(height: 24),
// Phase 3.1: Simple text fields - use new state
_buildTextField("Price (€)", "2.00", controller: formState!.priceCtrl, isNumber: true, required: true),
const SizedBox(height: 8),
Text(
"This is the price for purchasing this adventure plan",
style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
),
const SizedBox(height: 24),

// Best Season Section
Text("Best Season", style: context.textStyles.titleMedium),
const SizedBox(height: 8),
Text("When is the best time to visit this adventure?", style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700)),
const SizedBox(height: 12),
// Entire Year Checkbox
CheckboxListTile(
  title: Text("Available year-round", style: context.textStyles.bodyMedium),
  value: formState?.isEntireYear ?? false,
  onChanged: (value) {
    if (formState != null) {
      setState(() {
        formState!.isEntireYear = value ?? false;
        if (formState!.isEntireYear) {
          formState!.bestSeasons.clear(); // Clear seasons if entire year is selected
        }
      });
    }
  },
  contentPadding: EdgeInsets.zero,
  controlAffinity: ListTileControlAffinity.leading,
),
if (formState != null && !formState!.isEntireYear) ...[
  const SizedBox(height: 12),
  // Season Ranges List
  ...List.generate(formState!.bestSeasons.length, (index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: formState!.bestSeasons[index].startMonth,
              decoration: InputDecoration(
                labelText: "Start Month",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: List.generate(12, (i) {
                final monthNum = i + 1;
                return DropdownMenuItem(
                  value: monthNum,
                  child: Text(_getMonthName(monthNum)),
                );
              }),
              onChanged: (value) {
                if (value != null && formState != null) {
                  setState(() {
                    formState!.bestSeasons[index] = SeasonRange(
                      startMonth: value,
                      endMonth: formState!.bestSeasons[index].endMonth,
                    );
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: formState!.bestSeasons[index].endMonth,
              decoration: InputDecoration(
                labelText: "End Month",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: List.generate(12, (i) {
                final monthNum = i + 1;
                return DropdownMenuItem(
                  value: monthNum,
                  child: Text(_getMonthName(monthNum)),
                );
              }),
              onChanged: (value) {
                if (value != null && formState != null) {
                  setState(() {
                    formState!.bestSeasons[index] = SeasonRange(
                      startMonth: formState!.bestSeasons[index].startMonth,
                      endMonth: value,
                    );
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              if (formState != null) {
                setState(() {
                  formState!.bestSeasons.removeAt(index);
                });
              }
            },
            tooltip: "Remove season",
          ),
        ],
      ),
    );
  }),
  const SizedBox(height: 8),
  // Add Season Button
  OutlinedButton.icon(
    onPressed: () {
      if (formState != null) {
        setState(() {
          formState!.bestSeasons.add(SeasonRange(
            startMonth: 1,
            endMonth: 12,
          ));
        });
      }
    },
    icon: const Icon(Icons.add, size: 18),
    label: const Text("Add Season"),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.green,
      side: const BorderSide(color: Colors.green),
    ),
  ),
],
const SizedBox(height: 32),

// Activity Categorization Section
// Activity Type summary (read-only, from Step 0)
ListenableBuilder(
  listenable: formState!,
  builder: (context, _) {
    final config = getActivityConfig(formState!.activityCategory);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(config?.icon ?? '🏔️', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            config?.displayName ?? 'No activity selected',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              _pageController.animateToPage(
                stepActivityType,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentStep = stepActivityType);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  },
),
const SizedBox(height: 16),
if (formState?.activityCategory != null &&
formState!.activityCategory != ActivityCategory.cityTrips &&
formState!.activityCategory != ActivityCategory.tours &&
formState!.activityCategory != ActivityCategory.roadTripping) ...[
_buildAccommodationTypeField(),
const SizedBox(height: 32),
],

// FAQ Section
Text("Frequently Asked Questions", style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Text("Add helpful information for travelers", style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700)),
const SizedBox(height: 16),
_buildGeneralInfoFAQSection(),
const SizedBox(height: 32),

// Generate Info Button
_buildGenerateInfoButton(),
],
),
),
),
),
);
}

Widget _buildStep3Versions() {
return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 800),
child: Padding(
padding: AppSpacing.paddingMd,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text("Define Versions", style: context.textStyles.headlineMedium),
const SizedBox(height: 8),
Text("Create different ways to experience this route.", style: context.textStyles.bodyMedium),
const SizedBox(height: 24),
// Phase 3.2: Use new state for display
...List.generate(formState!.versions.length, (index) => _buildVersionCard(index)),
const SizedBox(height: 16),
OutlinedButton.icon(
onPressed: () {
final newVersion = VersionFormState.initial();
// Phase 5: Use new state
setState(() {
formState!.versions.add(newVersion);
if (formState!.activeVersionIndex >= formState!.versions.length - 1) {
formState!.activeVersionIndex = formState!.versions.length - 1;
}
});
},
icon: const Icon(Icons.add),
label: const Text("Add Another Version"),
style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), side: BorderSide(color: context.colors.primary)),
),
],
),
),
),
),
);
}

// Step 3: What to Pack
Widget _buildStep4Prepare() {
  // Phase 3.2: Use new state for checks
  if (formState!.versions.isEmpty) {
    return Center(
      child: Text(
        'Add at least one version first',
        style: context.textStyles.bodyMedium,
      ),
    );
  }
  // Use LayoutBuilder to get proper constraints instead of SizedBox.expand
  // which causes layout issues inside PageView
  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: Column(
          children: [
            // Version selector
            _buildVersionSelector(),
            // Packing content
            Expanded(child: _buildPackingTab()),
          ],
        ),
      );
    },
  );
}

// Step 4: How to Get There
Widget _buildStep5LocalTips() {
  // Phase 3.2: Use new state for checks
  if (formState!.versions.isEmpty) {
    return Center(
      child: Text(
        'Add at least one version first',
        style: context.textStyles.bodyMedium,
      ),
    );
  }
  // Use LayoutBuilder to get proper constraints instead of SizedBox.expand
  // which causes layout issues inside PageView
  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: Column(
          children: [
            // Version selector
            _buildVersionSelector(),
            // Local Tips content
            Expanded(child: _buildLocalTipsTab()),
          ],
        ),
      );
    },
  );
}

Widget _buildLocalTipsTab() {
  final version = formState!.activeVersion;
  return SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Local Tips', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: version,
                builder: (context, _) {
                  final localTips = version.generatedLocalTips ?? LocalTips();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        version.generatedLocalTips != null
                            ? 'Review and edit local tips (AI-generated or manually entered)'
                            : 'Fill in local tips manually, or use "Generate Info" in Step 1',
                        style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      _buildLocalTipsSection(localTips, version),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Step 5: Days (with day tabs)
Widget _buildStep6Days() {
  // Phase 3.2: Use new state for checks
  if (formState!.versions.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Add at least one version first',
              style: context.textStyles.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Go back to the Versions step to create your first adventure version',
              style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Phase 3.2: Ensure active version index is valid (using new state)
  if (formState!.activeVersionIndex >= formState!.versions.length) {
    formState!.activeVersionIndex = 0;
  }
  
  // Use LayoutBuilder to get proper constraints instead of SizedBox.expand
  // which causes layout issues inside PageView
  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: Column(
          children: [
            // Version selector
            _buildVersionSelector(),
            // Days content
            Expanded(child: _buildDaysTab()),
          ],
        ),
      );
    },
  );
}

// Shared version selector widget
Widget _buildVersionSelector() {
  // Phase 3.2: Use new state with ListenableBuilder for reactive updates
  return ListenableBuilder(
    listenable: formState!,
    builder: (context, _) {
      final versions = formState!.versions;
      final activeIndex = formState!.activeVersionIndex.clamp(0, versions.length - 1);
      
      return Container(
        padding: AppSpacing.horizontalLg.add(AppSpacing.verticalSm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            bottom: BorderSide(color: context.colors.outline, width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, size: 20),
            const SizedBox(width: 8),
            Text('Editing', style: context.textStyles.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<int>(
                value: activeIndex,
                isExpanded: true,
                items: List.generate(
                  versions.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text('Version ${i + 1}: ${versions[i].nameCtrl.text.isEmpty ? 'Untitled' : versions[i].nameCtrl.text}'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      formState!.activeVersionIndex = v; // Triggers notifyListeners() internally
                      _dayOrderManagers.clear(); // Force re-init for new version's days
                    });
                  }
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildPackingTab() {
// Phase 5: Use new state - get version directly
final version = formState!.activeVersion;

return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 900),
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Packing List Section
Text(
'Packing List',
style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),
Text(
'Organize packing items by category',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),

// Packing categories
...version.packingCategories.asMap().entries.map((entry) {
final index = entry.key;
final category = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildPackingCategoryCard(version, index, category),
);
}),

// Add category button
OutlinedButton.icon(
onPressed: () {
// Phase 3.2: Temporarily use old state (will migrate in later phase)
setState(() {
version.packingCategories.add(PackingCategoryFormState.initial());
version.notifyListeners();
});
},
icon: const Icon(Icons.add),
label: const Text('Add Packing Category'),
style: OutlinedButton.styleFrom(
minimumSize: const Size(double.infinity, 50),
side: BorderSide(color: context.colors.primary, style: BorderStyle.solid),
),
),

const SizedBox(height: 32),

// Travel Preparation Section
Divider(),
const SizedBox(height: 16),
Text(
  'Travel Preparation',
  style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),
// Phase 3.4: Use new state - get Prepare from active version
ListenableBuilder(
listenable: version,
builder: (context, _) {
final prepare = version.generatedPrepare ?? Prepare();
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
version.generatedPrepare != null
? 'Review and edit the travel information (AI-generated or manually entered)'
: 'Fill in travel preparation information manually, or use "Generate Info" in Step 1 to auto-fill',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),
_buildPrepareSection(prepare, version),
],
);
},
),

const SizedBox(height: 32),

// How to Get There Section (relocated from Step 4)
Text(
'How to Get There',
style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),
Text(
'Add different ways to reach the starting point',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),

// Transportation options
// Phase 5: Use new state directly
...version.transportationOptions.asMap().entries.map((entry) {
final index = entry.key;
final option = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildTransportationCard(version, index, option),
);
}),

// Add option button
OutlinedButton.icon(
onPressed: () {
if (formState != null) {
setState(() {
version.transportationOptions.add(TransportationFormState.initial());
});
}
},
icon: const Icon(Icons.add),
label: const Text('Add Transportation Option'),
style: OutlinedButton.styleFrom(
minimumSize: const Size(double.infinity, 50),
side: BorderSide(color: context.colors.primary, style: BorderStyle.solid),
),
),

const SizedBox(height: 16),
Container(
padding: AppSpacing.paddingMd,
decoration: BoxDecoration(
color: Colors.blue.shade50,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.blue.shade200),
),
child: Row(
children: [
Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
const SizedBox(width: 12),
Expanded(
child: Text(
'Tip: Describe each route option (e.g., "Flying from Brussels") and select transport types that travelers can combine',
style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
),
),
],
),
),
],
),
),
),
),
);
}

// Phase 5: Updated to accept new state classes
Widget _buildPackingCategoryCard(VersionFormState version, int index, PackingCategoryFormState category) {
// Use new state classes directly - no temp objects needed
return _PackingCategoryCardWidgetNew(
key: ValueKey('packing_category_${version.tempId}_$index'),
version: version,
categoryIndex: index,
category: category,
onUpdate: () {
version.notifyListeners();
setState(() {});
},
);
}

// Phase 5: Updated to accept new state classes directly
Widget _buildTransportationCard(VersionFormState version, int index, TransportationFormState option) {
// Use new state classes directly - no temp objects needed
return Container(
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(AppRadius.md),
border: Border.all(color: context.colors.outline),
),
child: ExpansionTile(
title: Row(
children: [
// Show selected transport icons
if (option.types.isNotEmpty)
...option.types.map((type) => Padding(
padding: const EdgeInsets.only(right: 8),
child: Icon(_getTransportIcon(type), size: 20, color: context.colors.primary),
))
else
Icon(Icons.directions, size: 20, color: Colors.grey.shade400),
const SizedBox(width: 8),
Expanded(
child: Text(
option.titleCtrl.text.isEmpty ? 'Transportation Option ${index + 1}' : option.titleCtrl.text,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
),
),
IconButton(
icon: const Icon(Icons.delete_outline, size: 20),
onPressed: () {
setState(() {
version.transportationOptions.removeAt(index);
version.notifyListeners();
});
},
tooltip: 'Delete option',
),
],
),
childrenPadding: AppSpacing.paddingMd,
children: [
_buildTextField("Title", "e.g., Flying from Brussels", controller: option.titleCtrl, required: true),
const SizedBox(height: 16),
_buildTextField("Description", "Describe this route option...", maxLines: 5, controller: option.descCtrl, required: true),
const SizedBox(height: 16),

Text('Transportation Types', style: context.textStyles.titleSmall),
const SizedBox(height: 8),
Text(
'Select one or more types that can be combined',
style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600),
),
const SizedBox(height: 12),
Wrap(
spacing: 12,
runSpacing: 12,
children: TransportationType.values.map((type) {
final isSelected = option.types.contains(type);
return FilterChip(
selected: isSelected,
label: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
_getTransportIcon(type),
size: 18,
color: isSelected ? context.colors.onPrimary : context.colors.onSurface,
),
const SizedBox(width: 8),
Text(_getTransportName(type)),
],
),
onSelected: (selected) {
setState(() {
if (selected) {
option.types.add(type);
} else {
option.types.remove(type);
}
option.notifyListeners();
});
},
selectedColor: context.colors.primary,
checkmarkColor: context.colors.onPrimary,
);
}).toList(),
),
],
),
);
}

IconData _getTransportIcon(TransportationType type) {
switch (type) {
case TransportationType.car:
return Icons.directions_car;
case TransportationType.flying:
return Icons.flight;
case TransportationType.boat:
return Icons.directions_boat;
case TransportationType.foot:
return Icons.directions_walk;
case TransportationType.bike:
return Icons.directions_bike;
case TransportationType.train:
return Icons.train;
case TransportationType.bus:
return Icons.directions_bus;
case TransportationType.taxi:
return Icons.local_taxi;
}
}

String _getTransportName(TransportationType type) {
switch (type) {
case TransportationType.car:
return 'Car';
case TransportationType.flying:
return 'Flying';
case TransportationType.boat:
return 'Boat';
case TransportationType.foot:
return 'By Foot';
case TransportationType.bike:
return 'Bike';
case TransportationType.train:
return 'Train';
case TransportationType.bus:
return 'Bus';
case TransportationType.taxi:
return 'Taxi';
}
}

Widget _buildPrepareSection(Prepare prepare, VersionFormState version) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Travel Insurance
      _buildInfoCard(
          icon: Icons.shield_outlined,
          title: 'Travel Insurance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phase 3.4: Use version's controller
              _buildEditableField(
                label: 'Recommended',
                value: version.prepareInsuranceRecommendationCtrl.text,
                onChanged: (value) {
                  // Phase 3.4: Update controller
                  version.prepareInsuranceRecommendationCtrl.text = value;
                  // Sync generatedPrepare
                  _syncPrepareFromControllers(version);
                  // Update version's generatedPrepare
                  version.generatedPrepare = version.generatedPrepare ?? Prepare();
                  _savePrepareAndLocalTips();
                },
              ),
              const SizedBox(height: 8),
              // Phase 3.4: Use version's controller
              _buildEditableField(
                label: 'URL',
                value: version.prepareInsuranceUrlCtrl.text,
                onChanged: (value) {
                  version.prepareInsuranceUrlCtrl.text = value;
                  _syncPrepareFromControllers(version);
                  setState(() {
                    version.generatedPrepare = version.generatedPrepare ?? Prepare();
                  });
                  _savePrepareAndLocalTips();
                },
              ),
              const SizedBox(height: 8),
              // Phase 3.4: Use version's controller
              _buildEditableField(
                label: 'Why',
                value: version.prepareInsuranceNoteCtrl.text,
                onChanged: (value) {
                  version.prepareInsuranceNoteCtrl.text = value;
                  _syncPrepareFromControllers(version);
                  setState(() {
                    version.generatedPrepare = version.generatedPrepare ?? Prepare();
                  });
                  _savePrepareAndLocalTips();
                },
              ),
              if (version.prepareInsuranceUrlCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(prepare.travelInsurance!.url)),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Visit website',
                        style: TextStyle(color: context.colors.primary, decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

      // Visa
      _buildInfoCard(
        icon: Icons.airplane_ticket_outlined,
        title: 'Visa & Entry Requirements',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Visa',
              value: version.prepareVisaRequirementCtrl.text,
              maxLines: 3,
              onChanged: (value) {
                version.prepareVisaRequirementCtrl.text = value;
                _syncPrepareFromControllers(version);
                setState(() {
                  // version.generatedPrepare is already updated via _syncPrepareFromControllers
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Medical insurance required for visa'),
              value: prepare.visa?.medicalInsuranceRequiredForVisa ?? false,
              onChanged: (value) {
                setState(() {
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: VisaInfo(
                      requirement: prepare.visa?.requirement ?? '',
                      medicalInsuranceRequiredForVisa: value ?? false,
                      note: prepare.visa?.note,
                    ),
                    passport: prepare.passport,
                    permits: prepare.permits,
                    vaccines: prepare.vaccines,
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Note',
              value: version.prepareVisaNoteCtrl.text,
              onChanged: (value) {
                version.prepareVisaNoteCtrl.text = value;
                _syncPrepareFromControllers(version);
                setState(() {
                  // version.generatedPrepare is already updated via _syncPrepareFromControllers
                });
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Passport
      _buildInfoCard(
        icon: Icons.badge_outlined,
        title: 'Passport',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Validity',
              value: version.preparePassportValidityCtrl.text,
              onChanged: (value) {
                version.preparePassportValidityCtrl.text = value;
                _syncPrepareFromControllers(version);
                setState(() {
                  // version.generatedPrepare is already updated via _syncPrepareFromControllers
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            _buildEditableField(
              label: 'Blank pages',
              value: prepare.passport?.blankPagesRequired ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: prepare.visa,
                    passport: PassportInfo(
                      validityRequirement: prepare.passport?.validityRequirement ?? '',
                      blankPagesRequired: value,
                    ),
                    permits: prepare.permits,
                    vaccines: prepare.vaccines,
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Permits
      _buildInfoCard(
        icon: Icons.description_outlined,
        title: 'Permits',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...prepare.permits.asMap().entries.map((entry) {
              final index = entry.key;
              final permit = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < prepare.permits.length - 1 ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditableField(
                      label: 'Type',
                      value: permit.type,
                      onChanged: (value) {
                        final updatedPermits = List<Permit>.from(prepare.permits);
                        updatedPermits[index] = Permit(
                          type: value,
                          details: permit.details,
                          howToObtain: permit.howToObtain,
                          cost: permit.cost,
                        );
                        setState(() {
                          version.generatedPrepare = Prepare(
                            travelInsurance: prepare.travelInsurance,
                            visa: prepare.visa,
                            passport: prepare.passport,
                            permits: updatedPermits,
                            vaccines: prepare.vaccines,
                            climate: prepare.climate,
                          );
                        });
                        // Fix: Use unified save path instead of direct _saveAIGeneratedData call
                        _savePrepareAndLocalTips();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildEditableField(
                      label: 'Details',
                      value: permit.details,
                      maxLines: 2,
                      onChanged: (value) {
                        final updatedPermits = List<Permit>.from(prepare.permits);
                        updatedPermits[index] = Permit(
                          type: permit.type,
                          details: value,
                          howToObtain: permit.howToObtain,
                          cost: permit.cost,
                        );
                        setState(() {
                          version.generatedPrepare = Prepare(
                            travelInsurance: prepare.travelInsurance,
                            visa: prepare.visa,
                            passport: prepare.passport,
                            permits: updatedPermits,
                            vaccines: prepare.vaccines,
                            climate: prepare.climate,
                          );
                        });
                        // Fix: Use unified save path instead of direct _saveAIGeneratedData call
                        _savePrepareAndLocalTips();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildEditableField(
                      label: 'How to obtain',
                      value: permit.howToObtain,
                      maxLines: 2,
                      onChanged: (value) {
                        final updatedPermits = List<Permit>.from(prepare.permits);
                        updatedPermits[index] = Permit(
                          type: permit.type,
                          details: permit.details,
                          howToObtain: value,
                          cost: permit.cost,
                        );
                        setState(() {
                          version.generatedPrepare = Prepare(
                            travelInsurance: prepare.travelInsurance,
                            visa: prepare.visa,
                            passport: prepare.passport,
                            permits: updatedPermits,
                            vaccines: prepare.vaccines,
                            climate: prepare.climate,
                          );
                        });
                        // Fix: Use unified save path instead of direct _saveAIGeneratedData call
                        _savePrepareAndLocalTips();
                      },
                    ),
                    if (permit.cost != null && permit.cost!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Cost: ${permit.cost}',
                        style: context.textStyles.bodyMedium,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final updatedPermits = List<Permit>.from(prepare.permits);
                  updatedPermits.add(Permit(
                    type: '',
                    details: '',
                    howToObtain: '',
                    cost: null,
                  ));
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: prepare.visa,
                    passport: prepare.passport,
                    permits: updatedPermits,
                    vaccines: prepare.vaccines,
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Permit'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.primary),
              ),
            ),
          ],
        ),
      ),

      // Vaccines
      _buildInfoCard(
        icon: Icons.medical_services_outlined,
        title: 'Vaccines',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableField(
              label: 'Required (comma-separated)',
              value: (prepare.vaccines?.required ?? []).join(', '),
              onChanged: (value) {
                setState(() {
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: prepare.visa,
                    passport: prepare.passport,
                    permits: prepare.permits,
                    vaccines: VaccineInfo(
                      required: value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
                      recommended: prepare.vaccines?.recommended ?? [],
                      note: prepare.vaccines?.note,
                    ),
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              label: 'Recommended (comma-separated)',
              value: (prepare.vaccines?.recommended ?? []).join(', '),
              onChanged: (value) {
                setState(() {
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: prepare.visa,
                    passport: prepare.passport,
                    permits: prepare.permits,
                    vaccines: VaccineInfo(
                      required: prepare.vaccines?.required ?? [],
                      recommended: value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
                      note: prepare.vaccines?.note,
                    ),
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              label: 'Note',
              value: prepare.vaccines?.note ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedPrepare = Prepare(
                    travelInsurance: prepare.travelInsurance,
                    visa: prepare.visa,
                    passport: prepare.passport,
                    permits: prepare.permits,
                    vaccines: VaccineInfo(
                      required: prepare.vaccines?.required ?? [],
                      recommended: prepare.vaccines?.recommended ?? [],
                      note: value.isEmpty ? null : value,
                    ),
                    climate: prepare.climate,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Climate
      if (prepare.climate != null && prepare.climate!.data.isNotEmpty)
        _buildInfoCard(
          icon: Icons.thermostat_outlined,
          title: 'Climate Data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prepare.climate!.location,
                style: context.textStyles.titleSmall,
              ),
              const SizedBox(height: 16),
              // Simple table view of climate data
              ...prepare.climate!.data.map((month) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          month.month,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Temp: ${month.avgTempLowC.toStringAsFixed(0)}°C - ${month.avgTempHighC.toStringAsFixed(0)}°C'),
                            Text('Rain: ${month.avgRainMm.toStringAsFixed(0)}mm'),
                            Text('Days: ${month.avgDaylightHours.toStringAsFixed(1)}h'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
    ],
  );
}

// Phase 3.4: Helper to sync Prepare object from version's controllers
void _syncPrepareFromControllers(VersionFormState version) {
  // Preserve existing values for fields that don't have controllers
  final existing = version.generatedPrepare;
  final prepare = Prepare(
    travelInsurance: TravelInsurance(
      recommendation: version.prepareInsuranceRecommendationCtrl.text,
      url: version.prepareInsuranceUrlCtrl.text,
      note: version.prepareInsuranceNoteCtrl.text,
    ),
    visa: VisaInfo(
      requirement: version.prepareVisaRequirementCtrl.text,
      note: version.prepareVisaNoteCtrl.text.isEmpty ? null : version.prepareVisaNoteCtrl.text,
      // Preserve checkbox state from existing Prepare object
      medicalInsuranceRequiredForVisa: existing?.visa?.medicalInsuranceRequiredForVisa ?? false,
    ),
    passport: PassportInfo(
      validityRequirement: version.preparePassportValidityCtrl.text,
      // Preserve blankPagesRequired from existing Prepare object (not in controller)
      blankPagesRequired: existing?.passport?.blankPagesRequired ?? version.preparePassportNoteCtrl.text,
    ),
    permits: version.permits.map((p) => Permit(
      type: p.typeCtrl.text,
      details: p.detailsCtrl.text,
      howToObtain: p.howToObtainCtrl.text,
      cost: p.costCtrl?.text.isNotEmpty == true ? p.costCtrl!.text : null,
    )).toList(),
    vaccines: VaccineInfo(
      required: version.prepareVaccinesRequiredCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      recommended: version.prepareVaccinesRecommendedCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      note: version.prepareVaccinesNoteCtrl.text.isEmpty ? null : version.prepareVaccinesNoteCtrl.text,
    ),
    climate: version.prepareClimateDescriptionCtrl.text.isNotEmpty || version.prepareClimateBestTimeCtrl.text.isNotEmpty
        ? ClimateData(
            location: formState?.locationCtrl.text.trim() ?? '',
            data: [], // TODO: Get from AI generation
          )
        : null,
  );
  version.generatedPrepare = prepare;
}

// Phase 3.4: Helper to sync LocalTips object from version's controllers
void _syncLocalTipsFromControllers(VersionFormState version) {
  // Preserve existing values for fields that don't have controllers
  final existing = version.generatedLocalTips;
  final localTips = LocalTips(
    emergency: EmergencyInfo(
      // Preserve generalEmergency from existing LocalTips (not in controller)
      generalEmergency: existing?.emergency?.generalEmergency ?? '',
      police: version.localTipsEmergencyPoliceCtrl.text,
      ambulance: version.localTipsEmergencyAmbulanceCtrl.text,
      fire: version.localTipsEmergencyFireCtrl.text,
      mountainRescue: version.localTipsEmergencyTouristCtrl.text.isEmpty ? null : version.localTipsEmergencyTouristCtrl.text,
    ),
    // Preserve messagingApp from existing LocalTips (not in controller)
    messagingApp: existing?.messagingApp,
    etiquette: version.etiquetteItems.map((e) => e.tipCtrl.text).where((s) => s.isNotEmpty).toList(),
    // Preserve tipping from existing LocalTips (not in controller)
    tipping: existing?.tipping,
    // Preserve basicPhrases from existing LocalTips (not in controller)
    basicPhrases: existing?.basicPhrases ?? [],
    foodSpecialties: version.foodSpecialties.map((f) => FoodSpecialty(
      name: f.nameCtrl.text,
      description: f.descriptionCtrl.text,
    )).toList(),
    // Preserve foodWarnings from existing LocalTips (not in controller)
    foodWarnings: existing?.foodWarnings ?? [],
    // Note: language and currency are not in LocalTips model - they may be stored elsewhere or not used
  );
  version.generatedLocalTips = localTips;
}

// Phase 4: Updated to use AdventureSaveService
void _savePrepareAndLocalTips() {
  // Phase 4: Guard against null formState
  if (formState == null || formState!.editingPlan == null) return;
  
  // Phase 4: Get Prepare and LocalTips from active version
  final version = formState!.activeVersion;
  final prepare = version.generatedPrepare ?? Prepare();
  final localTips = version.generatedLocalTips ?? LocalTips();
  
  // Phase 4: Use saveService.saveAIData
  saveService.saveAIData(
    formState!.editingPlan!.id,
    version.tempId,
    prepare,
    localTips,
  ).then((result) {
    if (!result.success) {
      Log.w('builder', 'Failed to save AI data: ${result.errors.join(', ')}');
    }
  });
}

Widget _buildLocalTipsSection(LocalTips localTips, VersionFormState version) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Emergency
      _buildInfoCard(
        icon: Icons.emergency_outlined,
        title: 'Emergency Numbers',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableField(
              label: 'General Emergency',
              value: localTips.emergency?.generalEmergency ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: EmergencyInfo(
                      generalEmergency: value,
                      police: localTips.emergency?.police ?? '',
                      ambulance: localTips.emergency?.ambulance ?? '',
                      fire: localTips.emergency?.fire ?? '',
                      mountainRescue: localTips.emergency?.mountainRescue,
                    ),
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Police',
              value: version.localTipsEmergencyPoliceCtrl.text,
              onChanged: (value) {
                version.localTipsEmergencyPoliceCtrl.text = value;
                _syncLocalTipsFromControllers(version);
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Ambulance',
              value: version.localTipsEmergencyAmbulanceCtrl.text,
              onChanged: (value) {
                version.localTipsEmergencyAmbulanceCtrl.text = value;
                _syncLocalTipsFromControllers(version);
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Fire',
              value: version.localTipsEmergencyFireCtrl.text,
              onChanged: (value) {
                version.localTipsEmergencyFireCtrl.text = value;
                _syncLocalTipsFromControllers(version);
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            // Phase 3.4: Use version's controller
            _buildEditableField(
              label: 'Mountain Rescue (optional)',
              value: version.localTipsEmergencyTouristCtrl.text,
              onChanged: (value) {
                version.localTipsEmergencyTouristCtrl.text = value;
                _syncLocalTipsFromControllers(version);
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Messaging App
      _buildInfoCard(
        icon: Icons.chat_bubble_outline,
        title: 'Communication',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableField(
              label: 'Most used app',
              value: localTips.messagingApp?.name ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: MessagingApp(name: value, note: localTips.messagingApp?.note ?? ''),
                    etiquette: localTips.etiquette,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            _buildEditableField(
              label: 'Note',
              value: localTips.messagingApp?.note ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: MessagingApp(name: localTips.messagingApp?.name ?? '', note: value),
                    etiquette: localTips.etiquette,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Etiquette
      _buildInfoCard(
        icon: Icons.handshake_outlined,
        title: 'Etiquette',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...(localTips.etiquette.isEmpty 
              ? [const SizedBox.shrink()]
              : localTips.etiquette.asMap().entries.map((entry) {
              final index = entry.key;
              return Padding(
                padding: EdgeInsets.only(bottom: index < localTips.etiquette.length - 1 ? 8 : 0),
                child: _buildEditableField(
                  label: 'Tip ${index + 1}',
                  value: entry.value,
                  onChanged: (value) {
                    final updated = List<String>.from(localTips.etiquette);
                    updated[index] = value;
                    setState(() {
                      version.generatedLocalTips = LocalTips(
                        emergency: localTips.emergency,
                        messagingApp: localTips.messagingApp,
                        etiquette: updated,
                        tipping: localTips.tipping,
                        basicPhrases: localTips.basicPhrases,
                        foodSpecialties: localTips.foodSpecialties,
                        foodWarnings: localTips.foodWarnings,
                      );
                    });
                    _savePrepareAndLocalTips();
                  },
                ),
              );
            })),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final updated = List<String>.from(localTips.etiquette);
                  updated.add('');
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: updated,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Etiquette Tip'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.primary),
              ),
            ),
          ],
        ),
      ),

      // Tipping
      _buildInfoCard(
        icon: Icons.attach_money_outlined,
        title: 'Tipping',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableField(
              label: 'General',
              value: localTips.tipping?.practice ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: TippingInfo(
                      practice: value,
                      restaurant: localTips.tipping?.restaurant ?? '',
                      taxi: localTips.tipping?.taxi ?? '',
                      hotel: localTips.tipping?.hotel ?? '',
                    ),
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            _buildEditableField(
              label: 'Restaurant',
              value: localTips.tipping?.restaurant ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: TippingInfo(
                      practice: localTips.tipping?.practice ?? '',
                      restaurant: value,
                      taxi: localTips.tipping?.taxi ?? '',
                      hotel: localTips.tipping?.hotel ?? '',
                    ),
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            _buildEditableField(
              label: 'Taxi',
              value: localTips.tipping?.taxi ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: TippingInfo(
                      practice: localTips.tipping?.practice ?? '',
                      restaurant: localTips.tipping?.restaurant ?? '',
                      taxi: value,
                      hotel: localTips.tipping?.hotel ?? '',
                    ),
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
            const SizedBox(height: 8),
            _buildEditableField(
              label: 'Hotel',
              value: localTips.tipping?.hotel ?? '',
              onChanged: (value) {
                setState(() {
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: TippingInfo(
                      practice: localTips.tipping?.practice ?? '',
                      restaurant: localTips.tipping?.restaurant ?? '',
                      taxi: localTips.tipping?.taxi ?? '',
                      hotel: value,
                    ),
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
            ),
          ],
        ),
      ),

      // Basic Phrases
      _buildInfoCard(
        icon: Icons.translate_outlined,
        title: 'Basic Phrases',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localTips.basicPhrases.isEmpty)
              Text(
                'No phrases added yet. Use "Generate Info" in Step 1 to auto-fill common phrases.',
                style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600),
              )
            else
              ...localTips.basicPhrases.map((phrase) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phrase.english,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${phrase.local} (${phrase.pronunciation})',
                          style: context.textStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),

      // Food Specialties
      _buildInfoCard(
        icon: Icons.restaurant_outlined,
        title: 'Food Specialties',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localTips.foodSpecialties.isEmpty)
              Text(
                'No food specialties added yet. Use "Generate Info" in Step 1 to auto-fill local specialties.',
                style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600),
              )
            else
              ...localTips.foodSpecialties.asMap().entries.map((entry) {
                final index = entry.key;
                final food = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditableField(
                        label: 'Name',
                        value: food.name,
                        onChanged: (value) {
                          // Fix: Use index-based updates instead of name matching
                          final updated = List<FoodSpecialty>.from(localTips.foodSpecialties);
                          updated[index] = FoodSpecialty(name: value, description: food.description);
                          setState(() {
                            version.generatedLocalTips = LocalTips(
                              emergency: localTips.emergency,
                              messagingApp: localTips.messagingApp,
                              etiquette: localTips.etiquette,
                              tipping: localTips.tipping,
                              basicPhrases: localTips.basicPhrases,
                              foodSpecialties: updated,
                              foodWarnings: localTips.foodWarnings,
                            );
                          });
                          _savePrepareAndLocalTips();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildEditableField(
                        label: 'Description',
                        value: food.description,
                        onChanged: (value) {
                          // Fix: Use index-based updates instead of name matching
                          final updated = List<FoodSpecialty>.from(localTips.foodSpecialties);
                          updated[index] = FoodSpecialty(name: food.name, description: value);
                          setState(() {
                            version.generatedLocalTips = LocalTips(
                              emergency: localTips.emergency,
                              messagingApp: localTips.messagingApp,
                              etiquette: localTips.etiquette,
                              tipping: localTips.tipping,
                              basicPhrases: localTips.basicPhrases,
                              foodSpecialties: updated,
                              foodWarnings: localTips.foodWarnings,
                            );
                          });
                          _savePrepareAndLocalTips();
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final updated = List<FoodSpecialty>.from(localTips.foodSpecialties);
                  updated.add(FoodSpecialty(name: '', description: ''));
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: updated,
                    foodWarnings: localTips.foodWarnings,
                  );
                });
                _savePrepareAndLocalTips();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Food Specialty'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.primary),
              ),
            ),
          ],
        ),
      ),

      // Food Warnings
      _buildInfoCard(
        icon: Icons.warning_amber_outlined,
        title: 'Food Warnings',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...(localTips.foodWarnings.isEmpty
              ? [
                  Text(
                    'No warnings added yet. Use "Generate Info" in Step 1 to auto-fill food safety information.',
                    style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ]
              : localTips.foodWarnings.asMap().entries.map((entry) {
              final index = entry.key;
              return Padding(
                padding: EdgeInsets.only(bottom: index < localTips.foodWarnings.length - 1 ? 8 : 0),
                child: _buildEditableField(
                  label: 'Warning ${index + 1}',
                  value: entry.value,
                  onChanged: (value) {
                    final updated = List<String>.from(localTips.foodWarnings);
                    updated[index] = value;
                    setState(() {
                      version.generatedLocalTips = LocalTips(
                        emergency: localTips.emergency,
                        messagingApp: localTips.messagingApp,
                        etiquette: localTips.etiquette,
                        tipping: localTips.tipping,
                        basicPhrases: localTips.basicPhrases,
                        foodSpecialties: localTips.foodSpecialties,
                        foodWarnings: updated,
                      );
                    });
                    _savePrepareAndLocalTips();
                  },
                ),
              );
            })),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final updated = List<String>.from(localTips.foodWarnings);
                  updated.add('');
                  version.generatedLocalTips = LocalTips(
                    emergency: localTips.emergency,
                    messagingApp: localTips.messagingApp,
                    etiquette: localTips.etiquette,
                    tipping: localTips.tipping,
                    basicPhrases: localTips.basicPhrases,
                    foodSpecialties: localTips.foodSpecialties,
                    foodWarnings: updated,
                  );
                });
                _savePrepareAndLocalTips();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Food Warning'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.primary),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoCard({required IconData icon, required String title, required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
    ),
    child: ExpansionTile(
      leading: Icon(icon, color: context.colors.primary),
      title: Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      childrenPadding: AppSpacing.paddingMd,
      children: [child],
    ),
  );
}

Widget _buildEditableField({
  String? label,
  required String value,
  int maxLines = 1,
  required Function(String) onChanged,
  TextEditingController? controller,
}) {
  // Use controller if provided to avoid cursor loss on keystroke
  // Otherwise use initialValue (for fields not yet backed by controllers)
  if (controller != null) {
    // Sync controller value if it differs from current value
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: context.textStyles.bodyMedium,
    );
  } else {
    // For fields without controllers, use initialValue with a stable key
    // Use label as key instead of value to avoid remounting on every keystroke
    return TextFormField(
      key: ValueKey('${label}_field'),
      initialValue: value,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: context.textStyles.bodyMedium,
    );
  }
}

Widget _buildFAQCard(AdventureFormState formState, int index, FAQFormState faq) {
return Container(
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(AppRadius.md),
border: Border.all(color: context.colors.outline),
),
child: ExpansionTile(
title: Row(
children: [
Icon(Icons.help_outline, size: 20, color: context.colors.primary),
const SizedBox(width: 12),
Expanded(
child: Text(
faq.questionCtrl.text.isEmpty ? 'FAQ ${index + 1}' : faq.questionCtrl.text,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
IconButton(
icon: const Icon(Icons.delete_outline, size: 20),
onPressed: () {
if (formState != null) {
setState(() {
formState.faqItems.removeAt(index);
});
}
},
tooltip: 'Delete FAQ',
),
],
),
childrenPadding: AppSpacing.paddingMd,
children: [
_buildTextField("Question", "What do you want to ask?", controller: faq.questionCtrl, required: true),
const SizedBox(height: 16),
_buildTextField("Answer", "Provide a helpful answer...", maxLines: 5, controller: faq.answerCtrl, required: true),
],
),
);
}

Widget _buildGeneralInfoFAQSection() {
if (formState?.versions.isEmpty ?? true) {
return Container(
padding: AppSpacing.paddingMd,
decoration: BoxDecoration(
color: Colors.orange.shade50,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.orange.shade200),
),
child: Row(
children: [
Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
const SizedBox(width: 12),
Expanded(
child: Text(
'Add at least one version first to manage FAQs',
style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
),
),
],
),
);
}

// Use formState FAQ items (plan-level)
if (formState == null) return const SizedBox.shrink();

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// FAQ items
...formState!.faqItems.asMap().entries.map((entry) {
final index = entry.key;
final faq = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildFAQCard(formState!, index, faq),
);
}),

// Add FAQ button
OutlinedButton.icon(
onPressed: () {
if (formState != null) {
setState(() {
formState!.faqItems.add(FAQFormState.initial());
});
}
},
icon: const Icon(Icons.add),
label: const Text('Add FAQ'),
style: OutlinedButton.styleFrom(
minimumSize: const Size(double.infinity, 50),
side: BorderSide(color: context.colors.primary, style: BorderStyle.solid),
),
),

const SizedBox(height: 16),
Container(
padding: AppSpacing.paddingMd,
decoration: BoxDecoration(
color: Colors.blue.shade50,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.blue.shade200),
),
child: Row(
children: [
Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
const SizedBox(width: 12),
Expanded(
child: Text(
'Tip: Use **bold**, *italic*, and press Enter for new paragraphs in answers',
style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
),
),
],
),
),
],
);
}

Widget _buildGenerateInfoButton() {
  // AI generation removed - return empty widget
  return const SizedBox.shrink();
}

// Phase 5: _saveAIGeneratedData removed - now using saveService.saveAIData

Widget _buildDaysTab() {
  // Phase 3.2: Use new state
  final version = formState!.activeVersion;
  final dayCount = version.daysCount.clamp(0, 60);
  
  // Ensure current day index is within bounds
  if (_currentDayIndex >= dayCount && dayCount > 0) {
    _currentDayIndex = dayCount - 1;
  }
  
  if (dayCount == 0) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No days added yet',
            style: context.textStyles.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least one day to start building your itinerary',
            style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Phase 3.2: Use new state
              final current = int.tryParse(version.durationCtrl.text) ?? 0;
              version.durationCtrl.text = (current + 1).toString();
              setState(() => _currentDayIndex = 0);
            },
            icon: const Icon(Icons.add),
            label: const Text("Add First Day"),
          ),
        ],
      ),
    );
  }

  return Column(
    children: [
      // Day Tabs Navigation
      Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            bottom: BorderSide(color: context.colors.outline, width: 1),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ...List.generate(dayCount, (index) {
                final isActive = _currentDayIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _currentDayIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? context.colors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      color: isActive 
                          ? context.colors.primary.withValues(alpha: 0.05) 
                          : Colors.transparent,
                    ),
                    child: Text(
                      'Day ${index + 1}',
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isActive 
                            ? context.colors.primary 
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
              // Add Day button
              GestureDetector(
                onTap: () {
                  // Phase 3.2: Use new state
                  final current = int.tryParse(version.durationCtrl.text) ?? 0;
                  version.durationCtrl.text = (current + 1).toString();
                  setState(() => _currentDayIndex = current);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 18, color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Add Day',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
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
      // Day Content
      Expanded(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 900,
              ),
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Builder(
                  builder: (context) {
                    try {
                      Log.i('builder', 'Rendering day content for index $_currentDayIndex');
                      return _buildDayCard(_currentDayIndex + 1, versionIndex: formState!.activeVersionIndex);
                    } catch (e, stack) {
                      Log.e('builder', 'Error building day card ${_currentDayIndex + 1}', e, stack);
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading Day ${_currentDayIndex + 1}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade900,
                              ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  e.toString(),
                                  style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
    ],
  );
}

Widget _buildDayCard(int dayNum, {required int versionIndex}) {
Log.i('builder', 'Building day card for day $dayNum, version $versionIndex');

// Phase 5: Use new state
if (formState == null) return const SizedBox.shrink();
final version = formState!.versions[versionIndex];
final dayState = version.getDayState(dayNum);

try {
final titleCtrl = dayState.titleCtrl;
final descCtrl = dayState.descCtrl;
final distCtrl = dayState.distanceCtrl;
final timeCtrl = dayState.timeCtrl;
final stayUrlCtrl = dayState.stayUrlCtrl;
final stayCostCtrl = dayState.stayCostCtrl;
final meta = dayState.stayMeta;
final existingRoute = dayState.route;
// Legacy form data removed - data is now managed via waypoints
final dayImageBytes = dayState.newImageBytes.isNotEmpty ? dayState.newImageBytes.first : null;
final existingImageUrl = dayState.existingImageUrls.isNotEmpty ? dayState.existingImageUrls.first : null;
final hasImage = dayImageBytes != null || existingImageUrl != null;

Log.i('builder', 'Day $dayNum: hasRoute=${existingRoute != null}, waypoints=${existingRoute?.poiWaypoints.length ?? 0}');

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Day Image at the top
GestureDetector(
onTap: () => _pickDayImage(dayNum),
child: Container(
height: 200,
decoration: BoxDecoration(
color: hasImage ? Colors.black : Colors.grey.shade100,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: context.colors.outlineVariant),
image: dayImageBytes != null
? DecorationImage(
image: MemoryImage(dayImageBytes),
fit: BoxFit.cover,
)
: (existingImageUrl != null
? DecorationImage(
image: NetworkImage(existingImageUrl),
fit: BoxFit.cover,
)
: null),
),
child: !hasImage
? Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade600),
const SizedBox(height: 8),
Text("Add Day Image", style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
],
),
)
: Stack(
children: [
Positioned(
top: 8,
right: 8,
child: CircleAvatar(
radius: 18,
backgroundColor: Colors.black54,
child: IconButton(
padding: EdgeInsets.zero,
icon: const Icon(Icons.close, color: Colors.white, size: 20),
onPressed: () => setState(() {
dayState.newImageBytes = [];
dayState.newImageExtensions = [];
dayState.existingImageUrls = [];
}),
),
),
),
],
),
),
),
const SizedBox(height: 24),

// Day Header
Text(
"Day $dayNum",
style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
),
const SizedBox(height: 16),
_buildTextField("Title", "e.g., Crossing the Pass", controller: titleCtrl, required: false),
const SizedBox(height: 12),
_buildTextField("Description", "What happens today...", maxLines: 5, controller: descCtrl, required: false),
const SizedBox(height: 12),
// Route Info Section (activity-type dependent)
RouteInfoSection(
  activityCategory: formState!.activityCategory,
  route: existingRoute,
  routeInfo: dayState.routeInfo,
  komootLinkController: dayState.komootLinkCtrl,
  allTrailsLinkController: dayState.allTrailsLinkCtrl,
  gpxRoute: dayState.gpxRoute,
  onRouteInfoChanged: (routeInfo) {
    // Defer setState to after build phase to avoid "setState during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        dayState.routeInfo = routeInfo;
      });
      _saveCurrentStep();
    });
  },
  onGpxRouteChanged: (gpxRoute) {
    // Defer setState to after build phase to avoid "setState during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        dayState.gpxRoute = gpxRoute;
        
        // Create DayRoute from GPX data so the map can render it
        if (gpxRoute != null) {
          final gpxPoints = gpxRoute.simplifiedPoints; // Use simplified points for rendering
          
          // Create GeoJSON LineString geometry (coordinates are [lng, lat] in GeoJSON)
          final geometry = {
            'type': 'LineString',
            'coordinates': gpxPoints
                .map((p) => [p.longitude, p.latitude]) // GeoJSON format: [lng, lat]
                .toList(),
          };
          
          // Calculate duration from activity type if GPX doesn't have it
          int durationSeconds = gpxRoute.estimatedDuration?.inSeconds ?? 0;
          if (durationSeconds == 0 && formState!.activityCategory != null) {
            final snapper = GpxWaypointSnapper();
            final estimatedDuration = snapper.estimateTravelTime(
              gpxRoute.totalDistanceKm,
              formState!.activityCategory!,
              gpxRoute.totalElevationGainM,
            );
            durationSeconds = estimatedDuration.inSeconds;
          }
          
          // Create DayRoute from GPX data
          // For GPX routes, routePoints should be EMPTY - the geometry contains the trail
          // Only poiWaypoints (actual POIs) should be included
          // Filter out route points from existing waypoints (they're in geometry now, not waypoints)
          final existingWaypoints = existingRoute?.poiWaypoints
              .map((json) => RouteWaypoint.fromJson(json))
              .where((w) => w.type != WaypointType.routePoint) // Remove route points for GPX routes
              .map((w) => w.toJson())
              .toList() ?? [];
          
          final dayRoute = DayRoute(
            geometry: geometry,
            distance: (gpxRoute.totalDistanceKm * 1000).roundToDouble(), // Convert km to meters
            duration: durationSeconds,
            routePoints: const [], // EMPTY - GPX geometry is the trail, not waypoints
            ascent: gpxRoute.totalElevationGainM,
            descent: null, // GPX doesn't typically provide descent separately
            routeType: RouteType.gpx,
            poiWaypoints: existingWaypoints, // Only actual POIs, no route points
          );
          
          // Set the route so the map can render it
          dayState.route = dayRoute;
          
          // Update distance and time fields in the form
          final distCtrl = dayState.distanceCtrl;
          final timeCtrl = dayState.timeCtrl;
          distCtrl.text = gpxRoute.totalDistanceKm.toStringAsFixed(2);
          final hours = durationSeconds / 3600.0;
          timeCtrl.text = hours.toStringAsFixed(1);
          
          Log.i('builder', '✅ Created DayRoute from GPX: ${gpxRoute.totalDistanceKm.toStringAsFixed(2)} km, ${gpxPoints.length} points, ${durationSeconds}s duration');
          
          // For supported activities (hike/ski/biking/climbing), skip waypoint snapping
          // Waypoints are just POIs along the route, not route segments
          final supportsGpx = formState!.activityCategory == ActivityCategory.hiking ||
                             formState!.activityCategory == ActivityCategory.skis ||
                             formState!.activityCategory == ActivityCategory.cycling ||
                             formState!.activityCategory == ActivityCategory.climbing;
          
          if (!supportsGpx && dayRoute.poiWaypoints.isNotEmpty) {
            // Only snap waypoints for non-supported activities (legacy behavior)
            _snapWaypointsToGpxRoute(dayNum, gpxRoute, dayRoute, version);
          }
        } else {
          // GPX route removed - clear all GPX-related data
          // Remove snap info from waypoints
          if (existingRoute != null) {
            _removeWaypointSnapInfo(dayNum, existingRoute, version);
            
            // Clear the route if it was GPX-sourced (removes geometry/trail from map)
            if (existingRoute.routeType == RouteType.gpx) {
              dayState.route = null;
            }
          }
          
          // Clear route info (distance, elevation, duration) from database
          dayState.routeInfo = null;
          
          // Clear form fields (distance, elevation, duration)
          final distCtrl = dayState.distanceCtrl;
          final timeCtrl = dayState.timeCtrl;
          distCtrl.clear();
          timeCtrl.clear();
          
          // Clear elevation if the controller exists
          // Note: elevation controller might not exist for all activity types
          // The RouteInfoSection will handle clearing its own elevation field
          
          Log.i('builder', '✅ Removed GPX route: cleared route, routeInfo, and form fields for day $dayNum');
        }
      });
      _saveCurrentStep();
    });
  },
),
const SizedBox(height: 16),

// MAP SECTION - Always show map preview (shows route/waypoints if available, otherwise shows location from step 1)
if (formState!.locationSearch.selectedLocation != null) ...[
_buildDayRouteMap(existingRoute, dayNum, version),
const SizedBox(height: 12),
],

// Route controls below the map
Align(
alignment: Alignment.centerLeft,
child: FilledButton.icon(
onPressed: () async {
Log.i('builder', 'Opening RouteBuilderScreen for day $dayNum');
try {
final planId = formState!.editingPlan?.id ?? 'new';
final route = await context.push<DayRoute>(
'/builder/route-builder/$planId/${formState!.activeVersionIndex}/$dayNum',
extra: {
'start': dayState.start,
'end': dayState.end,
'initial': dayState.route,
'activityCategory': formState!.activityCategory,
'location': formState!.locationSearch.selectedLocation != null 
    ? ll.LatLng(formState!.locationSearch.selectedLocation!.latitude, formState!.locationSearch.selectedLocation!.longitude) 
    : null,
},
);
if (route != null && mounted) {
setState(() {
dayState.route = route;
});
final km = (route.distance / 1000.0);
dayState.distanceCtrl.text = km.toStringAsFixed(2);
final hours = route.duration / 3600.0;
dayState.timeCtrl.text = hours.toStringAsFixed(1);
// Trigger auto-save to persist the route changes including waypoint ordering
_saveCurrentStep();
}
} catch (e, stack) {
Log.e('builder', 'RouteBuilderScreen failed', e, stack);
}
},
icon: const Icon(Icons.alt_route),
label: Text(existingRoute == null ? 'Create Route' : 'Edit Route'),
),
),

// WAYPOINTS SECTION - All types combined in one ordered list
const SizedBox(height: 24),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text("Waypoints", style: context.textStyles.titleMedium),
IconButton(
icon: const Icon(Icons.add_circle),
tooltip: 'Add Waypoint',
onPressed: () => _pushAddWaypointPage(dayNum, version),
),
],
),
const SizedBox(height: 8),
_buildAllWaypointsList(dayNum, version),
],
);
} catch (e, stack) {
Log.e('builder', 'Error building day card for day $dayNum', e, stack);
return Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
color: Colors.red.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.red.shade200),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
const SizedBox(height: 16),
Text(
'Error loading Day $dayNum',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w600,
color: Colors.red.shade900,
),
),
const SizedBox(height: 8),
Text(
'Details: $e',
style: TextStyle(
fontSize: 12,
color: Colors.red.shade700,
),
textAlign: TextAlign.center,
),
],
),
);
}
}

/// Helper to filter out waypoint connections (2-3 points = direct lines)
/// Only filters for GPX-required activities to avoid false positives on short legitimate routes
bool _isWaypointConnection(List<ll.LatLng> points, ActivityCategory? activityCategory) {
  // Waypoint connections have 2-3 points, GPX trails have 50+ points
  // Only filter for GPX-required activities to avoid false positives
  if (!requiresGpxRoute(activityCategory)) {
    return false; // Don't filter for city trips/tours
  }
  return points.length >= 2 && points.length <= 3;
}

// Helper functions moved to lib/utils/activity_utils.dart

/// Build a map widget showing the day's route and waypoints
/// Uses AdaptiveMapWidget with Google Maps for preview map
Widget _buildDayRouteMap(DayRoute? route, int dayNum, VersionFormState version) {
  // Parse route coordinates
  List<ll.LatLng> routeCoordinates = [];
  if (route?.geometry != null) {
    try {
      final coords = route!.geometry['coordinates'];
      if (coords is List && coords.isNotEmpty) {
        if (coords.first is List) {
          // Format: [[lng, lat], ...]
          routeCoordinates = coords
              .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
        } else if (coords.first is Map) {
          // Format: [{lng: ..., lat: ...}, ...]
          routeCoordinates = coords
              .map((c) => ll.LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble()))
              .toList();
        }
      }
    } catch (e) {
      Log.e('builder', 'Failed to parse route coordinates: $e');
    }
  }

  // Extract and convert waypoints from Map<String, dynamic> to RouteWaypoint
  final waypointMaps = route?.poiWaypoints ?? [];
  final waypoints = waypointMaps
      .map((w) {
        try {
          return RouteWaypoint.fromJson(w);
        } catch (e) {
          Log.e('builder', 'Failed to parse waypoint: $e');
          return null;
        }
      })
      .whereType<RouteWaypoint>()
      .toList();
  
  // Calculate center point (from waypoints or route)
  ll.LatLng center;
  if (waypoints.isNotEmpty) {
    final avgLat = waypoints.map((w) => w.position.latitude).reduce((a, b) => a + b) / waypoints.length;
    final avgLng = waypoints.map((w) => w.position.longitude).reduce((a, b) => a + b) / waypoints.length;
    center = ll.LatLng(avgLat, avgLng);
  } else if (routeCoordinates.isNotEmpty) {
    final avgLat = routeCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / routeCoordinates.length;
    final avgLng = routeCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / routeCoordinates.length;
    center = ll.LatLng(avgLat, avgLng);
    } else {
      // Fallback to location from step 1 (General Info)
      final selectedLocation = formState!.locationSearch.selectedLocation;
      if (selectedLocation != null) {
        center = ll.LatLng(selectedLocation.latitude, selectedLocation.longitude);
      } else {
        // Fallback to start location or default
        final dayState = version.getDayState(dayNum);
        final startLocation = dayState.start;
        center = startLocation ?? const ll.LatLng(61.0, 8.5); // Norway default
      }
    }

  // Create annotations for waypoints
  // For GPX routes, filter out route points (they're in geometry, not waypoints)
  final isGpxRoute = route?.routeType == RouteType.gpx;
  final filteredWaypoints = isGpxRoute
      ? waypoints.where((wp) => wp.type != WaypointType.routePoint).toList()
      : waypoints;
  final annotations = filteredWaypoints.map((wp) => MapAnnotation.fromWaypoint(wp)).toList();

  // Create polyline for route
  final polylines = <MapPolyline>[];
  
  // For GPX routes, only show the GPX route geometry (the trail), not connections between waypoints
  if (isGpxRoute) {
    final supportsGpx = supportsGpxRoute(formState!.activityCategory);
    
    // For GPX routes with supported activities, ONLY show the GPX trail (no waypoint connections)
    // Use the GPX route directly from gpxRouteByDay to guarantee we're using the original trail,
    // not a contaminated route.geometry that might contain waypoint connections
    if (supportsGpx) {
      final dayState = version.getDayState(dayNum);
      final gpxRoute = dayState.gpxRoute;
      if (gpxRoute != null && gpxRoute.simplifiedPoints.isNotEmpty) {
        // Use the GPX route's simplified points directly - this is the original trail
        // Convert to LatLng format for the map
        final gpxTrailPoints = gpxRoute.simplifiedPoints
            .map((p) => ll.LatLng(p.latitude, p.longitude))
            .toList();
        
        polylines.add(MapPolyline(
          id: 'route_$dayNum',
          points: gpxTrailPoints,
          color: const Color(0xFF4CAF50),
          width: 4.0,
        ));
        
        Log.i('builder', '✅ Showing GPX trail from gpxRouteByDay: ${gpxTrailPoints.length} points');
      } else {
        // GPX route not available - don't show anything to prevent contaminated geometry
        Log.w('builder', '⚠️ GPX route not available in gpxRouteByDay - not showing route (prevents contaminated geometry)');
        // Don't show anything - better to show no route than contaminated waypoint connections
      }
      // No waypoint connections, no snap lines - just the trail
    } else {
      // Legacy behavior for non-supported activities
      if (routeCoordinates.isNotEmpty) {
        polylines.add(MapPolyline(
          id: 'route_$dayNum',
          points: routeCoordinates,
          color: const Color(0xFF4CAF50),
          width: 4.0,
        ));
      }
      
      // Add green lines from waypoints to their snap points (if off-trail) for legacy behavior
      final dayState = version.getDayState(dayNum);
      final gpxRoute = dayState.gpxRoute;
      if (gpxRoute != null) {
        for (final wp in filteredWaypoints) {
          if (wp.waypointSnapInfo != null && wp.waypointSnapInfo!.distanceFromRouteM > 0) {
            // Waypoint is off-trail - draw green line from original position to snap point
            polylines.add(MapPolyline(
              id: 'snap_${wp.id}_$dayNum',
              points: [
                wp.waypointSnapInfo!.originalPosition, // Use original position
                wp.waypointSnapInfo!.snapPoint,
              ],
              color: const Color(0xFF4CAF50), // Green
              width: 2.0,
              isDashed: true,
              dashPattern: [5, 5],
            ));
          }
        }
      }
    }
  } else {
    // Non-GPX routes: show route geometry if available
    if (routeCoordinates.isNotEmpty) {
      polylines.add(MapPolyline(
        id: 'route_$dayNum',
        points: routeCoordinates,
        color: const Color(0xFF4CAF50),
        width: 4.0,
      ));
    }
  }
  
  // CRITICAL: Filter out any polylines that look like waypoint connections
  // This is a defensive measure to catch any contaminated geometry
  // Only filter for GPX-required activities (hiking/cycling/skiing/climbing)
  final requiresGpx = requiresGpxRoute(formState!.activityCategory);
  final filteredPolylines = polylines.where((polyline) {
    final isConnection = _isWaypointConnection(polyline.points, formState!.activityCategory);
    if (isConnection) {
      Log.w('builder', '⚠️ Filtered out waypoint connection polyline: ${polyline.id} (${polyline.points.length} points)');
      return false; // Remove this polyline
    }
    return true; // Keep this polyline
  }).toList();
  
  // Only log if filtering actually removed something (reduce noise)
  if (filteredPolylines.length < polylines.length) {
    Log.i('builder', '📊 Polylines after filtering: ${filteredPolylines.length} (removed ${polylines.length - filteredPolylines.length} waypoint connections)');
  }

  // Use Google Maps configuration for preview
  final mapConfig = MapConfiguration.mainMap(
    enable3DTerrain: false, // Flat for preview
    initialZoom: 12.0,
  );

  return SizedBox(
    height: 300,
    child: AdaptiveMapWidget(
      initialCenter: center,
      configuration: mapConfig,
      annotations: annotations,
      polylines: filteredPolylines,
      onMapCreated: (controller) {
        // Fit bounds to show all waypoints and route, or location from step 1
        final allPoints = <ll.LatLng>[];
        allPoints.addAll(waypoints.map((w) => w.position));
        allPoints.addAll(routeCoordinates);
        
        // If no waypoints or route, add location from step 1
        final selectedLocation = formState!.locationSearch.selectedLocation;
        if (allPoints.isEmpty && selectedLocation != null) {
          allPoints.add(ll.LatLng(selectedLocation.latitude, selectedLocation.longitude));
        }
        
        if (allPoints.isNotEmpty) {
          // Calculate bounds
          final lats = allPoints.map((p) => p.latitude).toList();
          final lngs = allPoints.map((p) => p.longitude).toList();
          final minLat = lats.reduce((a, b) => a < b ? a : b);
          final maxLat = lats.reduce((a, b) => a > b ? a : b);
          final minLng = lngs.reduce((a, b) => a < b ? a : b);
          final maxLng = lngs.reduce((a, b) => a > b ? a : b);
          
          // Calculate center and zoom
          final boundsCenter = ll.LatLng(
            (minLat + maxLat) / 2,
            (minLng + maxLng) / 2,
          );
          
          // Estimate zoom level based on bounds
          final latDiff = maxLat - minLat;
          final lngDiff = maxLng - minLng;
          final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
          double zoom = 12.0;
          if (maxDiff > 0) {
            if (maxDiff > 0.5) zoom = 8.0;
            else if (maxDiff > 0.2) zoom = 10.0;
            else if (maxDiff > 0.1) zoom = 11.0;
            else if (maxDiff > 0.05) zoom = 12.0;
            else zoom = 13.0;
          }
          
          // Animate to fit bounds
          controller.animateCamera(boundsCenter, zoom);
        }
      },
    ),
  );
}

Widget _buildActivityCategoryField() {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text("Activity Type", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(4),
),
child: Text(
'Optional',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w600,
color: Colors.grey.shade600,
),
),
),
],
),
const SizedBox(height: 6),
DropdownButtonFormField<ActivityCategory?>(
value: formState?.activityCategory,
decoration: InputDecoration(
hintText: 'Select activity type...',
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.all(16),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFF428A13), width: 1.5),
),
),
items: [
const DropdownMenuItem<ActivityCategory?>(
value: null,
child: Text('Not specified'),
),
DropdownMenuItem(value: ActivityCategory.hiking, child: const Text('🥾 Hiking')),
DropdownMenuItem(value: ActivityCategory.cycling, child: const Text('🚴 Cycling')),
DropdownMenuItem(value: ActivityCategory.roadTripping, child: const Text('🚗 Road Tripping')),
DropdownMenuItem(value: ActivityCategory.skis, child: const Text('⛷️ Skiing')),
DropdownMenuItem(value: ActivityCategory.climbing, child: const Text('🧗 Climbing')),
DropdownMenuItem(value: ActivityCategory.cityTrips, child: const Text('🏙️ City Trips')),
DropdownMenuItem(value: ActivityCategory.tours, child: const Text('🌏 Tours')),
],
onChanged: (value) {
// Defer setState to avoid calling it during build phase
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted && formState != null) {
    setState(() {
      formState!.activityCategory = value;
      // Auto-set accommodation type for city trips, tours, and road tripping
      if (value == ActivityCategory.cityTrips || value == ActivityCategory.tours || value == ActivityCategory.roadTripping) {
        formState!.accommodationType = AccommodationType.comfort;
      }
      // Clear accommodation type when category is cleared
      if (value == null) {
        formState!.accommodationType = null;
      }
    });
    // Save the change
    _saveCurrentStep();
  }
});
},
),
],
);
}

Widget _buildAccommodationTypeField() {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text("Accommodation Type", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(4),
),
child: Text(
'Optional',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w600,
color: Colors.grey.shade600,
),
),
),
],
),
const SizedBox(height: 6),
DropdownButtonFormField<AccommodationType?>(
value: formState?.accommodationType,
isExpanded: true,
decoration: InputDecoration(
hintText: 'Select accommodation type...',
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.all(16),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFF428A13), width: 1.5),
),
),
items: [
const DropdownMenuItem<AccommodationType?>(
value: null,
child: Text('Not specified'),
),
DropdownMenuItem(
  value: AccommodationType.comfort,
  child: Text(
    '💰 Comfort - Hotels, hostels, huts, lodges',
    overflow: TextOverflow.ellipsis,
  ),
),
DropdownMenuItem(
  value: AccommodationType.adventure,
  child: Text(
    '⛺ Adventure - Tent, campervan, bivouac',
    overflow: TextOverflow.ellipsis,
  ),
),
],
onChanged: (value) {
if (formState != null) {
  setState(() {
    formState!.accommodationType = value;
  });
}
},
),
const SizedBox(height: 8),
Text(
'This determines how travelers stay during the adventure',
style: context.textStyles.bodySmall?.copyWith(color: Colors.grey.shade700),
),
],
);
}

Widget _buildTextField(String label, String hint, {int maxLines = 1, bool isNumber = false, TextEditingController? controller, FocusNode? focusNode, bool required = false}) {
final isMultiLine = maxLines > 1;
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: required ? Colors.red.shade50 : Colors.grey.shade200,
borderRadius: BorderRadius.circular(4),
),
child: Text(
required ? 'Required' : 'Optional',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.w600,
color: required ? Colors.red.shade700 : Colors.grey.shade600,
),
),
),
],
),
const SizedBox(height: 6),
TextField(
controller: controller,
focusNode: focusNode,
maxLines: maxLines,
keyboardType: isNumber ? TextInputType.number : (isMultiLine ? TextInputType.multiline : TextInputType.text),
decoration: InputDecoration(
hintText: hint,
hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.all(16),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5EBE5), width: 1.5),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFF428A13), width: 1.5),
),
),
),
if (isMultiLine && !isNumber) ...[
const SizedBox(height: 4),
Text(
'Tip: Use **bold**, *italic*, and press Enter for new paragraphs',
style: TextStyle(
fontSize: 11,
color: Colors.grey.shade600,
fontStyle: FontStyle.italic,
),
),
],
],
);
}

Future<List<DayItinerary>> _composeDays(VersionFormState version, String planId, {List<DayItinerary> existing = const []}) async {
final duration = version.daysCount;
final byNum = {for (final d in existing) d.dayNum: d};
final days = <DayItinerary>[];
for (int i = 1; i <= duration; i++) {
final prev = byNum[i];
final dayState = version.getDayState(i);
final start = dayState.start;
final end = dayState.end;

// Upload day image if new bytes are available, otherwise use existing URL
final imageBytes = dayState.newImageBytes.isNotEmpty ? dayState.newImageBytes.first : null;
final existingUrl = dayState.existingImageUrls.isNotEmpty ? dayState.existingImageUrls.first : null;
String? dayImageUrl;

if (imageBytes != null) {
// New image selected, upload it
try {
Log.i('builder', 'Uploading image for day $i...');
final extension = dayState.newImageExtensions.isNotEmpty ? dayState.newImageExtensions.first : 'jpg';
final path = _storageService.dayImagePath(planId, i, extension);
dayImageUrl = await _storageService.uploadImage(
path: path,
bytes: imageBytes,
contentType: 'image/$extension',
);
Log.i('builder', 'Day $i image uploaded successfully');
} catch (e, stack) {
Log.e('builder', 'Failed to upload day $i image', e, stack);
// Fallback to existing URL if upload fails
dayImageUrl = existingUrl;
}
} else {
// No new image, use existing URL if available
dayImageUrl = existingUrl;
}

// Build stay info from form maps (legacy)
final link = dayState.stayUrlCtrl.text.trim();
final cost = double.tryParse(dayState.stayCostCtrl.text.replaceAll(',', '.'));
final meta = dayState.stayMeta;
final stay = (link.isNotEmpty || cost != null || meta != null)
? StayInfo(
name: meta?.title ?? 'Accommodation',
type: 'Lodge',
bookingLink: link.isEmpty ? null : link,
cost: cost,
linkTitle: meta?.title,
linkDescription: meta?.description,
linkImageUrl: meta?.imageUrl,
linkSiteName: meta?.siteName,
)
: prev?.stay;

// Legacy form data removed - accommodations/restaurants/activities are now managed via waypoints
// Extract from waypoints if needed, otherwise use empty lists
final route = dayState.route;
final waypoints = route?.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)).toList() ?? [];
final accommodations = <AccommodationInfo>[];
final restaurants = <RestaurantInfo>[];
final activities = <ActivityInfo>[];

// Note: In the future, these could be extracted from waypoints if needed for backward compatibility
// For now, we save empty lists since the waypoint system is the primary way to manage POIs

days.add(DayItinerary(
dayNum: i,
title: dayState.titleCtrl.text.trim().isEmpty ? (prev?.title ?? 'Day $i') : dayState.titleCtrl.text.trim(),
description: dayState.descCtrl.text.trim().isEmpty ? (prev?.description ?? '') : dayState.descCtrl.text.trim(),
distanceKm: double.tryParse(dayState.distanceCtrl.text.replaceAll(',', '.')) ?? (prev?.distanceKm ?? 0),
estimatedTimeMinutes: ((double.tryParse(dayState.timeCtrl.text.replaceAll(',', '.')) ?? (prev?.estimatedTimeMinutes ?? 0).toDouble()) * 60).toInt(),
stay: stay,
accommodations: accommodations,
restaurants: restaurants,
activities: activities,
photos: dayImageUrl != null ? [dayImageUrl] : (prev?.photos ?? const []),
startLat: start?.latitude ?? prev?.startLat,
startLng: start?.longitude ?? prev?.startLng,
endLat: end?.latitude ?? prev?.endLat,
endLng: end?.longitude ?? prev?.endLng,
route: dayState.route ?? prev?.route,
komootLink: dayState.komootLinkCtrl.text.trim().isEmpty ? (prev?.komootLink) : dayState.komootLinkCtrl.text.trim(),
allTrailsLink: dayState.allTrailsLinkCtrl.text.trim().isEmpty ? (prev?.allTrailsLink) : dayState.allTrailsLinkCtrl.text.trim(),
routeInfo: dayState.routeInfo ?? prev?.routeInfo,
gpxRoute: dayState.gpxRoute ?? prev?.gpxRoute,
));
  }

  return days;
  }

// Phase 5: Updated to use new state
Future<void> _publishPlan(BuildContext context) async {
// Phase 5: Guard against null formState
if (formState == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form not initialized')));
return;
}

final name = formState!.nameCtrl.text.trim();
final location = formState!.locations.isNotEmpty
    ? formState!.locations.map((l) => l.shortName).join(', ')
    : '';
final desc = formState!.descriptionCtrl.text.trim();
if (name.isEmpty || location.isEmpty || desc.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields.')));
return;
}
// Cover image is now optional - no validation needed
if (formState!.versions.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one version.')));
return;
}

final userId = _auth.currentUserId;
if (userId == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to publish.')));
return;
}

formState!.isSaving = true;
try {
final userModel = await _userService.getUserById(userId);
final creatorName = userModel?.displayName ?? 'Creator';

// Phase 5: Set isPublished before saving to avoid double-save
if (formState!.editingPlan != null) {
formState!.isPublished = true;
}

// Phase 5: Use saveService.saveAndValidate (includes validation and save)
final result = await saveService.saveAndValidate(formState!);
if (!result.success) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to publish: ${result.errors.join(', ')}')),
);
}
// Revert isPublished on failure
if (formState!.editingPlan != null) {
formState!.isPublished = false;
}
return;
}

if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adventure published successfully!')));
context.go('/mytrips');
} catch (e, stack) {
Log.e('builder', 'Failed to publish plan', e, stack);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish. Please try again.')));
} finally {
if (mounted) formState!.isSaving = false;
}
}


// Phase 5: Updated to use new state
Future<void> _saveChanges(BuildContext context) async {
// Phase 5: Guard against null formState
if (formState == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form not initialized')));
return;
}

// Phase 5: Use saveService.saveAndValidate
final result = await saveService.saveAndValidate(formState!);
if (!result.success) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to save: ${result.errors.join(', ')}')),
);
}
return;
}

if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved')));
context.pop();
}

/// Saves the current draft state without validation
/// Allows users to save progress at any point in the creation process
// Phase 4: Updated to use AdventureSaveService
Future<void> _saveDraft(BuildContext context) async {
final userId = _auth.currentUserId;
if (userId == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please sign in to save drafts')),
);
return;
}

// Phase 4: Guard against null formState
if (formState == null) {
Log.w('builder', 'Cannot save: formState is null');
return;
}

// Phase 4: For new plans, create draft first
if (formState!.editingPlan == null) {
// Create initial draft plan
final uuid = const Uuid();
final userModel = await _userService.getUserById(userId);
final creatorName = userModel?.displayName ?? 'Unknown';
final now = DateTime.now();
final planId = widget.editPlanId ?? uuid.v4();

// Upload cover image if available
String heroImageUrl = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800';
if (formState!.coverImageBytes != null) {
try {
final path = _storageService.coverImagePath(planId, formState!.coverImageExtension ?? 'jpg');
heroImageUrl = await _storageService.uploadImage(
path: path,
bytes: formState!.coverImageBytes!,
contentType: 'image/${formState!.coverImageExtension ?? 'jpeg'}',
);
} catch (e) {
Log.w('builder', 'Failed to upload cover image: $e');
}
} else if (formState!.heroImageUrlCtrl.text.trim().isNotEmpty) {
heroImageUrl = formState!.heroImageUrlCtrl.text.trim();
}

final plan = Plan(
id: planId,
name: formState!.nameCtrl.text.trim().isEmpty ? 'Untitled Adventure' : formState!.nameCtrl.text.trim(),
description: formState!.descriptionCtrl.text.trim(),
heroImageUrl: heroImageUrl,
location: formState!.locations.isNotEmpty
    ? formState!.locations.map((l) => l.shortName).join(', ')
    : '',
basePrice: 0.0,
creatorId: userId,
creatorName: creatorName,
versions: [],
isPublished: false,
createdAt: now,
updatedAt: now,
faqItems: [],
activityCategory: formState!.activityCategory,
accommodationType: formState!.accommodationType,
bestSeasons: formState!.bestSeasons,
isEntireYear: formState!.isEntireYear,
showPrices: formState!.showPrices,
);

final newPlanId = await _planService.createPlan(plan);
await _userService.addCreatedPlan(userId, newPlanId);
Log.i('builder', 'New draft created: $newPlanId');

// Update formState's editingPlan reference without recreating the state
// This preserves unsaved form changes
formState!.editingPlan = plan;
// Now save the current formState to persist any unsaved changes
final result = await saveService.saveDraft(formState!);
if (!result.success) {
Log.w('builder', 'Failed to save initial draft: ${result.errors.join(', ')}');
}
// Don't reload - that would lose unsaved form changes
}

// Phase 4: Use saveService for existing plans
if (formState!.editingPlan != null) {
final result = await saveService.saveDraft(formState!);
if (!mounted) return;

if (result.success) {
// Save status is now in formState, no need to update local variables
setState(() {});
} else {
setState(() {});
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to save: ${result.errors.join(', ')}')),
);
}
}
}

// Phase 4: Updated to use AdventureSaveService
/// Saves current step data when clicking Next button
/// Returns true if save was successful, false otherwise
Future<bool> _saveCurrentStep() async {
final userId = _auth.currentUserId;
if (userId == null) return true;

// Phase 4: Guard against null formState
if (formState == null) {
Log.w('builder', 'Cannot save: formState is null');
return false;
}

// Phase 4: Use saveService.saveAndValidate (includes validation)
final result = await saveService.saveAndValidate(formState!);

// Phase 5: Save status is now in formState, no need to update local variables

if (!result.success) {
if (result.errors.isNotEmpty) {
Log.w('builder', 'Validation errors: ${result.errors.join(', ')}');
}
return false;
}

return true;
}

Widget _buildStep7Overview() {
return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 900),
child: Padding(
padding: AppSpacing.paddingMd,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Page Header
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Review Your Adventure',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.w700,
color: Color(0xFF1A1C19),
),
),
const SizedBox(height: 8),
Text(
'Make sure everything looks good before publishing',
style: TextStyle(
fontSize: 16,
color: Colors.grey.shade600,
),
),
],
),
const SizedBox(height: 32),

// Publish Status Toggle
_buildPublishStatusToggle(),
const SizedBox(height: 24),

// Summary Cards
_buildActivityTypeCard(),
_buildLocationsCard(),
_buildGeneralInfoCard(),
_buildVersionsCard(),
_buildPackingCard(),
_buildTransportCard(),
_buildLocalTipsCard(),
_buildDaysCard(),

const SizedBox(height: 80),
],
),
),
),
),
);
}

Widget _buildPublishStatusToggle() {
return Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: Colors.grey.shade200),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.04),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Row(
children: [
Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: (formState?.isPublished ?? false) ? StatusColors.publishedBg : StatusColors.draftBg,
borderRadius: BorderRadius.circular(12),
),
child: Icon(
(formState?.isPublished ?? false) ? Icons.public : Icons.edit_note,
color: (formState?.isPublished ?? false) ? StatusColors.published : StatusColors.draft,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Publish Status',
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
Text(
(formState?.isPublished ?? false)
? 'Visible on marketplace'
: 'Saved as draft (not visible)',
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
),
),
],
),
),
const SizedBox(width: 8),
Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Switch(
value: formState?.isPublished ?? false,
onChanged: (value) {
if (formState != null) {
formState!.isPublished = value;
setState(() {});
}
},
activeColor: StatusColors.published,
),
Text(
(formState?.isPublished ?? false) ? 'Published' : 'Draft',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: (formState?.isPublished ?? false) ? StatusColors.published : StatusColors.draft,
),
),
],
),
],
),
);
}

Map<String, bool> _checkCompletion() {
// Phase 3.1: Use new state
return {
'Title': formState!.nameCtrl.text.trim().isNotEmpty,
'Description': formState!.descriptionCtrl.text.trim().isNotEmpty,
'Cover image': formState!.heroImageUrlCtrl.text.trim().isNotEmpty || formState!.coverImageBytes != null,
'Location': formState?.locations.isNotEmpty ?? false,
'At least one version': (formState?.versions.isNotEmpty ?? false) && (formState?.versions.any((v) => v.daysCount > 0) ?? false),
'At least one day': formState?.versions.any((v) => v.daysCount > 0) ?? false,
};
}

Widget _buildActivityTypeCard() {
  final hasActivity = formState?.activityCategory != null;
  final config = hasActivity ? getActivityConfig(formState!.activityCategory) : null;
  
  return _SummaryCard(
    icon: Icons.category_outlined,
    title: 'Activity Type',
    onEdit: () {
      _pageController.animateToPage(stepActivityType, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = stepActivityType);
    },
    isComplete: hasActivity,
    child: hasActivity
        ? Row(
            children: [
              Text(
                config?.icon ?? '🏔️',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                config?.displayName ?? formState!.activityCategory!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.category_outlined, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  'No activity type selected',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
  );
}

Widget _buildLocationsCard() {
  final hasLocations = formState?.locations.isNotEmpty ?? false;
  final config = getActivityConfig(formState?.activityCategory);
  
  return _SummaryCard(
    icon: Icons.location_on_outlined,
    title: 'Locations',
    badge: hasLocations ? '${formState!.locations.length} location${formState!.locations.length != 1 ? 's' : ''}' : null,
    onEdit: () {
      _pageController.animateToPage(stepLocations, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = stepLocations);
    },
    isComplete: hasLocations && (config == null || formState!.locations.length >= config.minLocations),
    child: hasLocations
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: formState!.locations.asMap().entries.map((entry) {
              final index = entry.key;
              final loc = entry.value;
              final canReorder = config?.locationOrderMatters ?? false;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (canReorder) ...[
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF428A13),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.place, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.shortName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          if (loc.fullAddress != loc.shortName)
                            Text(
                              loc.fullAddress,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  'No locations added',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
  );
}

Widget _buildGeneralInfoCard() {
// Phase 3.1: Use new state for display
final isComplete = formState!.nameCtrl.text.trim().isNotEmpty &&
formState!.descriptionCtrl.text.trim().isNotEmpty;

return _SummaryCard(
icon: Icons.info_outline,
title: 'General Information',
onEdit: () {
_pageController.animateToPage(stepGeneralInfo, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
setState(() => _currentStep = stepGeneralInfo);
},
isComplete: isComplete,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Cover image thumbnail
ClipRRect(
borderRadius: BorderRadius.circular(12),
// Phase 3.1: Use new state
child: formState!.coverImageBytes != null
? Image.memory(formState!.coverImageBytes!, width: 100, height: 80, fit: BoxFit.cover)
: formState!.heroImageUrlCtrl.text.trim().isNotEmpty
? Image.network(formState!.heroImageUrlCtrl.text, width: 100, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
return Container(width: 100, height: 80, color: Colors.grey.shade200, child: Icon(Icons.image, color: Colors.grey.shade400));
})
: Container(width: 100, height: 80, color: Colors.grey.shade200, child: Icon(Icons.image, color: Colors.grey.shade400)),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Phase 3.1: Use new state
Text(
formState!.nameCtrl.text.trim().isNotEmpty ? formState!.nameCtrl.text : 'Untitled Adventure',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w600,
color: formState!.nameCtrl.text.trim().isNotEmpty ? Colors.grey.shade900 : Colors.grey.shade400,
),
),
const SizedBox(height: 4),
Text(
formState!.descriptionCtrl.text.trim().isNotEmpty ? formState!.descriptionCtrl.text : 'No description added',
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
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

Widget _buildVersionsCard() {
// Phase 5: Use new state
if (formState == null) return const SizedBox.shrink();
final hasVersions = formState!.versions.isNotEmpty && formState!.versions.any((v) => v.daysCount > 0);

return _SummaryCard(
icon: Icons.layers_outlined,
title: 'Versions',
badge: '${formState!.versions.length} version${formState!.versions.length != 1 ? 's' : ''}',
onEdit: () {
_pageController.animateToPage(stepVersions, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
setState(() => _currentStep = stepVersions);
},
isComplete: hasVersions,
child: hasVersions
? Column(
children: formState!.versions.asMap().entries.map((entry) {
final index = entry.key;
final version = entry.value;
final duration = version.daysCount;
if (duration == 0) return const SizedBox.shrink();

final price = double.tryParse(formState!.priceCtrl.text.replaceAll(',', '.')) ?? 0.0;

return Container(
margin: EdgeInsets.only(bottom: index < formState!.versions.length - 1 ? 12 : 0),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.grey.shade50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
version.nameCtrl.text.trim().isNotEmpty ? version.nameCtrl.text : 'Version ${index + 1}',
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
Row(
children: [
Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
const SizedBox(width: 4),
Text(
'$duration day${duration != 1 ? 's' : ''}',
style: TextStyle(
fontSize: 13,
color: Colors.grey.shade600,
),
),
],
),
],
),
),
// Price
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: price == 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
borderRadius: BorderRadius.circular(8),
),
child: Text(
price == 0 ? 'FREE' : '€${price.toStringAsFixed(2)}',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w700,
color: price == 0 ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
),
),
),
],
),
);
}).toList(),
)
: _EmptyState(message: 'No versions added yet', icon: Icons.layers_outlined),
);
}

Widget _buildPackingCard() {
  // Phase 5: Use new state
  if (formState == null) return const SizedBox.shrink();
  final hasPacking = formState!.versions.any((v) => v.packingCategories.isNotEmpty);
  int totalItems = 0;
  for (final v in formState!.versions) {
    for (final cat in v.packingCategories) {
      totalItems += (cat.items.length as num).toInt();
    }
  }

  return _SummaryCard(
    icon: Icons.backpack_outlined,
    title: 'Travel Preparation',
    badge: hasPacking ? '$totalItems items' : null,
    onEdit: () {
      _pageController.animateToPage(stepPrepare, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 2);
    },
    isComplete: hasPacking,
    child: hasPacking
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: formState!.versions.take(2).expand((version) {
              return version.packingCategories.take(3).map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${cat.nameCtrl.text} (${cat.items.length} items)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }).toList(),
          )
        : _EmptyState(message: 'No packing items added', icon: Icons.backpack_outlined),
  );
}

Widget _buildTransportCard() {
  // Phase 5: Use new state
  if (formState == null) return const SizedBox.shrink();
  final hasTransport = formState!.versions.any((v) => v.transportationOptions.isNotEmpty);
  int totalOptions = 0;
  for (final v in formState!.versions) {
    totalOptions += (v.transportationOptions.length as num).toInt();
  }

  return _SummaryCard(
    icon: Icons.directions_outlined,
    title: 'How to Get There',
    badge: hasTransport ? '$totalOptions options' : null,
    onEdit: () {
      _pageController.animateToPage(stepPrepare, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 2);
    },
    isComplete: hasTransport,
    child: hasTransport
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: formState!.versions.take(2).expand((version) {
              return version.transportationOptions.take(3).map((opt) {
                final icons = opt.types.map((t) => _getTransportIcon(t)).take(3).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ...icons.map((icon) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(icon, size: 16, color: const Color(0xFF428A13)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt.titleCtrl.text.trim().isNotEmpty ? opt.titleCtrl.text : 'Transportation Option',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }).toList(),
          )
        : _EmptyState(message: 'No transport options added', icon: Icons.directions_outlined),
  );
}

Widget _buildLocalTipsCard() {
  // Phase 5: Use new state
  if (formState == null) return const SizedBox.shrink();
  final hasLocalTips = formState!.versions.any((v) => v.generatedLocalTips != null);
  int versionsWithTips = 0;
  for (final v in formState!.versions) {
    if (v.generatedLocalTips != null) versionsWithTips++;
  }

  return _SummaryCard(
    icon: Icons.lightbulb_outline,
    title: 'Local Tips',
    badge: hasLocalTips ? '$versionsWithTips version${versionsWithTips != 1 ? 's' : ''}' : null,
    onEdit: () {
      _pageController.animateToPage(stepLocalTips, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 3);
    },
    isComplete: hasLocalTips,
    child: hasLocalTips
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local tips configured for this adventure',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          )
        : _EmptyState(message: 'No local tips added', icon: Icons.lightbulb_outline),
  );
}

Widget _buildDaysCard() {
  // Phase 5: Use new state
  if (formState == null) return const SizedBox.shrink();
  final hasDays = formState!.versions.any((v) => v.daysCount > 0);
  int totalDays = 0;
  for (final v in formState!.versions) {
    totalDays += (v.daysCount as num).toInt();
  }

  return _SummaryCard(
    icon: Icons.calendar_today_outlined,
    title: 'Days',
    badge: hasDays ? '$totalDays days planned' : null,
    onEdit: () {
      _pageController.animateToPage(stepDays, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 4);
    },
    isComplete: hasDays,
    child: hasDays
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: formState!.versions.asMap().entries.expand((vEntry) {
              final vIndex = vEntry.key;
              final version = vEntry.value;
              final versionName = version.nameCtrl.text.trim().isNotEmpty ? version.nameCtrl.text : 'Version ${vIndex + 1}';

              return [
                if (vIndex > 0) const SizedBox(height: 16),
                if (formState!.versions.length > 1) ...[
                  Text(
                    versionName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF428A13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ...List.generate(version.daysCount.clamp(0, 5), (dayIndex) {
                  final dayNum = dayIndex + 1;
                  final dayState = version.getDayState(dayNum);
                  final titleCtrl = dayState.titleCtrl;
                  final distanceCtrl = dayState.distanceCtrl;
                  final distance = double.tryParse(distanceCtrl.text) ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            'Day $dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            titleCtrl.text.trim().isNotEmpty ? titleCtrl.text : 'Untitled day',
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distance > 0)
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                if (version.daysCount > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'and ${version.daysCount - 5} more days...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ];
            }).toList(),
          )
        : _EmptyState(message: 'No days added to itinerary', icon: Icons.calendar_today_outlined),
  );
}

/// Builds the auto-save indicator (Google Docs style)
Widget _buildAutoSaveIndicator() {
// Only show for editing existing plans
if (widget.editPlanId == null) return const SizedBox.shrink();

IconData icon;
Color color;
String text;

// Phase 5: Updated to use formState
final saveStatus = formState?.saveStatus ?? '';
final isSaving = formState?.isSaving ?? false;
final lastSavedAt = formState?.lastSavedAt;

if (isSaving) {
icon = Icons.cloud_upload_outlined;
color = Colors.grey;
text = 'Saving...';
} else if (saveStatus == 'Failed to save') {
icon = Icons.cloud_off_outlined;
color = Colors.red;
text = 'Failed to save';
} else if (lastSavedAt != null) {
icon = Icons.cloud_done_outlined;
color = Colors.green;
text = 'Saved';
} else {
icon = Icons.cloud_outlined;
color = Colors.grey;
text = 'Not saved yet';
}

String timeText = '';
if (lastSavedAt != null && !isSaving) {
final now = DateTime.now();
final diff = now.difference(lastSavedAt);
if (diff.inSeconds < 60) {
timeText = ' • just now';
} else if (diff.inMinutes < 60) {
timeText = ' • ${diff.inMinutes}m ago';
} else if (diff.inHours < 24) {
timeText = ' • ${diff.inHours}h ago';
}
}

return Row(
mainAxisSize: MainAxisSize.min,
children: [
if (isSaving)
SizedBox(
height: 16,
width: 16,
child: CircularProgressIndicator(strokeWidth: 2, color: color),
)
else
Icon(icon, size: 18, color: color),
const SizedBox(width: 6),
Text(
'$text$timeText',
style: TextStyle(
fontSize: 13,
color: color,
fontWeight: FontWeight.w500,
),
),
],
);
}

@override
void didChangeDependencies() {
super.didChangeDependencies();
// Phase 3.3: Use new state for location search
if (formState != null) {
formState!.locationCtrl.removeListener(_onLocationChanged);
formState!.locationCtrl.addListener(_onLocationChanged);
}
// Phase 5: Old listener removed - using formState.locationCtrl
}

void _onLocationChanged() {
// Phase 3.3: Use new state
final locationSearch = formState!.locationSearch;
final locationCtrl = formState!.locationCtrl;

// Only trigger search if the field has focus (user is actively typing)
if (!locationSearch.focusNode.hasFocus) {
return;
}

final text = locationCtrl.text.trim();
// Increased minimum length to 4 characters to reduce API calls
if (text.length < LocationSearchState.minQueryLength) {
locationSearch.suggestions = [];
locationSearch.isSearching = false;
locationSearch.lastQuery = ''; // Reset last query
locationSearch.notifyListeners(); // Notify UI
// Cancel any pending search
locationSearch.cancelSearch();
return;
}

// Don't search if query is same as last successful search
if (text == locationSearch.lastQuery) {
return;
}

// Cooldown: Prevent searches if last search was less than cooldown duration ago
if (!locationSearch.canSearch) {
// Too soon - cancel and reschedule
locationSearch.cancelSearch();
final timeSinceLastSearch = DateTime.now().difference(locationSearch.lastSearchTime!);
final remainingCooldown = LocationSearchState.searchCooldown - timeSinceLastSearch;
locationSearch.setDebounceTimer(Timer(remainingCooldown, () => _onLocationChanged()));
return;
}

// Cancel previous timer and search
locationSearch.cancelSearch();

// Show loading indicator immediately
locationSearch.isSearching = true;
locationSearch.notifyListeners();

// Set new debounce timer (using LocationSearchState.debounceDelay)
// Store timer in LocationSearchState so it can be cancelled
locationSearch.setDebounceTimer(Timer(LocationSearchState.debounceDelay, () async {
// Check cooldown again before executing
if (!locationSearch.canSearch) {
// Still too soon - reschedule
locationSearch.isSearching = false;
final timeSinceLastSearch = DateTime.now().difference(locationSearch.lastSearchTime!);
final remainingCooldown = LocationSearchState.searchCooldown - timeSinceLastSearch;
locationSearch.setDebounceTimer(Timer(remainingCooldown, () => _onLocationChanged()));
return;
}

// Update last search time
locationSearch.lastSearchTime = DateTime.now();

// Create search future for cancellation tracking
final searchFuture = _performLocationSearch(text);
locationSearch.searchFuture = searchFuture;

try {
final predictions = await searchFuture;
if (!mounted) return;

// Phase 3.3: Update new state with PlacePrediction results
if (mounted && locationSearch.searchFuture == searchFuture) {
locationSearch.suggestions = predictions;
locationSearch.lastQuery = text; // Remember successful search
locationSearch.isSearching = false;
locationSearch.notifyListeners(); // Notify UI to rebuild suggestions list
}
} catch (e) {
debugPrint('Google Places search error: $e');
if (mounted && locationSearch.searchFuture == searchFuture) {
locationSearch.suggestions = [];
locationSearch.isSearching = false;
locationSearch.notifyListeners();
}
} finally {
if (mounted && locationSearch.searchFuture == searchFuture) {
locationSearch.searchFuture = null;
}
}
}));
}

/// Perform location search with cancellation support
Future<List<PlacePrediction>> _performLocationSearch(String query) async {
final placesService = GooglePlacesService();
return await placesService.searchPlaces(query: query);
}

/// Push to WaypointEditPage (add mode); on return apply result.
Future<void> _pushAddWaypointPage(int dayNum, VersionFormState version) async {
if (formState == null || !mounted) return;
final dayState = version.getDayState(dayNum);
dayState.route ??= const DayRoute(
  geometry: {},
  distance: 0,
  duration: 0,
  routePoints: [],
  poiWaypoints: [],
);
final planId = formState!.editingPlan?.id ?? 'new';
final path = '/builder/$planId/waypoint/${formState!.activeVersionIndex}/$dayNum';
final result = await context.push<WaypointEditResult>(
  path,
  extra: <String, dynamic>{
    'mode': 'add',
    'initialRoute': dayState.route,
    'existingWaypoint': null,
    'tripName': formState!.nameCtrl.text.trim().isNotEmpty ? formState!.nameCtrl.text.trim() : 'Trip',
  },
);
if (!mounted) return;
_applyWaypointEditResult(dayNum, version, result);
}

/// Push to WaypointEditPage (edit mode); on return apply result.
Future<void> _pushEditWaypointPage(int dayNum, int waypointIndex, VersionFormState version) async {
if (formState == null || !mounted) return;
final dayState = version.getDayState(dayNum);
final existingRoute = dayState.route;
if (existingRoute == null) return;
final waypoints = existingRoute.poiWaypoints
    .map((json) => RouteWaypoint.fromJson(json))
    .toList();
if (waypointIndex >= waypoints.length) return;
final existingWaypoint = waypoints[waypointIndex];
final planId = formState!.editingPlan?.id ?? 'new';
final path = '/builder/$planId/waypoint/${formState!.activeVersionIndex}/$dayNum';
final result = await context.push<WaypointEditResult>(
  path,
  extra: <String, dynamic>{
    'mode': 'edit',
    'initialRoute': existingRoute,
    'existingWaypoint': existingWaypoint,
    'tripName': formState!.nameCtrl.text.trim().isNotEmpty ? formState!.nameCtrl.text.trim() : 'Trip',
  },
);
if (!mounted) return;
_applyWaypointEditResult(dayNum, version, result);
}

/// Handle WaypointEditResult from WaypointEditPage (BuilderScreen: updates dayState.route).
void _applyWaypointEditResult(int dayNum, VersionFormState version, WaypointEditResult? result) {
if (result == null) return;
final dayState = version.getDayState(dayNum);
if (result is WaypointSaved) {
  final updatedRoute = result.route;
  setState(() => dayState.route = updatedRoute);
  if (dayState.gpxRoute != null) {
    _snapWaypointsToGpxRoute(dayNum, dayState.gpxRoute!, updatedRoute, version);
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Waypoint saved'), backgroundColor: Colors.green),
  );
} else if (result is WaypointDeleted) {
  final route = dayState.route;
  if (route != null) {
    final waypoints = route.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .toList();
    waypoints.removeWhere((w) => w.id == result.waypointId);
    setState(() {
      dayState.route = route.copyWith(poiWaypoints: waypoints.map((w) => w.toJson()).toList());
    });
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Waypoint removed'), backgroundColor: Colors.orange),
  );
}
}

/// Delete a waypoint from the itinerary
void _deleteWaypointFromItinerary(int dayNum, int waypointIndex, VersionFormState version) {
final dayState = version.getDayState(dayNum);
final existingRoute = dayState.route;
if (existingRoute == null) return;

final waypoints = existingRoute.poiWaypoints
.map((json) => RouteWaypoint.fromJson(json))
.toList();

if (waypointIndex >= waypoints.length) return;

// Show confirmation dialog
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Delete Waypoint'),
content: const Text('Are you sure you want to delete this waypoint?'),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
TextButton(
onPressed: () {
Navigator.of(context).pop();
// Remove waypoint
waypoints.removeAt(waypointIndex);

// Update route
final updatedRoute = DayRoute(
geometry: existingRoute.geometry,
distance: existingRoute.distance,
duration: existingRoute.duration,
routePoints: existingRoute.routePoints,
elevationProfile: existingRoute.elevationProfile,
ascent: existingRoute.ascent,
descent: existingRoute.descent,
poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
);

setState(() {
dayState.route = updatedRoute;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Waypoint deleted'),
backgroundColor: Colors.red,
),
);
},
style: TextButton.styleFrom(foregroundColor: Colors.red),
child: const Text('Delete'),
),
],
),
);
}

/// Update the suggested time for a waypoint
void _updateWaypointTime(int dayNum, RouteWaypoint waypoint, String? newTime, VersionFormState version) {
final dayState = version.getDayState(dayNum);
final existingRoute = dayState.route;
if (existingRoute == null) return;

final waypoints = existingRoute.poiWaypoints
.map((json) => RouteWaypoint.fromJson(json))
.toList();

// Find and update the waypoint
final index = waypoints.indexWhere((w) => w.id == waypoint.id);
if (index < 0) return;

waypoints[index] = waypoints[index].copyWith(suggestedStartTime: newTime);

// Update route
final updatedRoute = DayRoute(
geometry: existingRoute.geometry,
distance: existingRoute.distance,
duration: existingRoute.duration,
routePoints: existingRoute.routePoints,
elevationProfile: existingRoute.elevationProfile,
ascent: existingRoute.ascent,
descent: existingRoute.descent,
poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
);

setState(() {
dayState.route = updatedRoute;
});

Log.i('builder', 'Updated waypoint time: ${waypoint.name} to $newTime');
}

/// Initialize ordering for a day from waypoints
void _initializeDayOrdering(int dayNum, List<RouteWaypoint> waypoints) {
  _dayOrderManagers[dayNum] = DayPlanOrderBuilder.buildFromWaypoints(dayNum, waypoints);
}

/// Move an item up in the day plan
void _moveItemUp(int dayNum, String itemId, VersionFormState version) {
  final manager = _dayOrderManagers[dayNum];
  if (manager == null) return;
  
  setState(() {
    _dayOrderManagers[dayNum] = manager.moveUp(itemId);
    _applyOrderingToWaypoints(dayNum, version);
  });
}

/// Move an item down in the day plan
void _moveItemDown(int dayNum, String itemId, VersionFormState version) {
  final manager = _dayOrderManagers[dayNum];
  if (manager == null) return;
  
  setState(() {
    _dayOrderManagers[dayNum] = manager.moveDown(itemId);
    _applyOrderingToWaypoints(dayNum, version);
  });
}

/// Apply the ordering to actual waypoints in the route
void _applyOrderingToWaypoints(int dayNum, VersionFormState version) {
  final manager = _dayOrderManagers[dayNum];
  if (manager == null) return;
  
  final dayState = version.getDayState(dayNum);
  final existingRoute = dayState.route;
  if (existingRoute == null) return;
  
  final waypoints = existingRoute.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  // Get ordered items
  final orderedItems = manager.sortedItems;
  
  // Reorder waypoints based on ordered items
  final reorderedWaypoints = <RouteWaypoint>[];
  for (final item in orderedItems) {
    if (item.isSection) {
      // Add all waypoints in this section
      final sectionId = item.id;
      final sectionWaypoints = waypoints.where((wp) {
        String? wpSectionId;
        switch (wp.type) {
          case WaypointType.restaurant:
            wpSectionId = 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
            break;
          case WaypointType.activity:
            wpSectionId = 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
            break;
          case WaypointType.accommodation:
            wpSectionId = 'accommodationSection';
            break;
          default:
            break;
        }
        return wpSectionId == sectionId;
      }).toList();
      reorderedWaypoints.addAll(sectionWaypoints);
    } else if (item.isIndividualWaypoint && item.waypointId != null) {
      // Add this individual waypoint
      final wp = waypoints.firstWhere(
        (w) => w.id == item.waypointId,
        orElse: () => waypoints.first, // Fallback (shouldn't happen)
      );
      if (!reorderedWaypoints.contains(wp)) {
        reorderedWaypoints.add(wp);
      }
    }
  }
  
  // Add any remaining waypoints that weren't in the ordering
  for (final wp in waypoints) {
    if (!reorderedWaypoints.contains(wp)) {
      reorderedWaypoints.add(wp);
    }
  }
  
  // Update order field to reflect new positions
  for (int i = 0; i < reorderedWaypoints.length; i++) {
    reorderedWaypoints[i].order = i;
  }
  
  // Update the route
  dayState.route = DayRoute(
    geometry: existingRoute.geometry,
    distance: existingRoute.distance,
    duration: existingRoute.duration,
    routePoints: existingRoute.routePoints,
    elevationProfile: existingRoute.elevationProfile,
    ascent: existingRoute.ascent,
    descent: existingRoute.descent,
    poiWaypoints: reorderedWaypoints.map((wp) => wp.toJson()).toList(),
  );
  dayState.notifyListeners();
  
  // Trigger auto-save to persist the ordering
  _saveCurrentStep();
}

/// Build timeline layout with categories for all waypoints
/// Uses the same _SidebarWaypointOrderedList component as route builder
Widget _buildAllWaypointsList(int dayNum, VersionFormState version) {
  // Phase 5: Get route from new state
  if (formState == null) return const SizedBox.shrink();
  final dayState = version.getDayState(dayNum);
  final existingRoute = dayState.route;
  Log.i('builder', 'Building waypoints list for day $dayNum. Route exists: ${existingRoute != null}');
  if (existingRoute != null) {
    Log.i('builder', 'Day $dayNum route has ${existingRoute.poiWaypoints.length} waypoints');
  }
  if (existingRoute == null) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.place, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Create a route first to add waypoints',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Get all waypoints and auto-assign categories if missing
  // For GPX routes, filter out route points (they're in geometry, not waypoints)
  final isGpxRoute = existingRoute.routeType == RouteType.gpx;
  final waypoints = existingRoute.poiWaypoints
      .map((json) {
        final wp = RouteWaypoint.fromJson(json);
        // Auto-assign time slot category if not set (for existing waypoints)
        if (wp.timeSlotCategory == null) {
          final autoCategory = autoAssignTimeSlotCategory(wp);
          return wp.copyWith(timeSlotCategory: autoCategory);
        }
        return wp;
      })
      .where((wp) => !isGpxRoute || wp.type != WaypointType.routePoint) // Filter route points for GPX routes
      .toList();

  // Renumber waypoints to ensure 1-indexed sequential ordering (1, 2, 3...)
  // This fixes the issue where saved waypoints might have 0-indexed orders
  // Only renumber if waypoints exist and ordering hasn't been initialized yet
  if (waypoints.isNotEmpty && !_dayOrderManagers.containsKey(dayNum)) {
    _renumberWaypointsInRoute(dayNum, version);
    // Reload waypoints after renumbering to get updated orders
    final updatedRoute = version.getDayState(dayNum).route;
    if (updatedRoute != null) {
      final renumberedWaypoints = updatedRoute.poiWaypoints
          .map((json) => RouteWaypoint.fromJson(json))
          .where((wp) => !isGpxRoute || wp.type != WaypointType.routePoint)
          .toList();
      _initializeDayOrdering(dayNum, renumberedWaypoints);
    } else {
      _initializeDayOrdering(dayNum, waypoints);
    }
  } else if (!_dayOrderManagers.containsKey(dayNum)) {
    // Initialize ordering if not already done
    _initializeDayOrdering(dayNum, waypoints);
  }

  // Get the order manager for this day
  final orderManager = _dayOrderManagers[dayNum];
  if (orderManager == null) {
    return const SizedBox.shrink();
  }

  // Check if this is a GPX route with supported activity (skip travel segments)
  final category = formState?.activityCategory;
  final supportsGpx = category == ActivityCategory.hiking ||
                      category == ActivityCategory.skis ||
                      category == ActivityCategory.cycling ||
                      category == ActivityCategory.climbing;
  final shouldSkipTravelSegments = isGpxRoute && supportsGpx;
  
  // Use _SidebarWaypointOrderedList (same as route builder)
  return _SidebarWaypointOrderedList(
    waypoints: waypoints,
    onEdit: (waypoint) {
      final index = waypoints.indexOf(waypoint);
      if (index >= 0) {
        _pushEditWaypointPage(dayNum, index, version);
      }
    },
    onMoveUp: (itemId) => _moveItemUp(dayNum, itemId, version),
    onMoveDown: (itemId) => _moveItemDown(dayNum, itemId, version),
    canMoveUp: (itemId) => orderManager.canMoveUp(itemId),
    canMoveDown: (itemId) => orderManager.canMoveDown(itemId),
    orderManager: orderManager,
    onInitializeOrdering: () {
      _initializeDayOrdering(dayNum, waypoints);
    },
    skipTravelSegments: shouldSkipTravelSegments,
    onTravelModeChanged: (waypoint, newMode) => _handleTravelModeChange(dayNum, waypoint, newMode, version),
    onAddAlternative: (waypoint) => _addAlternativeWaypoint(dayNum, waypoint, version),
    onWaypointUpdated: (updatedWaypoint) => _updateWaypointInRoute(dayNum, updatedWaypoint, version),
    onBulkWaypointUpdate: (updatedWaypoints) => _bulkUpdateWaypointsInRoute(dayNum, updatedWaypoints, version),
    onOrderChanged: () => _renumberWaypointsInRoute(dayNum, version),
    onUngroup: (choiceGroupId) => _ungroupChoiceGroup(dayNum, choiceGroupId, version),
  );
}

/// Update a waypoint in the route
void _updateWaypointInRoute(int dayNum, RouteWaypoint updatedWaypoint, VersionFormState version) {
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  final index = waypoints.indexWhere((w) => w.id == updatedWaypoint.id);
  if (index >= 0) {
    waypoints[index] = updatedWaypoint;
    
    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
      );
    });
    // Reinitialize ordering after update
    _initializeDayOrdering(dayNum, waypoints);
    
    // Re-snap waypoints to GPX route if it exists
    final gpxRoute = dayState.gpxRoute;
    if (gpxRoute != null) {
      final updatedRoute = dayState.route;
      if (updatedRoute != null) {
        _snapWaypointsToGpxRoute(dayNum, gpxRoute, updatedRoute, version);
      }
    }
  }
}

/// Bulk update waypoints in the route (for atomic move operations)
void _bulkUpdateWaypointsInRoute(int dayNum, List<RouteWaypoint> updatedWaypoints, VersionFormState version) {
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  // Update all waypoints in a single setState
  // Fix: Use indexed loop to avoid O(n²) performance
  setState(() {
    for (final updatedWaypoint in updatedWaypoints) {
      // Use indexed loop instead of indexWhere for O(n) performance
      for (int i = 0; i < waypoints.length; i++) {
        if (waypoints[i].id == updatedWaypoint.id) {
          waypoints[i] = updatedWaypoint;
          break;
        }
      }
    }
    
    dayState.route = route.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    
    // Renumber waypoints after bulk update
    _renumberWaypointsInRoute(dayNum, version);
  });
  
  // Re-snap waypoints to GPX route if it exists
  final gpxRoute = dayState.gpxRoute;
  if (gpxRoute != null) {
    final updatedRoute = dayState.route;
    if (updatedRoute != null) {
      _snapWaypointsToGpxRoute(dayNum, gpxRoute, updatedRoute, version);
    }
  }
  
  // Save the changes
  _saveCurrentStep();
}

/// Renumber waypoints to ensure sequential ordering (1, 2, 3...)
/// Ungroup a choice group - removes choiceGroupId and choiceLabel from all waypoints in the group
/// and assigns sequential order numbers
void _ungroupChoiceGroup(int dayNum, String choiceGroupId, VersionFormState version) {
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  // Find all waypoints in this choice group
  final waypointsInGroup = waypoints
      .where((w) => w.choiceGroupId == choiceGroupId)
      .toList();
  
  if (waypointsInGroup.isEmpty) return;
  
  // Get the base order (the order of the first waypoint in the group)
  final baseOrder = waypointsInGroup.first.order;
  
  // Remove choice group info and assign sequential orders
  final updatedWaypoints = waypoints.map((wp) {
    if (wp.choiceGroupId == choiceGroupId) {
      final index = waypointsInGroup.indexWhere((w) => w.id == wp.id);
      return wp.copyWith(
        choiceGroupId: null,
        choiceLabel: null,
        order: baseOrder + index,
      );
    }
    return wp;
  }).toList();
  
  // Update the route with ungrouped waypoints
  setState(() {
    dayState.route = route.copyWith(
      poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
    );
  });
  
  // Renumber all waypoints to ensure sequential ordering
  _renumberWaypointsInRoute(dayNum, version);
  
  // Trigger auto-save to persist the changes
  _saveCurrentStep();
}

void _renumberWaypointsInRoute(int dayNum, VersionFormState version) {
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  // Group by order, then renumber sequentially
  waypoints.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
  
  // Group waypoints by their current order to handle choice groups
  final groupedByOrder = <int, List<RouteWaypoint>>{};
  for (final wp in waypoints) {
    final order = wp.order ?? 0;
    groupedByOrder.putIfAbsent(order, () => []).add(wp);
  }
  
  final sortedOrders = groupedByOrder.keys.toList()..sort();
  final renumberedWaypoints = <RouteWaypoint>[];
  
  int newOrder = 1;
  for (final oldOrder in sortedOrders) {
    final group = groupedByOrder[oldOrder]!;
    for (final wp in group) {
      renumberedWaypoints.add(wp.copyWith(order: newOrder));
    }
    newOrder++;
  }
  
  setState(() {
    dayState.route = route.copyWith(
      poiWaypoints: renumberedWaypoints.map((w) => w.toJson()).toList(),
    );
  });
  
  // Re-snap waypoints to GPX route if it exists
  final gpxRoute = dayState.gpxRoute;
  if (gpxRoute != null) {
    final updatedRoute = dayState.route;
    if (updatedRoute != null) {
      _snapWaypointsToGpxRoute(dayNum, gpxRoute, updatedRoute, version);
    }
  }
  
  // Reinitialize ordering
  _initializeDayOrdering(dayNum, renumberedWaypoints);
}

/// Snap all waypoints in a route to a GPX route
void _snapWaypointsToGpxRoute(int dayNum, GpxRoute gpxRoute, DayRoute route, VersionFormState version) {
  try {
    final dayState = version.getDayState(dayNum);
    final waypoints = route.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .toList();
    
    if (waypoints.isEmpty) return;
    
    final snapper = GpxWaypointSnapper();
    final snapResults = snapper.snapAllWaypoints(waypoints, gpxRoute);
    
    // Update waypoints with snap info and move positions to snap points
    // This ensures waypoints appear on the GPX route, not at their original locations
    final updatedWaypoints = <RouteWaypoint>[];
    for (int i = 0; i < waypoints.length; i++) {
      final waypoint = waypoints[i];
      final snapResult = snapResults[i];
      
      final snapInfo = WaypointSnapInfo(
        snapPoint: snapResult.snapPoint,
        originalPosition: waypoint.position, // Store original position BEFORE moving
        distanceFromRouteM: snapResult.distanceFromRoute,
        distanceAlongRouteKm: snapResult.distanceAlongRoute,
        segmentIndex: snapResult.segmentIndex,
      );
      
      // Update waypoint position to snap point so it appears on the GPX route
      updatedWaypoints.add(waypoint.copyWith(
        position: snapResult.snapPoint, // Move waypoint to snap point on route
        waypointSnapInfo: snapInfo,
      ));
    }
    
    // Update route with snapped waypoints
    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
      );
    });
    
    Log.i('builder', 'Snapped ${updatedWaypoints.length} waypoints to GPX route for day $dayNum');
  } catch (e, stack) {
    Log.e('builder', 'Failed to snap waypoints to GPX route', e, stack);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to snap waypoints to route: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

/// Remove snap info from all waypoints when GPX route is removed
void _removeWaypointSnapInfo(int dayNum, DayRoute route, VersionFormState version) {
  try {
    final dayState = version.getDayState(dayNum);
    final waypoints = route.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .toList();
    
    if (waypoints.isEmpty) return;
    
    // Remove snap info from all waypoints
    final updatedWaypoints = waypoints
        .map((wp) => wp.copyWith(waypointSnapInfo: null))
        .toList();
    
    // Update route
    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
      );
    });
    
    Log.i('builder', 'Removed snap info from waypoints for day $dayNum');
  } catch (e, stack) {
    Log.e('builder', 'Failed to remove waypoint snap info', e, stack);
  }
}

/// Handle travel mode change for a waypoint
Future<void> _handleTravelModeChange(int dayNum, RouteWaypoint waypoint, String newMode, VersionFormState version) async {
  if (formState == null) return;
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  final index = waypoints.indexWhere((w) => w.id == waypoint.id);
  if (index < 0) return;
  
  // Find previous waypoint to calculate travel
  final prevIndex = index > 0 ? index - 1 : null;
  if (prevIndex == null) {
    // No previous waypoint, just update mode
    waypoints[index] = waypoint.copyWith(travelMode: newMode);
    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
      );
    });
    return;
  }
  
  final prevWaypoint = waypoints[prevIndex];
  final travelService = TravelCalculatorService();
  
  try {
    // Check if GPX route exists for this day
    final gpxRoute = dayState.gpxRoute;
    TravelInfo? travelInfo;
    
    if (gpxRoute != null && route.routeType == RouteType.gpx) {
      // Use GPX-based calculation
      travelInfo = await travelService.calculateTravelWithGpx(
        from: prevWaypoint.position,
        to: waypoint.position,
        gpxRoute: gpxRoute,
        activityCategory: formState?.activityCategory,
      );
    } else {
      // Use standard Directions API calculation
      TravelMode? travelMode;
      if (newMode == 'walking') {
        travelMode = TravelMode.walking;
      } else if (newMode == 'transit') {
        travelMode = TravelMode.transit;
      } else if (newMode == 'driving') {
        travelMode = TravelMode.driving;
      } else if (newMode == 'bicycling') {
        travelMode = TravelMode.bicycling;
      }
      
      travelInfo = await travelService.calculateTravel(
        from: prevWaypoint.position,
        to: waypoint.position,
        travelMode: travelMode,
        includeGeometry: false,
        activityCategory: formState?.activityCategory,
      );
    }
    
    if (travelInfo != null && mounted) {
      waypoints[index] = waypoint.copyWith(
        travelMode: newMode,
        travelTime: travelInfo.durationSeconds,
        travelDistance: travelInfo.distanceMeters.toDouble(),
      );
      
      setState(() {
        dayState.route = route.copyWith(
          poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
        );
      });
    }
  } catch (e) {
    Log.e('builder', 'Failed to calculate travel time', e);
  }
}

/// Add an alternative waypoint (OR grouping)
Future<void> _addAlternativeWaypoint(int dayNum, RouteWaypoint sourceWaypoint, VersionFormState version) async {
  if (formState == null) return;
  final dayState = version.getDayState(dayNum);
  final route = dayState.route;
  if (route == null) return;
  
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList();
  
  // Filter available waypoints: exclude source and any already in the same choice group
  final availableWaypoints = waypoints.where((wp) {
    if (wp.id == sourceWaypoint.id) return false;
    if (sourceWaypoint.choiceGroupId != null && 
        wp.choiceGroupId == sourceWaypoint.choiceGroupId) {
      return false;
    }
    return true;
  }).toList();

  if (availableWaypoints.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other waypoints available to group with'),
        ),
      );
    }
    return;
  }

  final selectedWaypoint = await showDialog<RouteWaypoint>(
    context: context,
    builder: (context) => _SelectWaypointForGroupDialog(
      availableWaypoints: availableWaypoints,
      sourceWaypoint: sourceWaypoint,
    ),
  );

  if (selectedWaypoint != null && mounted) {
    // Get or create choice group ID
    final choiceGroupId = sourceWaypoint.choiceGroupId ?? const Uuid().v4();
    final groupingService = WaypointGroupingService();
    final choiceLabel = sourceWaypoint.choiceLabel ?? 
        groupingService.generateAutoChoiceLabel(
          sourceWaypoint.type,
          sourceWaypoint.suggestedStartTime,
          sourceWaypoint.mealTime,
          sourceWaypoint.activityTime,
        );

    // Update source waypoint if it doesn't have choiceGroupId yet
    final sourceIndex = waypoints.indexWhere((w) => w.id == sourceWaypoint.id);
    if (sourceIndex >= 0 && sourceWaypoint.choiceGroupId == null) {
      waypoints[sourceIndex] = sourceWaypoint.copyWith(
        choiceGroupId: choiceGroupId,
        choiceLabel: choiceLabel,
      );
    }

    // Update selected waypoint to join the choice group
    final selectedIndex = waypoints.indexWhere((w) => w.id == selectedWaypoint.id);
    if (selectedIndex >= 0) {
      final oldChoiceGroupId = selectedWaypoint.choiceGroupId;
      
      waypoints[selectedIndex] = selectedWaypoint.copyWith(
        order: sourceWaypoint.order, // Same order as source waypoint
        choiceGroupId: choiceGroupId,
        choiceLabel: choiceLabel,
      );
      
      // Clean up orphaned choice groups
      if (oldChoiceGroupId != null && oldChoiceGroupId != choiceGroupId) {
        final remainingInOldGroup = waypoints
            .where((w) => w.choiceGroupId == oldChoiceGroupId)
            .toList();
        
        if (remainingInOldGroup.length <= 1) {
          // Fix: Use indexed loop to avoid O(n²) performance
          for (final wp in remainingInOldGroup) {
            for (int i = 0; i < waypoints.length; i++) {
              if (waypoints[i].id == wp.id) {
                waypoints[i] = waypoints[i].copyWith(
                  choiceGroupId: null,
                  choiceLabel: null,
                );
                break;
              }
            }
          }
        }
      }
      
      _renumberWaypointsInRoute(dayNum, version);
    }
    
    setState(() {
      dayState.route = route.copyWith(
        poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
      );
    });
  }
}

// Removed unused compose methods - data is now composed directly from state classes in save service
}

// Legacy form data classes removed - all data is now managed via VersionFormState, DayFormState, etc.

extension on _BuilderScreenState {
Widget _buildVersionCard(int index) {
// Phase 3.2: Use new state for display
final version = formState!.versions[index];
return Container(
margin: const EdgeInsets.only(bottom: 20),
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 3,
offset: const Offset(0, 1),
),
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 2,
offset: const Offset(0, 1),
),
],
),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
Text(
"Version ${index + 1}",
style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
),
IconButton(
tooltip: 'Remove version',
onPressed: formState!.versions.length == 1
? null
: () {
// Phase 5: Use new state only
if (formState!.activeVersionIndex >= formState!.versions.length - 1) {
formState!.activeVersionIndex = (formState!.activeVersionIndex - 1).clamp(0, formState!.versions.length - 2);
}
formState!.versions.removeAt(index);
setState(() {}); // Trigger rebuild
},
icon: const Icon(Icons.delete_outline, size: 20),
style: IconButton.styleFrom(
foregroundColor: Colors.grey.shade600,
hoverColor: Colors.red.shade50,
),
),
]),
const SizedBox(height: 20),
_buildTextField("Version Name", "e.g., 5-Day Extreme", controller: version.nameCtrl, required: false),
const SizedBox(height: 16),
_buildTextField("Duration (Days)", "5", isNumber: true, controller: version.durationCtrl, required: true),
]),
);
}


Future<void> _pickCoverImage() async {
try {
final result = await _storageService.pickImage();
if (result != null && mounted) {
// Phase 3.1: Use new state
setState(() {
formState!.coverImageBytes = result.bytes;
formState!.coverImageExtension = result.extension;
formState!.heroImageUrlCtrl.clear(); // Clear URL field when image is uploaded
});
Log.i('builder', 'Cover image selected: ${result.name}');
}
} catch (e, stack) {
Log.e('builder', 'Failed to pick cover image', e, stack);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Failed to select image')),
);
}
}
}

Future<void> _pickDayImage(int dayNum) async {
try {
final result = await _storageService.pickImage();
if (result != null && mounted) {
// Phase 5: Use new state
final version = formState!.activeVersion;
final dayState = version.getDayState(dayNum);
setState(() {
dayState.newImageBytes = [result.bytes];
dayState.newImageExtensions = [result.extension];
});
Log.i('builder', 'Day $dayNum image selected: ${result.name}');
}
} catch (e, stack) {
Log.e('builder', 'Failed to pick day image', e, stack);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Failed to select image')),
);
}
}
}
}

/// New stateful widget for packing category card using new state classes
class _PackingCategoryCardWidgetNew extends StatefulWidget {
final VersionFormState version;
final int categoryIndex;
final PackingCategoryFormState category;
final VoidCallback onUpdate;

const _PackingCategoryCardWidgetNew({
super.key,
required this.version,
required this.categoryIndex,
required this.category,
required this.onUpdate,
});

@override
State<_PackingCategoryCardWidgetNew> createState() => _PackingCategoryCardWidgetNewState();
}

class _PackingCategoryCardWidgetNewState extends State<_PackingCategoryCardWidgetNew> {
late TextEditingController _itemNameCtrl;
late TextEditingController _itemDescCtrl;
late TextEditingController _categoryDescCtrl;
bool _showCategoryDescription = false;
bool _showItemDescription = false;

@override
void initState() {
super.initState();
_itemNameCtrl = TextEditingController();
_itemDescCtrl = TextEditingController();
// Use existing controller or create local one
_categoryDescCtrl = widget.category.descriptionCtrl ?? TextEditingController();
_showCategoryDescription = _categoryDescCtrl.text.isNotEmpty;
}

@override
void dispose() {
_itemNameCtrl.dispose();
_itemDescCtrl.dispose();
// Only dispose local controller if it's not the one from the category
if (widget.category.descriptionCtrl == null) {
_categoryDescCtrl.dispose();
}
super.dispose();
}

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 3,
offset: const Offset(0, 1),
),
BoxShadow(
color: Colors.black.withValues(alpha: 0.06),
blurRadius: 2,
offset: const Offset(0, 1),
),
],
),
child: ExpansionTile(
title: Row(
children: [
Expanded(
child: Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: widget.category.nameCtrl,
textDirection: TextDirection.ltr,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
decoration: const InputDecoration(
hintText: 'Category name (e.g., Insurance)',
border: InputBorder.none,
isDense: true,
contentPadding: EdgeInsets.zero,
),
onChanged: (value) {
widget.category.notifyListeners();
widget.onUpdate();
},
),
),
),
if (widget.category.descriptionCtrl?.text.isNotEmpty ?? false)
Tooltip(
message: 'This category has additional information',
child: Icon(Icons.info_outline, size: 20, color: context.colors.primary),
),
const SizedBox(width: 4),
IconButton(
icon: const Icon(Icons.delete_outline, size: 20),
onPressed: () {
widget.version.packingCategories.removeAt(widget.categoryIndex);
widget.version.notifyListeners();
widget.onUpdate();
},
tooltip: 'Delete category',
),
],
),
childrenPadding: AppSpacing.paddingMd,
children: [
// Category description toggle
TextButton.icon(
onPressed: () {
setState(() {
_showCategoryDescription = !_showCategoryDescription;
if (!_showCategoryDescription && (widget.category.descriptionCtrl?.text.isEmpty ?? true)) {
// Description will be cleared when controller is empty
}
});
},
icon: Icon(
_showCategoryDescription ? Icons.remove_circle_outline : Icons.add_circle_outline,
size: 18,
),
label: Text(_showCategoryDescription
? 'Remove category information'
: 'Add category information/description'),
style: TextButton.styleFrom(
padding: EdgeInsets.zero,
alignment: Alignment.centerLeft,
),
),

// Category description field
if (_showCategoryDescription) ...[
const SizedBox(height: 8),
Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: _categoryDescCtrl,
textDirection: TextDirection.ltr,
maxLines: 3,
decoration: InputDecoration(
hintText: 'Add helpful information with links',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
isDense: true,
helperText: 'Supports markdown: [link text](url)',
helperMaxLines: 2,
),
onChanged: (value) {
// If category doesn't have a descriptionCtrl, we need to update it via the version
// For now, just notify - the actual persistence happens on save
widget.category.notifyListeners();
widget.onUpdate();
},
),
),
const SizedBox(height: 12),
],

const SizedBox(height: 8),

// Add item section
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: _itemNameCtrl,
textDirection: TextDirection.ltr,
decoration: const InputDecoration(
hintText: 'Add item (e.g., Travel insurance)',
isDense: true,
),
onSubmitted: (_) => _addItem(),
),
),
),
const SizedBox(width: 8),
IconButton(
icon: Icon(
_showItemDescription ? Icons.notes : Icons.note_add_outlined,
color: _showItemDescription ? context.colors.primary : Colors.grey.shade600,
),
tooltip: 'Add description with links',
onPressed: () => setState(() => _showItemDescription = !_showItemDescription),
),
const SizedBox(width: 8),
FilledButton.icon(
onPressed: _addItem,
icon: const Icon(Icons.add, size: 18),
label: const Text('Add'),
style: FilledButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
],
),

// Item description field (expandable)
AnimatedSize(
duration: const Duration(milliseconds: 200),
child: _showItemDescription
? Padding(
padding: const EdgeInsets.only(top: 12),
child: Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: _itemDescCtrl,
textDirection: TextDirection.ltr,
maxLines: 3,
decoration: InputDecoration(
hintText: 'Add helpful info...\nSupports links: [text](url)',
helperText: 'Tip: Use [link text](url) for clickable links',
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
contentPadding: const EdgeInsets.all(16),
),
),
),
)
: const SizedBox.shrink(),
),
],
),

const SizedBox(height: 12),

// Items list
if (widget.category.items.isEmpty)
Container(
padding: AppSpacing.paddingMd,
decoration: BoxDecoration(
color: Colors.grey.shade100,
borderRadius: BorderRadius.circular(8),
),
child: Row(
children: [
Icon(Icons.inventory_2_outlined, color: Colors.grey.shade600),
const SizedBox(width: 8),
Text('No items yet', style: TextStyle(color: Colors.grey.shade600)),
],
),
)
else
Wrap(
spacing: 8,
runSpacing: 8,
children: widget.category.items.asMap().entries.map((entry) {
final itemIndex = entry.key;
final item = entry.value;
return _buildItemChipNew(item, itemIndex);
}).toList(),
),
],
),
);
}

Widget _buildItemChipNew(PackingItemFormState item, int itemIndex) {
final hasDescription = item.descriptionCtrl?.text.isNotEmpty ?? false;

return GestureDetector(
onLongPress: () => _showEditItemDialogNew(item, itemIndex),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: Colors.grey.shade100,
borderRadius: BorderRadius.circular(20),
border: Border.all(color: Colors.grey.shade300),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(item.nameCtrl.text, style: const TextStyle(fontSize: 14)),
if (hasDescription) ...[
const SizedBox(width: 6),
GestureDetector(
onTap: () => _showItemInfoTooltipNew(item),
child: MouseRegion(
cursor: SystemMouseCursors.click,
child: Icon(
Icons.info_outline,
size: 16,
color: context.colors.primary,
),
),
),
],
const SizedBox(width: 6),
GestureDetector(
onTap: () => _deleteItemNew(itemIndex),
child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
),
],
),
),
);
}

void _addItem() {
final name = _itemNameCtrl.text.trim();
if (name.isEmpty) return;

final description = _showItemDescription ? _itemDescCtrl.text.trim() : null;

final newItem = PackingItemFormState(
id: DateTime.now().millisecondsSinceEpoch.toString(),
nameCtrl: TextEditingController(text: name),
descriptionCtrl: description?.isNotEmpty == true ? TextEditingController(text: description) : null,
);

widget.category.items.add(newItem);
widget.category.notifyListeners();

_itemNameCtrl.clear();
_itemDescCtrl.clear();
setState(() => _showItemDescription = false);
widget.onUpdate();
}

void _deleteItemNew(int itemIndex) {
widget.category.items[itemIndex].dispose();
widget.category.items.removeAt(itemIndex);
widget.category.notifyListeners();
widget.onUpdate();
}

void _showItemInfoTooltipNew(PackingItemFormState item) {
showModalBottomSheet(
context: context,
builder: (context) => Container(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(Icons.info_outline, color: context.colors.primary),
const SizedBox(width: 8),
Expanded(
child: Text(
item.nameCtrl.text,
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
),
),
],
),
const SizedBox(height: 12),
if (item.descriptionCtrl?.text.isNotEmpty ?? false)
MarkdownBody(
data: item.descriptionCtrl!.text,
styleSheet: MarkdownStyleSheet(
a: TextStyle(color: context.colors.primary, decoration: TextDecoration.underline),
),
onTapLink: (text, href, title) {
Navigator.pop(context);
if (href != null) {
launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
}
},
),
const SizedBox(height: 20),
],
),
),
);
}

void _showEditItemDialogNew(PackingItemFormState item, int itemIndex) {
final nameController = TextEditingController(text: item.nameCtrl.text);
final descController = TextEditingController(text: item.descriptionCtrl?.text ?? '');

showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Edit Item'),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: nameController,
textDirection: TextDirection.ltr,
decoration: const InputDecoration(labelText: 'Item name'),
),
),
const SizedBox(height: 16),
Directionality(
textDirection: TextDirection.ltr,
child: TextField(
controller: descController,
textDirection: TextDirection.ltr,
maxLines: 3,
decoration: const InputDecoration(labelText: 'Description (optional)'),
),
),
],
),
actions: [
TextButton(
onPressed: () {
nameController.dispose();
descController.dispose();
Navigator.pop(context);
},
child: const Text('Cancel'),
),
FilledButton(
onPressed: () {
item.nameCtrl.text = nameController.text;
// Note: descriptionCtrl is final, so we can't assign it
// The description will be preserved if it already exists
// For new descriptions, they'll be saved when the category is saved
if (item.descriptionCtrl != null && descController.text.isNotEmpty) {
item.descriptionCtrl!.text = descController.text;
} else if (item.descriptionCtrl != null && descController.text.isEmpty) {
// Can't remove the controller since it's final, but we can clear it
item.descriptionCtrl!.clear();
}
widget.category.notifyListeners();
nameController.dispose();
descController.dispose();
Navigator.pop(context);
widget.onUpdate();
},
child: const Text('Save'),
),
],
),
);
}
}

/// Reusable summary card component for overview page
class _SummaryCard extends StatelessWidget {
final IconData icon;
final String title;
final String? badge;
final VoidCallback onEdit;
final bool isComplete;
final Widget child;

const _SummaryCard({
required this.icon,
required this.title,
this.badge,
required this.onEdit,
required this.isComplete,
required this.child,
});

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(bottom: 20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.04),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Column(
children: [
// Header
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
border: Border(
bottom: BorderSide(color: Colors.grey.shade100),
),
),
child: Row(
children: [
Icon(icon, size: 22, color: const Color(0xFF428A13)),
const SizedBox(width: 12),
Text(
title,
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.w600,
color: Color(0xFF1A1C19),
),
),
if (badge != null) ...[
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
decoration: BoxDecoration(
color: Colors.grey.shade100,
borderRadius: BorderRadius.circular(12),
),
child: Text(
badge!,
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade600,
fontWeight: FontWeight.w500,
),
),
),
],
const Spacer(),
TextButton(
onPressed: onEdit,
child: const Row(
children: [
Text('Edit'),
SizedBox(width: 4),
Icon(Icons.arrow_forward, size: 16),
],
),
style: TextButton.styleFrom(
foregroundColor: const Color(0xFF428A13),
),
),
],
),
),

// Content
Padding(
padding: const EdgeInsets.all(20),
child: child,
),

// Status indicator
Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
decoration: BoxDecoration(
color: isComplete ? const Color(0xFFF1F8E9) : const Color(0xFFFFF8E1),
borderRadius: const BorderRadius.only(
bottomLeft: Radius.circular(16),
bottomRight: Radius.circular(16),
),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
Icon(
isComplete ? Icons.check_circle : Icons.warning_amber_rounded,
size: 16,
color: isComplete ? const Color(0xFF4CAF50) : const Color(0xFFF9A825),
),
const SizedBox(width: 6),
Text(
isComplete ? 'Complete' : 'Incomplete',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: isComplete ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
),
),
],
),
),
],
),
);
}
}

/// Empty state widget for summary cards
class _EmptyState extends StatelessWidget {
final String message;
final IconData icon;

const _EmptyState({
required this.message,
required this.icon,
});

@override
Widget build(BuildContext context) {
return Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 48,
color: Colors.grey.shade300,
),
const SizedBox(height: 12),
Text(
message,
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade500,
),
),
],
),
);
}
}

// ============================================================================
// SIDEBAR WIDGETS - Same as route_builder_screen.dart
// ============================================================================


/// Sidebar waypoint list using sequential ordering by order number
class _SidebarWaypointOrderedList extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final void Function(RouteWaypoint) onEdit;
  final void Function(String itemId) onMoveUp;
  final void Function(String itemId) onMoveDown;
  final bool Function(String itemId) canMoveUp;
  final bool Function(String itemId) canMoveDown;
  final DayPlanOrderManager? orderManager;
  final VoidCallback onInitializeOrdering;
  final Future<void> Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;
  final Future<void> Function(RouteWaypoint waypoint)? onAddAlternative;
  final void Function(RouteWaypoint updatedWaypoint)? onWaypointUpdated;
  final void Function(List<RouteWaypoint> updatedWaypoints)? onBulkWaypointUpdate;
  final VoidCallback? onOrderChanged;
  final void Function(String choiceGroupId)? onUngroup;
  final bool skipTravelSegments; // Skip travel segments for GPX routes with supported activities
  
  const _SidebarWaypointOrderedList({
    required this.waypoints,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canMoveUp,
    required this.canMoveDown,
    this.orderManager,
    required this.onInitializeOrdering,
    this.onTravelModeChanged,
    this.onAddAlternative,
    this.onWaypointUpdated,
    this.onBulkWaypointUpdate,
    this.onOrderChanged,
    this.onUngroup,
    this.skipTravelSegments = false,
  });

  @override
  State<_SidebarWaypointOrderedList> createState() => _SidebarWaypointOrderedListState();
}

class _SidebarWaypointOrderedListState extends State<_SidebarWaypointOrderedList> {
  @override
  void initState() {
    super.initState();
    if (widget.orderManager == null) {
      widget.onInitializeOrdering();
    }
  }

  @override
  void didUpdateWidget(_SidebarWaypointOrderedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderManager != widget.orderManager && widget.orderManager == null) {
      widget.onInitializeOrdering();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simplified sequential ordering: sort by order number (1, 2, 3...)
    final sortedWaypoints = List<RouteWaypoint>.from(widget.waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedWaypoints.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group waypoints by order, handling choice groups
    final groupedWaypoints = <int, List<RouteWaypoint>>{};
    for (final wp in sortedWaypoints) {
      groupedWaypoints.putIfAbsent(wp.order, () => <RouteWaypoint>[]).add(wp);
    }

    final orderedGroups = groupedWaypoints.keys.toList()..sort();

    final widgets = <Widget>[];
    
    // Calculate waypoint numbers based on order groups (not individual waypoints)
    // Each order group gets one number, and choice groups share that number
    int waypointNumber = 1;
    
    for (int i = 0; i < orderedGroups.length; i++) {
      final order = orderedGroups[i];
      final waypointsAtOrder = groupedWaypoints[order]!;
      
      // Check if this is a choice group (multiple waypoints with same order and choiceGroupId)
      final firstWp = waypointsAtOrder.first;
      final isChoiceGroup = firstWp.choiceGroupId != null && waypointsAtOrder.length > 1;
      final isLastGroup = i == orderedGroups.length - 1;
      
      if (isChoiceGroup) {
        // Display choice group with move arrows on header
        widgets.add(
          _SidebarChoiceGroup(
            key: ValueKey('choice_${firstWp.choiceGroupId}'),
            waypoints: waypointsAtOrder,
            choiceLabel: firstWp.choiceLabel ?? 'Choose an option',
            onEdit: widget.onEdit,
            onMoveUp: widget.canMoveUp(firstWp.id) ? () => widget.onMoveUp(firstWp.id) : null,
            onMoveDown: widget.canMoveDown(firstWp.id) ? () => widget.onMoveDown(firstWp.id) : null,
            onTravelModeChanged: widget.onTravelModeChanged,
            onUngroup: widget.onUngroup != null && firstWp.choiceGroupId != null 
                ? () => widget.onUngroup!(firstWp.choiceGroupId!) 
                : null,
            groupNumber: waypointNumber, // All waypoints in group share this number
            showConnectingLine: !isLastGroup, // Show line if not last group
          ),
        );
        waypointNumber++; // Increment for next group
      } else {
        // Display individual waypoint with move arrows
        for (int j = 0; j < waypointsAtOrder.length; j++) {
          final wp = waypointsAtOrder[j];
          final isLastInOrderGroup = j == waypointsAtOrder.length - 1;
          // Check if there are other waypoints available to group with
          final availableForGrouping = widget.waypoints.where((other) {
            if (other.id == wp.id) return false; // Exclude self
            if (wp.choiceGroupId != null && other.choiceGroupId == wp.choiceGroupId) return false; // Exclude same group
            return true;
          }).isNotEmpty;
          
          widgets.add(
            SidebarWaypointTile(
              key: ValueKey(wp.id),
              waypoint: wp,
              onEdit: () => widget.onEdit(wp),
              onMoveUp: widget.canMoveUp(wp.id) ? () => widget.onMoveUp(wp.id) : null,
              onMoveDown: widget.canMoveDown(wp.id) ? () => widget.onMoveDown(wp.id) : null,
              onAddAlternative: (widget.onAddAlternative != null && availableForGrouping) 
                  ? () => widget.onAddAlternative!(wp) 
                  : null,
              waypointNumber: waypointNumber, // Individual waypoint gets its own number
              showConnectingLine: !isLastGroup || !isLastInOrderGroup, // Show line if not last
              isLastInGroup: isLastInOrderGroup,
            ),
          );
        }
        waypointNumber++; // Increment for next group
      }
    }
    
    return Column(children: widgets);
  }
}

class _SidebarChoiceGroup extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final String choiceLabel;
  final void Function(RouteWaypoint) onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final List<RouteWaypoint>? previousWaypoints;
  final Future<void> Function(RouteWaypoint waypoint, String newMode)? onTravelModeChanged;
  final VoidCallback? onUngroup;
  final int? groupNumber; // Number badge for this choice group
  final bool showConnectingLine; // Whether to show connecting line below

  const _SidebarChoiceGroup({
    super.key,
    required this.waypoints,
    required this.choiceLabel,
    required this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.previousWaypoints,
    this.onTravelModeChanged,
    this.onUngroup,
    this.groupNumber,
    this.showConnectingLine = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use the first waypoint's color for the group number badge
    final groupColor = waypoints.isNotEmpty 
        ? getWaypointColor(waypoints.first.type)
        : Colors.blue;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connecting line above group (if groupNumber is set)
              if (groupNumber != null)
                Container(
                  width: 2,
                  height: 8,
                  margin: const EdgeInsets.only(left: 14),
                  color: Colors.grey.shade300,
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    // Number badge for the group
                    if (groupNumber != null)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vertical line
                          Positioned(
                            left: 14,
                            top: -8,
                            bottom: -8,
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          // Number badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: groupColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '$groupNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (groupNumber != null) const SizedBox(width: 10),
                    if (onMoveUp != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: onMoveUp,
                        tooltip: 'Move group up',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    if (onMoveDown != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: onMoveDown,
                        tooltip: 'Move group down',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        choiceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    Text(
                      '(${waypoints.length} options)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (onUngroup != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: onUngroup,
                        tooltip: 'Ungroup waypoints',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: Colors.blue.shade700,
                      ),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final wp in waypoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Waypoints in choice group don't show individual numbers - they share the group number
                        Row(
                          children: [
                            // Indent for grouped waypoints
                            SizedBox(
                              width: groupNumber != null ? 38 : 0, // Space for number badge
                            ),
                            Icon(Icons.radio_button_unchecked, size: 16, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SidebarWaypointTile(
                                waypoint: wp,
                                onEdit: () => onEdit(wp),
                                onMoveUp: null,
                                onMoveDown: null,
                                waypointNumber: null, // No individual number in choice group
                                showConnectingLine: false,
                                isLastInGroup: wp == waypoints.last,
                              ),
                            ),
                          ],
                        ),
                        // Travel info removed - no longer showing duration/distance
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
      // Connecting line below group (if showConnectingLine is true)
      if (showConnectingLine && groupNumber != null)
        Container(
          width: 2,
          height: 8,
          margin: const EdgeInsets.only(left: 14),
          color: Colors.grey.shade300,
        ),
    ],
    );
  }
}

class _SelectWaypointForGroupDialog extends StatelessWidget {
  final List<RouteWaypoint> availableWaypoints;
  final RouteWaypoint sourceWaypoint;

  const _SelectWaypointForGroupDialog({
    required this.availableWaypoints,
    required this.sourceWaypoint,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollBlockingDialog(
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group as Choice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a waypoint to group with "${sourceWaypoint.name}"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ScrollBlockingScrollView(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: availableWaypoints.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final waypoint = availableWaypoints[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(waypoint),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: getWaypointColor(waypoint.type),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                getWaypointIcon(waypoint.type),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    waypoint.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    getWaypointLabel(waypoint.type),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
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

