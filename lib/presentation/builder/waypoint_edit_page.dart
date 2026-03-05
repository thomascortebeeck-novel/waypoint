import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/core/theme/layout_tokens.dart';
import 'package:waypoint/core/models/waypoint_category.dart';
import 'package:waypoint/components/waypoint/waypoint_cream_chip.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/waypoint_edit_result.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/services/url_metadata_service.dart';
import 'package:waypoint/utils/waypoint_google_types_mapping.dart';
import 'package:waypoint/presentation/builder/waypoint_category_picker_sheet.dart';

/// Stippl-style full-page screen for adding or editing a waypoint.
/// Two-step flow (add mode): Step 1 = search / paste URL / add manually; Step 2 = form.
/// Edit mode opens directly at Step 2. Pops [WaypointEditResult] (WaypointSaved or WaypointDeleted).
class WaypointEditPage extends StatefulWidget {
  final String planId;
  final int versionIndex;
  final int dayNum;
  final String mode; // 'add' | 'edit'
  final DayRoute? initialRoute;
  final RouteWaypoint? existingWaypoint;
  final String tripName;
  /// Pre-fetched place (add mode only). When set, page opens at Step 2 with form prefilled; no extra API call.
  final PlaceDetails? preselectedPlace;

  const WaypointEditPage({
    super.key,
    required this.planId,
    required this.versionIndex,
    required this.dayNum,
    required this.mode,
    this.initialRoute,
    this.existingWaypoint,
    this.tripName = '',
    this.preselectedPlace,
  });

  @override
  State<WaypointEditPage> createState() => _WaypointEditPageState();
}

class _WaypointEditPageState extends State<WaypointEditPage> {
  static const _uuid = Uuid();
  static const _defaultPosition = ll.LatLng(0, 0); // sentinel when no coords (manual entry)

  late final bool _isEditMode;
  late bool _isStep2;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _estimatedPriceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _ratingController = TextEditingController(); // used when _placeDetails == null (manual/edit)

  WaypointType _selectedType = WaypointType.attraction;
  ll.LatLng? _latLng;
  MealTime? _mealTime;
  ActivityTime? _activityTime;
  List<Uint8List> _photoBytes = [];
  bool _isLoadingUrl = false;
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  String? _waypointId; // stable for add (initState) and edit; used for photo cache key

  /// Rating from API or manual entry. Read-only when _placeDetails != null.
  double? _rating;
  POIAccommodationType? _accommodationType;
  EatCategory? _eatCategory;
  AttractionCategory? _attractionCategory;
  SightCategory? _sightCategory;
  ServiceCategory? _serviceCategory;
  /// API/existing photo URLs (all place photos fetched and cached in Storage).
  /// _loadingPhoto true only while getCachedPhotoUrls is in progress, not when init from existingWaypoint.
  List<String> _googlePlacePhotoUrls = [];
  /// Live strip: URLs (Google-cached + already-uploaded) + pending uploads in _photoBytes. Replaced when user picks a new place.
  List<String> _currentPhotoUrls = [];
  /// Tags (sub-categories) for the current waypoint; cleared when category changes.
  List<String> _subCategoryTags = [];
  bool _loadingPhoto = false;
  /// Set when place selected from search; used for reviews, rating display, userRatingCount. If user changes category, reviews still from original place.
  PlaceDetails? _placeDetails;

  final GooglePlacesService _placesService = GooglePlacesService();
  final UrlMetadataService _urlMetadataService = UrlMetadataService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.mode == 'edit';
    _isStep2 = _isEditMode;
    if (widget.existingWaypoint != null) {
      final wp = widget.existingWaypoint!;
      _waypointId = wp.id;
      _nameController.text = wp.name;
      _addressController.text = wp.address ?? '';
      _descController.text = wp.description ?? '';
      _phoneController.text = wp.phoneNumber ?? '';
      _websiteController.text = wp.website ?? '';
      _rating = wp.rating;
      _accommodationType = wp.accommodationType;
      _eatCategory = wp.eatCategory;
      _attractionCategory = wp.attractionCategory;
      _sightCategory = wp.sightCategory;
      _serviceCategory = wp.serviceCategory;
      // 4-pill UI: map viewingPoint to Do (attraction)
      _selectedType = wp.type == WaypointType.viewingPoint
          ? WaypointType.attraction
          : wp.type;
      _latLng = wp.position;
      _mealTime = wp.mealTime;
      _activityTime = wp.activityTime;
      if (wp.estimatedPriceRange != null) {
        _priceMinController.text = wp.estimatedPriceRange!.min.toString();
        _priceMaxController.text = wp.estimatedPriceRange!.max.toString();
      }
      final priceVal = wp.estimatedPrice ?? (wp.estimatedPriceRange != null ? (wp.estimatedPriceRange!.min + wp.estimatedPriceRange!.max) / 2 : null);
      if (priceVal != null) _estimatedPriceController.text = priceVal.toString();
      _currentPhotoUrls = wp.photoUrls ?? (wp.photoUrl != null ? [wp.photoUrl!] : []);
      _subCategoryTags = List.from(wp.subCategoryTags ?? []);
      if (wp.photoUrl != null) _googlePlacePhotoUrls = [wp.photoUrl!];
      if (wp.rating != null) _ratingController.text = wp.rating!.toString();
    } else {
      _waypointId = _uuid.v4(); // stable for getCachedPhotoUrl so no duplicate cache on reopen
      if (widget.preselectedPlace != null) {
        _applyPlaceDetails(widget.preselectedPlace!);
      }
    }
  }

  /// Pre-fill form and go to Step 2 from PlaceDetails (used for preselectedPlace and _onPlaceSelected).
  void _applyPlaceDetails(PlaceDetails details) {
    _placeDetails = details;
    _nameController.text = details.name;
    _addressController.text = details.address ?? '';
    _descController.text = details.description ?? '';
    _phoneController.text = details.phoneNumber ?? '';
    _websiteController.text = details.website ?? '';
    _rating = details.rating;
    _applyPriceLevelToControllers(details.priceLevel);
    final suggestion = WaypointTypeSuggestion.fromGoogleTypes(details.types);
    _selectedType = suggestion.type == WaypointType.viewingPoint
        ? WaypointType.attraction
        : suggestion.type;
    _subCategoryTags = List.from(suggestion.subCategoryLabels);
    _accommodationType = suggestion.accommodationType ?? _accommodationType;
    _eatCategory = suggestion.eatCategory ?? _eatCategory;
    _attractionCategory = suggestion.attractionCategory ?? _attractionCategory;
    _sightCategory = suggestion.sightCategory ?? _sightCategory;
    _serviceCategory = suggestion.serviceCategory ?? _serviceCategory;
    _latLng = details.location;
    _isStep2 = true;
    final refs = details.photoReferences.isNotEmpty
        ? details.photoReferences
        : (details.photoReference != null ? [details.photoReference!] : <String>[]);
    if (refs.isNotEmpty) {
      _currentPhotoUrls = [];
      _googlePlacePhotoUrls = [];
      _loadingPhoto = true;
      final wid = _waypointId!;
      _placesService.getCachedPhotoUrls(refs, wid).then((urls) {
        if (!mounted) return;
        setState(() {
          _googlePlacePhotoUrls = urls;
          _currentPhotoUrls = List.from(urls);
          _loadingPhoto = false;
        });
      });
    } else {
      _currentPhotoUrls = [];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _estimatedPriceController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  String get _title {
    if (_isEditMode) return 'Edit ${_nameController.text.isNotEmpty ? _nameController.text : 'waypoint'}';
    if (_isStep2) {
      final typeLabel = _typeLabel(_selectedType);
      return 'Add $typeLabel to ${widget.tripName.isNotEmpty ? widget.tripName : 'trip'}';
    }
    return 'Add waypoint to ${widget.tripName.isNotEmpty ? widget.tripName : 'trip'}';
  }

  String _typeLabel(WaypointType t) => WaypointCategoryLabels.fromType(t);

  Future<void> _onSearchChanged(String value) async {
    final trimmed = value.trim();
    if (trimmed.startsWith('http')) return;
    if (trimmed.isEmpty || trimmed.length < 2) {
      setState(() => _predictions = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _placesService.searchPlaces(query: trimmed);
    if (mounted) setState(() { _predictions = results; _searching = false; });
  }

  void _onSearchSubmitted(String value) {
    final trimmed = value.trim();
    if (_looksLikeUrl(trimmed)) {
      _handleUrlInput(trimmed);
      return;
    }
    if (trimmed.isNotEmpty && _predictions.isNotEmpty) {
      _onPlaceSelected(_predictions.first);
    }
  }

  /// True if [text] looks like an http(s) URL so we trigger fetchMeta (fold function) instead of place search.
  bool _looksLikeUrl(String text) {
    final t = text.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  Future<void> _onPasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (_looksLikeUrl(text)) {
      _searchController.text = text;
      _handleUrlInput(text);
    } else {
      _searchController.text = text;
      _onSearchChanged(text);
    }
  }

  /// Trigger fetch from URL (fetchMeta Cloud Function) for the current search field content. Call when user has entered a URL and taps "Load link" or submits.
  void _loadLinkFromField() {
    final url = _searchController.text.trim();
    if (_looksLikeUrl(url)) _handleUrlInput(url);
  }

  Future<void> _handleUrlInput(String url) async {
    setState(() => _isLoadingUrl = true);
    try {
      final result = await _urlMetadataService.fetchFromUrl(url);
      if (result != null && mounted) {
        _nameController.text = result.name ?? '';
        _addressController.text = result.address ?? '';
        _descController.text = result.description ?? '';
        _websiteController.text = result.website ?? '';
        _latLng = result.latLng;
        if (result.imageUrl != null) {
          _googlePlacePhotoUrls = [result.imageUrl!];
          _currentPhotoUrls = [result.imageUrl!];
        }
        setState(() => _isStep2 = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load link. Add details manually.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load link.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUrl = false);
    }
  }

  /// Map priceLevel (0-4) to price min/max strings (dialog mapping) and single estimated price.
  void _applyPriceLevelToControllers(int? priceLevel) {
    if (priceLevel == null) return;
    switch (priceLevel) {
      case 1:
        _priceMinController.text = '10';
        _priceMaxController.text = '30';
        _estimatedPriceController.text = '20';
        break;
      case 2:
        _priceMinController.text = '30';
        _priceMaxController.text = '60';
        _estimatedPriceController.text = '45';
        break;
      case 3:
        _priceMinController.text = '60';
        _priceMaxController.text = '120';
        _estimatedPriceController.text = '90';
        break;
      case 4:
        _priceMinController.text = '120';
        _priceMaxController.text = '300';
        _estimatedPriceController.text = '210';
        break;
      default:
        break;
    }
  }

  Future<void> _onPlaceSelected(PlacePrediction prediction) async {
    final details = await _placesService.getPlaceDetails(prediction.placeId);
    if (details == null || !mounted) return;
    _applyPlaceDetails(details);
  }

  void _goToStep1() {
    setState(() => _isStep2 = false);
  }

  Future<void> _showCategoryPicker() async {
    final result = await showModalBottomSheet<WaypointType>(
      context: context,
      builder: (context) => WaypointCategoryPickerSheet(currentType: _selectedType),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedType = result;
        _subCategoryTags = [];
        if (result != WaypointType.accommodation) _accommodationType = null;
        if (result != WaypointType.restaurant) _eatCategory = null;
        if (result != WaypointType.attraction) _attractionCategory = null;
        if (result != WaypointType.viewingPoint) _sightCategory = null;
        if (result != WaypointType.service) _serviceCategory = null;
      });
    }
  }

  /// Sanitize website: empty → null; else prepend https:// if missing; if result has no '.' save null.
  String? _sanitizeWebsite(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    String url = trimmed;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
    if (!url.contains('.')) return null;
    return url;
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }
    final route = widget.initialRoute ?? const DayRoute(
      geometry: {},
      distance: 0,
      duration: 0,
      routePoints: [],
      poiWaypoints: [],
    );
    final waypoints = route.poiWaypoints
        .map((e) => RouteWaypoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final maxOrder = waypoints.isEmpty ? 0 : waypoints.map((w) => w.order).reduce((a, b) => a > b ? a : b);
    final position = _latLng ?? _defaultPosition;
    final id = _waypointId ?? _uuid.v4();

    double? minPrice;
    double? maxPrice;
    if (_priceMinController.text.isNotEmpty) minPrice = double.tryParse(_priceMinController.text);
    if (_priceMaxController.text.isNotEmpty) maxPrice = double.tryParse(_priceMaxController.text);
    PriceRange? priceRange;
    if (minPrice != null || maxPrice != null) {
      priceRange = PriceRange(
        min: minPrice ?? 0,
        max: maxPrice ?? 0,
      );
    }
    final estimatedPrice = _estimatedPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_estimatedPriceController.text.trim());

    // Upload each pending photo with a unique path to avoid collisions
    final List<String> uploadedUrls = [];
    if (_photoBytes.isNotEmpty && id.isNotEmpty) {
      final prefix = (widget.planId.isEmpty || widget.planId == 'new')
          ? 'waypoints/$id'
          : 'plans/${widget.planId}/waypoints/$id';
      for (final bytes in _photoBytes) {
        try {
          final path = '$prefix/${_uuid.v4()}.jpg';
          final url = await _storageService.uploadImage(
            path: path,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
          uploadedUrls.add(url);
        } catch (_) {}
      }
    }
    final List<String> allUrls = [..._currentPhotoUrls, ...uploadedUrls];
    final String? photoUrl = allUrls.isNotEmpty ? allUrls.first : null;

    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final website = _sanitizeWebsite(_websiteController.text);
    // googlePlaceId may not match displayed place if user edited name/address after place selection.
    final googlePlaceId = _placeDetails?.placeId ?? widget.existingWaypoint?.googlePlaceId;

    // Use typed subcategory fields from chips (single source of truth); persist as subCategoryTags for display/backward compat.
    final accommodationType = _selectedType == WaypointType.accommodation ? _accommodationType : null;
    final eatCategory = _selectedType == WaypointType.restaurant ? _eatCategory : null;
    final mealTime = _selectedType == WaypointType.restaurant ? _mealTime : null;
    final attractionCategory = _selectedType == WaypointType.attraction ? _attractionCategory : null;
    final activityTime = _selectedType == WaypointType.attraction ? _activityTime : null;
    final sightCategory = _selectedType == WaypointType.viewingPoint ? _sightCategory : null;
    final serviceCategory = _selectedType == WaypointType.service ? _serviceCategory : null;
    // Build subCategoryTags from typed fields for display/backward compat (single tag from selected chip).
    final List<String>? subCategoryTags = _subCategoryTagsFromTyped(
      selectedType: _selectedType,
      accommodationType: accommodationType,
      eatCategory: eatCategory,
      attractionCategory: attractionCategory,
      sightCategory: sightCategory,
      serviceCategory: serviceCategory,
    );

    RouteWaypoint wp;
    if (_isEditMode && widget.existingWaypoint != null) {
      final existing = widget.existingWaypoint!;
      wp = existing.copyWith(
        name: name,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        position: position,
        type: _selectedType,
        mealTime: mealTime,
        activityTime: activityTime,
        estimatedPriceRange: priceRange,
        estimatedPrice: estimatedPrice,
        photoUrl: photoUrl,
        photoUrls: allUrls.isEmpty ? null : allUrls,
        googlePlaceId: googlePlaceId,
        phoneNumber: phone,
        rating: _rating,
        website: website,
        accommodationType: accommodationType,
        eatCategory: eatCategory,
        attractionCategory: attractionCategory,
        sightCategory: sightCategory,
        serviceCategory: serviceCategory,
        subCategoryTags: subCategoryTags,
      );
      final index = waypoints.indexWhere((w) => w.id == id);
      if (index >= 0) {
        waypoints[index] = wp;
      } else {
        waypoints.add(wp);
      }
    } else {
      wp = RouteWaypoint(
        id: id,
        name: name,
        type: _selectedType,
        position: position,
        order: maxOrder + 1,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        mealTime: mealTime,
        activityTime: activityTime,
        estimatedPriceRange: priceRange,
        estimatedPrice: estimatedPrice,
        photoUrl: photoUrl,
        photoUrls: allUrls.isEmpty ? null : allUrls,
        googlePlaceId: googlePlaceId,
        phoneNumber: phone,
        rating: _rating,
        website: website,
        accommodationType: accommodationType,
        eatCategory: eatCategory,
        attractionCategory: attractionCategory,
        sightCategory: sightCategory,
        serviceCategory: serviceCategory,
        subCategoryTags: subCategoryTags,
      );
      waypoints.add(wp);
    }

    final updatedRoute = route.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    if (mounted) context.pop<WaypointEditResult>(WaypointSaved(updatedRoute));
  }

  void _delete() {
    if (_waypointId == null) return;
    context.pop<WaypointEditResult>(WaypointDeleted(_waypointId!));
  }

  Future<void> _addPhoto() async {
    final result = await _storageService.pickImage();
    if (result != null && mounted) {
      setState(() => _photoBytes.add(result.bytes));
    }
  }

  static const _photoSize = 90.0;

  Widget _buildAddPhotoCell() {
    return GestureDetector(
      onTap: _addPhoto,
      child: Container(
        width: _photoSize,
        height: _photoSize,
        decoration: BoxDecoration(
          color: BrandingLightTokens.formFieldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BrandingLightTokens.formFieldBorder,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 28, color: BrandingLightTokens.secondary),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: BrandingLightTokens.secondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BrandingLightTokens.formLabel,
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
    final hasAnyPhoto = _currentPhotoUrls.isNotEmpty || _photoBytes.isNotEmpty || _loadingPhoto;
    if (!hasAnyPhoto) {
              return _buildAddPhotoCell();
    }
    return SizedBox(
              height: _photoSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_loadingPhoto)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                        width: _photoSize,
                        height: _photoSize,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
          ..._currentPhotoUrls.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(e.value, width: _photoSize, height: _photoSize, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      final url = _currentPhotoUrls[e.key];
                      _currentPhotoUrls.removeAt(e.key);
                      if (url != null) _googlePlacePhotoUrls.remove(url);
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          )),
          ..._photoBytes.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(e.value, width: _photoSize, height: _photoSize, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => setState(() => _photoBytes.removeAt(e.key)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          )),
          Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: _buildAddPhotoCell(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static final _waypointEditBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: BrandingLightTokens.formFieldBorder),
  );

  InputDecoration _waypointEditDecoration({String? hintText, Widget? prefixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: BrandingLightTokens.formFieldBackground,
      border: _waypointEditBorder,
      enabledBorder: _waypointEditBorder,
      focusedBorder: _waypointEditBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandingLightTokens.error),
      ),
      hintText: hintText,
      hintStyle: const TextStyle(color: BrandingLightTokens.hint),
      prefixIcon: prefixIcon,
      prefixIconColor: BrandingLightTokens.secondary,
    );
  }

  Widget _formFieldSection(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: BrandingLightTokens.formLabel,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: BrandingLightTokens.formLabel,
        ),
      ),
    );
  }

  /// Returns only the rating widget (read-only box or TextField) for use in Phone|Rating 50/50 row.
  Widget _buildRatingContent() {
    if (_placeDetails != null) {
      final r = _placeDetails!.rating ?? _rating;
      final count = _placeDetails!.userRatingCount;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: BrandingLightTokens.formFieldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandingLightTokens.formFieldBorder),
        ),
        child: Row(
        children: [
          if (r != null) ...[
            Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text('${r.toStringAsFixed(1)} ★', style: Theme.of(context).textTheme.titleSmall),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
                Text('($count reviews)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandingLightTokens.hint)),
            ],
          ],
        ],
        ),
      );
    }
    return TextField(
      controller: _ratingController,
      decoration: _waypointEditDecoration(hintText: 'Optional').copyWith(prefixIcon: const Icon(Icons.star_outline, size: 20)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => setState(() => _rating = double.tryParse(v)),
    );
  }

  Widget _buildAccommodationTypeRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: POIAccommodationType.values.map((v) => WaypointCreamChip(
        label: getPOIAccommodationTypeLabel(v),
        selected: _accommodationType == v,
        onTap: () => setState(() => _accommodationType = _accommodationType == v ? null : v),
      )).toList(),
    );
  }

  Widget _buildEatCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EatCategory.values.map((v) => WaypointCreamChip(
        label: getEatCategoryLabel(v),
        selected: _eatCategory == v,
        onTap: () => setState(() => _eatCategory = _eatCategory == v ? null : v),
      )).toList(),
    );
  }

  Widget _buildAttractionCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AttractionCategory.values.map((v) => WaypointCreamChip(
        label: getAttractionCategoryLabel(v),
        selected: _attractionCategory == v,
        onTap: () => setState(() => _attractionCategory = _attractionCategory == v ? null : v),
      )).toList(),
    );
  }

  Widget _buildSightCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SightCategory.values.map((v) => WaypointCreamChip(
        label: getSightCategoryLabel(v),
        selected: _sightCategory == v,
        onTap: () => setState(() => _sightCategory = _sightCategory == v ? null : v),
      )).toList(),
    );
  }

  Widget _buildServiceCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [ServiceCategory.trainStation, ServiceCategory.carRental, ServiceCategory.bus, ServiceCategory.plane, ServiceCategory.bike, ServiceCategory.other]
          .map((v) => WaypointCreamChip(
        label: getServiceCategoryLabel(v),
        selected: _serviceCategory == v,
        onTap: () => setState(() => _serviceCategory = _serviceCategory == v ? null : v),
      )).toList(),
    );
  }

  /// Build subCategoryTags from typed chip fields (single source of truth) for persistence.
  /// Only adds the label for the currently selected type; null/empty filtered so we never persist [''].
  List<String>? _subCategoryTagsFromTyped({
    required WaypointType selectedType,
    POIAccommodationType? accommodationType,
    EatCategory? eatCategory,
    AttractionCategory? attractionCategory,
    SightCategory? sightCategory,
    ServiceCategory? serviceCategory,
  }) {
    final list = <String>[
      if (selectedType == WaypointType.accommodation && accommodationType != null) getPOIAccommodationTypeLabel(accommodationType),
      if (selectedType == WaypointType.restaurant && eatCategory != null) getEatCategoryLabel(eatCategory),
      if (selectedType == WaypointType.attraction && attractionCategory != null) getAttractionCategoryLabel(attractionCategory),
      if (selectedType == WaypointType.viewingPoint && sightCategory != null) getSightCategoryLabel(sightCategory),
      if (selectedType == WaypointType.service && serviceCategory != null) getServiceCategoryLabel(serviceCategory),
    ].where((s) => s.isNotEmpty).toList();
    return list.isEmpty ? null : list;
  }

  void _showReviewsSheet(List<PlaceReview> reviews) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  final text = review.text != null
                      ? (review.text!.length > 150 ? '${review.text!.substring(0, 150)}...' : review.text!)
                      : '';
                  return ListTile(
                    title: Text(review.authorName ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (review.rating != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Text(review.rating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                        if (text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _placeDetails!.reviews;
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showReviewsSheet(reviews),
            child: Row(
              children: [
                Icon(Icons.reviews_rounded, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text('Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...reviews.take(3).map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (review.rating != null) ...[
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text(review.rating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                      const SizedBox(width: 8),
                    ],
                    if (review.authorName != null)
                      Expanded(
                        child: Text(review.authorName!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
                if (review.text != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.text!.length > 150 ? '${review.text!.substring(0, 150)}...' : review.text!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  ),
                ],
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandingLightTokens.background,
      appBar: AppBar(
        backgroundColor: BrandingLightTokens.appBarGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit Waypoint' : 'Add waypoint',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isStep2 && _isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isStep2 ? _buildStep2() : _buildStep1(),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.formMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a new place to Day ${widget.dayNum}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a city, landmark, or hidden gem to your itinerary.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search place or paste link..',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              final url = value.text.trim();
              final showLoadLink = _looksLikeUrl(url) && !_isLoadingUrl;
              if (!showLoadLink) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _isLoadingUrl ? null : _loadLinkFromField,
                  icon: _isLoadingUrl
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link, size: 20),
                  label: Text(_isLoadingUrl ? 'Loading link…' : 'Load link'),
                ),
              );
            },
          ),
          if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          if (_predictions.isNotEmpty)
            ..._predictions.take(5).map((p) => ListTile(
              title: Text(p.text),
              onTap: () => _onPlaceSelected(p),
            )),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _isLoadingUrl ? null : _onPasteFromClipboard,
            icon: _isLoadingUrl ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link),
            label: const Text('Paste from clipboard'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _isStep2 = true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_location_alt, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Place you're looking for is not in the list? Add it manually",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey('step2'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.formMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isEditMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: _goToStep1,
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Back to search'),
              ),
            ),
          _buildPhotoSection(),
          const SizedBox(height: 16),
                _buildSectionLabel('Category'),
                _buildCategoryRow(),
                if (_selectedType == WaypointType.accommodation ||
                    _selectedType == WaypointType.restaurant ||
                    _selectedType == WaypointType.attraction ||
                    _selectedType == WaypointType.service) ...[
                  const SizedBox(height: 8),
                  _buildSectionLabel('Type'),
                  if (_selectedType == WaypointType.accommodation) _buildAccommodationTypeRow(),
                  if (_selectedType == WaypointType.restaurant) _buildEatCategoryRow(),
                  if (_selectedType == WaypointType.attraction) _buildAttractionCategoryRow(),
                  if (_selectedType == WaypointType.service) _buildServiceCategoryRow(),
                ],
                const SizedBox(height: 16),
                _formFieldSection('Name', TextField(
            controller: _nameController,
            decoration: _waypointEditDecoration(),
          )),
          const SizedBox(height: 16),
          _formFieldSection('Address', TextField(
            controller: _addressController,
            decoration: _waypointEditDecoration(),
          )),
          const SizedBox(height: 16),
          _formFieldSection('Description (optional)', TextField(
            controller: _descController,
            maxLines: 3,
            decoration: _waypointEditDecoration(),
          )),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _formFieldSection('Phone', TextField(
            controller: _phoneController,
                  decoration: _waypointEditDecoration().copyWith(prefixIcon: const Icon(Icons.phone_outlined, size: 20)),
            keyboardType: TextInputType.phone,
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _formFieldSection('Rating (1-5)', _buildRatingContent()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _formFieldSection('Website', TextField(
            controller: _websiteController,
            decoration: _waypointEditDecoration(),
            keyboardType: TextInputType.url,
          )),
          const SizedBox(height: 16),
          _formFieldSection('Price (estimation)', TextField(
            controller: _estimatedPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _waypointEditDecoration(hintText: 'Optional'),
          )),
          if (_selectedType == WaypointType.restaurant && (_eatCategory == null || _eatCategory == EatCategory.diningRestaurant)) ...[
            const SizedBox(height: 16),
            _formFieldSection('Meal time', DropdownButtonFormField<MealTime>(
              value: _mealTime,
              decoration: _waypointEditDecoration(),
              items: MealTime.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
              onChanged: (v) => setState(() => _mealTime = v),
            )),
          ],
          if (_selectedType == WaypointType.attraction) ...[
            const SizedBox(height: 16),
            _formFieldSection('Activity time', DropdownButtonFormField<ActivityTime>(
              value: _activityTime,
              decoration: _waypointEditDecoration(),
              items: ActivityTime.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _activityTime = v),
            )),
          ],
          if (_placeDetails?.reviews.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _buildReviewsSection(),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: BrandingLightTokens.appBarGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(_isEditMode ? 'Save Changes' : 'Add place to the list'),
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

  Widget _buildCategoryRow() {
    final pills = [
      (WaypointType.restaurant, WaypointCategoryLabels.eat),
      (WaypointType.accommodation, WaypointCategoryLabels.sleep),
      (WaypointType.service, WaypointCategoryLabels.move),
      (WaypointType.attraction, WaypointCategoryLabels.doAndSee),
    ];
    return Row(
      children: pills.map((p) {
        final type = p.$1;
        final label = p.$2;
        final selected = _selectedType == type;
        return Expanded(
          child: WaypointCreamChip(
            label: label,
              selected: selected,
            onTap: () {
              setState(() {
                _selectedType = type;
                _subCategoryTags = [];
                if (type != WaypointType.accommodation) _accommodationType = null;
                if (type != WaypointType.restaurant) _eatCategory = null;
                if (type != WaypointType.attraction) _attractionCategory = null;
                if (type != WaypointType.service) _serviceCategory = null;
                _sightCategory = null;
              });
            },
            borderRadius: 22,
            fillWidth: true,
            minHeight: 44,
          ),
            );
          }).toList(),
    );
  }
}
