import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/services/itinerary_image_service.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/theme.dart';

class ImageUploadDialog extends StatefulWidget {
  const ImageUploadDialog({super.key, required this.userId, required this.tripId});

  final String userId;
  final String tripId;

  @override
  State<ImageUploadDialog> createState() => _ImageUploadDialogState();
}

class _ImageUploadDialogState extends State<ImageUploadDialog> {
  final _picker = StorageService();
  final _imageService = ItineraryImageService();
  Uint8List? _selectedBytes;
  bool _isUploading = false;
  double? _progress;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('Customize Trip Cover', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(icon: const Icon(Icons.close), color: context.colors.onSurface, onPressed: _isUploading ? null : () => Navigator.of(context).pop()),
            ]),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: context.colors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: context.textStyles.bodySmall?.copyWith(color: context.colors.error))),
                ]),
              ),
            if (_error != null) const SizedBox(height: 12),
            _selectedBytes == null ? _buildUploadArea(context) : _buildPreviewArea(context),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _isUploading ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: !_isUploading && _selectedBytes != null ? _onSave : null,
                child: _isUploading
                    ? Row(children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary)),
                        const SizedBox(width: 8),
                        const Text('Uploading...'),
                      ])
                    : const Text('Save'),
              )
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildUploadArea(BuildContext context) {
    return InkWell(
      onTap: _isUploading ? null : _pick,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: context.colors.outline)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_upload_outlined, size: 48, color: context.colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Drop your image here', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('or click to browse', style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text('JPG, PNG, WebP (max 10MB)', style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.memory(_selectedBytes!, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton.icon(onPressed: _isUploading ? null : _pick, icon: const Icon(Icons.edit), label: const Text('Change Image')),
        const SizedBox(width: 8),
        if (!_isUploading)
          TextButton.icon(
            onPressed: () => setState(() => _selectedBytes = null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
          ),
      ]),
      if (_isUploading && _progress != null) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _progress, minHeight: 6),
      ]
    ]);
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final picked = await _picker.pickImage();
      if (picked == null) return;
      // Client-side validation
      if (picked.bytes.length > 10 * 1024 * 1024) {
        setState(() => _error = 'Image must be under 10MB');
        return;
      }
      final extOk = ['jpg', 'jpeg', 'png', 'webp'].contains(picked.extension.toLowerCase());
      if (!extOk) {
        setState(() => _error = 'Please upload a JPG, PNG, or WebP image');
        return;
      }
      setState(() => _selectedBytes = picked.bytes);
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _onSave() async {
    if (_selectedBytes == null) return;
    setState(() {
      _isUploading = true;
      _progress = null;
      _error = null;
    });
    try {
      final images = await _imageService.uploadItineraryImages(userId: widget.userId, itineraryId: widget.tripId, bytes: _selectedBytes!);
      await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).update({
        'customImages': {
          'original': images.original,
          'large': images.large,
          'medium': images.medium,
          'thumbnail': images.thumbnail,
        },
        'usePlanImage': false,
        'updated_at': Timestamp.now(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
