import 'package:flutter/material.dart';
import 'package:waypoint/integrations/offline_manager.dart';
import 'package:waypoint/theme.dart';

class OfflineManagerSheet extends StatefulWidget {
  const OfflineManagerSheet({super.key});

  @override
  State<OfflineManagerSheet> createState() => _OfflineManagerSheetState();
}

class _OfflineManagerSheetState extends State<OfflineManagerSheet> {
  bool _loading = true;
  List<OfflineRegionInfo> _regions = [];

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _loading = true);
    try {
      final regions = await OfflineTilesManager().listRegions();
      if (mounted) setState(() => _regions = regions);
    } catch (e) {
      debugPrint('Failed to load regions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.cloud_download, color: context.colors.primary),
              const SizedBox(width: 12),
              Text('Offline Maps', style: context.textStyles.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_regions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.cloud_off, size: 48, color: Colors.grey.withValues(alpha: 0.8)),
                    const SizedBox(height: 12),
                    Text('No offline maps downloaded', style: context.textStyles.bodyMedium),
                  ]),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return ListTile(
                      leading: Icon(Icons.map, color: context.colors.primary),
                      title: Text(region.name),
                      subtitle: Text('${region.tileCount} tiles • ${region.sizeFormatted}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(region),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _regions.isEmpty ? null : () => _confirmDeleteAll(),
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Delete All'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(OfflineRegionInfo region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offline Region?'),
        content: Text('Delete cached tiles for "${region.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await OfflineTilesManager().deleteAllRegions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline region deleted')));
          await _loadRegions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete offline region')));
        }
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Offline Maps?'),
        content: const Text("This will free up storage space but you'll need to re-download maps for offline use."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await OfflineTilesManager().deleteAllRegions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All offline maps deleted')));
          await _loadRegions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete offline maps')));
        }
      }
    }
  }
}
