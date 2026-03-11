import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/auth/auth_exception.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/models/creator_stats_model.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/services/storage_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/providers/theme_provider.dart';
import 'package:waypoint/components/creator/creator_stats_widget.dart';
import 'package:waypoint/nav.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/stripe_config_service.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';

/// Profile screen where users can sign in/up and manage their account
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Check for pending invite and redirect if found
  /// Called after successful authentication
  Future<void> _handlePostAuthRedirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inviteCode = prefs.getString('pending_invite_code');
      
      if (inviteCode != null && mounted) {
        debugPrint('Found pending invite code: $inviteCode, redirecting...');
        // Clear the pending invite
        await prefs.remove('pending_invite_code');
        
        // Small delay to ensure auth state is fully propagated
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          // Redirect to join screen with fromAuth flag
          context.go('/join/$inviteCode', extra: {'fromAuth': true});
        }
      } else if (mounted) {
        // No invite code, redirect to explore page
        context.go('/');
      }
    } catch (e) {
      debugPrint('Failed to check pending invite: $e');
      // If error occurs, still try to redirect to explore
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuthManager();
    final userService = UserService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (isDesktop)
            SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight)),
          StreamBuilder(
            stream: auth.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }
              final firebaseUser = snapshot.data;
              if (firebaseUser == null) {
                return SliverToBoxAdapter(
                  child: _LoggedOutView(
                    auth: auth,
                    onAuthSuccess: _handlePostAuthRedirect,
                  ),
                );
              }
              return SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: StreamBuilder(
                        stream: userService.streamUser(firebaseUser.uid),
                        builder: (context, userSnap) {
                          final user = userSnap.data;
                          return _LoggedInView(
                            user: user,
                            uid: firebaseUser.uid,
                            email: firebaseUser.email,
                            auth: auth,
                            isDesktop: isDesktop,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _initialsFrom(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _LoggedInView extends StatelessWidget {
  final UserModel? user;
  final String uid;
  final String? email;
  final FirebaseAuthManager auth;
  final bool isDesktop;

  const _LoggedInView({
    required this.user,
    required this.uid,
    required this.email,
    required this.auth,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.isAdmin ?? false;
    final isInfluencer = user?.isInfluencer ?? false;
    final displayName = user != null
        ? ([user!.firstName, user!.lastName].where((e) => e != null && e.isNotEmpty).join(' ').trim().isNotEmpty
            ? [user!.firstName, user!.lastName].where((e) => e != null && e.isNotEmpty).join(' ').trim()
            : user!.displayName)
        : (email ?? 'Explorer');
    final initials = _ProfileScreenState._initialsFrom(displayName);

    return Column(
      children: [
        const SizedBox(height: 16),
        _EditableProfileHeader(
          user: user,
          uid: uid,
          displayName: displayName,
          initials: initials,
          email: email,
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Trip>>(
          stream: TripService().streamTripsForUser(uid),
          builder: (context, tripSnap) {
            final tripCount = tripSnap.data?.length ?? 0;
            final stats = CreatorStats(
              tripsCount: tripCount,
              adventuresCreated: user?.createdPlanIds.length ?? 0,
              followersCount: user?.followerIds.length ?? 0,
              totalDistanceKm: 0,
            );
            return CreatorStatsWidget(stats: stats);
          },
        ),
        const SizedBox(height: 32),
        if (isAdmin || isInfluencer) ...[
          _CreatedPlansSection(uid: uid, isAdmin: isAdmin),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: _CreatorStudioCard()),
          const SizedBox(height: 32),
        ],
        if (isAdmin) ...[
          _SettingsSection(
            label: 'ADMIN',
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.database,
                title: 'Database Migration',
                subtitle: 'Manage system data and schema',
                onTap: () => context.push('/admin/migration'),
              ),
              _StripeModeTile(),
            ],
          ),
          const SizedBox(height: 24),
        ],
        _SettingsSection(
          label: 'APPEARANCE',
          children: [
            _ThemeSwitchTile(),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          label: 'SETTINGS',
          children: [
            _SettingsTile(
              icon: FontAwesomeIcons.gear,
              title: 'Preferences',
              subtitle: 'App behavior and defaults',
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.download,
              title: 'Offline Maps',
              subtitle: 'Download maps for offline use',
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.creditCard,
              title: 'Payments',
              subtitle: 'Manage your cards and billing',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          label: 'SUPPORT',
          children: [
            _SettingsTile(
              icon: FontAwesomeIcons.circleQuestion,
              title: 'Help Center',
              subtitle: 'Guides and support tickets',
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.shieldHalved,
              title: 'Privacy Policy',
              subtitle: 'Data usage and legal terms',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),
        _LogoutButton(auth: auth),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Waypoint v1.0.0',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CreatedPlansSection extends StatelessWidget {
  final String uid;
  final bool isAdmin;

  const _CreatedPlansSection({required this.uid, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final planService = PlanService();
    final stream = isAdmin ? planService.streamAllPlansForAdmin() : planService.streamPlansByCreator(uid);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final cardWidth = isDesktop ? 300.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Created plans'),
        const SizedBox(height: 16),
        SizedBox(
          height: isDesktop ? 400 : 380,
          child: StreamBuilder<List<Plan>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                return Center(
                  child: Text(
                    'No adventures yet',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.none,
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 24),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return SizedBox(
                    width: cardWidth,
                    child: AdventureCard(
                      plan: plan,
                      variant: AdventureCardVariant.standard,
                      onTap: () => context.push('/details/${plan.id}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreatorStudioCard extends StatelessWidget {
  /// Use light-theme green in both themes so Creator Studio stays consistent.
  static const Color _creatorStudioGreen = Color(0xFF228B22); // BrandingLightTokens.primary

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(AppRoutes.builder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _creatorStudioGreen,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: _creatorStudioGreen.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creator Studio',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Design and sell your own custom adventure itineraries.',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.builder),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _creatorStudioGreen,
                ),
                child: const Text('Open Builder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableProfileHeader extends StatefulWidget {
  final UserModel? user;
  final String uid;
  final String displayName;
  final String initials;
  final String? email;

  const _EditableProfileHeader({
    required this.user,
    required this.uid,
    required this.displayName,
    required this.initials,
    required this.email,
  });

  @override
  State<_EditableProfileHeader> createState() => _EditableProfileHeaderState();
}

class _EditableProfileHeaderState extends State<_EditableProfileHeader> {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  bool _uploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final user = widget.user;
    if (user == null) return;
    final result = await _storageService.pickImage();
    if (result == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _storageService.uploadProfilePhoto(
        userId: widget.uid,
        bytes: result.bytes,
      );
      await _userService.updateUser(user.copyWith(photoUrl: url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editName() async {
    final user = widget.user;
    if (user == null) return;
    final fn = await showDialog<String>(
      context: context,
      builder: (ctx) => _InlineEditDialog(
        title: 'First name',
        initial: user.firstName ?? '',
      ),
    );
    if (fn == null || !mounted) return;
    final ln = await showDialog<String>(
      context: context,
      builder: (ctx) => _InlineEditDialog(
        title: 'Last name',
        initial: user.lastName ?? '',
      ),
    );
    if (!mounted) return;
    await _userService.updateUser(user.copyWith(
      firstName: fn.isEmpty ? null : fn,
      lastName: (ln ?? '').isEmpty ? null : ln,
    ));
  }

  Future<void> _editLocation() async {
    final user = widget.user;
    if (user == null) return;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _InlineEditDialog(
        title: 'Location',
        initial: user.location ?? '',
      ),
    );
    if (value == null || !mounted) return;
    await _userService.updateUser(user.copyWith(
      location: value.isEmpty ? null : value,
    ));
  }

  Future<void> _editDescription() async {
    final user = widget.user;
    if (user == null) return;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _InlineEditDialog(
        title: 'Description',
        initial: user.shortBio ?? '',
        maxLines: 4,
      ),
    );
    if (value == null || !mounted) return;
    await _userService.updateUser(user.copyWith(
      shortBio: value.isEmpty ? null : value,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isAdmin = user?.isAdmin ?? false;
    final isInfluencer = user?.isInfluencer ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.photoUrl!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            placeholder: (_, __) => _buildInitialsCircle(),
                            errorWidget: (_, __, ___) => _buildInitialsCircle(),
                          ),
                        )
                      : _buildInitialsCircle(),
                ),
                if (_uploadingPhoto)
                  Positioned.fill(
                    child: ClipOval(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: _editName,
                  child: Text(
                    widget.displayName,
                    style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'ADMIN',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (isInfluencer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'CREATOR',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (user?.location != null && user!.location!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _editLocation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: context.colors.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    user.location!,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _editLocation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Add location',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.email != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.email!,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          if (user?.shortBio != null && user!.shortBio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _editDescription,
              child: Text(
                user.shortBio!,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _editDescription,
              child: Text(
                'Add description',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialsCircle() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.primary,
            context.colors.primary.withValues(alpha: 0.7),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.initials,
          style: context.textStyles.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InlineEditDialog extends StatefulWidget {
  final String title;
  final String initial;
  final int maxLines;

  const _InlineEditDialog({
    required this.title,
    required this.initial,
    this.maxLines = 1,
  });

  @override
  State<_InlineEditDialog> createState() => _InlineEditDialogState();
}

class _InlineEditDialogState extends State<_InlineEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.title,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SettingsSection({
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.outline.withValues(alpha: 0.3),
                  ),
                );
              }
              return children[index ~/ 2];
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? context.colors.surfaceContainerHighest.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: context.textStyles.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              widget.trailing ??
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: context.colors.onSurface.withValues(alpha: 0.4),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripeModeTile extends StatefulWidget {
  @override
  State<_StripeModeTile> createState() => _StripeModeTileState();
}

class _StripeModeTileState extends State<_StripeModeTile> {
  bool? _useLive;

  @override
  void initState() {
    super.initState();
    StripeConfigService.instance.getUseLiveKeysFromCache().then((v) {
      if (mounted) setState(() => _useLive = v);
    });
  }

  Future<void> _onChanged(bool useLive) async {
    setState(() => _useLive = useLive);
    try {
      await StripeConfigService.instance.setUseLiveKeys(useLive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stripe mode updated. Takes effect after app restart.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _useLive = !useLive);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final useLive = _useLive ?? false;
    return _SettingsTile(
      icon: FontAwesomeIcons.creditCard,
      title: 'Stripe mode',
      subtitle: useLive ? 'Production' : 'Test (use for development)',
      trailing: Switch(
        value: useLive,
        onChanged: _onChanged,
        activeColor: context.colors.primary,
        activeTrackColor: context.colors.primary.withValues(alpha: 0.4),
        inactiveThumbColor: context.colors.onSurface.withValues(alpha: 0.7),
        inactiveTrackColor: context.colors.outline,
      ),
      onTap: () => _onChanged(!useLive),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return _SettingsTile(
          icon: themeProvider.isDarkMode ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
          title: 'Theme',
          subtitle: themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            activeColor: context.colors.primary,
            activeTrackColor: context.colors.primary.withValues(alpha: 0.4),
            inactiveThumbColor: context.colors.onSurface.withValues(alpha: 0.7),
            inactiveTrackColor: context.colors.outline,
          ),
          onTap: () => themeProvider.toggleTheme(),
        );
      },
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final FirebaseAuthManager auth;

  const _LogoutButton({required this.auth});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        try {
          await auth.signOut();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Signed out successfully.'),
              backgroundColor: context.colors.primary,
            ),
          );
          context.go('/');
        } catch (e) {
          debugPrint('Logout failed: $e');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to sign out. Please try again.'),
              backgroundColor: context.colors.error,
            ),
          );
        }
      },
      icon: Icon(
        Icons.logout,
        size: 18,
        color: Colors.red.shade400,
      ),
      label: Text(
        'Log Out',
        style: context.textStyles.bodyLarge?.copyWith(
          color: Colors.red.shade400,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Logged-out profile: full-page login/register UI matching the design (logo, card, tabs, social, footer).
class _LoggedOutView extends StatefulWidget {
  const _LoggedOutView({required this.auth, required this.onAuthSuccess});
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;

  @override
  State<_LoggedOutView> createState() => _LoggedOutViewState();
}

class _LoggedOutViewState extends State<_LoggedOutView> {
  late _AuthMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = _AuthMode.signIn;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;
    final cardPadding = isDesktop ? 32.0 : 20.0;
    final maxCardWidth = 420.0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                _WaypointLogoAndTagline(),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _LoginRegisterCard(
                    initialMode: _mode,
                    auth: widget.auth,
                    onAuthSuccess: widget.onAuthSuccess,
                    onModeToggle: (mode) => setState(() => _mode = mode),
                  ),
                ),
                const SizedBox(height: 24),
                _LoggedOutFooter(
                  isRegisterMode: _mode == _AuthMode.signUp,
                  onToggleMode: () => setState(() => _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, app name and tagline for the login screen.
class _WaypointLogoAndTagline extends StatelessWidget {
  static const _logoAsset = 'assets/images/logo-waypoint.png';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 144,
          height: 144,
          child: Image.asset(
            _logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.explore,
                size: 80,
                color: context.colors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Waypoint',
          style: context.textStyles.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plan your next adventure.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

/// Footer: "Don't have an account? Create Account" / "Already have an account? Sign In" and legal links.
class _LoggedOutFooter extends StatelessWidget {
  const _LoggedOutFooter({required this.isRegisterMode, required this.onToggleMode});
  final bool isRegisterMode;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isRegisterMode ? "Already have an account? " : "Don't have an account? ",
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            GestureDetector(
              onTap: onToggleMode,
              child: Text(
                isRegisterMode ? 'Sign In' : 'Create Account',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: context.colors.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Privacy Policy',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              ' • ',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: context.colors.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Terms of Service',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cream card content: Login | Register tabs, form, social buttons.
class _LoginRegisterCard extends StatefulWidget {
  const _LoginRegisterCard({
    required this.initialMode,
    required this.auth,
    required this.onAuthSuccess,
    required this.onModeToggle,
  });
  final _AuthMode initialMode;
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;
  final ValueChanged<_AuthMode> onModeToggle;

  @override
  State<_LoginRegisterCard> createState() => _LoginRegisterCardState();
}

class _LoginRegisterCardState extends State<_LoginRegisterCard> {
  late _AuthMode _mode;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _rememberMe = false;
  bool _agreedToTerms = false;
  bool _marketingOptIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(covariant _LoginRegisterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _agreedToTerms = false;
      _marketingOptIn = false;
    });
    widget.onModeToggle(_mode);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabChip(
                label: 'Login',
                isActive: _mode == _AuthMode.signIn,
                onTap: () {
                  setState(() => _mode = _AuthMode.signIn);
                  widget.onModeToggle(_AuthMode.signIn);
                },
              ),
              const SizedBox(width: 24),
              _TabChip(
                label: 'Register',
                isActive: _mode == _AuthMode.signUp,
                onTap: () {
                  setState(() => _mode = _AuthMode.signUp);
                  widget.onModeToggle(_AuthMode.signUp);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_mode == _AuthMode.signUp) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person_outline, color: context.colors.primary, size: 20),
                      filled: true,
                      fillColor: context.colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline, color: context.colors.primary, size: 20),
                      filled: true,
                      fillColor: context.colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailCtrl,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'explorer@waypoint.com',
              prefixIcon: Icon(Icons.mail_outline, color: context.colors.primary, size: 20),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: context.colors.primary, size: 20),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (_mode == _AuthMode.signIn) return (v == null || v.length < 6) ? 'Min 6 characters' : null;
              return PasswordValidator(v ?? '').errorMessage;
            },
          ),
          if (_mode == _AuthMode.signUp) ...[
            const SizedBox(height: 12),
            _PasswordRequirementsIndicator(password: _passwordCtrl.text),
            const SizedBox(height: 16),
            _CheckboxTile(
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              child: Text.rich(
                TextSpan(
                  text: 'I agree to the ',
                  style: context.textStyles.bodySmall,
                  children: [
                    TextSpan(
                      text: 'Terms and Conditions',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and have read the '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CheckboxTile(
              value: _marketingOptIn,
              onChanged: (v) => setState(() => _marketingOptIn = v ?? false),
              child: Text(
                'Send me interesting commercial offers from Waypoints.',
                style: context.textStyles.bodySmall,
              ),
            ),
          ],
          if (_mode == _AuthMode.signIn) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _CheckboxTile(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    child: Text(
                      'Remember me',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_mode == _AuthMode.signIn ? 'Sign in' : 'Create Account'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: context.colors.outline.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(child: Divider(color: context.colors.outline.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loading ? null : () => _signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              side: BorderSide(color: context.colors.outline.withValues(alpha: 0.6)),
            ),
            child: Icon(Icons.g_mobiledata, size: 26, color: context.colors.onSurface),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _AuthMode.signUp && !_agreedToTerms) {
      _showError('Please agree to the Terms and Conditions');
      return;
    }
    setState(() => _loading = true);
    String? errorMessage;
    try {
      if (_mode == _AuthMode.signIn) {
        await widget.auth.signInWithEmail(context, _emailCtrl.text.trim(), _passwordCtrl.text);
        if (!mounted) return;
        if (!widget.auth.isEmailVerified) {
          _showEmailVerificationDialog();
          return;
        }
        widget.onAuthSuccess();
      } else {
        await widget.auth.createAccountWithEmail(
          context,
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          agreedToTerms: _agreedToTerms,
          marketingOptIn: _marketingOptIn,
        );
        if (!mounted) return;
        _showEmailVerificationDialog();
        return;
      }
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('Auth error: $e');
      errorMessage = _mode == _AuthMode.signIn
          ? 'Sign in failed. Please try again.'
          : 'Failed to create account. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (errorMessage != null) _showError(errorMessage);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(auth: widget.auth, initialEmail: _emailCtrl.text),
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmailVerificationDialog(
        auth: widget.auth,
        onVerified: () {
          Navigator.of(ctx).pop();
          widget.onAuthSuccess();
        },
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final _ = await widget.auth.signInWithGoogle(context);
    if (mounted && _ != null) widget.onAuthSuccess();
  }
}

/// Tab chip for Login / Register with optional green underline.
class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isActive ? context.colors.primary : context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: isActive ? 48 : 0,
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AuthMode { signIn, signUp }

/// Password validation helper class
class PasswordValidator {
  final String password;

  PasswordValidator(this.password);

  bool get hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get hasLowercase => password.contains(RegExp(r'[a-z]'));
  bool get hasNumber => password.contains(RegExp(r'[0-9]'));
  bool get hasSpecialChar => password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]'));
  bool get hasMinLength => password.length >= 8;

  bool get isValid => hasUppercase && hasLowercase && hasNumber && hasSpecialChar && hasMinLength;

  String? get errorMessage {
    if (password.isEmpty) return 'Password is required';
    if (!hasMinLength) return 'Password must be at least 8 characters';
    if (!hasUppercase) return 'Password must contain an uppercase letter';
    if (!hasLowercase) return 'Password must contain a lowercase letter';
    if (!hasNumber) return 'Password must contain a number';
    if (!hasSpecialChar) return 'Password must contain a special character';
    return null;
  }
}

class _EmailAuthForm extends StatefulWidget {
  const _EmailAuthForm({
    required this.initialMode,
    required this.auth,
    required this.onAuthSuccess,
    this.onModeToggle,
  });
  final _AuthMode initialMode;
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;
  final ValueChanged<_AuthMode>? onModeToggle;

  @override
  State<_EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({
    required this.initialMode,
    required this.auth,
    required this.onAuthSuccess,
  });
  final _AuthMode initialMode;
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthFormState extends State<_EmailAuthForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late _AuthMode _mode;
  bool _loading = false;
  bool _agreedToTerms = false;
  bool _marketingOptIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _mode == _AuthMode.signIn ? 'Sign In' : 'Create Account',
                  style: context.textStyles.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: _toggleMode,
                  child: Text(
                    _mode == _AuthMode.signIn ? 'Create account' : 'Have an account?',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Name fields for sign up
            if (_mode == _AuthMode.signUp) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            TextFormField(
              controller: _emailCtrl,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (_mode == _AuthMode.signIn) {
                  return (v == null || v.length < 6) ? 'Min 6 characters' : null;
                }
                return PasswordValidator(v ?? '').errorMessage;
              },
            ),
            
            // Password requirements for sign up
            if (_mode == _AuthMode.signUp) ...[
              const SizedBox(height: 12),
              _PasswordRequirementsIndicator(password: _passwordCtrl.text),
              const SizedBox(height: 16),
              
              // Terms and conditions checkbox
              _CheckboxTile(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: context.textStyles.bodySmall,
                    children: [
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and have read the '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Marketing opt-in checkbox
              _CheckboxTile(
                value: _marketingOptIn,
                onChanged: (v) => setState(() => _marketingOptIn = v ?? false),
                child: Text(
                  'Send me interesting commercial offers from Waypoints.',
                  style: context.textStyles.bodySmall,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account'),
              ),
            ),
            if (_mode == _AuthMode.signIn)
              Center(
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: Text(
                    'Forgot password?',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _agreedToTerms = false;
      _marketingOptIn = false;
    });
    widget.onModeToggle?.call(_mode);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check terms agreement for sign up
    if (_mode == _AuthMode.signUp && !_agreedToTerms) {
      _showInlineError('Please agree to the Terms and Conditions');
      return;
    }
    
    setState(() => _loading = true);
    String? errorMessage;
    
    try {
      if (_mode == _AuthMode.signIn) {
        final user = await widget.auth.signInWithEmail(context, _emailCtrl.text.trim(), _passwordCtrl.text);
        
        if (!mounted) return;
        
        // Check email verification status
        if (!widget.auth.isEmailVerified) {
          _showEmailVerificationDialog();
          return;
        }
        
        if (!mounted) return;
        widget.onAuthSuccess();
      } else {
        final user = await widget.auth.createAccountWithEmail(
          context,
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          agreedToTerms: _agreedToTerms,
          marketingOptIn: _marketingOptIn,
        );
        
        if (!mounted) return;
        
        // Show email verification dialog after signup
        _showEmailVerificationDialog();
        return;
      }
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      errorMessage = _mode == _AuthMode.signIn 
          ? 'Sign in failed. Please try again.'
          : 'Failed to create account. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (errorMessage != null) {
          _showInlineError(errorMessage);
        }
      }
    }
  }
  
  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(auth: widget.auth, initialEmail: _emailCtrl.text),
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmailVerificationDialog(
        auth: widget.auth,
        onVerified: () {
          Navigator.of(ctx).pop();
          widget.onAuthSuccess();
        },
      ),
    );
  }
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late _AuthMode _mode;
  bool _loading = false;
  bool _agreedToTerms = false;
  bool _marketingOptIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _mode == _AuthMode.signIn ? 'Sign In' : 'Create Account',
                    style: context.textStyles.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _mode == _AuthMode.signIn ? 'Create account' : 'Have an account?',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Name fields for sign up
              if (_mode == _AuthMode.signUp) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _emailCtrl,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (_mode == _AuthMode.signIn) {
                    return (v == null || v.length < 6) ? 'Min 6 characters' : null;
                  }
                  return PasswordValidator(v ?? '').errorMessage;
                },
              ),
              
              // Password requirements for sign up
              if (_mode == _AuthMode.signUp) ...[
                const SizedBox(height: 12),
                _PasswordRequirementsIndicator(password: _passwordCtrl.text),
                const SizedBox(height: 16),
                
                // Terms and conditions checkbox
                _CheckboxTile(
                  value: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  child: Text.rich(
                    TextSpan(
                      text: 'I agree to the ',
                      style: context.textStyles.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' and have read the '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Marketing opt-in checkbox
                _CheckboxTile(
                  value: _marketingOptIn,
                  onChanged: (v) => setState(() => _marketingOptIn = v ?? false),
                  child: Text(
                    'Send me interesting commercial offers from Waypoints.',
                    style: context.textStyles.bodySmall,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account'),
                ),
              ),
              if (_mode == _AuthMode.signIn)
                Center(
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'Forgot password?',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _agreedToTerms = false;
      _marketingOptIn = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check terms agreement for sign up
    if (_mode == _AuthMode.signUp && !_agreedToTerms) {
      _showInlineError('Please agree to the Terms and Conditions');
      return;
    }
    
    setState(() => _loading = true);
    String? errorMessage;
    
    try {
      if (_mode == _AuthMode.signIn) {
        final user = await widget.auth.signInWithEmail(context, _emailCtrl.text.trim(), _passwordCtrl.text);
        
        if (!mounted) return;
        
        // Check email verification status
        if (!widget.auth.isEmailVerified) {
          _showEmailVerificationDialog();
          return;
        }
        
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onAuthSuccess();
      } else {
        final user = await widget.auth.createAccountWithEmail(
          context,
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          agreedToTerms: _agreedToTerms,
          marketingOptIn: _marketingOptIn,
        );
        
        if (!mounted) return;
        
        // Show email verification dialog after signup
        _showEmailVerificationDialog();
        return;
      }
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      errorMessage = _mode == _AuthMode.signIn 
          ? 'Sign in failed. Please try again.'
          : 'Failed to create account. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (errorMessage != null) {
          _showInlineError(errorMessage);
        }
      }
    }
  }
  
  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 200,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(auth: widget.auth, initialEmail: _emailCtrl.text),
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmailVerificationDialog(
        auth: widget.auth,
        onVerified: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
          widget.onAuthSuccess();
        },
      ),
    );
  }
}

/// Password requirements visual indicator
class _PasswordRequirementsIndicator extends StatelessWidget {
  final String password;

  const _PasswordRequirementsIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    final validator = PasswordValidator(password);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: context.textStyles.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          _RequirementRow(label: 'At least 8 characters', met: validator.hasMinLength),
          _RequirementRow(label: 'One uppercase letter (A-Z)', met: validator.hasUppercase),
          _RequirementRow(label: 'One lowercase letter (a-z)', met: validator.hasLowercase),
          _RequirementRow(label: 'One number (0-9)', met: validator.hasNumber),
          _RequirementRow(label: 'One special character (!@#\$%...)', met: validator.hasSpecialChar),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : context.colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: met ? Colors.green : context.colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Checkbox tile widget
class _CheckboxTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget child;

  const _CheckboxTile({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged?.call(!value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Forgot password dialog
class _ForgotPasswordDialog extends StatefulWidget {
  final FirebaseAuthManager auth;
  final String initialEmail;

  const _ForgotPasswordDialog({
    required this.auth,
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              _sent ? Icons.mark_email_read : Icons.lock_reset,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _sent ? 'Email Sent' : 'Reset Password',
            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a password reset link to:',
                  style: context.textStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _emailCtrl.text,
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Check your inbox and follow the instructions to reset your password.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
      actions: [
        if (!_sent)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: _sent
              ? () => Navigator.of(context).pop()
              : (_loading ? null : _sendResetEmail),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_sent ? 'Done' : 'Send Reset Link'),
        ),
      ],
    );
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.resetPassword(email: email, context: context);
      if (mounted) {
        setState(() {
          _sent = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Email verification dialog
class _EmailVerificationDialog extends StatefulWidget {
  final FirebaseAuthManager auth;
  final VoidCallback onVerified;

  const _EmailVerificationDialog({
    required this.auth,
    required this.onVerified,
  });

  @override
  State<_EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  bool _checking = false;
  bool _resending = false;

  @override
  Widget build(BuildContext context) {
    final email = widget.auth.currentFirebaseUser?.email ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.mark_email_unread,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verify Your Email',
              style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.email_outlined,
            color: context.colors.primary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'We\'ve sent a verification email to:',
            style: context.textStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: context.textStyles.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Please check your inbox and click the verification link, then tap "I\'ve Verified" below.',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _resending ? null : _resendVerification,
            icon: _resending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(_resending ? 'Sending...' : 'Resend verification email'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.auth.signOut();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _checkVerification,
          child: _checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('I\'ve Verified'),
        ),
      ],
    );
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    try {
      final verified = await widget.auth.reloadUserAndCheckVerification();
      if (verified) {
        widget.onVerified();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Email not verified yet. Please check your inbox.'),
              backgroundColor: context.colors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _resending = true);
    try {
      await widget.auth.resendEmailVerification(context);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }
}
