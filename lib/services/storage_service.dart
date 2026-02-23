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
      Log.i('storage', 'Uploading image to: $path (${bytes.length} bytes)');
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {'uploaded': DateTime.now().toIso8601String()},
      );

      final uploadTask = ref.putData(bytes, metadata);
      
      // Log upload progress for debugging
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Log.i('storage', 'Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      
      Log.i('storage', 'Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      Log.e('storage', 'Upload failed for path: $path - Error: $e', e, stack);
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

  /// Generates a storage path for plan media items (images/videos)
  String planMediaPath(String planId, int index, String extension) =>
      'plans/$planId/media/$index.$extension';

  /// Generates a storage path for day media items (images/videos)
  String dayMediaPath(String planId, String versionId, int dayNumber, int index, String extension) =>
      'plans/$planId/versions/$versionId/days/$dayNumber/media/$index.$extension';

  /// Uploads a video file to Firebase Storage and returns the download URL
  /// 
  /// [path] - Storage path (e.g., 'plans/plan_id/media/0.mp4')
  /// [bytes] - Video data as bytes
  /// [contentType] - MIME type (e.g., 'video/mp4')
  Future<String> uploadVideo({
    required String path,
    required Uint8List bytes,
    String contentType = 'video/mp4',
  }) async {
    try {
      Log.i('storage', 'Uploading video to: $path (${bytes.length} bytes)');
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {'uploaded': DateTime.now().toIso8601String()},
      );

      final uploadTask = ref.putData(bytes, metadata);
      
      // Log upload progress for debugging
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Log.i('storage', 'Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      
      Log.i('storage', 'Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      Log.e('storage', 'Upload failed for path: $path - Error: $e', e, stack);
      rethrow;
    }
  }

  /// Picks a video file from the user's device (cross-platform)
  /// Returns video bytes and file extension, or null if canceled
  /// NOTE: Video aspect ratio validation should be done separately using video_player package
  Future<VideoPickResult?> pickVideo() async {
    try {
      Log.i('storage', 'Opening video picker...');
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) {
        Log.i('storage', 'Video picker canceled');
        return null;
      }

      final bytes = await video.readAsBytes();
      
      // Extract extension from filename or default to mp4
      final extension = video.name.split('.').last.toLowerCase();
      final validExtension = ['mp4', 'mov', 'avi'].contains(extension) 
          ? extension 
          : 'mp4';
      
      Log.i('storage', 'Video picked: ${video.name} (${bytes.length} bytes)');

      return VideoPickResult(
        bytes: bytes,
        extension: validExtension,
        name: video.name,
      );
    } catch (e, stack) {
      Log.e('storage', 'Failed to pick video', e, stack);
      rethrow;
    }
  }

  /// Upload a review photo
  Future<String> uploadReviewPhoto({
    required String reviewId,
    required String userId,
    required Uint8List photoBytes,
    required int index,
  }) async {
    final path = 'reviews/$userId/$reviewId/photo_$index.jpg';
    return await uploadImage(
      path: path,
      bytes: photoBytes,
      contentType: 'image/jpeg',
    );
  }
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

/// Result of picking a video
class VideoPickResult {
  final Uint8List bytes;
  final String extension;
  final String name;

  VideoPickResult({
    required this.bytes,
    required this.extension,
    required this.name,
  });
}
