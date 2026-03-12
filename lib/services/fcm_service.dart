import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM (Firebase Cloud Messaging) registration and token storage for push notifications.
/// Token is stored in Firestore at users/{uid} field `fcm_token` for Cloud Functions to send messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false;

  /// Call once after Firebase.initializeApp(). Sets background handler and listens to auth to save token.
  Future<void> init() async {
    if (_initialized) return;
    // Background/terminated message handler (must be top-level or static)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      // Optional: show in-app banner or update UI
    });

    // User tapped notification (app opened from background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Opened from notification: ${message.data}');
      // Optional: deep link to tripId, etc. via message.data
    });

    _initialized = true;

    // If already logged in, register token
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _saveTokenForUser(user.uid);

    // When auth state changes, update token for new user or clear on logout
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _saveTokenForUser(user.uid);
      } else {
        // Logout: token is no longer valid for this device; Cloud Functions will skip if no token
      }
    });
  }

  /// Request notification permission (iOS; Android 13+ handled by plugin). No-op on web.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    return true;
  }

  /// Get current FCM token. Returns null on web if not configured.
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // Web requires VAPID key in Firebase console; optional for "start"
        return await _messaging.getToken();
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore users/{userId}.fcm_token for Cloud Functions.
  Future<void> saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _saveTokenForUser(user.uid);
  }

  Future<void> _saveTokenForUser(String userId) async {
    try {
      final granted = await requestPermission();
      if (!granted) return;
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      await _firestore.collection('users').doc(userId).set(
            {'fcm_token': token, 'fcm_token_updated_at': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
      debugPrint('[FCM] Token saved for user $userId');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Call when token refreshes (e.g. onTokenRefresh listener) to keep Firestore in sync.
  void listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((String token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _firestore.collection('users').doc(user.uid).set(
              {'fcm_token': token, 'fcm_token_updated_at': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
      }
    });
  }
}
