// Authentication Manager - Base interface for auth implementations
//
// This abstract class and mixins define the contract for authentication systems.
// Implement this with concrete classes for Firebase, Supabase, or local auth.
//
// Usage:
// 1. Create a concrete class extending AuthManager
// 2. Mix in the required authentication provider mixins
// 3. Implement all abstract methods with your auth provider logic

import 'package:flutter/material.dart';
import 'package:waypoint/models/user_model.dart';

// Core authentication operations that all auth implementations must provide
abstract class AuthManager {
  Future signOut();
  Future deleteUser(BuildContext context);
  Future updateEmail({required String email, required BuildContext context});
  Future resetPassword({required String email, required BuildContext context});
}

// Email/password authentication mixin
mixin EmailSignInManager on AuthManager {
  Future<UserModel?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  );

  Future<UserModel?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password, {
    required String firstName,
    required String lastName,
    required bool agreedToTerms,
    required bool marketingOptIn,
  });

  /// Send email verification to the current user
  Future<void> sendEmailVerification(BuildContext context);

  /// Check if current user's email is verified
  bool get isEmailVerified;

  /// Resend email verification
  Future<void> resendEmailVerification(BuildContext context);
}

// Anonymous authentication for guest users
mixin AnonymousSignInManager on AuthManager {
  Future<UserModel?> signInAnonymously(BuildContext context);
}

// Apple Sign-In authentication (iOS/web)
mixin AppleSignInManager on AuthManager {
  Future<UserModel?> signInWithApple(BuildContext context);
}

// Google Sign-In authentication (all platforms)
mixin GoogleSignInManager on AuthManager {
  Future<UserModel?> signInWithGoogle(BuildContext context);
}

// JWT token authentication for custom backends
mixin JwtSignInManager on AuthManager {
  Future<UserModel?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  );
}

// Phone number authentication with SMS verification
mixin PhoneSignInManager on AuthManager {
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  });

  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  });
}

// Facebook Sign-In authentication
mixin FacebookSignInManager on AuthManager {
  Future<UserModel?> signInWithFacebook(BuildContext context);
}

// Microsoft Sign-In authentication (Azure AD)
mixin MicrosoftSignInManager on AuthManager {
  Future<UserModel?> signInWithMicrosoft(
    BuildContext context,
    List<String> scopes,
    String tenantId,
  );
}

// GitHub Sign-In authentication (OAuth)
mixin GithubSignInManager on AuthManager {
  Future<UserModel?> signInWithGithub(BuildContext context);
}
