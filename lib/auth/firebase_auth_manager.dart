import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:waypoint/auth/auth_manager.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/user_service.dart';

/// Firebase implementation of AuthManager
class FirebaseAuthManager extends AuthManager with EmailSignInManager, GoogleSignInManager {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Get current Firebase user
  fb_auth.User? get currentFirebaseUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<fb_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Convert Firebase user to UserModel
  Future<UserModel?> _getCurrentUserModel() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return await _userService.getUserById(fbUser.uid);
  }

  @override
  Future<UserModel?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        return await _userService.getUserById(credential.user!.uid);
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      // Don't show snackbar here - let the UI handle error display
      return null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      // Don't show snackbar here - let the UI handle error display
      return null;
    }
  }

  @override
  Future<UserModel?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password, {
    required String firstName,
    required String lastName,
    required bool agreedToTerms,
    required bool marketingOptIn,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Send email verification
        await credential.user!.sendEmailVerification();
        
        // Update display name in Firebase Auth
        final displayName = '$firstName $lastName'.trim();
        await credential.user!.updateDisplayName(displayName);
        
        // Create user document in Firestore
        final user = UserModel(
          id: credential.user!.uid,
          email: email,
          displayName: displayName,
          firstName: firstName,
          lastName: lastName,
          agreedToTerms: agreedToTerms,
          marketingOptIn: marketingOptIn,
          emailVerified: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _userService.createUser(user);
        
        return user;
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Create account error: ${e.code} - ${e.message}');
      // Don't show snackbar here - let the UI handle error display
      return null;
    } catch (e) {
      debugPrint('Create account error: $e');
      // Don't show snackbar here - let the UI handle error display
      return null;
    }
  }

  @override
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  Future<void> sendEmailVerification(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSuccessSnackBar(context, 'Verification email sent to ${user.email}');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Send verification error: ${e.code} - ${e.message}');
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Send verification error: $e');
      _showErrorSnackBar(context, 'Failed to send verification email');
    }
  }

  @override
  Future<void> resendEmailVerification(BuildContext context) async {
    await sendEmailVerification(context);
  }

  /// Reload current user to check for email verification status
  Future<bool> reloadUserAndCheckVerification() async {
    try {
      await _auth.currentUser?.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      
      // Update Firestore if verified
      if (verified && _auth.currentUser != null) {
        await _userService.updateEmailVerificationStatus(_auth.currentUser!.uid, true);
      }
      
      return verified;
    } catch (e) {
      debugPrint('Failed to reload user: $e');
      return false;
    }
  }

  @override
  Future<UserModel?> signInWithGoogle(BuildContext context) async {
    // Note: Google Sign-In requires additional setup and the google_sign_in package
    // This is a placeholder for future implementation
    _showErrorSnackBar(context, 'Google Sign-In not yet implemented');
    return null;
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Delete user error: ${e.code} - ${e.message}');
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Delete user error: $e');
      _showErrorSnackBar(context, 'An unexpected error occurred');
      rethrow;
    }
  }

  @override
  Future<void> updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(email);
        _showSuccessSnackBar(context, 'Verification email sent to $email');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Update email error: ${e.code} - ${e.message}');
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Update email error: $e');
      _showErrorSnackBar(context, 'An unexpected error occurred');
      rethrow;
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccessSnackBar(context, 'Password reset email sent to $email');
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Reset password error: ${e.code} - ${e.message}');
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
      rethrow;
    } catch (e) {
      debugPrint('Reset password error: $e');
      _showErrorSnackBar(context, 'An unexpected error occurred');
      rethrow;
    }
  }

  /// Get user-friendly error message from Firebase auth error code
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'requires-recent-login':
        return 'Please log in again to perform this action';
      default:
        return 'Authentication error: $code';
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
