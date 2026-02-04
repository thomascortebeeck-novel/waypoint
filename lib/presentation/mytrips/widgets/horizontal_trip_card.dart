import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/mytrips/widgets/image_upload_dialog.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

/// Horizontal row-based trip card used on My Trips page
class HorizontalTripCard extends StatefulWidget {
  final Trip trip;
  final Plan plan;
  final String userId;

  const HorizontalTripCard({super.key, required this.trip, required this.plan, required this.userId});

  @override
  State<HorizontalTripCard> createState() => _HorizontalTripCardState();
}

class _HorizontalTripCardState extends State<HorizontalTripCard> {
  bool _hover = false;

  PlanVersion? get _version => widget.plan.versions.where((v) => v.id == widget.trip.versionId).firstOrNull;

  String? get _versionName => _version?.name;

  String get _dateWithDuration {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;
    if (start == null || end == null) return 'Dates TBD';
    final fmt = DateFormat('MMM d');
    final days = end.difference(start).inDays + 1;
    final durationStr = days > 0 ? '$days ${days == 1 ? 'day' : 'days'}' : '';
    final sameYear = start.year == end.year;
    final dateStr = sameYear ? '${fmt.format(start)} - ${fmt.format(end)}, ${start.year}' : '${fmt.format(start)}, ${start.year} - ${fmt.format(end)}, ${end.year}';
    return durationStr.isNotEmpty ? '$dateStr • $durationStr' : dateStr;
  }

  String _computeImageUrl() {
    // Use trip custom image if available, otherwise fall back to plan hero image
    String imageUrl = widget.plan.heroImageUrl;
    final trip = widget.trip;
    if (trip.customImages != null && !trip.usePlanImage) {
      final customLarge = trip.customImages!['large'] as String?;
      final customOriginal = trip.customImages!['original'] as String?;
      if (customLarge != null && customLarge.isNotEmpty) {
        imageUrl = customLarge;
      } else if (customOriginal != null && customOriginal.isNotEmpty) {
        imageUrl = customOriginal;
      }
    }
    return imageUrl;
  }

  _TripStatus _deriveStatus(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    if (start != null && start.isAfter(now)) return _TripStatus.upcoming;
    if (end != null && end.isBefore(now)) return _TripStatus.completed;
    if (start != null && (end == null || (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))))) return _TripStatus.inProgress;
    return _TripStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 640;
    final isTablet = width >= 640 && width < 1024;
    // Use minHeight to avoid overflow while allowing taller content when needed
    final containerMinHeight = isMobile ? 0.0 : (isTablet ? 160.0 : 160.0);

    final plan = widget.plan;
    final trip = widget.trip;
    final title = trip.title?.isNotEmpty == true ? trip.title! : plan.name;
    final status = _deriveStatus(trip.startDate, trip.endDate);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ConstrainedBox(
        // Left-align by removing Center. Limit width and ensure a comfortable min height.
        constraints: BoxConstraints(maxWidth: 1200, minHeight: containerMinHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          // No fixed height to prevent overflow; card grows with content.
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hover ? context.colors.primary.withValues(alpha: 0.2) : context.colors.outline.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.12 : 0.08), blurRadius: _hover ? 16 : 8, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/itinerary/${plan.id}/setup/${trip.id}'),
            child: isMobile
                ? Column(children: [
                    _buildImage(isMobile: true),
                    _buildContent(title: title, status: status, isMobile: true),
                  ])
                : IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Image left 35-40%
                      Expanded(flex: 40, child: _buildImage(isMobile: false)),
                      // Content right 60-65%
                      Expanded(flex: 60, child: _buildContent(title: title, status: status, isMobile: false)),
                    ]),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage({required bool isMobile}) {
    final imageUrl = _computeImageUrl();
    final plan = widget.plan;
    final trip = widget.trip;
    final showEdit = _hover || isMobile;
    final status = _deriveStatus(trip.startDate, trip.endDate);
    final isOwner = trip.isOwner(widget.userId);

    final imageStack = Stack(children: [
      Positioned.fill(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (c, _) => Container(color: context.colors.surfaceVariant),
          errorWidget: (c, _, __) => Container(color: context.colors.surfaceVariant, child: Center(child: Icon(Icons.image_outlined, size: 40, color: context.colors.onSurface.withValues(alpha: 0.4)))),
        ),
      ),
      // Subtle bottom gradient overlay
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.0, 0.6, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      // Status badge
      Positioned(left: 12, top: 12, child: _statusBadge(context, status)),
      // Top right buttons row
      Positioned(
        right: 12,
        top: 12,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: showEdit ? 1 : 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete button (only for owner)
              if (isOwner) ...[
                Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 1.5)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Trip'),
                          content: const Text('Are you sure you want to delete this trip? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        try {
                          await TripService().deleteTrip(trip.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip deleted successfully')),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error deleting trip: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting trip: $e')),
                            );
                          }
                        }
                      }
                    },
                    child: const SizedBox(width: 36, height: 36, child: Icon(Icons.delete_outline, size: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Edit image button
              Material(
                color: Colors.black.withValues(alpha: 0.6),
                shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 1.5)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final updated = await showDialog<bool>(context: context, builder: (_) => ImageUploadDialog(userId: widget.userId, tripId: trip.id));
                    if (updated == true && mounted) setState(() {});
                  },
                  child: const SizedBox(width: 36, height: 36, child: Icon(Icons.photo_camera_outlined, size: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);

    // Wrap in AspectRatio for mobile (gives intrinsic height) or SizedBox.expand for desktop row
    if (isMobile) {
      return AspectRatio(aspectRatio: 16 / 9, child: imageStack);
    }
    return SizedBox.expand(child: imageStack);
  }

  Widget _buildContent({required String title, required _TripStatus status, required bool isMobile}) {
    final plan = widget.plan;
    final trip = widget.trip;
    final version = _version;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 16 : 20, 24, isMobile ? 16 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        // Date range
        Row(children: [
          Icon(Icons.calendar_today, size: 16, color: context.colors.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(child: Text(_dateWithDuration, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        // Based on
        Text('Based on:', style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
          ),
        ]),
        if (plan.location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 14, color: context.colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Expanded(child: Text(plan.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6))))
          ]),
        ],
        const SizedBox(height: 12),
        // Metadata badges
        Wrap(spacing: 12, runSpacing: 8, children: [
          _metaBadge(icon: Icons.schedule, label: _durationLabel()),
          if (version != null) _versionBadge(version),
          if (version != null) _accommodationBadge(version),
          // Member count badge (for group trips)
          if (trip.memberIds.length > 1)
            _metaBadge(icon: Icons.group, label: '${trip.memberIds.length} members'),
          // Customization status badge (for owner only)
          if (trip.isOwner(widget.userId))
            _customizationBadge(trip),
          // Joined badge (if not owner)
          if (!trip.isOwner(widget.userId))
            _joinedBadge(),
        ]),
      ]),
    );
  }

  String _durationLabel() {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;
    if (start == null || end == null) return 'Dates TBD';
    final days = end.difference(start).inDays + 1;
    return '$days ${days == 1 ? 'day' : 'days'}';
  }

  Widget _metaBadge({required IconData icon, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: context.colors.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(label, style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.onSurface.withValues(alpha: 0.8))),
        ]),
      );

  Widget _versionBadge(PlanVersion version) {
    // Prefer experienceLevel if present, otherwise use difficulty
    Color dotColor;
    String label;
    IconData icon;
    if (version.experienceLevel != null) {
      switch (version.experienceLevel!) {
        case ExperienceLevel.beginner:
          dotColor = const Color(0xFF10B981);
          label = 'Easy • ${version.name}';
          icon = Icons.flag_circle;
          break;
        case ExperienceLevel.intermediate:
          dotColor = const Color(0xFFF59E0B);
          label = 'Moderate • ${version.name}';
          icon = Icons.landscape;
          break;
        case ExperienceLevel.expert:
          dotColor = const Color(0xFFEF4444);
          label = 'Expert • ${version.name}';
          icon = Icons.whatshot;
          break;
      }
    } else {
      switch (version.difficulty) {
        case Difficulty.easy:
          dotColor = const Color(0xFF10B981);
          label = 'Easy • ${version.name}';
          icon = Icons.flag_circle;
          break;
        case Difficulty.moderate:
          dotColor = const Color(0xFFF59E0B);
          label = 'Moderate • ${version.name}';
          icon = Icons.landscape;
          break;
        case Difficulty.hard:
          dotColor = const Color(0xFFFB923C);
          label = 'Hard • ${version.name}';
          icon = Icons.fitness_center;
          break;
        case Difficulty.extreme:
          dotColor = const Color(0xFFEF4444);
          label = 'Expert • ${version.name}';
          icon = Icons.whatshot;
          break;
        case Difficulty.none:
          dotColor = context.colors.onSurface.withValues(alpha: 0.5);
          label = version.name;
          icon = Icons.flag_circle;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: dotColor),
        const SizedBox(width: 6),
        Text(label, style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.onSurface.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _accommodationBadge(PlanVersion version) {
    final isComfort = version.comfortType == ComfortType.comfort;
    final icon = isComfort ? Icons.hotel : Icons.park;
    final label = isComfort ? 'Comfort' : 'Adventure';
    return _metaBadge(icon: icon, label: label);
  }

  Widget _joinedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_add, size: 14, color: context.colors.tertiary),
        const SizedBox(width: 6),
        Text(
          'Joined',
          style: context.textStyles.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.tertiary,
          ),
        ),
      ]),
    );
  }

  Widget _customizationBadge(Trip trip) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (trip.customizationStatus) {
      case TripCustomizationStatus.draft:
        bgColor = StatusColors.draftBg;
        textColor = StatusColors.draft;
        icon = Icons.edit_note;
        label = 'Draft';
        break;
      case TripCustomizationStatus.customizing:
        bgColor = StatusColors.customizingBg;
        textColor = StatusColors.customizing;
        icon = Icons.tune;
        label = 'Customizing';
        break;
      case TripCustomizationStatus.ready:
        bgColor = StatusColors.readyBg;
        textColor = StatusColors.ready;
        icon = Icons.check_circle;
        label = 'Ready';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ]),
    );
  }

  Widget _statusBadge(BuildContext context, _TripStatus status) {
    Color bg;
    switch (status) {
      case _TripStatus.upcoming:
        bg = StatusColors.upcoming;
        break;
      case _TripStatus.inProgress:
        bg = StatusColors.inProgress;
        break;
      case _TripStatus.completed:
        bg = StatusColors.completed;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
      ]),
      child: Text(
        switch (status) { _TripStatus.upcoming => 'Upcoming', _TripStatus.inProgress => 'In Progress', _TripStatus.completed => 'Completed' },
        style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

enum _TripStatus { upcoming, inProgress, completed }
