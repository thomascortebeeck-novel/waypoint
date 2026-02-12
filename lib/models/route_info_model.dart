import 'package:flutter/material.dart';

/// Route metadata extracted from Komoot or AllTrails links
class RouteInfo {
  final String source; // "komoot" or "alltrails"
  final String sourceUrl;
  final double? distanceKm;
  final int? elevationM;
  final String? estimatedTime; // e.g., "06:43" or "6h 43m"
  final String? difficulty; // "easy", "moderate", or "hard"
  final String extractionMethod; // "json_ld", "meta_tags", "html_parsing", or "llm_fallback"

  RouteInfo({
    required this.source,
    required this.sourceUrl,
    this.distanceKm,
    this.elevationM,
    this.estimatedTime,
    this.difficulty,
    required this.extractionMethod,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    try {
      return RouteInfo(
        source: (json['source'] as String?) ?? 'unknown',
        sourceUrl: json['sourceUrl'] as String? ?? json['source_url'] as String? ?? '',
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        elevationM: (json['elevation_m'] as num?)?.toInt(),
        estimatedTime: json['estimated_time'] as String?,
        difficulty: json['difficulty'] as String?,
        extractionMethod: json['extraction_method'] as String? ?? 'html_parsing',
      );
    } catch (e) {
      // Fallback for malformed data
      return RouteInfo(
        source: 'unknown',
        sourceUrl: '',
        extractionMethod: 'html_parsing',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'source_url': sourceUrl,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (elevationM != null) 'elevation_m': elevationM,
        if (estimatedTime != null) 'estimated_time': estimatedTime,
        if (difficulty != null) 'difficulty': difficulty,
        'extraction_method': extractionMethod,
      };

  RouteInfo copyWith({
    String? source,
    String? sourceUrl,
    double? distanceKm,
    int? elevationM,
    String? estimatedTime,
    String? difficulty,
    String? extractionMethod,
  }) =>
      RouteInfo(
        source: source ?? this.source,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        distanceKm: distanceKm ?? this.distanceKm,
        elevationM: elevationM ?? this.elevationM,
        estimatedTime: estimatedTime ?? this.estimatedTime,
        difficulty: difficulty ?? this.difficulty,
        extractionMethod: extractionMethod ?? this.extractionMethod,
      );

  /// Get difficulty color for UI
  Color get difficultyColor {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get display name for source
  String get sourceDisplayName {
    switch (source.toLowerCase()) {
      case 'komoot':
        return 'Komoot';
      case 'alltrails':
        return 'AllTrails';
      default:
        return source;
    }
  }
}

