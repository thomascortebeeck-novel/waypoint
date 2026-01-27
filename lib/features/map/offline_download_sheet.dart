import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/offline_region_manager.dart';

/// Bottom sheet for downloading offline map regions
class OfflineDownloadSheet extends StatefulWidget {
  final List<LatLng> routePoints;
  final String routeName;
  final String routeId;

  const OfflineDownloadSheet({
    super.key,
    required this.routePoints,
    required this.routeName,
    required this.routeId,
  });

  static Future<void> show(
    BuildContext context, {
    required List<LatLng> routePoints,
    required String routeName,
    required String routeId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OfflineDownloadSheet(
        routePoints: routePoints,
        routeName: routeName,
        routeId: routeId,
      ),
    );
  }

  @override
  State<OfflineDownloadSheet> createState() => _OfflineDownloadSheetState();
}

class _OfflineDownloadSheetState extends State<OfflineDownloadSheet> {
  final _offlineManager = OfflineRegionManager();
  StreamSubscription<DownloadProgress>? _progressSub;
  
  DownloadProgress? _currentProgress;
  EstimatedSize? _estimatedSize;
  bool _isDownloading = false;
  bool _isEstimating = true;
  bool _alreadyDownloaded = false;
  
  int _selectedMinZoom = 10;
  int _selectedMaxZoom = 16;
  double _bufferKm = 2.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _offlineManager.initialize();
    
    // Check if already downloaded
    _alreadyDownloaded = await _offlineManager.isRegionDownloaded(widget.routeId);
    
    // Estimate size
    await _updateEstimate();
    
    // Listen to progress
    _progressSub = _offlineManager.downloadProgress.listen((progress) {
      if (progress.regionId == widget.routeId) {
        setState(() => _currentProgress = progress);
        
        if (progress.phase == DownloadPhase.complete) {
          setState(() {
            _isDownloading = false;
            _alreadyDownloaded = true;
          });
        } else if (progress.phase == DownloadPhase.error) {
          setState(() => _isDownloading = false);
          _showError(progress.message);
        } else if (progress.phase == DownloadPhase.cancelled) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download cancelled')),
          );
        }
      }
    });

    setState(() => _isEstimating = false);
  }

  Future<void> _updateEstimate() async {
    setState(() => _isEstimating = true);
    
    _estimatedSize = await _offlineManager.estimateRegionSize(
      routePoints: widget.routePoints,
      bufferKm: _bufferKm,
      minZoom: _selectedMinZoom,
      maxZoom: _selectedMaxZoom,
    );
    
    setState(() => _isEstimating = false);
  }

  Future<void> _startDownload() async {
    setState(() => _isDownloading = true);
    
    await _offlineManager.downloadRouteRegion(
      regionId: widget.routeId,
      routePoints: widget.routePoints,
      bufferKm: _bufferKm,
      minZoom: _selectedMinZoom,
      maxZoom: _selectedMaxZoom,
      displayName: widget.routeName,
    );
  }

  Future<void> _cancelDownload() async {
    await _offlineManager.cancelDownload(widget.routeId);
    setState(() => _isDownloading = false);
  }

  Future<void> _deleteRegion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offline Map?'),
        content: Text('Remove the offline map for "${widget.routeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _offlineManager.deleteRegion(widget.routeId);
      setState(() => _alreadyDownloaded = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Row(
            children: [
              Icon(
                _alreadyDownloaded ? Icons.cloud_done : Icons.cloud_download,
                color: _alreadyDownloaded ? Colors.green : Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _alreadyDownloaded ? 'Offline Map Ready' : 'Download for Offline',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.routeName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_alreadyDownloaded) ...[ 
            // Already downloaded state
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This route is available offline with full 3D terrain.',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteRegion,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Offline Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else if (_isDownloading && _currentProgress != null) ...[
            // Downloading state
            _buildProgressSection(),
          ] else ...[
            // Not downloaded - show options
            _buildOptionsSection(),
            const SizedBox(height: 24),
            _buildEstimateSection(),
            const SizedBox(height: 24),
            _buildDownloadButton(),
          ],
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Download Options',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        
        // Buffer slider
        Row(
          children: [
            const Text('Buffer around route:'),
            const Spacer(),
            Text(
              '${_bufferKm.toStringAsFixed(1)} km',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: _bufferKm,
          min: 0.5,
          max: 5.0,
          divisions: 9,
          onChanged: (value) {
            setState(() => _bufferKm = value);
            _updateEstimate();
          },
        ),
        
        // Zoom level info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.layers, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Detail level: Zoom $_selectedMinZoom - $_selectedMaxZoom',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateSection() {
    if (_isEstimating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_estimatedSize == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _estimatedSize!.formattedSize,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Estimated download size',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_estimatedSize!.tiles}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'tiles',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = _currentProgress!;
    
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 16),
        
        // Progress text
        Text(
          progress.message,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          '${progress.progressPercent}%',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        if (progress.completedTiles != null && progress.totalTiles != null) ...[
          const SizedBox(height: 4),
          Text(
            '${progress.completedTiles} / ${progress.totalTiles} tiles',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
        
        // Cancel button
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancelDownload,
            icon: const Icon(Icons.close),
            label: const Text('Cancel Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download),
        label: const Text('Download for Offline Use'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
