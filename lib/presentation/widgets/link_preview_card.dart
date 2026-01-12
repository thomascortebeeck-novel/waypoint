import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:waypoint/services/link_preview_service.dart';
import 'package:waypoint/theme.dart';

class LinkPreviewCard extends StatelessWidget {
  final LinkPreviewData data;
  final VoidCallback? onRemove;
  const LinkPreviewCard({super.key, required this.data, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final image = data.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image != null && image.isNotEmpty)
          SizedBox(
            width: 120,
            height: 90,
            child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
          )
        else
          Container(
            width: 120,
            height: 90,
            color: context.colors.surfaceContainerHighest,
            child: const Icon(Icons.link, size: 28),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                data.title ?? data.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.titleMedium,
              ),
              const SizedBox(height: 4),
              if (data.description != null)
                Text(
                  data.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
                ),
              const SizedBox(height: 4),
              Text(
                Uri.tryParse(data.url)?.host ?? '',
                style: context.textStyles.labelSmall?.copyWith(color: Colors.grey),
              ),
            ]),
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
      ]),
    );
  }
}
