import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/services/route_info_calculator_service.dart';
import 'package:waypoint/services/gpx_parser_service.dart';
import 'package:waypoint/services/gpx_waypoint_snapper.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/theme.dart';

// Import the helper function
bool isAutoCalculatedActivity(ActivityCategory? activityCategory) {
  if (activityCategory == null) return false;
  
  switch (activityCategory) {
    case ActivityCategory.roadTripping:
    case ActivityCategory.cityTrips:
    case ActivityCategory.tours:
      return true;
    case ActivityCategory.hiking:
    case ActivityCategory.cycling:
    case ActivityCategory.skis:
    case ActivityCategory.climbing:
      return false;
  }
}

/// Check if activity type supports GPX route import
bool isGpxSupportedActivity(ActivityCategory? category) {
  if (category == null) return false;
  return category == ActivityCategory.hiking ||
         category == ActivityCategory.skis ||
         category == ActivityCategory.cycling ||
         category == ActivityCategory.climbing;
}

/// Route Info section that displays differently based on activity type
/// - Auto-calculated: Shows read-only stats from waypoints (roadTripping, cityTrips, tours)
/// - Manual entry: Shows editable form fields (hiking, cycling, skis, climbing)
class RouteInfoSection extends StatefulWidget {
  final ActivityCategory? activityCategory;
  final DayRoute? route;
  final RouteInfo? routeInfo;
  final ValueChanged<RouteInfo?> onRouteInfoChanged;
  final TextEditingController komootLinkController;
  final TextEditingController allTrailsLinkController;
  final GpxRoute? gpxRoute; // Imported GPX route
  final ValueChanged<GpxRoute?> onGpxRouteChanged; // Callback when GPX route is uploaded/removed

  const RouteInfoSection({
    super.key,
    required this.activityCategory,
    this.route,
    this.routeInfo,
    required this.onRouteInfoChanged,
    required this.komootLinkController,
    required this.allTrailsLinkController,
    this.gpxRoute,
    required this.onGpxRouteChanged,
  });

  @override
  State<RouteInfoSection> createState() => _RouteInfoSectionState();
}

class _RouteInfoSectionState extends State<RouteInfoSection> {
  late TextEditingController _distanceController;
  late TextEditingController _elevationController;
  late TextEditingController _durationController;
  String? _selectedDifficulty;
  DistanceUnit _distanceUnit = DistanceUnit.km;
  ElevationUnit _elevationUnit = ElevationUnit.meters;
  bool _isLoadingGpx = false;

  final _calculatorService = RouteInfoCalculatorService();
  final _gpxParserService = GpxParserService();

  @override
  void initState() {
    super.initState();
    // Initialize units from routeInfo or default to metric
    _distanceUnit = widget.routeInfo?.distanceUnit ?? DistanceUnit.km;
    _elevationUnit = widget.routeInfo?.elevationUnit ?? ElevationUnit.meters;
    
    // If GPX route exists but routeInfo doesn't have data, populate from GPX
    if (widget.gpxRoute != null && (widget.routeInfo == null || 
        (widget.routeInfo!.distanceKm == null && widget.routeInfo!.estimatedTime == null))) {
      // Calculate duration from activity type if GPX doesn't have it
      String? estimatedTime;
      if (widget.gpxRoute!.estimatedDuration != null) {
        estimatedTime = _formatDuration(widget.gpxRoute!.estimatedDuration!);
      } else if (widget.activityCategory != null) {
        final estimatedDuration = _estimateDurationFromActivity(widget.gpxRoute!, widget.activityCategory!);
        estimatedTime = _formatDuration(estimatedDuration);
      }
      
      // Update route info with GPX data
      final updatedRouteInfo = RouteInfo(
        distanceKm: widget.gpxRoute!.totalDistanceKm,
        elevationM: widget.gpxRoute!.totalElevationGainM?.round(),
        estimatedTime: estimatedTime,
        difficulty: widget.routeInfo?.difficulty,
        source: RouteInfoSource.manual,
        distanceUnit: _distanceUnit,
        elevationUnit: _elevationUnit,
      );
      // Update form fields from GPX data
      _distanceController = TextEditingController(
        text: _formatDistanceForDisplay(widget.gpxRoute!.totalDistanceKm),
      );
      _elevationController = TextEditingController(
        text: _formatElevationForDisplay(widget.gpxRoute!.totalElevationGainM?.round()),
      );
      _durationController = TextEditingController(
        text: estimatedTime ?? '',
      );
      _selectedDifficulty = widget.routeInfo?.difficulty;
      
      // Save to Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRouteInfoChanged(updatedRouteInfo);
      });
    } else {
      // Initialize controllers with converted values based on selected units
      _distanceController = TextEditingController(
        text: _formatDistanceForDisplay(widget.routeInfo?.distanceKm),
      );
      _elevationController = TextEditingController(
        text: _formatElevationForDisplay(widget.routeInfo?.elevationM),
      );
      _durationController = TextEditingController(
        text: widget.routeInfo?.estimatedTime ?? '',
      );
      _selectedDifficulty = widget.routeInfo?.difficulty;
    }
  }

  @override
  void didUpdateWidget(RouteInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if routeInfo changed externally
    if (widget.routeInfo != oldWidget.routeInfo) {
      _distanceUnit = widget.routeInfo?.distanceUnit ?? DistanceUnit.km;
      _elevationUnit = widget.routeInfo?.elevationUnit ?? ElevationUnit.meters;
      _distanceController.text = _formatDistanceForDisplay(widget.routeInfo?.distanceKm);
      _elevationController.text = _formatElevationForDisplay(widget.routeInfo?.elevationM);
      _durationController.text = widget.routeInfo?.estimatedTime ?? '';
      _selectedDifficulty = widget.routeInfo?.difficulty;
    }
    // If GPX route was just added and routeInfo doesn't have GPX data, populate it
    if (widget.gpxRoute != null && oldWidget.gpxRoute == null) {
      // GPX route was just added - populate form fields and save
      String? estimatedTime;
      if (widget.gpxRoute!.estimatedDuration != null) {
        estimatedTime = _formatDuration(widget.gpxRoute!.estimatedDuration!);
      } else if (widget.activityCategory != null) {
        final estimatedDuration = _estimateDurationFromActivity(widget.gpxRoute!, widget.activityCategory!);
        estimatedTime = _formatDuration(estimatedDuration);
      }
      
      final updatedRouteInfo = RouteInfo(
        distanceKm: widget.gpxRoute!.totalDistanceKm,
        elevationM: widget.gpxRoute!.totalElevationGainM?.round(),
        estimatedTime: estimatedTime,
        difficulty: widget.routeInfo?.difficulty,
        source: RouteInfoSource.manual,
        distanceUnit: _distanceUnit,
        elevationUnit: _elevationUnit,
      );
      
      _distanceController.text = _formatDistanceForDisplay(widget.gpxRoute!.totalDistanceKm);
      if (widget.gpxRoute!.totalElevationGainM != null) {
        _elevationController.text = _formatElevationForDisplay(widget.gpxRoute!.totalElevationGainM!.round());
      }
      if (estimatedTime != null) {
        _durationController.text = estimatedTime;
      }
      
      widget.onRouteInfoChanged(updatedRouteInfo);
    }
    // If GPX route was just removed, clear form fields if they were GPX-derived
    if (widget.gpxRoute == null && oldWidget.gpxRoute != null) {
      // GPX route was removed - clear form fields if routeInfo is also null/empty
      if (widget.routeInfo == null || 
          (widget.routeInfo!.distanceKm == null && 
           widget.routeInfo!.elevationM == null && 
           widget.routeInfo!.estimatedTime == null)) {
        _distanceController.clear();
        _elevationController.clear();
        _durationController.clear();
      }
    }
    // Auto-calculate if activity type is auto and route exists
    if (isAutoCalculatedActivity(widget.activityCategory) && widget.route != null) {
      final calculated = _calculatorService.calculateFromRoute(widget.route);
      if (calculated != null && calculated != widget.routeInfo) {
        widget.onRouteInfoChanged(calculated);
      }
    }
  }

  // Convert distance from km to display unit
  String _formatDistanceForDisplay(double? distanceKm) {
    if (distanceKm == null) return '';
    if (_distanceUnit == DistanceUnit.miles) {
      return (distanceKm * 0.621371).toStringAsFixed(1);
    }
    return distanceKm.toStringAsFixed(1);
  }

  // Convert elevation from meters to display unit
  String _formatElevationForDisplay(int? elevationM) {
    if (elevationM == null) return '';
    if (_elevationUnit == ElevationUnit.feet) {
      return (elevationM * 3.28084).round().toString();
    }
    return elevationM.toString();
  }

  // Convert distance from display unit to km
  double? _parseDistanceFromDisplay(String value) {
    if (value.trim().isEmpty) return null;
    final num = double.tryParse(value.replaceAll(',', '.'));
    if (num == null) return null;
    if (_distanceUnit == DistanceUnit.miles) {
      return num * 1.60934; // Convert miles to km
    }
    return num; // Already in km
  }

  // Convert elevation from display unit to meters
  int? _parseElevationFromDisplay(String value) {
    if (value.trim().isEmpty) return null;
    final num = double.tryParse(value.replaceAll(',', '.'));
    if (num == null) return null;
    if (_elevationUnit == ElevationUnit.feet) {
      return (num * 0.3048).round(); // Convert feet to meters
    }
    return num.round(); // Already in meters
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _elevationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool get _isAutoCalculated => isAutoCalculatedActivity(widget.activityCategory);

  @override
  Widget build(BuildContext context) {
    // Auto-calculate route info for auto-calculated activity types
    if (_isAutoCalculated && widget.route != null) {
      final calculated = _calculatorService.calculateFromRoute(widget.route);
      if (calculated != null) {
        return _buildAutoCalculatedCard(calculated);
      }
    }

    // Manual entry for outdoor activities
    if (!_isAutoCalculated) {
      return _buildManualEntryForm();
    }

    // No route data available
    return const SizedBox.shrink();
  }

  Widget _buildAutoCalculatedCard(RouteInfo routeInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: context.colors.secondary),
              const SizedBox(width: 8),
              Text(
                'Route Info',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Auto-calculated',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (routeInfo.distanceKm != null)
                _StatItem(
                  icon: Icons.straighten,
                  label: '${routeInfo.distanceKm!.toStringAsFixed(1)} km',
                ),
              if (routeInfo.estimatedTime != null)
                _StatItem(
                  icon: Icons.access_time,
                  label: routeInfo.estimatedTime!,
                ),
              if (routeInfo.numStops != null)
                _StatItem(
                  icon: Icons.location_on,
                  label: '${routeInfo.numStops} ${routeInfo.numStops == 1 ? 'stop' : 'stops'}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Info',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter route details from Komoot, AllTrails, or your planned route',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // Distance field with unit selector
          _buildDistanceField(),
          const SizedBox(height: 12),
          // Elevation field with unit selector
          _buildElevationField(),
          const SizedBox(height: 12),
          // Duration field
          _buildFormField(
            label: 'Estimated duration',
            controller: _durationController,
            icon: Icons.access_time,
            hint: 'e.g., 6h 30m',
            onChanged: _updateRouteInfo,
          ),
          const SizedBox(height: 12),
          // Difficulty dropdown
          _buildDifficultyDropdown(),
          const SizedBox(height: 12),
          // Komoot Link field
          _buildFormField(
            label: 'Komoot Link',
            controller: widget.komootLinkController,
            icon: Icons.link,
            hint: 'https://www.komoot.com/...',
            onChanged: () {}, // Links are saved separately
          ),
          const SizedBox(height: 12),
          // AllTrails Link field
          _buildFormField(
            label: 'AllTrails Link',
            controller: widget.allTrailsLinkController,
            icon: Icons.link,
            hint: 'https://www.alltrails.com/...',
            onChanged: () {}, // Links are saved separately
          ),
          const SizedBox(height: 16),
          // GPX Route Import section
          _buildGpxImportSection(),
        ],
      ),
    );
  }

  Widget _buildGpxImportSection() {
    final hasGpxRoute = widget.gpxRoute != null;
    final supportsGpx = isGpxSupportedActivity(widget.activityCategory);
    
    // Only show GPX section for supported activities
    if (!supportsGpx) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route, size: 16, color: context.colors.secondary),
            const SizedBox(width: 6),
            const Text(
              'GPX Route',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasGpxRoute) ...[
          // Show GPX route info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'GPX Route Imported',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // Only show route name, stats are in the form fields above
                if (widget.gpxRoute!.name != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Name: ${widget.gpxRoute!.name}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Remove route button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingGpx ? null : _removeGpxRoute,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove GPX Route'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else ...[
          // Import GPX button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoadingGpx ? null : _importGpxFile,
              icon: _isLoadingGpx
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(_isLoadingGpx ? 'Importing...' : 'Import GPX Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _importGpxFile() async {
    try {
      Log.i('gpx_upload', '📤 Starting GPX file import...');
      setState(() => _isLoadingGpx = true);

      // Pick GPX file
      Log.i('gpx_upload', '📂 Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );

      if (result == null || result.files.isEmpty) {
        Log.i('gpx_upload', '❌ No file selected');
        setState(() => _isLoadingGpx = false);
        return;
      }
      
      final selectedFile = result.files.single;
      Log.i('gpx_upload', '📁 File selected: ${selectedFile.name} (${selectedFile.size} bytes)');
      Log.i('gpx_upload', '🌐 Platform: ${kIsWeb ? "Web" : "Mobile/Desktop"}');

      // Handle file reading for both web and mobile
      GpxRoute gpxRoute;
      if (kIsWeb) {
        Log.i('gpx_upload', '🌐 Web platform: reading file bytes...');
        // On web, use bytes directly
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          Log.e('gpx_upload', '❌ Failed to read file bytes');
          setState(() => _isLoadingGpx = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to read file')),
            );
          }
          return;
        }
        Log.i('gpx_upload', '✅ Read ${bytes.length} bytes, starting parse...');
        gpxRoute = await _gpxParserService.parseGpxBytes(
          bytes,
          result.files.single.name,
        );
        Log.i('gpx_upload', '✅ GPX parsing successful!');
      } else {
        Log.i('gpx_upload', '📱 Mobile/Desktop platform: reading file...');
        // On mobile/desktop, use File API
        final file = File(result.files.single.path!);
        if (!file.existsSync()) {
          Log.e('gpx_upload', '❌ File not found: ${file.path}');
          setState(() => _isLoadingGpx = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File not found')),
            );
          }
          return;
        }
        Log.i('gpx_upload', '✅ File exists, starting parse...');
        gpxRoute = await _gpxParserService.parseGpxFile(file);
        Log.i('gpx_upload', '✅ GPX parsing successful!');
      }

      // Update route info with GPX data (always update for GPX routes)
      // Calculate duration from activity type if GPX doesn't have it
      String? estimatedTime;
      if (gpxRoute.estimatedDuration != null) {
        estimatedTime = _formatDuration(gpxRoute.estimatedDuration!);
      } else if (widget.activityCategory != null) {
        final estimatedDuration = _estimateDurationFromActivity(gpxRoute, widget.activityCategory!);
        estimatedTime = _formatDuration(estimatedDuration);
      }
      
      final updatedRouteInfo = RouteInfo(
        distanceKm: gpxRoute.totalDistanceKm,
        elevationM: gpxRoute.totalElevationGainM?.round(),
        estimatedTime: estimatedTime,
        difficulty: widget.routeInfo?.difficulty,
        source: RouteInfoSource.manual,
        distanceUnit: _distanceUnit,
        elevationUnit: _elevationUnit,
      );
      widget.onRouteInfoChanged(updatedRouteInfo);
      
      // Update form fields to reflect GPX data
      _distanceController.text = _formatDistanceForDisplay(gpxRoute.totalDistanceKm);
      if (gpxRoute.totalElevationGainM != null) {
        _elevationController.text = _formatElevationForDisplay(gpxRoute.totalElevationGainM!.round());
      }
      if (estimatedTime != null) {
        _durationController.text = estimatedTime;
      }

      // Notify parent of GPX route
      widget.onGpxRouteChanged(gpxRoute);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'GPX route imported successfully (${gpxRoute.totalDistanceKm.toStringAsFixed(1)} km)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      Log.e('gpx_upload', '❌ Error importing GPX file', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing GPX: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGpx = false);
      }
    }
  }

  void _removeGpxRoute() {
    // Clear form fields (distance, elevation, duration)
    _distanceController.clear();
    _elevationController.clear();
    _durationController.clear();
    
    // Clear route info from database (distance, elevation, duration)
    // Keep difficulty and units, but clear GPX-derived data
    final clearedRouteInfo = RouteInfo(
      distanceKm: null,
      elevationM: null,
      estimatedTime: null,
      difficulty: widget.routeInfo?.difficulty, // Keep difficulty if set
      source: RouteInfoSource.manual,
      distanceUnit: _distanceUnit,
      elevationUnit: _elevationUnit,
    );
    widget.onRouteInfoChanged(clearedRouteInfo);
    
    // Notify parent that GPX route is removed (this will clear route geometry)
    widget.onGpxRouteChanged(null);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPX route removed')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Estimate duration from activity type and GPX distance
  Duration _estimateDurationFromActivity(GpxRoute gpxRoute, ActivityCategory activityCategory) {
    final snapper = GpxWaypointSnapper();
    return snapper.estimateTravelTime(
      gpxRoute.totalDistanceKm,
      activityCategory,
      gpxRoute.totalElevationGainM,
    );
  }

  Widget _buildDistanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.straighten, size: 16, color: context.colors.secondary),
            const SizedBox(width: 6),
            const Text(
              'Distance',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            // Unit selector
            _buildUnitSelector<DistanceUnit>(
              value: _distanceUnit,
              options: const [DistanceUnit.km, DistanceUnit.miles],
              labels: const ['km', 'miles'],
              onChanged: (unit) {
                setState(() {
                  final oldUnit = _distanceUnit;
                  _distanceUnit = unit;
                  // Convert existing value if present
                  final currentValue = _distanceController.text;
                  if (currentValue.isNotEmpty) {
                    final num = double.tryParse(currentValue.replaceAll(',', '.'));
                    if (num != null) {
                      if (oldUnit == DistanceUnit.miles && unit == DistanceUnit.km) {
                        // Converting from miles to km
                        _distanceController.text = (num * 1.60934).toStringAsFixed(1);
                      } else if (oldUnit == DistanceUnit.km && unit == DistanceUnit.miles) {
                        // Converting from km to miles
                        _distanceController.text = (num * 0.621371).toStringAsFixed(1);
                      }
                    }
                  }
                });
                _updateRouteInfo();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _distanceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter distance',
            suffixText: _distanceUnit == DistanceUnit.km ? 'km' : 'miles',
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
          onChanged: (_) => _updateRouteInfo(),
        ),
      ],
    );
  }

  Widget _buildElevationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.terrain, size: 16, color: context.colors.secondary),
            const SizedBox(width: 6),
            const Text(
              'Elevation gain',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            // Unit selector
            _buildUnitSelector<ElevationUnit>(
              value: _elevationUnit,
              options: const [ElevationUnit.meters, ElevationUnit.feet],
              labels: const ['m', 'ft'],
              onChanged: (unit) {
                setState(() {
                  final oldUnit = _elevationUnit;
                  _elevationUnit = unit;
                  // Convert existing value if present
                  final currentValue = _elevationController.text;
                  if (currentValue.isNotEmpty) {
                    final num = double.tryParse(currentValue.replaceAll(',', '.'));
                    if (num != null) {
                      if (oldUnit == ElevationUnit.feet && unit == ElevationUnit.meters) {
                        // Converting from feet to meters
                        _elevationController.text = (num * 0.3048).round().toString();
                      } else if (oldUnit == ElevationUnit.meters && unit == ElevationUnit.feet) {
                        // Converting from meters to feet
                        _elevationController.text = (num * 3.28084).round().toString();
                      }
                    }
                  }
                });
                _updateRouteInfo();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _elevationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter elevation',
            suffixText: _elevationUnit == ElevationUnit.meters ? 'm' : 'ft',
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
          onChanged: (_) => _updateRouteInfo(),
        ),
      ],
    );
  }

  Widget _buildUnitSelector<T>({
    required T value,
    required List<T> options,
    required List<String> labels,
    required Function(T) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = option == value;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? context.colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: context.colors.secondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
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
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }

  Widget _buildDifficultyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, size: 16, color: context.colors.secondary),
            const SizedBox(width: 6),
            const Text(
              'Difficulty',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedDifficulty,
          decoration: InputDecoration(
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
          items: const [
            DropdownMenuItem(value: 'easy', child: Text('Easy')),
            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
            DropdownMenuItem(value: 'hard', child: Text('Hard')),
          ],
          onChanged: (value) {
            setState(() => _selectedDifficulty = value);
            _updateRouteInfo();
          },
        ),
      ],
    );
  }

  void _updateRouteInfo() {
    final distanceKm = _parseDistanceFromDisplay(_distanceController.text);
    final elevationM = _parseElevationFromDisplay(_elevationController.text);
    final estimatedTime = _durationController.text.trim().isEmpty ? null : _durationController.text.trim();

    final routeInfo = RouteInfo(
      distanceKm: distanceKm,
      elevationM: elevationM,
      estimatedTime: estimatedTime,
      difficulty: _selectedDifficulty,
      source: RouteInfoSource.manual,
      distanceUnit: _distanceUnit,
      elevationUnit: _elevationUnit,
    );

    widget.onRouteInfoChanged(routeInfo);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.colors.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textStyles.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

