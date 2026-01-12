import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/utils/logger.dart';

/// Service for uploading and managing images in Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Uploads an image file to Firebase Storage and returns the download URL
  /// 
  /// [path] - Storage path (e.g., 'plans/cover_images/plan_id.jpg')
  /// [bytes] - Image data as bytes
  /// [contentType] - MIME type (e.g., 'image/jpeg')
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      Log.i('storage', 'Uploading image to: $path');
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {'uploaded': DateTime.now().toIso8601String()},
      );

      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();
      
      Log.i('storage', 'Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      Log.e('storage', 'Upload failed for path: $path', e, stack);
      rethrow;
    }
  }

  /// Deletes an image from Firebase Storage
  Future<void> deleteImage(String path) async {
    try {
      Log.i('storage', 'Deleting image: $path');
      await _storage.ref().child(path).delete();
      Log.i('storage', 'Delete successful');
    } catch (e, stack) {
      Log.e('storage', 'Delete failed for path: $path', e, stack);
      rethrow;
    }
  }

  /// Picks an image file from the user's device (cross-platform)
  /// Returns image bytes and file extension, or null if canceled
  Future<ImagePickResult?> pickImage() async {
    try {
      Log.i('storage', 'Opening image picker...');
      
      // Use ImagePicker for better web compatibility
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) {
        Log.i('storage', 'Image picker canceled');
        return null;
      }

      final bytes = await image.readAsBytes();
      
      // Extract extension from filename or default to jpg
      final extension = image.name.split('.').last.toLowerCase();
      final validExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension) 
          ? extension 
          : 'jpg';
      
      Log.i('storage', 'Image picked: ${image.name} (${bytes.length} bytes)');

      return ImagePickResult(
        bytes: bytes,
        extension: validExtension,
        name: image.name,
      );
    } catch (e, stack) {
      Log.e('storage', 'Failed to pick image', e, stack);
      rethrow;
    }
  }

  /// Generates a storage path for plan cover images
  String coverImagePath(String planId, String extension) =>
      'plans/$planId/cover.$extension';

  /// Generates a storage path for day images
  String dayImagePath(String planId, int dayNumber, String extension) =>
      'plans/$planId/days/day_$dayNumber.$extension';
}

/// Result of picking an image
class ImagePickResult {
  final Uint8List bytes;
  final String extension;
  final String name;

  ImagePickResult({
    required this.bytes,
    required this.extension,
    required this.name,
  });
}
