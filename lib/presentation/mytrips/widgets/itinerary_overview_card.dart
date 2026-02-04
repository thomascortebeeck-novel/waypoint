import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/mytrips/widgets/image_upload_dialog.dart';
import 'package:waypoint/theme.dart';

class ItineraryOverviewCard extends StatefulWidget {
  const ItineraryOverviewCard({super.key, required this.trip, required this.plan, required this.userId});

  final Trip trip;
  final Plan plan;
  final String userId;

  @override
  State<ItineraryOverviewCard> createState() => _ItineraryOverviewCardState();
}

class _ItineraryOverviewCardState extends State<ItineraryOverviewCard> {
  bool _hover = false;

  String? get _versionName {
    final trip = widget.trip;
    final plan = widget.plan;
    if (trip.versionId == null) return null;
    final version = plan.versions.where((v) => v.id == trip.versionId).firstOrNull;
    return version?.name;
  }

  String get _dateWithDuration {
    final trip = widget.trip;
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null || end == null) return 'Dates TBD';
    final fmt = DateFormat('MMM d');
    final days = end.difference(start).inDays + 1;
    final durationStr = days > 0 ? '$days ${days == 1 ? 'day' : 'days'}' : '';
    final sameYear = start.year == end.year;
    final dateStr = sameYear
        ? '${fmt.format(start)} - ${fmt.format(end)}, ${start.year}'
        : '${fmt.format(start)}, ${start.year} - ${fmt.format(end)}, ${end.year}';
    return durationStr.isNotEmpty ? '$dateStr • $durationStr' : dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final plan = widget.plan;

    // Use trip custom image if available, otherwise fall back to plan hero image
    String imageUrl = plan.heroImageUrl;
    if (trip.customImages != null && !trip.usePlanImage) {
      final customLarge = trip.customImages!['large'] as String?;
      final customOriginal = trip.customImages!['original'] as String?;
      if (customLarge != null && customLarge.isNotEmpty) {
        imageUrl = customLarge;
      } else if (customOriginal != null && customOriginal.isNotEmpty) {
        imageUrl = customOriginal;
      }
    }

    final title = trip.title?.isNotEmpty == true ? trip.title! : plan.name;
    final status = _deriveStatus(trip.startDate, trip.endDate);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.16 : 0.12),
              blurRadius: _hover ? 32 : 24,
              offset: Offset(0, _hover ? 12 : 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Image section - 60% of card height like AdventureCard
          Expanded(
            flex: 60,
            child: Stack(children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (c, _) => Container(color: context.colors.surfaceVariant),
                  errorWidget: (c, _, __) => _placeholder(context),
                ),
              ),
              // Gradient overlay matching AdventureCard
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              // Status badge
              Positioned(
                left: 16,
                top: 16,
                child: _statusBadge(context, status),
              ),
              // Edit image button
              Positioned(
                right: 16,
                top: 16,
                child: Opacity(
                  opacity: _hover || !isDesktop ? 1 : 0,
                  child: _editButton(context),
                ),
              ),
              // Title/version/date at bottom of image
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  // Version name
                  if (_versionName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _versionName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                  // Date range with duration
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.white.withValues(alpha: 0.95)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _dateWithDuration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
          // Content section - 40% of card height like AdventureCard
          Expanded(
            flex: 40,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Based on:', style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                const SizedBox(height: 2),
                Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13)),
                if (plan.location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: context.colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        plan.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ),
                  ]),
                ],
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/itinerary/${plan.id}/setup/${trip.id}'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('View Trip', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _menu(context),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.colors.surfaceVariant,
        child: Center(child: Icon(Icons.image_outlined, size: 40, color: context.colors.onSurface.withValues(alpha: 0.4))),
      );

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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        switch (status) { _TripStatus.upcoming => 'Upcoming', _TripStatus.inProgress => 'In Progress', _TripStatus.completed => 'Completed' },
        style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _editButton(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final updated = await showDialog<bool>(context: context, builder: (_) => ImageUploadDialog(userId: widget.userId, tripId: widget.trip.id));
            if (updated == true && mounted) setState(() {});
          },
          child: const SizedBox(width: 40, height: 40, child: Icon(Icons.photo_camera_outlined, size: 20, color: Colors.white)),
        ),
      );



  _TripStatus _deriveStatus(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    if (start != null && start.isAfter(now)) return _TripStatus.upcoming;
    if (end != null && end.isBefore(now)) return _TripStatus.completed;
    if (start != null && (end == null || (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))))) return _TripStatus.inProgress;
    return _TripStatus.upcoming;
  }

  Widget _menu(BuildContext context) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          switch (value) {
            case 'edit_image':
              final updated = await showDialog<bool>(context: context, builder: (_) => ImageUploadDialog(userId: widget.userId, tripId: widget.trip.id));
              if (updated == true && mounted) setState(() {});
              break;
            case 'view_details':
              if (mounted) context.go('/itinerary/${widget.plan.id}/setup/${widget.trip.id}');
              break;
            default:
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'view_details', child: Text('View details')),
          const PopupMenuItem(value: 'edit_image', child: Text('Change cover image')),
          // Placeholders for future features
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate itinerary')),
          const PopupMenuItem(value: 'delete', child: Text('Delete itinerary')),
        ],
      );
}

enum _TripStatus { upcoming, inProgress, completed }
