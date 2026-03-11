import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/presentation/profile/profile_screen.dart';

/// Full-screen login/register screen for iOS/Android.
/// Shown as the first screen when the user is not signed in. No bottom navigation.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WaypointLoginRegisterView(
          auth: FirebaseAuthManager(),
          onAuthSuccess: () => _handlePostAuthRedirect(context),
        ),
      ),
    );
  }

  /// Same as ProfileScreen: check pending invite then go to /join/XXX or /.
  static Future<void> _handlePostAuthRedirect(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inviteCode = prefs.getString('pending_invite_code');
      if (inviteCode != null && context.mounted) {
        await prefs.remove('pending_invite_code');
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          context.go('/join/$inviteCode', extra: {'fromAuth': true});
          return;
        }
      }
    } catch (e) {
      debugPrint('AuthScreen post-auth redirect: $e');
    }
    if (context.mounted) context.go('/');
  }
}
