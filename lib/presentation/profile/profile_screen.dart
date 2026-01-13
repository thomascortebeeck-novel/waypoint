import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuthManager();
    final userService = UserService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, isDesktop),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 8,
            ),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder(
                stream: auth.authStateChanges,
                builder: (context, snapshot) {
                  final firebaseUser = snapshot.data;
                  if (firebaseUser == null) {
                    return _LoggedOutView(auth: auth);
                  }
                  return StreamBuilder(
                    stream: userService.streamUser(firebaseUser.uid),
                    builder: (context, userSnap) {
                      final user = userSnap.data;
                      final displayName = user?.displayName ?? firebaseUser.displayName ?? firebaseUser.email ?? 'Explorer';
                      final initials = _initialsFrom(displayName);
                      final isAdmin = user?.isAdmin ?? false;
                      return _LoggedInView(
                        displayName: displayName,
                        email: firebaseUser.email,
                        initials: initials,
                        isAdmin: isAdmin,
                        auth: auth,
                        isDesktop: isDesktop,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 140 : 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: context.colors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.primary.withValues(alpha: 0.08),
                context.colors.surface,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 24 : 16,
                isDesktop ? 32 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Profile',
                    style: context.textStyles.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed = constraints.biggest.height < 80;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                'Profile',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
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
  final String displayName;
  final String? email;
  final String initials;
  final bool isAdmin;
  final FirebaseAuthManager auth;
  final bool isDesktop;

  const _LoggedInView({
    required this.displayName,
    required this.email,
    required this.initials,
    required this.isAdmin,
    required this.auth,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _UserInfoCard(
          displayName: displayName,
          email: email,
          initials: initials,
          isAdmin: isAdmin,
        ),
        const SizedBox(height: 32),
        if (isAdmin) ...[
          _SettingsSection(
            label: 'ADMIN',
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.database,
                title: 'Database Migration',
                onTap: () => context.push('/admin/migration'),
              ),
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
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.download,
              title: 'Offline Maps',
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.creditCard,
              title: 'Payment Methods',
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
              onTap: () {},
            ),
            _SettingsTile(
              icon: FontAwesomeIcons.shieldHalved,
              title: 'Privacy Policy',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),
        _LogoutButton(auth: auth),
      ],
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  final String displayName;
  final String? email;
  final String initials;
  final bool isAdmin;

  const _UserInfoCard({
    required this.displayName,
    required this.email,
    required this.initials,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 80,
            height: 80,
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
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: context.textStyles.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
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
              ],
            ],
          ),
          if (email != null) ...[
            const SizedBox(height: 4),
            Text(
              email!,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
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

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView({required this.auth});
  final FirebaseAuthManager auth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 36,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to sync your plans and trips',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openAuthSheet(context, mode: _AuthMode.signIn),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openAuthSheet(context, mode: _AuthMode.signUp),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAuthSheet(BuildContext context, {required _AuthMode mode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _EmailAuthSheet(initialMode: mode, auth: auth),
    );
  }
}

enum _AuthMode { signIn, signUp }

class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({required this.initialMode, required this.auth});
  final _AuthMode initialMode;
  final FirebaseAuthManager auth;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late _AuthMode _mode;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
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
                    onPressed: _forgotPassword,
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

  void _toggleMode() => setState(() => _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_mode == _AuthMode.signIn) {
        await widget.auth.signInWithEmail(context, _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await widget.auth.createAccountWithEmail(context, _emailCtrl.text.trim(), _passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password')),
      );
      return;
    }
    await FirebaseAuthManager().resetPassword(email: email, context: context);
  }
}
