import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/components/waypoint/unified_waypoint_card.dart';
import 'package:waypoint/components/builder/day_timeline_section.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/integrations/mapbox_service.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/services/link_preview_service.dart';
import 'package:waypoint/presentation/widgets/link_preview_card.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/utils/google_link_parser.dart';
import 'package:waypoint/services/storage_service.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:waypoint/integrations/mapbox_config.dart';

class BuilderScreen extends StatefulWidget {
final String? editPlanId;
const BuilderScreen({super.key, this.editPlanId});

@override
State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> with SingleTickerProviderStateMixin {
final PageController _pageController = PageController();
int _currentStep = 0;
bool _isSaving = false;
bool _isLoadingExisting = false;
bool _isInitializing = true;

// Save state (manual save on Next button)
DateTime? _lastSavedAt;
String _saveStatus = ''; // 'Saving...', 'Saved', 'Failed to save'

/// Returns the appropriate time label based on activity category
String _getActivityTimeLabel() {
  switch (_activityCategory) {
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
  switch (_activityCategory) {
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

final _nameCtrl = TextEditingController();
final _locationCtrl = TextEditingController();
final _locationFocusNode = FocusNode();
List<PlaceSuggestion>? _locationSuggestions;
bool _searchingLocation = false;
double? _locationLat;
double? _locationLng;
Timer? _locationDebounceTimer; // Debounce timer for location search
final _descCtrl = TextEditingController();
final _heroCtrl = TextEditingController();
final _priceCtrl = TextEditingController(text: '2.00');

final List<_VersionFormData> _versions = [];
int _activeVersionIndex = 0;

final _auth = FirebaseAuthManager();
final _planService = PlanService();
final _userService = UserService();
final _storageService = StorageService();
Plan? _editingPlan;

// Cover image state
Uint8List? _coverImageBytes;
String? _coverImageExtension;
bool _uploadingCoverImage = false;

// Publish status (for draft/publish toggle)
bool _isPublished = true;

// Activity categorization (plan-level)
ActivityCategory? _activityCategory;
AccommodationType? _accommodationType;
  
  // Current day being edited in Step 5
  int _currentDayIndex = 0;

@override
void dispose() {
_locationDebounceTimer?.cancel(); // Cancel debounce timer
_pageController.removeListener(_onPageChanged);
_pageController.dispose();
_nameCtrl.dispose();
_locationCtrl.dispose();
_locationFocusNode.dispose();
_descCtrl.dispose();
_heroCtrl.dispose();
for (final v in _versions) {
v.dispose();
}
super.dispose();
}

@override
void initState() {
super.initState();
// Add PageController listener to keep _currentStep in sync
_pageController.addListener(_onPageChanged);

if (widget.editPlanId != null) {
_loadExistingPlan(widget.editPlanId!);
} else {
final initialVersion = _VersionFormData.initial();
// Add listeners to update button state AND trigger auto-save
_addVersionListeners(initialVersion);
_versions.add(initialVersion);
// Delay to allow validation to run after first build
Future.delayed(const Duration(milliseconds: 100), () {
if (mounted) setState(() => _isInitializing = false);
});
}
// Add listeners to update state when required fields change
_nameCtrl.addListener(() => setState(() {}));
_locationCtrl.addListener(() => setState(() {}));
_descCtrl.addListener(() => setState(() {}));
_priceCtrl.addListener(() => setState(() {}));
_heroCtrl.addListener(() => setState(() {}));
}

/// Add listeners to version form data for UI updates
void _addVersionListeners(_VersionFormData vf) {
vf.duration.addListener(() => setState(() {}));
vf.name.addListener(() => setState(() {}));
}

/// Add listeners to FAQ form data for UI updates
void _addFaqListeners(_FAQFormData faq) {
faq.questionCtrl.addListener(() => setState(() {}));
faq.answerCtrl.addListener(() => setState(() {}));
}

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
_editingPlan = plan;
_nameCtrl.text = plan.name;
_locationCtrl.text = plan.location;
_descCtrl.text = plan.description;
_heroCtrl.text = plan.heroImageUrl;
_priceCtrl.text = plan.basePrice.toStringAsFixed(2);
_isPublished = plan.isPublished;
_activityCategory = plan.activityCategory;
_accommodationType = plan.accommodationType;
_versions.clear();
if (plan.versions.isNotEmpty) {
for (var i = 0; i < plan.versions.length; i++) {
final v = plan.versions[i];
final form = _VersionFormData.fromVersion(v);
// Add listeners to update button state AND trigger auto-save
_addVersionListeners(form);
for (final d in v.days) {
// Load title and description
form.titleCtrl(d.dayNum).text = d.title;
form.descCtrl(d.dayNum).text = d.description;

        // CRITICAL: Keep existing route in form state so POIs/sections show up
        if (d.route != null) {
          form.routeByDay[d.dayNum] = d.route!;
          Log.i('builder', 'Loaded route for day ${d.dayNum} with ${d.route!.poiWaypoints.length} waypoints');
        } else {
          Log.w('builder', 'Day ${d.dayNum} has no route data');
        }

// Load existing day image URL
if (d.photos.isNotEmpty) {
form.existingDayImageUrls[d.dayNum] = d.photos.first;
}

if (d.startLat != null && d.startLng != null) {
form.startForDay[d.dayNum] = ll.LatLng(d.startLat!, d.startLng!);
}
if (d.endLat != null && d.endLng != null) {
form.endForDay[d.dayNum] = ll.LatLng(d.endLat!, d.endLng!);
}
form.distanceCtrl(d.dayNum).text = d.distanceKm.toStringAsFixed(2);
if (d.estimatedTimeMinutes > 0) {
final hours = (d.estimatedTimeMinutes / 60.0);
form.timeCtrl(d.dayNum).text = hours.toStringAsFixed(1);
}
if (d.stay != null) {
final s = d.stay!;
form.stayUrlCtrl(d.dayNum).text = s.bookingLink ?? '';
if (s.cost != null) {
form.stayCostCtrl(d.dayNum).text = s.cost!.toStringAsFixed(2);
}
if ((s.linkTitle ?? s.linkDescription ?? s.linkImageUrl) != null) {
form.stayMetaByDay[d.dayNum] = LinkPreviewData(
url: s.bookingLink ?? '',
title: s.linkTitle,
description: s.linkDescription,
imageUrl: s.linkImageUrl,
siteName: s.linkSiteName,
);
}
}
// Load accommodations
form.accommodationsByDay[d.dayNum] = d.accommodations.map((a) => _AccommodationFormData.fromModel(a)).toList();
// Load restaurants
form.restaurantsByDay[d.dayNum] = d.restaurants.map((r) => _RestaurantFormData.fromModel(r)).toList();
// Load activities
form.activitiesByDay[d.dayNum] = d.activities.map((a) => _ActivityFormData.fromModel(a)).toList();
}
// Load transportation options
form.transportationOptions.addAll(
v.transportationOptions.map((t) => _TransportationFormData.fromModel(t)).toList(),
);
// Load FAQ items from plan level (only for first version in UI)
if (i == 0) {
final faqForms = plan.faqItems.map((f) => _FAQFormData.fromModel(f)).toList();
// Add listeners to FAQ items for auto-save
for (final faq in faqForms) {
_addFaqListeners(faq);
}
form.faqItems.addAll(faqForms);
}
_versions.add(form);
}
} else {
final initialVersion = _VersionFormData.initial();
// Add listeners to update button state AND trigger auto-save
_addVersionListeners(initialVersion);
_versions.add(initialVersion);
}
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

/// Validate if current step has all required fields filled
bool _canProceedFromCurrentStep() {
switch (_currentStep) {
case 0: // Step 1: General Info
final priceValid = (double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? -1) >= 0;
// When editing, we trust the existing location; when creating new, require lat/lng from Mapbox
final locationValid = _editingPlan != null
? _locationCtrl.text.trim().isNotEmpty
: (_locationCtrl.text.trim().isNotEmpty && _locationLat != null && _locationLng != null);
return _nameCtrl.text.trim().isNotEmpty &&
locationValid &&
_descCtrl.text.trim().isNotEmpty &&
priceValid;
// Cover image is now optional
case 1: // Step 2: Versions
if (_versions.isEmpty) return false;
// Check if at least one version has valid duration
for (final v in _versions) {
final duration = int.tryParse(v.duration.text) ?? 0;
if (duration > 0) return true;
}
return false;
case 2: // Step 3: What to Pack
return true; // Optional, can skip
case 3: // Step 4: How to Get There
return true; // Optional, can skip
case 4: // Step 5: Days
return true; // No strict validation
case 5: // Step 6: Overview
return true; // Can always proceed from overview (validation happens on publish)
default:
return false;
}
}

@override
Widget build(BuildContext context) {
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
// Step Progress Indicator (centered, modern)
_buildStepProgressIndicator(),
// Content
Expanded(
child: PageView(
controller: _pageController,
physics: const NeverScrollableScrollPhysics(),
children: [
_buildStep1General(),
_buildStep2Versions(),
_buildStep3Packing(),
_buildStep4Transport(),
_buildStep5Days(),
_buildStep6Overview(),
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
if (_currentStep > 0)
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
onPressed: (_isInitializing || _isSaving || (_currentStep < 5 && !_canProceedFromCurrentStep()))
? null
: () async {
            if (_currentStep < 5) {
if (!_canProceedFromCurrentStep()) {
String message = '';
switch (_currentStep) {
case 0:
if (_nameCtrl.text.trim().isEmpty) {
message = 'Please enter an adventure name';
} else if (_locationCtrl.text.trim().isEmpty || _locationLat == null) {
message = 'Please search and select a location from the dropdown';
} else if (_descCtrl.text.trim().isEmpty) {
message = 'Please enter a description';
}
break;
case 1:
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
child: _isSaving
? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
_currentStep == 5 ? (widget.editPlanId != null ? 'Save Changes' : "Publish Adventure") : "Next",
style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
),
const SizedBox(width: 8),
Icon(_currentStep == 5 ? Icons.check : Icons.arrow_forward, size: 18),
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
final steps = ['General Info', 'Versions', 'What to Pack', 'How to Get There', 'Days', 'Overview'];

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
color: _currentStep > lineIndex ? const Color(0xFF428A13) : const Color(0xFFE5EBE5),
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
final isClickable = true; // All steps are now clickable

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
? const Color(0xFF428A13)
: Colors.white,
border: Border.all(
color: isCompleted || isActive
? const Color(0xFF428A13)
: const Color(0xFFE5EBE5),
width: 2,
),
boxShadow: isActive ? [
BoxShadow(
color: const Color(0xFF428A13).withValues(alpha: 0.15),
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
color: isActive ? const Color(0xFF428A13) : const Color(0xFF8A8A8A),
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

Widget _buildStep1General() {
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

_buildTextField("Adventure Name", "e.g., The Arctic Trail", controller: _nameCtrl, required: true),
const SizedBox(height: 16),
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
_buildTextField("Location", "Search a place…", controller: _locationCtrl, focusNode: _locationFocusNode, required: true),
const SizedBox(height: 6),
_searchingLocation
? const LinearProgressIndicator(minHeight: 2)
: const SizedBox.shrink(),
if ((_locationSuggestions?.isNotEmpty ?? false))
Container(
decoration: BoxDecoration(
color: context.colors.surface,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: context.colors.outlineVariant),
),
constraints: const BoxConstraints(maxHeight: 220),
child: ListView.builder(
shrinkWrap: true,
itemCount: _locationSuggestions?.length ?? 0,
itemBuilder: (context, index) {
final s = _locationSuggestions![index];
return ListTile(
dense: true,
leading: const Icon(Icons.place),
title: Text(s.text),
subtitle: Text(s.placeName),
onTap: () {
// Remove listener to prevent re-triggering search
_locationCtrl.removeListener(_onLocationChanged);

setState(() {
_locationCtrl.text = s.placeName;
_locationLat = s.latitude;
_locationLng = s.longitude;
_locationSuggestions = null;
});

// Re-add listener after a short delay
Future.delayed(const Duration(milliseconds: 100), () {
if (mounted) {
_locationCtrl.addListener(_onLocationChanged);
}
});
},
);
},
),
),
]),
const SizedBox(height: 16),
_buildTextField("Description", "Describe the experience...", controller: _descCtrl, maxLines: 8, required: true),
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
onTap: _uploadingCoverImage ? null : _pickCoverImage,
child: Container(
height: 200,
decoration: BoxDecoration(
color: (_coverImageBytes != null || _heroCtrl.text.trim().isNotEmpty)
? Colors.black
: context.colors.surfaceContainerHighest,
borderRadius: BorderRadius.circular(AppRadius.md),
border: Border.all(color: context.colors.outline, style: BorderStyle.solid),
image: _coverImageBytes != null
? DecorationImage(
image: MemoryImage(_coverImageBytes!),
fit: BoxFit.cover,
)
: _heroCtrl.text.trim().isNotEmpty
? DecorationImage(
image: NetworkImage(_heroCtrl.text.trim()),
fit: BoxFit.cover,
)
: null,
),
child: _uploadingCoverImage
? const Center(child: CircularProgressIndicator())
: (_coverImageBytes == null && _heroCtrl.text.trim().isEmpty)
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
onPressed: () => setState(() {
_coverImageBytes = null;
_coverImageExtension = null;
_heroCtrl.clear();
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
_buildTextField("Or paste Image URL", "https://...", controller: _heroCtrl, required: false),
const SizedBox(height: 24),
_buildTextField("Price (€)", "2.00", controller: _priceCtrl, isNumber: true, required: true),
const SizedBox(height: 8),
Text(
"This is the price for purchasing this adventure plan",
style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
),
const SizedBox(height: 32),

// Activity Categorization Section
_buildActivityCategoryField(),
const SizedBox(height: 16),
if (_activityCategory != null &&
_activityCategory != ActivityCategory.cityTrips &&
_activityCategory != ActivityCategory.tours &&
_activityCategory != ActivityCategory.roadTripping) ...[
_buildAccommodationTypeField(),
const SizedBox(height: 32),
],

// FAQ Section
Text("Frequently Asked Questions", style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Text("Add helpful information for travelers", style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700)),
const SizedBox(height: 16),
_buildGeneralInfoFAQSection(),
],
),
),
),
),
);
}

Widget _buildStep2Versions() {
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
...List.generate(_versions.length, (index) => _buildVersionCard(index)),
const SizedBox(height: 16),
OutlinedButton.icon(
onPressed: () {
final newVersion = _VersionFormData.initial();
// Add listeners to update button state
_addVersionListeners(newVersion);
setState(() {
_versions.add(newVersion);
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
Widget _buildStep3Packing() {
  if (_versions.isEmpty) {
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
Widget _buildStep4Transport() {
  if (_versions.isEmpty) {
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
            // Transportation content
            Expanded(child: _buildTransportationTab()),
          ],
        ),
      );
    },
  );
}

// Step 5: Days (with day tabs)
Widget _buildStep5Days() {
  if (_versions.isEmpty) {
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
  
  // Ensure active version index is valid
  if (_activeVersionIndex >= _versions.length) {
    _activeVersionIndex = 0;
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
            value: _activeVersionIndex.clamp(0, _versions.length - 1),
            isExpanded: true,
            items: List.generate(
              _versions.length,
              (i) => DropdownMenuItem(
                value: i,
                child: Text('Version ${i + 1}: ${_versions[i].name.text.isEmpty ? 'Untitled' : _versions[i].name.text}'),
              ),
            ),
            onChanged: (v) => setState(() => _activeVersionIndex = v ?? 0),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPackingTab() {
final vf = _versions[_activeVersionIndex];

return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 900),
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Organize packing items by category',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),

// Packing categories
...vf.packingCategories.asMap().entries.map((entry) {
final index = entry.key;
final category = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildPackingCategoryCard(vf, index, category),
);
}),

// Add category button
OutlinedButton.icon(
onPressed: () {
setState(() {
vf.packingCategories.add(_PackingCategory(
name: 'Category ${vf.packingCategories.length + 1}',
items: [],
));
});
},
icon: const Icon(Icons.add),
label: const Text('Add Packing Category'),
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
'Tip: Create categories like "Insurance", "Clothing", "Equipment" to organize your packing list',
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

Widget _buildPackingCategoryCard(_VersionFormData vf, int index, _PackingCategory category) {
return _PackingCategoryCardWidget(
key: ValueKey(index),
versionFormData: vf,
categoryIndex: index,
category: category,
onUpdate: () {
setState(() {});
},
);
}

Widget _buildTransportationTab() {
final vf = _versions[_activeVersionIndex];

return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 900),
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Add different ways to reach the starting point',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),

// Transportation options
...vf.transportationOptions.asMap().entries.map((entry) {
final index = entry.key;
final option = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildTransportationCard(vf, index, option),
);
}),

// Add option button
OutlinedButton.icon(
onPressed: () {
setState(() {
vf.transportationOptions.add(_TransportationFormData());
});
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

Widget _buildTransportationCard(_VersionFormData vf, int index, _TransportationFormData option) {
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
vf.transportationOptions.removeAt(index);
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

Widget _buildFAQTab() {
final vf = _versions[_activeVersionIndex];

return SingleChildScrollView(
child: Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 900),
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Add frequently asked questions and answers',
style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey.shade700),
),
const SizedBox(height: 24),

// FAQ items
...vf.faqItems.asMap().entries.map((entry) {
final index = entry.key;
final faq = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildFAQCard(vf, index, faq),
);
}),

// Add FAQ button
OutlinedButton.icon(
onPressed: () {
setState(() {
final newFaq = _FAQFormData();
_addFaqListeners(newFaq);
vf.faqItems.add(newFaq);
});
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
),
),
),
),
);
}

Widget _buildFAQCard(_VersionFormData vf, int index, _FAQFormData faq) {
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
setState(() {
vf.faqItems.removeAt(index);
});
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
if (_versions.isEmpty) {
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

// Use the first version's FAQ items
final vf = _versions[0];

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// FAQ items
...vf.faqItems.asMap().entries.map((entry) {
final index = entry.key;
final faq = entry.value;
return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: _buildFAQCard(vf, index, faq),
);
}),

// Add FAQ button
OutlinedButton.icon(
onPressed: () {
setState(() {
final newFaq = _FAQFormData();
_addFaqListeners(newFaq);
vf.faqItems.add(newFaq);
});
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

Widget _buildDaysTab() {
  final vf = _versions[_activeVersionIndex];
  final dayCount = vf.daysCount.clamp(0, 60);
  
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
              final current = int.tryParse(vf.duration.text) ?? 0;
              vf.duration.text = (current + 1).toString();
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
                  final current = int.tryParse(vf.duration.text) ?? 0;
                  vf.duration.text = (current + 1).toString();
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
                      return _buildDayCard(_currentDayIndex + 1, versionIndex: _activeVersionIndex);
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

try {
final vf = _versions[versionIndex];
final titleCtrl = vf.titleCtrl(dayNum);
final descCtrl = vf.descCtrl(dayNum);
final distCtrl = vf.distanceCtrl(dayNum);
final timeCtrl = vf.timeCtrl(dayNum);
final stayUrlCtrl = vf.stayUrlCtrl(dayNum);
final stayCostCtrl = vf.stayCostCtrl(dayNum);
final meta = vf.stayMetaByDay[dayNum];
final existingRoute = vf.routeByDay[dayNum];
final accommodations = vf.accommodationsByDay[dayNum] ?? [];
final restaurants = vf.restaurantsByDay[dayNum] ?? [];
final activities = vf.activitiesByDay[dayNum] ?? [];
final dayImageBytes = vf.dayImagesByDay[dayNum];
final existingImageUrl = vf.existingDayImageUrls[dayNum];
final hasImage = dayImageBytes != null || existingImageUrl != null;

Log.i('builder', 'Day $dayNum: hasRoute=${existingRoute != null}, accommodations=${accommodations.length}, restaurants=${restaurants.length}, activities=${activities.length}');

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
vf.dayImagesByDay.remove(dayNum);
vf.dayImageExtByDay.remove(dayNum);
vf.existingDayImageUrls.remove(dayNum);
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
const SizedBox(height: 16),

// MAP SECTION - Show the route map if route exists or if there are waypoints
if (existingRoute != null || _hasWaypoints(dayNum, vf)) ...[
_buildDayRouteMap(existingRoute, dayNum, vf),
const SizedBox(height: 12),
],

// Route controls below the map
Align(
alignment: Alignment.centerLeft,
child: FilledButton.icon(
onPressed: () async {
Log.i('builder', 'Opening RouteBuilderScreen for day $dayNum');
try {
final planId = _editingPlan?.id ?? 'new';
final route = await context.push<DayRoute>(
'/builder/route-builder/$planId/$_activeVersionIndex/$dayNum',
extra: {
'start': vf.startForDay[dayNum],
'end': vf.endForDay[dayNum],
'initial': vf.routeByDay[dayNum],
'activityCategory': _activityCategory,
},
);
if (route != null && mounted) {
setState(() {
vf.routeByDay[dayNum] = route;
});
final km = (route.distance / 1000.0);
distCtrl.text = km.toStringAsFixed(2);
final hours = route.duration / 3600.0;
timeCtrl.text = hours.toStringAsFixed(1);
}
} catch (e, stack) {
Log.e('builder', 'RouteBuilderScreen failed', e, stack);
}
},
icon: const Icon(Icons.alt_route),
label: Text(existingRoute == null ? 'Create Route' : 'Edit Route'),
),
),
if (existingRoute != null) ...[
const SizedBox(height: 8),
Row(children: [
Icon(Icons.timeline, size: 18, color: context.colors.secondary),
const SizedBox(width: 6),
Text('${(existingRoute.distance / 1000).toStringAsFixed(2)} km • ${_formatDuration(existingRoute.duration)}', style: Theme.of(context).textTheme.bodySmall),
]),
],
const SizedBox(height: 12),
Row(
children: [
Expanded(child: _buildTextField("Distance (km)", "0", isNumber: true, controller: distCtrl, required: false)),
const SizedBox(width: 12),
Expanded(child: _buildTextField(_getActivityTimeLabel(), "0", isNumber: true, controller: timeCtrl, required: false)),
],
),

// WAYPOINTS SECTION - All types combined in one draggable list
const SizedBox(height: 24),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text("Waypoints", style: context.textStyles.titleMedium),
IconButton(
icon: const Icon(Icons.add_circle),
tooltip: 'Add Waypoint',
onPressed: () => _showWaypointTypeDialog(context, dayNum, vf),
),
],
),
const SizedBox(height: 8),
_buildAllWaypointsList(dayNum, vf),
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

Widget _buildAccommodationCard(_AccommodationFormData acc, int dayNum, int idx, _VersionFormData vf) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: const Color(0xFFE5EBE5), width: 1),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Accommodation ${idx + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
IconButton(
icon: const Icon(Icons.delete, size: 20),
style: IconButton.styleFrom(
foregroundColor: Colors.grey.shade600,
),
onPressed: () {
setState(() {
vf.accommodationsByDay[dayNum]?.removeAt(idx);
});
},
),
],
),
const SizedBox(height: 12),
_buildTextField("Name", "e.g., Mountain Lodge", controller: acc.nameCtrl, required: false),
const SizedBox(height: 12),
_buildTextField("Type", "e.g., Hotel, Hostel, Camping", controller: acc.typeCtrl, required: false),
const SizedBox(height: 12),
Row(
children: [
Expanded(child: _buildTextField("URL", "https://...", controller: acc.urlCtrl, required: false)),
const SizedBox(width: 8),
Expanded(child: _buildTextField("Cost (€)", "80", isNumber: true, controller: acc.costCtrl, required: false)),
],
),
],
),
);
}

Widget _buildRestaurantCard(_RestaurantFormData rest, int dayNum, int idx, _VersionFormData vf) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: const Color(0xFFE5EBE5), width: 1),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Restaurant ${idx + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
IconButton(
icon: const Icon(Icons.delete, size: 20),
style: IconButton.styleFrom(
foregroundColor: Colors.grey.shade600,
),
onPressed: () {
setState(() {
vf.restaurantsByDay[dayNum]?.removeAt(idx);
});
},
),
],
),
const SizedBox(height: 8),
_buildTextField("Name", "e.g., Lakeside Cafe", controller: rest.nameCtrl, required: false),
const SizedBox(height: 8),
DropdownButtonFormField<MealType>(
value: rest.mealType,
decoration: const InputDecoration(
labelText: 'Meal Type',
border: OutlineInputBorder(),
),
items: MealType.values.map((type) => DropdownMenuItem(
value: type,
child: Text(type.name[0].toUpperCase() + type.name.substring(1)),
)).toList(),
onChanged: (v) {
if (v != null) setState(() => rest.mealType = v);
},
),
const SizedBox(height: 8),
Row(
children: [
Expanded(child: _buildTextField("URL", "https://...", controller: rest.urlCtrl, required: false)),
const SizedBox(width: 8),
Expanded(child: _buildTextField("Cost (€)", "25", isNumber: true, controller: rest.costCtrl, required: false)),
],
),
],
),
);
}

Widget _buildActivityCard(_ActivityFormData act, int dayNum, int idx, _VersionFormData vf) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: const Color(0xFFE5EBE5), width: 1),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Activity ${idx + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
IconButton(
icon: const Icon(Icons.delete, size: 20),
style: IconButton.styleFrom(
foregroundColor: Colors.grey.shade600,
),
onPressed: () {
setState(() {
vf.activitiesByDay[dayNum]?.removeAt(idx);
});
},
),
],
),
const SizedBox(height: 12),
_buildTextField("Name", "e.g., Kayaking", controller: act.nameCtrl, required: false),
const SizedBox(height: 12),
_buildTextField("Description", "What happens...", maxLines: 2, controller: act.descCtrl, required: false),
const SizedBox(height: 12),
Row(
children: [
Expanded(child: _buildTextField("URL", "https://...", controller: act.urlCtrl, required: false)),
const SizedBox(width: 8),
Expanded(child: _buildTextField("Cost (€)", "40", isNumber: true, controller: act.costCtrl, required: false)),
],
),
],
),
);
}

/// Check if there are any waypoints for a day (even without route)
bool _hasWaypoints(int dayNum, _VersionFormData vf) {
final existingRoute = vf.routeByDay[dayNum];
if (existingRoute == null) return false;
return existingRoute.poiWaypoints.isNotEmpty;
}

/// Build a map widget showing the day's route and waypoints
Widget _buildDayRouteMap(DayRoute? route, int dayNum, _VersionFormData vf) {
  // Parse geometry coordinates to LatLng
  List<ll.LatLng> routeCoordinates = [];
  if (route != null) {
    try {
      final coords = route.geometry['coordinates'];
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
      Log.e('builder', 'Failed to parse route geometry', e);
    }
  }

  // Parse POI waypoints
  final existingRoute = vf.routeByDay[dayNum];
  final poiWaypoints = existingRoute != null
      ? existingRoute.poiWaypoints
          .map((json) => RouteWaypoint.fromJson(json))
          .toList()
      : <RouteWaypoint>[];

  // Calculate map center from route or waypoints
  ll.LatLng center;
  if (routeCoordinates.isNotEmpty) {
    final midIndex = routeCoordinates.length ~/ 2;
    center = routeCoordinates[midIndex];
  } else if (poiWaypoints.isNotEmpty) {
    center = poiWaypoints.first.position;
  } else {
    center = const ll.LatLng(61.0, 8.5); // Default fallback
  }

  return Container(
    height: 300,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: fm.FlutterMap(
      options: fm.MapOptions(
        initialCenter: center,
        initialZoom: 11,
        interactionOptions: const fm.InteractionOptions(
          flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
        ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken',
          userAgentPackageName: 'com.waypoint.app',
          tileSize: 512,
          zoomOffset: -1,
        ),
        // Route polyline
        if (routeCoordinates.isNotEmpty)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: routeCoordinates,
                color: const Color(0xFF4CAF50),
                strokeWidth: 5,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        // Start/End markers from route points
        if (route != null && route.routePoints.isNotEmpty)
          fm.MarkerLayer(
            markers: [
              // Start marker (A) - Largest for route endpoints
              fm.Marker(
                point: ll.LatLng(
                  route.routePoints.first['lat']!,
                  route.routePoints.first['lng']!,
                ),
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788), // Success green
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // End marker (B) - Largest for route endpoints
              if (route.routePoints.length > 1)
                fm.Marker(
                  point: ll.LatLng(
                    route.routePoints.last['lat']!,
                    route.routePoints.last['lng']!,
                  ),
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828), // Error red
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        // Custom POI waypoint markers - Prominent but smaller than Start/End
        if (poiWaypoints.isNotEmpty)
          fm.MarkerLayer(
            markers: poiWaypoints
                .map((wp) => fm.Marker(
                      point: wp.position,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: getWaypointColor(wp.type),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: getWaypointColor(wp.type).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            getWaypointIcon(wp.type),
                            color: getWaypointColor(wp.type),
                            size: 18,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
      ],
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
value: _activityCategory,
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
setState(() {
_activityCategory = value;
// Auto-set accommodation type for city trips, tours, and road tripping
if (value == ActivityCategory.cityTrips || value == ActivityCategory.tours || value == ActivityCategory.roadTripping) {
_accommodationType = AccommodationType.comfort;
}
// Clear accommodation type when category is cleared
if (value == null) {
_accommodationType = null;
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
value: _accommodationType,
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
setState(() {
_accommodationType = value;
});
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

Future<List<DayItinerary>> _composeDays(_VersionFormData vf, String planId, {List<DayItinerary> existing = const []}) async {
final duration = vf.daysCount;
final byNum = {for (final d in existing) d.dayNum: d};
final days = <DayItinerary>[];
for (int i = 1; i <= duration; i++) {
final prev = byNum[i];
final start = vf.startForDay[i];
final end = vf.endForDay[i];

// Upload day image if new bytes are available, otherwise use existing URL
final imageBytes = vf.dayImagesByDay[i];
final existingUrl = vf.existingDayImageUrls[i];
String? dayImageUrl;

if (imageBytes != null) {
// New image selected, upload it
try {
Log.i('builder', 'Uploading image for day $i...');
final extension = vf.dayImageExtByDay[i] ?? 'jpg';
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
final link = vf.stayUrlCtrl(i).text.trim();
final cost = double.tryParse(vf.stayCostCtrl(i).text.replaceAll(',', '.'));
final meta = vf.stayMetaByDay[i];
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

// Build accommodations list
final accommodations = (vf.accommodationsByDay[i] ?? []).map((a) {
return AccommodationInfo(
name: a.nameCtrl.text.trim().isEmpty ? 'Unnamed' : a.nameCtrl.text.trim(),
type: a.typeCtrl.text.trim().isEmpty ? 'Hotel' : a.typeCtrl.text.trim(),
bookingLink: a.urlCtrl.text.trim().isEmpty ? null : a.urlCtrl.text.trim(),
cost: double.tryParse(a.costCtrl.text.replaceAll(',', '.')),
);
}).toList();

// Build restaurants list
final restaurants = (vf.restaurantsByDay[i] ?? []).map((r) {
return RestaurantInfo(
name: r.nameCtrl.text.trim().isEmpty ? 'Unnamed' : r.nameCtrl.text.trim(),
mealType: r.mealType,
bookingLink: r.urlCtrl.text.trim().isEmpty ? null : r.urlCtrl.text.trim(),
cost: double.tryParse(r.costCtrl.text.replaceAll(',', '.')),
);
}).toList();

// Build activities list
final activities = (vf.activitiesByDay[i] ?? []).map((a) {
return ActivityInfo(
name: a.nameCtrl.text.trim().isEmpty ? 'Unnamed' : a.nameCtrl.text.trim(),
description: a.descCtrl.text.trim().isEmpty ? '' : a.descCtrl.text.trim(),
bookingLink: a.urlCtrl.text.trim().isEmpty ? null : a.urlCtrl.text.trim(),
cost: double.tryParse(a.costCtrl.text.replaceAll(',', '.')),
);
}).toList();

days.add(DayItinerary(
dayNum: i,
title: vf.titleCtrl(i).text.trim().isEmpty ? (prev?.title ?? 'Day $i') : vf.titleCtrl(i).text.trim(),
description: vf.descCtrl(i).text.trim().isEmpty ? (prev?.description ?? '') : vf.descCtrl(i).text.trim(),
distanceKm: double.tryParse(vf.distanceCtrl(i).text.replaceAll(',', '.')) ?? (prev?.distanceKm ?? 0),
estimatedTimeMinutes: ((double.tryParse(vf.timeCtrl(i).text.replaceAll(',', '.')) ?? (prev?.estimatedTimeMinutes ?? 0).toDouble()) * 60).toInt(),
stay: stay,
accommodations: accommodations,
restaurants: restaurants,
activities: activities,
photos: dayImageUrl != null ? [dayImageUrl] : (prev?.photos ?? const []),
startLat: start?.latitude ?? prev?.startLat,
startLng: start?.longitude ?? prev?.startLng,
endLat: end?.latitude ?? prev?.endLat,
endLng: end?.longitude ?? prev?.endLng,
route: vf.routeByDay[i] ?? prev?.route,
));
}
return days;
}

Future<void> _publishPlan(BuildContext context) async {
final uuid = const Uuid();
final name = _nameCtrl.text.trim();
final location = _locationCtrl.text.trim();
final desc = _descCtrl.text.trim();
if (name.isEmpty || location.isEmpty || desc.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields.')));
return;
}
// Cover image is now optional - no validation needed
if (_versions.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one version.')));
return;
}

final userId = _auth.currentUserId;
if (userId == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to publish.')));
return;
}

setState(() => _isSaving = true);
try {
final userModel = await _userService.getUserById(userId);
final creatorName = userModel?.displayName ?? 'Creator';

// Generate temporary plan ID for storage paths
final tempPlanId = uuid.v4();

// Upload cover image if bytes are available
String heroImageUrl;
if (_coverImageBytes != null) {
try {
Log.i('builder', 'Uploading cover image...');
final path = _storageService.coverImagePath(tempPlanId, _coverImageExtension ?? 'jpg');
heroImageUrl = await _storageService.uploadImage(
path: path,
bytes: _coverImageBytes!,
contentType: 'image/${_coverImageExtension ?? 'jpeg'}',
);
Log.i('builder', 'Cover image uploaded successfully');
} catch (e, stack) {
Log.e('builder', 'Cover image upload failed', e, stack);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to upload cover image: ${e.toString().split('\n').first}')),
);
}
setState(() => _isSaving = false);
return;
}
} else {
heroImageUrl = _heroCtrl.text.trim().isEmpty
? 'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?q=80&w=2070&auto=format&fit=crop'
: _heroCtrl.text.trim();
}

final versions = <PlanVersion>[];
// Get plan-level price
final planPrice = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? -1;
if (planPrice < 0) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid price for the plan.')));
setState(() => _isSaving = false);
return;
}

for (final vf in _versions) {
final duration = vf.daysCount;
if (duration <= 0) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid duration for each version.')));
setState(() => _isSaving = false);
return;
}

// Compose days and upload day images
final days = await _composeDays(vf, tempPlanId);

versions.add(PlanVersion(
id: uuid.v4(),
name: vf.name.text.trim().isEmpty ? 'Default' : vf.name.text.trim(),
durationDays: duration,
difficulty: Difficulty.none, // Deprecated - removed from version
comfortType: ComfortType.none, // Deprecated - removed from version
price: planPrice, // Price is stored at plan level
days: days,
packingCategories: _composePackingCategories(vf),
transportationOptions: _composeTransportationOptions(vf),
faqItems: const [], // FAQ is stored at plan level
));
}

// Extract FAQ items from first version to save at plan level
final planFaqItems = _versions.isNotEmpty ? _composeFAQItems(_versions.first) : <FAQItem>[];

final now = DateTime.now();
final plan = Plan(
id: 'temp',
name: name,
description: desc,
heroImageUrl: heroImageUrl,
location: location,
basePrice: versions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
creatorId: userId,
creatorName: creatorName,
versions: versions,
isFeatured: false,
isPublished: _isPublished,
createdAt: now,
updatedAt: now,
activityCategory: _activityCategory,
accommodationType: _accommodationType,
faqItems: planFaqItems,
);

Log.i('builder', 'Creating plan document...');
final planId = await _planService.createPlan(plan);
await _userService.addCreatedPlan(userId, planId);

if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adventure published successfully!')));
context.go('/mytrips');
} catch (e, stack) {
Log.e('builder', 'Failed to publish plan', e, stack);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish. Please try again.')));
} finally {
if (mounted) setState(() => _isSaving = false);
}
}


Future<void> _saveChanges(BuildContext context) async {
final name = _nameCtrl.text.trim();
final location = _locationCtrl.text.trim();
final desc = _descCtrl.text.trim();
if (name.isEmpty || location.isEmpty || desc.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields.')));
return;
}
if (_versions.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one version.')));
return;
}

if (_editingPlan == null) return;

setState(() => _isSaving = true);
try {
// Get plan-level price
final planPrice = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? -1;
if (planPrice < 0) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
setState(() => _isSaving = false);
return;
}

// Upload new cover image if user selected one
String heroImageUrl = _editingPlan!.heroImageUrl;
if (_coverImageBytes != null) {
try {
Log.i('builder', 'Uploading new cover image...');
final path = _storageService.coverImagePath(_editingPlan!.id, _coverImageExtension ?? 'jpg');
heroImageUrl = await _storageService.uploadImage(
path: path,
bytes: _coverImageBytes!,
contentType: 'image/${_coverImageExtension ?? 'jpeg'}',
);
Log.i('builder', 'Cover image uploaded successfully');
} catch (e) {
Log.w('builder', 'Failed to upload cover image: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Failed to upload cover image. Using existing image.')),
);
}
}
} else if (_heroCtrl.text.trim().isNotEmpty) {
// User pasted a new URL
heroImageUrl = _heroCtrl.text.trim();
}

final updatedVersions = <PlanVersion>[];
for (var i = 0; i < _versions.length; i++) {
final vf = _versions[i];
final prev = i < _editingPlan!.versions.length ? _editingPlan!.versions[i] : null;
final duration = vf.daysCount;
if (duration <= 0) continue;
final id = prev?.id ?? const Uuid().v4();
updatedVersions.add(PlanVersion(
id: id,
name: vf.name.text.trim().isEmpty ? (prev?.name ?? 'Default') : vf.name.text.trim(),
durationDays: duration,
difficulty: Difficulty.none, // Deprecated - removed from version
comfortType: ComfortType.none, // Deprecated - removed from version
price: planPrice, // Price is stored at plan level
days: await _composeDays(vf, _editingPlan!.id, existing: prev?.days ?? const []),
packingCategories: _composePackingCategories(vf, fallback: prev?.packingCategories ?? const []),
transportationOptions: _composeTransportationOptions(vf),
faqItems: const [], // FAQ is stored at plan level
));
}

// Extract FAQ items from first version to save at plan level
final planFaqItems = _versions.isNotEmpty ? _composeFAQItems(_versions.first) : <FAQItem>[];

final updated = _editingPlan!.copyWith(
name: name,
description: desc,
heroImageUrl: heroImageUrl,
location: location,
basePrice: updatedVersions.isEmpty ? _editingPlan!.basePrice : updatedVersions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
versions: updatedVersions.isEmpty ? _editingPlan!.versions : updatedVersions,
isPublished: _isPublished,
updatedAt: DateTime.now(),
activityCategory: _activityCategory,
accommodationType: _accommodationType,
faqItems: planFaqItems,
);
// Use updatePlanWithVersions to save versions and days to subcollections
await _planService.updatePlanWithVersions(updated);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved')));
context.go('/builder');
} catch (e) {
debugPrint('Failed to save changes: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save changes')));
}
} finally {
if (mounted) setState(() => _isSaving = false);
}
}

/// Saves the current draft state without validation
/// Allows users to save progress at any point in the creation process
Future<void> _saveDraft(BuildContext context) async {
final userId = _auth.currentUserId;
if (userId == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please sign in to save drafts')),
);
return;
}

setState(() => _isSaving = true);
try {
final uuid = const Uuid();
final name = _nameCtrl.text.trim().isEmpty ? 'Untitled Adventure' : _nameCtrl.text.trim();
final location = _locationCtrl.text.trim();
final desc = _descCtrl.text.trim();

// Get user info for creator name
final userModel = await _userService.getUserById(userId);
final creatorName = userModel?.displayName ?? 'Unknown';

// Upload cover image if available
String heroImageUrl = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800';
if (_coverImageBytes != null) {
try {
Log.i('builder', 'Uploading cover image for draft...');
final planId = widget.editPlanId ?? uuid.v4();
final path = _storageService.coverImagePath(planId, _coverImageExtension ?? 'jpg');
heroImageUrl = await _storageService.uploadImage(
path: path,
bytes: _coverImageBytes!,
contentType: 'image/${_coverImageExtension ?? 'jpeg'}',
);
Log.i('builder', 'Cover image uploaded successfully');
} catch (e) {
Log.w('builder', 'Failed to upload cover image, using default: $e');
}
} else if (_heroCtrl.text.trim().isNotEmpty) {
heroImageUrl = _heroCtrl.text.trim();
}

// Build versions from current form data (even if incomplete)
final planPrice = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
final versions = <PlanVersion>[];
final planId = widget.editPlanId ?? uuid.v4();
    for (final vf in _versions) {
      final duration = vf.daysCount > 0 ? vf.daysCount : 1;

// Use existing _composeDays method to build day itinerary
final existingDays = _editingPlan != null && _versions.indexOf(vf) < _editingPlan!.versions.length
? _editingPlan!.versions[_versions.indexOf(vf)].days
: const <DayItinerary>[];
final days = await _composeDays(vf, planId, existing: existingDays);

      versions.add(PlanVersion(
        // Preserve IDs in edit mode to prevent version churn and day deletion
        id: widget.editPlanId != null && _editingPlan != null && _versions.indexOf(vf) < _editingPlan!.versions.length
            ? _editingPlan!.versions[_versions.indexOf(vf)].id
            : vf.tempId,
name: vf.name.text.trim().isEmpty ? 'Version ${_versions.indexOf(vf) + 1}' : vf.name.text.trim(),
durationDays: duration,
difficulty: Difficulty.none, // Deprecated - removed from version
comfortType: ComfortType.none, // Deprecated - removed from version
price: planPrice, // Price is stored at plan level
days: days,
packingCategories: _composePackingCategories(vf),
transportationOptions: _composeTransportationOptions(vf),
faqItems: const [], // FAQ is stored at plan level
));
}

// Extract FAQ items from first version to save at plan level
final planFaqItems = _versions.isNotEmpty ? _composeFAQItems(_versions.first) : <FAQItem>[];

if (widget.editPlanId != null && _editingPlan != null) {
// Update existing draft using full CRUD method
final updated = _editingPlan!.copyWith(
name: name,
description: desc,
heroImageUrl: heroImageUrl,
location: location,
basePrice: versions.isEmpty ? 0.0 : versions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
versions: versions,
isPublished: false,
updatedAt: DateTime.now(),
activityCategory: _activityCategory,
accommodationType: _accommodationType,
faqItems: planFaqItems,
);
// Use updatePlanWithVersions to save versions and days to subcollections
await _planService.updatePlanWithVersions(updated);
Log.i('builder', 'Draft updated: ${updated.id}');
} else {
// This shouldn't happen since we create draft on "New Adventure", but handle it
final now = DateTime.now();
final plan = Plan(
id: '',
name: name,
description: desc,
heroImageUrl: heroImageUrl,
location: location,
basePrice: versions.isEmpty ? 0.0 : versions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
creatorId: userId,
creatorName: creatorName,
versions: versions,
isPublished: false,
createdAt: now,
updatedAt: now,
faqItems: planFaqItems,
);

final newPlanId = await _planService.createPlan(plan);
await _userService.addCreatedPlan(userId, newPlanId);
Log.i('builder', 'New draft created: $newPlanId');

// Update URL to include the plan ID
if (!mounted) return;
context.go('/builder/$newPlanId');
// Load the newly created plan
await _loadExistingPlan(newPlanId);
return;
}

if (!mounted) return;
setState(() {
_saveStatus = 'Saved';
_lastSavedAt = DateTime.now();
});
} catch (e, stack) {
Log.e('builder', 'Failed to save draft', e, stack);
if (mounted) {
setState(() => _saveStatus = 'Failed to save');
}
} finally {
if (mounted) setState(() => _isSaving = false);
}
}

/// Saves current step data when clicking Next button
/// Returns true if save was successful, false otherwise
Future<bool> _saveCurrentStep() async {
final userId = _auth.currentUserId;
if (userId == null || _editingPlan == null) return true;

setState(() {
_isSaving = true;
_saveStatus = 'Saving...';
});

    try {
      final uuid = const Uuid();
final name = _nameCtrl.text.trim().isEmpty ? 'Untitled Adventure' : _nameCtrl.text.trim();
final location = _locationCtrl.text.trim();
final desc = _descCtrl.text.trim();

// Upload cover image if available
String heroImageUrl = _editingPlan!.heroImageUrl;
if (_coverImageBytes != null) {
try {
final path = _storageService.coverImagePath(_editingPlan!.id, _coverImageExtension ?? 'jpg');
heroImageUrl = await _storageService.uploadImage(
path: path,
bytes: _coverImageBytes!,
contentType: 'image/${_coverImageExtension ?? 'jpeg'}',
);
} catch (e) {
Log.w('builder', 'Failed to upload cover image: $e');
}
} else if (_heroCtrl.text.trim().isNotEmpty) {
heroImageUrl = _heroCtrl.text.trim();
}

// Build versions from current form data
final planPrice = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final versions = <PlanVersion>[];
      for (final vf in _versions) {
final duration = vf.daysCount > 0 ? vf.daysCount : 1;

final existingDays = _versions.indexOf(vf) < _editingPlan!.versions.length
? _editingPlan!.versions[_versions.indexOf(vf)].days
: const <DayItinerary>[];
final days = await _composeDays(vf, _editingPlan!.id, existing: existingDays);

versions.add(PlanVersion(
          // Preserve a stable version ID to avoid deleting/recreating versions
          // which was wiping their day subcollections.
          id: (_versions.indexOf(vf) < _editingPlan!.versions.length)
              ? _editingPlan!.versions[_versions.indexOf(vf)].id
              : vf.tempId,
name: vf.name.text.trim().isEmpty ? 'Version ${_versions.indexOf(vf) + 1}' : vf.name.text.trim(),
durationDays: duration,
difficulty: Difficulty.none,
comfortType: ComfortType.none,
price: planPrice,
days: days,
packingCategories: _composePackingCategories(vf),
transportationOptions: _composeTransportationOptions(vf),
faqItems: const [],
));
}

// Extract FAQ items from first version to save at plan level
final planFaqItems = _versions.isNotEmpty ? _composeFAQItems(_versions.first) : <FAQItem>[];

// Update existing plan using full CRUD method
final updated = _editingPlan!.copyWith(
name: name,
description: desc,
heroImageUrl: heroImageUrl,
location: location,
basePrice: versions.isEmpty ? 0.0 : versions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
versions: versions,
isPublished: _isPublished,
updatedAt: DateTime.now(),
activityCategory: _activityCategory,
accommodationType: _accommodationType,
faqItems: planFaqItems,
);

await _planService.updatePlanWithVersions(updated);

if (mounted) {
setState(() {
_saveStatus = 'Saved';
_lastSavedAt = DateTime.now();
});
}

return true;
} catch (e, stack) {
Log.e('builder', 'Save failed', e, stack);
if (mounted) {
setState(() => _saveStatus = 'Failed to save');
}
return false;
} finally {
if (mounted) setState(() => _isSaving = false);
}
}

Widget _buildStep6Overview() {
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
_buildGeneralInfoCard(),
_buildVersionsCard(),
_buildPackingCard(),
_buildTransportCard(),
_buildDaysCard(),

const SizedBox(height: 80),
],
),
),
),
),
);
}

Widget _buildCompletionStatus() {
final checks = _checkCompletion();
final completed = checks.values.where((v) => v).length;
final total = checks.length;
final percentage = completed / total;
final missingItems = checks.entries.where((e) => !e.value).map((e) => e.key).toList();

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
// Circular progress
SizedBox(
width: 64,
height: 64,
child: Stack(
children: [
CircularProgressIndicator(
value: percentage,
strokeWidth: 6,
backgroundColor: Colors.grey.shade200,
valueColor: AlwaysStoppedAnimation<Color>(
percentage == 1.0 ? const Color(0xFF4CAF50) : const Color(0xFF428A13),
),
),
Center(
child: Text(
'${(percentage * 100).toInt()}%',
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w700,
),
),
),
],
),
),
const SizedBox(width: 20),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'$completed of $total sections complete',
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
if (missingItems.isNotEmpty) ...[
const SizedBox(height: 4),
Text(
'⚠ Missing: ${missingItems.join(", ")}',
style: TextStyle(
fontSize: 14,
color: Colors.orange.shade700,
),
),
],
],
),
),
if (percentage == 1.0)
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: const Color(0xFFE8F5E9),
borderRadius: BorderRadius.circular(20),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
const SizedBox(width: 4),
Text(
'Ready to publish',
style: TextStyle(
color: const Color(0xFF2E7D32),
fontWeight: FontWeight.w600,
fontSize: 13,
),
),
],
),
),
],
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
color: _isPublished ? const Color(0xFFE8F5E9) : Colors.orange.shade50,
borderRadius: BorderRadius.circular(12),
),
child: Icon(
_isPublished ? Icons.public : Icons.edit_note,
color: _isPublished ? const Color(0xFF428A13) : Colors.orange.shade700,
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
_isPublished
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
value: _isPublished,
onChanged: (value) {
setState(() => _isPublished = value);
},
activeColor: const Color(0xFF428A13),
),
Text(
_isPublished ? 'Published' : 'Draft',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: _isPublished ? const Color(0xFF428A13) : Colors.orange.shade700,
),
),
],
),
],
),
);
}

Map<String, bool> _checkCompletion() {
return {
'Title': _nameCtrl.text.trim().isNotEmpty,
'Description': _descCtrl.text.trim().isNotEmpty,
'Cover image': _heroCtrl.text.trim().isNotEmpty || _coverImageBytes != null,
'Location': _locationCtrl.text.trim().isNotEmpty,
'At least one version': _versions.isNotEmpty && _versions.any((v) => (int.tryParse(v.duration.text) ?? 0) > 0),
'At least one day': _versions.any((v) => v.daysCount > 0),
};
}

Widget _buildGeneralInfoCard() {
final isComplete = _nameCtrl.text.trim().isNotEmpty &&
_descCtrl.text.trim().isNotEmpty &&
_locationCtrl.text.trim().isNotEmpty;

return _SummaryCard(
icon: Icons.info_outline,
title: 'General Information',
onEdit: () {
_pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
setState(() => _currentStep = 0);
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
child: _coverImageBytes != null
? Image.memory(_coverImageBytes!, width: 100, height: 80, fit: BoxFit.cover)
: _heroCtrl.text.trim().isNotEmpty
? Image.network(_heroCtrl.text, width: 100, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
return Container(width: 100, height: 80, color: Colors.grey.shade200, child: Icon(Icons.image, color: Colors.grey.shade400));
})
: Container(width: 100, height: 80, color: Colors.grey.shade200, child: Icon(Icons.image, color: Colors.grey.shade400)),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text : 'Untitled Adventure',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w600,
color: _nameCtrl.text.trim().isNotEmpty ? Colors.grey.shade900 : Colors.grey.shade400,
),
),
const SizedBox(height: 4),
Text(
_descCtrl.text.trim().isNotEmpty ? _descCtrl.text : 'No description added',
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
const SizedBox(height: 16),
// Location row
if (_locationCtrl.text.trim().isNotEmpty)
Row(
children: [
Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
const SizedBox(width: 4),
Text(
_locationCtrl.text,
style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
),
],
),
],
),
);
}

Widget _buildVersionsCard() {
final hasVersions = _versions.isNotEmpty && _versions.any((v) => (int.tryParse(v.duration.text) ?? 0) > 0);

return _SummaryCard(
icon: Icons.layers_outlined,
title: 'Versions',
badge: '${_versions.length} version${_versions.length != 1 ? 's' : ''}',
onEdit: () {
_pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
setState(() => _currentStep = 1);
},
isComplete: hasVersions,
child: hasVersions
? Column(
children: _versions.asMap().entries.map((entry) {
final index = entry.key;
final version = entry.value;
final duration = int.tryParse(version.duration.text) ?? 0;
if (duration == 0) return const SizedBox.shrink();

final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;

return Container(
margin: EdgeInsets.only(bottom: index < _versions.length - 1 ? 12 : 0),
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
version.name.text.trim().isNotEmpty ? version.name.text : 'Version ${index + 1}',
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
  final hasPacking = _versions.any((v) => v.packingCategories.isNotEmpty);
  int totalItems = 0;
  for (final v in _versions) {
    for (final cat in v.packingCategories) {
      totalItems += cat.items.length;
    }
  }

  return _SummaryCard(
    icon: Icons.backpack_outlined,
    title: 'What to Pack',
    badge: hasPacking ? '$totalItems items' : null,
    onEdit: () {
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 2);
    },
    isComplete: hasPacking,
    child: hasPacking
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _versions.take(2).expand((version) {
              final versionName = version.name.text.trim().isNotEmpty ? version.name.text : 'Version';
              return version.packingCategories.take(3).map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${cat.name} (${cat.items.length} items)',
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
  final hasTransport = _versions.any((v) => v.transportationOptions.isNotEmpty);
  int totalOptions = 0;
  for (final v in _versions) {
    totalOptions += v.transportationOptions.length;
  }

  return _SummaryCard(
    icon: Icons.directions_outlined,
    title: 'How to Get There',
    badge: hasTransport ? '$totalOptions options' : null,
    onEdit: () {
      _pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 3);
    },
    isComplete: hasTransport,
    child: hasTransport
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _versions.take(2).expand((version) {
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

Widget _buildDaysCard() {
  final hasDays = _versions.any((v) => v.daysCount > 0);
  int totalDays = 0;
  for (final v in _versions) {
    totalDays += v.daysCount;
  }

  return _SummaryCard(
    icon: Icons.calendar_today_outlined,
    title: 'Days',
    badge: hasDays ? '$totalDays days planned' : null,
    onEdit: () {
      _pageController.animateToPage(4, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 4);
    },
    isComplete: hasDays,
    child: hasDays
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _versions.asMap().entries.expand((vEntry) {
              final vIndex = vEntry.key;
              final version = vEntry.value;
              final versionName = version.name.text.trim().isNotEmpty ? version.name.text : 'Version ${vIndex + 1}';

              return [
                if (vIndex > 0) const SizedBox(height: 16),
                if (_versions.length > 1) ...[
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
                  final titleCtrl = version.titleCtrl(dayNum);
                  final distanceCtrl = version.distanceCtrl(dayNum);
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

if (_isSaving) {
icon = Icons.cloud_upload_outlined;
color = Colors.grey;
text = 'Saving...';
} else if (_saveStatus == 'Failed to save') {
icon = Icons.cloud_off_outlined;
color = Colors.red;
text = 'Failed to save';
} else if (_lastSavedAt != null) {
icon = Icons.cloud_done_outlined;
color = Colors.green;
text = 'Saved';
} else {
icon = Icons.cloud_outlined;
color = Colors.grey;
text = 'Not saved yet';
}

String timeText = '';
if (_lastSavedAt != null && !_isSaving) {
final now = DateTime.now();
final diff = now.difference(_lastSavedAt!);
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
if (_isSaving)
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
_locationCtrl.removeListener(_onLocationChanged);
_locationCtrl.addListener(_onLocationChanged);
}

void _onLocationChanged() {
// Only trigger search if the field has focus (user is actively typing)
if (!_locationFocusNode.hasFocus) {
return;
}

final text = _locationCtrl.text.trim();
if (text.length < 3) {
setState(() {
_locationSuggestions = null;
_searchingLocation = false;
});
// Cancel any pending search
_locationDebounceTimer?.cancel();
return;
}

// Cancel previous timer
_locationDebounceTimer?.cancel();

// Show loading indicator immediately
setState(() => _searchingLocation = true);

// Set new debounce timer (500ms delay)
_locationDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
try {
final svc = MapboxService();
final res = await svc.searchPlaces(text);
if (!mounted) return;
setState(() => _locationSuggestions = res);
} catch (e) {
debugPrint('searchPlaces error: $e');
} finally {
if (mounted) setState(() => _searchingLocation = false);
}
});
}

String _formatDuration(int seconds) {
final h = seconds ~/ 3600;
final m = (seconds % 3600) ~/ 60;
if (h > 0) return '${h}h ${m}m';
return '${m}m';
}

/// Add a waypoint from the itinerary page for a specific type
Future<void> _addWaypointFromItinerary(int dayNum, WaypointType type, _VersionFormData vf) async {
// Check if route exists
final existingRoute = vf.routeByDay[dayNum];
if (existingRoute == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Please create a route first before adding waypoints'),
backgroundColor: Colors.orange,
),
);
return;
}

// Get proximity bias from route
ll.LatLng? proximityBias;
if (existingRoute.routePoints.isNotEmpty) {
final midIndex = existingRoute.routePoints.length ~/ 2;
final midPoint = existingRoute.routePoints[midIndex];
proximityBias = ll.LatLng(midPoint['lat']! as double, midPoint['lng']! as double);
}

// Open add waypoint dialog with Google Places search
final waypoint = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointFromItineraryDialog(
type: type,
proximityBias: proximityBias,
),
);

if (waypoint != null && mounted) {
// Add waypoint to route
final updatedWaypoints = [
...existingRoute.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)),
waypoint,
];

// Update route with new waypoint
final updatedRoute = DayRoute(
geometry: existingRoute.geometry,
distance: existingRoute.distance,
duration: existingRoute.duration,
routePoints: existingRoute.routePoints,
elevationProfile: existingRoute.elevationProfile,
ascent: existingRoute.ascent,
descent: existingRoute.descent,
poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
);

setState(() {
vf.routeByDay[dayNum] = updatedRoute;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('${getWaypointLabel(type)} added successfully'),
backgroundColor: Colors.green,
),
);
}
}

/// Add a waypoint to a specific time slot category
Future<void> _addWaypointToCategory(int dayNum, WaypointType type, TimeSlotCategory category, _VersionFormData vf) async {
// Check if route exists
final existingRoute = vf.routeByDay[dayNum];
if (existingRoute == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Please create a route first before adding waypoints'),
backgroundColor: Colors.orange,
),
);
return;
}

// Get proximity bias from route
ll.LatLng? proximityBias;
if (existingRoute.routePoints.isNotEmpty) {
final midIndex = existingRoute.routePoints.length ~/ 2;
final midPoint = existingRoute.routePoints[midIndex];
proximityBias = ll.LatLng(midPoint['lat']! as double, midPoint['lng']! as double);
}

// Open add waypoint dialog with Google Places search
final waypoint = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointFromItineraryDialog(
type: type,
proximityBias: proximityBias,
),
);

if (waypoint != null && mounted) {
// Set the category for the new waypoint
final waypointWithCategory = waypoint.copyWith(timeSlotCategory: category);

// Add waypoint to route
final updatedWaypoints = [
...existingRoute.poiWaypoints.map((json) => RouteWaypoint.fromJson(json)),
waypointWithCategory,
];

// Update route with new waypoint
final updatedRoute = DayRoute(
geometry: existingRoute.geometry,
distance: existingRoute.distance,
duration: existingRoute.duration,
routePoints: existingRoute.routePoints,
elevationProfile: existingRoute.elevationProfile,
ascent: existingRoute.ascent,
descent: existingRoute.descent,
poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
);

setState(() {
vf.routeByDay[dayNum] = updatedRoute;
});

Log.i('builder', 'Added ${getWaypointLabel(type)} to ${getTimeSlotLabel(category)} category');

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('${getWaypointLabel(type)} added to ${getTimeSlotLabel(category)}'),
backgroundColor: Colors.green,
),
);
}
}

/// Edit an existing waypoint from the itinerary
Future<void> _editWaypointFromItinerary(int dayNum, int waypointIndex, _VersionFormData vf) async {
final existingRoute = vf.routeByDay[dayNum];
if (existingRoute == null) return;

final waypoints = existingRoute.poiWaypoints
.map((json) => RouteWaypoint.fromJson(json))
.toList();

if (waypointIndex >= waypoints.length) return;

final existingWaypoint = waypoints[waypointIndex];

// Open edit waypoint dialog
final result = await showDialog<RouteWaypoint>(
context: context,
builder: (context) => _AddWaypointFromItineraryDialog(
type: existingWaypoint.type,
existingWaypoint: existingWaypoint,
),
);

if (result != null && mounted) {
// Replace the waypoint at the index
waypoints[waypointIndex] = result;

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
vf.routeByDay[dayNum] = updatedRoute;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Waypoint updated successfully'),
backgroundColor: Colors.green,
),
);
}
}

/// Delete a waypoint from the itinerary
void _deleteWaypointFromItinerary(int dayNum, int waypointIndex, _VersionFormData vf) {
final existingRoute = vf.routeByDay[dayNum];
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
vf.routeByDay[dayNum] = updatedRoute;
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
void _updateWaypointTime(int dayNum, RouteWaypoint waypoint, String? newTime, _VersionFormData vf) {
final existingRoute = vf.routeByDay[dayNum];
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
vf.routeByDay[dayNum] = updatedRoute;
});

Log.i('builder', 'Updated waypoint time: ${waypoint.name} to $newTime');
}

/// Reorder waypoints within a category
void _reorderWaypointsInCategory(int dayNum, TimeSlotCategory category, int oldIndex, int newIndex, _VersionFormData vf) {
final existingRoute = vf.routeByDay[dayNum];
if (existingRoute == null) return;

// Get all waypoints
final allWaypoints = existingRoute.poiWaypoints
.map((json) => RouteWaypoint.fromJson(json))
.toList();

// Get waypoints in this category
final categoryWaypoints = allWaypoints
.where((wp) => wp.timeSlotCategory == category)
.toList();

if (oldIndex >= categoryWaypoints.length || newIndex > categoryWaypoints.length) return;

// Adjust newIndex for ReorderableListView behavior
int adjustedNewIndex = newIndex;
if (newIndex > oldIndex) {
adjustedNewIndex -= 1;
}

// Reorder within category
final item = categoryWaypoints.removeAt(oldIndex);
categoryWaypoints.insert(adjustedNewIndex, item);

// Merge back into all waypoints, maintaining category order
final otherWaypoints = allWaypoints
.where((wp) => wp.timeSlotCategory != category)
.toList();

// Combine and sort by time slot order
final updatedWaypoints = [...otherWaypoints, ...categoryWaypoints];
updatedWaypoints.sort((a, b) {
final aOrder = a.timeSlotCategory != null ? getTimeSlotOrder(a.timeSlotCategory!) : 999;
final bOrder = b.timeSlotCategory != null ? getTimeSlotOrder(b.timeSlotCategory!) : 999;
return aOrder.compareTo(bOrder);
});

// Update route
final updatedRoute = DayRoute(
geometry: existingRoute.geometry,
distance: existingRoute.distance,
duration: existingRoute.duration,
routePoints: existingRoute.routePoints,
elevationProfile: existingRoute.elevationProfile,
ascent: existingRoute.ascent,
descent: existingRoute.descent,
poiWaypoints: updatedWaypoints.map((w) => w.toJson()).toList(),
);

setState(() {
vf.routeByDay[dayNum] = updatedRoute;
});

Log.i('builder', 'Reordered waypoints in ${getTimeSlotLabel(category)}');
}

/// Show dialog to select waypoint type before adding
void _showWaypointTypeDialog(BuildContext context, int dayNum, _VersionFormData vf) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Add Waypoint'),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
ListTile(
leading: Icon(Icons.hotel, color: getWaypointColor(WaypointType.accommodation)),
title: const Text('Accommodation'),
onTap: () {
Navigator.of(context).pop();
_addWaypointFromItinerary(dayNum, WaypointType.accommodation, vf);
},
),
ListTile(
leading: Icon(Icons.restaurant, color: getWaypointColor(WaypointType.restaurant)),
title: const Text('Restaurant'),
onTap: () {
Navigator.of(context).pop();
_addWaypointFromItinerary(dayNum, WaypointType.restaurant, vf);
},
),
ListTile(
leading: Icon(Icons.local_activity, color: getWaypointColor(WaypointType.activity)),
title: const Text('Activity'),
onTap: () {
Navigator.of(context).pop();
_addWaypointFromItinerary(dayNum, WaypointType.activity, vf);
},
),
ListTile(
leading: Icon(Icons.visibility, color: getWaypointColor(WaypointType.viewingPoint)),
title: const Text('Viewing Point'),
onTap: () {
Navigator.of(context).pop();
_addWaypointFromItinerary(dayNum, WaypointType.viewingPoint, vf);
},
),
ListTile(
leading: Icon(Icons.local_gas_station, color: getWaypointColor(WaypointType.servicePoint)),
title: const Text('Service Point'),
onTap: () {
Navigator.of(context).pop();
_addWaypointFromItinerary(dayNum, WaypointType.servicePoint, vf);
},
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
],
),
);
}

/// Build timeline layout with categories for all waypoints
Widget _buildAllWaypointsList(int dayNum, _VersionFormData vf) {
final existingRoute = vf.routeByDay[dayNum];
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
.toList();

// If any categories were auto-assigned, save them back to the route
bool needsUpdate = false;
for (int i = 0; i < waypoints.length; i++) {
  if (existingRoute.poiWaypoints[i]['timeSlotCategory'] == null && 
      waypoints[i].timeSlotCategory != null) {
    needsUpdate = true;
    break;
  }
}
if (needsUpdate) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        vf.routeByDay[dayNum] = DayRoute(
          geometry: existingRoute.geometry,
          distance: existingRoute.distance,
          duration: existingRoute.duration,
          routePoints: existingRoute.routePoints,
          elevationProfile: existingRoute.elevationProfile,
          ascent: existingRoute.ascent,
          descent: existingRoute.descent,
          poiWaypoints: waypoints.map((wp) => wp.toJson()).toList(),
        );
      });
    }
  });
}

Log.i('builder', 'Total waypoints for day $dayNum: ${waypoints.length}');

// Group waypoints by time slot category
final Map<TimeSlotCategory, List<RouteWaypoint>> waypointsByCategory = {};
for (final category in TimeSlotCategory.values) {
  waypointsByCategory[category] = waypoints
      .where((wp) => wp.timeSlotCategory == category)
      .toList();
}

// Build timeline sections for each category - only show sections with waypoints
return Column(
  children: TimeSlotCategory.values.where((category) {
    final categoryWaypoints = waypointsByCategory[category] ?? [];
    return categoryWaypoints.isNotEmpty;
  }).map((category) {
    final categoryWaypoints = waypointsByCategory[category] ?? [];
    Log.i('builder', 'Day $dayNum - ${getTimeSlotLabel(category)}: ${categoryWaypoints.length} waypoints');
    
    return DayTimelineSection(
      category: category,
      waypoints: categoryWaypoints,
      isExpanded: true,
      onAddWaypoint: () {
        // Determine what type to add based on category
        WaypointType type;
        switch (category) {
          case TimeSlotCategory.breakfast:
          case TimeSlotCategory.lunch:
          case TimeSlotCategory.dinner:
            type = WaypointType.restaurant;
            break;
          case TimeSlotCategory.accommodation:
            type = WaypointType.accommodation;
            break;
          case TimeSlotCategory.morningActivity:
          case TimeSlotCategory.allDayActivity:
          case TimeSlotCategory.afternoonActivity:
          case TimeSlotCategory.eveningActivity:
            type = WaypointType.activity;
            break;
          case TimeSlotCategory.servicePoint:
            type = WaypointType.servicePoint;
            break;
          case TimeSlotCategory.viewingPoint:
            type = WaypointType.viewingPoint;
            break;
        }
        _addWaypointToCategory(dayNum, type, category, vf);
      },
      onEditWaypoint: (waypoint) {
        final index = waypoints.indexOf(waypoint);
        if (index >= 0) {
          _editWaypointFromItinerary(dayNum, index, vf);
        }
      },
      onDeleteWaypoint: (waypoint) {
        final index = waypoints.indexOf(waypoint);
        if (index >= 0) {
          _deleteWaypointFromItinerary(dayNum, index, vf);
        }
      },
      onTimeChange: (waypoint, newTime) {
        _updateWaypointTime(dayNum, waypoint, newTime, vf);
      },
      onReorder: (oldIndex, newIndex) {
        _reorderWaypointsInCategory(dayNum, category, oldIndex, newIndex, vf);
      },
    );
  }).toList(),
);
}

List<PackingCategory> _composePackingCategories(_VersionFormData vf, {List<PackingCategory> fallback = const []}) {
// Convert internal _PackingCategory to model PackingCategory
if (vf.packingCategories.isNotEmpty) {
return vf.packingCategories.map((cat) => PackingCategory(
name: cat.name,
items: cat.items.map((item) => PackingItem(
id: item.id,
name: item.name,
description: item.description,
)).toList(),
description: cat.description,
)).toList();
}

// Otherwise use fallback
return fallback;
}

List<TransportationOption> _composeTransportationOptions(_VersionFormData vf) {
return vf.transportationOptions
.where((t) => t.titleCtrl.text.trim().isNotEmpty && t.types.isNotEmpty)
.map((t) => TransportationOption(
title: t.titleCtrl.text.trim(),
description: t.descCtrl.text.trim(),
types: List<TransportationType>.from(t.types),
))
.toList();
}

List<FAQItem> _composeFAQItems(_VersionFormData vf) {
return vf.faqItems
.where((f) => f.questionCtrl.text.trim().isNotEmpty)
.map((f) => FAQItem(
question: f.questionCtrl.text.trim(),
answer: f.answerCtrl.text.trim(),
))
.toList();
}
}

class _PackingItem {
final String id;
final String name;
final String? description;

_PackingItem({required this.id, required this.name, this.description});

_PackingItem copyWith({String? name, String? description, bool clearDescription = false}) {
return _PackingItem(
id: id,
name: name ?? this.name,
description: clearDescription ? null : (description ?? this.description),
);
}
}

class _PackingCategory {
final String name;
final List<_PackingItem> items;
final String? description; // Optional info/description with markdown support

_PackingCategory({required this.name, this.items = const [], this.description});

_PackingCategory copyWith({String? name, List<_PackingItem>? items, String? description, bool clearDescription = false}) {
return _PackingCategory(
name: name ?? this.name,
items: items ?? this.items,
description: clearDescription ? null : (description ?? this.description),
);
}
}

class _TransportationFormData {
final TextEditingController titleCtrl;
final TextEditingController descCtrl;
final List<TransportationType> types;

_TransportationFormData()
: titleCtrl = TextEditingController(),
descCtrl = TextEditingController(),
types = [];

factory _TransportationFormData.fromModel(TransportationOption option) => _TransportationFormData()
..titleCtrl.text = option.title
..descCtrl.text = option.description
..types.addAll(option.types);

void dispose() {
titleCtrl.dispose();
descCtrl.dispose();
}
}

class _FAQFormData {
final TextEditingController questionCtrl;
final TextEditingController answerCtrl;

_FAQFormData()
: questionCtrl = TextEditingController(),
answerCtrl = TextEditingController();

factory _FAQFormData.fromModel(FAQItem faq) => _FAQFormData()
..questionCtrl.text = faq.question
..answerCtrl.text = faq.answer;

void dispose() {
questionCtrl.dispose();
answerCtrl.dispose();
}
}

class _VersionFormData {
final String tempId;
final TextEditingController name;
final TextEditingController duration;
// Note: difficulty, comfortType, experienceLevel, price, faqItems are now stored at PLAN level
// They are no longer stored in version subcollections
final List<String> packingItems; // Legacy - keep for backwards compatibility
final List<_PackingCategory> packingCategories; // New categorized system
final List<_TransportationFormData> transportationOptions;
final List<_FAQFormData> faqItems; // UI only - saved at plan level
final Map<int, ll.LatLng> startForDay;
final Map<int, ll.LatLng> endForDay;
final Map<int, TextEditingController> _titleByDay = {};
final Map<int, TextEditingController> _descByDay = {};
final Map<int, TextEditingController> _distanceByDay = {};
final Map<int, TextEditingController> _timeHoursByDay = {};
final Map<int, TextEditingController> _stayUrlByDay = {};
final Map<int, TextEditingController> _stayCostByDay = {};
final Map<int, LinkPreviewData?> stayMetaByDay = {};
final Map<int, DayRoute> routeByDay = {};
final Map<int, List<_AccommodationFormData>> accommodationsByDay = {};
final Map<int, List<_RestaurantFormData>> restaurantsByDay = {};
final Map<int, List<_ActivityFormData>> activitiesByDay = {};
final Map<int, Uint8List> dayImagesByDay = {};
final Map<int, String> dayImageExtByDay = {};
final Map<int, String> existingDayImageUrls = {}; // URLs from previously uploaded images

_VersionFormData({
required this.tempId,
required this.name,
required this.duration,
List<String>? packingItems,
List<_PackingCategory>? packingCategories,
List<_TransportationFormData>? transportationOptions,
List<_FAQFormData>? faqItems,
Map<int, ll.LatLng>? startForDay,
Map<int, ll.LatLng>? endForDay,
}) : packingItems = packingItems ?? <String>[],
packingCategories = packingCategories ?? <_PackingCategory>[],
transportationOptions = transportationOptions ?? <_TransportationFormData>[],
faqItems = faqItems ?? <_FAQFormData>[],
startForDay = startForDay ?? <int, ll.LatLng>{},
endForDay = endForDay ?? <int, ll.LatLng>{};

int get daysCount => int.tryParse(duration.text) ?? 0;

void dispose() {
name.dispose();
duration.dispose();
for (final t in transportationOptions) {
t.dispose();
}
for (final f in faqItems) {
f.dispose();
}
for (final c in _titleByDay.values) {
c.dispose();
}
for (final c in _descByDay.values) {
c.dispose();
}
for (final c in _distanceByDay.values) {
c.dispose();
}
for (final c in _timeHoursByDay.values) {
c.dispose();
}
for (final c in _stayUrlByDay.values) {
c.dispose();
}
for (final c in _stayCostByDay.values) {
c.dispose();
}
for (final list in accommodationsByDay.values) {
for (final a in list) {
a.dispose();
}
}
for (final list in restaurantsByDay.values) {
for (final r in list) {
r.dispose();
}
}
for (final list in activitiesByDay.values) {
for (final a in list) {
a.dispose();
}
}
}

factory _VersionFormData.initial() => _VersionFormData(
tempId: const Uuid().v4(),
name: TextEditingController(text: ''),
duration: TextEditingController(text: '5'),
);

factory _VersionFormData.fromVersion(PlanVersion v) => _VersionFormData(
tempId: v.id,
name: TextEditingController(text: v.name),
duration: TextEditingController(text: v.durationDays.toString()),
packingCategories: v.packingCategories.map((cat) => _PackingCategory(
name: cat.name,
items: cat.items.map((item) => _PackingItem(
id: item.id,
name: item.name,
description: item.description,
)).toList(),
description: cat.description,
)).toList(),
);

TextEditingController titleCtrl(int day) => _titleByDay.putIfAbsent(day, () => TextEditingController());
TextEditingController descCtrl(int day) => _descByDay.putIfAbsent(day, () => TextEditingController());
TextEditingController distanceCtrl(int day) => _distanceByDay.putIfAbsent(day, () => TextEditingController());
TextEditingController timeCtrl(int day) => _timeHoursByDay.putIfAbsent(day, () => TextEditingController());
TextEditingController stayUrlCtrl(int day) => _stayUrlByDay.putIfAbsent(day, () => TextEditingController());
TextEditingController stayCostCtrl(int day) => _stayCostByDay.putIfAbsent(day, () => TextEditingController());
}

class _AccommodationFormData {
final TextEditingController nameCtrl;
final TextEditingController typeCtrl;
final TextEditingController urlCtrl;
final TextEditingController costCtrl;

_AccommodationFormData()
: nameCtrl = TextEditingController(),
typeCtrl = TextEditingController(text: 'Hotel'),
urlCtrl = TextEditingController(),
costCtrl = TextEditingController();

factory _AccommodationFormData.fromModel(AccommodationInfo acc) => _AccommodationFormData()
..nameCtrl.text = acc.name
..typeCtrl.text = acc.type
..urlCtrl.text = acc.bookingLink ?? ''
..costCtrl.text = acc.cost?.toStringAsFixed(2) ?? '';

void dispose() {
nameCtrl.dispose();
typeCtrl.dispose();
urlCtrl.dispose();
costCtrl.dispose();
}
}

class _RestaurantFormData {
final TextEditingController nameCtrl;
MealType mealType;
final TextEditingController urlCtrl;
final TextEditingController costCtrl;

_RestaurantFormData()
: nameCtrl = TextEditingController(),
mealType = MealType.lunch,
urlCtrl = TextEditingController(),
costCtrl = TextEditingController();

factory _RestaurantFormData.fromModel(RestaurantInfo rest) => _RestaurantFormData()
..nameCtrl.text = rest.name
..mealType = rest.mealType
..urlCtrl.text = rest.bookingLink ?? ''
..costCtrl.text = rest.cost?.toStringAsFixed(2) ?? '';

void dispose() {
nameCtrl.dispose();
urlCtrl.dispose();
costCtrl.dispose();
}
}

class _ActivityFormData {
final TextEditingController nameCtrl;
final TextEditingController descCtrl;
final TextEditingController urlCtrl;
final TextEditingController costCtrl;

_ActivityFormData()
: nameCtrl = TextEditingController(),
descCtrl = TextEditingController(),
urlCtrl = TextEditingController(),
costCtrl = TextEditingController();

factory _ActivityFormData.fromModel(ActivityInfo act) => _ActivityFormData()
..nameCtrl.text = act.name
..descCtrl.text = act.description
..urlCtrl.text = act.bookingLink ?? ''
..costCtrl.text = act.cost?.toStringAsFixed(2) ?? '';

void dispose() {
nameCtrl.dispose();
descCtrl.dispose();
urlCtrl.dispose();
costCtrl.dispose();
}
}

extension on _BuilderScreenState {
Widget _buildVersionCard(int index) {
final v = _versions[index];
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
onPressed: _versions.length == 1
? null
: () => setState(() {
if (_activeVersionIndex >= _versions.length - 1) {
_activeVersionIndex = (_activeVersionIndex - 1).clamp(0, _versions.length - 2);
}
_versions.removeAt(index);
}),
icon: const Icon(Icons.delete_outline, size: 20),
style: IconButton.styleFrom(
foregroundColor: Colors.grey.shade600,
hoverColor: Colors.red.shade50,
),
),
]),
const SizedBox(height: 20),
_buildTextField("Version Name", "e.g., 5-Day Extreme", controller: v.name, required: false),
const SizedBox(height: 16),
_buildTextField("Duration (Days)", "5", isNumber: true, controller: v.duration, required: true),
]),
);
}


Future<void> _pickCoverImage() async {
try {
final result = await _storageService.pickImage();
if (result != null && mounted) {
setState(() {
_coverImageBytes = result.bytes;
_coverImageExtension = result.extension;
_heroCtrl.clear(); // Clear URL field when image is uploaded
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
final vf = _versions[_activeVersionIndex];
setState(() {
vf.dayImagesByDay[dayNum] = result.bytes;
vf.dayImageExtByDay[dayNum] = result.extension;
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

/// Stateful widget for packing category card with item descriptions
class _PackingCategoryCardWidget extends StatefulWidget {
final _VersionFormData versionFormData;
final int categoryIndex;
final _PackingCategory category;
final VoidCallback onUpdate;

const _PackingCategoryCardWidget({
super.key,
required this.versionFormData,
required this.categoryIndex,
required this.category,
required this.onUpdate,
});

@override
State<_PackingCategoryCardWidget> createState() => _PackingCategoryCardWidgetState();
}

class _PackingCategoryCardWidgetState extends State<_PackingCategoryCardWidget> {
late TextEditingController _nameCtrl;
late TextEditingController _categoryDescCtrl;
late TextEditingController _itemNameCtrl;
late TextEditingController _itemDescCtrl;
bool _showCategoryDescription = false;
bool _showItemDescription = false;

@override
void initState() {
super.initState();
_nameCtrl = TextEditingController(text: widget.category.name);
_categoryDescCtrl = TextEditingController(text: widget.category.description ?? '');
_itemNameCtrl = TextEditingController();
_itemDescCtrl = TextEditingController();
_showCategoryDescription = widget.category.description?.isNotEmpty ?? false;
}

@override
void dispose() {
_nameCtrl.dispose();
_categoryDescCtrl.dispose();
_itemNameCtrl.dispose();
_itemDescCtrl.dispose();
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
controller: _nameCtrl,
textDirection: TextDirection.ltr,
style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
decoration: const InputDecoration(
hintText: 'Category name (e.g., Insurance)',
border: InputBorder.none,
isDense: true,
contentPadding: EdgeInsets.zero,
),
onChanged: (value) {
widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(name: value);
widget.onUpdate();
},
),
),
),
if (widget.category.description?.isNotEmpty ?? false)
Tooltip(
message: 'This category has additional information',
child: Icon(Icons.info_outline, size: 20, color: context.colors.primary),
),
const SizedBox(width: 4),
IconButton(
icon: const Icon(Icons.delete_outline, size: 20),
onPressed: () {
widget.versionFormData.packingCategories.removeAt(widget.categoryIndex);
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
if (!_showCategoryDescription && _categoryDescCtrl.text.isEmpty) {
widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(clearDescription: true);
widget.onUpdate();
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
widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(description: value.isEmpty ? null : value);
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
return _buildItemChip(item, itemIndex);
}).toList(),
),
],
),
);
}

Widget _buildItemChip(_PackingItem item, int itemIndex) {
final hasDescription = item.description?.isNotEmpty ?? false;

return GestureDetector(
onLongPress: () => _showEditItemDialog(item, itemIndex),
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
Text(item.name, style: const TextStyle(fontSize: 14)),
if (hasDescription) ...[
const SizedBox(width: 6),
GestureDetector(
onTap: () => _showItemInfoTooltip(item),
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
onTap: () => _deleteItem(itemIndex),
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

final newItem = _PackingItem(
id: DateTime.now().millisecondsSinceEpoch.toString(),
name: name,
description: description?.isNotEmpty == true ? description : null,
);

final updatedItems = List<_PackingItem>.from(widget.category.items)..add(newItem);
widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(items: updatedItems);

_itemNameCtrl.clear();
_itemDescCtrl.clear();
setState(() => _showItemDescription = false);
widget.onUpdate();
}

void _deleteItem(int itemIndex) {
final updatedItems = List<_PackingItem>.from(widget.category.items)..removeAt(itemIndex);
widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(items: updatedItems);
widget.onUpdate();
}

void _showItemInfoTooltip(_PackingItem item) {
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
item.name,
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
),
),
],
),
const SizedBox(height: 12),
MarkdownBody(
data: item.description!,
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

void _showEditItemDialog(_PackingItem item, int itemIndex) {
final nameController = TextEditingController(text: item.name);
final descController = TextEditingController(text: item.description ?? '');

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
maxLines: 4,
decoration: const InputDecoration(
labelText: 'Description (optional)',
hintText: 'Add links: [text](url)',
helperText: 'Supports markdown links',
),
),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () {
final updatedItem = item.copyWith(
name: nameController.text.trim(),
description: descController.text.trim().isEmpty ? null : descController.text.trim(),
clearDescription: descController.text.trim().isEmpty,
);

final updatedItems = List<_PackingItem>.from(widget.category.items);
updatedItems[itemIndex] = updatedItem;

widget.versionFormData.packingCategories[widget.categoryIndex] =
widget.category.copyWith(items: updatedItems);

widget.onUpdate();
Navigator.pop(context);
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

/// Add waypoint dialog with Google Places search (for itinerary sections)
class _AddWaypointFromItineraryDialog extends StatefulWidget {
final WaypointType type;
final ll.LatLng? proximityBias;
final RouteWaypoint? existingWaypoint; // For editing

const _AddWaypointFromItineraryDialog({
required this.type,
this.proximityBias,
this.existingWaypoint,
});

@override
State<_AddWaypointFromItineraryDialog> createState() => _AddWaypointFromItineraryDialogState();
}

class _AddWaypointFromItineraryDialogState extends State<_AddWaypointFromItineraryDialog> {
final _searchController = TextEditingController();
final _nameController = TextEditingController();
final _descController = TextEditingController();
final _airbnbAddressController = TextEditingController();
final _placesService = GooglePlacesService();
POIAccommodationType? _accommodationType;
MealTime? _mealTime;
ActivityTime? _activityTime;
List<PlacePrediction> _searchResults = [];
PlaceDetails? _selectedPlace;
bool _searching = false;
bool _geocoding = false;
ll.LatLng? _airbnbLocation;
bool _airbnbAddressConfirmed = false;
Timer? _searchDebounce;
String _lastSearchedQuery = ''; // Track last successful search to prevent duplicates

@override
void initState() {
super.initState();
_searchController.addListener(_onSearchChanged);
// Pre-fill if editing
if (widget.existingWaypoint != null) {
final wp = widget.existingWaypoint!;
_nameController.text = wp.name;
_descController.text = wp.description ?? '';
_accommodationType = wp.accommodationType;
_mealTime = wp.mealTime;
_activityTime = wp.activityTime;
if (wp.accommodationType == POIAccommodationType.airbnb) {
_airbnbAddressController.text = wp.address ?? '';
_airbnbLocation = wp.position;
_airbnbAddressConfirmed = true;
}
}
}

@override
void dispose() {
_searchController.dispose();
_nameController.dispose();
_descController.dispose();
_airbnbAddressController.dispose();
_searchDebounce?.cancel();
super.dispose();
}

void _onSearchChanged() {
final query = _searchController.text.trim();

// Check if user pasted a Google Maps link
if (GoogleLinkParser.isGoogleMapsUrl(query)) {
// ✅ ADD DEBOUNCE: Wait 300ms before processing
_searchDebounce?.cancel();
_searchDebounce = Timer(const Duration(milliseconds: 500), () {
if (mounted && _searchController.text.trim() == query) {
_handleGoogleLink(query);
}
});
return;
}

// Don't search if query is same as last successful search
if (query == _lastSearchedQuery) {
return;
}

if (query.length < 3) {
setState(() {
_searchResults = [];
_searching = false;
});
_lastSearchedQuery = ''; // Reset last searched query
return;
}

_searchDebounce?.cancel();
// Optimized: 600ms debounce reduces API calls by 90% while maintaining responsiveness
_searchDebounce = Timer(const Duration(milliseconds: 600), () {
_performSearch(query);
});
}

/// Handle Google Maps link paste
Future<void> _handleGoogleLink(String url) async {
// Show immediate feedback
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars();
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Row(
children: [
SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
),
SizedBox(width: 12),
Text('Processing Google Maps link...'),
],
),
duration: Duration(seconds: 30), // Long duration
),
);
}

setState(() => _searching = true);

try {
// Try to extract place ID from URL
String? placeId = GoogleLinkParser.extractPlaceId(url);

// If not found, try expanding short URL
if (placeId == null && (url.contains('goo.gl') || url.contains('share.google'))) {
Log.i('waypoint_dialog', 'Expanding short URL...');
placeId = await GoogleLinkParser.expandShortUrl(url);
}

if (placeId != null) {
Log.i('waypoint_dialog', 'Place ID extracted: $placeId');

// Fetch place details directly
final details = await _placesService.getPlaceDetails(placeId);

if (details != null && mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
setState(() {
_selectedPlace = details;
_nameController.text = details.name;
_descController.text = details.address ?? '';
_searchController.text = details.name;
_searching = false;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('✓ Place loaded from Google link!'),
backgroundColor: Colors.green,
duration: Duration(seconds: 2),
),
);
return;
}
}

// Failed to extract place - CRITICAL FIX: Clear the search field!
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
setState(() {
_searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
_searching = false;
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Could not extract place from this link. Try searching instead.'),
backgroundColor: Colors.orange,
duration: Duration(seconds: 3),
),
);
}
} catch (e) {
Log.e('waypoint_dialog', 'Failed to process Google link', e);

// CRITICAL FIX: Clear the search field on any error!
if (mounted) {
ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
setState(() {
_searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
_searching = false;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error processing link: ${e.toString()}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
}
}

Future<void> _performSearch(String query) async {
setState(() => _searching = true);

try {
List<String>? typeFilters;
switch (widget.type) {
case WaypointType.restaurant:
typeFilters = ['restaurant', 'cafe', 'bar'];
break;
case WaypointType.accommodation:
typeFilters = ['lodging', 'hotel'];
break;
case WaypointType.activity:
typeFilters = ['tourist_attraction'];
break;
case WaypointType.viewingPoint:
typeFilters = ['tourist_attraction'];
break;
case WaypointType.servicePoint:
case WaypointType.routePoint:
// Don't filter by type for service points and route points to avoid API errors
// Let the search query determine the results
typeFilters = null;
break;
}

final results = await _placesService.searchPlaces(
query: query,
proximity: widget.proximityBias,
types: typeFilters,
);

if (mounted) {
setState(() {
_searchResults = results;
_searching = false;
_lastSearchedQuery = query; // Remember successful search to prevent duplicates
});
}
} catch (e) {
Log.e('waypoint_dialog', 'Search failed', e);
if (mounted) {
setState(() => _searching = false);
}
}
}

Future<void> _selectPlace(PlacePrediction prediction) async {
final details = await _placesService.getPlaceDetails(prediction.placeId);

if (details != null && mounted) {
setState(() {
_selectedPlace = details;
_nameController.text = details.name;
_descController.text = details.address ?? '';
_searchController.text = details.name;
_searchResults = [];
});
}
}

Future<void> _geocodeAirbnbAddress() async {
final address = _airbnbAddressController.text.trim();
if (address.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter an address first')),
);
return;
}

setState(() => _geocoding = true);

final location = await _placesService.geocodeAddress(address);

setState(() => _geocoding = false);

if (location != null) {
setState(() {
_airbnbLocation = location;
_airbnbAddressConfirmed = true;
});
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Location found! ✓'), backgroundColor: Colors.green),
);
}
} else {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Could not find location. Please check the address.'),
backgroundColor: Colors.orange,
),
);
}
}
}

@override
Widget build(BuildContext context) => Dialog(
backgroundColor: Colors.transparent,
elevation: 0,
child: Container(
width: 480,
constraints: BoxConstraints(
maxWidth: MediaQuery.of(context).size.width * 0.95,
maxHeight: MediaQuery.of(context).size.height * 0.85,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.15),
blurRadius: 40,
offset: const Offset(0, 20),
spreadRadius: 0,
),
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 12,
offset: const Offset(0, 4),
),
],
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// Modern header
Container(
padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
decoration: BoxDecoration(
border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
),
child: Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Color(0xFF428A13), Color(0xFF2D5A27)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(12),
boxShadow: [
BoxShadow(
color: const Color(0xFF428A13).withValues(alpha: 0.3),
blurRadius: 8,
offset: const Offset(0, 4),
),
],
),
child: Icon(getWaypointIcon(widget.type), color: Colors.white, size: 24),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'${widget.existingWaypoint != null ? 'Edit' : 'Add'} ${getWaypointLabel(widget.type)}',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w700,
color: Colors.grey.shade900,
letterSpacing: -0.5,
),
),
const SizedBox(height: 2),
Text(
'Search or paste Google Maps link',
style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
),
],
),
),
Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: () => Navigator.pop(context),
child: Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: Colors.grey.shade100,
borderRadius: BorderRadius.circular(12),
),
child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
),
),
),
],
),
),
Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// Modern search section
Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: Colors.grey.shade200),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.04),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: TextField(
controller: _searchController,
decoration: InputDecoration(
hintText: 'Search for a place or paste Google Maps link',
hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
helperText: 'Tip: You can paste Google Maps share links directly',
helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
prefixIcon: Padding(
padding: const EdgeInsets.all(14),
child: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
),
suffixIcon: _searching
? const Padding(
padding: EdgeInsets.all(12),
child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
)
: null,
border: InputBorder.none,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
),
),
),
const SizedBox(height: 12),
if (_searchResults.isNotEmpty) ...[
Container(
constraints: const BoxConstraints(maxHeight: 200),
decoration: BoxDecoration(
border: Border.all(color: Colors.grey.shade300),
borderRadius: BorderRadius.circular(8),
),
child: ListView.separated(
shrinkWrap: true,
itemCount: _searchResults.length,
separatorBuilder: (_, __) => const Divider(height: 1),
itemBuilder: (_, i) {
final result = _searchResults[i];
return ListTile(
dense: true,
leading: Icon(getWaypointIcon(widget.type), size: 20),
title: Text(result.text),
onTap: () => _selectPlace(result),
);
},
),
),
const SizedBox(height: 8),
// ✅ "Powered by Google" Attribution
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Image.network(
'https://developers.google.com/static/maps/images/powered-by-google-on-white.png',
height: 16,
errorBuilder: (_, __, ___) => Text(
'Powered by Google',
style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
),
),
],
),
],
if (_selectedPlace != null) ...[
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.green.shade50,
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.green.shade200),
),
child: Row(
children: [
Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
_selectedPlace!.name,
style: const TextStyle(fontWeight: FontWeight.w600),
),
if (_selectedPlace!.rating != null)
Text(
'⭐ ${_selectedPlace!.rating!.toStringAsFixed(1)}',
style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
),
],
),
),
IconButton(
icon: const Icon(Icons.close, size: 18),
onPressed: () => setState(() {
_selectedPlace = null;
_searchController.clear();
}),
),
],
),
),
const SizedBox(height: 4),
// ✅ "Powered by Google" Attribution
Text(
'Powered by Google Places',
style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
),
],
const SizedBox(height: 16),
if (widget.type == WaypointType.accommodation) ...[
const Text('Accommodation Type *', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: ChoiceChip(
label: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.hotel, size: 16),
SizedBox(width: 4),
Text('Hotel'),
],
),
selected: _accommodationType == POIAccommodationType.hotel,
onSelected: (selected) {
if (selected) setState(() => _accommodationType = POIAccommodationType.hotel);
},
),
),
const SizedBox(width: 8),
Expanded(
child: ChoiceChip(
label: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.home, size: 16),
SizedBox(width: 4),
Text('Airbnb'),
],
),
selected: _accommodationType == POIAccommodationType.airbnb,
onSelected: (selected) {
if (selected) setState(() => _accommodationType = POIAccommodationType.airbnb);
},
),
),
],
),
if (_accommodationType == POIAccommodationType.airbnb) ...[
const SizedBox(height: 16),
const Text('Airbnb Property', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
TextField(
controller: _airbnbAddressController,
decoration: InputDecoration(
labelText: 'Address or Location',
hintText: 'e.g., 123 Main St, Oslo, Norway',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
helperText: 'We\'ll use this to place the marker on the map',
),
),
const SizedBox(height: 8),
OutlinedButton.icon(
onPressed: _geocoding ? null : _geocodeAirbnbAddress,
icon: _geocoding
? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
: const Icon(Icons.my_location, size: 18),
label: Text(_geocoding ? 'Finding...' : 'Find Location'),
),
if (_airbnbAddressConfirmed)
Padding(
padding: const EdgeInsets.only(top: 8),
child: Row(
children: [
Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
const SizedBox(width: 4),
Text(
'Location confirmed',
style: TextStyle(color: Colors.green.shade700, fontSize: 12),
),
],
),
),
],
const SizedBox(height: 16),
],
// Meal time selection for restaurants
if (widget.type == WaypointType.restaurant) ...[
const Text('Meal Time', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: MealTime.values.map((time) {
final isSelected = _mealTime == time;
return ChoiceChip(
label: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getMealTimeIcon(time), size: 14),
const SizedBox(width: 4),
Text(getMealTimeLabel(time)),
],
),
selected: isSelected,
onSelected: (selected) {
setState(() => _mealTime = selected ? time : null);
},
);
}).toList(),
),
const SizedBox(height: 16),
],
// Activity time selection for activities
if (widget.type == WaypointType.activity) ...[
const Text('Activity Time', style: TextStyle(fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: ActivityTime.values.map((time) {
final isSelected = _activityTime == time;
return ChoiceChip(
label: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(getActivityTimeIcon(time), size: 14),
const SizedBox(width: 4),
Text(getActivityTimeLabel(time)),
],
),
selected: isSelected,
onSelected: (selected) {
setState(() => _activityTime = selected ? time : null);
},
);
}).toList(),
),
const SizedBox(height: 16),
],
TextField(
controller: _nameController,
decoration: InputDecoration(
labelText: 'Name *',
hintText: 'e.g., Café Aurora',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
),
const SizedBox(height: 12),
TextField(
controller: _descController,
maxLines: 2,
decoration: InputDecoration(
labelText: 'Description (optional)',
hintText: 'Add details...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
),
],
),
),
),
const Divider(height: 1),
Padding(
padding: const EdgeInsets.all(16),
child: Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
const SizedBox(width: 8),
FilledButton(
onPressed: _canSave() ? _save : null,
child: Text(widget.existingWaypoint != null ? 'Update' : 'Add'),
),
],
),
),
],
),
),
);

bool _canSave() {
if (_nameController.text.trim().isEmpty) return false;
if (widget.type == WaypointType.accommodation && _accommodationType == null) return false;
if (_accommodationType == POIAccommodationType.airbnb && !_airbnbAddressConfirmed) return false;
// When editing, we don't need a selected place (we already have the waypoint data)
if (widget.existingWaypoint == null && _accommodationType != POIAccommodationType.airbnb && _selectedPlace == null) return false;
return true;
}

void _save() async {
if (!_canSave()) return;

String? photoUrl;
if (_selectedPlace?.photoReference != null) {
final waypointId = const Uuid().v4();

// Show loading indicator
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Row(
children: [
SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
SizedBox(width: 12),
Text('Caching photo...'),
],
),
duration: Duration(seconds: 2),
),
);
}

// Use cached photo method
photoUrl = await _placesService.getCachedPhotoUrl(
_selectedPlace!.photoReference!,
waypointId,
);
}

ll.LatLng position;
if (_accommodationType == POIAccommodationType.airbnb && _airbnbLocation != null) {
position = _airbnbLocation!;
} else if (_selectedPlace != null) {
position = _selectedPlace!.location;
} else if (widget.existingWaypoint != null) {
// When editing, use existing waypoint's position if no new place selected
position = widget.existingWaypoint!.position;
} else {
return;
}

final waypoint = RouteWaypoint(
id: widget.existingWaypoint?.id,
type: widget.type,
position: position,
name: _nameController.text.trim(),
description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
order: widget.existingWaypoint?.order ?? 0,
googlePlaceId: _selectedPlace?.placeId ?? widget.existingWaypoint?.googlePlaceId,
address: _accommodationType == POIAccommodationType.airbnb
? _airbnbAddressController.text.trim()
: (_selectedPlace?.address ?? widget.existingWaypoint?.address),
rating: _selectedPlace?.rating ?? widget.existingWaypoint?.rating,
website: _selectedPlace?.website ?? widget.existingWaypoint?.website,
phoneNumber: _selectedPlace?.phoneNumber ?? widget.existingWaypoint?.phoneNumber,
photoUrl: photoUrl ?? widget.existingWaypoint?.photoUrl,
accommodationType: widget.type == WaypointType.accommodation ? _accommodationType : null,
mealTime: widget.type == WaypointType.restaurant ? _mealTime : null,
activityTime: widget.type == WaypointType.activity ? _activityTime : null,
);

Navigator.of(context).pop(waypoint);
}
}
