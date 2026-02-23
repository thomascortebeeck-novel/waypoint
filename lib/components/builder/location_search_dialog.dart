import 'dart:async';
import 'package:flutter/material.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/utils/logger.dart';

/// Dialog for searching and selecting locations using Google Places
class LocationSearchDialog extends StatefulWidget {
  const LocationSearchDialog({super.key});

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final GooglePlacesService _placesService = GooglePlacesService();
  Timer? _debounceTimer;
  
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    if (query.trim().length < 3) {
      setState(() {
        _predictions = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _placesService.searchPlaces(query: query);
      if (mounted) {
        setState(() {
          _predictions = results;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      Log.e('location_search', 'Search failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to search locations. Please try again.';
        });
      }
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await _placesService.getPlaceDetails(prediction.placeId);
      if (details == null || !mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get location details. Please try again.';
        });
        return;
      }

      // Extract short name and full address
      // Parse the text to get short name (first part before comma) and full address
      final textParts = prediction.text.split(', ');
      final shortName = textParts.first;
      final fullAddress = details.address ?? details.name ?? prediction.text;
      final latitude = details.location.latitude;
      final longitude = details.location.longitude;

      final locationInfo = LocationInfo(
        shortName: shortName,
        fullAddress: fullAddress,
        latitude: latitude,
        longitude: longitude,
        placeId: prediction.placeId,
      );

      if (mounted) {
        Navigator.of(context).pop(locationInfo);
      }
    } catch (e) {
      Log.e('location_search', 'Failed to get place details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get location details. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search for a location...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_searchController.text.trim().length < 3) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Type at least 3 characters to search',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No locations found',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return ListTile(
          leading: const Icon(Icons.place, color: Color(0xFF428A13)),
          title: Text(
            prediction.text.split(', ').first,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            prediction.text.contains(', ') ? prediction.text.split(', ').skip(1).join(', ') : '',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectPlace(prediction),
        );
      },
    );
  }
}

