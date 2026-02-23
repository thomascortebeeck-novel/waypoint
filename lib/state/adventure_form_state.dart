import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/state/location_search_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/state/sub_form_states.dart';
import 'package:waypoint/utils/activity_config.dart';

/// Top-level form state — plan-level fields only
/// Prepare, LocalTips, Days are per-version (in VersionFormState)
class AdventureFormState extends ChangeNotifier {
  // --- Plan-level text fields ---
  final TextEditingController nameCtrl;
  final TextEditingController locationCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController heroImageUrlCtrl;
  final TextEditingController priceCtrl;
  
  // --- Location geocoding (extracted) ---
  final LocationSearchState locationSearch;
  
  // --- Multi-location support ---
  List<LocationInfo> _locations = [];
  List<LocationInfo> get locations => List.unmodifiable(_locations);
  
  void addLocation(LocationInfo location) {
    final config = getActivityConfig(_activityCategory);
    if (config != null && config.maxLocations != null && _locations.length >= config.maxLocations!) {
      return; // Max locations reached
    }
    _locations.add(location);
    _updateLocationOrder();
    notifyListeners();
  }
  
  void removeLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      _locations.removeAt(index);
      _updateLocationOrder();
      notifyListeners();
    }
  }
  
  void reorderLocations(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _locations.length ||
        newIndex < 0 || newIndex >= _locations.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _locations.removeAt(oldIndex);
    _locations.insert(newIndex, item);
    _updateLocationOrder();
    notifyListeners();
  }
  
  void _updateLocationOrder() {
    for (int i = 0; i < _locations.length; i++) {
      _locations[i] = _locations[i].copyWith(order: i);
    }
  }
  
  void setLocations(List<LocationInfo> locations) {
    _locations = List.from(locations);
    _updateLocationOrder();
    notifyListeners();
  }
  
  // --- Plan-level selections ---
  ActivityCategory? _activityCategory;
  ActivityCategory? get activityCategory => _activityCategory;
  set activityCategory(ActivityCategory? value) {
    if (_activityCategory != value) {
      _activityCategory = value;
      notifyListeners();
    }
  }
  
  AccommodationType? accommodationType;
  List<SeasonRange> bestSeasons;
  bool isEntireYear;
  bool showPrices;
  
  // --- Languages and highlights ---
  List<String> _languages = [];
  List<String> get languages => List.unmodifiable(_languages);
  
  List<String> _highlights = [];
  List<String> get highlights => List.unmodifiable(_highlights);
  
  // --- Image highlights from waypoints ---
  List<HighlightItem> _highlightItems = [];
  List<HighlightItem> get highlightItems => List.unmodifiable(_highlightItems);
  
  // --- Media items (images/videos) for carousel ---
  List<MediaItem> _mediaItems = [];
  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);
  
  void addMediaItem(MediaItem item) {
    if (_mediaItems.length >= 10) return; // Max 10 items
    _mediaItems.add(item);
    notifyListeners();
  }
  
  void removeMediaItem(int index) {
    if (index >= 0 && index < _mediaItems.length) {
      _mediaItems.removeAt(index);
      notifyListeners();
    }
  }
  
  void setMediaItems(List<MediaItem> items) {
    _mediaItems = List.from(items.take(10)); // Limit to 10
    notifyListeners();
  }
  
  // --- Privacy mode ---
  PlanPrivacyMode _privacyMode = PlanPrivacyMode.invited;
  PlanPrivacyMode get privacyMode => _privacyMode;
  set privacyMode(PlanPrivacyMode value) {
    if (_privacyMode != value) {
      _privacyMode = value;
      notifyListeners();
    }
  }
  
  void setLanguages(List<String> languages) {
    _languages = List.from(languages);
    notifyListeners();
  }
  
  void addHighlight(String text) {
    if (_highlights.length >= 10) return; // Max 10 items
    _highlights.add(text);
    notifyListeners();
  }
  
  void removeHighlight(int index) {
    if (index >= 0 && index < _highlights.length) {
      _highlights.removeAt(index);
      notifyListeners();
    }
  }
  
  void updateHighlight(int index, String text) {
    if (index >= 0 && index < _highlights.length) {
      _highlights[index] = text;
      notifyListeners();
    }
  }
  
  // --- Cover image ---
  Uint8List? coverImageBytes;
  String? coverImageExtension;
  bool _uploadingCoverImage = false;
  bool get uploadingCoverImage => _uploadingCoverImage;
  set uploadingCoverImage(bool value) {
    if (_uploadingCoverImage != value) {
      _uploadingCoverImage = value;
      notifyListeners();
    }
  }
  
  // --- Publish status ---
  bool _isPublished = true;
  bool get isPublished => _isPublished;
  set isPublished(bool value) {
    if (_isPublished != value) {
      _isPublished = value;
      notifyListeners();
    }
  }
  
  // --- FAQ items (plan-level) ---
  final List<FAQFormState> faqItems;
  
  // --- Versions ---
  final List<VersionFormState> versions;
  int _activeVersionIndex = 0;
  int get activeVersionIndex => _activeVersionIndex;
  set activeVersionIndex(int value) {
    if (_activeVersionIndex != value && value >= 0 && value < versions.length) {
      _activeVersionIndex = value;
      notifyListeners();
    }
  }
  
  /// Active version shortcut
  VersionFormState get activeVersion => versions[_activeVersionIndex];
  
  // --- Editing state ---
  Plan? editingPlan;
  
  // --- Save state ---
  bool _isSaving = false;
  bool get isSaving => _isSaving;
  set isSaving(bool value) {
    if (_isSaving != value) {
      _isSaving = value;
      notifyListeners();
    }
  }
  
  DateTime? lastSavedAt;
  
  String _saveStatus = '';
  String get saveStatus => _saveStatus;
  set saveStatus(String value) {
    if (_saveStatus != value) {
      _saveStatus = value;
      notifyListeners();
    }
  }
  
  AdventureFormState({
    required this.nameCtrl,
    required this.locationCtrl,
    required this.descriptionCtrl,
    required this.heroImageUrlCtrl,
    required this.priceCtrl,
    required this.locationSearch,
    ActivityCategory? activityCategory,
    this.accommodationType,
    this.bestSeasons = const [],
    this.isEntireYear = false,
    this.showPrices = false,
    List<String>? languages,
    List<String>? highlights,
    List<HighlightItem>? highlightItems,
    List<MediaItem>? mediaItems,
    PlanPrivacyMode privacyMode = PlanPrivacyMode.invited,
    this.coverImageBytes,
    this.coverImageExtension,
    bool uploadingCoverImage = false,
    bool isPublished = true,
    required this.faqItems,
    required this.versions,
    int activeVersionIndex = 0,
    this.editingPlan,
    bool isSaving = false,
    this.lastSavedAt,
    String saveStatus = '',
  }) : _activityCategory = activityCategory,
       _uploadingCoverImage = uploadingCoverImage,
       _isPublished = isPublished,
       _activeVersionIndex = activeVersionIndex,
       _isSaving = isSaving,
       _saveStatus = saveStatus {
    _languages = languages ?? [];
    _highlights = highlights ?? [];
    _highlightItems = highlightItems ?? [];
    _mediaItems = mediaItems ?? [];
    _privacyMode = privacyMode;
  }
  
  // --- Helper getters ---
  /// Primary location name for backward compatibility
  String get primaryLocationName => 
      _locations.isNotEmpty ? _locations.first.shortName : locationCtrl.text;
  
  // --- Validation ---
  bool get isGeneralInfoValid => 
    nameCtrl.text.trim().isNotEmpty &&
    (_locations.isNotEmpty || locationCtrl.text.trim().isNotEmpty) &&
    descriptionCtrl.text.trim().isNotEmpty &&
    (_locations.isNotEmpty || locationSearch.selectedLocation != null) &&
    _activityCategory != null && // Activity category is now required
    accommodationType != null; // Accommodation type is now required
  
  /// Validation for location step (Step 1)
  bool get isLocationStepValid {
    final config = getActivityConfig(_activityCategory);
    if (config == null) return false;
    return _locations.length >= config.minLocations &&
           (config.maxLocations == null || _locations.length <= config.maxLocations!);
  }
  
  // --- Activity type helpers ---
  bool get isOutdoorActivity {
    const outdoor = {
      ActivityCategory.hiking,
      ActivityCategory.cycling,
      ActivityCategory.climbing,
      ActivityCategory.skis,
    };
    return _activityCategory != null && outdoor.contains(_activityCategory);
  }
  
  bool get isCityActivity {
    const city = {
      ActivityCategory.cityTrips,
      ActivityCategory.tours,
    };
    return _activityCategory != null && city.contains(_activityCategory);
  }
  
  // --- Factories ---
  factory AdventureFormState.initial() {
    return AdventureFormState(
      nameCtrl: TextEditingController(),
      locationCtrl: TextEditingController(),
      descriptionCtrl: TextEditingController(),
      heroImageUrlCtrl: TextEditingController(),
      priceCtrl: TextEditingController(text: '2.00'),
      locationSearch: LocationSearchState.initial(),
      faqItems: [],
      versions: [VersionFormState.initial()],
    );
  }
  
  factory AdventureFormState.fromPlan(Plan plan) {
    // Create location search state and set selected location if coordinates exist
    final locationSearch = LocationSearchState.initial();
    locationSearch.selectedLocationName = plan.location;
    // Note: Coordinates would need to be geocoded separately if not stored
    
    // Create FAQ items from plan
    final faqItems = plan.faqItems.map((f) => FAQFormState.fromModel(f)).toList();
    
    // Create versions from plan
    final versions = plan.versions.map((v) => VersionFormState.fromVersion(v)).toList();
    
    final state = AdventureFormState(
      nameCtrl: TextEditingController(text: plan.name),
      locationCtrl: TextEditingController(text: plan.location),
      descriptionCtrl: TextEditingController(text: plan.description),
      heroImageUrlCtrl: TextEditingController(text: plan.heroImageUrl),
      priceCtrl: TextEditingController(text: plan.basePrice.toStringAsFixed(2)),
      locationSearch: locationSearch,
      activityCategory: plan.activityCategory,
      accommodationType: plan.accommodationType,
      bestSeasons: List<SeasonRange>.from(plan.bestSeasons),
      isEntireYear: plan.isEntireYear,
      showPrices: plan.showPrices,
      languages: plan.languages ?? [],
      highlights: plan.highlights ?? [],
      highlightItems: plan.highlightItems ?? [],
      mediaItems: plan.mediaItems ?? [],
      privacyMode: plan.privacyMode,
      faqItems: faqItems,
      versions: versions,
      activeVersionIndex: 0,
      isPublished: plan.isPublished,
    );
    
    // Load locations from plan (new format)
    if (plan.locations.isNotEmpty) {
      state.setLocations(plan.locations);
    } else if (plan.location.isNotEmpty) {
      // Legacy: migrate single location string to LocationInfo
      final shortName = plan.location.split(',').first.trim();
      state.setLocations([
        LocationInfo(
          shortName: shortName,
          fullAddress: plan.location,
          order: 0,
        ),
      ]);
    }
    
    state.editingPlan = plan;
    
    return state;
  }
  
  // --- Dispose ---
  @override
  void dispose() {
    nameCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    heroImageUrlCtrl.dispose();
    priceCtrl.dispose();
    locationSearch.dispose();
    for (final faq in faqItems) {
      faq.dispose();
    }
    for (final version in versions) {
      version.dispose();
    }
    super.dispose();
  }
}

