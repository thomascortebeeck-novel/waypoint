import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/itinerary_image_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

/// Final step: Custom image upload (optional)
class OnboardingImageScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  const OnboardingImageScreen({
    super.key,
    required this.planId,
    required this.tripId,
  });

  @override
  State<OnboardingImageScreen> createState() => _OnboardingImageScreenState();
}

class _OnboardingImageScreenState extends State<OnboardingImageScreen> {
  final _trips = TripService();
  final _imageService = ItineraryImageService();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _saving = false;

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _selectedImageBytes = result.files.first.bytes;
          _selectedImageName = result.files.first.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      // Upload custom image if selected
      if (_selectedImageBytes != null) {
        final images = await _imageService.uploadItineraryImages(
          userId: uid,
          itineraryId: widget.tripId,
          bytes: _selectedImageBytes!,
        );
        await _trips.updateTripCustomImage(
          tripId: widget.tripId,
          imageUrls: {
            'original': images.original,
            'large': images.large,
            'medium': images.medium,
            'thumbnail': images.thumbnail,
          },
          usePlanImage: false,
        );
      }

      if (!mounted) return;
      // Navigate to trip details page
      context.go('/trip/${widget.tripId}');
    } catch (e) {
      debugPrint('Upload image failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    // Skip image upload and go to trip details
    context.go('/trip/${widget.tripId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.go('/mytrips'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terrain, color: context.colors.primary, size: 24),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Question number
              Text(
                'Final Step',
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // Question
              Text(
                'Add a custom cover image',
                style: context.textStyles.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make your trip unique with a custom cover (optional)',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              // Image upload area
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedImageBytes != null
                          ? context.colors.primary
                          : context.colors.outlineVariant,
                      width: _selectedImageBytes != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: context.colors.surfaceContainerLow,
                    image: _selectedImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_selectedImageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 56,
                              color: context.colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap to upload an image',
                              style: context.textStyles.titleMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Recommended: 4:3 aspect ratio',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () => setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageName = null;
                                }),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (_selectedImageName != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: context.colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedImageName!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.pop(),
        backLabel: 'Back',
        onNext: _saving ? null : (_selectedImageBytes != null ? _finish : _skip),
        nextEnabled: !_saving,
        nextLabel: _saving
            ? 'Uploading…'
            : _selectedImageBytes != null
                ? 'Finish'
                : 'Skip',
        nextIcon: Icons.check,
      ),
    );
  }
}
