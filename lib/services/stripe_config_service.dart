import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stripe test/live mode. Uses Firestore config/stripe.useLiveKeys (admin-only write).
/// Caches value in SharedPreferences so startup is fast; refreshes in background.
/// Stripe.publishableKey must be set at startup from this; changing mode requires app restart.
class StripeConfigService {
  StripeConfigService._();
  static final StripeConfigService _instance = StripeConfigService._();
  static StripeConfigService get instance => _instance;

  static const _prefUseLive = 'stripe_use_live';

  /// Publishable key for current session (from cache at startup; do not change mid-session).
  String get publishableKey => _publishableKey;
  String _publishableKey = '';

  /// Test key from --dart-define=STRIPE_PK_TEST=... or fallback STRIPE_PK
  static String get _pkTest {
    const fromTest = String.fromEnvironment('STRIPE_PK_TEST', defaultValue: '');
    if (fromTest.isNotEmpty) return fromTest;
    return const String.fromEnvironment('STRIPE_PK', defaultValue: '');
  }

  /// Live key from --dart-define=STRIPE_PK_LIVE=...
  static String get _pkLive =>
      const String.fromEnvironment('STRIPE_PK_LIVE', defaultValue: '');

  /// Initialize: read cache, set key for session, then refresh config in background.
  /// Call after Firebase.initializeApp(). Sets Stripe key from cache so UI can show immediately.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final useLive = prefs.getBool(_prefUseLive) ?? false;
    _publishableKey = useLive ? _pkLive : _pkTest;
    if (_publishableKey.isEmpty) return;

    // Refresh config in background for next launch
    _refreshConfig(prefs);
  }

  Future<void> _refreshConfig(SharedPreferences prefs) async {
    try {
      final snap = await FirebaseFirestore.instance.doc('config/stripe').get();
      final useLive = (snap.data()?['useLiveKeys'] as bool?) ?? false;
      await prefs.setBool(_prefUseLive, useLive);
    } catch (_) {
      // Keep existing cache
    }
  }

  /// Current useLive from cache (for profile UI display). May be stale until next launch.
  Future<bool> getUseLiveKeysFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefUseLive) ?? false;
  }

  /// Write useLiveKeys (admin only; Firestore rules enforce). Call after admin toggles in profile.
  /// Note: Takes effect after app restart.
  Future<void> setUseLiveKeys(bool useLive) async {
    await FirebaseFirestore.instance.doc('config/stripe').set(
      {'useLiveKeys': useLive},
      SetOptions(merge: true),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseLive, useLive);
  }
}
