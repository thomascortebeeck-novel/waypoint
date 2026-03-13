import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/models/contact_request_model.dart';
import 'package:waypoint/nav.dart';
import 'package:waypoint/presentation/admin/admin_migration_content.dart';
import 'package:waypoint/services/contact_service.dart';
import 'package:waypoint/services/admin_service.dart';
import 'package:waypoint/services/notification_config_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/theme.dart';

/// Admin hub: Dashboard, Push notifications, Migration. Guarded by isAdmin; redirects to login or profile when not allowed.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final AdminService _adminService = AdminService();
  final NotificationConfigService _notificationConfig = NotificationConfigService();

  bool _isCheckingAdmin = true;
  bool _isAdmin = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdmin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        context.go(AppRoutes.login);
      }
      return;
    }
    UserModel? userModel;
    try {
      userModel = await _userService.getUserById(user.uid);
    } catch (_) {}
    if (!mounted) return;
    if (userModel?.isAdmin != true) {
      if (mounted) {
        context.go(AppRoutes.profile);
      }
      return;
    }
    setState(() {
      _isCheckingAdmin = false;
      _isAdmin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Checking access...', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (!_isAdmin) {
      return const SizedBox.shrink();
    }
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
            const Text('Admin'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Push'),
            Tab(icon: Icon(Icons.storage_outlined), text: 'Migration'),
            Tab(icon: Icon(Icons.contact_mail_outlined), text: 'Contact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminDashboardTab(adminService: _adminService),
          _AdminPushNotificationsTab(notificationConfig: _notificationConfig),
          const AdminMigrationContent(),
          _AdminContactTab(contactService: ContactService()),
        ],
      ),
    );
  }
}

class _AdminDashboardTab extends StatefulWidget {
  final AdminService adminService;

  const _AdminDashboardTab({required this.adminService});

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  AdminDashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.adminService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: context.colors.error),
              const SizedBox(height: 16),
              Text('Could not load dashboard', style: context.textStyles.titleMedium?.copyWith(color: context.colors.error)),
              const SizedBox(height: 8),
              Text(_error!, style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final stats = _stats!;
    return ListView(
      padding: AppSpacing.paddingMd,
      children: [
        _StatCard(
          icon: FontAwesomeIcons.layerGroup,
          label: 'Plans',
          value: stats.planCount.toString(),
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: FontAwesomeIcons.route,
          label: 'Trips',
          value: stats.tripCount.toString(),
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: FontAwesomeIcons.users,
          label: 'Users',
          value: stats.userCount.toString(),
        ),
      ],
    );
  }
}

class _AdminContactTab extends StatelessWidget {
  final ContactService contactService;

  const _AdminContactTab({required this.contactService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactRequest>>(
      stream: contactService.streamContactRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: context.colors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load contact requests', style: context.textStyles.titleMedium?.copyWith(color: context.colors.error)),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: context.colors.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No contact requests yet', style: context.textStyles.titleMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: AppSpacing.paddingMd,
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContactRequestCard(request: r),
            );
          },
        );
      },
    );
  }
}

class _ContactRequestCard extends StatelessWidget {
  final ContactRequest request;

  const _ContactRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final created = request.createdAt;
    final dateStr = '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.name,
                  style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                dateStr,
                style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.description,
            style: context.textStyles.bodyMedium,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (request.userEmail != null && request.userEmail!.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                  label: Text(request.userEmail!, style: context.textStyles.bodySmall),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              Chip(
                avatar: const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                label: Text(request.userId, style: context.textStyles.bodySmall, overflow: TextOverflow.ellipsis),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              if (request.relatedPlanId != null)
                Chip(
                  label: Text('Plan: ${request.relatedPlanId}', style: context.textStyles.bodySmall, overflow: TextOverflow.ellipsis),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (request.relatedTripId != null)
                Chip(
                  label: Text('Trip: ${request.relatedTripId}', style: context.textStyles.bodySmall, overflow: TextOverflow.ellipsis),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          if (request.screenshotUrl != null && request.screenshotUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(Uri.parse(request.screenshotUrl!), mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 18, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text('View screenshot', style: context.textStyles.bodySmall?.copyWith(color: context.colors.primary, decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: context.colors.primary),
          const SizedBox(width: 16),
          Text(label, style: context.textStyles.titleMedium),
          const Spacer(),
          Text(value, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AdminPushNotificationsTab extends StatelessWidget {
  final NotificationConfigService notificationConfig;

  const _AdminPushNotificationsTab({required this.notificationConfig});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NotificationConfig>(
      stream: notificationConfig.streamConfig(),
      builder: (context, snapshot) {
        final config = snapshot.hasData ? snapshot.data! : NotificationConfig.defaultConfig;
        return ListView(
          padding: AppSpacing.paddingMd,
          children: [
            _NotificationSwitch(
              title: 'Push notifications enabled',
              subtitle: 'Master switch for all push notifications',
              value: config.pushEnabled,
              onChanged: (v) => _save(context, config.copyWith(pushEnabled: v)),
            ),
            const SizedBox(height: 12),
            _NotificationSwitch(
              title: 'Crew check-in notifications',
              subtitle: 'Notify trip members when someone checks in',
              value: config.checkInEnabled,
              onChanged: (v) => _save(context, config.copyWith(checkInEnabled: v)),
            ),
            const SizedBox(height: 12),
            _NotificationSwitch(
              title: 'Vote resolved notifications',
              subtitle: 'Notify when waypoint voting is closed',
              value: config.voteResolvedEnabled,
              onChanged: (v) => _save(context, config.copyWith(voteResolvedEnabled: v)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, NotificationConfig config) async {
    try {
      await notificationConfig.setConfig(config);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
