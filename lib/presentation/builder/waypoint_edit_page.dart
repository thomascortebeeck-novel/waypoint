import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';
import 'package:waypoint/core/theme/colors.dart';
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
      _selectedType = wp.type;
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
    _selectedType = suggestion.type;
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

  String _typeLabel(WaypointType t) {
    switch (t) {
      case WaypointType.accommodation: return 'Sleep';
      case WaypointType.restaurant: return 'Eat & Drink';
      case WaypointType.attraction: return 'Do & See';
      case WaypointType.viewingPoint: return 'See';
      case WaypointType.service: return 'Move';
      default: return 'place';
    }
  }

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

    // Write first tag back to typed field via reverse mapping (plan §3)
    final String? firstTag = _subCategoryTags.isNotEmpty ? _subCategoryTags.first : null;
    final accommodationType = _selectedType == WaypointType.accommodation
        ? (firstTag != null ? accommodationTypeFromLabel(firstTag) : _accommodationType)
        : null;
    final eatCategory = _selectedType == WaypointType.restaurant
        ? (firstTag != null ? eatCategoryFromLabel(firstTag) : _eatCategory)
        : null;
    final mealTime = _selectedType == WaypointType.restaurant ? _mealTime : null;
    final attractionCategory = _selectedType == WaypointType.attraction
        ? (firstTag != null ? attractionCategoryFromLabel(firstTag) : _attractionCategory)
        : null;
    final activityTime = _selectedType == WaypointType.attraction ? _activityTime : null;
    final sightCategory = _selectedType == WaypointType.viewingPoint
        ? (firstTag != null ? sightCategoryFromLabel(firstTag) : _sightCategory)
        : null;
    final serviceCategory = _selectedType == WaypointType.service
        ? (firstTag != null ? serviceCategoryFromLabel(firstTag) : _serviceCategory)
        : null;

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
        subCategoryTags: _subCategoryTags.isEmpty ? null : _subCategoryTags,
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
        subCategoryTags: _subCategoryTags.isEmpty ? null : _subCategoryTags,
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

  Widget _buildPhotoSection() {
    final hasAnyPhoto = _currentPhotoUrls.isNotEmpty || _photoBytes.isNotEmpty || _loadingPhoto;
    if (!hasAnyPhoto) {
      return OutlinedButton.icon(
        onPressed: _addPhoto,
        icon: const Icon(Icons.add_photo_alternate, size: 20),
        label: const Text('Add photo'),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_loadingPhoto)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(e.value, width: 80, height: 80, fit: BoxFit.cover),
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(e.value, width: 80, height: 80, fit: BoxFit.cover),
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
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: _addPhoto,
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_photo_alternate, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow() {
    if (_placeDetails != null) {
      final r = _placeDetails!.rating ?? _rating;
      final count = _placeDetails!.userRatingCount;
      return Row(
        children: [
          if (r != null) ...[
            Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text('${r.toStringAsFixed(1)} ★', style: Theme.of(context).textTheme.titleSmall),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              Text('($count reviews)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ],
          ],
        ],
      );
    }
    return TextField(
      controller: _ratingController,
      decoration: const InputDecoration(labelText: 'Rating (optional)', border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => setState(() => _rating = double.tryParse(v)),
    );
  }

  Widget _buildAccommodationTypeRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: POIAccommodationType.values.map((v) => ChoiceChip(
        label: Text(getPOIAccommodationTypeLabel(v)),
        selected: _accommodationType == v,
        onSelected: (s) => setState(() => _accommodationType = s ? v : null),
      )).toList(),
    );
  }

  Widget _buildEatCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EatCategory.values.map((v) => ChoiceChip(
        label: Text(getEatCategoryLabel(v)),
        selected: _eatCategory == v,
        onSelected: (s) => setState(() => _eatCategory = s ? v : null),
      )).toList(),
    );
  }

  Widget _buildAttractionCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AttractionCategory.values.map((v) => ChoiceChip(
        label: Text(getAttractionCategoryLabel(v)),
        selected: _attractionCategory == v,
        onSelected: (s) => setState(() => _attractionCategory = s ? v : null),
      )).toList(),
    );
  }

  Widget _buildSightCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SightCategory.values.map((v) => ChoiceChip(
        label: Text(getSightCategoryLabel(v)),
        selected: _sightCategory == v,
        onSelected: (s) => setState(() => _sightCategory = s ? v : null),
      )).toList(),
    );
  }

  Widget _buildServiceCategoryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [ServiceCategory.trainStation, ServiceCategory.carRental, ServiceCategory.bus, ServiceCategory.plane, ServiceCategory.bike, ServiceCategory.other]
          .map((v) => ChoiceChip(
        label: Text(getServiceCategoryLabel(v)),
        selected: _serviceCategory == v,
        onSelected: (s) => setState(() => _serviceCategory = s ? v : null),
      )).toList(),
    );
  }

  Widget _buildTagsRow() {
    final labels = WaypointTypeSuggestion.allowedSubCategoryLabels(_selectedType);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tags', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showTagsSheet(),
              tooltip: 'Add tags',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._subCategoryTags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () => setState(() => _subCategoryTags.remove(tag)),
              deleteIcon: const Icon(Icons.close, size: 16),
            )),
          ],
        ),
      ],
    );
  }

  Future<void> _showTagsSheet() async {
    final allowed = WaypointTypeSuggestion.allowedSubCategoryLabels(_selectedType);
    if (allowed.isEmpty) return;
    final selected = List<String>.from(_subCategoryTags);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Subcategory tags', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Flexible(
                      child: ListView(
                        controller: scrollController,
                        shrinkWrap: true,
                        children: allowed.map((label) {
                          final isSelected = selected.contains(label);
                          return CheckboxListTile(
                            title: Text(label),
                            value: isSelected,
                            onChanged: (v) {
                              if (v == true) {
                                selected.add(label);
                              } else {
                                selected.remove(label);
                              }
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop<List<String>>(List.from(selected)),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    if (result != null && mounted) setState(() => _subCategoryTags = result);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_title, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.all(24),
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
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.all(24),
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
          _buildCategoryRow(),
          const SizedBox(height: 16),
          _buildPhotoSection(),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildRatingRow(),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteController,
            decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder()),
            keyboardType: TextInputType.url,
          ),
          if (_selectedType == WaypointType.accommodation) ...[
            const SizedBox(height: 12),
            _buildAccommodationTypeRow(),
          ],
          if (_selectedType == WaypointType.restaurant) ...[
            const SizedBox(height: 12),
            _buildEatCategoryRow(),
          ],
          if (_selectedType == WaypointType.attraction) ...[
            const SizedBox(height: 12),
            _buildAttractionCategoryRow(),
          ],
          if (_selectedType == WaypointType.viewingPoint) ...[
            const SizedBox(height: 12),
            _buildSightCategoryRow(),
          ],
          if (_selectedType == WaypointType.service) ...[
            const SizedBox(height: 12),
            _buildServiceCategoryRow(),
          ],
          if (WaypointTypeSuggestion.allowedSubCategoryLabels(_selectedType).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTagsRow(),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _estimatedPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (estimation)',
              border: OutlineInputBorder(),
              hintText: 'Optional',
            ),
          ),
          if (_selectedType == WaypointType.restaurant && (_eatCategory == null || _eatCategory == EatCategory.diningRestaurant)) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<MealTime>(
              value: _mealTime,
              decoration: const InputDecoration(labelText: 'Meal time', border: OutlineInputBorder()),
              items: MealTime.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
              onChanged: (v) => setState(() => _mealTime = v),
            ),
          ],
          if (_selectedType == WaypointType.attraction) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityTime>(
              value: _activityTime,
              decoration: const InputDecoration(labelText: 'Activity time', border: OutlineInputBorder()),
              items: ActivityTime.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _activityTime = v),
            ),
          ],
          if (_placeDetails?.reviews.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _buildReviewsSection(),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Text(_isEditMode ? 'Save changes' : 'Add place to the list'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    const types = [
      (WaypointType.accommodation, Icons.hotel, 'Sleep'),
      (WaypointType.restaurant, Icons.restaurant, 'Eat & Drink'),
      (WaypointType.attraction, Icons.local_activity, 'Do & See'),
      (WaypointType.viewingPoint, Icons.visibility, 'See'),
      (WaypointType.service, Icons.directions_bus, 'Move'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = _selectedType == t.$1;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.$2, size: 18, color: selected ? Colors.white : getWaypointColor(t.$1)),
                  const SizedBox(width: 4),
                  Text(t.$3),
                ],
              ),
              selected: selected,
              onSelected: (_) => setState(() {
                _selectedType = t.$1;
                _subCategoryTags = [];
                if (t.$1 != WaypointType.accommodation) _accommodationType = null;
                if (t.$1 != WaypointType.restaurant) _eatCategory = null;
                if (t.$1 != WaypointType.attraction) _attractionCategory = null;
                if (t.$1 != WaypointType.viewingPoint) _sightCategory = null;
                if (t.$1 != WaypointType.service) _serviceCategory = null;
              }),
              selectedColor: getWaypointColor(t.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _showCategoryPicker,
          icon: const Icon(Icons.list, size: 20),
          label: const Text('Change category'),
        ),
      ],
    );
  }
}
