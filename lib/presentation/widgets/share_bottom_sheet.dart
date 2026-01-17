import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme.dart';

/// Bottom sheet for sharing a plan with rich preview
class ShareBottomSheet extends StatelessWidget {
  final Plan plan;

  const ShareBottomSheet({super.key, required this.plan});

  /// Get the base URL for sharing based on current environment
  static String get _baseUrl {
    if (kIsWeb) {
      // On web, use the current domain
      final uri = Uri.base;
      final baseUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
      return baseUrl;
    }
    // On mobile, use production URL
    return 'https://waypoint.app';
  }

  /// Generate the deep link URL for the plan
  /// Uses /plan/:planId format which redirects to the actual route
  String get shareUrl => '$_baseUrl/plan/${plan.id}';

  /// Generate share text
  String get shareText => '${plan.name}\n\n${plan.description.length > 100 ? '${plan.description.substring(0, 100)}...' : plan.description}\n\n$shareUrl';

  static Future<void> show(BuildContext context, Plan plan) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareBottomSheet(plan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Title
            Text(
              'Share Adventure',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Mini preview card
            _buildPreviewCard(context),
            const SizedBox(height: 24),

            // Share options
            Text(
              'Share via',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Share buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  context,
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: context.colors.primary,
                  onTap: () => _copyLink(context),
                ),
                _buildShareOption(
                  context,
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.blue,
                  onTap: () => _systemShare(context),
                ),
                _buildShareOption(
                  context,
                  icon: Icons.message,
                  label: 'SMS',
                  color: Colors.green,
                  onTap: () => _sendSms(context),
                ),
                _buildShareOption(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  color: Colors.orange,
                  onTap: () => _sendEmail(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: plan.heroImageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade300,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plan.location,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.minPrice == 0 ? 'Free' : '€${plan.minPrice.toStringAsFixed(0)}',
                    style: context.textStyles.titleSmall?.copyWith(
                      color: context.colors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: context.textStyles.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Link Copied!'),
            ],
          ),
          backgroundColor: context.colors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _systemShare(BuildContext context) async {
    Navigator.pop(context);
    await Share.share(shareText);
  }

  Future<void> _sendSms(BuildContext context) async {
    Navigator.pop(context);
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': shareText},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    Navigator.pop(context);
    final uri = Uri(
      scheme: 'mailto',
      path: '',
      queryParameters: {
        'subject': 'Check out this adventure: ${plan.name}',
        'body': shareText,
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
