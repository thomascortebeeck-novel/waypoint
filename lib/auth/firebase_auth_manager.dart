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
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
      return null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      _showErrorSnackBar(context, 'An unexpected error occurred');
      return null;
    }
  }

  @override
  Future<UserModel?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Create user document in Firestore
        final user = UserModel(
          id: credential.user!.uid,
          email: email,
          displayName: email.split('@')[0],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _userService.createUser(user);
        return user;
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Create account error: ${e.code} - ${e.message}');
      _showErrorSnackBar(context, _getAuthErrorMessage(e.code));
      return null;
    } catch (e) {
      debugPrint('Create account error: $e');
      _showErrorSnackBar(context, 'An unexpected error occurred');
      return null;
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
