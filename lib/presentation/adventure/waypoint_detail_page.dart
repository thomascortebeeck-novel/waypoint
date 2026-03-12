import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/core/models/waypoint_category.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/core/theme/layout_tokens.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_waypoint_override_model.dart';
import 'package:waypoint/models/waypoint_document_model.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/services/trip_service.dart';

/// Waypoint detail page (view) for trip owners/participants and plan viewers.
/// Not the edit page — builders use Edit button to go to WaypointEditPage.
class WaypointDetailPage extends StatefulWidget {
  final RouteWaypoint waypoint;
  final int dayNum;
  final String? tripId;
  final String? planId;
  final int versionIndex;
  final bool isTripOwner;
  final bool isBuilder;
  final Trip? trip;

  const WaypointDetailPage({
    super.key,
    required this.waypoint,
    required this.dayNum,
    this.tripId,
    this.planId,
    this.versionIndex = 0,
    this.isTripOwner = false,
    this.isBuilder = false,
    this.trip,
  });

  @override
  State<WaypointDetailPage> createState() => _WaypointDetailPageState();
}

class _WaypointDetailPageState extends State<WaypointDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TripWaypointOverride? _override;
  bool _loading = true;
  String? _error;
  int _currentPhotoIndex = 0;
  String? _displayName; // local override for inline name edit
  final TripService _tripService = TripService();
  final StorageService _storageService = StorageService();
  List<WaypointDocument> _documents = [];
  bool _uploadingDocument = false;
  int? _overviewTargetDayNum;
  String? _overviewTime;
  String? _overviewStatus;
  double? _overviewPrice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.tripId != null) {
      _loadOverride();
      _loadDocuments();
    } else {
      setState(() {
        _overviewTime = widget.waypoint.actualStartTime ?? widget.waypoint.suggestedStartTime;
        _overviewStatus = 'not_booked';
        _overviewPrice = widget.waypoint.estimatedPrice;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverride() async {
    if (widget.tripId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await _tripService.getWaypointOverride(
        widget.tripId!,
        widget.dayNum,
        widget.waypoint.id,
      );
      if (mounted) {
        setState(() {
          _override = o;
          _overviewTargetDayNum = o?.targetDayNum;
          _overviewTime = o?.actualStartTime ?? widget.waypoint.actualStartTime ?? widget.waypoint.suggestedStartTime;
          _overviewStatus = o?.status ?? 'not_booked';
          _overviewPrice = o?.price ?? widget.waypoint.estimatedPrice;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _canEditOverview =>
      widget.tripId != null && widget.isTripOwner;
  /// Only trip owner or Quartermaster may upload waypoint documents.
  bool get _canUploadDocuments {
    if (widget.tripId == null || widget.trip == null) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return widget.isTripOwner || widget.trip!.isQuartermaster(uid);
  }

  /// True when the user can edit (plan builder or trip owner). Used for Edit button and inline name edit.
  bool get _isOwner => widget.isBuilder || widget.isTripOwner;

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat.yMMMd().format(date);
  }

  String _formatTime() {
    final actual = _overviewTime ?? widget.waypoint.actualStartTime;
    final suggested = widget.waypoint.suggestedStartTime;
    if (actual != null && suggested != null && actual != suggested) {
      return '$actual – $suggested';
    }
    return actual ?? suggested ?? '—';
  }

  String _formatStatus(String? status) {
    if (status == null || status.isEmpty) return '—';
    switch (status) {
      case 'not_booked':
        return 'Not booked';
      case 'booked':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: BrandingLightTokens.secondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BrandingLightTokens.formLabel)),
        ],
      ),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        if (!isLast) Divider(height: 1, color: BrandingLightTokens.formFieldBorder),
      ],
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: column);
    }
    return column;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waypoint')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waypoint')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Something went wrong: $_error'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _loadOverride(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final photoUrls = _photoUrlsList();
    final isOwner = widget.isBuilder || widget.isTripOwner;

    return Scaffold(
      backgroundColor: BrandingLightTokens.background,
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Column(
        children: [
          _buildHeroCarousel(photoUrls),
          Container(
            color: BrandingLightTokens.background,
            child: TabBar(
            controller: _tabController,
            labelColor: BrandingLightTokens.appBarGreen,
            unselectedLabelColor: BrandingLightTokens.hint,
            indicatorColor: BrandingLightTokens.appBarGreen,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Details'),
            ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildDetailsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isOwner),
    );
  }

  List<String> _photoUrlsList() {
    final urls = widget.waypoint.photoUrls;
    if (urls != null && urls.isNotEmpty) return urls;
    if (widget.waypoint.photoUrl != null) return [widget.waypoint.photoUrl!];
    if (widget.waypoint.linkImageUrl != null && widget.waypoint.linkImageUrl!.isNotEmpty) {
      return [widget.waypoint.linkImageUrl!];
    }
    return [];
  }

  Widget _buildHeroCarousel(List<String> photoUrls) {
    if (photoUrls.isEmpty) {
      return Container(
        height: 280,
        color: BrandingLightTokens.appBarGreen.withOpacity(0.8),
      );
    }
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: photoUrls.length,
            onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
            itemBuilder: (context, i) => CachedNetworkImage(
              imageUrl: photoUrls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: Colors.black26),
              errorWidget: (_, __, ___) => Container(color: Colors.black26),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BrandingLightTokens.appBarGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    WaypointCategoryLabels.fromType(widget.waypoint.type).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _isOwner ? _showNameEditSheet : null,
                  child: Text(
                    _displayName ?? widget.waypoint.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                if (widget.waypoint.address != null && widget.waypoint.address!.isNotEmpty)
                  Text(
                    widget.waypoint.address!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (photoUrls.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photoUrls.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPhotoIndex == i ? 8 : 5,
                  height: _currentPhotoIndex == i ? 8 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                )),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNameEditSheet() {
    final controller = TextEditingController(text: _displayName ?? widget.waypoint.name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _displayName = controller.text.trim().isEmpty ? null : controller.text.trim());
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    final startDate = widget.trip?.startDate;
    final endDate = widget.trip?.endDate;
    final effectiveDayNum = _overviewTargetDayNum ?? widget.dayNum;
    DateTime? currentDate;
    if (startDate != null && effectiveDayNum >= 1) {
      currentDate = startDate.add(Duration(days: effectiveDayNum - 1));
    }
    final effectivePrice = _overviewPrice ?? widget.waypoint.estimatedPrice;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LayoutTokens.formMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cream info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E8CF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BrandingLightTokens.formFieldBorder),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'Date',
                      _formatDate(currentDate),
                      isLast: false,
                      onTap: _canEditOverview ? () => _pickDate(startDate, endDate) : null,
                    ),
                    _buildInfoRow(
                      'Time',
                      _formatTime(),
                      isLast: false,
                      onTap: _canEditOverview ? _pickTime : null,
                    ),
                    _buildInfoRow(
                      'Status',
                      _formatStatus(_overviewStatus),
                      isLast: false,
                      onTap: _canEditOverview ? _pickStatus : null,
                    ),
                    _buildInfoRow(
                      'Price',
                      effectivePrice != null ? '\$${effectivePrice.toStringAsFixed(2)}' : '—',
                      isLast: true,
                      onTap: _canEditOverview ? _pickPrice : null,
                    ),
                  ],
                ),
              ),
              // Notes
              if (widget.waypoint.description != null && widget.waypoint.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Notes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BrandingLightTokens.formLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.waypoint.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: BrandingLightTokens.secondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_canUploadDocuments) ...[
                Text('Documents', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Upload documents (e.g. confirmations). Shared with all trip participants.',
                  style: theme.textTheme.bodySmall,
                ),
                if (_documents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._documents.map((doc) => ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(doc.fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      doc.uploadedAt.toIso8601String().split('T').first,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onTap: () => _openDocumentUrl(doc.downloadUrl),
                  )),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _uploadingDocument ? null : () => _pickAndUploadDocument(),
                  icon: _uploadingDocument
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(_uploadingDocument ? 'Uploading...' : 'Upload document'),
                ),
              ],
              if (_canEditOverview) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveOverview(),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(DateTime? start, DateTime? end) async {
    if (start == null || end == null) return;
    final initial = _overviewTargetDayNum ?? widget.dayNum;
    final initialDate = start.add(Duration(days: initial - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: start,
      lastDate: end,
    );
    if (picked != null && mounted) {
      final days = picked.difference(start).inDays + 1;
      setState(() => _overviewTargetDayNum = days);
    }
  }

  Future<void> _pickTime() async {
    final parts = (_overviewTime ?? '09:00').split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59)),
    );
    if (picked != null && mounted) {
      setState(() => _overviewTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickStatus() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Not booked'), onTap: () => Navigator.pop(context, 'not_booked')),
            ListTile(title: const Text('Booked'), onTap: () => Navigator.pop(context, 'booked')),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _overviewStatus = chosen);
  }

  Future<void> _pickPrice() async {
    final c = TextEditingController(text: _overviewPrice?.toStringAsFixed(2) ?? '');
    final chosen = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Price (actual cost)'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'e.g. 25.00'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(c.text.replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) setState(() => _overviewPrice = chosen);
  }

  void _saveOverview() {
    if (widget.tripId == null) return;
    final startDate = widget.trip?.startDate;
    final endDate = widget.trip?.endDate;
    final targetDay = _overviewTargetDayNum ?? widget.dayNum;
    if (startDate != null && endDate != null) {
      final selectedDate = startDate.add(Duration(days: targetDay - 1));
      if (targetDay < 1 || selectedDate.isBefore(startDate) || selectedDate.isAfter(endDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date must be within your trip dates')),
        );
        return;
      }
    }
    final override = TripWaypointOverride(
      tripId: widget.tripId!,
      dayNum: widget.dayNum,
      waypointId: widget.waypoint.id,
      targetDayNum: _overviewTargetDayNum != null && _overviewTargetDayNum != widget.dayNum ? _overviewTargetDayNum : null,
      actualStartTime: _overviewTime,
      status: _overviewStatus,
      price: _overviewPrice,
    );
    _tripService.setWaypointOverride(override).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_overviewTargetDayNum != null && _overviewTargetDayNum != widget.dayNum
              ? 'Waypoint moved to Day $_overviewTargetDayNum'
              : 'Saved')),
        );
        setState(() => _override = override);
      }
    });
  }

  Future<void> _loadDocuments() async {
    if (widget.tripId == null) return;
    try {
      final list = await _tripService.getWaypointDocuments(
        widget.tripId!,
        widget.dayNum,
        widget.waypoint.id,
      );
      if (mounted) setState(() => _documents = list);
    } catch (_) {
      if (mounted) setState(() => _documents = []);
    }
  }

  Future<void> _pickAndUploadDocument() async {
    if (widget.tripId == null || _uploadingDocument) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      allowMultiple: false,
      withData: true, // ensure bytes are populated on mobile/desktop, not just web
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file. Try a different file.')),
        );
      }
      return;
    }
    final fileName = file.name;
    final ext = file.extension ?? 'bin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload document'),
        content: Text('Upload "$fileName"? It will be shared with all trip participants.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploadingDocument = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      const uuid = Uuid();
      // Storage rules expect trips/{userId}/{tripId}/...
      final path = 'trips/$userId/${widget.tripId}/waypoint_docs/${widget.waypoint.id}_${widget.dayNum}/${uuid.v4()}.$ext';
      final contentType = _contentTypeForExtension(ext);
      final downloadUrl = await _storageService.uploadFile(
        path: path,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
      );
      await _tripService.addWaypointDocument(
        tripId: widget.tripId!,
        dayNum: widget.dayNum,
        waypointId: widget.waypoint.id,
        downloadUrl: downloadUrl,
        fileName: fileName,
        uploadedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  static String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'heic': return 'image/heic';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  Widget _buildDetailsTab() {
    final wp = widget.waypoint;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LayoutTokens.formMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('Category', WaypointCategoryLabels.fromType(wp.type)),
              if (wp.subCategoryTags != null && wp.subCategoryTags!.isNotEmpty)
                _buildDetailSection('Type', wp.subCategoryTags!.join(', ')),
              _buildDetailSection('Name', wp.name),
              if (wp.description != null && wp.description!.isNotEmpty)
                _buildDetailSection('Description', wp.description!),
              if (wp.address != null && wp.address!.isNotEmpty)
                _buildDetailSection('Address', wp.address!),
              if (wp.phoneNumber != null && wp.phoneNumber!.isNotEmpty)
                _buildDetailSection('Phone', wp.phoneNumber!),
              if (wp.website != null && wp.website!.isNotEmpty)
                _buildDetailSection('Website', wp.website!),
              if (wp.rating != null)
                _buildDetailSection('Rating', '${wp.rating!.toStringAsFixed(1)} ★'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandingLightTokens.hint,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: BrandingLightTokens.formLabel,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isOwner) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: BrandingLightTokens.background,
        border: Border(top: BorderSide(color: BrandingLightTokens.formFieldBorder)),
      ),
      child: Row(
        children: [
          if (isOwner) ...[
            OutlinedButton(
              onPressed: _navigateToEdit,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BrandingLightTokens.appBarGreen, width: 1.5),
                foregroundColor: BrandingLightTokens.appBarGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _launchMap,
              style: FilledButton.styleFrom(
                backgroundColor: BrandingLightTokens.appBarGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: const Text('Go there', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMap() async {
    final lat = widget.waypoint.position.latitude;
    final lng = widget.waypoint.position.longitude;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Google Maps'),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Apple Maps'),
              onTap: () => Navigator.of(context).pop('apple'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Waze'),
              onTap: () => Navigator.of(context).pop('waze'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    String url;
    switch (chosen) {
      case 'apple':
        url = 'https://maps.apple.com/?daddr=$lat,$lng';
        break;
      case 'waze':
        url = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
        break;
      default:
        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToEdit() {
    if (widget.planId == null) return;
    context.push(
      '/builder/${widget.planId}/waypoint/${widget.versionIndex}/${widget.dayNum}',
      extra: {
        'mode': 'edit',
        'existingWaypoint': widget.waypoint,
      },
    );
  }
}
