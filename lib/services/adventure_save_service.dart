import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/state/day_form_state.dart';
import 'package:waypoint/utils/logger.dart';
import 'dart:typed_data';

/// Service for saving adventure form state to Firestore
/// Handles validation, image uploads, and data composition
class AdventureSaveService {
  final PlanService _planService;
  final StorageService _storageService;
  final UserService _userService;
  
  Timer? _autoSaveTimer;
  
  AdventureSaveService({
    required PlanService planService,
    required StorageService storageService,
    required UserService userService,
  }) : _planService = planService,
       _storageService = storageService,
       _userService = userService;
  
  /// Save draft without validation
  Future<SaveResult> saveDraft(AdventureFormState state) async {
    if (state.editingPlan == null) {
      return SaveResult.failed('No plan to save');
    }
    
    try {
      state.isSaving = true;
      state.saveStatus = 'Saving...';
      
      // Upload cover image if available
      String heroImageUrl = state.editingPlan!.heroImageUrl;
      if (state.coverImageBytes != null) {
        try {
          final path = _storageService.coverImagePath(
            state.editingPlan!.id,
            state.coverImageExtension ?? 'jpg',
          );
          heroImageUrl = await _storageService.uploadImage(
            path: path,
            bytes: state.coverImageBytes!,
            contentType: 'image/${state.coverImageExtension ?? 'jpeg'}',
          );
        } catch (e) {
          Log.w('adventure_save', 'Failed to upload cover image: $e');
        }
      } else if (state.heroImageUrlCtrl.text.trim().isNotEmpty) {
        heroImageUrl = state.heroImageUrlCtrl.text.trim();
      }
      
      // Build versions from form state
      final planPrice = double.tryParse(
        state.priceCtrl.text.replaceAll(',', '.'),
      ) ?? 0.0;
      
      final versions = <PlanVersion>[];
      // Use indexed loop instead of indexOf to avoid O(n²) performance
      for (var i = 0; i < state.versions.length; i++) {
        final versionState = state.versions[i];
        final duration = versionState.daysCount > 0 ? versionState.daysCount : 1;
        
        // Get existing days for this version
        final existingDays = i < state.editingPlan!.versions.length
            ? state.editingPlan!.versions[i].days
            : const <DayItinerary>[];
        
        // Compose days with parallel image uploads
        final days = await composeDays(
          versionState,
          state.editingPlan!.id,
          state.activityCategory,
          existing: existingDays,
        );
        
        // Preserve stable version ID to avoid deleting/recreating versions
        final versionId = (i < state.editingPlan!.versions.length)
            ? state.editingPlan!.versions[i].id
            : versionState.tempId;
        
        versions.add(PlanVersion(
          id: versionId,
          name: versionState.nameCtrl.text.trim().isEmpty
              ? 'Version ${i + 1}'
              : versionState.nameCtrl.text.trim(),
          durationDays: duration,
          difficulty: Difficulty.none,
          comfortType: ComfortType.none,
          price: planPrice,
          days: days,
          packingCategories: _composePackingCategories(versionState),
          transportationOptions: _composeTransportationOptions(versionState),
          faqItems: const [], // FAQ is stored at plan level
        ));
      }
      
      // Extract FAQ items from plan level (FAQ items are stored at plan level in AdventureFormState)
      final planFaqItems = _composeFAQItems(state);
      
      // Update existing plan
      // Determine location string for backward compatibility
      final locationString = state.locations.isNotEmpty
          ? state.locations.first.fullAddress
          : state.locationCtrl.text.trim();
      
      final updated = state.editingPlan!.copyWith(
        name: state.nameCtrl.text.trim().isEmpty
            ? 'Untitled Adventure'
            : state.nameCtrl.text.trim(),
        description: state.descriptionCtrl.text.trim(),
        heroImageUrl: heroImageUrl,
        location: locationString,
        basePrice: versions.isEmpty
            ? 0.0
            : versions.map((v) => v.price).reduce((a, b) => a < b ? a : b),
        versions: versions,
        isPublished: state.isPublished,
        updatedAt: DateTime.now(),
        activityCategory: state.activityCategory,
        accommodationType: state.accommodationType,
        faqItems: planFaqItems,
        bestSeasons: state.bestSeasons,
        isEntireYear: state.isEntireYear,
        showPrices: state.showPrices,
        locations: state.locations, // New multi-location support
        mediaItems: state.mediaItems.isNotEmpty ? state.mediaItems : null,
        highlightItems: state.highlightItems.isNotEmpty ? state.highlightItems : null,
        privacyMode: state.privacyMode,
      );
      
      await _planService.updatePlanWithVersions(updated);
      
      state.saveStatus = 'Saved';
      state.lastSavedAt = DateTime.now();
      
      return SaveResult.ok(updated.id);
    } catch (e, stack) {
      Log.e('adventure_save', 'Save failed', e, stack);
      state.saveStatus = 'Failed to save';
      return SaveResult.failed(e.toString());
    } finally {
      state.isSaving = false;
    }
  }
  
  /// Save with validation
  Future<SaveResult> saveAndValidate(AdventureFormState state) async {
    final errors = validate(state);
    if (errors.isNotEmpty) {
      return SaveResult.validationFailed(errors);
    }
    return saveDraft(state);
  }
  
  /// Save AI-generated Prepare and LocalTips data to a specific version
  /// Unified save path - saves to version subcollection
  Future<SaveResult> saveAIData(
    String planId,
    String versionId,
    Prepare prepare,
    LocalTips localTips,
  ) async {
    try {
      // Check if there's actual data (not just empty objects)
      final hasPrepareData = prepare.travelInsurance != null ||
          prepare.visa != null ||
          prepare.passport != null ||
          prepare.permits.isNotEmpty ||
          prepare.vaccines != null ||
          prepare.climate != null;
      
      final hasLocalTipsData = localTips.emergency != null ||
          localTips.messagingApp != null ||
          localTips.etiquette.isNotEmpty ||
          localTips.tipping != null ||
          localTips.basicPhrases.isNotEmpty ||
          localTips.foodSpecialties.isNotEmpty ||
          localTips.foodWarnings.isNotEmpty;
      
      if (!hasPrepareData && !hasLocalTipsData) {
        return SaveResult.failed('No data to save');
      }
      
      // Save to version subcollection
      final versionRef = FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .collection('versions')
          .doc(versionId);
      
      await versionRef.update({
        if (hasPrepareData) 'prepare': prepare.toJson(),
        if (hasLocalTipsData) 'local_tips': localTips.toJson(),
        'ai_generated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      Log.i('adventure_save', 'AI-generated data saved to version $versionId in plan $planId');
      return SaveResult.ok(planId);
    } catch (e, stack) {
      Log.e('adventure_save', 'Failed to save AI data', e, stack);
      return SaveResult.failed(e.toString());
    }
  }
  
  /// Compose days from version form state with parallel image uploads
  Future<List<DayItinerary>> composeDays(
    VersionFormState version,
    String planId,
    ActivityCategory? activityCategory, {
    List<DayItinerary> existing = const [],
  }) async {
    final duration = version.daysCount;
    final byNum = {for (final d in existing) d.dayNum: d};
    
    // Parallel image uploads via Future.wait
    final uploadFutures = <Future<String?>>[];
    for (int i = 1; i <= duration; i++) {
      final day = version.getDayState(i);
      if (day.newImageBytes.isNotEmpty) {
        uploadFutures.add(_uploadDayImage(planId, i, day));
      } else {
        uploadFutures.add(Future.value(day.existingImageUrls.isNotEmpty ? day.existingImageUrls.first : null));
      }
    }
    final imageUrls = await Future.wait(uploadFutures);
    
    // Assemble days — write ALL controller data regardless of activity type
    // Activity type filtering is UI-only (ActivityAwareBuilder)
    // This preserves data when switching activity types (hiking → city → hiking)
    final days = <DayItinerary>[];
    for (int i = 1; i <= duration; i++) {
      final day = version.getDayState(i);
      final prev = byNum[i];
      
      // Build stay info from form controllers
      final link = day.stayUrlCtrl.text.trim();
      final cost = double.tryParse(day.stayCostCtrl.text.replaceAll(',', '.'));
      final meta = day.stayMeta;
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
      
      // Extract waypoints from route
      final route = day.route;
      final waypoints = route?.poiWaypoints
              .map((json) => RouteWaypoint.fromJson(json))
              .toList() ??
          [];
      
      // Legacy form data removed - accommodations/restaurants/activities are now managed via waypoints
      // For backward compatibility, save empty lists
      final accommodations = <AccommodationInfo>[];
      final restaurants = <RestaurantInfo>[];
      final activities = <ActivityInfo>[];
      
      days.add(DayItinerary(
        dayNum: i,
        title: day.titleCtrl.text.trim().isEmpty
            ? (prev?.title ?? 'Day $i')
            : day.titleCtrl.text.trim(),
        description: day.descCtrl.text.trim().isEmpty
            ? (prev?.description ?? '')
            : day.descCtrl.text.trim(),
        distanceKm: double.tryParse(day.distanceCtrl.text.replaceAll(',', '.')) ??
            (prev?.distanceKm ?? 0),
        estimatedTimeMinutes: ((double.tryParse(
                  day.timeCtrl.text.replaceAll(',', '.'),
                ) ??
                (prev?.estimatedTimeMinutes ?? 0).toDouble()) *
            60).toInt(),
        stay: stay,
        accommodations: accommodations,
        restaurants: restaurants,
        activities: activities,
        photos: imageUrls[i - 1] != null
            ? [imageUrls[i - 1]!]
            : (prev?.photos ?? const []),
        startLat: day.start?.latitude ?? prev?.startLat,
        startLng: day.start?.longitude ?? prev?.startLng,
        endLat: day.end?.latitude ?? prev?.endLat,
        endLng: day.end?.longitude ?? prev?.endLng,
        route: day.route ?? prev?.route,
        komootLink: day.komootLinkCtrl.text.trim().isEmpty
            ? (prev?.komootLink)
            : day.komootLinkCtrl.text.trim(),
        allTrailsLink: day.allTrailsLinkCtrl.text.trim().isEmpty
            ? (prev?.allTrailsLink)
            : day.allTrailsLinkCtrl.text.trim(),
        routeInfo: day.routeInfo ?? prev?.routeInfo,
        gpxRoute: day.gpxRoute ?? prev?.gpxRoute,
      ));
    }
    return days;
  }
  
  /// Upload day image and return URL
  Future<String?> _uploadDayImage(String planId, int dayNum, DayFormState day) async {
    if (day.newImageBytes.isEmpty) return day.existingImageUrls.isNotEmpty ? day.existingImageUrls.first : null;
    
    try {
      Log.i('adventure_save', 'Uploading image for day $dayNum...');
      final extension = day.newImageExtensions.isNotEmpty ? day.newImageExtensions.first : 'jpg';
      final path = _storageService.dayImagePath(planId, dayNum, extension);
      final url = await _storageService.uploadImage(
        path: path,
        bytes: day.newImageBytes.first,
        contentType: 'image/$extension',
      );
      Log.i('adventure_save', 'Day $dayNum image uploaded successfully');
      return url;
    } catch (e, stack) {
      Log.e('adventure_save', 'Failed to upload day $dayNum image', e, stack);
      return day.existingImageUrls.isNotEmpty ? day.existingImageUrls.first : null;
    }
  }
  
  /// Schedule auto-save
  void scheduleAutoSave(AdventureFormState state) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (state.editingPlan != null) {
        saveDraft(state);
      }
    });
  }
  
  /// Validate form state
  List<String> validate(AdventureFormState state) {
    final errors = <String>[];
    if (state.nameCtrl.text.trim().isEmpty) {
      errors.add('Name required');
    }
    if (state.locationSearch.selectedLocation == null) {
      errors.add('Location required');
    }
    if (state.descriptionCtrl.text.trim().isEmpty) {
      errors.add('Description required');
    }
    if (state.versions.isEmpty) {
      errors.add('At least one version required');
    }
    for (final v in state.versions) {
      if (v.daysCount <= 0) {
        errors.add('Version "${v.nameCtrl.text}" needs at least one day');
      }
    }
    return errors;
  }
  
  /// Compose packing categories from version form state
  List<PackingCategory> _composePackingCategories(VersionFormState version) {
    return version.packingCategories.map((cat) => PackingCategory(
      name: cat.nameCtrl.text.trim(),
      items: cat.items.map((item) => PackingItem(
        id: item.id,
        name: item.nameCtrl.text.trim(),
        description: item.descriptionCtrl?.text.trim(),
      )).toList(),
      description: cat.descriptionCtrl?.text.trim(),
    )).toList();
  }
  
  /// Compose transportation options from version form state
  List<TransportationOption> _composeTransportationOptions(VersionFormState version) {
    return version.transportationOptions
        .where((t) => t.titleCtrl.text.trim().isNotEmpty && t.types.isNotEmpty)
        .map((t) => TransportationOption(
              title: t.titleCtrl.text.trim(),
              description: t.descCtrl.text.trim(),
              types: List<TransportationType>.from(t.types),
            ))
        .toList();
  }
  
  /// Compose FAQ items from adventure form state
  /// FAQ items are stored at plan level in AdventureFormState
  List<FAQItem> _composeFAQItems(AdventureFormState formState) {
    return formState.faqItems
        .where((f) => f.questionCtrl.text.trim().isNotEmpty)
        .map((f) => FAQItem(
              question: f.questionCtrl.text.trim(),
              answer: f.answerCtrl.text.trim(),
            ))
        .toList();
  }
  
  void dispose() {
    _autoSaveTimer?.cancel();
  }
}

/// Result of a save operation
class SaveResult {
  final bool success;
  final String? planId;
  final List<String> errors;
  
  SaveResult.ok(this.planId)
      : success = true,
        errors = const [];
  
  SaveResult.failed(String error)
      : success = false,
        planId = null,
        errors = [error];
  
  SaveResult.validationFailed(this.errors)
      : success = false,
        planId = null;
}

