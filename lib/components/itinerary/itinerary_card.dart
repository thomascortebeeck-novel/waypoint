import 'package:flutter/material.dart';
import 'package:waypoint/theme.dart';

enum ItineraryStatus { upcoming, inProgress, completed }

class ItineraryCard extends StatelessWidget {
  final String title;
  final String? dateRange;
  final int? days;
  final String? versionName;
  final ItineraryStatus status;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>>? menuItems;
  final void Function(String value)? onMenuSelected;
  /// Number of members in the trip (for group travel)
  final int? memberCount;
  /// Whether current user is the owner of this trip
  final bool isOwner;

  const ItineraryCard({
    super.key,
    required this.title,
    this.dateRange,
    this.days,
    this.versionName,
    required this.status,
    this.onTap,
    this.menuItems,
    this.onMenuSelected,
    this.memberCount,
    this.isOwner = true,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeFg;
    switch (status) {
      case ItineraryStatus.upcoming:
        badgeBg = context.colors.secondaryContainer;
        badgeFg = context.colors.secondary;
        break;
      case ItineraryStatus.inProgress:
        badgeBg = context.colors.primaryContainer;
        badgeFg = context.colors.primary;
        break;
      case ItineraryStatus.completed:
        badgeBg = context.colors.tertiaryContainer;
        badgeFg = context.colors.tertiary;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.colors.outlineVariant),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(Icons.map, color: context.colors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (menuItems != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => menuItems!,
                  ),
              ]),
              if (dateRange != null) ...[
                const SizedBox(height: 4),
                Text(dateRange!, style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (days != null)
                  _badge(context, icon: Icons.calendar_today, label: '$days days'),
                if (versionName != null)
                  _badge(context, icon: Icons.label_rounded, label: versionName!),
                if (memberCount != null && memberCount! > 1)
                  _badge(context, icon: Icons.group, label: '$memberCount members'),
                if (!isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Joined',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: context.colors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _statusLabel(),
                    style: context.textStyles.labelSmall?.copyWith(color: badgeFg, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }

  Widget _badge(BuildContext context, {required IconData icon, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: context.colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: context.textStyles.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ]),
      );

  String _statusLabel() {
    switch (status) {
      case ItineraryStatus.upcoming:
        return 'Upcoming';
      case ItineraryStatus.inProgress:
        return 'In progress';
      case ItineraryStatus.completed:
        return 'Completed';
    }
  }
}
