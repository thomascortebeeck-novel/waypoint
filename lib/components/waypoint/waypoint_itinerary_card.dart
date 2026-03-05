import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';

/// Stippl-style itinerary card.
/// Layout (reference):
///   [name + time row] on left  |  [72×72 thumbnail] on right  |  [three-dot menu]
/// No left accent bar. Background: warm tan #F2E8CF.
class WaypointItineraryCard extends StatefulWidget {
  final RouteWaypoint waypoint;
  final int order;
  final bool isBuilder;
  final bool canEditTime;
  final VoidCallback? onTap;
  final VoidCallback? onGetDirections;
  final void Function(String?)? onTimeChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddAlternative;
  final VoidCallback? onRemoveAlternative;
  final String? timeOverride;
  final bool isSelectedInPickOne;
  final VoidCallback? onSelectInPickOne;
  final bool isAddOnDisabled;
  final VoidCallback? onToggleAddOn;
  final VoidCallback? onPromoteToStandalone;
  final bool isPromoted;

  const WaypointItineraryCard({
    super.key,
    required this.waypoint,
    required this.order,
    this.isBuilder = false,
    this.canEditTime = false,
    this.onTap,
    this.onGetDirections,
    this.onTimeChanged,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
    this.onAddAlternative,
    this.onRemoveAlternative,
    this.timeOverride,
    this.isSelectedInPickOne = false,
    this.onSelectInPickOne,
    this.isAddOnDisabled = false,
    this.onToggleAddOn,
    this.onPromoteToStandalone,
    this.isPromoted = false,
  });

  @override
  State<WaypointItineraryCard> createState() => _WaypointItineraryCardState();
}

class _WaypointItineraryCardState extends State<WaypointItineraryCard> {
  bool _expanded = false;

  static const Color _kCardBg = Color(0xFFF2E8CF);
  static const Color _kTextPrimary = Color(0xFF212529);

  bool get _hasShowMore =>
      (widget.waypoint.description != null &&
          widget.waypoint.description!.isNotEmpty) ||
      (widget.waypoint.photoUrls != null &&
          widget.waypoint.photoUrls!.length > 1);

  String get _timeLabel {
    if (widget.timeOverride != null && widget.timeOverride!.isNotEmpty) {
      return widget.timeOverride!;
    }
    final wp = widget.waypoint;
    final time = wp.actualStartTime ?? wp.suggestedStartTime;
    if (time != null && time.isNotEmpty) return time;
    return 'No time set';
  }

  @override
  Widget build(BuildContext context) {
    final config = getCategoryConfig(widget.waypoint.type);
    final theme = Theme.of(context);

    final showPickOneRadio = widget.onSelectInPickOne != null;
    final showAddOnCheckbox = widget.onToggleAddOn != null;

    return Material(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPickOneRadio)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          child: Radio<bool>(
                            value: true,
                            groupValue: widget.isSelectedInPickOne,
                            onChanged: (_) => widget.onSelectInPickOne?.call(),
                          ),
                        ),
                      if (showAddOnCheckbox)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, top: 8),
                          child: Checkbox(
                            value: !widget.isAddOnDisabled,
                            onChanged: (_) => widget.onToggleAddOn?.call(),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.waypoint.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
                                      height: 1.3,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
                                      height: 1.3,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildTimeRow(theme),
                              if (widget.isPromoted &&
                                  (widget.waypoint.travelDistance == null ||
                                      widget.waypoint.travelDistance == 0))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Transport not set — tap to add',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ) ??
                                        TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ),
                              if (_hasShowMore) _buildShowMoreRow(theme),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: _buildActionsColumn(config, theme),
                      ),
                      // Thumbnail fills row height when collapsed (stretch gives it the height).
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 72,
                            maxWidth: 72,
                            minHeight: 72,
                          ),
                          child: _buildThumbnailContent(config),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_expanded) ..._buildExpandedContent(config, theme),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildTimeRow(ThemeData theme) {
    const style = TextStyle(
      fontSize: 13,
      color: BrandingLightTokens.secondary,
      height: 1.3,
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.canEditTime && widget.onTimeChanged != null)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.touch_app, size: 13, color: BrandingLightTokens.secondary),
          ),
        const Icon(Icons.schedule, size: 14, color: BrandingLightTokens.secondary),
        const SizedBox(width: 5),
        Text(_timeLabel, style: style),
      ],
    );
    if (widget.canEditTime && widget.onTimeChanged != null) {
      return GestureDetector(
        onTap: () => _showTimePicker(context),
        child: content,
      );
    }
    return content;
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final (h, m) = _parseTime(_timeLabel);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (picked != null && mounted) {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      widget.onTimeChanged?.call(s);
    }
  }

  (int, int) _parseTime(String t) {
    if (t == 'No time set') return (9, 0);
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts[1]) ?? 0;
      return (h.clamp(0, 23), m.clamp(0, 59));
    }
    return (9, 0);
  }

  Widget _buildShowMoreRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _expanded ? 'Show less' : 'Show more',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExpandedContent(CategoryConfig config, ThemeData theme) {
    final list = <Widget>[];
    if (widget.waypoint.description?.isNotEmpty == true) {
      list.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            widget.waypoint.description!,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ) ??
                const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      );
    }
    final urls = widget.waypoint.photoUrls;
    if (urls != null && urls.length > 1) {
      list.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length - 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final url = urls[i + 1];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: config.color.withOpacity(0.15),
                        child: Icon(config.icon, size: 24, color: config.color),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: config.color.withOpacity(0.15),
                        child: Icon(config.icon, size: 24, color: config.color),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return list;
  }

  Widget _buildThumbnailContent(CategoryConfig config) {
    final imageUrl = widget.waypoint.photoUrls?.isNotEmpty == true
        ? widget.waypoint.photoUrls!.first
        : (widget.waypoint.photoUrl ?? widget.waypoint.linkImageUrl);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 72,
        placeholder: (_, __) => _thumbnailPlaceholder(config),
        errorWidget: (_, __, ___) => _thumbnailPlaceholder(config),
      );
    }
    return _thumbnailPlaceholder(config);
  }

  Widget _thumbnailPlaceholder(CategoryConfig config) {
    return Container(
      color: config.color.withOpacity(0.15),
      child: Center(
        child: Icon(config.icon, size: 26, color: config.color),
      ),
    );
  }

  Widget _buildActionsColumn(CategoryConfig config, ThemeData theme) {
    final bool hasBuilderActions =
        widget.isBuilder &&
        (widget.onMoveUp != null ||
            widget.onMoveDown != null ||
            widget.onEdit != null ||
            widget.onDelete != null ||
            widget.onAddAlternative != null ||
            widget.onRemoveAlternative != null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBuilderActions) ...[
            if (widget.onMoveUp != null)
              _buildArrowBtn(Icons.keyboard_arrow_up, widget.onMoveUp, config),
            if (widget.onMoveUp != null && widget.onMoveDown != null)
              const SizedBox(height: 2),
            if (widget.onMoveDown != null)
              _buildArrowBtn(Icons.keyboard_arrow_down, widget.onMoveDown, config),
            const SizedBox(height: 2),
            _buildThreeDot(forBuilder: true),
          ] else if (widget.onPromoteToStandalone != null) ...[
            _buildThreeDot(forBuilder: false),
            if (widget.onGetDirections != null) ...[
              const SizedBox(height: 4),
              _buildDirectionsBtn(config),
            ],
          ] else if (widget.onGetDirections != null)
            _buildDirectionsBtn(config),
        ],
      ),
    );
  }

  Widget _buildArrowBtn(IconData icon, VoidCallback? onTap, CategoryConfig config) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Icon(icon, size: 16, color: const Color(0xFF666666)),
        ),
      ),
    );
  }

  Widget _buildThreeDot({required bool forBuilder}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: BrandingLightTokens.secondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            widget.onEdit?.call();
          case 'delete':
            widget.onDelete?.call();
          case 'add_alternative':
            widget.onAddAlternative?.call();
          case 'remove_alternative':
            widget.onRemoveAlternative?.call();
          case 'promote':
            widget.onPromoteToStandalone?.call();
        }
      },
      itemBuilder: (context) => [
        if (forBuilder) ...[
          if (widget.onEdit != null)
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
          if (widget.onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, size: 18),
                SizedBox(width: 8),
                Text('Delete'),
              ]),
            ),
          if (widget.onAddAlternative != null)
            const PopupMenuItem(
              value: 'add_alternative',
              child: Row(children: [
                Icon(Icons.add_link, size: 18),
                SizedBox(width: 8),
                Text('Add alternative'),
              ]),
            ),
          if (widget.onRemoveAlternative != null)
            const PopupMenuItem(
              value: 'remove_alternative',
              child: Row(children: [
                Icon(Icons.link_off, size: 18),
                SizedBox(width: 8),
                Text('Use as standalone'),
              ]),
            ),
        ] else ...[
          if (widget.onPromoteToStandalone != null)
            const PopupMenuItem(
              value: 'promote',
              child: Row(children: [
                Icon(Icons.unfold_more, size: 18),
                SizedBox(width: 8),
                Text('Use as separate stop'),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _buildDirectionsBtn(CategoryConfig config) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: config.color.withOpacity(0.14),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onGetDirections,
          customBorder: const CircleBorder(),
          child: Icon(Icons.arrow_forward, size: 18, color: config.color),
        ),
      ),
    );
  }
}
