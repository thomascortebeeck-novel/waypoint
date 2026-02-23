import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// GPX import area component
/// 
/// Dashed border drop zone for GPX file import (builder only, when no GPX loaded).
/// On hover: primary green border + light green background.
/// On file select: parse GPX → populate route → auto-fill distance/elevation/duration.

class GpxImportArea extends StatefulWidget {
  final bool hasGpx;
  final VoidCallback? onImport;
  final VoidCallback? onReplace;
  final bool isLoading;
  
  const GpxImportArea({
    super.key,
    this.hasGpx = false,
    this.onImport,
    this.onReplace,
    this.isLoading = false,
  });
  
  @override
  State<GpxImportArea> createState() => _GpxImportAreaState();
}

class _GpxImportAreaState extends State<GpxImportArea> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    // If GPX already loaded, show "Replace GPX" button instead
    if (widget.hasGpx && widget.onReplace != null) {
      return GestureDetector(
        onTap: widget.onReplace,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: WaypointColors.surface,
            border: Border.all(color: WaypointColors.border, width: 1.0),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Text(
            'Replace GPX',
            style: WaypointTypography.bodyMedium.copyWith(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: WaypointColors.textSecondary,
            ),
          ),
        ),
      );
    }
    
    // Show drop zone (builder only, when no GPX)
    if (widget.onImport == null) {
      return const SizedBox.shrink();
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : _handleFilePick,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: _isHovering ? WaypointColors.primarySurface : WaypointColors.surface,
            border: Border.all(
              color: _isHovering ? WaypointColors.primaryLight : WaypointColors.border,
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
          ),
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '📂',
                      style: TextStyle(fontSize: 24.0),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Import GPX Route',
                      style: WaypointTypography.bodyMedium.copyWith(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: _isHovering ? WaypointColors.primary : WaypointColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Drag & drop or click to upload .gpx file',
                      style: WaypointTypography.bodyMedium.copyWith(
                        fontSize: 11.0,
                        color: WaypointColors.textTertiary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  Future<void> _handleFilePick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );
      
      if (result != null && result.files.isNotEmpty && widget.onImport != null) {
        widget.onImport!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }
}

