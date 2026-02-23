import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/components/common/link_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// External links row component
/// 
/// Displays horizontal row of external links (Komoot, AllTrails, GPX download).
/// Shown when respective links/data exist.

class ExternalLinksRow extends StatelessWidget {
  final String? komootLink;
  final String? allTrailsLink;
  final bool hasGpx;
  final VoidCallback? onDownloadGpx;
  
  const ExternalLinksRow({
    super.key,
    this.komootLink,
    this.allTrailsLink,
    this.hasGpx = false,
    this.onDownloadGpx,
  });
  
  @override
  Widget build(BuildContext context) {
    final links = <Widget>[];
    
    if (komootLink != null && komootLink!.isNotEmpty) {
      links.add(_buildLink(
        emoji: '🔗',
        label: 'Komoot',
        onTap: () => _launchUrl(komootLink!),
      ));
    }
    
    if (allTrailsLink != null && allTrailsLink!.isNotEmpty) {
      links.add(_buildLink(
        emoji: '🥾',
        label: 'AllTrails',
        onTap: () => _launchUrl(allTrailsLink!),
      ));
    }
    
    if (hasGpx && onDownloadGpx != null) {
      links.add(_buildLink(
        emoji: '📥',
        label: 'Download GPX',
        onTap: onDownloadGpx!,
      ));
    }
    
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: WaypointSpacing.gapSm,
      runSpacing: WaypointSpacing.gapSm,
      children: links,
    );
  }
  
  Widget _buildLink({
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return LinkButton(
      emoji: emoji,
      label: label,
      onTap: onTap,
    );
  }
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

