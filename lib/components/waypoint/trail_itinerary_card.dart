import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kKomootLogoAsset = 'assets/images/komoot_logo.png';
const String _kAllTrailsLogoAsset = 'assets/images/alltrailslogo.png';

/// Trail card for itinerary: same style as [WaypointItineraryCard].
/// Shows trail name, optional description (Show more), optional image,
/// and a row of Komoot/AllTrails/GPX icons (always visible) instead of time.
class TrailItineraryCard extends StatefulWidget {
  final String name;
  final String? description;
  final List<String>? photoUrls;
  final bool hasKomoot;
  final bool hasAllTrails;
  final bool hasGpx;
  final String? komootLink;
  final String? allTrailsLink;
  final VoidCallback? onDownloadGpx;
  final VoidCallback? onTap;

  const TrailItineraryCard({
    super.key,
    required this.name,
    this.description,
    this.photoUrls,
    this.hasKomoot = false,
    this.hasAllTrails = false,
    this.hasGpx = false,
    this.komootLink,
    this.allTrailsLink,
    this.onDownloadGpx,
    this.onTap,
  });

  @override
  State<TrailItineraryCard> createState() => _TrailItineraryCardState();
}

class _TrailItineraryCardState extends State<TrailItineraryCard> {
  bool _expanded = false;

  static const Color _kCardBg = Color(0xFFF2E8CF);
  static const Color _kTextPrimary = Color(0xFF212529);

  bool get _hasShowMore =>
      widget.description != null && widget.description!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.name,
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
                            _buildLinkIconsRow(),
                            if (_hasShowMore) _buildShowMoreRow(theme),
                          ],
                        ),
                      ),
                    ),
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
                        child: _buildThumbnailContent(),
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded && _hasShowMore) _buildExpandedDescription(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkIconsRow() {
    final children = <Widget>[];
    if (widget.hasKomoot && widget.komootLink != null) {
      children.add(
        _buildIconChip(
          imageAsset: _kKomootLogoAsset,
          onTap: () => _launchUrl(widget.komootLink!),
        ),
      );
    }
    if (widget.hasAllTrails && widget.allTrailsLink != null) {
      children.add(
        _buildIconChip(
          imageAsset: _kAllTrailsLogoAsset,
          onTap: () => _launchUrl(widget.allTrailsLink!),
        ),
      );
    }
    if (widget.hasGpx && widget.onDownloadGpx != null) {
      children.add(
        _buildIconChip(
          emoji: '📥',
          label: 'GPX',
          onTap: widget.onDownloadGpx!,
        ),
      );
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children
          .expand((w) => [w, const SizedBox(width: 6)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildIconChip({
    String? imageAsset,
    String? emoji,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: WaypointColors.surface,
          border: Border.all(color: WaypointColors.border, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.link, size: 16, color: WaypointColors.textSecondary),
              )
            else if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 12)),
            if (label != null && label.isNotEmpty) ...[
              if (imageAsset != null || emoji != null) const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: WaypointColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Widget _buildThumbnailContent() {
    final urls = widget.photoUrls;
    final imageUrl = urls != null && urls.isNotEmpty ? urls.first : null;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 72,
        placeholder: (_, __) => _thumbnailPlaceholder(),
        errorWidget: (_, __, ___) => _thumbnailPlaceholder(),
      );
    }
    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: WaypointColors.catDo.withValues(alpha: 0.15),
      child: Center(
        child: Icon(Icons.terrain, size: 24, color: WaypointColors.catDo),
      ),
    );
  }

  Widget _buildExpandedDescription(ThemeData theme) {
    if (widget.description == null || widget.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Text(
        widget.description!,
        style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ) ??
            const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}
