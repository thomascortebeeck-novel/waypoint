import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';
import 'package:waypoint/models/route_waypoint.dart' show
    RouteWaypoint,
    getWaypointIcon,
    getWaypointColor,
    getWaypointLabel;
import 'package:waypoint/services/favorite_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared bottom sheet for waypoint detail from map marker tap.
/// Shows hero image (with null fallback), name, description, Save (plan favorite), Open link.
/// Use [WaypointMapDetailSheet.show] so the same sheet updates in place when another marker is tapped.
class WaypointMapDetailSheet {
  WaypointMapDetailSheet._();

  static ValueNotifier<RouteWaypoint?>? _waypointNotifier;
  static String? _planId;

  /// Shows the waypoint detail sheet. If a sheet is already open, updates its content to [waypoint].
  static void show(
    BuildContext context, {
    required RouteWaypoint waypoint,
    String? planId,
  }) {
    if (_waypointNotifier != null) {
      _waypointNotifier!.value = waypoint;
      _planId = planId;
      return;
    }
    _waypointNotifier = ValueNotifier<RouteWaypoint?>(waypoint);
    _planId = planId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _WaypointMapDetailSheetContent(
        waypointNotifier: _waypointNotifier!,
        planId: planId,
      ),
    ).whenComplete(() {
      _waypointNotifier = null;
      _planId = null;
    });
  }
}

class _WaypointMapDetailSheetContent extends StatefulWidget {
  const _WaypointMapDetailSheetContent({
    required this.waypointNotifier,
    this.planId,
  });

  final ValueNotifier<RouteWaypoint?> waypointNotifier;
  final String? planId;

  @override
  State<_WaypointMapDetailSheetContent> createState() =>
      _WaypointMapDetailSheetContentState();
}

class _WaypointMapDetailSheetContentState
    extends State<_WaypointMapDetailSheetContent> {
  bool? _isFavorited;
  bool _toggleInProgress = false;

  @override
  void initState() {
    super.initState();
    widget.waypointNotifier.addListener(_onWaypointChanged);
    _loadFavoriteState();
  }

  void _onWaypointChanged() {
    if (mounted) {
      setState(() {
        _isFavorited = null;
      });
      _loadFavoriteState();
    }
  }

  Future<void> _loadFavoriteState() async {
    final waypoint = widget.waypointNotifier.value;
    final planId = widget.planId;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (planId == null || userId == null) {
      if (mounted) setState(() => _isFavorited = false);
      return;
    }
    final favorited =
        await FavoriteService().isFavorited(userId, planId);
    if (mounted) setState(() => _isFavorited = favorited);
  }

  Future<void> _toggleFavorite() async {
    final planId = widget.planId;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (planId == null || userId == null || _toggleInProgress) return;
    setState(() => _toggleInProgress = true);
    try {
      final nowFavorited =
          await FavoriteService().toggleFavorite(userId, planId);
      if (mounted) setState(() {
        _isFavorited = nowFavorited;
        _toggleInProgress = false;
      });
    } catch (e) {
      if (mounted) setState(() => _toggleInProgress = false);
    }
  }

  @override
  void dispose() {
    widget.waypointNotifier.removeListener(_onWaypointChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waypoint = widget.waypointNotifier.value;
    if (waypoint == null) return const SizedBox.shrink();

    final config = getCategoryConfig(waypoint.type);
    final imageUrl = waypoint.linkImageUrl ??
        waypoint.photoUrl ??
        (waypoint.photoUrls?.isNotEmpty == true ? waypoint.photoUrls!.first : null);
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final showSave = isAuthenticated && widget.planId != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
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
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder(config),
                    ),
                  )
                else
                  _heroPlaceholder(config),
                if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
                Text(
                  waypoint.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ) ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  getWaypointLabel(waypoint.type),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (waypoint.description != null &&
                    waypoint.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    waypoint.description!,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (showSave)
                      _SaveButton(
                        isFavorited: _isFavorited ?? false,
                        isLoading: _isFavorited == null || _toggleInProgress,
                        onTap: _toggleFavorite,
                      ),
                    if (showSave) const SizedBox(width: 16),
                    if (waypoint.linkUrl != null &&
                        waypoint.linkUrl!.isNotEmpty)
                      _OpenButton(linkUrl: waypoint.linkUrl!),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroPlaceholder(CategoryConfig config) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(config.icon, size: 48, color: config.color),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isFavorited,
    required this.isLoading,
    required this.onTap,
  });

  final bool isFavorited;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.red : Colors.grey.shade600,
                  size: 24,
                ),
              const SizedBox(width: 8),
              const Text('Save'),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.linkUrl});

  final String linkUrl;

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.tryParse(linkUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openLink(context),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new, size: 24, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text('Open'),
            ],
          ),
        ),
      ),
    );
  }
}
