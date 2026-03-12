import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/presentation/admin/admin_migration_content.dart';

/// Standalone admin migration screen (Scaffold + body). Prefer opening /admin and using the Migration tab.
/// /admin/migration redirects to /admin; this screen is kept for any direct usage.
class AdminMigrationScreen extends StatelessWidget {
  const AdminMigrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(FontAwesomeIcons.shieldHalved, size: 16, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Admin Console'),
          ],
        ),
      ),
      body: const AdminMigrationContent(),
    );
  }
}
