import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/providers/theme_provider.dart';

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
                  // Wait for stream to initialize
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  final firebaseUser = snapshot.data;
                  if (firebaseUser == null) {
                    return _LoggedOutView(
                      auth: auth,
                      onAuthSuccess: _handlePostAuthRedirect,
                    );
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
  const _LoggedOutView({required this.auth, required this.onAuthSuccess});
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;

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
      builder: (_) => _EmailAuthSheet(
        initialMode: mode,
        auth: auth,
        onAuthSuccess: onAuthSuccess,
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
        
        // If sign in failed (user is null), show error and keep sheet open
        if (user == null) {
          errorMessage = 'Incorrect email or password. Please try again.';
          return;
        }
        
        // Check email verification status
        if (!widget.auth.isEmailVerified) {
          _showEmailVerificationDialog();
          return;
        }
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
        
        // If account creation failed, keep sheet open
        if (user == null) {
          errorMessage = 'Failed to create account. Please try again.';
          return;
        }
        
        // Show email verification dialog after signup
        _showEmailVerificationDialog();
        return;
      }
      
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAuthSuccess();
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
