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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profile",
          style: context.textStyles.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: auth.authStateChanges,
        builder: (context, snapshot) {
          final firebaseUser = snapshot.data;
          if (firebaseUser == null) {
            return _LoggedOutView(auth: auth);
          }
          // Logged in: stream the app user profile for live updates
          return StreamBuilder(
            stream: userService.streamUser(firebaseUser.uid),
            builder: (context, userSnap) {
              final displayName = userSnap.data?.displayName ?? firebaseUser.displayName ?? firebaseUser.email ?? 'Explorer';
              final initials = _initialsFrom(displayName);
              return ListView(
                padding: AppSpacing.paddingMd,
                children: [
                  Center(
                    child: Column(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: context.colors.primaryContainer,
                        child: Text(initials, style: context.textStyles.headlineLarge?.copyWith(color: context.colors.onPrimaryContainer)),
                      ),
                      const SizedBox(height: 16),
                      Text(displayName, style: context.textStyles.titleLarge),
                      if (firebaseUser.email != null)
                        Text(firebaseUser.email!, style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 32),
                  _buildSection(context, "Appearance", [
                    _buildThemeSwitcher(context),
                  ]),
                  _buildSection(context, "Settings", [
                    _buildTile(context, FontAwesomeIcons.gear, "Preferences", () {}),
                    _buildTile(context, FontAwesomeIcons.download, "Offline Maps", () {}),
                    _buildTile(context, FontAwesomeIcons.creditCard, "Payment Methods", () {}),
                  ]),
                  _buildSection(context, "Support", [
                    _buildTile(context, FontAwesomeIcons.circleQuestion, "Help Center", () {}),
                    _buildTile(context, FontAwesomeIcons.shieldHalved, "Privacy Policy", () {}),
                  ]),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await auth.signOut();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully.')));
                        context.go('/');
                      } catch (e) {
                        debugPrint('Logout failed: $e');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to sign out. Please try again.')));
                      }
                    },
                    child: const Text("Log Out"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            title,
            style: context.textStyles.titleMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: context.colors.onSurface),
      title: Text(title, style: context.textStyles.bodyLarge),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }

  Widget _buildThemeSwitcher(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return ListTile(
          leading: Icon(
            themeProvider.isDarkMode ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
            size: 20,
            color: context.colors.onSurface,
          ),
          title: Text('Theme', style: context.textStyles.bodyLarge),
          subtitle: Text(
            themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
            style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
          ),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            activeColor: context.colors.primary,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
      },
    );
  }

  String _initialsFrom(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView({required this.auth});
  final FirebaseAuthManager auth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMd,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: context.colors.primaryContainer,
              child: Icon(Icons.person, color: context.colors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Welcome', style: context.textStyles.titleLarge),
            Text('Sign in to sync your plans and trips', style: context.textStyles.bodyMedium?.copyWith(color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _openAuthSheet(context, mode: _AuthMode.signIn, auth: auth),
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openAuthSheet(context, mode: _AuthMode.signUp, auth: auth),
          icon: const Icon(Icons.person_add),
          label: const Text('Create Account'),
        ),
      ],
    );
  }

  void _openAuthSheet(BuildContext context, {required _AuthMode mode, required FirebaseAuthManager auth}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
        padding: AppSpacing.paddingMd,
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account', style: context.textStyles.titleLarge),
                TextButton(
                  onPressed: _toggleMode,
                  child: Text(_mode == _AuthMode.signIn ? 'Create account' : 'Have an account? Sign in'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account'),
              ),
            ),
            if (_mode == _AuthMode.signIn)
              Center(
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 8),
          ]),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email to reset password')));
      return;
    }
    await FirebaseAuthManager().resetPassword(email: email, context: context);
  }
}
