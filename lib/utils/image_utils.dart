import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Utility functions for image/video aspect ratio validation
/// STRICT validation: Only 16:9 or 9:16 allowed

/// Valid aspect ratios
enum ValidAspectRatio {
  ratio16_9,  // 16:9 (landscape)
  ratio9_16,  // 9:16 (portrait/story)
}

/// Calculate aspect ratio from width and height
double _calculateAspectRatio(int width, int height) {
  if (height == 0) return 0;
  return width / height;
}

/// Check if aspect ratio matches 16:9 (within tolerance)
bool _is16to9(double aspectRatio, {double tolerance = 0.1}) {
  const targetRatio = 16 / 9; // ~1.778
  return (aspectRatio - targetRatio).abs() <= tolerance;
}

/// Check if aspect ratio matches 9:16 (within tolerance)
bool _is9to16(double aspectRatio, {double tolerance = 0.1}) {
  const targetRatio = 9 / 16; // ~0.5625
  return (aspectRatio - targetRatio).abs() <= tolerance;
}

/// Validate image aspect ratio
/// Returns the valid aspect ratio if valid, null if invalid
/// Throws exception if file cannot be read
Future<ValidAspectRatio?> validateImageAspectRatio(File imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Could not decode image file');
    }
    
    final aspectRatio = _calculateAspectRatio(image.width, image.height);
    
    if (_is16to9(aspectRatio)) {
      return ValidAspectRatio.ratio16_9;
    } else if (_is9to16(aspectRatio)) {
      return ValidAspectRatio.ratio9_16;
    } else {
      return null; // Invalid aspect ratio
    }
  } catch (e) {
    debugPrint('Error validating image aspect ratio: $e');
    rethrow;
  }
}

/// Validate image aspect ratio from bytes
/// Returns the valid aspect ratio if valid, null if invalid
ValidAspectRatio? validateImageAspectRatioFromBytes(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Could not decode image bytes');
    }
    
    final aspectRatio = _calculateAspectRatio(image.width, image.height);
    
    if (_is16to9(aspectRatio)) {
      return ValidAspectRatio.ratio16_9;
    } else if (_is9to16(aspectRatio)) {
      return ValidAspectRatio.ratio9_16;
    } else {
      return null; // Invalid aspect ratio
    }
  } catch (e) {
    debugPrint('Error validating image aspect ratio from bytes: $e');
    rethrow;
  }
}

/// Get aspect ratio string from enum
String aspectRatioToString(ValidAspectRatio ratio) {
  switch (ratio) {
    case ValidAspectRatio.ratio16_9:
      return '16:9';
    case ValidAspectRatio.ratio9_16:
      return '9:16';
  }
}

/// Validate video aspect ratio (requires video metadata)
/// For now, this is a placeholder - video aspect ratio validation
/// should be done using video_player or similar package
/// Returns the valid aspect ratio if valid, null if invalid
Future<ValidAspectRatio?> validateVideoAspectRatio(File videoFile) async {
  // TODO: Implement video aspect ratio validation
  // This requires using video_player or similar package to get video dimensions
  // For now, return null to indicate validation not implemented
  // The actual validation should be done in the upload service
  throw UnimplementedError('Video aspect ratio validation not yet implemented. Use video_player package to get video dimensions.');
}

/// Get error message for invalid aspect ratio
String getInvalidAspectRatioMessage() {
  return 'Image/video must be 16:9 (landscape) or 9:16 (portrait/story) aspect ratio. Please crop or resize your media before uploading.';
}

