import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/components/common/action_button.dart';
import 'package:share_plus/share_plus.dart';

/// Action buttons row component
/// 
/// Share and Like buttons for the tab bar.
/// Share: Opens native share dialog
/// Like: Toggles saved state

class ActionButtonsRow extends StatefulWidget {
  final String planId;
  final String? shareUrl;
  final bool isSaved;
  final VoidCallback? onShareTap;
  final VoidCallback? onLikeTap;
  
  const ActionButtonsRow({
    super.key,
    required this.planId,
    this.shareUrl,
    this.isSaved = false,
    this.onShareTap,
    this.onLikeTap,
  });
  
  @override
  State<ActionButtonsRow> createState() => _ActionButtonsRowState();
}

class _ActionButtonsRowState extends State<ActionButtonsRow> {
  bool _isSaved = false;
  
  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }
  
  @override
  void didUpdateWidget(ActionButtonsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      _isSaved = widget.isSaved;
    }
  }
  
  Future<void> _handleShare() async {
    if (widget.onShareTap != null) {
      widget.onShareTap!();
      return;
    }
    
    // Default share behavior
    final url = widget.shareUrl ?? 'https://waypoint.app/adventure/${widget.planId}';
    await Share.share(url);
  }
  
  void _handleLike() {
    setState(() {
      _isSaved = !_isSaved;
    });
    
    if (widget.onLikeTap != null) {
      widget.onLikeTap!();
    } else {
      // TODO: Implement save/unsave plan functionality
      // _userService.toggleSavedPlan(widget.planId);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        _buildActionButton(
          icon: _isSaved ? Icons.favorite : Icons.favorite_border,
          color: _isSaved ? const Color(0xFFD32F2F) : WaypointColors.textSecondary,
          onTap: _handleLike,
        ),
        const SizedBox(width: 8),
        // Share button
        _buildActionButton(
          icon: Icons.share,
          color: WaypointColors.textSecondary,
          onTap: _handleShare,
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionButton(
      icon: icon,
      iconColor: color,
      onTap: onTap,
      tooltip: icon == Icons.favorite || icon == Icons.favorite_border
          ? (_isSaved ? 'Remove from saved' : 'Save adventure')
          : 'Share adventure',
    );
  }
}

