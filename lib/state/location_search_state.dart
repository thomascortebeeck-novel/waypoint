import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/google_places_service.dart';

/// State management for location search with cooldown, debouncing, and cancellation
class LocationSearchState extends ChangeNotifier {
  static const Duration searchCooldown = Duration(milliseconds: 1500);
  static const Duration debounceDelay = Duration(milliseconds: 1000);
  static const int minQueryLength = 4;
  
  ll.LatLng? selectedLocation;
  String selectedLocationName = '';
  List<PlacePrediction> suggestions = [];
  
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  set isSearching(bool value) {
    if (_isSearching != value) {
      _isSearching = value;
      notifyListeners();
    }
  }
  
  String lastQuery = '';
  DateTime? lastSearchTime;
  Timer? _debounceTimer;
  Future<List<PlacePrediction>>? searchFuture;
  final FocusNode focusNode;
  
  LocationSearchState({
    this.selectedLocation,
    this.selectedLocationName = '',
    this.suggestions = const [],
    this.lastQuery = '',
    required this.focusNode,
  });
  
  factory LocationSearchState.initial() => LocationSearchState(
    selectedLocation: null,
    selectedLocationName: '',
    suggestions: [],
    lastQuery: '',
    focusNode: FocusNode(),
  );
  
  bool get canSearch {
    if (lastSearchTime == null) return true;
    return DateTime.now().difference(lastSearchTime!) > searchCooldown;
  }
  
  void cancelSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    searchFuture = null;
  }
  
  void setDebounceTimer(Timer timer) {
    _debounceTimer?.cancel();
    _debounceTimer = timer;
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    focusNode.dispose();
    super.dispose();
  }
}



