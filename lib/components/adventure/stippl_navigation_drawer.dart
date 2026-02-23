import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';
import 'package:go_router/go_router.dart';

/// Navigation items for the Stippl-style drawer
enum NavigationItem {
  overview,
  itinerary,
  checklist,
  localTips,
  comments,
  review,
}

/// Stippl-style left sidebar navigation drawer
/// Replaces the TabController-based navigation system
class StipplNavigationDrawer extends StatelessWidget {
  final NavigationItem selectedItem;
  final ValueChanged<NavigationItem> onItemSelected;
  final String title;
  final bool isPlanMode; // true for plan, false for trip
  final VoidCallback? onShare;
  final VoidCallback? onLike;
  final VoidCallback? onInvite; // Only for trip mode
  final bool isLiked;
  
  /// When true, renders a loading placeholder instead of nav content.
  /// This avoids swapping the drawer widget type (which causes DrawerController
  /// to hit-test an unlaid-out child during the loading→loaded transition).
  final bool isLoading;

  const StipplNavigationDrawer({
    Key? key,
    required this.selectedItem,
    required this.onItemSelected,
    required this.title,
    this.isPlanMode = true,
    this.onShare,
    this.onLike,
    this.onInvite,
    this.isLiked = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safe — caller guarantees valid mediaQuery
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = WaypointBreakpoints.isDesktop(screenWidth);
    final drawerWidth = isDesktop ? 280.0 : 260.0;

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          // ALWAYS a Column — same structure to avoid DrawerController hit-test issues
          children: [
            // Header with title and action buttons
            _buildHeader(context),
            
            // Navigation items or loading indicator
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildNavigationList(context),
            ),
            
            // Footer with "Back to home" button (only when not loading)
            if (!isLoading) _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: WaypointTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            children: [
              if (isPlanMode) ...[
                // Share button
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: onShare,
                  tooltip: 'Share',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                const SizedBox(width: 8),
                // Like button
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                  tooltip: 'Like',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ] else ...[
                // Trip mode: Invite and Like
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: onInvite,
                  tooltip: 'Invite friend',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                  tooltip: 'Like',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(BuildContext context) {
    final items = [
      _NavigationItemData(
        item: NavigationItem.overview,
        label: 'Overview',
        icon: Icons.dashboard_outlined,
      ),
      _NavigationItemData(
        item: NavigationItem.itinerary,
        label: 'Itinerary',
        icon: Icons.route_outlined,
      ),
      _NavigationItemData(
        item: NavigationItem.checklist,
        label: 'Checklist',
        icon: Icons.checklist_outlined,
      ),
      _NavigationItemData(
        item: NavigationItem.localTips,
        label: 'Local Tips',
        icon: Icons.lightbulb_outline,
      ),
      _NavigationItemData(
        item: NavigationItem.comments,
        label: 'Comments',
        icon: Icons.comment_outlined,
      ),
      _NavigationItemData(
        item: NavigationItem.review,
        label: 'Review',
        icon: Icons.rate_review_outlined,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: items.map((itemData) {
        final isSelected = selectedItem == itemData.item;
        return _buildNavigationItem(
          context,
          itemData: itemData,
          isSelected: isSelected,
        );
      }).toList(),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required _NavigationItemData itemData,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        onItemSelected(itemData.item);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade100 : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              itemData.icon,
              size: 22,
              color: isSelected
                  ? const Color(0xFF1B4332)
                  : Colors.grey.shade700,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                itemData.label,
                style: WaypointTypography.bodyMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF1B4332)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(); // Close drawer
            context.go('/');
          },
          icon: const Icon(Icons.home_outlined, size: 20),
          label: const Text('Back to home'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}

/// Internal data class for navigation items
class _NavigationItemData {
  final NavigationItem item;
  final String label;
  final IconData icon;

  _NavigationItemData({
    required this.item,
    required this.label,
    required this.icon,
  });
}

