import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:waypoint/services/storage_service.dart';

/// URLs for the different image sizes of an itinerary cover
class ItineraryImages {
  final String original;
  final String large;
  final String medium;
  final String thumbnail;

  ItineraryImages({required this.original, required this.large, required this.medium, required this.thumbnail});
}

/// Handles resizing and uploading itinerary cover images to Firebase Storage
class ItineraryImageService {
  final StorageService _storage = StorageService();
  final FirebaseStorage _fs = FirebaseStorage.instance;

  /// Upload a picked/cropped image as itinerary cover and generate size variants
  /// Storage structure: trips/{userId}/{itineraryId}/cover_*.jpg
  Future<ItineraryImages> uploadItineraryImages({
    required String userId,
    required String itineraryId,
    required Uint8List bytes,
  }) async {
    try {
      // Decode once
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Invalid image data');

      // Ensure landscape 4:3 aspect for cards by center-cropping before resizing
      img.Image _ensureAspect(img.Image src, double aspect) {
        final current = src.width / src.height;
        if ((current - aspect).abs() < 0.02) return src; // close enough
        if (current > aspect) {
          // Too wide: crop width
          final targetW = (src.height * aspect).round();
          final x = ((src.width - targetW) / 2).round();
          return img.copyCrop(src, x: x, y: 0, width: targetW, height: src.height);
        } else {
          // Too tall: crop height
          final targetH = (src.width / aspect).round();
          final y = ((src.height - targetH) / 2).round();
          return img.copyCrop(src, x: 0, y: y, width: src.width, height: targetH);
        }
      }

      final base = _ensureAspect(decoded, 4 / 3);
      final originalJpg = Uint8List.fromList(img.encodeJpg(base, quality: 90));
      final large = img.copyResize(base, width: 1024, interpolation: img.Interpolation.linear);
      final medium = img.copyResize(base, width: 512, interpolation: img.Interpolation.linear);
      final thumb = img.copyResize(base, width: 256, interpolation: img.Interpolation.average);

      final largeJpg = Uint8List.fromList(img.encodeJpg(large, quality: 85));
      final mediumJpg = Uint8List.fromList(img.encodeJpg(medium, quality: 85));
      final thumbJpg = Uint8List.fromList(img.encodeJpg(thumb, quality: 80));

      final basePath = 'trips/$userId/$itineraryId';
      final originalUrl = await _storage.uploadImage(path: '$basePath/cover_original.jpg', bytes: originalJpg, contentType: 'image/jpeg');
      final largeUrl = await _storage.uploadImage(path: '$basePath/cover_1024x768.jpg', bytes: largeJpg, contentType: 'image/jpeg');
      final mediumUrl = await _storage.uploadImage(path: '$basePath/cover_512x384.jpg', bytes: mediumJpg, contentType: 'image/jpeg');
      final thumbUrl = await _storage.uploadImage(path: '$basePath/cover_256x192.jpg', bytes: thumbJpg, contentType: 'image/jpeg');

      return ItineraryImages(original: originalUrl, large: largeUrl, medium: mediumUrl, thumbnail: thumbUrl);
    } catch (e, stack) {
      debugPrint('Failed to upload itinerary images: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// Delete all cover images for an itinerary
  Future<void> deleteItineraryImages({required String userId, required String itineraryId}) async {
    try {
      final ref = _fs.ref('trips/$userId/$itineraryId');
      final list = await ref.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('Error deleting itinerary images: $e');
    }
  }
}
