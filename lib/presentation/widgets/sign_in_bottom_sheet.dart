import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/theme.dart';

/// Bottom sheet prompting user to sign in
class SignInBottomSheet extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onSignIn;

  const SignInBottomSheet({
    super.key,
    this.title,
    this.message,
    this.onSignIn,
  });

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onSignIn,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SignInBottomSheet(
        title: title,
        message: message,
        onSignIn: onSignIn,
      ),
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
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title ?? 'Sign In Required',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message ?? 'Create an account or sign in to save your favorites, track your adventures, and access exclusive features.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onSignIn != null) {
                    onSignIn!();
                  } else {
                    // Navigate to profile/auth screen
                    context.go('/profile');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Sign In'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
